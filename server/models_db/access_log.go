package models

import (
	"time"

	"gorm.io/gorm"
)

type AccessLog struct {
	gorm.Model
	UserID        uint      `gorm:""`
	IPAddress     string    `gorm:"not null"`
	RequestMethod string    `gorm:"not null"`
	RequestPath   string    `gorm:"not null"`
	StatusCode    int       `gorm:"not null"`
	UserAgent     string    `gorm:""`
	RequestTime   int       `gorm:""`
	Timestamp     time.Time `gorm:"default:CURRENT_TIMESTAMP"`
}
