package handlers

import (
	"fmt"
	"net/http"
	"os"
	"time"

	"skysync/encryption"
	"skysync/global"
	models "skysync/models_db"
	"skysync/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func GetQuickShareFileEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.Param("token")
		var share models.QuickShare
		if err := db.Where("share_token = ? AND is_active = ?", token, true).First(&share).Error; err != nil {
			c.JSON(404, gin.H{"error": "Link not found or expired"})
			return
		}

		if time.Now().After(share.ExpiresAt) {
			share.IsActive = false
			db.Save(&share)
			c.JSON(410, gin.H{"error": "Link expired"})
			return
		}

		var file models.EncryptedFile
		db.First(&file, share.FileID)

		var owner models.User
		db.First(&owner, share.CreatedByID)

		physPath := utils.GetPhysicalPath(owner.UUID, file.StorageKey)
		encryptedFile, err := os.Open(physPath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "File access error"})
			return
		}
		defer encryptedFile.Close()

		userKey, _ := encryption.DecryptUserEncryptionKey(owner.EncryptionKey, global.ENCRYPTION_KEY, owner.EncryptionKeySalt)

		share.Downloads++
		db.Save(&share)

		c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, file.OriginalName))
		c.Header("Content-Type", file.MimeType)
		c.Status(200)

		encryption.DecryptStream(encryptedFile, c.Writer, userKey)
	}
}
