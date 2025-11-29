package encryption

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"io"
)

func EncryptedStream(plainReader io.Reader, destWriter io.Writer, userKey []byte) error {
	if len(userKey) != 32 {
		return fmt.Errorf("userKey must be exactly 32 bytes")
	}

	fileKey := make([]byte, 32)
	if _, err := rand.Read(fileKey); err != nil {
		return err
	}

	block, err := aes.NewCipher(userKey)
	if err != nil {
		return err
	}
	userGCM, err := cipher.NewGCM(block)
	if err != nil {
		return err
	}

	fileKeyNonce := make([]byte, userGCM.NonceSize())
	if _, err := rand.Read(fileKeyNonce); err != nil {
		return err
	}
	if _, err := destWriter.Write(fileKeyNonce); err != nil {
		return err
	}

	encryptedFileKey := userGCM.Seal(nil, fileKeyNonce, fileKey, nil)
	if _, err := destWriter.Write(encryptedFileKey); err != nil {
		return err
	}

	fileBlock, err := aes.NewCipher(fileKey)
	if err != nil {
		return err
	}
	fileGCM, err := cipher.NewGCM(fileBlock)
	if err != nil {
		return err
	}

	baseNonce := make([]byte, 12)
	if _, err := rand.Read(baseNonce); err != nil {
		return err
	}
	if _, err := destWriter.Write(baseNonce); err != nil {
		return err
	}

	const chunkSize = 64 * 1024
	buf := make([]byte, chunkSize)
	counter := uint64(0)

	for {
		n, err := plainReader.Read(buf)
		if n > 0 {
			nonce := make([]byte, 12)
			copy(nonce, baseNonce)
			for i := range uint64(8) {
				nonce[11-i] ^= byte(counter >> (i * 8))
			}

			ciphertext := fileGCM.Seal(nil, nonce, buf[:n], nil)

			chunkLen := uint32(len(ciphertext))
			if err := binary.Write(destWriter, binary.LittleEndian, chunkLen); err != nil {
				return err
			}

			if _, err := destWriter.Write(ciphertext); err != nil {
				return err
			}

			counter++
		}

		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func DecryptStream(encryptedReader io.Reader, destWriter io.Writer, userKey []byte) error {
	if len(userKey) != 32 {
		return fmt.Errorf("userKey must be exactly 32 bytes")
	}

	block, err := aes.NewCipher(userKey)
	if err != nil {
		return err
	}
	userGCM, err := cipher.NewGCM(block)
	if err != nil {
		return err
	}

	fileKeyNonce := make([]byte, 12)
	if _, err := io.ReadFull(encryptedReader, fileKeyNonce); err != nil {
		return fmt.Errorf("read fileKey nonce: %w", err)
	}

	encryptedFileKey := make([]byte, 48)
	if _, err := io.ReadFull(encryptedReader, encryptedFileKey); err != nil {
		return fmt.Errorf("read encrypted fileKey: %w", err)
	}

	fileKey, err := userGCM.Open(nil, fileKeyNonce, encryptedFileKey, nil)
	if err != nil {
		return fmt.Errorf("decrypt fileKey: %w", err)
	}

	fileBlock, err := aes.NewCipher(fileKey)
	if err != nil {
		return err
	}
	fileGCM, err := cipher.NewGCM(fileBlock)
	if err != nil {
		return err
	}

	baseNonce := make([]byte, 12)
	if _, err := io.ReadFull(encryptedReader, baseNonce); err != nil {
		return fmt.Errorf("read base nonce: %w", err)
	}

	counter := uint64(0)

	for {
		var chunkLen uint32
		err := binary.Read(encryptedReader, binary.LittleEndian, &chunkLen)
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("read chunk length: %w", err)
		}

		ciphertext := make([]byte, chunkLen)
		if _, err := io.ReadFull(encryptedReader, ciphertext); err != nil {
			return fmt.Errorf("read ciphertext: %w", err)
		}

		nonce := make([]byte, 12)
		copy(nonce, baseNonce)
		for i := range uint64(8) {
			nonce[11-i] ^= byte(counter >> (i * 8))
		}

		plaintext, err := fileGCM.Open(nil, nonce, ciphertext, nil)
		if err != nil {
			return fmt.Errorf("decrypt chunk failed: %w", err)
		}

		if _, err := destWriter.Write(plaintext); err != nil {
			return err
		}

		counter++
	}

	return nil
}
