# Documentation for `server.py`

## Overview

This file implements a FastAPI-based backend server for user management, file storage, sharing, and security features. It handles user registration, authentication, file uploads/downloads, folder management, group-based sharing, encryption, and enhanced security measures including rate limiting, WAF (Web Application Firewall), and logging.

### Key Features

- **User Management**: Registration, email verification, login, password reset, and deletion.
- **File Management**: Upload, download, delete, rename, encrypt/decrypt, and favorite files.
- **Folder Management**: Create folders, list files/folders, share folders.
- **Group Management**: Create groups, add/remove members, share files/folders with groups.
- **Sharing**: Share files/folders with individual users or groups.
- **Security**: JWT authentication, API key protection, rate limiting, WAF middleware, virus scanning (heuristic), encryption at rest, audit logging, and IP blocking.
- **Database**: Uses SQLAlchemy with SQLite for storing users, files, groups, shares, sessions, and security events.
- **Environment Dependencies**: Relies on `.env` for secrets like `API_KEY`, `SECRET_KEY`, `EMAIL`, `PASSWORD`, etc.

The server runs on port 8000 and supports CORS for all origins.

### Dependencies

- **Python Standard Libraries**: `os`, `json`, `random`, `re`, `time`, `secrets`, `zipfile`, `shutil`, `hashlib`, `logging`, `smtplib`, `ssl`, `hmac`, `uuid`, `datetime`, `typing`, `collections`, `email`.
- **Third-Party Libraries**: `fastapi`, `sqlalchemy`, `bcrypt`, `jose` (JWT), `cryptography`, `asyncio`, `aiofiles`, `dotenv`, `uvicorn` (for running).

```bash
# Run this command to auto instllation of packages
pip install -r requirements.txt
```

### Security Configuration

Defined in the `SECURITY_CONFIG` dictionary, including:

- Maximum file size, login attempts, session timeouts, etc.
- Blocked file extensions listed in `BLOCKED_FILE_EXTENSIONS`.

### Logging

- Uses Python's `logging` module with a custom filter for IP and user information.
- Logs to `security.log` file and console.
- Security events are stored in-memory, file, and database (`SecurityEvent` model).

### Database Models

All models inherit from SQLAlchemy's `Base`. Tables are created on startup.

- **User**: Stores user details (username, email, hashed password, verification status, reset tokens, login attempts).
- **File**: Stores file metadata (filename, folder, user ID, size, hash, MIME type, encryption status).
- **Favorite**: Tracks user-favorited files.
- **SharedFile**: Tracks files shared with users.
- **SharedFolder**: Tracks folders shared with users.
- **EncryptedFile**: Stores encryption details for files.
- **SecurityEvent**: Logs security events (type, severity, details, IP, etc.).
- **RenameFile**: History of file renames.
- **PasswordHistory**: Prevents password reuse.
- **UserSession**: Manages active sessions.
- **FileScan**: Stores file scan results.
- **AccessLog**: Logs API access.
- **UserGroup**: Defines user groups.
- **UserGroupMember**: Group memberships.
- **GroupSharedFile**: Files shared with groups.
- **GroupSharedFolder**: Folders shared with groups.

### Pydantic Models

Used for request/response validation:

- **CreateUserRequest**: For user registration (username, password, email).
- **CreateGroupRequest**: For group creation (name, description).
- **AddGroupMemberRequest**: Add member to group (group_name, user_identifier, is_admin).
- **RemoveGroupMemberRequest**: Remove member (group_name, username).
- **RenameFileRequest**: Rename file (old/new filename, folder).
- **ShareFileWithGroupRequest**: Share file with group (filename, folder, group_name).
- **ShareFolderWithGroupRequest**: Share folder with group (folder_path, group_name).
- **CreateFolderRequest**: Create folder (folder_name, username).
- **VerifyEmailRequest**: Verify email (code).
- **LoginRequest**: Login (email/username, password).
- **ListFilesRequest**: List files in folder (folder_name, username).
- **ListSharedFolderRequest**: List shared folder (folder_path, shared_by).
- **ResetPasswordRequest**: Request password reset (email).
- **ConfirmResetRequest**: Confirm reset (token, new_password).
- **ToggleFavoriteRequest**: Favorite/unfavorite file (filename, folder).
- **ShareFileRequest**: Share file with user (filename, folder, share_with).
- **ShareFolderRequest**: Share folder with user (folder_path, share_with).
- **UnshareFileRequest**: Unshare file from user (filename, folder, shared_with).
- **UnshareFolderRequest**: Unshare folder from user (folder_path, shared_with).
- **EncryptFileRequest**: Encrypt file (filename, folder, encryption_password).
- **DecryptFileRequest**: Decrypt file (filename, folder, decryption_password).
- **SecurityConfigRequest**: Update security config (various optional fields).
- **AuditLogRequest**: Query audit logs (filters like dates, event_type).

## Endpoints

All endpoints require appropriate authentication (API key or JWT where specified). Sensitive endpoints use middleware for security checks.

### User Management

- **POST /create_user**: Register new user. Validates password/email, sends verification email. Requires API key.
- **POST /verify/{email}**: Verify email with code. Creates user folder on success. Requires API key.
- **POST /login**: Authenticate user. Returns JWT on success. Handles lockouts.
- **POST /reset_password**: Request password reset. Sends email with token.
- **POST /confirm_reset**: Confirm password reset with token and new password.
- **DELETE /delete_user/{username}**: Delete user and their data. Requires JWT and API key.

### File/Folder Management

