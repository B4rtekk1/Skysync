package models

import (
	"time"

	"gorm.io/gorm"
)

type PasswordHistory struct {
	gorm.Model
	UserID       uint      `gorm:"not null"`
	PasswordHash string    `gorm:"not null"`
	CreatedAt    time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
