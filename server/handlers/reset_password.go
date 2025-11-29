package handlers

import (
	"encoding/binary"
	"fmt"
	"net/http"
	"regexp"
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

func GenerateResetToken() (string, error) {
	var n uint64
	if err := binary.Read(rand.Reader, binary.BigEndian, &n); err != nil {
		return "", fmt.Errorf("failed to generate reset token: %v", err)
	}

	return fmt.Sprintf("%08d", n%100_000_000), nil
}

func hasRepeatedChars(password string) bool {
	if len(password) < 3 {
		return false
	}
	for i := 0; i < len(password)-2; i++ {
		if password[i] == password[i+1] && password[i+1] == password[i+2] {
			return true
		}
	}
	return false
}

func ResetPasswordEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.ResetPasswordRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Invalid request"})
			return
		}

		var user models.User
		userExists := db.Where("email = ?", req.Email).First(&user).Error == nil

		if !userExists {
			db.Create(&models.SecurityEvent{
				EventType:     "password_reset_attempt_invalid_email",
				Severity:      "medium",
				Details:       fmt.Sprintf("%s tried to reset password for non-existent email: %s", c.ClientIP(), req.Email),
				Username:      req.Email,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/reset_password",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusOK, gin.H{"detail": "If the email exists, a reset token has been sent"})
			return
		}

		if user.Verified == 0 {
			db.Create(&models.SecurityEvent{
				EventType:     "reset_password_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Reset password attempt for unverified user: %s", req.Email),
				Username:      req.Email,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/reset_password",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusForbidden, gin.H{"detail": "Email not verified"})
			return
		}

		resetToken, err := GenerateResetToken()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": "Failed to generate reset token"})
			return
		}

		user.ResetToken = resetToken
		expiry := time.Now().Add(15 * time.Minute)
		user.ResetTokenExpiry = &expiry
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": "Failed to save reset token"})
			return
		}

		if err := SendPasswordResetEmail(req.Email, resetToken); err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "password_reset_email_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Failed to send password reset email to %s: %v", req.Email, err),
				Username:      user.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/reset_password",
				RequestMethod: "POST",
			})
		}

		db.Create(&models.SecurityEvent{
			EventType:     "password_reset_initiated",
			Severity:      "low",
			Details:       fmt.Sprintf("Password reset initiated for user: %s", user.Username),
			Username:      user.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/reset_password",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{"detail": "Password reset token sent successfully"})
	}
}

func ValidateResetTokenEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.ValidateResetTokenEndpoint
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Invalid request"})
			return
		}

		var user models.User
		if err := db.Where("reset_token = ? AND reset_token_expiry > ?", req.ResetToken, time.Now()).First(&user).Error; err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "reset_token_validation_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Invalid or expired reset token: %s", req.ResetToken),
				Username:      "unknown",
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/validate_reset_token",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusOK, gin.H{"valid": false})
			return
		}

		db.Create(&models.SecurityEvent{
			EventType:     "reset_token_validation_success",
			Severity:      "low",
			Details:       fmt.Sprintf("Reset token validated for user: %s", user.Username),
			Username:      user.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/validate_reset_token",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{"valid": true})
	}
}

func ConfirmResetPasswordEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.ConfirmResetPasswordRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Invalid request"})
			return
		}

		var user models.User
		if err := db.Where("reset_token = ? AND reset_token_expiry > ? AND email = ?", req.Code, time.Now(), req.Email).First(&user).Error; err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "password_reset_confirm_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Invalid or expired reset token: %s", req.Code),
				Username:      "unknown",
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/confirm_reset_password",
				RequestMethod: "POST",
			})
		}

		if len(req.NewPassword) < 12 || len(req.NewPassword) > 128 {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must be between 12 and 128 characters"})
			return
		}
		if !regexp.MustCompile(`[A-Z]`).MatchString(req.NewPassword) {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must contain at least one uppercase letter"})
			return
		}
		if !regexp.MustCompile(`[a-z]`).MatchString(req.NewPassword) {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must contain at least one lowercase letter"})
			return
		}
		if !regexp.MustCompile(`[0-9]`).MatchString(req.NewPassword) {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must contain at least one number"})
			return
		}
		if !regexp.MustCompile(`[!@#\$%^&*(),.?":{}|<>_\-+=~]`).MatchString(req.NewPassword) {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must contain at least one special character"})
			return
		}
		if hasRepeatedChars(req.NewPassword) {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must not contain a character repeated three or more times consecutively"})
			return
		}

		patterns := []string{"abc", "bcd", "cde", "def", "efg", "fgh", "ghi", "hij", "ijk", "jkl", "klm", "lmn", "mno", "nop", "opq", "pqr", "qrs", "rst", "stu", "tuv", "uvw", "vwx", "wxy", "xyz", "123", "234", "345", "456", "567", "678", "789", "012"}
		commonWords := []string{"password", "admin", "user", "test", "guest", "qwerty", "asdfgh", "zxcvbn", "123456", "654321"}
		lowerPassword := strings.ToLower(req.NewPassword)
		for _, pattern := range patterns {
			if strings.Contains(lowerPassword, pattern) {
				c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must not contain sequential patterns"})
				return
			}
		}
		for _, word := range commonWords {
			if strings.Contains(lowerPassword, word) {
				c.JSON(http.StatusBadRequest, gin.H{"detail": "Password must not contain common words"})
				return
			}
		}

		config := global.GetConfig()
		if config.PasswordHistorySize > 0 {
			var passwordHistory []models.PasswordHistory
			db.Where("user_id = ?", user.ID).Order("created_at desc").Limit(config.PasswordHistorySize).Find(&passwordHistory)

			for _, ph := range passwordHistory {
				if err := bcrypt.CompareHashAndPassword([]byte(ph.PasswordHash), []byte(req.NewPassword)); err == nil {
					c.JSON(http.StatusBadRequest, gin.H{"detail": "Password has been used recently"})
					return
				}
			}
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": "Failed to hash new password"})
			return
		}

		encryptedKey, salt, err := encryption.GenerateUserEncryptionKey(req.NewPassword)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": fmt.Sprintf("Failed to generate encryption key: %v", err)})
			return
		}

		user.PasswordHash = string(hashedPassword)
		user.EncryptionKey = encryptedKey
		user.EncryptionKeySalt = salt
		user.ResetToken = ""
		user.ResetTokenExpiry = &time.Time{}
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": "Failed to update password"})
			return
		}

		db.Create(&models.PasswordHistory{
			UserID:       user.ID,
			PasswordHash: string(hashedPassword),
			CreatedAt:    time.Now(),
		})

		if config.PasswordHistorySize > 0 {
			var count int64
			db.Model(&models.PasswordHistory{}).Where("user_id = ?", user.ID).Count(&count)
			if count > int64(config.PasswordHistorySize) {
				limit := count - int64(config.PasswordHistorySize)
				var toDelete []models.PasswordHistory
				db.Where("user_id = ?", user.ID).Order("created_at asc").Limit(int(limit)).Find(&toDelete)
				for _, ph := range toDelete {
					db.Delete(&ph)
				}
			}
		}

		db.Create(&models.SecurityEvent{
			EventType:     "password_reset_success",
			Severity:      "low",
			Details:       fmt.Sprintf("Password reset successful for user: %s", user.Username),
			Username:      user.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/confirm_reset_password",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{
			"detail": "Password reset successfully",
		})
	}
}