- **POST /create_folder**: Create folder for user. Requires API key.
- **POST /upload_file**: Upload file to folder. Validates size/type/content, scans for viruses. Requires API key.
- **DELETE /delete_file/{file_path}**: Delete file. Requires JWT and API key.
- **POST /rename_file**: Rename file. Logs history. Requires JWT.
- **POST /toggle_favorite**: Add/remove favorite. Requires JWT.
- **GET /list_files**: List files in folder. Requires JWT.
- **GET /list_folders**: List user's folders. Requires JWT.
- **GET /download/{file_path}**: Download file. Supports decryption. Requires JWT.
- **GET /download_folder/{folder_path}**: Download folder as ZIP. Requires JWT.
- **POST /encrypt_file**: Encrypt file with password. Requires JWT.
- **POST /decrypt_file**: Decrypt file with password. Requires JWT.

### Sharing

- **POST /share_file**: Share file with user (by email/username). Requires JWT.
- **POST /share_folder**: Share folder with user. Requires JWT.
- **POST /unshare_file**: Unshare file from user. Requires JWT.
- **POST /unshare_folder**: Unshare folder from user. Requires JWT.
- **GET /shared_files**: List files shared with current user. Requires JWT.
- **GET /shared_folders**: List folders shared with current user. Requires JWT.
- **GET /my_shared_files**: List files shared by current user. Requires JWT.
- **GET /my_shared_folders**: List folders shared by current user. Requires JWT.
- **GET /shared_folder_files**: List files in shared folder. Requires JWT.

### Group Management

- **POST /groups/create**: Create group. Creator becomes admin. Requires JWT.
- **POST /groups/add_member**: Add member to group (admin only). Requires JWT.
- **POST /groups/remove_member**: Remove member from group (admin only). Requires JWT.
- **GET /groups/list**: List user's groups. Requires JWT.
- **GET /groups/{group_name}/members**: List group members. Requires JWT (member access).
- **POST /groups/share_file**: Share file with group. Requires JWT (member access).
- **POST /groups/share_folder**: Share folder with group. Requires JWT (member access).
- **GET /groups/shared_files**: List files shared with user's groups. Requires JWT.
- **GET /groups/shared_folders**: List folders shared with user's groups. Requires JWT.
- **GET /groups/my_shared_files**: List files user shared with groups. Requires JWT.
- **GET /groups/my_shared_folders**: List folders user shared with groups. Requires JWT.

### Security/Admin

- **POST /security/update_config**: Update security settings (admin only). Requires JWT.
- **GET /security/audit_log**: Query audit logs (admin only). Requires JWT.
- **POST /security/block_ip**: Block IP address (admin only). Requires JWT.
- **POST /security/unblock_ip**: Unblock IP (admin only). Requires JWT.
- **GET /security/blocked_ips**: List blocked IPs (admin only). Requires JWT.
- **POST /security/cleanup_sessions**: Clean expired sessions (admin only). Requires JWT.
- **POST /security/scan_file**: Scan file for issues (admin only). Requires JWT.

## Helper Functions

- **validate_password**: Checks password complexity (12+ chars, mixed case, numbers, special chars, no patterns).
- **validate_email**: Validates email format using regex.
- **get_username_from_email_or_username**: Resolves identifier to username.
- **create_access_token/verify_access_token**: Handles JWT creation/validation.
- **encrypt_file_content/decrypt_file_content**: File encryption/decryption using Fernet.
- **log_security_event_enhanced**: Logs events to file and database.
- **validate_file_content/scan_file_for_viruses**: Heuristic file validation and virus scanning.
- **sanitize_input**: Prevents XSS and injection attacks.
- **rate_limit_check**: Implements per-IP/endpoint rate limiting.
- **cleanup_expired_sessions**: Removes expired sessions.

## Middleware

- **CORSMiddleware**: Allows all origins, methods, and headers.
- **add_security_headers**: Adds HTTP security headers (CSP, HSTS, X-Frame-Options, etc.).
- **rate_limit_middleware**: Limits requests on sensitive endpoints (/login, /create_user, etc.).
- **waf_middleware**: Blocks SQL injection, XSS, path traversal, and command injection attempts.
- **access_log_middleware**: Logs all requests with IP, method, path, status, and timing.
- **session_middleware**: Placeholder for session validation.

## Startup/Background Tasks

- Creates database tables on startup using SQLAlchemy's `Base.metadata.create_all`.
- Runs a periodic background task (`periodic_cleanup`) to clean expired sessions every hour.

## Instalation

### 1. Install Dependencies

```bash
# Install core security dependencies
pip install -r requirements.txt

```

### 2. Configure Enviroment Variables

Create the `.env` file:

```env
API_KEY="<your_api_key>"
EMAIL="<your_email>"
PASSWORD="<app_password_gmail>"
SECRET_KEY="<your_secret_key>"
ENCRYPTION_KEY="<your_encryption_key>"
BASE_URL="<your domain>"
SECURITY_LOG_LEVEL=INFO
ENABLE_VIRUS_SCANNING=true
ENABLE_ENCRYPTION=true
MAX_FILE_SIZE=104857600
SESSION_TIMEOUT_MINUTES=30
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_WINDOW=60
```

### Note

- **In password field do not put your gmail password. It must be app password more information [here](https://www.hostpapa.com/knowledgebase/how-to-create-and-use-google-app-passwords/)**
- **Highly recommend using [ngrok](https://ngrok.com/) for tunneling**

### 3. Start the server

```bash
# Hot reload start
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
# Normal start
uvicorn server:app --host 0.0.0.0 --port 8000

# Or optionally you can run it using
python server.py
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

```python
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
