package handlers

import (
	models "skysync/models_db"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RenameFileEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		var req struct {
			FileID    uint   `json:"file_id"`
			NewName   string `json:"new_name"`
			NewFolder string `json:"new_folder,omitempty"`
		}
		c.ShouldBindJSON(&req)

		var file models.EncryptedFile
		if err := db.First(&file, req.FileID).Error; err != nil || file.UserID != user.ID {
			c.JSON(404, gin.H{"error": "Not found"})
			return
		}

		updates := map[string]interface{}{
			"original_name": req.NewName,
		}
		if req.NewFolder != "" {
			updates["folder"] = req.NewFolder
		}

		db.Model(&file).Updates(updates)
		c.JSON(200, gin.H{"message": "Renamed"})
	}
}
