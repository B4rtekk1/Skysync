package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"net/http"
	"time"

	"skysync/global"
	models "skysync/models_db"

	"github.com/gin-gonic/gin"
	"github.com/skip2/go-qrcode"
	"gorm.io/gorm"
)

func generateToken() string {
	b := make([]byte, 32)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)
}

func QuickShareEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		var req struct {
			FileID uint `json:"file_id"`
		}
		c.ShouldBindJSON(&req)

		var file models.EncryptedFile
		if db.First(&file, req.FileID).Error != nil || file.UserID != user.ID {
			c.JSON(404, gin.H{"error": "File not found"})
			return
		}

		token := generateToken()
		share := models.QuickShare{
			FileID:      file.ID,
			ShareToken:  token,
			CreatedByID: user.ID,
			ExpiresAt:   time.Now().Add(7 * 24 * time.Hour),
			IsActive:    true,
		}
		db.Create(&share)

		url := fmt.Sprintf("%s/quick-share/%s", global.BASE_URL, token)
		qr, _ := qrcode.Encode(url, qrcode.Medium, 256)

		c.JSON(http.StatusOK, gin.H{
			"share_url": url,
			"qr_code":   base64.StdEncoding.EncodeToString(qr),
		})
	}
}
