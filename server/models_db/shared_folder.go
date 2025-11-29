package models

import (
	"time"

	"gorm.io/gorm"
)

type SharedFolder struct {
	gorm.Model
	FolderPath       string    `gorm:"not null"`
	SharedWithUserID uint      `gorm:"not null"`
	SharedByUserID   uint      `gorm:"not null"`
	CreatedAt        time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
