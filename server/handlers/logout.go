package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"skysync/global"
	models "skysync/models_db"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"gorm.io/gorm"
)

func LogoutEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet("user").(models.User)

		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "No token provided"})
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid authorization format"})
			return
		}

		tokenString := parts[1]

		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("invalid signing method")
			}
			return []byte(global.SECRET_KEY), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid token"})
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid token claims"})
			return
		}

		jti, _ := claims["jti"].(string)
		sessionID, _ := claims["session_id"].(string)
		exp, _ := claims["exp"].(float64)

		if jti != "" {
			expiresAt := time.Unix(int64(exp), 0)
			blacklistEntry := models.JWTBlacklist{
				JTI:       jti,
				UserID:    user.ID,
				Token:     tokenString,
				ExpiresAt: expiresAt,
				RevokedAt: time.Now(),
				Reason:    "user_logout",
			}

			if err := db.Create(&blacklistEntry).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to revoke token"})
				return
			}
		}

		if sessionID != "" {
			db.Model(&models.UserSession{}).
				Where("session_id = ? AND user_id = ?", sessionID, user.ID).
				Update("is_active", false)
		}

		db.Create(&models.SecurityEvent{
			EventType:     "user_logout",
			Severity:      "low",
			Details:       fmt.Sprintf("User %s logged out successfully", user.Username),
			Username:      user.Username,
			Timestamp:     time.Now(),
			UserIP:        c.ClientIP(),
			UserAgent:     c.Request.UserAgent(),
			RequestPath:   "/logout",
			RequestMethod: "POST",
		})

		c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
	}
}
