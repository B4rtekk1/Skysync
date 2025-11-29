package models

import (
	"time"

	"gorm.io/gorm"
)

type UserGroupMember struct {
	gorm.Model
	GroupID       uint      `gorm:"not null"`
	UserID        uint      `gorm:"not null"`
	AddedByUserID uint      `gorm:"not null"`
	AddedAt       time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	IsAdmin       bool      `gorm:"default:false"`
}
