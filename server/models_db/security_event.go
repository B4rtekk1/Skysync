package models

import (
	"time"

	"gorm.io/gorm"
)

type SecurityEvent struct {
	gorm.Model
	EventType       string    `gorm:"not null;index:idx_event_type"`
	Severity        string    `gorm:"not null;index:idx_severity"`
	Details         string    `gorm:"not null;type:text"`
	UserIP          string    `gorm:"index:idx_user_ip"`
	Username        string    `gorm:"index:idx_username"`
	UserAgent       string    `gorm:""`
	RequestPath     string    `gorm:""`
	RequestMethod   string    `gorm:""`
	Timestamp       time.Time `gorm:"default:CURRENT_TIMESTAMP;index:idx_timestamp"`
	Resolved        bool      `gorm:"default:false;index:idx_resolved"`
	ResolutionNotes string    `gorm:"type:text"`
}
