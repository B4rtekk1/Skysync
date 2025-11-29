package models

import (
	"time"

	"gorm.io/gorm"
)

type GroupSharedFile struct {
	gorm.Model
	OriginalFileID    uint      `gorm:"not null"`
	SharedWithGroupID uint      `gorm:"not null"`
	SharedByUserID    uint      `gorm:"not null"`
	CreatedAt         time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
