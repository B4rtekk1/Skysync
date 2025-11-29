package models

import (
	"time"

	"gorm.io/gorm"
)

type File struct {
	gorm.Model
	Filename    string    `gorm:"not null;index:idx_file_lookup,priority:2"`
	FolderName  string    `gorm:"not null;index:idx_file_lookup,priority:3"`
	UserID      uint      `gorm:"not null;index:idx_file_lookup,priority:1;index:idx_user_id"`
	FileSize    int       `gorm:"not null"`
	FileHash    string    `gorm:"not null"`
	MimeType    string    `gorm:""`
	UploadedAt  time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	IsEncrypted bool      `gorm:"default:false"`
}
