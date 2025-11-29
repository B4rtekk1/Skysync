package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	models "skysync/models_db"
	"skysync/types"
)

func AddToFavoriteEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.AddFavoriteRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "favorite_toggle_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Invalid request: %v", err),
				Username:      "unknown",
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/add_favorite",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		userInterface, exists := c.Get("user")
		if !exists {
			db.Create(&models.SecurityEvent{
				EventType:     "favorite_toggle_failed",
				Severity:      "medium",
				Details:       "User not found in context",
				Username:      "unknown",
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/add_favorite",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		currentUser, ok := userInterface.(models.User)
		if !ok {
			db.Create(&models.SecurityEvent{
				EventType:     "favorite_toggle_failed",
				Severity:      "medium",
				Details:       "Invalid user data",
				Username:      "unknown",
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/add_favorite",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user data"})
			return
		}

		var encryptedFile models.EncryptedFile
		if err := db.Where("user_id = ? AND original_name = ? AND folder = ?", currentUser.ID, req.Filename, req.FolderName).
			First(&encryptedFile).Error; err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "favorite_toggle_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("File not found: %s in folder %s", req.Filename, req.FolderName),
				Username:      currentUser.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/add_favorite",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
			return
		}

		var existingFavorite models.Favorite
		if err := db.Where("user_id = ? AND file_id = ?", currentUser.ID, encryptedFile.ID).
			First(&existingFavorite).Error; err == nil {
			if err := db.Delete(&existingFavorite).Error; err != nil {
				db.Create(&models.SecurityEvent{
					EventType:     "favorite_toggle_failed",
					Severity:      "medium",
					Details:       fmt.Sprintf("Failed to remove file from favorites: %v", err),
					Username:      currentUser.Username,
					Timestamp:     time.Now(),
					UserIP:        c.ClientIP(),
					UserAgent:     c.Request.UserAgent(),
					RequestPath:   "/api/add_favorite",
					RequestMethod: "POST",
				})
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove file from favorites"})
				return
			}

			db.Create(&models.SecurityEvent{
				EventType:     "remove_favorite_success",
				Severity:      "low",
				Details:       fmt.Sprintf("File %s in folder %s removed from favorites (FileID: %d)", req.Filename, req.FolderName, encryptedFile.ID),
				Username:      currentUser.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/add_favorite",
				RequestMethod: "POST",
			})

			c.JSON(http.StatusOK, gin.H{
				"message":  "File removed from favorites successfully",
				"filename": req.Filename,
				"folder":   req.FolderName,
				"file_id":  encryptedFile.ID,
			})
			return
		} else if err != gorm.ErrRecordNotFound {
			db.Create(&models.SecurityEvent{
				EventType:     "favorite_toggle_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Error checking favorite status: %v", err),
				Username:      currentUser.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/add_favorite",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check favorite status"})
			return
		}

		favorite := models.Favorite{
			UserID: currentUser.ID,
			FileID: encryptedFile.ID,
		}

		if err := db.Create(&favorite).Error; err != nil {
			db.Create(&models.SecurityEvent{
				EventType:     "favorite_toggle_failed",
				Severity:      "medium",
				Details:       fmt.Sprintf("Failed to add file to favorites: %v", err),
				Username:      currentUser.Username,
				Timestamp:     time.Now(),
				UserIP:        c.ClientIP(),
				UserAgent:     c.Request.UserAgent(),
				RequestPath:   "/api/add_favorite",
				RequestMethod: "POST",
			})
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add file to favorites"})
			return
		}

		db.Create(&models.SecurityEvent{
			EventType:     "add_favorite_success",
			Severity:      "low",
			Details:       fmt.Sprintf("File %s in folder %s added to favorites (FileID: %d)", req.Filename, req.FolderName, encryptedFile.ID),
			Username:      currentUser.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/api/add_favorite",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{
			"message":  "File added to favorites successfully",
			"filename": req.Filename,
			"folder":   req.FolderName,
			"file_id":  encryptedFile.ID,
		})
	}
}
