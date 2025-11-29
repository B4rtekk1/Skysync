package models

import (
	"time"

	"gorm.io/gorm"
)

type UserSession struct {
	gorm.Model
	UserID       uint      `gorm:"not null"`
	SessionID    string    `gorm:"unique;not null"`
	TokenHash    string    `gorm:"not null"`
	IPAddress    string    `gorm:"not null"`
	UserAgent    string    `gorm:""`
	CreatedAt    time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	LastActivity time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	ExpiresAt    time.Time `gorm:"not null"`
	IsActive     bool      `gorm:"default:true"`
}
