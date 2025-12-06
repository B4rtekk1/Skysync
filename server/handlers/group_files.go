package handlers

import (
	"net/http"
	models "skysync/models_db"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func ShareFileWithGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var req struct {
			GroupID uint `json:"group_id" binding:"required"`
			FileID  uint `json:"file_id" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, user.ID).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
			return
		}

		var file models.EncryptedFile
		if err := db.Where("id = ? AND user_id = ?", req.FileID, user.ID).First(&file).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "File not found or you don't have permission"})
			return
		}

		var existing models.GroupSharedFile
		if err := db.Where("original_file_id = ? AND shared_with_group_id = ?", req.FileID, req.GroupID).First(&existing).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "File is already shared with this group"})
			return
		}

		sharedFile := models.GroupSharedFile{
			OriginalFileID:    req.FileID,
			SharedWithGroupID: req.GroupID,
			SharedByUserID:    user.ID,
			CreatedAt:         time.Now(),
		}

		if err := db.Create(&sharedFile).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to share file"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "File shared successfully"})
	}
}

func ShareFolderWithGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var req struct {
			GroupID    uint   `json:"group_id" binding:"required"`
			FolderPath string `json:"folder_path" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, user.ID).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
			return
		}

		var existing models.GroupSharedFolder
		if err := db.Where("folder_path = ? AND shared_with_group_id = ?", req.FolderPath, req.GroupID).First(&existing).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Folder is already shared with this group"})
			return
		}

		sharedFolder := models.GroupSharedFolder{
			FolderPath:        req.FolderPath,
			SharedWithGroupID: req.GroupID,
			SharedByUserID:    user.ID,
			CreatedAt:         time.Now(),
		}

		if err := db.Create(&sharedFolder).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to share folder"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Folder shared successfully"})
	}
}

func GetGroupFilesEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		groupID := c.Param("id")
		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ?", groupID, user.ID).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
			return
		}

		var sharedFiles []models.GroupSharedFile
		if err := db.Where("shared_with_group_id = ?", groupID).Find(&sharedFiles).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch shared files"})
			return
		}

		var fileDetails []gin.H
		for _, sf := range sharedFiles {
			var file models.EncryptedFile
			if err := db.First(&file, sf.OriginalFileID).Error; err == nil {
				var sharedBy models.User
				db.First(&sharedBy, sf.SharedByUserID)

				fileDetails = append(fileDetails, gin.H{
					"id":          file.ID,
					"filename":    file.OriginalName,
					"file_size":   file.FileSize,
					"mime_type":   file.MimeType,
					"uploaded_at": file.UploadTime,
					"shared_by":   sharedBy.Username,
					"shared_at":   sf.CreatedAt,
					"folder_name": file.Folder,
				})
			}
		}

		var sharedFolders []models.GroupSharedFolder
		if err := db.Where("shared_with_group_id = ?", groupID).Find(&sharedFolders).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch shared folders"})
			return
		}

		var folderDetails []gin.H
		for _, sf := range sharedFolders {
			var sharedBy models.User
			db.First(&sharedBy, sf.SharedByUserID)

			folderDetails = append(folderDetails, gin.H{
				"folder_path": sf.FolderPath,
				"shared_by":   sharedBy.Username,
				"shared_at":   sf.CreatedAt,
			})
		}

		c.JSON(http.StatusOK, gin.H{
			"files":   fileDetails,
			"folders": folderDetails,
		})
	}
}

func UnshareFileFromGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var req struct {
			GroupID uint `json:"group_id" binding:"required"`
			FileID  uint `json:"file_id" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, user.ID).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
			return
		}

		var sharedFile models.GroupSharedFile
		if err := db.Where("original_file_id = ? AND shared_with_group_id = ?", req.FileID, req.GroupID).First(&sharedFile).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Shared file not found"})
			return
		}

		if !membership.IsAdmin && sharedFile.SharedByUserID != user.ID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only group admins or the user who shared can unshare"})
			return
		}

		if err := db.Delete(&sharedFile).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unshare file"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "File unshared successfully"})
	}
}

func UnshareFolderFromGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var req struct {
			GroupID    uint   `json:"group_id" binding:"required"`
			FolderPath string `json:"folder_path" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, user.ID).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
			return
		}

		var sharedFolder models.GroupSharedFolder
		if err := db.Where("folder_path = ? AND shared_with_group_id = ?", req.FolderPath, req.GroupID).First(&sharedFolder).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Shared folder not found"})
			return
		}

		if !membership.IsAdmin && sharedFolder.SharedByUserID != user.ID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only group admins or the user who shared can unshare"})
			return
		}
		if err := db.Delete(&sharedFolder).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unshare folder"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Folder unshared successfully"})
	}
}
