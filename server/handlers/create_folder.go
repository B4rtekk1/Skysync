package handlers

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"skysync/global"
	models "skysync/models_db"
	"skysync/types"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func CreateFolderEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.CreateFolderRequest

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		userInterface, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}
		user := userInterface.(models.User)

		cleanFolder := filepath.Clean(req.FolderName)
		if strings.Contains(cleanFolder, "..") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid folder path"})
			return
		}

		if cleanFolder == "." || cleanFolder == "/" || cleanFolder == "\\" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid folder name"})
			return
		}

		config := global.GetConfig()
		if cleanFolder != "." && cleanFolder != "/" {
			parts := strings.Split(cleanFolder, string(os.PathSeparator))
			if len(parts) > config.MaxFolderDepth {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Folder depth limit exceeded"})
				return
			}
		}

		// Ensure the path is relative by trimming leading separators
		relFolder := strings.TrimLeft(cleanFolder, string(os.PathSeparator))
		relFolder = strings.TrimLeft(relFolder, "/")
		relFolder = strings.TrimLeft(relFolder, "\\")

		folderPath := filepath.Join("users", user.UUID, relFolder)

		if _, err := os.Stat(folderPath); !os.IsNotExist(err) {
			c.JSON(http.StatusConflict, gin.H{"error": "Folder already exists"})
			return
		}

		err := os.MkdirAll(folderPath, 0755)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create folder in filesystem"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Folder created successfully"})

	}
}
