package handlers

import (
	"fmt"
	"net/http"
	"time"

	"skysync/global"
	models "skysync/models_db"
	"skysync/types"
	"skysync/utils"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func LoginEndpoint(db *gorm.DB, logger *utils.AsyncLogger) gin.HandlerFunc {
	jwtSecret := global.SECRET_KEY
	if jwtSecret == "" {
		panic("JWT secret not configured")
	}

	sessionTimeout := 24 * time.Hour
	if global.AppConfig != nil && global.AppConfig.SessionTimeoutMinutes > 0 {
		sessionTimeout = time.Duration(global.AppConfig.SessionTimeoutMinutes) * time.Minute
	}

	return func(c *gin.Context) {
		var req types.LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Invalid request"})
			return
		}

		var user models.User
		dummyHash := "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy"

		if err := db.Where("username = ? OR email = ?", req.Username, req.Username).First(&user).Error; err != nil {
			bcrypt.CompareHashAndPassword([]byte(dummyHash), []byte(req.Password))

			logger.LogEvent(models.SecurityEvent{
				EventType:     "login_failed",
				Severity:      "medium",
				Details:       "Failed login attempt: invalid credentials",
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/login",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
			return
		}

		passwordValid := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) == nil

		if !passwordValid {
			logger.LogEvent(models.SecurityEvent{
				EventType:     "login_failed",
				Severity:      "medium",
				Details:       "Invalid password attempt",
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/login",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
			return
		}

		if user.Verified == 0 {
			logger.LogEvent(models.SecurityEvent{
				EventType:     "login_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Login attempt for unverified account: %s", req.Username),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/login",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusForbidden, gin.H{"detail": "Email not verified"})
			return
		}

		if !user.IsActive {
			logger.LogEvent(models.SecurityEvent{
				EventType:     "login_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Login attempt for inactive account: %s", req.Username),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/login",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusForbidden, gin.H{"detail": "Account is not active"})
			return
		}

		sessionID := uuid.New().String()

		if global.AppConfig != nil && global.AppConfig.MaxConcurrentSessions > 0 {
			var activeSessionsCount int64
			db.Model(&models.UserSession{}).Where("user_id = ? AND is_active = ?", user.ID, true).Count(&activeSessionsCount)

			if activeSessionsCount >= int64(global.AppConfig.MaxConcurrentSessions) {
				limit := activeSessionsCount - int64(global.AppConfig.MaxConcurrentSessions) + 1
				if limit > 0 {
					var sessionsToRemove []models.UserSession
					db.Where("user_id = ? AND is_active = ?", user.ID, true).Order("created_at asc").Limit(int(limit)).Find(&sessionsToRemove)
					for _, s := range sessionsToRemove {
						db.Model(&s).Update("is_active", false)
					}
				}
			}
		}

		userSession := models.UserSession{
			UserID:       user.ID,
			SessionID:    sessionID,
			TokenHash:    "",
			IPAddress:    c.ClientIP(),
			UserAgent:    c.Request.UserAgent(),
			ExpiresAt:    time.Now().Add(sessionTimeout),
			IsActive:     true,
			LastActivity: time.Now(),
		}
		if err := db.Create(&userSession).Error; err != nil {
			logger.LogEvent(models.SecurityEvent{
				EventType:     "login_error",
				Severity:      "high",
				Details:       fmt.Sprintf("Failed to create session for user: %s", req.Username),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/login",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"detail": "Failed to create session"})
			return
		}

		claims := jwt.MapClaims{
			"jti":        sessionID,
			"user_id":    user.ID,
			"username":   user.Username,
			"email":      user.Email,
			"session_id": sessionID,
			"exp":        time.Now().Add(sessionTimeout).Unix(),
			"iat":        time.Now().Unix(),
			"nbf":        time.Now().Unix(),
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": "Failed to generate JWT token"})
			return
		}

		logger.LogEvent(models.SecurityEvent{
			EventType:     "login_success",
			Severity:      "low",
			Details:       "User logged in successfully",
			Username:      req.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/login",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{
			"token":    tokenString,
			"username": user.Username,
			"email":    user.Email,
		})
	}
}
