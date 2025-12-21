package handlers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	models "skysync/models_db"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

func UploadAvatarEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userInterface, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found in context"})
			return
		}
		user := userInterface.(models.User)

		contentType := c.Request.Header.Get("Content-Type")
		fmt.Printf("[AVATAR] Upload attempt by user %s, Content-Type: %s\n", user.Username, contentType)

		file, header, err := c.Request.FormFile("avatar")
		if err != nil {
			fmt.Printf("[AVATAR] FormFile error: %v\n", err)
			c.JSON(http.StatusBadRequest, gin.H{"error": "No avatar file provided: " + err.Error()})
			return
		}
		defer file.Close()

		fileContentType := header.Header.Get("Content-Type")
		if !strings.HasPrefix(fileContentType, "image/") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "File must be an image"})
			return
		}

		if header.Size > 5*1024*1024 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Avatar file too large (max 5MB)"})
			return
		}

		avatarsDir := "avatars"
		if err := os.MkdirAll(avatarsDir, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create avatars directory"})
			return
		}

		if user.AvatarPath != "" {
			oldPath := filepath.Join(avatarsDir, filepath.Base(user.AvatarPath))
			os.Remove(oldPath)
		}
		ext := filepath.Ext(header.Filename)
		if ext == "" {
			switch fileContentType {
			case "image/jpeg":
				ext = ".jpg"
			case "image/png":
				ext = ".png"
			case "image/gif":
				ext = ".gif"
			case "image/webp":
				ext = ".webp"
			default:
				ext = ".jpg"
			}
		}
		filename := fmt.Sprintf("%s_%s%s", user.UUID, uuid.New().String()[:8], ext)
		avatarPath := filepath.Join(avatarsDir, filename)

		out, err := os.Create(avatarPath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save avatar"})
			return
		}
		defer out.Close()

		_, err = io.Copy(out, file)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to write avatar file"})
			return
		}

		user.AvatarPath = filename
		if err := db.Save(&user).Error; err != nil {
			os.Remove(avatarPath)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user avatar"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":     "Avatar uploaded successfully",
			"avatar_path": filename,
		})
	}
}

func GetAvatarEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		username := c.Param("username")
		if username == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Username required"})
			return
		}

		var user models.User
		if err := db.Where("username = ?", username).First(&user).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		if user.AvatarPath == "" {
			c.JSON(http.StatusNotFound, gin.H{"error": "No avatar set"})
			return
		}

		avatarPath := filepath.Join("avatars", user.AvatarPath)
		if _, err := os.Stat(avatarPath); os.IsNotExist(err) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Avatar file not found"})
			return
		}

		c.File(avatarPath)
	}
}

func DeleteAvatarEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userInterface, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found in context"})
			return
		}
		user := userInterface.(models.User)

		if user.AvatarPath == "" {
			c.JSON(http.StatusOK, gin.H{"message": "No avatar to delete"})
			return
		}

		avatarPath := filepath.Join("avatars", user.AvatarPath)
		os.Remove(avatarPath)

		user.AvatarPath = ""
		if err := db.Save(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Avatar deleted successfully"})
	}
}
