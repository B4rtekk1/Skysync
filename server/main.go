package main

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"regexp"
	"skysync/global"
	"skysync/handlers"
	models "skysync/models_db"
	"skysync/utils"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"gopkg.in/yaml.v3"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var LoginAttempts = make(map[string][]time.Time)
var BlockedIPs = make(map[string]time.Time)
var DeletionAttempts = make(map[string][]time.Time)
var ResetAttempts = make(map[string][]time.Time)
var Mutex = &sync.Mutex{}
var Logger *utils.AsyncLogger

func clearRateLimitMaps() {
	Mutex.Lock()
	defer Mutex.Unlock()
	LoginAttempts = make(map[string][]time.Time)
	BlockedIPs = make(map[string]time.Time)
	DeletionAttempts = make(map[string][]time.Time)
	ResetAttempts = make(map[string][]time.Time)
	log.Println("Rate limiting maps cleared")
}

func generateLogFile(db *gorm.DB) error {
	var securityEvents []models.SecurityEvent
	if err := db.Find(&securityEvents).Error; err != nil {
		return fmt.Errorf("could not load data from database: %v", err)
	}
	logFileName := fmt.Sprintf("security_log_%s.txt", time.Now().Format("2006-01-02_15-04-05"))
	file, err := os.Create(logFileName)
	if err != nil {
		return fmt.Errorf("could not create logs file: %v", err)
	}
	defer file.Close()

	for _, event := range securityEvents {
		logEntry := fmt.Sprintf("[%s] %s: %s (Username: %s, IP: %s, UserAgent: %s, Path: %s, Method: %s)\n",
			event.Timestamp.Format("2006-01-02 15:04:05"),
			event.EventType,
			event.Details,
			event.Username,
			event.UserIP,
			event.UserAgent,
			event.RequestPath,
			event.RequestMethod)
		if _, err := file.WriteString(logEntry); err != nil {
			return fmt.Errorf("nie udało się zapisać do pliku logów: %v", err)
		}
	}

	log.Printf("Logs file %s created successfully", logFileName)
	return nil
}

func APIKeyMiddleware() gin.HandlerFunc {
	if global.API_KEY == "" {
		log.Fatal("API key not found in .env")
	}
	return func(c *gin.Context) {
		providedKey := c.GetHeader("X-API-Key")
		if providedKey == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "No API key provided"})
			c.Abort()
			return
		}
		if providedKey != global.API_KEY {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid API key"})
			c.Abort()
			return
		}
		c.Next()
	}
}

func JWTMiddleware(db *gorm.DB, config *utils.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Autorization header required"})
			c.Abort()
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid header format"})
			c.Abort()
			return
		}

		tokenString := parts[1]
		secretKey := global.SECRET_KEY
		if secretKey == "" {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "SECRET_KEY not found"})
			c.Abort()
			return
		}

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("invalid algorithm: %v", token.Header["alg"])
			}
			return []byte(secretKey), nil
		})

		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token: " + err.Error()})
			c.Abort()
			return
		}

		if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
			userIDFloat, ok := claims["user_id"].(float64)
			if !ok {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token data"})
				c.Abort()
				return
			}
			userID := uint(userIDFloat)

			jti, jtiExists := claims["jti"].(string)
			if jtiExists && jti != "" {
				var blacklisted models.JWTBlacklist
				if err := db.Where("jti = ?", jti).First(&blacklisted).Error; err == nil {
					c.JSON(http.StatusUnauthorized, gin.H{"error": "Token has been revoked"})
					c.Abort()
					return
				}
			}

			if nbf, ok := claims["nbf"].(float64); ok {
				if time.Now().Unix() < int64(nbf) {
					c.JSON(http.StatusUnauthorized, gin.H{"error": "Token not yet valid"})
					c.Abort()
					return
				}
			}

			if config.SessionInactivityTimeout > 0 {
				sessionID, _ := claims["session_id"].(string)

				if sessionID != "" {
					var userSession models.UserSession
					if err := db.Where("session_id = ? AND user_id = ?", sessionID, userID).First(&userSession).Error; err != nil {
						c.JSON(http.StatusUnauthorized, gin.H{"error": "Session invalid or expired"})
						c.Abort()
						return
					}

					if !userSession.IsActive {
						c.JSON(http.StatusUnauthorized, gin.H{"error": "Session is inactive"})
						c.Abort()
						return
					}

					if time.Since(userSession.LastActivity) > time.Duration(config.SessionInactivityTimeout)*time.Minute {
						userSession.IsActive = false
						db.Save(&userSession)
						c.JSON(http.StatusUnauthorized, gin.H{"error": "Session timed out due to inactivity"})
						c.Abort()
						return
					}

					if time.Since(userSession.LastActivity) > time.Minute {
						db.Model(&userSession).Update("last_activity", time.Now())
					}
				}
			}

			var user models.User
			if err := db.First(&user, userID).Error; err != nil {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
				c.Abort()
				return
			}

			c.Set("user", user)
			c.Next()
		} else {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}
	}
}

