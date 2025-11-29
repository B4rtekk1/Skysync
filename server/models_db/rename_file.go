package models

import (
	"time"

	"gorm.io/gorm"
)

type RenameFile struct {
	gorm.Model
	FileID          uint      `gorm:"not null"`
	OldFilename     string    `gorm:"not null"`
	NewFilename     string    `gorm:"not null"`
	RenamedByUserID uint      `gorm:"not null"`
	RenamedAt       time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
