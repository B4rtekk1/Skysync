package handlers

import (
	"os"

	models "skysync/models_db"
	"skysync/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func DeleteFileEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		var req struct {
			FileID uint `json:"file_id"`
		}
		c.ShouldBindJSON(&req)

		var file models.EncryptedFile
		if err := db.First(&file, req.FileID).Error; err != nil || file.UserID != user.ID {
			c.JSON(404, gin.H{"error": "Not found"})
			return
		}

		physPath := utils.GetPhysicalPath(user.UUID, file.StorageKey)
		os.Remove(physPath)

		db.Delete(&file)
		c.JSON(200, gin.H{"message": "Deleted"})
	}
}