func SecurityHeadersMiddleware(config *utils.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		if config.MimeSniffingProtection {
			c.Writer.Header().Set("X-Content-Type-Options", "nosniff")
		}

		if config.ClickjackingProtection {
			c.Writer.Header().Set("X-Frame-Options", "DENY")
		}

		if config.XSSProtection {
			c.Writer.Header().Set("X-XSS-Protection", "1; mode=block")
		}

		if config.ReferrerPolicy != "" {
			c.Writer.Header().Set("Referrer-Policy", config.ReferrerPolicy)
		}

		if config.ContentSecurityPolicy != "" {
			c.Writer.Header().Set("Content-Security-Policy", config.ContentSecurityPolicy)
		}

		if config.PermissionsPolicy != "" {
			c.Writer.Header().Set("Permissions-Policy", config.PermissionsPolicy)
		}

		if config.EncryptionInTransit {
			hstsValue := fmt.Sprintf("max-age=%d", config.HSTSMaxAge)
			if config.HSTSIncludeSubdomains {
				hstsValue += "; includeSubDomains"
			}
			if config.HSTSPreload {
				hstsValue += "; preload"
			}
			c.Writer.Header().Set("Strict-Transport-Security", hstsValue)
		}

		c.Writer.Header().Set("X-Download-Options", "noopen")
		c.Writer.Header().Set("X-Permitted-Cross-Domain-Policies", "none")
		c.Writer.Header().Set("Cross-Origin-Embedder-Policy", "require-corp")
		c.Writer.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
		c.Writer.Header().Set("Cross-Origin-Resource-Policy", "same-origin")
		c.Next()
	}
}

