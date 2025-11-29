package handlers

import (
	"archive/zip"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"skysync/encryption"
	"skysync/global"
	models "skysync/models_db"
	"skysync/types"
	"skysync/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func DownloadFolderEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userInterface, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}
		user := userInterface.(models.User)

		var req types.DownloadFolderRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		cleanFolder := filepath.Clean(req.FolderName)
		if strings.Contains(cleanFolder, "..") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid folder path"})
			return
		}

		searchFolder := cleanFolder
		if !strings.HasPrefix(searchFolder, "/") && searchFolder != "/" {
			searchFolder = "/" + searchFolder
		}
		searchFolder = strings.ReplaceAll(searchFolder, "\\", "/")

		var files []models.EncryptedFile
		query := db.Where("user_id = ? AND is_deleted = ?", user.ID, false)

		if searchFolder == "/" || searchFolder == "." {
		} else {
			query = query.Where("folder = ? OR folder LIKE ?", searchFolder, searchFolder+"/%")
		}

		if err := query.Find(&files).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		if len(files) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Folder is empty or does not exist"})
			return
		}

		userKey, err := encryption.DecryptUserEncryptionKey(user.EncryptionKey, global.ENCRYPTION_KEY, user.EncryptionKeySalt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Key decryption error"})
			return
		}

		zipName := filepath.Base(searchFolder)
		if zipName == "/" || zipName == "." || zipName == "\\" {
			zipName = "root"
		}
		zipName += ".zip"

		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", zipName))
		c.Header("Content-Type", "application/zip")
		c.Status(http.StatusOK)

		zw := zip.NewWriter(c.Writer)
		defer zw.Close()

		for _, file := range files {

			relPath := file.Folder
			relPath = strings.TrimPrefix(relPath, "/")

			var zipEntryPath string
			if searchFolder == "/" || searchFolder == "." {
				zipEntryPath = filepath.Join(relPath, file.OriginalName)
			} else {
				parent := filepath.Dir(searchFolder)
				parent = strings.ReplaceAll(parent, "\\", "/")
				if parent == "." {
					parent = ""
				}

				prefixToRemove := filepath.Dir(searchFolder)
				prefixToRemove = strings.ReplaceAll(prefixToRemove, "\\", "/")
				if prefixToRemove == "/" || prefixToRemove == "." {
					prefixToRemove = ""
				}

				rel, err := filepath.Rel(searchFolder, file.Folder)
				if err != nil {
					zipEntryPath = filepath.Join(file.Folder, file.OriginalName)
				} else {
					if rel == "." {
						rel = ""
					}
					zipEntryPath = filepath.Join(filepath.Base(searchFolder), rel, file.OriginalName)
				}
			}

			zipEntryPath = strings.ReplaceAll(zipEntryPath, "\\", "/")

			physPath := utils.GetPhysicalPath(user.UUID, file.StorageKey)

			f, err := os.Open(physPath)
			if err != nil {
				log.Printf("Failed to open file %s: %v", physPath, err)
				continue
			}

			header := &zip.FileHeader{
				Name:     zipEntryPath,
				Method:   zip.Deflate,
				Modified: file.UploadTime,
			}

			writer, err := zw.CreateHeader(header)
			if err != nil {
				f.Close()
				log.Printf("Failed to create zip entry %s: %v", zipEntryPath, err)
				continue
			}

			err = encryption.DecryptStream(f, writer, userKey)
			f.Close()
			if err != nil {
				log.Printf("Failed to decrypt file %s: %v", file.OriginalName, err)
				continue
			}
		}
	}
}
