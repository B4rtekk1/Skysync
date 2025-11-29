package utils

import (
	"os"
	"path/filepath"

	"github.com/google/uuid"
)

const StorageRoot = "storage/users"

func GetPhysicalPath(userUUID, storageKey string) string {
	return filepath.Join(StorageRoot, userUUID, storageKey[:1], storageKey[1:3], storageKey)
}

func EnsureUserStorage(userUUID string) error {
	return os.MkdirAll(filepath.Join(StorageRoot, userUUID), 0750)
}

func GenerateFilePath(userUUID string) (physicalPath, storageKey string, err error) {
	storageKey = uuid.New().String()
	physicalPath = GetPhysicalPath(userUUID, storageKey)
	if err := os.MkdirAll(filepath.Dir(physicalPath), 0750); err != nil {
		return "", "", err
	}
	return physicalPath, storageKey, nil
}