func RateLimitMiddleware(db *gorm.DB, config *utils.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := c.ClientIP()

		Mutex.Lock()
		currentTime := time.Now()
		for ip, blockUntil := range BlockedIPs {
			if currentTime.After(blockUntil) {
				delete(BlockedIPs, ip)
			}
		}
		Mutex.Unlock()

		if blockUntil, ok := BlockedIPs[clientIP]; ok && time.Now().Before(blockUntil) {
			log.Printf("[RATE_LIMIT] IP %s is blocked until %s (attempts in LoginAttempts: %d)", clientIP, blockUntil, len(LoginAttempts[clientIP]))
			Logger.LogEvent(models.SecurityEvent{
				EventType:     "ip_blocked",
				Severity:      "high",
				Details:       fmt.Sprintf("IP %s blocked for %d minutes due to rate limiting", clientIP, config.AccountLockoutDuration),
				UserIP:        clientIP,
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   c.Request.URL.Path,
				RequestMethod: c.Request.Method,
				Timestamp:     time.Now(),
			})
			retryAfter := int(time.Until(blockUntil).Seconds())
			c.Writer.Header().Set("Retry-After", fmt.Sprintf("%d", retryAfter))
			c.JSON(http.StatusTooManyRequests, gin.H{"detail": "Too many requests. Please try again later."})
			c.Abort()
			return
		}

		sensitiveEndpoints := []string{"/register", "/login", "/reset_password", "/delete_account"}
		path := c.Request.URL.Path
		isSensitive := false
		for _, endpoint := range sensitiveEndpoints {
			if strings.Contains(path, endpoint) {
				isSensitive = true
				break
			}
		}

		c.Next()

		if isSensitive {
			status := c.Writer.Status()
			if status == http.StatusUnauthorized || status == http.StatusForbidden {
				Mutex.Lock()
				defer Mutex.Unlock()
				currentTime := time.Now()
				attempts, ok := LoginAttempts[clientIP]
				if !ok {
					attempts = []time.Time{}
				}
				var recentAttempts []time.Time
				for _, t := range attempts {
					if currentTime.Sub(t) < time.Hour {
						recentAttempts = append(recentAttempts, t)
					}
				}
				var veryRecentAttempts []time.Time
				windowDuration := 5 * time.Minute
				for _, t := range recentAttempts {
					if currentTime.Sub(t) < windowDuration {
						veryRecentAttempts = append(veryRecentAttempts, t)
					}
				}
				veryRecentAttempts = append(veryRecentAttempts, currentTime)

				recentAttempts = append(recentAttempts, currentTime)
				LoginAttempts[clientIP] = recentAttempts

				log.Printf("[RATE_LIMIT] Failed attempt from IP %s | Recent (5min): %d | Recent (1hr): %d | Threshold 5min: %d | Threshold 1hr: %d",
					clientIP, len(veryRecentAttempts), len(recentAttempts), config.AccountLockoutThreshold, config.MaxFailedAttemptsPerHour)

				if len(veryRecentAttempts) >= config.AccountLockoutThreshold {
					blockUntil := currentTime.Add(time.Minute * time.Duration(config.AccountLockoutDuration))
					BlockedIPs[clientIP] = blockUntil
					log.Printf("[RATE_LIMIT] IP %s BLOCKED: %d attempts in 5 minutes (threshold: %d)", clientIP, len(veryRecentAttempts), config.AccountLockoutThreshold)
					Logger.LogEvent(models.SecurityEvent{
						EventType:     "ip_blocked",
						Severity:      "high",
						Details:       fmt.Sprintf("IP %s blocked for %d minutes due to %d failed attempts in 5 minutes", clientIP, config.AccountLockoutDuration, len(veryRecentAttempts)),
						UserIP:        clientIP,
						UserAgent:     c.Request.UserAgent(),
						RequestPath:   path,
						RequestMethod: c.Request.Method,
						Timestamp:     time.Now(),
					})
				}

				if len(recentAttempts) >= config.MaxFailedAttemptsPerHour {
					blockUntil := currentTime.Add(time.Minute * time.Duration(config.AccountLockoutDuration))
					BlockedIPs[clientIP] = blockUntil
					log.Printf("[RATE_LIMIT] IP %s BLOCKED: %d attempts in 1 hour (threshold: %d)", clientIP, len(recentAttempts), config.MaxFailedAttemptsPerHour)
					Logger.LogEvent(models.SecurityEvent{
						EventType:     "ip_blocked",
						Severity:      "high",
						Details:       fmt.Sprintf("IP %s blocked for %d minutes due to %d failed attempts per hour", clientIP, config.AccountLockoutDuration, len(recentAttempts)),
						UserIP:        clientIP,
						UserAgent:     c.Request.UserAgent(),
						RequestPath:   path,
						RequestMethod: c.Request.Method,
						Timestamp:     time.Now(),
					})
				}
			}
		}
	}
}

