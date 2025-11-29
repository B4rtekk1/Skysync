package utils

import (
	"fmt"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"gopkg.in/yaml.v3"
)

type AppVersion struct {
	Version    string `yaml:"version"`
	BuildDate  string `yaml:"build_date"`
	CommitHash string `yaml:"commit_hash"`
}

func getAppVersion() (*AppVersion, error) {
	path := "../app_version.yaml"

	if _, err := os.Stat(path); os.IsNotExist(err) {
		defaultVersion := AppVersion{
			Version:    "0.0.1",
			BuildDate:  "unknown",
			CommitHash: "none",
		}

		data, err := yaml.Marshal(defaultVersion)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal default version: %v", err)
		}

		if err := os.WriteFile(path, data, 0644); err != nil {
			return nil, fmt.Errorf("failed to create default app_version.yaml: %v", err)
		}
	}

	file, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read app_version.yaml: %v", err)
	}

	var appVersion AppVersion
	if err := yaml.Unmarshal(file, &appVersion); err != nil {
		return nil, fmt.Errorf("failed to parse app_version.yaml: %v", err)
	}

	return &appVersion, nil
}

func AppVersionEndpoint() gin.HandlerFunc {
	return func(c *gin.Context) {
		appVersion, err := getAppVersion()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"detail": "Failed to get app version"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"version": appVersion.Version})
	}
}
