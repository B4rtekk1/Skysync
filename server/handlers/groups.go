package handlers

import (
	"net/http"
	models "skysync/models_db"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func CreateGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var req struct {
			Name        string `json:"name" binding:"required"`
			Description string `json:"description"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var existing models.UserGroup
		if err := db.Where("name = ?", req.Name).First(&existing).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Group name already exists"})
			return
		}

		group := models.UserGroup{
			Name:            req.Name,
			Description:     req.Description,
			CreatedByUserID: user.ID,
			CreatedAt:       time.Now(),
			IsActive:        true,
		}

		if err := db.Create(&group).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create group"})
			return
		}

		member := models.UserGroupMember{
			GroupID:       group.ID,
			UserID:        user.ID,
			AddedByUserID: user.ID,
			AddedAt:       time.Now(),
			IsAdmin:       true,
		}

		if err := db.Create(&member).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add creator to group"})
			return
		}

		c.JSON(http.StatusCreated, gin.H{
			"message": "Group created successfully",
			"group": gin.H{
				"id":          group.ID,
				"name":        group.Name,
				"description": group.Description,
				"created_at":  group.CreatedAt,
			},
		})
	}
}

func ListGroupsEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var memberships []models.UserGroupMember
		if err := db.Where("user_id = ?", user.ID).Find(&memberships).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch groups"})
			return
		}

		var groupIDs []uint
		for _, m := range memberships {
			groupIDs = append(groupIDs, m.GroupID)
		}

		var groups []models.UserGroup
		if len(groupIDs) > 0 {
			if err := db.Where("id IN ? AND is_active = ?", groupIDs, true).Find(&groups).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch group details"})
				return
			}
		}

		type GroupWithMembers struct {
			ID              uint      `json:"id"`
			Name            string    `json:"name"`
			Description     string    `json:"description"`
			CreatedAt       time.Time `json:"created_at"`
			CreatedByUserID uint      `json:"created_by_user_id"`
			IsActive        bool      `json:"is_active"`
			MemberCount     int       `json:"member_count"`
			IsAdmin         bool      `json:"is_admin"`
		}

		var result []GroupWithMembers
		for _, group := range groups {
			var memberCount int64
			db.Model(&models.UserGroupMember{}).Where("group_id = ?", group.ID).Count(&memberCount)

			var membership models.UserGroupMember
			isAdmin := false
			if err := db.Where("group_id = ? AND user_id = ?", group.ID, user.ID).First(&membership).Error; err == nil {
				isAdmin = membership.IsAdmin
			}

			result = append(result, GroupWithMembers{
				ID:              group.ID,
				Name:            group.Name,
				Description:     group.Description,
				CreatedAt:       group.CreatedAt,
				CreatedByUserID: group.CreatedByUserID,
				IsActive:        group.IsActive,
				MemberCount:     int(memberCount),
				IsAdmin:         isAdmin,
			})
		}

		c.JSON(http.StatusOK, gin.H{"groups": result})
	}
}

func GetGroupDetailsEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		groupID := c.Param("id")

		var group models.UserGroup
		if err := db.First(&group, groupID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ?", group.ID, user.ID).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "You are not a member of this group"})
			return
		}

		var members []models.UserGroupMember
		db.Where("group_id = ?", group.ID).Find(&members)

		var memberDetails []gin.H
		for _, m := range members {
			var u models.User
			if err := db.First(&u, m.UserID).Error; err == nil {
				memberDetails = append(memberDetails, gin.H{
					"id":       u.ID,
					"username": u.Username,
					"email":    u.Email,
					"is_admin": m.IsAdmin,
					"added_at": m.AddedAt,
				})
			}
		}

		c.JSON(http.StatusOK, gin.H{
			"group": gin.H{
				"id":          group.ID,
				"name":        group.Name,
				"description": group.Description,
				"created_at":  group.CreatedAt,
				"is_active":   group.IsActive,
			},
			"members":  memberDetails,
			"is_admin": membership.IsAdmin,
		})
	}
}

func AddMemberToGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var req struct {
			GroupID  uint   `json:"group_id" binding:"required"`
			Username string `json:"username"`
			Email    string `json:"email"`
			IsAdmin  bool   `json:"is_admin"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ? AND is_admin = ?", req.GroupID, user.ID, true).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only group admins can add members"})
			return
		}

		var targetUser models.User
		var err error

		if req.Email != "" {
			err = db.Where("email = ?", req.Email).First(&targetUser).Error
		} else if req.Username != "" {
			err = db.Where("username = ?", req.Username).First(&targetUser).Error
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email or Username is required"})
			return
		}

		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		var existing models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, targetUser.ID).First(&existing).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "User is already a member"})
			return
		}

		newMember := models.UserGroupMember{
			GroupID:       req.GroupID,
			UserID:        targetUser.ID,
			AddedByUserID: user.ID,
			AddedAt:       time.Now(),
			IsAdmin:       req.IsAdmin,
		}

		if err := db.Create(&newMember).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add member"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Member added successfully"})
	}
}

func RemoveMemberFromGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		var req struct {
			GroupID uint `json:"group_id" binding:"required"`
			UserID  uint `json:"user_id" binding:"required"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ? AND is_admin = ?", req.GroupID, user.ID, true).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only group admins can remove members"})
			return
		}

		if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, req.UserID).Delete(&models.UserGroupMember{}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove member"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Member removed successfully"})
	}
}

func DeleteGroupEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)
		groupID := c.Param("id")

		var group models.UserGroup
		if err := db.First(&group, groupID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Group not found"})
			return
		}

		var membership models.UserGroupMember
		if err := db.Where("group_id = ? AND user_id = ? AND is_admin = ?", group.ID, user.ID, true).First(&membership).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only group admins can delete the group"})
			return
		}

		db.Where("group_id = ?", group.ID).Delete(&models.UserGroupMember{})

		if err := db.Delete(&group).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete group"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Group deleted successfully"})
	}
}
