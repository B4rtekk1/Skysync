package utils

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type ScannerConfig struct {
	Verbose          bool    `yaml:"verbose"`
	EntropyThreshold float64 `yaml:"EntropyThreshold"`
}

type UsersConfig struct {
	MaxDataSize int `yaml:"max_data_size"`
	MaxFiles    int `yaml:"max_files"`
	MaxFolders  int `yaml:"max_folders"`
	MaxFileSize int `yaml:"max_file_size"`
}

type Config struct {
	Port                      string        `yaml:"port"`
	MaxRequestSize            int           `yaml:"max_request_size"`
	MaxFilesPerUpload         int           `yaml:"max_files_per_upload"`
	SessionTimeoutMinutes     int           `yaml:"session_timeout"`
	PasswordHistorySize       int           `yaml:"password_history_size"`
	MaxFailedAttemptsPerHour  int           `yaml:"max_failed_attempts_per_hour"`
	AccountLockoutThreshold   int           `yaml:"account_lockout_threshold"`
	AccountLockoutDuration    int           `yaml:"account_lockout_duration"`
	SessionInactivityTimeout  int           `yaml:"session_inactivity_timeout"`
	MaxConcurrentSessions     int           `yaml:"max_concurrent_sessions"`
	FileScanTimeout           int           `yaml:"file_scan_timeout"`
	EncryptionKeyRotationDays int           `yaml:"encryption_key_rotation_days"`
	AuditLogRetentionDays     int           `yaml:"audit_log_retention_days"`
	BackupRetentionDays       int           `yaml:"backup_retention_days"`
	MaxFileNameLength         int           `yaml:"max_file_name_length"`
	MaxFolderDepth            int           `yaml:"max_folder_depth"`
	RateLimitWindow           int           `yaml:"rate_limit_window"`
	RateLimitMaxRequests      int           `yaml:"rate_limit_max_requests"`
	CSRFProtection            bool          `yaml:"csrf_protection"`
	XSSProtection             bool          `yaml:"xss_protection"`
	SQLInjectionProtection    bool          `yaml:"sql_injection_protection"`
	PathTraversalProtection   bool          `yaml:"path_traversal_protection"`
	FileUploadValidation      bool          `yaml:"file_upload_validation"`
	ContentTypeValidation     bool          `yaml:"content_type_validation"`
	VirusScanning             bool          `yaml:"virus_scanning"`
	EncryptionAtRest          bool          `yaml:"encryption_at_rest"`
	EncryptionInTransit       bool          `yaml:"encryption_in_transit"`
	SessionFixationProtection bool          `yaml:"session_fixation_protection"`
	ClickjackingProtection    bool          `yaml:"clickjacking_protection"`
	MimeSniffingProtection    bool          `yaml:"mime_sniffing_protection"`
	ReferrerPolicy            string        `yaml:"referrer_policy"`
	ContentSecurityPolicy     string        `yaml:"content_security_policy"`
	PermissionsPolicy         string        `yaml:"permissions_policy"`
	HSTSMaxAge                int           `yaml:"hsts_max_age"`
	HSTSIncludeSubdomains     bool          `yaml:"hsts_include_subdomains"`
	HSTSPreload               bool          `yaml:"hsts_preload"`
	Scanner                   ScannerConfig `yaml:"scanner"`
	UsersConfig               UsersConfig   `yaml:"users_config"`
}

func LoadConfig() (*Config, error) {
	configFile, err := os.ReadFile("config.yaml")
	if err != nil {
		return nil, fmt.Errorf("failed to parse config.yaml: %v", err)
	}

	var config Config
	if err := yaml.Unmarshal(configFile, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config.yaml: %v", err)
	}
	return &config, nil
}

var BLOCKED_FILE_EXTENSIONS = []string{
	".exe", ".bat", ".cmd", ".com", ".pif", ".scr", ".vbs", ".js", ".jar",
	".msi", ".dmg", ".app", ".sh", ".php", ".asp", ".aspx", ".jsp",
}
