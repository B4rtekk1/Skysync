package handlers

import (
	"net/http"
	"os"

	"skysync/encryption"
	"skysync/global"
	models "skysync/models_db"
	"skysync/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func DownloadFileEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		fileID := c.Query("file_id")

		var file models.EncryptedFile
		if err := db.First(&file, fileID).Error; err != nil || file.UserID != user.ID {
			c.JSON(404, gin.H{"error": "File not found"})
			return
		}

		physPath := utils.GetPhysicalPath(user.UUID, file.StorageKey)
		encryptedFile, err := os.Open(physPath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "File access error"})
			return
		}
		defer encryptedFile.Close()

		userKey, _ := encryption.DecryptUserEncryptionKey(user.EncryptionKey, global.ENCRYPTION_KEY, user.EncryptionKeySalt)

		c.Header("Content-Disposition", `attachment; filename="`+file.OriginalName+`"`)
		c.Header("Content-Type", file.MimeType)
		c.Status(200)

		encryption.DecryptStream(encryptedFile, c.Writer, userKey)
	}
}
