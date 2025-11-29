package utils

import (
	"log"
	"time"

	models "skysync/models_db"

	"gorm.io/gorm"
)

func CleanupExpiredTokens(db *gorm.DB) {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	log.Println("[SECURITY] JWT blacklist cleanup task started")

	for range ticker.C {
		now := time.Now()

		result := db.Where("expires_at < ?", now).Delete(&models.JWTBlacklist{})

		if result.Error != nil {
			log.Printf("[SECURITY] Error cleaning up JWT blacklist: %v", result.Error)
		} else if result.RowsAffected > 0 {
			log.Printf("[SECURITY] Cleaned up %d expired tokens from blacklist", result.RowsAffected)
		}

		result = db.Where("expires_at < ?", now).Delete(&models.UserSession{})

		if result.Error != nil {
			log.Printf("[SECURITY] Error cleaning up expired sessions: %v", result.Error)
		} else if result.RowsAffected > 0 {
			log.Printf("[SECURITY] Cleaned up %d expired sessions", result.RowsAffected)
		}
	}
}
