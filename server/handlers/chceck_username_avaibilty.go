package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	models "skysync/models_db"
	"skysync/types"
)

func CheckUsernameAvailabilityEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req types.CheckUsernameAvailabilityRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"detail": "Invalid request"})
			return
		}

		var user models.User
		if err := db.Where("username = ?", req.Username).First(&user).Error; err != nil {
			c.JSON(http.StatusOK, gin.H{"available": true})
			return
		} else {
			c.JSON(http.StatusConflict, gin.H{"available": false})
			return
		}

	}
}
