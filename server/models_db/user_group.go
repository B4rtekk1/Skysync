package models

import (
	"time"

	"gorm.io/gorm"
)

type UserGroup struct {
	ID              uint           `gorm:"primarykey" json:"id"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
	Name            string         `gorm:"unique;not null" json:"name"`
	Description     string         `gorm:"type:text" json:"description"`
	CreatedByUserID uint           `gorm:"not null" json:"created_by_user_id"`
	IsActive        bool           `gorm:"default:true" json:"is_active"`
}
