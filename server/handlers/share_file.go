package handlers

import (
	"net/http"
	models "skysync/models_db"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func ShareFileWithUserEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		var req struct {
			FileID   uint   `json:"file_id" binding:"required"`
			Username string `json:"username"`
			Email    string `json:"email"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var file models.EncryptedFile
		if err := db.Where("id = ? AND user_id = ?", req.FileID, user.ID).First(&file).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "File not found or you don't have permission"})
			return
		}

		var targetUser models.User
		var err error

		if req.Email != "" {
			err = db.Where("email = ?", req.Email).First(&targetUser).Error
		} else if req.Username != "" {
			err = db.Where("username = ?", req.Username).First(&targetUser).Error
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email or Username is required"})
			return
		}

		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		if targetUser.ID == user.ID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot share file with yourself"})
			return
		}

		var existingShare models.SharedFile
		if err := db.Where("original_file_id = ? AND shared_with_user_id = ?", file.ID, targetUser.ID).First(&existingShare).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "File already shared with this user"})
			return
		}

		share := models.SharedFile{
			OriginalFileID:   file.ID,
			SharedWithUserID: targetUser.ID,
			SharedByUserID:   user.ID,
		}

		if err := db.Create(&share).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to share file"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "File shared successfully"})
	}
}
