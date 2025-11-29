package models

import (
	"time"

	"gorm.io/gorm"
)

type GroupSharedFolder struct {
	gorm.Model
	FolderPath        string    `gorm:"not null"`
	SharedWithGroupID uint      `gorm:"not null"`
	SharedByUserID    uint      `gorm:"not null"`
	CreatedAt         time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
