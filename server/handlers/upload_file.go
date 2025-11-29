package handlers

import (
	"io"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"skysync/encryption"
	"skysync/global"
	models "skysync/models_db"
	"skysync/scanner"
	"skysync/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func UploadFileEndpoint(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		config := global.GetConfig()
		user := c.MustGet("user").(models.User)

		fileHeader, err := c.FormFile("file")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "No file provided"})
			return
		}

		if len(fileHeader.Filename) > config.MaxFileNameLength {
			c.JSON(http.StatusBadRequest, gin.H{"error": "File name too long"})
			return
		}

		folder := c.PostForm("folder")
		if folder == "" {
			folder = "/"
		}

		if config.FileUploadValidation {
			ext := filepath.Ext(fileHeader.Filename)
			if slices.Contains(utils.BLOCKED_FILE_EXTENSIONS, ext) {
				log.Printf("[SECURITY] Blocked file extension: %s for file: %s", ext, fileHeader.Filename)
				c.JSON(http.StatusBadRequest, gin.H{"error": "File type not allowed"})
				return
			}
		}

		if config.ContentTypeValidation {
			contentType := fileHeader.Header.Get("Content-Type")
			if contentType == "" || contentType == "application/octet-stream" {
				mimeType := mime.TypeByExtension(filepath.Ext(fileHeader.Filename))
				if mimeType == "" {
					log.Printf("[SECURITY] Unable to determine content type for file: %s", fileHeader.Filename)
				}
			}
		}

		physPath, storageKey, err := utils.GenerateFilePath(user.UUID)
		if err != nil {
			log.Printf("Storage path generation error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Storage error"})
			return
		}

		tempFile, err := os.CreateTemp("", "upload-*")
		if err != nil {
			log.Printf("Temp file creation error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Temp file creation error"})
			return
		}
		defer os.Remove(tempFile.Name())

		src, err := fileHeader.Open()
		if err != nil {
			log.Printf("File open error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "File open error"})
			return
		}
		defer src.Close()

		_, err = io.Copy(tempFile, src)
		if err != nil {
			log.Printf("File copy error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "File copy error"})
			tempFile.Close()
			return
		}
		tempFile.Close()

		if config.ContentTypeValidation {
			detectedMime, isSafe, err := utils.ValidateFileMagicBytes(tempFile.Name())
			if err != nil {
				log.Printf("[SECURITY] Failed to validate file content: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "File validation error"})
				return
			}

			if !isSafe {
				log.Printf("[SECURITY] Dangerous file type detected: %s for file: %s", detectedMime, fileHeader.Filename)
				c.JSON(http.StatusBadRequest, gin.H{"error": "Executable files are not allowed"})
				return
			}

			declaredMime := mime.TypeByExtension(filepath.Ext(fileHeader.Filename))
			if declaredMime != "" && detectedMime != "application/octet-stream" {
				declaredTypePrefix := declaredMime
				if idx := strings.Index(declaredMime, "/"); idx != -1 {
					declaredTypePrefix = declaredMime[:idx]
				}
				detectedTypePrefix := detectedMime
				if idx := strings.Index(detectedMime, "/"); idx != -1 {
					detectedTypePrefix = detectedMime[:idx]
				}

				if declaredTypePrefix != detectedTypePrefix && declaredMime != detectedMime {
					log.Printf("[SECURITY WARNING] MIME type mismatch: declared=%s, detected=%s for file=%s",
						declaredMime, detectedMime, fileHeader.Filename)
				}
			}
		}

		if config.VirusScanning {
			if scanner.NewScanner().ScanFile(tempFile.Name()) != nil {
				log.Printf("[SECURITY] Malware detected in file: %s", fileHeader.Filename)
				c.JSON(http.StatusBadRequest, gin.H{"error": "Malware detected"})
				return
			}
		}

		userKey, err := encryption.DecryptUserEncryptionKey(user.EncryptionKey, global.ENCRYPTION_KEY, user.EncryptionKeySalt)
		if err != nil {
			log.Printf("Key decryption error for user %s: %v", user.UUID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Key decryption error"})
			return
		}

		encryptedFile, err := os.Create(physPath)
		if err != nil {
			log.Printf("Save error for file %s: %v", physPath, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Save error"})
			return
		}
		defer encryptedFile.Close()

		tempFile, err = os.Open(tempFile.Name())
		if err != nil {
			log.Printf("Temp file open error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Temp file open error"})
			return
		}
		err = encryption.EncryptedStream(tempFile, encryptedFile, userKey)
		tempFile.Close()

		if err != nil {
			log.Printf("Encryption error: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Encryption error"})
			return
		}

		mimeType := mime.TypeByExtension(filepath.Ext(fileHeader.Filename))
		if mimeType == "" {
			mimeType = "application/octet-stream"
		}

		db.Create(&models.EncryptedFile{
			UserID:       user.ID,
			OriginalName: fileHeader.Filename,
			Folder:       folder,
			MimeType:     mimeType,
			FileSize:     fileHeader.Size,
			StorageKey:   storageKey,
			UploadTime:   time.Now(),
		})
		c.JSON(http.StatusOK, gin.H{"message": "File uploaded successfully"})
	}
}
