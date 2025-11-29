package models

import (
	"time"

	"gorm.io/gorm"
)

type FileScan struct {
	gorm.Model
	FileID      uint      `gorm:"not null"`
	ScanType    string    `gorm:"not null"`
	ScanResult  string    `gorm:"not null"`
	ScanDetails string    `gorm:"type:text"`
	ScannedAt   time.Time `gorm:"default:CURRENT_TIMESTAMP"`
	IsClean     bool      `gorm:"default:true"`
}
