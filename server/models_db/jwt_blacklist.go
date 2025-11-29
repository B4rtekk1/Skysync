package models

import (
	"time"
)

type JWTBlacklist struct {
	ID        uint      `gorm:"primaryKey"`
	JTI       string    `gorm:"uniqueIndex;not null"`
	UserID    uint      `gorm:"index"`
	Token     string    `gorm:"type:text"`
	ExpiresAt time.Time `gorm:"index"`
	RevokedAt time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	Reason    string    `gorm:"type:varchar(100)"`
}
