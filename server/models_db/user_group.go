package models

import (
	"time"

	"gorm.io/gorm"
)

type UserGroup struct {
	gorm.Model
	Name            string    `gorm:"unique;not null"`
	Description     string    `gorm:"type:text"`
	CreatedByUserID uint      `gorm:"not null"`
	CreatedAt       time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	IsActive        bool      `gorm:"default:true"`
}
