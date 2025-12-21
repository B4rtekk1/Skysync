package handlers

import (
	"net/http"
	models "skysync/models_db"
	"skysync/utils"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required"`
}

func ChangePasswordEndpoint(db *gorm.DB, logger *utils.AsyncLogger) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req ChangePasswordRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		userInterface, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found in context"})
			return
		}
		user := userInterface.(models.User)

		if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.CurrentPassword)); err != nil {
			logger.LogEvent(models.SecurityEvent{
				EventType:     "change_password_failed",
				Severity:      "medium",
				Details:       "Invalid current password during password change",
				Username:      user.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   c.Request.URL.Path,
				RequestMethod: c.Request.Method,
			})
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Current password is incorrect"})
			return
		}

		if len(req.NewPassword) < 8 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "New password must be at least 8 characters"})
			return
		}
		if req.CurrentPassword == req.NewPassword {
			c.JSON(http.StatusBadRequest, gin.H{"error": "New password must be different from current password"})
			return
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
			return
		}

		user.PasswordHash = string(hashedPassword)
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update password"})
			return
		}

		passwordHistory := models.PasswordHistory{
			UserID:       user.ID,
			PasswordHash: string(hashedPassword),
		}
		db.Create(&passwordHistory)

		logger.LogEvent(models.SecurityEvent{
			EventType:     "password_changed",
			Severity:      "low",
			Details:       "Password changed successfully",
			Username:      user.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   c.Request.URL.Path,
			RequestMethod: c.Request.Method,
		})

		c.JSON(http.StatusOK, gin.H{"message": "Password changed successfully"})
	}
}
