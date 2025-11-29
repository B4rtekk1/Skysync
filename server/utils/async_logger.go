package utils

import (
	"log"
	models "skysync/models_db"
	"sync"
	"time"

	"gorm.io/gorm"
)

type AsyncLogger struct {
	db            *gorm.DB
	eventBuffer   chan models.SecurityEvent
	batchSize     int
	flushInterval time.Duration
	wg            sync.WaitGroup
	stopChan      chan struct{}
}

func NewAsyncLogger(db *gorm.DB, bufferSize, batchSize int, flushInterval time.Duration) *AsyncLogger {
	logger := &AsyncLogger{
		db:            db,
		eventBuffer:   make(chan models.SecurityEvent, bufferSize),
		batchSize:     batchSize,
		flushInterval: flushInterval,
		stopChan:      make(chan struct{}),
	}
	logger.wg.Add(1)
	go logger.processEvents()
	return logger
}

func (al *AsyncLogger) LogEvent(event models.SecurityEvent) {
	select {
	case al.eventBuffer <- event:
	default:
		log.Printf("Warning: Event buffer full, saving directly")
		if err := al.db.Create(&event).Error; err != nil {
			log.Printf("Error saving security event: %v", err)
		}
	}
}

func (al *AsyncLogger) processEvents() {
	defer al.wg.Done()

	var events []models.SecurityEvent
	ticker := time.NewTicker(al.flushInterval)
	defer ticker.Stop()

	flush := func() {
		if len(events) > 0 {
			if err := al.db.CreateInBatches(events, al.batchSize).Error; err != nil {
				log.Printf("Error batch saving security events: %v", err)
			}
			events = events[:0]
		}
	}

	for {
		select {
		case event := <-al.eventBuffer:
			events = append(events, event)
			if len(events) >= al.batchSize {
				flush()
			}
		case <-ticker.C:
			flush()
		case <-al.stopChan:
			for len(al.eventBuffer) > 0 {
				events = append(events, <-al.eventBuffer)
			}
			flush()
			return
		}
	}
}

func (al *AsyncLogger) Stop() {
	close(al.stopChan)
	al.wg.Wait()
	close(al.eventBuffer)
}
