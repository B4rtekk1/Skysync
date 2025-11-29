package handlers

import (
	"fmt"
	"net"
	"net/http"
	"strings"
	"time"

	"crypto/rand"
	"skysync/encryption"
	"skysync/global"
	models "skysync/models_db"
	"skysync/types"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func GenerateVerificationCode() (string, error) {
	code := make([]byte, 6)
	for i := range code {
		b := make([]byte, 1)
		_, err := rand.Read(b)
		if err != nil {
			return "", fmt.Errorf("failed to generate random number: %v", err)
		}
		code[i] = '0' + (b[0] % 10)
	}
	return string(code), nil
}

func isValidEmail(email string) bool {
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return false
	}
	local, domain := parts[0], parts[1]
	if len(local) == 0 || len(domain) == 0 {
		return false
	}
	domainParts := strings.Split(domain, ".")
	if len(domainParts) < 2 {
		return false
	}
	for _, part := range domainParts {
		if len(part) == 0 {
			return false
		}
	}
	return true
}

func CheckEmailDomain(email string) error {
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return fmt.Errorf("invalid email format")
	}
	domain := parts[1]

	mxRecords, err := net.LookupMX(domain)
	if err != nil {
		return fmt.Errorf("failed to find MX records for domain %s: %v", domain, err)
	}
	if len(mxRecords) == 0 {
		return fmt.Errorf("no MX records found for domain %s", domain)
	}

	return nil
}

func RegisterUserEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.RegisterRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Invalid request data: %v", err),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		if !isValidEmail(req.Email) {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Invalid email format: %s", req.Email),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid email format"})
			return
		}

		if err := CheckEmailDomain(req.Email); err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "invalid_email_domain",
				Severity:      "medium",
				Details:       fmt.Sprintf("Attempted registration with invalid email domain: %s, error: %v", req.Email, err),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Invalid email domain: %v", err)})
			return
		}

		var existingUser models.User
		if err := db.Where("username = ? OR email = ?", req.Username, req.Email).First(&existingUser).Error; err == nil {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("User already exists: username=%s, email=%s", req.Username, req.Email),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusBadRequest, gin.H{"error": "User already exists"})
			return
		}

		verificationCode, err := GenerateVerificationCode()
		if err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "high",
				Details:       fmt.Sprintf("Failed to generate verification code: %v", err),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate verification code"})
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "high",
				Details:       fmt.Sprintf("Failed to hash password: %v", err),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
			return
		}

		globalKey := global.ENCRYPTION_KEY
		if globalKey == "" {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "high",
				Details:       "ENCRYPTION_KEY not set in environment",
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Server configuration error"})
			return
		}

		encryptedKey, salt, err := encryption.GenerateUserEncryptionKey(globalKey)
		if err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "high",
				Details:       fmt.Sprintf("Failed to generate encryption key: %v", err),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to generate encryption key: %v", err)})
			return
		}

		expiry := time.Now().Add(15 * time.Minute)
		user := models.User{
			Username:           req.Username,
			Email:              req.Email,
			PasswordHash:       string(hashedPassword),
			EncryptionKey:      encryptedKey,
			EncryptionKeySalt:  salt,
			VerificationCode:   verificationCode,
			VerificationExpiry: &expiry,
			IsActive:           true,
			CreatedAt:          time.Now(),
			Verified:           0,
		}
		if err := db.Create(&user).Error; err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "register_failed",
				Severity:      "high",
				Details:       fmt.Sprintf("Failed to create user in database: %v", err),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}

		if err := SendVerificationEmail(req.Email, verificationCode); err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "email_sending_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Failed to send verification email to %s: %v", req.Email, err),
				Username:      req.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/register",
				RequestMethod: "POST",
			})
		}

		db.Create(&models.SecurityEvent{
			EventType:     "user_registered",
			Severity:      "low",
			Details:       fmt.Sprintf("User %s registered successfully", req.Username),
			Username:      req.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/api/register",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusCreated, gin.H{
			"message": "User registered successfully. Please check your email for verification code.",
			"user_id": user.ID,
		})
	}
}
