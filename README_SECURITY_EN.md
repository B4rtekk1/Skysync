# 🛡️ ServApp - Security Instructions

## Overview

This document provides instructions for implementing and configuring enhanced security for the ServApp application. All features are designed to maximize protection against various types of attacks.

## 🚀 Quick Installation

### 1. Install Dependencies

```bash
# Install core security dependencies
pip install -r requirements_security.txt

# Or install individual packages
pip install python-magic cryptography aiofiles pydantic[email]
```

### 2. Configure Environment Variables

Create or update the `.env` file:

```env
# Basic configuration
SECRET_KEY=your-very-secure-secret-key-minimum-32-characters
API_KEY=your-secure-api-key-here
BASE_URL=http://localhost:8000

# Email configuration
EMAIL=your-email@gmail.com
PASSWORD=your-app-password

# Enhanced security configuration
ENCRYPTION_KEY=your-secure-encryption-key-32-characters
SECURITY_LOG_LEVEL=INFO
ENABLE_VIRUS_SCANNING=true
ENABLE_ENCRYPTION=true
MAX_FILE_SIZE=104857600
SESSION_TIMEOUT_MINUTES=30
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_WINDOW=60
```

### 3. Start the Server

```bash
# Start with enhanced security features
python server.py

# Or with uvicorn
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
```

## 🔧 Detailed Configuration

### Security Configuration

All security settings are available in the `SECURITY_CONFIG` dictionary in `server.py`:

```python
SECURITY_CONFIG = {
    'max_request_size': 100 * 1024 * 1024,  # 100MB
    'max_files_per_upload': 10,
    'session_timeout_minutes': 30,
    'password_history_size': 5,
    'max_failed_attempts_per_hour': 10,
    'account_lockout_threshold': 5,
    'account_lockout_duration': 30,  # minutes
    'session_inactivity_timeout': 15,  # minutes
    'max_concurrent_sessions': 3,
    'file_scan_timeout': 30,  # seconds
    'encryption_key_rotation_days': 90,
    'audit_log_retention_days': 365,
    'backup_retention_days': 30,
    'max_file_name_length': 255,
    'max_folder_depth': 10,
    'rate_limit_window': 60,  # seconds
    'rate_limit_max_requests': 100,
    'csrf_protection': True,
    'xss_protection': True,
    'sql_injection_protection': True,
    'path_traversal_protection': True,
    'file_upload_validation': True,
    'content_type_validation': True,
    'virus_scanning': True,
    'encryption_at_rest': True,
    'encryption_in_transit': True,
    'session_fixation_protection': True,
    'clickjacking_protection': True,
    'mime_sniffing_protection': True,
    'referrer_policy': 'strict-origin-when-cross-origin',
    'content_security_policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
    'permissions_policy': "geolocation=(), microphone=(), camera=()",
    'hsts_max_age': 31536000,
    'hsts_include_subdomains': True,
    'hsts_preload': True
}
```

### Logging Configuration

Security logs are stored in `security.log` with the following format:

```
2024-01-15 10:30:00 - INFO - [192.168.1.100] [testuser] SECURITY_EVENT: {"event_type": "failed_login", "details": "Invalid password", "severity": "medium"}
```

## 🧪 Security Testing

### Run Tests

```bash
# Test all security features
python test_security.py

# Test with custom parameters
python test_security.py --url http://localhost:8000 --api-key your_api_key
```

### Tests to Perform

1. **Rate Limiting** - Check blocking after exceeding limits
2. **File Upload Validation** - Test file validation
3. **Path Traversal** - Check path traversal protection
4. **SQL Injection** - Test SQL injection protection
5. **XSS Protection** - Check XSS protection
6. **Password Validation** - Test password validation
7. **File Encryption** - Check file encryption
8. **Security Headers** - Test security headers
9. **Admin Endpoints** - Check admin endpoints
10. **Session Management** - Test session management
11. **Audit Logging** - Check audit logging
