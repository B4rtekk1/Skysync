package models

import (
	"time"
)

type QuickShare struct {
	ID            uint          `gorm:"primaryKey"`
	FileID        uint          `gorm:"not null"`
	File          EncryptedFile `gorm:"foreignKey:FileID"`
	ShareToken    string        `gorm:"size:64;uniqueIndex;not null"`
	CreatedByID   uint          `gorm:"not null"`
	ExpiresAt     time.Time     `gorm:"not null"`
	DownloadLimit int           `gorm:"default:0"`
	Downloads     int           `gorm:"default:0"`
	IsActive      bool          `gorm:"default:true"`
	CreatedAt     time.Time
}
