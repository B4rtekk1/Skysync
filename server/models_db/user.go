package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type User struct {
	ID                  uint   `gorm:"primaryKey"`
	UUID                string `gorm:"type:char(36);uniqueIndex;not null"`
	Username            string `gorm:"size:50;uniqueIndex;not null;index:idx_username_email,priority:1"`
	Email               string `gorm:"size:255;UniqueIndex;not null;index:idx_username_email,priority:2"`
	PasswordHash        string `gorm:"size:255;not null"`
	EncryptionKey       string `gorm:"size:500;not null"`
	EncryptionKeySalt   []byte `gorm:"not null"`
	Verified            int    `gorm:"default:0"`
	VerificationCode    string `gorm:"size:100"`
	VerificationExpiry  *time.Time
	ResetToken          string `gorm:"size:100"`
	ResetTokenExpiry    *time.Time
	DeletionToken       string `gorm:"size:100"`
	DeletionTokenExpiry *time.Time
	FailedLoginAttempts int `gorm:"default:0"`
	AccountLockedUntil  *time.Time
	LastLogin           *time.Time
	IsActive            bool `gorm:"default:true"`
	CreatedAt           time.Time
	UpdatedAt           time.Time
	DeletedAt           gorm.DeletedAt `gorm:"index"`
}

func (u *User) BeforeCreate(tx *gorm.DB) (err error) {
	if u.UUID == "" {
		u.UUID = uuid.New().String()
	}
	return nil
}
