package encryption

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"

	"golang.org/x/crypto/pbkdf2"
)

const (
	iterations = 210_000
	keyLen     = 32
	saltLen    = 32
)

func GenerateUserEncryptionKey(globalKey string) (encryptedKeyB64 string, userSalt []byte, err error) {
	userSalt = make([]byte, saltLen)
	if _, err = io.ReadFull(rand.Reader, userSalt); err != nil {
		return "", nil, err
	}

	userKey := make([]byte, keyLen)
	if _, err = rand.Read(userKey); err != nil {
		return "", nil, err
	}

	encrypted, err := encryptWithGlobalKey(userKey, []byte(globalKey), userSalt)
	if err != nil {
		return "", nil, err
	}

	return base64.RawStdEncoding.EncodeToString(encrypted), userSalt, nil
}

func DecryptUserEncryptionKey(encryptedB64, globalKey string, userSalt []byte) ([]byte, error) {
	data, err := base64.RawStdEncoding.DecodeString(encryptedB64)
	if err != nil {
		return nil, err
	}
	return decryptWithGlobalKey(data, []byte(globalKey), userSalt)
}

func encryptWithGlobalKey(plaintext, globalKey, salt []byte) ([]byte, error) {
	key := pbkdf2.Key(globalKey, salt, iterations, keyLen, sha256.New)
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	return gcm.Seal(nonce, nonce, plaintext, nil), nil
}

func decryptWithGlobalKey(ciphertext, globalKey, salt []byte) ([]byte, error) {
	key := pbkdf2.Key(globalKey, salt, iterations, keyLen, sha256.New)
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, fmt.Errorf("ciphertext too short")
	}
	nonce, ct := ciphertext[:nonceSize], ciphertext[nonceSize:]
	return gcm.Open(nil, nonce, ct, nil)
}
