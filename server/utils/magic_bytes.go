package utils

import (
	"bytes"
	"io"
	"os"
)

type MagicByteSignature struct {
	Offset    int
	Signature []byte
	MimeType  string
}

var FileMagicBytes = []MagicByteSignature{
	{0, []byte{0xFF, 0xD8, 0xFF}, "image/jpeg"},
	{0, []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, "image/png"},
	{0, []byte{0x47, 0x49, 0x46, 0x38, 0x37, 0x61}, "image/gif"},
	{0, []byte{0x47, 0x49, 0x46, 0x38, 0x39, 0x61}, "image/gif"},
	{0, []byte{0x42, 0x4D}, "image/bmp"},
	{0, []byte{0x49, 0x49, 0x2A, 0x00}, "image/tiff"},
	{0, []byte{0x4D, 0x4D, 0x00, 0x2A}, "image/tiff"},
	{0, []byte{0x52, 0x49, 0x46, 0x46}, "image/webp"},
	{8, []byte{0x57, 0x45, 0x42, 0x50}, "image/webp"},
	{0, []byte{0x25, 0x50, 0x44, 0x46}, "application/pdf"},
	{0, []byte{0x50, 0x4B, 0x03, 0x04}, "application/zip"},
	{0, []byte{0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1}, "application/msword"},
	{0, []byte{0x7B, 0x5C, 0x72, 0x74, 0x66}, "application/rtf"},
	{0, []byte{0x49, 0x44, 0x33}, "audio/mpeg"},
	{0, []byte{0xFF, 0xFB}, "audio/mpeg"},
	{0, []byte{0xFF, 0xF3}, "audio/mpeg"},
	{0, []byte{0xFF, 0xF2}, "audio/mpeg"},
	{0, []byte{0x52, 0x49, 0x46, 0x46}, "audio/wav"},
	{0, []byte{0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41}, "audio/mp4"},
	{0, []byte{0x4F, 0x67, 0x67, 0x53}, "audio/ogg"},
	{4, []byte{0x66, 0x74, 0x79, 0x70}, "video/mp4"},
	{0, []byte{0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70}, "video/mp4"},
	{0, []byte{0x00, 0x00, 0x00, 0x1C, 0x66, 0x74, 0x79, 0x70}, "video/mp4"},
	{0, []byte{0x1A, 0x45, 0xDF, 0xA3}, "video/webm"},
	{0, []byte{0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11}, "video/x-ms-wmv"},
	{0, []byte{0x46, 0x4C, 0x56, 0x01}, "video/x-flv"},
	{0, []byte{0x52, 0x61, 0x72, 0x21, 0x1A, 0x07}, "application/x-rar-compressed"},
	{0, []byte{0x1F, 0x8B, 0x08}, "application/gzip"},
	{0, []byte{0x42, 0x5A, 0x68}, "application/x-bzip2"},
	{0, []byte{0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C}, "application/x-7z-compressed"},
	{0, []byte{0x4D, 0x5A}, "application/x-msdownload"},
	{0, []byte{0x7F, 0x45, 0x4C, 0x46}, "application/x-elf"},
	{0, []byte{0xCA, 0xFE, 0xBA, 0xBE}, "application/x-mach-binary"},
	{0, []byte{0xCE, 0xFA, 0xED, 0xFE}, "application/x-mach-binary"},
	{0, []byte{0x4D, 0x5A}, "application/x-msdownload"},
	{0, []byte{0x7F, 0x45, 0x4C, 0x46}, "application/x-elf"},
	{0, []byte{0xCA, 0xFE, 0xBA, 0xBE}, "application/x-mach-binary"},
	{0, []byte{0xCE, 0xFA, 0xED, 0xFE}, "application/x-mach-binary"},
	{0, []byte{0xCF, 0xFA, 0xED, 0xFE}, "application/x-mach-binary"},
	{0, []byte{0xEF, 0xBB, 0xBF}, "text/plain"},
}

var DangerousMimeTypes = []string{
	"application/x-msdownload",
	"application/x-elf",
	"application/x-mach-binary",
	"application/x-executable",
	"application/x-sharedlib",
	"application/x-dosexec",
}

func ValidateFileMagicBytes(filePath string) (detectedMime string, isSafe bool, err error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", false, err
	}
	defer file.Close()

	buffer := make([]byte, 512)
	n, err := file.Read(buffer)
	if err != nil && err != io.EOF {
		return "", false, err
	}
	buffer = buffer[:n]

	detectedMime = "application/octet-stream"
	for _, sig := range FileMagicBytes {
		if sig.Offset+len(sig.Signature) > len(buffer) {
			continue
		}

		if bytes.Equal(buffer[sig.Offset:sig.Offset+len(sig.Signature)], sig.Signature) {
			detectedMime = sig.MimeType
			break
		}
	}

	isSafe = true
	for _, dangerous := range DangerousMimeTypes {
		if detectedMime == dangerous {
			isSafe = false
			break
		}
	}

	return detectedMime, isSafe, nil
}

func IsTextFile(buffer []byte) bool {
	if len(buffer) == 0 {
		return false
	}

	nullCount := 0
	for _, b := range buffer {
		if b == 0 {
			nullCount++
		}
	}

	return float64(nullCount)/float64(len(buffer)) < 0.01
}