func WAFMiddleware(db *gorm.DB, config *utils.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		var allPatterns []string

		if config.SQLInjectionProtection {
			sqlPatterns := []string{
				`(?i)\b(union|select|insert|update|delete|drop|alter|exec|execute|create|grant|revoke)\b`,
				`(?i)\b(and|or)\s+[\d\w]+\s*=\s*[\d\w]+`,
				`(?i)\b(xp_cmdshell|sp_executesql|xp_)\w+`,
				`(?:--|#|/\*|\*/|;)`,
				`(?i)\binto\s+(outfile|dumpfile)\b`,
				`(?i)\b(load_file|benchmark|sleep|waitfor)\b`,
				`['"]\s*(?:or|and)\s+['"0-9]`,
				`['"]\s*;\s*(?:drop|delete|update|insert)`,
				`(?i)0x[0-9a-f]+`,
				`(?i)char\s*\(`,
			}
			allPatterns = append(allPatterns, sqlPatterns...)
		}

		if config.XSSProtection {
			xssPatterns := []string{
				`(?i)<script[^>]*>.*?</script>`,
				`(?i)javascript:`,
				`(?i)on\w+\s*=`,
				`(?i)<iframe[^>]*>`,
				`(?i)<embed[^>]*>`,
				`(?i)<object[^>]*>`,
			}
			allPatterns = append(allPatterns, xssPatterns...)
		}

		if config.PathTraversalProtection {
			pathPatterns := []string{
				`\.\.[\\/]`,
				`\.\.%2[fF]`,
				`\.\.%5[cC]`,
				`%2e%2e[\\/]`,
				`(?i)\.\.[/\\]`,
			}
			allPatterns = append(allPatterns, pathPatterns...)
		}

		cmdPatterns := []string{
			`(?i)\b(cmd|command|exec|execute|system|shell|bash|sh|powershell|powershell\.exe)\b`,
			`(?i)[;&|]\s*(cat|ls|dir|type|wget|curl)\b`,
		}
		allPatterns = append(allPatterns, cmdPatterns...)

		clientIP := c.ClientIP()
		userAgent := c.Request.UserAgent()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		legitimateEndpoints := []string{"/groups/create", "/create_user", "/api/register", "/api/login", "api/reset_password", "/api/upload_file"}
		isLegitimate := false
		for _, ep := range legitimateEndpoints {
			if path == ep {
				isLegitimate = true
				break
			}
		}
		if isLegitimate {
			c.Next()
			return
		}

		var bodyContent string
		if c.Request.Method == "POST" || c.Request.Method == "PUT" || c.Request.Method == "PATCH" {
			bodyBytes, err := c.GetRawData()
			if err == nil {
				bodyContent = strings.ToLower(string(bodyBytes))
				c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
			}
		}

		combinedContent := strings.ToLower(path + " " + query + " " + bodyContent)

		headersToCheck := []string{
			"User-Agent",
			"Referer",
			"X-Forwarded-For",
			"X-Real-IP",
			"Cookie",
			"X-Requested-With",
			"Origin",
		}

		headerContent := ""
		for _, headerName := range headersToCheck {
			headerValue := c.Request.Header.Get(headerName)
			if headerValue != "" {
				headerContent += strings.ToLower(headerValue) + " "
			}
		}

		combinedContent += " " + headerContent

		for _, pattern := range allPatterns {
			re, err := regexp.Compile(pattern)
			if err != nil {
				log.Printf("[WAF] Failed to compile regex pattern %s: %v", pattern, err)
				continue
			}

			if re.MatchString(combinedContent) {
				Logger.LogEvent(models.SecurityEvent{
					EventType:     "waf_blocked",
					Severity:      "high",
					Details:       fmt.Sprintf("WAF blocked request: pattern '%s' matched in request", pattern),
					UserIP:        clientIP,
					UserAgent:     c.Request.UserAgent(),
					RequestPath:   path,
					RequestMethod: c.Request.Method,
					Timestamp:     time.Now(),
				})
				c.JSON(http.StatusForbidden, gin.H{"error": "Request blocked by security policy"})
				c.Abort()
				return
			}
		}

		suspiciousAgents := []string{"sqlmap", "nikto", "havij", "acunetix", "nmap", "masscan"}
		userAgentLower := strings.ToLower(userAgent)
		for _, suspicious := range suspiciousAgents {
			if strings.Contains(userAgentLower, suspicious) {
				Logger.LogEvent(models.SecurityEvent{
					EventType:     "waf_blocked",
					Severity:      "high",
					Details:       fmt.Sprintf("WAF blocked suspicious user agent: %s", userAgent),
					UserIP:        clientIP,
					UserAgent:     c.Request.UserAgent(),
					RequestPath:   path,
					RequestMethod: c.Request.Method,
					Timestamp:     time.Now(),
				})
				c.JSON(http.StatusForbidden, gin.H{"error": "Request blocked by security policy"})
				c.Abort()
				return
			}
		}
		c.Next()
	}
}

func AccessLogMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		duration := time.Since(start).Milliseconds()
		clientIP := c.ClientIP()
		Logger.LogEvent(models.SecurityEvent{
			EventType:     "access_log",
			Severity:      "high",
			Details:       fmt.Sprintf("ACCESS_LOG: IP=%s Method=%s Path=%s Status=%d Time=%dms UA=%s", clientIP, c.Request.Method, c.Request.URL.Path, c.Writer.Status(), duration, c.Request.UserAgent()),
			UserIP:        clientIP,
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   c.Request.URL.Path,
			RequestMethod: c.Request.Method,
			Timestamp:     time.Now(),
		})
	}
}

func main() {

	log.SetOutput(os.Stdout)
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)
	if _, err := os.Stat("users"); os.IsNotExist(err) {
		err := os.MkdirAll("users", 0755)
		if err != nil {
			log.Printf("Error while creating users folder: %v", err)
			os.Exit(1)
		}
		log.Printf("Folder created successfully")
	} else if err != nil {
		log.Printf("Error while searching folder: %v", err)
		os.Exit(1)
	}

	global.LoadEnv()
	clearRateLimitMaps()

	logsFlag := flag.Bool("logs", false, "Generate logs file. Server not starting")
	versionFlag := flag.String("appversion", "1.0.0", "Saves app version")
	portFlag := flag.Int("port", 0, "Port to run the server on (overrides config.yaml)")
	changeYamlPort := flag.Bool("u", false, "If set, saves port to config.yaml")
	flag.Parse()

	config, err := utils.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load security configuration: %v", err)
	}
	global.SetConfig(config)
	log.Println("Configuration loaded successfully")

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL environment variable not set")
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		PrepareStmt:            true,
		SkipDefaultTransaction: true,
	})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("Failed to get database instance: %v", err)
	}
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)
	sqlDB.SetConnMaxIdleTime(5 * time.Minute)

	log.Println("Successfully connected to PostgreSQL database")

	if *logsFlag {
		if err := generateLogFile(db); err != nil {
			log.Fatalf("Error while creating logs file: %v", err)
		}
		return
	}

	if *versionFlag != "" {
		appVersion := utils.AppVersion{
			Version:    *versionFlag,
			BuildDate:  time.Now().Format("2006-01-02"),
			CommitHash: "N/A",
		}
		data, err := yaml.Marshal(&appVersion)
		if err != nil {
			log.Fatalf("Failed to marshal app version: %v", err)
		}
		if err := os.WriteFile("app_version.yaml", data, 0644); err != nil {
			log.Fatalf("Failed to write app_version.yaml: %v", err)
		}
	}

	if *changeYamlPort {
		config.Port = fmt.Sprintf("%d", *portFlag)
		data, err := yaml.Marshal(&config)
		if err != nil {
			log.Fatalf("Failed to marshal config: %v", err)
		}
		if err := os.WriteFile("config.yaml", data, 0644); err != nil {
			log.Fatalf("Failed to write config.yaml: %v", err)
		}
		log.Printf("Port %d saved to config.yaml successfully", *portFlag)
	}

	portStr := ""
	if *portFlag != 0 {
		portStr = fmt.Sprint(*portFlag)
	} else if config != nil && config.Port != "" {
		portStr = config.Port
	} else {
		portStr = "8000"
	}

	parsedPort, err := strconv.Atoi(portStr)
	if err != nil || parsedPort < 1 || parsedPort > 65535 {
		log.Fatalf("Invalid port value: %s", portStr)
		os.Exit(1)
	}
	port := parsedPort

	err = db.AutoMigrate(
		&models.User{},
		&models.File{},
		&models.Favorite{},
		&models.SharedFile{},
		&models.SharedFolder{},
		&models.EncryptedFile{},
		&models.SecurityEvent{},
		&models.RenameFile{},
		&models.PasswordHistory{},
		&models.UserSession{},
		&models.FileScan{},
		&models.AccessLog{},
		&models.UserGroup{},
		&models.UserGroupMember{},
		&models.GroupSharedFile{},
		&models.GroupSharedFolder{},
		&models.QuickShare{},
		&models.JWTBlacklist{},
	)

	if err != nil {
		log.Fatalf("Failed to auto-migrate to database: %v", err)
	}

	Logger = utils.NewAsyncLogger(db, 10000, 100, 2*time.Second)
	defer Logger.Stop()
	log.Println("AsyncLogger initialized successfully")

	go utils.CleanupExpiredTokens(db)
	log.Println("[SECURITY] JWT blacklist cleanup task started")

	r := gin.Default()
	if config.MaxRequestSize > 0 {
		r.MaxMultipartMemory = int64(config.MaxRequestSize)
	}
	allowedOrigins := os.Getenv("ALLOWED_ORIGINS")
	if allowedOrigins == "" {
		allowedOrigins = "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000"
		log.Println("[SECURITY WARNING] ALLOWED_ORIGINS not set, using default localhost origins")
	}

	r.Use(func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")

		allowed := false
		if origin != "" {
			for _, allowedOrigin := range strings.Split(allowedOrigins, ",") {
				if strings.TrimSpace(allowedOrigin) == origin {
					allowed = true
					break
				}
			}
		}

		if allowed {
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
			c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		}

		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, DELETE, PUT, PATCH")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-API-Key, Content-Disposition")
		c.Writer.Header().Set("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	if config.ClickjackingProtection || config.MimeSniffingProtection || config.XSSProtection || config.EncryptionInTransit {
		r.Use(SecurityHeadersMiddleware(config))
		log.Println("[SECURITY] Security headers middleware enabled")
	}

	if config.RateLimitMaxRequests > 0 {
		r.Use(RateLimitMiddleware(db, config))
		log.Printf("[SECURITY] Rate limiting enabled: %d requests per %d seconds\n", config.RateLimitMaxRequests, config.RateLimitWindow)
	}

	if config.SQLInjectionProtection || config.XSSProtection || config.PathTraversalProtection {
		r.Use(WAFMiddleware(db, config))
		log.Println("[SECURITY] WAF middleware enabled")
	}

	r.Use(AccessLogMiddleware(db))

	api := r.Group("/api")
	api.Use(APIKeyMiddleware())
	{
		api.POST("/register", handlers.RegisterUserEndpoint(db))
		api.POST("/verify", handlers.VerifyEmailEndpoint(db))
		api.POST("/resend_verification", handlers.ResendVerificationEndpoint(db))
		api.POST("/login", handlers.LoginEndpoint(db, Logger))
		api.POST("/reset_password", handlers.ResetPasswordEndpoint(db))
		api.POST("/validate_reset_token", handlers.ValidateResetTokenEndpoint(db))
		api.POST("/confirm_reset_password", handlers.ConfirmResetPasswordEndpoint(db))

		api.POST("/list_files", JWTMiddleware(db, config), handlers.ListFilesEndpoint(db))
		api.POST("/upload_file", JWTMiddleware(db, config), handlers.UploadFileEndpoint(db))
		api.POST("/toggle_favorite", JWTMiddleware(db, config), handlers.AddToFavoriteEndpoint(db))
		api.DELETE("/delete_file", JWTMiddleware(db, config), handlers.DeleteFileEndpoint(db))
		api.GET("/download_file", JWTMiddleware(db, config), handlers.DownloadFileEndpoint(db))
		api.POST("/create_folder", JWTMiddleware(db, config), handlers.CreateFolderEndpoint(db))
		api.POST("/download_folder", JWTMiddleware(db, config), handlers.DownloadFolderEndpoint(db))
		api.POST("/quick_share", JWTMiddleware(db, config), handlers.QuickShareEndpoint(db))
		api.POST("/logout", JWTMiddleware(db, config), handlers.LogoutEndpoint(db))

		api.POST("/check_username", handlers.CheckUsernameAvailabilityEndpoint(db))
		api.GET("/app_version", utils.AppVersionEndpoint())
	}

	r.GET("/quick-share/:token", handlers.GetQuickShareFileEndpoint(db))

	r.GET("health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
	addr := fmt.Sprintf(":%d", port)
	log.Printf("Server starting on port %d...", port)
	if err := r.Run(addr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
