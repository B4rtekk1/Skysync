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

type UpdateUsernameRequest struct {
	NewUsername string `json:"new_username" binding:"required"`
	Password    string `json:"password" binding:"required"`
}

func UpdateUsernameEndpoint(db *gorm.DB, logger *utils.AsyncLogger) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req UpdateUsernameRequest
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

		if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
			logger.LogEvent(models.SecurityEvent{
				EventType:     "update_username_failed",
				Severity:      "medium",
				Details:       "Invalid password during username update",
				Username:      user.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   c.Request.URL.Path,
				RequestMethod: c.Request.Method,
			})
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid password"})
			return
		}

		var existingUser models.User
		if err := db.Where("username = ?", req.NewUsername).First(&existingUser).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Username already taken"})
			return
		}

		oldUsername := user.Username
		user.Username = req.NewUsername
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update username"})
			return
		}

		logger.LogEvent(models.SecurityEvent{
			EventType:     "username_updated",
			Severity:      "low",
			Details:       "Username changed from " + oldUsername + " to " + req.NewUsername,
			Username:      req.NewUsername,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   c.Request.URL.Path,
			RequestMethod: c.Request.Method,
		})

		c.JSON(http.StatusOK, gin.H{"message": "Username updated successfully", "username": req.NewUsername})
	}
}
