package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	models "skysync/models_db"
	"skysync/types"
)

func ListFilesEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.ListFilesRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		userInterface, exists := c.Get("user")
		if !exists {
			fmt.Println("ListFilesEndpoint: User not found in context")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		currentUser := userInterface.(models.User)

		folderName := req.FolderName
		if folderName == "" {
			folderName = "/"
		}

		var encryptedFiles []models.EncryptedFile
		if err := db.Where("user_id = ? AND folder = ? AND is_deleted = ?", currentUser.ID, folderName, false).Find(&encryptedFiles).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error fetching files"})
			return
		}

		var favorites []models.Favorite
		db.Where("user_id = ?", currentUser.ID).Find(&favorites)
		favoriteMap := make(map[uint]bool)
		for _, fav := range favorites {
			favoriteMap[fav.FileID] = true
		}

		var fileList []map[string]interface{}

		for _, file := range encryptedFiles {
			isFavorite := favoriteMap[file.ID]
			fileMap := map[string]interface{}{
				"id":            file.ID,
				"name":          file.OriginalName,
				"size":          file.FileSize,
				"mime_type":     file.MimeType,
				"last_modified": file.UploadTime.Format(time.RFC3339),
				"is_favorite":   isFavorite,
				"file_count":    0,
				"folder_count":  0,
				"total_size":    0,
			}
			fileList = append(fileList, fileMap)
		}

		addedFolders := make(map[string]bool)

		cleanFolder := req.FolderName
		cleanFolder = filepath.Clean(cleanFolder)
		if strings.Contains(cleanFolder, "..") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid folder path"})
			return
		}

		physicalPath := filepath.Join("users", currentUser.UUID, cleanFolder)

		if info, err := os.Stat(physicalPath); err == nil && info.IsDir() {
			entries, err := os.ReadDir(physicalPath)
			if err == nil {
				for _, entry := range entries {
					if entry.IsDir() {
						name := entry.Name()
						if addedFolders[name] {
							continue
						}
						folderMap := map[string]interface{}{
							"name":          name,
							"size":          0,
							"mime_type":     "folder",
							"last_modified": time.Now().Format(time.RFC3339),
							"is_favorite":   false,
							"file_count":    0,
							"folder_count":  0,
							"total_size":    0,
						}
						if info, err := entry.Info(); err == nil {
							folderMap["last_modified"] = info.ModTime().Format(time.RFC3339)
						}
						fileList = append(fileList, folderMap)
						addedFolders[name] = true
					}
				}
			}
		}

		var allFolders []string
		prefix := folderName
		if !strings.HasSuffix(prefix, "/") {
			prefix += "/"
		}
		db.Model(&models.EncryptedFile{}).
			Where("user_id = ? AND folder LIKE ? AND is_deleted = ?", currentUser.ID, prefix+"%", false).
			Distinct("folder").
			Pluck("folder", &allFolders)

		for _, f := range allFolders {
			if len(f) > len(prefix) {
				rel := f[len(prefix):]
				parts := strings.Split(rel, "/")
				if len(parts) > 0 && parts[0] != "" {
					name := parts[0]
					if !addedFolders[name] {
						folderMap := map[string]interface{}{
							"name":          name,
							"size":          0,
							"mime_type":     "folder",
							"last_modified": time.Now().Format(time.RFC3339),
							"is_favorite":   false,
							"file_count":    0,
							"folder_count":  0,
							"total_size":    0,
						}
						fileList = append(fileList, folderMap)
						addedFolders[name] = true
					}
				}
			}
		}

		type FolderStat struct {
			Size        int64
			FileCount   int
			SeenFolders map[string]bool
		}
		folderStats := make(map[string]*FolderStat)

		var allRecursiveFiles []models.EncryptedFile
		if err := db.Select("folder, file_size").Where("user_id = ? AND folder LIKE ? AND is_deleted = ?", currentUser.ID, prefix+"%", false).Find(&allRecursiveFiles).Error; err == nil {
			for _, f := range allRecursiveFiles {
				if len(f.Folder) <= len(prefix) {
					continue
				}

				rel := f.Folder[len(prefix):]
				parts := strings.Split(rel, "/")
				if len(parts) > 0 && parts[0] != "" {
					immediateName := parts[0]

					if _, ok := folderStats[immediateName]; !ok {
						folderStats[immediateName] = &FolderStat{SeenFolders: make(map[string]bool)}
					}

					stat := folderStats[immediateName]
					stat.Size += f.FileSize
					stat.FileCount++
					stat.SeenFolders[f.Folder] = true
				}
			}
		}

		for i, item := range fileList {
			if item["mime_type"] == "folder" {
				name := item["name"].(string)
				if stat, ok := folderStats[name]; ok {
					fileList[i]["total_size"] = stat.Size
					fileList[i]["file_count"] = stat.FileCount

					basePath := prefix + name
					subFolderCount := 0
					for seenFolder := range stat.SeenFolders {
						if len(seenFolder) > len(basePath) {
							subFolderCount++
						}

						if len(seenFolder) > len(basePath) {
							subFolderCount++
						}
					}
					fileList[i]["folder_count"] = subFolderCount
				}
			}
		}

		if fileList == nil {
			fileList = []map[string]interface{}{}
		}

		c.JSON(http.StatusOK, gin.H{"files": fileList})
	}
}
