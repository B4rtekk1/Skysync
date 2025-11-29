package models

import (
	"time"

	"gorm.io/gorm"
)

type SharedFile struct {
	gorm.Model
	OriginalFileID   uint      `gorm:"not null"`
	SharedWithUserID uint      `gorm:"not null"`
	SharedByUserID   uint      `gorm:"not null"`
	CreatedAt        time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
