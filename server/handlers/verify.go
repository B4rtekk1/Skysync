package handlers

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	models "skysync/models_db"
	"skysync/types"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func VerifyEmailEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.VerifyEmailRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		var user models.User
		if err := db.Where("email = ? AND verification_code = ? AND verification_expiry > ? AND verified = 0",
			req.Email, req.VerificationCode, time.Now()).First(&user).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid or expired verification code"})
			return
		}

		user.Verified = 1
		user.VerificationCode = ""
		user.VerificationExpiry = &time.Time{}

		if err := createUserFolder(user.Username); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user folder"})
			return
		}

		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify email"})
			return
		}

		db.Create(&models.SecurityEvent{
			EventType:     "email_verified",
			Severity:      "low",
			Details:       fmt.Sprintf("User %s verified email successfully", user.Username),
			Username:      user.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/verify_email",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{
			"message": "Email verified successfully. User account is now active.",
			"user_id": user.ID,
		})

	}
}

func ResendVerificationEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.ResendVerificationRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		var user models.User
		if err := db.Where("email = ? AND verified = 0", req.Email).First(&user).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "No unverified account found for this email"})
			return
		}

		if user.VerificationExpiry.After(time.Now()) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Verification code is still valid"})
			return
		}

		newCode, err := GenerateVerificationCode()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate verification code"})
			return
		}

		user.VerificationCode = newCode
		expiry := time.Now().Add(15 * time.Minute)
		user.VerificationExpiry = &expiry
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to update verification code"})
			return
		}

		if err := SendVerificationEmail(req.Email, newCode); err != nil {
			log.Printf("Warning: failed to resend verification code to %s: %v", req.Email, err)
		}

		db.Create(&models.SecurityEvent{
			EventType:     "verification_resend",
			Severity:      "low",
			Details:       fmt.Sprintf("Verification code resent to %s", req.Email),
			Username:      user.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/resend_verification",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{"message": "New verification code sent to your email"})
	}
}

func createUserFolder(username string) error {
	folderPath := filepath.Join("users", username)

	if _, err := os.Stat(folderPath); err == nil {
		return nil
	}
	err := os.MkdirAll(folderPath, 0755)
	if err != nil {
		return fmt.Errorf("failed to create user folder %s: %v", folderPath, err)
	}

	log.Printf("Created user folder for %s: %s successfully", username, folderPath)
	return nil
}
