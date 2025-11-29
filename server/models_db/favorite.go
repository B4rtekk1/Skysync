package models

import (
	"time"

	"gorm.io/gorm"
)

type Favorite struct {
	gorm.Model
	UserID    uint      `gorm:"not null;index:idx_user_file_favorite,priority:1;index:idx_fav_user_id"`
	FileID    uint      `gorm:"not null;index:idx_user_file_favorite,priority:2;index:idx_fav_file_id"`
	CreatedAt time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
