package models

import (
	"time"

	"gorm.io/gorm"
)

type EncryptedFile struct {
	ID           uint      `gorm:"primaryKey"`
	UserID       uint      `gorm:"index:idx_enc_file_lookup,priority:1;index:idx_enc_user_id;not null"`
	User         string    `gorm:"foreignKey:UserID"`
	OriginalName string    `gorm:"not null;index:idx_enc_file_lookup,priority:2"`
	Folder       string    `gorm:"not null;index:idx_enc_file_lookup,priority:3"`
	MimeType     string    `gorm:"not null"`
	FileSize     int64     `gorm:"not null"`
	UploadTime   time.Time `gorm:"not null"`
	StorageKey   string    `gorm:"size:36;uniqueIndex;not null"`
	IsDeleted    bool      `gorm:"default:false"`
	DeletedAt    gorm.DeletedAt
}
