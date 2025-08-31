"""
FastAPI backend for user and file management.

Endpoints:
1. /create_user (POST):
   - Register a new user (username, email, password, confirm_password).
   - Sends verification code to email.
   - Returns message about registration status.

2. /verify/{email} (POST):
   - Verifies user email with code.
   - On success, marks user as verified and creates user folder.

3. /login (POST):
   - Authenticates user (username, password).
   - Returns JWT token on success.

4. /create_folder (POST):
   - Creates a folder for a user (requires API key).

5. /upload_file (POST):
   - Uploads a file to a user's folder (requires API key).
   - Records file in database.

6. /delete_file/{file_path} (DELETE):
   - Deletes a file and its DB record (requires JWT token and API key).

7. /delete_user/{username} (DELETE):
   - Deletes user, their folder, and all files (requires JWT token and API key).

Security:
- API_KEY required in headers for most endpoints.
- JWT token required for file/user deletion.

Models:
- User: id, username, email, password (hashed), verified, verification_code
- File: id, filename, folder_name, user_id
"""

# Standard library imports
import os
import json
import random
import re  # Import regex module for password validation
import time
import secrets
import zipfile
import shutil
import hashlib
import logging
import smtplib
import ssl
import hmac
import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Tuple
from collections import defaultdict
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# Third-party imports
from fastapi import FastAPI, Request, HTTPException, Depends, UploadFile, Form, BackgroundTasks, Query
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi import File as FastAPIFile
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, validator, Field
from sqlalchemy import create_engine, Column, Integer, String, DateTime, UniqueConstraint, Boolean, Text
from sqlalchemy.orm import declarative_base, sessionmaker, Session
from sqlalchemy.exc import SQLAlchemyError
from dotenv import load_dotenv
import bcrypt
from jose import JWTError, jwt
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
import base64
import asyncio
import aiofiles
# import magic  # For MIME type detection - removed due to Windows compatibility issues
# Note: antivirus package not available - using basic heuristic scanning instead

# Local imports
# Email functionality moved from Emails.py

# Load environment variables
load_dotenv()

# Get environment variables
BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")

# Email configuration
email = os.getenv("EMAIL")
password = os.getenv("PASSWORD")

def send_verification_email(to_email, verification_code):
    """
    Sends a verification email to the user.

    Args:
        to_email (str): The recipient's email address.
        verification_code (str): The verification code to include in the email.
    """
    print(f"[DEBUG] Preparing to send email to {to_email} with verification code {verification_code}")
    if email and password:
        subject = "Email Verification"
        body = f"Your verification code is: {verification_code}"

        msg = MIMEMultipart()
        msg['Subject'] = subject
        msg['From'] = email
        msg['To'] = to_email

        msg.attach(MIMEText(body))

        try:
            with smtplib.SMTP('smtp.gmail.com', 587) as server:
                server.starttls()
                print("[DEBUG] Logging into SMTP server")
                server.login(email, password)
                server.send_message(msg)
                print(f"[DEBUG] Verification email sent to {to_email}")
        except Exception as e:
            print(f"[ERROR] Failed to send email to {to_email}: {e}")
    else:
        print("[ERROR] Email or password environment variables are not set.")

def send_reset_password_email(to_email, reset_token, base_url=os.getenv("BASE_URL")):
    """
    Sends a password reset email to the user.

    Args:
        to_email (str): The recipient's email address.
        reset_token (str): The reset token for password reset.
        base_url (str): The base URL for the application.
    """
    print(f"[DEBUG] Preparing to send password reset email to {to_email}")
    if email and password:
        subject = "Password Reset Request"

        reset_link = f"{base_url}/reset-password?token={reset_token}"
        
        body = f"""
        Hello,

        You have requested to reset your password for your account.

        To reset your password, please follow these steps:

        1. Open your Skysync application
        2. Go to "Forgot Password" page
        3. Enter the following reset token:
           {reset_token}

        OR click this link to copy the token:
        {reset_link}

        This token will expire in 1 hour for security reasons.

        If you did not request this password reset, please ignore this email.
        Your password will remain unchanged.

        Best regards,
        Your App Team

        ---
        This is an automated message, please do not reply to this email.
        """

        msg = MIMEMultipart()
        msg['Subject'] = subject
        msg['From'] = email
        msg['To'] = to_email

        msg.attach(MIMEText(body))

        try:
            with smtplib.SMTP('smtp.gmail.com', 587) as server:
                server.starttls()
                print("[DEBUG] Logging into SMTP server")
                server.login(email, password)
                server.send_message(msg)
                print(f"[DEBUG] Password reset email sent to {to_email}")
        except Exception as e:
            print(f"[ERROR] Failed to send password reset email to {to_email}: {e}")
    else:
        print("[ERROR] Email or password environment variables are not set.")

def send_account_deletion_email(to_email, deletion_token, base_url=os.getenv("BASE_URL")):
    """
    Sends an account deletion confirmation email to the user.

    Args:
        to_email (str): The recipient's email address.
        deletion_token (str): The deletion token for account deletion.
        base_url (str): The base URL for the application.
    """
    print(f"[DEBUG] Preparing to send account deletion email to {to_email}")
    if email and password:
        subject = "Account Deletion Request"

        deletion_link = f"{base_url}/delete-account?token={deletion_token}"
        
        body = f"""
        Hello,

        You have requested to delete your account permanently.

        To confirm account deletion, please follow these steps:

        1. Open your Skysync application
        2. Go to "Delete Account" page
        3. Enter the following deletion token:
           {deletion_token}

        OR click this link to copy the token:
        {deletion_link}

        ⚠️  WARNING: This action is IRREVERSIBLE!
        - All your files will be permanently deleted
        - All your data will be permanently removed
        - This action cannot be undone

        This token will expire in 1 hour for security reasons.

        If you did not request this account deletion, please ignore this email.
        Your account will remain unchanged.

        Best regards,
        Your App Team

        ---
        This is an automated message, please do not reply to this email.
        """

        msg = MIMEMultipart()
        msg['Subject'] = subject
        msg['From'] = email
        msg['To'] = to_email

        msg.attach(MIMEText(body))

        try:
            with smtplib.SMTP('smtp.gmail.com', 587) as server:
                server.starttls()
                print("[DEBUG] Logging into SMTP server")
                server.login(email, password)
                server.send_message(msg)
                print(f"[DEBUG] Account deletion email sent to {to_email}")
        except Exception as e:
            print(f"[ERROR] Failed to send account deletion email to {to_email}: {e}")
    else:
        print("[ERROR] Email or password environment variables are not set.")

# Alias for backward compatibility
send_email = send_verification_email

# Security configuration
MAX_LOGIN_ATTEMPTS = 5
LOGIN_LOCKOUT_DURATION = 15  # minutes
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
BLOCKED_FILE_EXTENSIONS = {
    '.exe', '.bat', '.cmd', '.com', '.pif', '.scr', '.vbs', '.js', '.jar',
    '.msi', '.dmg', '.app', '.sh', '.php', '.asp', '.aspx', '.jsp'
}

# Enhanced security configuration
SECURITY_CONFIG = {
    'max_request_size': 25 * 1024 * 1024,  # 25MB
    'max_files_per_upload': 100,
    'session_timeout_minutes': 30,
    'password_history_size': 5,
    'max_failed_attempts_per_hour': 10,
    'account_lockout_threshold': 5,
    'account_lockout_duration': 30,  # minutes
    'session_inactivity_timeout': 10,  # minutes
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

# Rate limiting for password reset and login attempts
reset_attempts = {}
deletion_attempts = {}
login_attempts = defaultdict(list)
blocked_ips = {}
session_store = {}
user_sessions = defaultdict(list)
file_upload_attempts = defaultdict(list)
security_events = []

# Security logging with enhanced configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - [%(ip)s] [%(user)s] %(message)s',
    handlers=[
        logging.FileHandler('security.log'),
        logging.StreamHandler()
    ]
)
security_logger = logging.getLogger('security')

# Add custom filter for IP and user logging
class SecurityLogFilter(logging.Filter):
    def filter(self, record):
        record.ip = getattr(record, 'ip', 'unknown')
        record.user = getattr(record, 'user', 'unknown')
        return True

security_logger.addFilter(SecurityLogFilter())

# -----------------------------------
# Database Configuration
# -----------------------------------
DATABASE_URL = "sqlite:///server.db"
engine = create_engine(DATABASE_URL)
Base = declarative_base()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# -----------------------------------
# FastAPI Application Setup
# -----------------------------------
app = FastAPI()

# Middleware for CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    
    # Enhanced security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = SECURITY_CONFIG['referrer_policy']
    response.headers["Strict-Transport-Security"] = f"max-age={SECURITY_CONFIG['hsts_max_age']}; includeSubDomains"
    response.headers["Content-Security-Policy"] = SECURITY_CONFIG['content_security_policy']
    response.headers["Permissions-Policy"] = SECURITY_CONFIG['permissions_policy']
    
    # Additional security headers
    response.headers["X-Download-Options"] = "noopen"
    response.headers["X-Permitted-Cross-Domain-Policies"] = "none"
    response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    
    if "Server" in response.headers:
        del response.headers["Server"]
    
    return response

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = get_real_ip(request)
    
    # Check if IP is blocked
    if client_ip in blocked_ips:
        block_until = blocked_ips[client_ip]
        if datetime.now() < block_until:
            log_security_event_enhanced(
                "rate_limit_blocked", 
                f"Blocked request from IP: {client_ip}",
                severity="medium",
                user_ip=client_ip,
                request_path=str(request.url.path),
                request_method=request.method
            )
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Please try again later."}
            )
        else:
            del blocked_ips[client_ip]

    sensitive_endpoints = ["/login", "/create_user", "/reset_password", "/upload_file", "delete_account"]
    if request.url.path in sensitive_endpoints:
        current_time = datetime.now()
        if client_ip in login_attempts:
            login_attempts[client_ip] = [
                attempt for attempt in login_attempts[client_ip]
                if current_time - attempt < timedelta(minutes=1)
            ]
            
            max_attempts = SECURITY_CONFIG['max_failed_attempts_per_hour']
            if len(login_attempts[client_ip]) >= max_attempts:
                blocked_ips[client_ip] = current_time + timedelta(minutes=SECURITY_CONFIG['account_lockout_duration'])
                log_security_event_enhanced(
                    "ip_blocked", 
                    f"IP {client_ip} blocked for {SECURITY_CONFIG['account_lockout_duration']} minutes due to rate limiting",
                    severity="high",
                    user_ip=client_ip,
                    request_path=str(request.url.path),
                    request_method=request.method
                )
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many requests. Please try again later."}
                )
        
        login_attempts[client_ip].append(current_time)
    
    response = await call_next(request)
    return response

@app.middleware("http")
async def waf_middleware(request: Request, call_next):
    """
    Enhanced Web Application Firewall middleware to detect and block malicious requests.
    """
    client_ip = get_real_ip(request)
    user_agent = request.headers.get("user-agent", "")
    
    # Enhanced SQL Injection detection patterns
    sql_patterns = [
        r"(\b(union|select|insert|update|delete|drop|alter|exec|execute)\b)",
        r"(\b(or|and)\b\s+\d+\s*=\s*\d+)",
        r"(\b(union|select)\b.*\bfrom\b)",
        r"(--|#|/\*|\*/)",
        r"(\bxp_cmdshell\b|\bsp_executesql\b)",
        r"(\bwaitfor\b\s+delay)",
        r"(\bcast\b|\bconvert\b)",
        r"(\bchar\b\s*\(\s*\d+)",
        r"(\bconcat\b\s*\()",
        r"(\bgroup\s+by\b.*\bhaving\b)",
    ]
    
    # Enhanced XSS detection patterns
    xss_patterns = [
        r"(<script[^>]*>.*?</script>)",
        r"(javascript:.*)",
        r"(on\w+\s*=)",
        r"(<iframe[^>]*>)",
        r"(<object[^>]*>)",
        r"(<embed[^>]*>)",
        r"(<form[^>]*>)",
        r"(<input[^>]*>)",
        r"(<textarea[^>]*>)",
        r"(<select[^>]*>)",
        r"(<link[^>]*>)",
        r"(<meta[^>]*>)",
        r"(<style[^>]*>)",
        r"(<base[^>]*>)",
        r"(<bgsound[^>]*>)",
        r"(<applet[^>]*>)",
        r"(<marquee[^>]*>)",
        r"(<xmp[^>]*>)",
        r"(<plaintext[^>]*>)",
        r"(<listing[^>]*>)",
    ]
    
    # Enhanced path traversal patterns
    path_patterns = [
        r"(\.\./|\.\.\\)",
        r"(/%2e%2e/|%2e%2e/)",
        r"(\.\.%2f|\.\.%5c)",
        r"(\.\.%252f|\.\.%255c)",
        r"(\.\.%c0%af|\.\.%c1%9c)",
        r"(\.\.%c0%2f|\.\.%c1%af)",
        r"(\.\.%252e%252e)",
        r"(\.\.%2e%2e)",
        r"(\.\.%252e%2e)",
        r"(\.\.%2e%252e)",
    ]
    
    # Command injection patterns
    cmd_patterns = [
        r"(\b(cmd|command|exec|execute|system|shell|bash|sh|powershell|powershell\.exe)\b)",
        r"(\b(ping|nslookup|traceroute|tracert|netstat|ipconfig|ifconfig)\b)",
        r"(\b(wget|curl|nc|netcat|telnet|ftp|ssh|scp)\b)",
        r"(\b(rm|del|erase|format|fdisk|chkdsk)\b)",
        r"(\b(cat|type|more|less|head|tail|grep|find)\b)",
        r"(\b(echo|print|printf|sprintf)\b)",
        r"(\b(ls|dir|pwd|cd|mkdir|rmdir|cp|copy|mv|move)\b)",
    ]
    
    # Check URL path and query
    url_path = str(request.url.path)
    url_query = str(request.url.query)
    
    # Whitelist for legitimate API endpoints that might contain SQL keywords
    legitimate_endpoints = [
        "/groups/create",
        "/groups/add_member", 
        "/groups/remove_member",
        "/groups/list",
        "/groups/share_file",
        "/groups/share_folder",
        "/groups/shared_files",
        "/groups/shared_folders",
        "/create_user",
        "/create_folder",
        "/create_quick_share",
        "/security/update_config",
        "/security/audit_log",
        "/security/block_ip",
        "/security/unblock_ip",
        "/security/blocked_ips",
        "/security/cleanup_sessions",
        "/security/scan_file",
        "/security/status"
    ]
    
    if url_path in legitimate_endpoints:
        response = await call_next(request)
        return response
    
    # Check for malicious patterns
    all_patterns = sql_patterns + xss_patterns + path_patterns + cmd_patterns
    
    for pattern in all_patterns:
        if re.search(pattern, url_path, re.IGNORECASE) or re.search(pattern, url_query, re.IGNORECASE):
            log_security_event_enhanced(
                "waf_blocked", 
                f"WAF blocked request: {pattern} in {url_path}",
                severity="high",
                user_ip=client_ip,
                user_agent=user_agent,
                request_path=url_path,
                request_method=request.method
            )
            return JSONResponse(
                status_code=403,
                content={"detail": "Request blocked by security policy"}
            )
    
    # Enhanced user agent validation
    suspicious_agents = [
        "sqlmap", "nikto", "nmap", "scanner", "bot", "crawler", "spider",
        "curl", "wget", "python-requests", "go-http-client", "java-http-client",
        "masscan", "zmap", "dirb", "dirbuster", "gobuster", "wfuzz",
        "burp", "zap", "acunetix", "nessus", "openvas", "qualys"
    ]
    
    user_agent_lower = user_agent.lower()
    for suspicious in suspicious_agents:
        if suspicious in user_agent_lower:
            log_security_event_enhanced(
                "waf_blocked", 
                f"WAF blocked suspicious user agent: {user_agent}",
                severity="medium",
                user_ip=client_ip,
                user_agent=user_agent,
                request_path=url_path,
                request_method=request.method
            )
            return JSONResponse(
                status_code=403,
                content={"detail": "Request blocked by security policy"}
            )
    
    # Check for suspicious headers (excluding legitimate proxy headers)
    suspicious_headers = [
        "x-forwarded-server", "x-forwarded-uri",
        "x-original-url", "x-rewrite-url", "x-custom-ip-authorization"
    ]
    
    for header in suspicious_headers:
        if header in request.headers:
            log_security_event_enhanced(
                "suspicious_header", 
                f"Suspicious header detected: {header}",
                severity="medium",
                user_ip=client_ip,
                user_agent=user_agent,
                request_path=url_path,
                request_method=request.method
            )
    
    # Log x-forwarded-host but don't treat it as suspicious (it's a legitimate proxy header)
    if "x-forwarded-host" in request.headers:
        log_security_event_enhanced(
            "proxy_header_detected", 
            f"Proxy header detected: x-forwarded-host",
            severity="low",
            user_ip=client_ip,
            user_agent=user_agent,
            request_path=url_path,
            request_method=request.method
        )
    
    response = await call_next(request)
    return response

# Access logging middleware
@app.middleware("http")
async def access_log_middleware(request: Request, call_next):
    start_time = time.time()
    
    response = await call_next(request)
    
    # Calculate request time
    request_time = int((time.time() - start_time) * 1000)  # Convert to milliseconds
    
    # Get client IP
    client_ip = get_real_ip(request)
    
    # Log access (could be stored in database)
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "ip_address": client_ip,
        "request_method": request.method,
        "request_path": str(request.url.path),
        "status_code": response.status_code,
        "user_agent": request.headers.get("user-agent", ""),
        "request_time": request_time
    }
    
    # Log to file
    security_logger.info(f"ACCESS_LOG: {json.dumps(log_entry)}")
    
    return response

# Session management middleware
@app.middleware("http")
async def session_middleware(request: Request, call_next):
    # This middleware would handle session validation
    # For now, we'll just pass through
    response = await call_next(request)
    return response

# Security utility functions
def log_security_event(event_type: str, details: str, user_ip: str = None, username: str = None):
    """Log security events for audit purposes."""
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "event_type": event_type,
        "details": details,
        "user_ip": user_ip,
        "username": username
    }
    security_logger.info(f"SECURITY_EVENT: {json.dumps(log_entry)}")

def validate_file_extension(filename: str) -> bool:
    """Validate if file extension is not blocked."""
    if not filename:
        return False
    
    file_ext = os.path.splitext(filename.lower())[1]
    
    # Sprawdzamy tylko czy rozszerzenie nie jest na blackliście
    if file_ext in BLOCKED_FILE_EXTENSIONS:
        return False
    
    return True

def sanitize_filename(filename: str) -> str:
    """Sanitize filename to prevent path traversal and XSS."""
    # Remove path traversal characters
    filename = filename.replace('..', '').replace('/', '').replace('\\', '')
    
    # Remove potentially dangerous characters
    dangerous_chars = ['<', '>', ':', '"', '|', '?', '*', '\0']
    for char in dangerous_chars:
        filename = filename.replace(char, '')
    
    # Limit length
    if len(filename) > 255:
        name, ext = os.path.splitext(filename)
        filename = name[:255-len(ext)] + ext
    
    return filename

def validate_path_safety(path: str) -> bool:
    """Validate if path is safe and doesn't contain path traversal."""
    # Normalize path
    normalized_path = os.path.normpath(path)
    
    # Check for path traversal attempts
    if '..' in normalized_path or normalized_path.startswith('/'):
        return False
    
    # Check if path is within allowed directory
    base_dir = os.getcwd()
    full_path = os.path.abspath(os.path.join(base_dir, normalized_path))
    
    if not full_path.startswith(base_dir):
        return False
    
    return True

def hash_file_content(content: bytes) -> str:
    """Generate SHA-256 hash of file content for integrity checking."""
    return hashlib.sha256(content).hexdigest()

# -----------------------------------
# Database Models
# -----------------------------------
class User(Base):
    """
    SQLAlchemy model for users.

    Attributes:
        id (int): Primary key.
        username (str): Unique username.
        email (str): Unique email address.
        password (str): Hashed password.
        verified (int): 1 if email verified, 0 otherwise.
        verification_code (str): Code sent for email verification.
        reset_token (str): Token for password reset.
        reset_token_expiry (datetime): Expiry time for reset token.
        deletion_token (str): Token for account deletion.
        deletion_token_expiry (datetime): Expiry time for deletion token.
        failed_login_attempts (int): Number of failed login attempts.
        account_locked_until (datetime): When account is locked until.
        last_login (datetime): Last successful login time.
        is_active (bool): Whether account is active.
        created_at (datetime): Account creation time.
    """
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, nullable=False)
    email = Column(String, unique=True, nullable=False)
    password = Column(String, nullable=False)
    verified = Column(Integer, default=0)
    verification_code = Column(String, nullable=True)
    reset_token = Column(String, nullable=True)
    reset_token_expiry = Column(DateTime, nullable=True)
    deletion_token = Column(String, nullable=True)
    deletion_token_expiry = Column(DateTime, nullable=True)
    failed_login_attempts = Column(Integer, default=0)
    account_locked_until = Column(DateTime, nullable=True)
    last_login = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class File(Base):
    """
    SQLAlchemy model for uploaded files.

    Attributes:
        id (int): Primary key.
        filename (str): File name.
        folder_name (str): Folder where file is stored.
        user_id (int): ID of the user who owns the file.
        file_size (int): File size in bytes.
        file_hash (str): SHA-256 hash of file content.
        mime_type (str): MIME type of the file.
        uploaded_at (datetime): When file was uploaded.
        is_encrypted (bool): Whether file is encrypted.
    """
    __tablename__ = 'files'
    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String, nullable=False)
    folder_name = Column(String, nullable=False)
    user_id = Column(Integer, nullable=False)
    file_size = Column(Integer, nullable=False)
    file_hash = Column(String, nullable=False)
    mime_type = Column(String, nullable=True)
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    is_encrypted = Column(Boolean, default=False)

class Favorite(Base):
    """
    SQLAlchemy model for favorite files.

    Attributes:
        id (int): Primary key.
        user_id (int): ID of the user who favorited the file.
        file_id (int): ID of the favorited file.
        created_at (datetime): When the file was favorited.
    """
    __tablename__ = 'favorites'
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    file_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Unique constraint to prevent duplicate favorites
    __table_args__ = (UniqueConstraint('user_id', 'file_id', name='unique_user_file_favorite'),)

class SharedFile(Base):
    """
    SQLAlchemy model for shared files.

    Attributes:
        id (int): Primary key.
        original_file_id (int): ID of the original file.
        shared_with_user_id (int): ID of the user the file is shared with.
        shared_by_user_id (int): ID of the user who shared the file.
        created_at (datetime): When the file was shared.
    """
    __tablename__ = 'shared_files'
    id = Column(Integer, primary_key=True, index=True)
    original_file_id = Column(Integer, nullable=False)
    shared_with_user_id = Column(Integer, nullable=False)
    shared_by_user_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Unique constraint to prevent duplicate shares
    __table_args__ = (UniqueConstraint('original_file_id', 'shared_with_user_id', name='unique_shared_file'),)

class SharedFolder(Base):
    """
    SQLAlchemy model for shared folders.

    Attributes:
        id (int): Primary key.
        folder_path (str): Path to the shared folder.
        shared_with_user_id (int): ID of the user the folder is shared with.
        shared_by_user_id (int): ID of the user who shared the folder.
        created_at (datetime): When the folder was shared.
    """
    __tablename__ = 'shared_folders'
    id = Column(Integer, primary_key=True, index=True)
    folder_path = Column(String, nullable=False)
    shared_with_user_id = Column(Integer, nullable=False)
    shared_by_user_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Unique constraint to prevent duplicate shares
    __table_args__ = (UniqueConstraint('folder_path', 'shared_with_user_id', name='unique_shared_folder'),)

class EncryptedFile(Base):
    """
    SQLAlchemy model for encrypted files.

    Attributes:
        id (int): Primary key.
        file_id (int): ID of the associated file.
        encryption_salt (str): Salt used for encryption (base64 encoded).
        encryption_algorithm (str): Algorithm used for encryption.
        created_at (datetime): When the file was encrypted.
    """
    __tablename__ = 'encrypted_files'
    id = Column(Integer, primary_key=True, index=True)
    file_id = Column(Integer, nullable=False)
    encryption_salt = Column(String, nullable=False)  # base64 encoded salt
    encryption_algorithm = Column(String, default="Fernet")
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Foreign key relationship
    __table_args__ = (UniqueConstraint('file_id', name='unique_encrypted_file'),)

class SecurityEvent(Base):
    """
    SQLAlchemy model for security events logging.
    
    Attributes:
        id (int): Primary key.
        event_type (str): Type of security event.
        severity (str): Event severity (low, medium, high, critical).
        details (str): Event details.
        user_ip (str): IP address of the user.
        username (str): Username if authenticated.
        user_agent (str): User agent string.
        request_path (str): Request path.
        request_method (str): HTTP method.
        timestamp (datetime): When the event occurred.
        resolved (bool): Whether the event was resolved.
        resolution_notes (str): Notes about resolution.
    """
    __tablename__ = 'security_events'
    id = Column(Integer, primary_key=True, index=True)
    event_type = Column(String, nullable=False)
    severity = Column(String, nullable=False)
    details = Column(Text, nullable=False)
    user_ip = Column(String, nullable=True)
    username = Column(String, nullable=True)
    user_agent = Column(String, nullable=True)
    request_path = Column(String, nullable=True)
    request_method = Column(String, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    resolved = Column(Boolean, default=False)
    resolution_notes = Column(Text, nullable=True)
    
class RenameFile(Base):
    """
    SQLAlchemy model for file renaming history.
    
    Attributes:
        id (int): Primary key.
        file_id (int): ID of the file that was renamed.
        old_filename (str): Previous file name.
        new_filename (str): New file name.
        renamed_by_user_id (int): ID of the user who renamed the file.
        renamed_at (datetime): When the file was renamed.
    """
    __tablename__ = 'rename_history'
    id = Column(Integer, primary_key=True, index=True)
    file_id = Column(Integer, nullable=False)
    old_filename = Column(String, nullable=False)
    new_filename = Column(String, nullable=False)
    renamed_by_user_id = Column(Integer, nullable=False)
    renamed_at = Column(DateTime, default=datetime.utcnow)

class PasswordHistory(Base):
    """
    SQLAlchemy model for password history to prevent reuse.
    
    Attributes:
        id (int): Primary key.
        user_id (int): ID of the user.
        password_hash (str): Hashed password.
        created_at (datetime): When password was set.
    """
    __tablename__ = 'password_history'
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    password_hash = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class UserSession(Base):
    """
    SQLAlchemy model for user sessions.
    
    Attributes:
        id (int): Primary key.
        user_id (int): ID of the user.
        session_id (str): Unique session identifier.
        token_hash (str): Hashed JWT token.
        ip_address (str): IP address of the session.
        user_agent (str): User agent string.
        created_at (datetime): When session was created.
        last_activity (datetime): Last activity timestamp.
        expires_at (datetime): When session expires.
        is_active (bool): Whether session is active.
    """
    __tablename__ = 'user_sessions'
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    session_id = Column(String, unique=True, nullable=False)
    token_hash = Column(String, nullable=False)
    ip_address = Column(String, nullable=False)
    user_agent = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_activity = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True)

class FileScan(Base):
    """
    SQLAlchemy model for file scan results.
    
    Attributes:
        id (int): Primary key.
        file_id (int): ID of the scanned file.
        scan_type (str): Type of scan (virus, malware, etc.).
        scan_result (str): Result of the scan.
        scan_details (str): Detailed scan information.
        scanned_at (datetime): When scan was performed.
        is_clean (bool): Whether file is clean.
    """
    __tablename__ = 'file_scans'
    id = Column(Integer, primary_key=True, index=True)
    file_id = Column(Integer, nullable=False)
    scan_type = Column(String, nullable=False)
    scan_result = Column(String, nullable=False)
    scan_details = Column(Text, nullable=True)
    scanned_at = Column(DateTime, default=datetime.utcnow)
    is_clean = Column(Boolean, default=True)

class AccessLog(Base):
    """
    SQLAlchemy model for access logging.
    
    Attributes:
        id (int): Primary key.
        user_id (int): ID of the user (if authenticated).
        ip_address (str): IP address.
        request_method (str): HTTP method.
        request_path (str): Request path.
        status_code (int): HTTP status code.
        user_agent (str): User agent string.
        request_time (float): Request processing time.
        timestamp (datetime): When request was made.
    """
    __tablename__ = 'access_logs'
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)
    ip_address = Column(String, nullable=False)
    request_method = Column(String, nullable=False)
    request_path = Column(String, nullable=False)
    status_code = Column(Integer, nullable=False)
    user_agent = Column(String, nullable=True)
    request_time = Column(Integer, nullable=True)  # in milliseconds
    timestamp = Column(DateTime, default=datetime.utcnow)

class UserGroup(Base):
    """
    SQLAlchemy model for user groups.
    
    Attributes:
        id (int): Primary key.
        name (str): Group name.
        description (str): Group description.
        created_by_user_id (int): ID of the user who created the group.
        created_at (datetime): When the group was created.
        is_active (bool): Whether the group is active.
    """
    __tablename__ = 'user_groups'
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    description = Column(Text, nullable=True)
    created_by_user_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=True)

class UserGroupMember(Base):
    """
    SQLAlchemy model for group memberships.
    
    Attributes:
        id (int): Primary key.
        group_id (int): ID of the group.
        user_id (int): ID of the user.
        added_by_user_id (int): ID of the user who added the member.
        added_at (datetime): When the user was added to the group.
        is_admin (bool): Whether the user is an admin of the group.
    """
    __tablename__ = 'user_group_members'
    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, nullable=False)
    user_id = Column(Integer, nullable=False)
    added_by_user_id = Column(Integer, nullable=False)
    added_at = Column(DateTime, default=datetime.utcnow)
    is_admin = Column(Boolean, default=False)
    
    # Unique constraint to prevent duplicate memberships
    __table_args__ = (UniqueConstraint('group_id', 'user_id', name='unique_group_member'),)

class GroupSharedFile(Base):
    """
    SQLAlchemy model for files shared with groups.
    
    Attributes:
        id (int): Primary key.
        original_file_id (int): ID of the original file.
        shared_with_group_id (int): ID of the group the file is shared with.
        shared_by_user_id (int): ID of the user who shared the file.
        created_at (datetime): When the file was shared.
    """
    __tablename__ = 'group_shared_files'
    id = Column(Integer, primary_key=True, index=True)
    original_file_id = Column(Integer, nullable=False)
    shared_with_group_id = Column(Integer, nullable=False)
    shared_by_user_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Unique constraint to prevent duplicate shares
    __table_args__ = (UniqueConstraint('original_file_id', 'shared_with_group_id', name='unique_group_shared_file'),)

class GroupSharedFolder(Base):
    """
    SQLAlchemy model for folders shared with groups.
    
    Attributes:
        id (int): Primary key.
        folder_path (str): Path to the shared folder.
        shared_with_group_id (int): ID of the group the folder is shared with.
        shared_by_user_id (int): ID of the user who shared the folder.
        created_at (datetime): When the folder was shared.
    """
    __tablename__ = 'group_shared_folders'
    id = Column(Integer, primary_key=True, index=True)
    folder_path = Column(String, nullable=False)
    shared_with_group_id = Column(Integer, nullable=False)
    shared_by_user_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Unique constraint to prevent duplicate shares
    __table_args__ = (UniqueConstraint('folder_path', 'shared_with_group_id', name='unique_group_shared_folder'),)

Base.metadata.create_all(bind=engine)

# Initialize security logging
security_logger.info("Server started with enhanced security features")
security_logger.info(f"Max file size: {MAX_FILE_SIZE // (1024*1024)}MB")
security_logger.info(f"Blocked file extensions: {len(BLOCKED_FILE_EXTENSIONS)}")

# -----------------------------------
# Pydantic Models
# -----------------------------------
class CreateUserRequest(BaseModel):
    """
    Pydantic model for user registration request with enhanced validation.

    Fields:
        username (str): Username.
        password (str): Password.
        email (str): User's email address.
    """
    username: str = Field(..., min_length=3, max_length=50, pattern=r'^[a-zA-Z0-9_]+$')
    password: str = Field(..., min_length=12, max_length=128)
    email: str = Field(..., pattern=r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')

class CreateGroupRequest(BaseModel):
    """
    Pydantic model for group creation request.
    
    Fields:
        name (str): Group name.
        description (str): Group description.
    """
    name: str = Field(..., min_length=2, max_length=100, pattern=r'^[a-zA-Z0-9_\-\s]+$')
    description: str = Field(None, max_length=500)

class AddGroupMemberRequest(BaseModel):
    """
    Pydantic model for adding member to group.
    
    Fields:
        group_name (str): Group name.
        user_identifier (str): Username or email to add.
        is_admin (bool): Whether the user should be admin.
    """
    group_name: str = Field(..., min_length=2, max_length=100)
    user_identifier: str = Field(..., min_length=3, max_length=100)  # Username or email
    is_admin: bool = Field(False)

class RemoveGroupMemberRequest(BaseModel):
    """
    Pydantic model for removing member from group.
    
    Fields:
        group_name (str): Group name.
        username (str): Username to remove.
    """
    group_name: str = Field(..., min_length=2, max_length=100)
    username: str = Field(..., min_length=3, max_length=50, pattern=r'^[a-zA-Z0-9_]+$')
    
class RenameFileRequest(BaseModel):
    """
    Pydantic model for renaming a file.
    
    Fields:
        old_filename (str): Current file name.
        new_filename (str): New file name.
        folder_name (str): Folder where the file is located.
    """
    old_filename: str = Field(..., min_length=1, max_length=255)
    new_filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)

class ShareFileWithGroupRequest(BaseModel):
    """
    Pydantic model for sharing file with group.
    
    Fields:
        filename (str): File name.
        folder_name (str): Folder name.
        group_name (str): Group name.
    """
    filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)
    group_name: str = Field(..., min_length=2, max_length=100)

class ShareFolderWithGroupRequest(BaseModel):
    """
    Pydantic model for sharing folder with group.
    
    Fields:
        folder_path (str): Folder path.
        group_name (str): Group name.
    """
    folder_path: str = Field(..., min_length=1, max_length=255)
    group_name: str = Field(..., min_length=2, max_length=100)

class UnshareFileFromGroupRequest(BaseModel):
    """
    Pydantic model for unsharing file from group.
    
    Fields:
        filename (str): File name.
        folder_name (str): Folder name.
        group_name (str): Group name.
    """
    filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)
    group_name: str = Field(..., min_length=2, max_length=100)

class UnshareFolderFromGroupRequest(BaseModel):
    """
    Pydantic model for unsharing folder from group.
    
    Fields:
        folder_path (str): Folder path.
        group_name (str): Group name.
    """
    folder_path: str = Field(..., min_length=1, max_length=255)
    group_name: str = Field(..., min_length=2, max_length=100)
    
folder_regex = re.compile(r'^[\w\-\s/]+$', re.UNICODE)

class CreateFolderRequest(BaseModel):
    """
    Pydantic model for folder creation request with enhanced validation.

    Fields:
        folder_name (str): Name of the folder to create (default: 'Folder').
        username (str): Username of the folder owner.
    """
    folder_name: str = Field(..., min_length=1, max_length=255)
    username: str = Field(..., min_length=3, max_length=50, pattern=r'^[a-zA-Z0-9_]+$')
    
    @validator('folder_name')
    def validate_folder_name(cls, v):
        if not folder_regex.match(v):
            raise ValueError('Folder name can only contain letters, numbers, underscores, hyphens, spaces, and forward slashes')
        return v.strip()

class VerifyEmailRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=6, pattern=r'^[0-9]{6}$')

class LoginRequest(BaseModel):
    email: str = Field(..., min_length=1, max_length=100)  # Accept both email and username
    password: str = Field(..., min_length=1, max_length=128)
    
    @validator('email')
    def validate_email(cls, v):
        # Only convert to lowercase if it looks like an email (contains @)
        if '@' in v:
            return v.lower()
        # If it's a username, keep the original case
        return v

class ListFilesRequest(BaseModel):
    folder_name: str = Field(..., min_length=1, max_length=255)
    username: str = Field(..., min_length=3, max_length=50, pattern=r'^[a-zA-Z0-9_]+$')

class ListSharedFolderRequest(BaseModel):
    folder_path: str = Field(..., min_length=1, max_length=255)
    shared_by: str = Field(..., min_length=3, max_length=50, pattern=r'^[a-zA-Z0-9_]+$')

class ResetPasswordRequest(BaseModel):
    email: str = Field(..., pattern=r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')
    
    @validator('email')
    def validate_email(cls, v):
        return v.lower()

class ConfirmResetRequest(BaseModel):
    token: str = Field(..., min_length=32, max_length=64)
    new_password: str = Field(..., min_length=12, max_length=128)

class ToggleFavoriteRequest(BaseModel):
    filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)

class ShareFileRequest(BaseModel):
    filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)
    share_with: str = Field(..., min_length=1, max_length=100)  # email or username

class ShareFolderRequest(BaseModel):
    folder_path: str = Field(..., min_length=1, max_length=255)
    share_with: str = Field(..., min_length=1, max_length=100)  # email or username

class UnshareFileRequest(BaseModel):
    filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)
    shared_with: str = Field(..., min_length=1, max_length=100)  # email or username

class UnshareFolderRequest(BaseModel):
    folder_path: str = Field(..., min_length=1, max_length=255)
    shared_with: str = Field(..., min_length=1, max_length=100)  # email or username

class EncryptFileRequest(BaseModel):
    filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)
    encryption_password: str = Field(..., min_length=8, max_length=128)

class DecryptFileRequest(BaseModel):
    filename: str = Field(..., min_length=1, max_length=255)
    folder_name: str = Field(..., min_length=1, max_length=255)
    decryption_password: str = Field(..., min_length=8, max_length=128)

class SecurityConfigRequest(BaseModel):
    """Request model for security configuration updates."""
    max_file_size: Optional[int] = Field(None, ge=1024*1024, le=1024*1024*1024)  # 1MB to 1GB
    max_login_attempts: Optional[int] = Field(None, ge=3, le=10)
    session_timeout_minutes: Optional[int] = Field(None, ge=5, le=1440)  # 5 minutes to 24 hours
    enable_virus_scanning: Optional[bool] = None
    enable_encryption: Optional[bool] = None

class AuditLogRequest(BaseModel):
    """Request model for audit log queries."""
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    event_type: Optional[str] = None
    severity: Optional[str] = Field(None, pattern=r'^(low|medium|high|critical)$')
    username: Optional[str] = None
    limit: Optional[int] = Field(None, ge=1, le=1000)
    offset: Optional[int] = Field(None, ge=0)

class RequestAccountDeletionRequest(BaseModel):
    email: str = Field(..., pattern=r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')
    
    @validator('email')
    def validate_email(cls, v):
        return v.lower()

class ConfirmAccountDeletionRequest(BaseModel):
    token: str = Field(..., min_length=32, max_length=64)

# -----------------------------------
# Helper Functions
# -----------------------------------
def get_db():
    """
    Dependency for getting a SQLAlchemy session.
    Yields:
        db (Session): SQLAlchemy session.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def validate_password(password: str) -> bool:
    """
    Validate password complexity with enhanced security:
    - At least 12 characters
    - At least one uppercase, one lowercase, one digit, one special character
    - No common patterns or dictionary words
    - Maximum length of 128 characters
    Args:
        password (str): Password to validate.
    Returns:
        bool: True if valid, False otherwise.
    """
    if len(password) < 12 or len(password) > 128:
        return False
    
    # Check for required character types
    if not re.search(r"[A-Z]", password):
        return False
    if not re.search(r"[a-z]", password):
        return False
    if not re.search(r"[0-9]", password):
        return False
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>_\-+=~`]", password):
        return False
    
    # Check for common patterns
    if re.search(r"(.)\1{2,}", password):  # No repeated characters more than 2 times
        return False
    
    # Check for sequential patterns
    if re.search(r"(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)", password.lower()):
        return False
    
    # Check for keyboard patterns
    keyboard_patterns = [
        "qwerty", "asdfgh", "zxcvbn", "123456", "654321",
        "password", "admin", "user", "test", "guest"
    ]
    
    for pattern in keyboard_patterns:
        if pattern in password.lower():
            return False
    
    return True

def validate_email(email: str) -> bool:
    """
    Validate email format using regex.
    Args:
        email (str): Email to validate.
    Returns:
        bool: True if valid, False otherwise.
    """
    email_regex = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
    return re.match(email_regex, email) is not None

def validate_new_password(password: str) -> bool:
    """
    Validate new password strength with enhanced security.
    Args:
        password (str): Password to validate.
    Returns:
        bool: True if valid, False otherwise.
    """
    return validate_password(password)

def get_username_from_email_or_username(identifier: str, db: Session) -> str:
    """
    Get username from identifier (email or username).
    Args:
        identifier (str): Email or username.
        db (Session): Database session.
    Returns:
        str: Username.
    Raises:
        HTTPException: 404 if user not found.
    """
    if '@' in identifier:
        # To jest email, znajdź użytkownika po emailu
        user = db.query(User).filter(User.email == identifier).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return user.username
    else:
        # To jest username, sprawdź czy istnieje
        user = db.query(User).filter(User.username == identifier).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        return user.username

async def require_api_key(request: Request):
    """
    Dependency to check API_KEY in request headers.
    Raises HTTPException(403) if missing or invalid.
    """
    api_key = request.headers.get("API_KEY")
    expected_api_key = os.getenv("API_KEY", "").strip()
    if not api_key or api_key.strip() != expected_api_key:
        print(f"=== INVALID API KEY DETECTED ===")
        print(f"Expected API Key: {expected_api_key}")
        print(f"Provided API Key: {api_key}")
        print(f"================================")
        raise HTTPException(status_code=403, detail="Invalid API Key")

async def require_jwt_token(request: Request):
    """
    Dependency to check JWT token in Authorization header.
    Raises HTTPException(401) if missing or invalid.
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    
    token = auth_header.split(" ")[1]
    try:
        payload = verify_access_token(token)
        return payload
    except HTTPException:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

# Secret key for JWT
SECRET_KEY = os.getenv("SECRET_KEY")
if not isinstance(SECRET_KEY, str) or not SECRET_KEY:
    raise ValueError("SECRET_KEY environment variable is not set or invalid. Please define it in your .env file.")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Helper function to create JWT token
def create_access_token(data: dict):
    """
    Generate JWT token with user data and expiration.
    Args:
        data (dict): Data to encode (e.g., {"sub": username}).
    Returns:
        str: Encoded JWT token.
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM) #type: ignore
    return encoded_jwt

# Helper function to verify JWT token
def verify_access_token(token: str):
    """
    Verify JWT token and decode payload.
    Args:
        token (str): JWT token.
    Returns:
        dict: Decoded payload if valid.
    Raises:
        HTTPException(401): If token is invalid or expired.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM]) #type: ignore
        username: str = payload.get("sub") #type: ignore
        if not username:
            raise HTTPException(status_code=401, detail="Invalid token: Missing subject")
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

# Encryption functions
def generate_encryption_key(password: str, salt: bytes = None) -> tuple[bytes, bytes]:
    """
    Generate encryption key from password using PBKDF2.
    Args:
        password (str): User password.
        salt (bytes): Salt for key derivation (generated if None).
    Returns:
        tuple: (encryption_key, salt).
    """
    if salt is None:
        salt = os.urandom(16)
    
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
    return key, salt

def encrypt_file_content(content: bytes, password: str) -> tuple[bytes, bytes]:
    """
    Encrypt file content using Fernet.
    Args:
        content (bytes): File content to encrypt.
        password (str): Password for encryption.
    Returns:
        tuple: (encrypted_content, salt).
    """
    key, salt = generate_encryption_key(password)
    fernet = Fernet(key)
    encrypted_content = fernet.encrypt(content)
    return encrypted_content, salt

def decrypt_file_content(encrypted_content: bytes, password: str, salt: bytes) -> bytes:
    """
    Decrypt file content using Fernet.
    Args:
        encrypted_content (bytes): Encrypted file content.
        password (str): Password for decryption.
        salt (bytes): Salt used for encryption.
    Returns:
        bytes: Decrypted content.
    """
    key, _ = generate_encryption_key(password, salt)
    fernet = Fernet(key)
    return fernet.decrypt(encrypted_content)

@app.post("/verify/{email}")
async def verify_email(email: str, request: VerifyEmailRequest, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Verify user's email with code (code is sent in request body as JSON). If successful, mark as verified and create user folder.
    Args:
        email (str): User's email (from path).
        request (VerifyEmailRequest): JSON body with verification code.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: Message about verification result.
    Raises:
        HTTPException: 404 if user not found, 400 if code invalid, 500 on folder error.
    """
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if user.verified == 1:
        return {"message": "User is already verified"}

    if user.verification_code != request.code:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    user.verified = 1
    db.commit()

    # Create a folder for the user
    user_folder = os.path.join(os.getcwd(), user.username)
    if not os.path.exists(user_folder):
        try:
            os.mkdir(user_folder)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error creating user folder: {str(e)}")

    return {"message": "Email verified successfully and user folder created."}

@app.post("/create_user")
async def create_user(request: CreateUserRequest, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Register a new user. Checks for unique email, password complexity.
    Sends verification code to email.
    Args:
        request (CreateUserRequest): Registration data.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: Message about registration status.
    Raises:
        HTTPException: 409 if email exists, 400 if password invalid.
    """
    if db.query(User).filter(User.email == request.email).first():
        raise HTTPException(status_code=409, detail="Email already in use")
    
    if db.query(User).filter(User.username == request.username).first():
        raise HTTPException(status_code=409, detail="Username already in use")

    if not validate_password(request.password):
        raise HTTPException(status_code=400, detail="Password does not meet complexity requirements")

    hashed_password = bcrypt.hashpw(request.password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    verification_code = str(random.randint(100000, 999999))
    print(f"[DEBUG] Attempting to send email to {request.email} with verification code {verification_code}")
    send_email(request.email, verification_code)
    print(f"[DEBUG] Email sent to {request.email}")
    new_user = User(username=request.username, password=hashed_password, email=request.email, verification_code=verification_code)
    db.add(new_user)
    db.commit()

    # Create user folder
    user_folder = os.path.join(os.getcwd(), request.username)
    if not os.path.exists(user_folder):
        os.makedirs(user_folder)
        print(f"[DEBUG] Created user folder: {user_folder}")

    return {"message": f"User {request.username} created successfully. Please verify your email."}

@app.post("/create_folder")
async def create_folder(
    request: CreateFolderRequest, 
    payload: dict = Depends(require_jwt_token)
):
    """
    Create a folder for a user. Requires JWT token and API key.
    Args:
        request (CreateFolderRequest): Folder data.
        payload (dict): JWT token payload.
    Returns:
        dict: Message about folder creation.
    Raises:
        HTTPException: 403/409 if folder exists or unauthorized.
    """
    print(request.json())
    # Sprawdź autoryzację - folder musi być tworzony w folderze użytkownika
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Sprawdź czy folder_name zaczyna się od username (może być username lub username/subfolder)
    if not request.folder_name.startswith(username):
        raise HTTPException(status_code=403, detail="You are not authorized to create folders for other users")

    folder_name = request.folder_name
    # Twórz folder w podanej ścieżce
    full_name = os.path.join(os.getcwd(), folder_name)
    if os.path.exists(full_name):
        raise HTTPException(status_code=409, detail=f"Folder {folder_name} already exists in your directory")

    os.mkdir(full_name)
    return {"message": f"Folder {folder_name} created successfully in your directory"}

@app.post("/upload_file")
async def upload_file(
    folder_info: str = Form(...),
    file: UploadFile = FastAPIFile(...),
    request: Request = None, #type: ignore
    db: Session = Depends(get_db),
    payload: dict = Depends(require_jwt_token)
):
    """
    Upload a file to a user's folder. Requires JWT token and API key.
    Args:
        folder_info (str): JSON with folder name.
        file (UploadFile): File to upload.
        request (Request): HTTP request.
        db (Session): SQLAlchemy session.
        payload (dict): JWT token payload.
    Returns:
        dict: Message about upload result.
    Raises:
        HTTPException: 400/403/404/409/413/415 on errors.
    """
    try:
        folder_info_dict = json.loads(folder_info)
        folder_name = folder_info_dict.get("folder")
    except Exception:
        raise HTTPException(status_code=400, detail="Incorrect JSON")

    if not folder_name:
        raise HTTPException(status_code=400, detail="Folder name is required")

    # Sprawdź autoryzację - folder musi należeć do zalogowanego użytkownika
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Sprawdź czy folder_name zaczyna się od username (może być username lub username/subfolder)
    if not folder_name.startswith(username):
        log_security_event("unauthorized_upload", f"Attempted upload to unauthorized folder: {folder_name}", 
                          request.client.host, username)
        raise HTTPException(status_code=403, detail="You are not authorized to upload to this folder")

    # Validate path safety
    if not validate_path_safety(folder_name):
        log_security_event("path_traversal_attempt", f"Path traversal attempt in folder: {folder_name}", 
                          request.client.host, username)
        raise HTTPException(status_code=400, detail="Invalid folder path")

    folder_path = os.path.join(os.getcwd(), folder_name)
    if not os.path.isdir(folder_path):
        raise HTTPException(status_code=404, detail=f"Folder \"{folder_name}\" does not exist")

    if not file.filename:
        raise HTTPException(status_code=400, detail="File name is missing")

    # Sanitize filename
    safe_filename = sanitize_filename(file.filename)
    if safe_filename != file.filename:
        log_security_event("filename_sanitized", f"Filename sanitized: {file.filename} -> {safe_filename}", 
                          request.client.host, username)

    # Validate file extension
    if not validate_file_extension(safe_filename):
        log_security_event("blocked_file_type", f"Blocked file type: {safe_filename}", 
                          request.client.host, username)
        raise HTTPException(status_code=415, detail="File type not allowed")

    file_path = os.path.join(folder_path, safe_filename)
    if os.path.exists(file_path):
        raise HTTPException(status_code=409, detail=f"File already exists in {folder_name}")

    # Read file content with size limit
    file_content = await file.read()
    
    # Check file size
    if len(file_content) > MAX_FILE_SIZE:
        log_security_event("file_too_large", f"File too large: {len(file_content)} bytes", 
                          request.client.host, username)
        raise HTTPException(status_code=413, detail=f"File too large. Maximum size is {MAX_FILE_SIZE // (1024*1024)}MB")

    # Generate file hash for integrity
    file_hash = hash_file_content(file_content)

    # Write file
    with open(file_path, "wb") as f:
        f.write(file_content)

    user = db.query(User).filter_by(username=username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Create file record with enhanced metadata
    new_file = File(
        filename=safe_filename,
        folder_name=folder_name,
        user_id=user.id,
        file_size=len(file_content),
        file_hash=file_hash,
        mime_type=file.content_type
    )
    db.add(new_file)
    db.commit()
    
    # Log successful upload
    log_security_event("file_uploaded", f"File uploaded: {safe_filename} ({len(file_content)} bytes)", 
                      request.client.host, email)
    
    # Get file metadata
    file_size = os.path.getsize(file_path)
    modification_time = os.path.getmtime(file_path)
    modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
    
    return {
        "message": f"File uploaded successfully to {folder_name}",
        "file_info": {
            "filename": safe_filename,
            "size_bytes": file_size,
            "size_mb": round(file_size / (1024 * 1024), 2),
            "content_type": file.content_type,
            "modification_date": modification_date,
            "folder": folder_name,
            "file_hash": file_hash
        }
    }
    
@app.post("/rename_file")
async def rename_path(
    request: RenameFileRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Rename a file or folder in a user's directory. Handles trailing slashes. Requires JWT token.
    Args:
        request (RenamePathRequest): Data containing folder name and old/new names.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about renaming result.
    Raises:
        HTTPException: 403/404/409/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")

    # Normalize folder_name by removing trailing slashes
    normalized_folder_name = request.folder_name.rstrip("/").strip()
    if not normalized_folder_name:
        raise HTTPException(status_code=400, detail="Folder name cannot be empty")

    # Check if the folder belongs to the authenticated user
    if not normalized_folder_name.startswith(username):
        raise HTTPException(status_code=403, detail="You are not authorized to rename in this folder")

    # Construct the folder path
    folder_path = os.path.join(os.getcwd(), normalized_folder_name)
    print(f"Checking folder path: {folder_path}")
    print(f"Folder contents: {os.listdir(folder_path) if os.path.isdir(folder_path) else 'Folder does not exist'}")
    if not os.path.isdir(folder_path):
        raise HTTPException(status_code=404, detail=f"Folder \"{normalized_folder_name}\" does not exist")

    # Construct old and new paths
    old_path = os.path.join(folder_path, request.old_filename)
    new_path = os.path.join(folder_path, request.new_filename)
    print(f"Checking old path: {old_path}")
    print(f"New path: {new_path}")

    # Check if the old path (file or folder) exists
    if not (os.path.isfile(old_path) or os.path.isdir(old_path)):
        raise HTTPException(status_code=404, detail=f"Path \"{request.old_filename}\" does not exist in {normalized_folder_name}")

    # Check if the new path already exists
    if os.path.exists(new_path):
        raise HTTPException(status_code=409, detail=f"Path \"{request.new_filename}\" already exists in {normalized_folder_name}")

    try:
        # Rename the file or folder
        os.rename(old_path, new_path)

        # Update database records (assuming File model tracks both files and folders)
        file_record = db.query(File).filter(
            File.filename == request.old_filename,
            File.folder_name == normalized_folder_name,
            File.user_id == payload.get("user_id")
        ).first()

        if file_record:
            file_record.filename = request.new_filename
            db.commit()
        # If it's a folder, update all files within it
        elif os.path.isdir(new_path):
            file_records = db.query(File).filter(
                File.folder_name == os.path.join(normalized_folder_name, request.old_filename),
                File.user_id == payload.get("user_id")
            ).all()
            for record in file_records:
                # Update the folder_name to reflect the new folder path
                record.folder_name = os.path.join(normalized_folder_name, request.new_filename)
            db.commit()

        return {"message": f"Path renamed from {request.old_filename} to {request.new_filename} successfully"}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error renaming path: {str(e)}")

@app.post("/list_files")
async def list_files(
    request: ListFilesRequest, 
    payload: dict = Depends(require_jwt_token), 
    db: Session = Depends(get_db)
):
    """
    List all files in a user's folder. Requires JWT token and API key.
    Args:
        request (ListFilesRequest): Folder data.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: List of files in the folder.
    Raises:
        HTTPException: 401/403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")

    # Check if the folder belongs to the authenticated user
    # If folder_name doesn't start with username, construct the full path
    if not request.folder_name.startswith(username):
        folder_name = f"{username}/{request.folder_name}"
    else:
        folder_name = request.folder_name
    folder_path = os.path.join(os.getcwd(), folder_name)
    if not os.path.isdir(folder_path):
        raise HTTPException(status_code=404, detail=f"Folder \"{folder_name}\" does not exist")
    
    try:
        # Get user ID for checking favorites
        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        files = os.listdir(folder_path)
        file_metadata = []
        
        for filename in files:
            file_path_full = os.path.join(folder_path, filename)
            modification_time = os.path.getmtime(file_path_full)
            modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
            
            if os.path.isfile(file_path_full):
                file_size = os.path.getsize(file_path_full)
                
                # Check if file is favorited
                file_record = db.query(File).filter(
                    File.filename == filename,
                    File.folder_name == folder_name,
                    File.user_id == user.id
                ).first()
                
                is_favorite = False
                if file_record:
                    favorite = db.query(Favorite).filter(
                        Favorite.user_id == user.id,
                        Favorite.file_id == file_record.id
                    ).first()
                    is_favorite = favorite is not None
                
                file_metadata.append({
                    "filename": filename,
                    "type": "file",
                    "size_bytes": file_size,
                    "size_mb": round(file_size / (1024 * 1024), 2),
                    "modification_date": modification_date,
                    "is_favorite": is_favorite
                })
            elif os.path.isdir(file_path_full):
                # Rekurencyjne zliczanie plików i folderów oraz rozmiaru
                file_count = 0
                folder_count = 0
                total_size = 0
                
                for root, dirs, files_in_folder in os.walk(file_path_full):
                    file_count += len(files_in_folder)
                    folder_count += len(dirs)
                    for file_in_folder in files_in_folder:
                        file_path_in_folder = os.path.join(root, file_in_folder)
                        if os.path.isfile(file_path_in_folder):
                            total_size += os.path.getsize(file_path_in_folder)
                
                file_metadata.append({
                    "filename": filename,
                    "type": "folder",
                    "size_bytes": total_size,
                    "size_mb": round(total_size / (1024 * 1024), 2),
                    "file_count": file_count,
                    "folder_count": folder_count,
                    "modification_date": modification_date,
                    "is_favorite": False  # Folders cannot be favorited
                })
        
        return {"files": file_metadata, "folder": folder_name}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing files: {str(e)}")

@app.post("/list_shared_folder")
async def list_shared_folder(
    request: ListSharedFolderRequest, 
    payload: dict = Depends(require_jwt_token), 
    db: Session = Depends(get_db)
):
    """
    List all files in a shared folder. Requires JWT token and API key.
    Args:
        request (ListSharedFolderRequest): Shared folder data.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: List of files in the shared folder.
    Raises:
        HTTPException: 401/403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")

    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Check if the folder is shared with this user directly
    shared_folder = db.query(SharedFolder).filter(
        SharedFolder.folder_path == request.folder_path,
        SharedFolder.shared_with_user_id == user.id,
        SharedFolder.shared_by_user_id == User.id
    ).join(User, SharedFolder.shared_by_user_id == User.id).filter(
        User.username == request.shared_by
    ).first()

    # Check if the folder is shared with this user through groups
    group_shared_folder = None
    if not shared_folder:
        # Get user's groups
        user_groups = db.query(UserGroupMember).filter(
            UserGroupMember.user_id == user.id
        ).all()
        
        for membership in user_groups:
            group = db.query(UserGroup).filter(UserGroup.id == membership.group_id).first()
            if group and group.is_active:
                # Check if folder is shared with this group
                group_share = db.query(GroupSharedFolder).filter(
                    GroupSharedFolder.folder_path == request.folder_path,
                    GroupSharedFolder.shared_with_group_id == group.id
                ).first()
                
                if group_share:
                    # Verify that the folder was shared by the specified user
                    shared_by_user = db.query(User).filter(User.id == group_share.shared_by_user_id).first()
                    if shared_by_user and shared_by_user.username == request.shared_by:
                        group_shared_folder = group_share
                        break

    if not shared_folder and not group_shared_folder:
        raise HTTPException(status_code=403, detail="You are not authorized to access this shared folder")

    folder_path = os.path.join(os.getcwd(), request.folder_path)
    if not os.path.isdir(folder_path):
        raise HTTPException(status_code=404, detail=f"Shared folder \"{request.folder_path}\" does not exist")
    
    try:
        files = os.listdir(folder_path)
        file_metadata = []
        
        for filename in files:
            file_path_full = os.path.join(folder_path, filename)
            modification_time = os.path.getmtime(file_path_full)
            modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
            
            if os.path.isfile(file_path_full):
                file_size = os.path.getsize(file_path_full)
                
                file_metadata.append({
                    "filename": filename,
                    "type": "file",
                    "size_bytes": file_size,
                    "size_mb": round(file_size / (1024 * 1024), 2),
                    "modification_date": modification_date,
                    "is_folder": False
                })
            elif os.path.isdir(file_path_full):
                # Recursive counting of files and folders and size
                file_count = 0
                folder_count = 0
                total_size = 0
                
                for root, dirs, files_in_folder in os.walk(file_path_full):
                    file_count += len(files_in_folder)
                    folder_count += len(dirs)
                    for file_in_folder in files_in_folder:
                        file_path_in_folder = os.path.join(root, file_in_folder)
                        if os.path.isfile(file_path_in_folder):
                            total_size += os.path.getsize(file_path_in_folder)
                
                file_metadata.append({
                    "filename": filename,
                    "type": "folder",
                    "size_bytes": total_size,
                    "size_mb": round(total_size / (1024 * 1024), 2),
                    "file_count": file_count,
                    "folder_count": folder_count,
                    "modification_date": modification_date,
                    "is_folder": True
                })
        
        return {"files": file_metadata, "folder": request.folder_path}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing shared folder files: {str(e)}")

@app.get("/files/{file_path:path}")
async def get_file(
    file_path: str, 
    webp: bool = Query(False, description="Convert image to WebP format for preview"),
    max_width: int = Query(1920, description="Maximum width for WebP conversion"),
    preview: bool = Query(False, description="Get text file content for preview"),
    spreadsheet: bool = Query(False, description="Get spreadsheet data as JSON"),
    payload: dict = Depends(require_jwt_token), 
    db: Session = Depends(get_db)
):
    """
    Get a file for preview/download (used by Flutter app).
    Args:
        file_path (str): Path to the file to get.
        webp (bool): Convert image to WebP format for preview.
        max_width (int): Maximum width for WebP conversion.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        FileResponse: The requested file.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get the first part of the file path (user identifier)
    path_parts = file_path.split('/')
    if len(path_parts) < 2:
        raise HTTPException(status_code=400, detail="Invalid file path")
    
    user_identifier = path_parts[0]
    
    # Check if user has direct access (owns the file)
    has_direct_access = user_identifier == username or user_identifier == user.email
    
    # If no direct access, check if file is shared with user
    if not has_direct_access:
        # Get the file owner's user ID
        file_owner = db.query(User).filter(
            (User.username == user_identifier) | (User.email == user_identifier)
        ).first()
        
        if not file_owner:
            raise HTTPException(status_code=404, detail="File owner not found")
        
        # Check if file is shared with current user
        filename = os.path.basename(file_path)
        folder_path = '/'.join(path_parts[1:-1]) if len(path_parts) > 2 else path_parts[1]
        
        print(f"DEBUG: Checking access for file_path={file_path}")
        print(f"DEBUG: username={username}, file_owner.username={file_owner.username}")
        print(f"DEBUG: filename={filename}, folder_path={folder_path}")
        print(f"DEBUG: user.id={user.id}, file_owner.id={file_owner.id}")
        
        # Check individual file sharing
        shared_file = db.query(SharedFile).join(File, SharedFile.original_file_id == File.id).filter(
            File.filename == filename,
            File.folder_name == folder_path,
            File.user_id == file_owner.id,
            SharedFile.shared_with_user_id == user.id
        ).first()
        
        print(f"DEBUG: shared_file found: {shared_file is not None}")
        
        # Check group file sharing
        group_shared_file = db.query(GroupSharedFile).join(File, GroupSharedFile.original_file_id == File.id).join(
            UserGroupMember, GroupSharedFile.shared_with_group_id == UserGroupMember.group_id
        ).filter(
            File.filename == filename,
            File.folder_name == folder_path,
            File.user_id == file_owner.id,
            UserGroupMember.user_id == user.id
        ).first()
        
        print(f"DEBUG: group_shared_file found: {group_shared_file is not None}")
        
        # Check folder sharing
        full_folder_path = f"{username}/{folder_path}"
        print(f"DEBUG: Checking folder sharing with folder_path='{folder_path}'")
        print(f"DEBUG: Full folder path for database lookup: '{full_folder_path}'")
        print(f"DEBUG: Looking for SharedFolder with:")
        print(f"DEBUG:   - folder_path='{full_folder_path}'")
        print(f"DEBUG:   - shared_with_user_id={user.id}")
        print(f"DEBUG:   - shared_by_user_id={file_owner.id}")
        
        shared_folder = db.query(SharedFolder).filter(
            SharedFolder.folder_path == full_folder_path,
            SharedFolder.shared_with_user_id == user.id,
            SharedFolder.shared_by_user_id == file_owner.id
        ).first()
        
        print(f"DEBUG: shared_folder found: {shared_folder is not None}")
        if shared_folder:
            print(f"DEBUG: shared_folder details: id={shared_folder.id}, folder_path='{shared_folder.folder_path}'")
        
        # Check group folder sharing
        print(f"DEBUG: Checking group folder sharing with folder_path='{folder_path}'")
        print(f"DEBUG: Full folder path for group database lookup: '{full_folder_path}'")
        group_shared_folder = db.query(GroupSharedFolder).join(
            UserGroupMember, GroupSharedFolder.shared_with_group_id == UserGroupMember.group_id
        ).filter(
            GroupSharedFolder.folder_path == full_folder_path,
            UserGroupMember.user_id == user.id,
            GroupSharedFolder.shared_by_user_id == file_owner.id
        ).first()
        
        print(f"DEBUG: group_shared_folder found: {group_shared_folder is not None}")
        if group_shared_folder:
            print(f"DEBUG: group_shared_folder details: id={group_shared_folder.id}, folder_path='{group_shared_folder.folder_path}'")
        
        # If no sharing found, deny access
        if not shared_file and not group_shared_file and not shared_folder and not group_shared_folder:
            print(f"DEBUG: Access denied - no sharing found")
            raise HTTPException(status_code=403, detail="Access denied to file")
        else:
            print(f"DEBUG: Access granted - sharing found")
    
    full_path = os.path.join(os.getcwd(), file_path)
    
    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    if not os.path.isfile(full_path):
        raise HTTPException(status_code=400, detail="Path is not a file")
    
    try:
        # Get filename from path
        filename = os.path.basename(full_path)
        
        # Check if it's an image file that can be converted to WebP
        is_image = filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff'))
        
        # Check if it's a text file
        is_text = filename.lower().endswith(('.txt', '.md', '.py', '.js', '.html', '.css', '.json', '.xml', '.csv', '.log', '.ini', '.cfg', '.conf'))
        
        # Check if it's a spreadsheet file
        is_spreadsheet = filename.lower().endswith(('.csv', '.xlsx', '.xls', '.ods'))
        
        if spreadsheet and is_spreadsheet:
            # Return spreadsheet data as JSON
            try:
                import pandas as pd
                
                if filename.lower().endswith('.csv'):
                    # Try different encodings for CSV
                    for encoding in ['utf-8', 'latin-1', 'cp1252']:
                        try:
                            df = pd.read_csv(full_path, encoding=encoding)
                            break
                        except UnicodeDecodeError:
                            continue
                    else:
                        raise Exception("Nie można odczytać pliku CSV - problem z kodowaniem")
                elif filename.lower().endswith(('.xlsx', '.xls')):
                    df = pd.read_excel(full_path)
                elif filename.lower().endswith('.ods'):
                    df = pd.read_excel(full_path, engine='odf')
                else:
                    raise Exception("Nieobsługiwany format pliku")
                
                # Convert DataFrame to JSON
                data = {
                    "filename": filename,
                    "columns": df.columns.tolist(),
                    "rows": df.values.tolist(),
                    "shape": df.shape,
                    "total_rows": len(df),
                    "total_columns": len(df.columns)
                }
                
                return JSONResponse(
                    content=data,
                    headers={
                        'Content-Type': 'application/json',
                        'Cache-Control': 'public, max-age=300'  # Cache for 5 minutes
                    }
                )
            except ImportError:
                raise HTTPException(status_code=500, detail="Biblioteka pandas nie jest dostępna")
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Błąd odczytu pliku arkusza: {str(e)}")
        
        if preview and is_text:
            # Return text file content for preview
            try:
                with open(full_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Limit content size for preview (first 50KB)
                if len(content) > 50000:
                    content = content[:50000] + "\n\n... (plik został obcięty dla podglądu)"
                
                return JSONResponse(
                    content={
                        "filename": filename,
                        "content": content,
                        "size": len(content),
                        "truncated": len(content) > 50000
                    },
                    headers={
                        'Content-Type': 'application/json',
                        'Cache-Control': 'public, max-age=300'  # Cache for 5 minutes
                    }
                )
            except UnicodeDecodeError:
                # Try with different encoding
                try:
                    with open(full_path, 'r', encoding='latin-1') as f:
                        content = f.read()
                    
                    if len(content) > 50000:
                        content = content[:50000] + "\n\n... (plik został obcięty dla podglądu)"
                    
                    return JSONResponse(
                        content={
                            "filename": filename,
                            "content": content,
                            "size": len(content),
                            "truncated": len(content) > 50000
                        },
                        headers={
                            'Content-Type': 'application/json',
                            'Cache-Control': 'public, max-age=300'
                        }
                    )
                except Exception as e:
                    raise HTTPException(status_code=500, detail=f"Error reading text file: {str(e)}")
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Error reading text file: {str(e)}")
        
        if webp and is_image:
            # Convert to WebP for preview
            try:
                from PIL import Image
                import io
                
                # Open and convert image
                with Image.open(full_path) as img:
                    # Convert to RGB if necessary (WebP doesn't support RGBA)
                    if img.mode in ('RGBA', 'LA', 'P'):
                        img = img.convert('RGB')
                    
                    # Resize if larger than max_width
                    if img.width > max_width:
                        ratio = max_width / img.width
                        new_height = int(img.height * ratio)
                        img = img.resize((max_width, new_height), Image.Resampling.LANCZOS)
                    
                    # Convert to WebP
                    webp_buffer = io.BytesIO()
                    img.save(webp_buffer, format='WEBP', quality=85, optimize=True)
                    webp_buffer.seek(0)
                    
                    # Create filename for WebP
                    name_without_ext = os.path.splitext(filename)[0]
                    webp_filename = f"{name_without_ext}.webp"
                    
                    return Response(
                        content=webp_buffer.getvalue(),
                        media_type='image/webp',
                        headers={
                            'Content-Disposition': f'inline; filename="{webp_filename}"',
                            'Cache-Control': 'public, max-age=3600'  # Cache for 1 hour
                        }
                    )
            except ImportError:
                # If Pillow is not available, return original file
                pass
            except Exception as e:
                # If conversion fails, return original file
                pass
        
        # Return original file
        # Determine MIME type based on file extension
        mime_type = 'application/octet-stream'
        if filename.lower().endswith(('.jpg', '.jpeg')):
            mime_type = 'image/jpeg'
        elif filename.lower().endswith('.png'):
            mime_type = 'image/png'
        elif filename.lower().endswith('.gif'):
            mime_type = 'image/gif'
        elif filename.lower().endswith('.webp'):
            mime_type = 'image/webp'
        elif filename.lower().endswith('.pdf'):
            mime_type = 'application/pdf'
        elif filename.lower().endswith(('.mp4', '.avi', '.mov')):
            mime_type = 'video/mp4'
        elif filename.lower().endswith(('.mp3', '.wav', '.flac')):
            mime_type = 'audio/mpeg'
        
        return FileResponse(
            full_path,
            filename=filename,
            media_type=mime_type
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting file: {str(e)}")

@app.get("/download_file/{file_path:path}")
async def download_file(
    file_path: str, 
    payload: dict = Depends(require_jwt_token), 
    db: Session = Depends(get_db)
):
    """
    Download a single file.
    Args:
        file_path (str): Path to the file to download.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        FileResponse: The requested file.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get the first part of the file path (user identifier)
    path_parts = file_path.split('/')
    if len(path_parts) < 2:
        raise HTTPException(status_code=400, detail="Invalid file path")
    
    user_identifier = path_parts[0]
    
    # Check if user has direct access (owns the file)
    has_direct_access = user_identifier == username or user_identifier == user.email
    
    # If no direct access, check if file is shared with user
    if not has_direct_access:
        # Get the file owner's user ID
        file_owner = db.query(User).filter(
            (User.username == user_identifier) | (User.email == user_identifier)
        ).first()
        
        if not file_owner:
            raise HTTPException(status_code=404, detail="File owner not found")
        
        # Check if file is shared with current user
        filename = os.path.basename(file_path)
        folder_path = '/'.join(path_parts[1:-1]) if len(path_parts) > 2 else path_parts[1]
        
        # Check individual file sharing
        shared_file = db.query(SharedFile).join(File, SharedFile.original_file_id == File.id).filter(
            File.filename == filename,
            File.folder_name == folder_path,
            File.user_id == file_owner.id,
            SharedFile.shared_with_user_id == user.id
        ).first()
        
        # Check group file sharing
        group_shared_file = db.query(GroupSharedFile).join(File, GroupSharedFile.original_file_id == File.id).join(
            UserGroupMember, GroupSharedFile.shared_with_group_id == UserGroupMember.group_id
        ).filter(
            File.filename == filename,
            File.folder_name == folder_path,
            File.user_id == file_owner.id,
            UserGroupMember.user_id == user.id
        ).first()
        
        # Check folder sharing
        shared_folder = db.query(SharedFolder).filter(
            SharedFolder.folder_path == folder_path,
            SharedFolder.shared_with_user_id == user.id,
            SharedFolder.shared_by_user_id == file_owner.id
        ).first()
        
        # Check group folder sharing
        group_shared_folder = db.query(GroupSharedFolder).join(
            UserGroupMember, GroupSharedFolder.shared_with_group_id == UserGroupMember.group_id
        ).filter(
            GroupSharedFolder.folder_path == folder_path,
            UserGroupMember.user_id == user.id,
            GroupSharedFolder.shared_by_user_id == file_owner.id
        ).first()
        
        # If no sharing found, deny access
        if not shared_file and not group_shared_file and not shared_folder and not group_shared_folder:
            raise HTTPException(status_code=403, detail="Access denied to file")
    
    full_path = os.path.join(os.getcwd(), file_path)
    
    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    if not os.path.isfile(full_path):
        raise HTTPException(status_code=400, detail="Path is not a file")
    
    try:
        # Get filename from path
        filename = os.path.basename(full_path)
        
        return FileResponse(
            full_path,
            filename=filename,
            media_type='application/octet-stream'
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error downloading file: {str(e)}")

@app.post("/move_file")
async def move_file(
    request: Request,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Move a file or folder to another folder.
    Args:
        request (Request): HTTP request with source and destination paths.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        JSONResponse: Success message.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Parse request body
        body = await request.json()
        source_path = body.get("source_path")
        destination_folder = body.get("destination_folder")
        
        if not source_path or not destination_folder:
            raise HTTPException(status_code=400, detail="Source path and destination folder are required")
        
        # Ensure paths start with username for security
        if not source_path.startswith(username) or not destination_folder.startswith(username):
            raise HTTPException(status_code=403, detail="Access denied to file")
        
        # Build full paths
        source_full_path = os.path.join(os.getcwd(), source_path)
        destination_full_path = os.path.join(os.getcwd(), destination_folder)
        
        # Check if source exists
        if not os.path.exists(source_full_path):
            raise HTTPException(status_code=404, detail="Source file/folder not found")
        
        # Check if this is a shared file or folder (in shared folder)
        if "shared" in source_path:
            raise HTTPException(status_code=403, detail="Cannot move shared files or folders")
        
        # Check if destination folder exists
        if not os.path.exists(destination_full_path):
            raise HTTPException(status_code=404, detail="Destination folder not found")
        
        if not os.path.isdir(destination_full_path):
            raise HTTPException(status_code=400, detail="Destination is not a folder")
        
        # Get filename from source path
        filename = os.path.basename(source_full_path)
        new_path = os.path.join(destination_full_path, filename)
        
        # Check if file already exists in destination
        if os.path.exists(new_path):
            raise HTTPException(status_code=409, detail="File already exists in destination folder")
        
        # Move the file/folder
        shutil.move(source_full_path, new_path)
        
        # Update the file record in the database
        # Find the file record by old path
        old_folder_name = os.path.dirname(source_path)
        file_record = db.query(File).filter(
            File.filename == filename,
            File.folder_name == old_folder_name,
            File.user_id == user.id
        ).first()
        
        if file_record:
            # Update the folder_name to the new location
            file_record.folder_name = destination_folder
            db.commit()
            print(f"[DEBUG] Updated file record in database: {filename} moved from {old_folder_name} to {destination_folder}")
        else:
            # If file record doesn't exist, create it
            file_size = os.path.getsize(new_path)
            with open(new_path, 'rb') as f:
                file_content = f.read()
            file_hash = hashlib.sha256(file_content).hexdigest()
            
            new_file_record = File(
                filename=filename, 
                folder_name=destination_folder, 
                user_id=user.id,
                file_size=file_size,
                file_hash=file_hash
            )
            db.add(new_file_record)
            db.commit()
            print(f"[DEBUG] Created new file record in database: {filename} in {destination_folder}")
        
        return JSONResponse(content={"message": f"Successfully moved {filename} to {destination_folder}"})
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error moving file: {str(e)}")

@app.delete("/delete_file/{file_path:path}")
async def delete_file(
    file_path: str, 
    payload: dict = Depends(require_jwt_token), 
    db: Session = Depends(get_db)
):
    """
    Delete a file and its DB record. Requires JWT token and API key.
    Args:
        file_path (str): Path to file.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about deletion result.
    Raises:
        HTTPException: 401/403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")

    # Check if the file exists in the database
    file_record = db.query(File).filter(File.filename == os.path.basename(file_path), File.folder_name == os.path.dirname(file_path)).first()
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found in the database")

    # Check if the file belongs to the authenticated user
    user = db.query(User).filter(User.id == file_record.user_id).first()
    if not user or user.username != username:
        raise HTTPException(status_code=403, detail="You are not authorized to delete this file")

    # Check if the file exists on the filesystem
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found on the server")

    # Check if this is a shared file or folder (in shared folder)
    if "shared" in file_path:
        raise HTTPException(status_code=403, detail="Cannot delete shared files or folders")
    
    # Attempt to delete the file
    try:
        os.remove(file_path)
        
        # Remove all favorites for this file
        favorites_to_delete = db.query(Favorite).filter(Favorite.file_id == file_record.id).all()
        for favorite in favorites_to_delete:
            db.delete(favorite)
        
        # Remove all shared file records for this file
        shared_files_to_delete = db.query(SharedFile).filter(SharedFile.original_file_id == file_record.id).all()
        for shared_file in shared_files_to_delete:
            db.delete(shared_file)
        
        # Remove the file record from the database
        db.delete(file_record)
        db.commit()
        return {"message": f"File {file_path} deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting file: {str(e)}")

@app.post("/reset_password")
async def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Request password reset for a user.
    Args:
        request (ResetPasswordRequest): JSON body with email.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: Success message (always the same for security).
    Raises:
        HTTPException: 429 if too many attempts.
    """
    email = request.email.lower()
    
    # Rate limiting - max 3 próby na godzinę
    current_time = time.time()
    if email in reset_attempts:
        attempts = reset_attempts[email]
        # Usuń stare próby (starsze niż 1 godzina)
        attempts = [t for t in attempts if current_time - t < 3600]
        
        if len(attempts) >= 3:
            raise HTTPException(status_code=429, detail="Too many reset attempts. Please try again later.")
        
        attempts.append(current_time)
        reset_attempts[email] = attempts
    else:
        reset_attempts[email] = [current_time]
    
    # Sprawdź czy użytkownik istnieje
    user = db.query(User).filter(User.email == email).first()
    
    # Zawsze zwróć sukces, nawet jeśli użytkownik nie istnieje
    if user:
        # Generuj bezpieczny token
        reset_token = secrets.token_urlsafe(32)
        expiry = datetime.utcnow() + timedelta(hours=1)
        
        # Zapisz token w bazie danych
        user.reset_token = reset_token
        user.reset_token_expiry = expiry
        db.commit()
        
        # Wyślij email z linkiem resetowania
        try:
            send_reset_password_email(user.email, reset_token, base_url=BASE_URL)
        except Exception as e:
            print(f"[ERROR] Failed to send reset email: {e}")
            # Nie przerywamy procesu, nawet jeśli email się nie wyśle
    
    return {"message": "Password reset instructions have been sent to your email address."}

@app.post("/confirm_reset")
async def confirm_reset(request: ConfirmResetRequest, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Confirm password reset with token and new password.
    Args:
        request (ConfirmResetRequest): JSON body with token and new password.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: Success message.
    Raises:
        HTTPException: 400 if invalid token or weak password.
    """
    # Waliduj nowe hasło
    if not validate_new_password(request.new_password):
        raise HTTPException(status_code=400, detail="Password does not meet security requirements")
    
    # Znajdź użytkownika z ważnym tokenem
    user = db.query(User).filter(
        User.reset_token == request.token,
        User.reset_token_expiry > datetime.utcnow()
    ).first()
    
    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    
    # Hashuj nowe hasło
    hashed_password = bcrypt.hashpw(request.new_password.encode('utf-8'), bcrypt.gensalt())
    user.password = hashed_password.decode('utf-8')
    
    # Wyczyść token
    user.reset_token = None
    user.reset_token_expiry = None
    db.commit()
    
    return {"message": "Password has been reset successfully"}

@app.get("/reset-password")
async def get_reset_password_page(token: str):
    """
    Get reset password page with token validation.
    Args:
        token (str): Reset token from URL.
    Returns:
        dict: Token validation status.
    """
    # Sprawdź czy token istnieje i jest ważny
    db = SessionLocal()
    try:
        user = db.query(User).filter(
            User.reset_token == token,
            User.reset_token_expiry > datetime.utcnow()
        ).first()
        
        if user:
            return {"valid": True, "message": "Token is valid"}
        else:
            return {"valid": False, "message": "Invalid or expired token"}
    finally:
        db.close()

@app.post("/login")
async def login(login_data: LoginRequest, request: Request, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Authenticate user by email and password, return JWT token.
    Args:
        request (LoginRequest): JSON body with email and password.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: JWT token and token type.
    Raises:
        HTTPException: 401 if credentials invalid, 423 if account locked.
    """
    # Find user by email or username
    user = db.query(User).filter(
        (User.email == login_data.email) | (User.username == login_data.email)
    ).first()
    
    if not user:
        log_security_event("failed_login", "User not found", request.client.host, login_data.email)
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Check if account is active
    if not user.is_active:
        log_security_event("login_attempt", "Account deactivated", request.client.host, user.username)
        raise HTTPException(status_code=401, detail="Account is deactivated")
    
    # Check if account is locked
    if user.account_locked_until and datetime.now() < user.account_locked_until:
        log_security_event("login_attempt", "Account locked", request.client.host, user.username)
        raise HTTPException(status_code=423, detail="Account is temporarily locked due to too many failed attempts")
    
    # Verify password
    if not bcrypt.checkpw(login_data.password.encode('utf-8'), user.password.encode('utf-8')):
        # Increment failed login attempts
        user.failed_login_attempts += 1
        
        # Lock account if too many failed attempts
        if user.failed_login_attempts >= MAX_LOGIN_ATTEMPTS:
            user.account_locked_until = datetime.now() + timedelta(minutes=LOGIN_LOCKOUT_DURATION)
            log_security_event("account_locked", f"Account locked after {user.failed_login_attempts} failed attempts", 
                             request.client.host, user.username)
        
        db.commit()
        log_security_event("failed_login", f"Invalid password (attempt {user.failed_login_attempts})", 
                          request.client.host, user.username)
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Reset failed login attempts on successful login
    user.failed_login_attempts = 0
    user.account_locked_until = None
    user.last_login = datetime.now()
    db.commit()
    
    log_security_event("successful_login", "User logged in successfully", request.client.host, user.username)

    # Create user folder if it doesn't exist
    user_folder = os.path.join(os.getcwd(), user.username)
    if not os.path.exists(user_folder):
        try:
            os.mkdir(user_folder)
            print(f"[DEBUG] Created user folder: {user_folder}")
        except Exception as e:
            print(f"[DEBUG] Error creating user folder: {str(e)}")
            # Don't fail login if folder creation fails
    
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer", "username": user.username, "email": user.email}

@app.get("/validate_token")
async def validate_token(payload: dict = Depends(require_jwt_token)):
    """
    Validate JWT token and return user information.
    
    Args:
        payload (dict): JWT token payload from require_jwt_token dependency.
        
    Returns:
        dict: Token validation result with user info.
    """
    try:
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        
        db = SessionLocal()
        user = db.query(User).filter(User.username == username).first()
        
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        
        return {
            "valid": True,
            "message": "Token is valid",
            "username": user.username,
            "email": user.email,
            "verified": bool(user.verified)
        }
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        db.close()

@app.delete("/delete_user/{username}")
async def delete_user(
    username: str, 
    payload: dict = Depends(require_jwt_token), 
    db: Session = Depends(get_db)
):
    """
    Delete user, their folder, and all files. Requires JWT token and API key.
    Args:
        username (str): Username to delete.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about deletion result.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    if payload.get("sub") != username:
        raise HTTPException(status_code=403, detail="You are not authorized to delete this user")

    user = db.query(User).filter_by(username=username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Delete all favorites for this user's files
    user_files = db.query(File).filter(File.user_id == user.id).all()
    for file in user_files:
        favorites_to_delete = db.query(Favorite).filter(Favorite.file_id == file.id).all()
        for favorite in favorites_to_delete:
            db.delete(favorite)
    
    # Delete all shared file records where this user is the sharer
    shared_files_as_sharer = db.query(SharedFile).filter(SharedFile.shared_by_user_id == user.id).all()
    for shared_file in shared_files_as_sharer:
        db.delete(shared_file)
    
    # Delete all shared file records where this user is the recipient
    shared_files_as_recipient = db.query(SharedFile).filter(SharedFile.shared_with_user_id == user.id).all()
    for shared_file in shared_files_as_recipient:
        db.delete(shared_file)
    
    # Delete all shared folder records where this user is the sharer
    shared_folders_as_sharer = db.query(SharedFolder).filter(SharedFolder.shared_by_user_id == user.id).all()
    for shared_folder in shared_folders_as_sharer:
        db.delete(shared_folder)
    
    # Delete all shared folder records where this user is the recipient
    shared_folders_as_recipient = db.query(SharedFolder).filter(SharedFolder.shared_with_user_id == user.id).all()
    for shared_folder in shared_folders_as_recipient:
        db.delete(shared_folder)
    
    # Delete all files for this user
    for file in user_files:
        db.delete(file)
    
    user_folder = os.path.join(os.getcwd(), username)
    if os.path.exists(user_folder):
        try:
            shutil.rmtree(user_folder)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error deleting user folder: {str(e)}")

    db.delete(user)
    db.commit()

    return {"message": f"User {username} and their folder have been deleted successfully"}

@app.post("/toggle_favorite")
async def toggle_favorite(
    request: ToggleFavoriteRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Toggle favorite status for a file. Add to favorites if not favorited, remove if already favorited.
    Args:
        request (ToggleFavoriteRequest): File information.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about the operation result.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if file exists on filesystem
    file_path = os.path.join(os.getcwd(), request.folder_name, request.filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found on filesystem")
    
    # Get file ID - first try to find by exact folder_name and filename
    file_record = db.query(File).filter(
        File.filename == request.filename,
        File.folder_name == request.folder_name,
        File.user_id == user.id
    ).first()
    
    # If not found, try to find by filename only (in case file was moved)
    if not file_record:
        file_record = db.query(File).filter(
            File.filename == request.filename,
            File.user_id == user.id
        ).first()
        
        # If found by filename only, update the folder_name to current location
        if file_record:
            file_record.folder_name = request.folder_name
            db.commit()
            print(f"[DEBUG] Updated file record folder_name: {request.filename} now in {request.folder_name}")
    
    if not file_record:
        # File exists on filesystem but not in database - add it
        try:
            # Get file size
            file_size = os.path.getsize(file_path)
            
            # Generate file hash
            with open(file_path, 'rb') as f:
                file_content = f.read()
                file_hash = hash_file_content(file_content)
            
            # Get MIME type
            import mimetypes
            mime_type, _ = mimetypes.guess_type(request.filename)
            
            file_record = File(
                filename=request.filename, 
                folder_name=request.folder_name, 
                user_id=user.id,
                file_size=file_size,
                file_hash=file_hash,
                mime_type=mime_type
            )
            db.add(file_record)
            db.commit()
            print(f"[DEBUG] Added file to database: {request.filename} in {request.folder_name} (size: {file_size}, hash: {file_hash[:8]}...)")
        except Exception as e:
            print(f"[DEBUG] Error adding file to database: {e}")
            raise HTTPException(status_code=500, detail="Error processing file metadata")
    
    # Check if already favorited
    existing_favorite = db.query(Favorite).filter(
        Favorite.user_id == user.id,
        Favorite.file_id == file_record.id
    ).first()
    
    if existing_favorite:
        # Remove from favorites
        db.delete(existing_favorite)
        db.commit()
        return {"message": f"File {request.filename} removed from favorites", "is_favorite": False}
    else:
        # Add to favorites
        new_favorite = Favorite(user_id=user.id, file_id=file_record.id)
        db.add(new_favorite)
        db.commit()
        return {"message": f"File {request.filename} added to favorites", "is_favorite": True}

@app.get("/get_favorites")
async def get_favorites(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get all favorite files for the authenticated user.
    Args:
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: List of favorite files with metadata.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get favorite files
    favorites = db.query(Favorite, File).join(File, Favorite.file_id == File.id).filter(
        Favorite.user_id == user.id
    ).all()
    
    favorite_files = []
    for favorite, file in favorites:
        # Get file metadata
        file_path = os.path.join(os.getcwd(), file.folder_name, file.filename)
        
        # If file doesn't exist in recorded location, try to find it in other folders
        if not os.path.exists(file_path):
            # Search for the file in user's folders
            user_folders = [f for f in os.listdir(os.getcwd()) if f.startswith(username) and os.path.isdir(os.path.join(os.getcwd(), f))]
            found_path = None
            
            for folder in user_folders:
                potential_path = os.path.join(os.getcwd(), folder, file.filename)
                if os.path.exists(potential_path):
                    found_path = potential_path
                    # Update the database record with the correct folder
                    file.folder_name = folder
                    db.commit()
                    print(f"[DEBUG] Updated favorite file location: {file.filename} found in {folder}")
                    break
            
            if found_path:
                file_path = found_path
            else:
                # File not found anywhere, skip it
                print(f"[DEBUG] Favorite file not found: {file.filename}")
                continue
        
        if os.path.exists(file_path):
            modification_time = os.path.getmtime(file_path)
            modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
            file_size = os.path.getsize(file_path) if os.path.isfile(file_path) else 0
            
            favorite_files.append({
                "filename": file.filename,
                "folder_name": file.folder_name,
                "size_bytes": file_size,
                "size_mb": round(file_size / (1024 * 1024), 2),
                "modification_date": modification_date,
                "favorited_at": favorite.created_at.isoformat()
            })
    
    return {"favorites": favorite_files}

@app.post("/share_file")
async def share_file(
    request: ShareFileRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Share a file with another user by email or username.
    Args:
        request (ShareFileRequest): File information and target user.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about the operation result.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID (the one sharing the file)
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Find the target user by email or username
    target_user = db.query(User).filter(
        (User.email == request.share_with) | (User.username == request.share_with)
    ).first()
    
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")
    
    if target_user.id == user.id:
        raise HTTPException(status_code=400, detail="Cannot share file with yourself")
    
    # Validate that the folder belongs to the authenticated user
    if not request.folder_name.startswith(username):
        raise HTTPException(status_code=403, detail="You are not authorized to access this folder")
    
    # Check if file exists on filesystem
    # The folder_name already includes the username, so we just join with current directory
    file_path = os.path.join(os.getcwd(), request.folder_name, request.filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found on filesystem")
    
    # Get file record
    file_record = db.query(File).filter(
        File.filename == request.filename,
        File.folder_name == request.folder_name,
        File.user_id == user.id
    ).first()
    
    # If not found, try to find by filename only (in case file was moved)
    if not file_record:
        file_record = db.query(File).filter(
            File.filename == request.filename,
            File.user_id == user.id
        ).first()
        
        # If found by filename only, update the folder_name to current location
        if file_record:
            file_record.folder_name = request.folder_name
            db.commit()
    
    if not file_record:
        # File exists on filesystem but not in database - add it
        file_size = os.path.getsize(file_path)
        with open(file_path, 'rb') as f:
            file_content = f.read()
        file_hash = hashlib.sha256(file_content).hexdigest()
        
        file_record = File(
            filename=request.filename, 
            folder_name=request.folder_name, 
            user_id=user.id,
            file_size=file_size,
            file_hash=file_hash
        )
        db.add(file_record)
        db.commit()
    
    # Check if already shared with this user
    existing_share = db.query(SharedFile).filter(
        SharedFile.original_file_id == file_record.id,
        SharedFile.shared_with_user_id == target_user.id
    ).first()
    
    if existing_share:
        raise HTTPException(status_code=409, detail="File already shared with this user")
    
    # Create shared file record
    shared_file = SharedFile(
        original_file_id=file_record.id,
        shared_with_user_id=target_user.id,
        shared_by_user_id=user.id
    )
    db.add(shared_file)
    
    # Create shared folder for target user if it doesn't exist
    target_shared_folder = os.path.join(os.getcwd(), target_user.username, "shared")
    if not os.path.exists(target_shared_folder):
        os.makedirs(target_shared_folder)
    
    # Copy file to target user's shared folder
    target_file_path = os.path.join(target_shared_folder, request.filename)
    
    # Handle filename conflicts by adding timestamp
    if os.path.exists(target_file_path):
        name, ext = os.path.splitext(request.filename)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        target_file_path = os.path.join(target_shared_folder, f"{name}_{timestamp}{ext}")
    
    try:
        shutil.copy2(file_path, target_file_path)
        
        # Create file record for the shared file
        shared_file_size = os.path.getsize(target_file_path)
        with open(target_file_path, 'rb') as f:
            file_content = f.read()
        shared_file_hash = hashlib.sha256(file_content).hexdigest()
        
        shared_file_record = File(
            filename=os.path.basename(target_file_path),
            folder_name=f"{target_user.username}/shared",
            user_id=target_user.id,
            file_size=shared_file_size,
            file_hash=shared_file_hash
        )
        db.add(shared_file_record)
        db.commit()
        
        return {
            "message": f"File {request.filename} shared successfully with {target_user.username}",
            "shared_filename": os.path.basename(target_file_path)
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error sharing file: {str(e)}")

@app.get("/get_shared_files")
async def get_shared_files(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get all files shared with the authenticated user.
    Args:
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: List of shared files with metadata.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get shared files
    shared_files = db.query(SharedFile, File, User).join(
        File, SharedFile.original_file_id == File.id
    ).join(
        User, SharedFile.shared_by_user_id == User.id
    ).filter(
        SharedFile.shared_with_user_id == user.id
    ).all()
    
    shared_files_list = []
    for shared_file, file, sharer in shared_files:
        # Get file metadata
        file_path = os.path.join(os.getcwd(), file.folder_name, file.filename)
        if os.path.exists(file_path):
            modification_time = os.path.getmtime(file_path)
            modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
            file_size = os.path.getsize(file_path) if os.path.isfile(file_path) else 0
            
            shared_files_list.append({
                "filename": file.filename,
                "folder_name": file.folder_name,
                "size_bytes": file_size,
                "size_mb": round(file_size / (1024 * 1024), 2),
                "modification_date": modification_date,
                "shared_at": shared_file.created_at.isoformat(),
                "shared_by": sharer.username,
                "shared_by_email": sharer.email
            })
    
    return {"shared_files": shared_files_list}

@app.post("/share_folder")
async def share_folder(
    request: ShareFolderRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Share a folder with another user by email or username.
    Args:
        request (ShareFolderRequest): Folder information and target user.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about the operation result.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID (the one sharing the folder)
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Find the target user by email or username
    target_user = db.query(User).filter(
        (User.email == request.share_with) | (User.username == request.share_with)
    ).first()
    
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")
    
    if target_user.id == user.id:
        raise HTTPException(status_code=400, detail="Cannot share folder with yourself")
    
    # Check if folder exists on filesystem
    folder_path = os.path.join(os.getcwd(), request.folder_path)
    if not os.path.exists(folder_path) or not os.path.isdir(folder_path):
        raise HTTPException(status_code=404, detail="Folder not found on filesystem")
    
    # Check if already shared with this user
    existing_share = db.query(SharedFolder).filter(
        SharedFolder.folder_path == request.folder_path,
        SharedFolder.shared_with_user_id == target_user.id
    ).first()
    
    if existing_share:
        raise HTTPException(status_code=409, detail="Folder already shared with this user")
    
    # Create shared folder record
    shared_folder = SharedFolder(
        folder_path=request.folder_path,
        shared_with_user_id=target_user.id,
        shared_by_user_id=user.id
    )
    db.add(shared_folder)
    
    # Create shared folder for target user if it doesn't exist
    target_shared_folder = os.path.join(os.getcwd(), target_user.username, "shared")
    if not os.path.exists(target_shared_folder):
        os.makedirs(target_shared_folder)
    
    # Create a symbolic link or copy the folder structure
    folder_name = os.path.basename(request.folder_path)
    target_folder_path = os.path.join(target_shared_folder, folder_name)
    
    # Handle folder name conflicts by adding timestamp
    if os.path.exists(target_folder_path):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        target_folder_path = os.path.join(target_shared_folder, f"{folder_name}_{timestamp}")
    
    try:
        # Copy the entire folder structure
        shutil.copytree(folder_path, target_folder_path)
        
        db.commit()
        
        return {
            "message": f"Folder {folder_name} shared successfully with {target_user.username}",
            "shared_folder_path": target_folder_path
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error sharing folder: {str(e)}")

@app.get("/get_shared_folders")
async def get_shared_folders(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get all folders shared with the authenticated user.
    Args:
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: List of shared folders with metadata.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get shared folders
    shared_folders = db.query(SharedFolder, User).join(
        User, SharedFolder.shared_by_user_id == User.id
    ).filter(
        SharedFolder.shared_with_user_id == user.id
    ).all()
    
    shared_folders_list = []
    for shared_folder, sharer in shared_folders:
        # Get folder metadata
        folder_path = os.path.join(os.getcwd(), shared_folder.folder_path)
        if os.path.exists(folder_path):
            modification_time = os.path.getmtime(folder_path)
            modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
            
            # Count files and folders in folder
            file_count = 0
            folder_count = 0
            total_size = 0
            for root, dirs, files in os.walk(folder_path):
                file_count += len(files)
                folder_count += len(dirs)
                for file in files:
                    file_path = os.path.join(root, file)
                    if os.path.isfile(file_path):
                        total_size += os.path.getsize(file_path)
            
            shared_folders_list.append({
                "folder_name": os.path.basename(shared_folder.folder_path),
                "folder_path": shared_folder.folder_path,
                "file_count": file_count,
                "folder_count": folder_count,
                "total_size_bytes": total_size,
                "total_size_mb": round(total_size / (1024 * 1024), 2),
                "modification_date": modification_date,
                "shared_at": shared_folder.created_at.isoformat(),
                "shared_by": sharer.username,
                "shared_by_email": sharer.email
            })
    
    return {"shared_folders": shared_folders_list}

@app.get("/get_my_shared_files")
async def get_my_shared_files(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get all files that the authenticated user has shared with others.
    Args:
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: List of shared files with metadata.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get files shared by this user
    shared_files = db.query(SharedFile, File, User).join(
        File, SharedFile.original_file_id == File.id
    ).join(
        User, SharedFile.shared_with_user_id == User.id
    ).filter(
        SharedFile.shared_by_user_id == user.id
    ).all()
    
    shared_files_list = []
    for shared_file, file, shared_with_user in shared_files:
        # Get file metadata
        file_path = os.path.join(os.getcwd(), file.folder_name, file.filename)
        
        if os.path.exists(file_path):
            modification_time = os.path.getmtime(file_path)
            modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
            file_size = os.path.getsize(file_path) if os.path.isfile(file_path) else 0
            
            shared_files_list.append({
                "filename": file.filename,
                "folder_name": file.folder_name,
                "size_bytes": file_size,
                "size_mb": round(file_size / (1024 * 1024), 2),
                "modification_date": modification_date,
                "shared_at": shared_file.created_at.isoformat(),
                "shared_with": shared_with_user.username,
                "shared_with_email": shared_with_user.email
            })
    
    return {"my_shared_files": shared_files_list}

@app.get("/get_my_shared_folders")
async def get_my_shared_folders(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get all folders that the authenticated user has shared with others.
    Args:
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: List of shared folders with metadata.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get folders shared by this user
    shared_folders = db.query(SharedFolder, User).join(
        User, SharedFolder.shared_with_user_id == User.id
    ).filter(
        SharedFolder.shared_by_user_id == user.id
    ).all()
    
    shared_folders_list = []
    for shared_folder, shared_with_user in shared_folders:
        # Get folder metadata
        folder_path = os.path.join(os.getcwd(), shared_folder.folder_path)
        if os.path.exists(folder_path):
            modification_time = os.path.getmtime(folder_path)
            modification_date = datetime.fromtimestamp(modification_time, tz=timezone.utc).isoformat()
            
            # Count files and folders in folder
            file_count = 0
            folder_count = 0
            total_size = 0
            for root, dirs, files in os.walk(folder_path):
                file_count += len(files)
                folder_count += len(dirs)
                for file in files:
                    file_path = os.path.join(root, file)
                    if os.path.isfile(file_path):
                        total_size += os.path.getsize(file_path)
            
            shared_folders_list.append({
                "folder_name": os.path.basename(shared_folder.folder_path),
                "folder_path": shared_folder.folder_path,
                "file_count": file_count,
                "folder_count": folder_count,
                "total_size_bytes": total_size,
                "total_size_mb": round(total_size / (1024 * 1024), 2),
                "modification_date": modification_date,
                "shared_at": shared_folder.created_at.isoformat(),
                "shared_with": shared_with_user.username,
                "shared_with_email": shared_with_user.email
            })
    
    return {"my_shared_folders": shared_folders_list}

@app.post("/download_files_as_zip")
async def download_files_as_zip(
    request: Request,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Download selected files and folders as a ZIP file.
    Args:
        request (Request): HTTP request with file paths in body.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        FileResponse: ZIP file containing selected files and folders.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    zip_path = None
    try:
        # Parse request body to get file paths
        body = await request.json()
        file_paths = body.get("file_paths", [])
        
        if not file_paths:
            raise HTTPException(status_code=400, detail="No files selected")
        
        # Create temporary ZIP file
        zip_filename = f"{username}_files_{datetime.now().strftime('%Y%m%d_%H%M%S')}.zip"
        zip_path = os.path.join(os.getcwd(), zip_filename)
        
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for file_path in file_paths:
                # Get the first part of the file path (user identifier)
                path_parts = file_path.split('/')
                if len(path_parts) < 2:
                    raise HTTPException(status_code=400, detail="Invalid file path")
                
                user_identifier = path_parts[0]
                
                # Check if user has direct access (owns the file)
                has_direct_access = user_identifier == username or user_identifier == user.email
                
                # If no direct access, check if file is shared with user
                if not has_direct_access:
                    # Get the file owner's user ID
                    file_owner = db.query(User).filter(
                        (User.username == user_identifier) | (User.email == user_identifier)
                    ).first()
                    
                    if not file_owner:
                        raise HTTPException(status_code=404, detail="File owner not found")
                    
                    # Check if file is shared with current user
                    filename = os.path.basename(file_path)
                    folder_path = '/'.join(path_parts[1:-1]) if len(path_parts) > 2 else path_parts[1]
                    
                    # Check individual file sharing
                    shared_file = db.query(SharedFile).join(File, SharedFile.original_file_id == File.id).filter(
                        File.filename == filename,
                        File.folder_name == folder_path,
                        File.user_id == file_owner.id,
                        SharedFile.shared_with_user_id == user.id
                    ).first()
                    
                    # Check group file sharing
                    group_shared_file = db.query(GroupSharedFile).join(File, GroupSharedFile.original_file_id == File.id).join(
                        UserGroupMember, GroupSharedFile.shared_with_group_id == UserGroupMember.group_id
                    ).filter(
                        File.filename == filename,
                        File.folder_name == folder_path,
                        File.user_id == file_owner.id,
                        UserGroupMember.user_id == user.id
                    ).first()
                    
                    # Check folder sharing
                    shared_folder = db.query(SharedFolder).filter(
                        SharedFolder.folder_path == folder_path,
                        SharedFolder.shared_with_user_id == user.id,
                        SharedFolder.shared_by_user_id == file_owner.id
                    ).first()
                    
                    # Check group folder sharing
                    group_shared_folder = db.query(GroupSharedFolder).join(
                        UserGroupMember, GroupSharedFolder.shared_with_group_id == UserGroupMember.group_id
                    ).filter(
                        GroupSharedFolder.folder_path == folder_path,
                        UserGroupMember.user_id == user.id,
                        GroupSharedFolder.shared_by_user_id == file_owner.id
                    ).first()
                    
                    # If no sharing found, deny access
                    if not shared_file and not group_shared_file and not shared_folder and not group_shared_folder:
                        raise HTTPException(status_code=403, detail="Access denied to file")
                
                full_path = os.path.join(os.getcwd(), file_path)
                
                if os.path.exists(full_path):
                    if os.path.isfile(full_path):
                        # Add file to ZIP
                        arcname = os.path.relpath(full_path, os.path.join(os.getcwd(), username))
                        zipf.write(full_path, arcname)
                    elif os.path.isdir(full_path):
                        # Add folder and its contents to ZIP
                        for root, dirs, files in os.walk(full_path):
                            for file in files:
                                file_path_full = os.path.join(root, file)
                                arcname = os.path.relpath(file_path_full, os.path.join(os.getcwd(), username))
                                zipf.write(file_path_full, arcname)
        
        # Return the ZIP file
        # Note: FileResponse will handle the file, but we need to clean it up manually later
        return FileResponse(
            zip_path,
            filename=zip_filename,
            media_type='application/zip'
        )
        
    except Exception as e:
        # Clean up ZIP file if it exists and there was an error
        if zip_path and os.path.exists(zip_path):
            try:
                os.remove(zip_path)
            except:
                pass  # Ignore cleanup errors
        raise HTTPException(status_code=500, detail=f"Error creating ZIP file: {str(e)}")

@app.post("/cleanup_zip")
async def cleanup_zip(
    request: Request,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Clean up ZIP file after download.
    Args:
        request (Request): HTTP request with zip filename in body.
        payload (dict): JWT token payload.
    Returns:
        JSONResponse: Success message.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    try:
        body = await request.json()
        zip_filename = body.get("zip_filename")
        
        if not zip_filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        
        # Get user from database to check email
        user = db.query(User).filter(User.username == username).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Allow access if the filename starts with username or email
        if not zip_filename.startswith(username) and not zip_filename.startswith(user.email):
            raise HTTPException(status_code=403, detail="Access denied to file")
        
        zip_path = os.path.join(os.getcwd(), zip_filename)
        
        if os.path.exists(zip_path):
            try:
                os.remove(zip_path)
                return JSONResponse(content={"message": "ZIP file cleaned up successfully"})
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Error cleaning up ZIP file: {str(e)}")
        else:
            return JSONResponse(content={"message": "ZIP file not found or already cleaned up"})
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error in cleanup: {str(e)}")

@app.post("/create_quick_share")
async def create_quick_share(
    request: Request,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Create a quick share link for a file or folder.
    Args:
        request (Request): HTTP request with file path in body.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        JSONResponse: Quick share URL and QR code data.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Parse request body to get file path
        body = await request.json()
        file_path = body.get("file_path")
        
        if not file_path:
            raise HTTPException(status_code=400, detail="No file path provided")
        
        # Get user from database to check email
        user = db.query(User).filter(User.username == username).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get the first part of the file path (user identifier)
        path_parts = file_path.split('/')
        if len(path_parts) < 2:
            raise HTTPException(status_code=400, detail="Invalid file path")
        
        user_identifier = path_parts[0]
        
        # Check if user has direct access (owns the file)
        has_direct_access = user_identifier == username or user_identifier == user.email
        
        # If no direct access, check if file is shared with user
        if not has_direct_access:
            # Get the file owner's user ID
            file_owner = db.query(User).filter(
                (User.username == user_identifier) | (User.email == user_identifier)
            ).first()
            
            if not file_owner:
                raise HTTPException(status_code=404, detail="File owner not found")
            
            # Check if file is shared with current user
            filename = os.path.basename(file_path)
            folder_path = '/'.join(path_parts[1:-1]) if len(path_parts) > 2 else path_parts[1]
            
            # Check individual file sharing
            shared_file = db.query(SharedFile).join(File, SharedFile.original_file_id == File.id).filter(
                File.filename == filename,
                File.folder_name == folder_path,
                File.user_id == file_owner.id,
                SharedFile.shared_with_user_id == user.id
            ).first()
            
            # Check group file sharing
            group_shared_file = db.query(GroupSharedFile).join(File, GroupSharedFile.original_file_id == File.id).join(
                UserGroupMember, GroupSharedFile.shared_with_group_id == UserGroupMember.group_id
            ).filter(
                File.filename == filename,
                File.folder_name == folder_path,
                File.user_id == file_owner.id,
                UserGroupMember.user_id == user.id
            ).first()
            
            # Check folder sharing
            shared_folder = db.query(SharedFolder).filter(
                SharedFolder.folder_path == folder_path,
                SharedFolder.shared_with_user_id == user.id,
                SharedFolder.shared_by_user_id == file_owner.id
            ).first()
            
            # Check group folder sharing
            group_shared_folder = db.query(GroupSharedFolder).join(
                UserGroupMember, GroupSharedFolder.shared_with_group_id == UserGroupMember.group_id
            ).filter(
                GroupSharedFolder.folder_path == folder_path,
                UserGroupMember.user_id == user.id,
                GroupSharedFolder.shared_by_user_id == file_owner.id
            ).first()
            
            # If no sharing found, deny access
            if not shared_file and not group_shared_file and not shared_folder and not group_shared_folder:
                raise HTTPException(status_code=403, detail="Access denied to file")
        
        full_path = os.path.join(os.getcwd(), file_path)
        
        if not os.path.exists(full_path):
            raise HTTPException(status_code=404, detail="File not found")
        
        # Generate unique share ID
        share_id = secrets.token_urlsafe(16)
        
        # Create share URL
        base_url = os.getenv("BASE_URL", "http://localhost:8000")
        share_url = f"{base_url}/quick_share/{share_id}"
        
        # Store share information (in production, use a database)
        # For now, we'll use a simple in-memory storage
        if not hasattr(create_quick_share, 'shares'):
            create_quick_share.shares = {}
        
        create_quick_share.shares[share_id] = {
            'file_path': file_path,
            'username': username,
            'created_at': datetime.now().isoformat(),
            'expires_at': (datetime.now() + timedelta(hours=24)).isoformat()  # 24 hour expiry
        }
        
        return JSONResponse(content={
            "share_id": share_id,
            "share_url": share_url,
            "qr_data": share_url,
            "expires_at": create_quick_share.shares[share_id]['expires_at']
        })
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating quick share: {str(e)}")

@app.get("/quick_share/{share_id}")
async def quick_share_download(
    share_id: str,
    db: Session = Depends(get_db)
):
    """
    Download file or folder via quick share link.
    Args:
        share_id (str): Unique share identifier.
        db (Session): SQLAlchemy session.
    Returns:
        FileResponse or StreamingResponse: The shared file or folder as ZIP.
    Raises:
        HTTPException: 404/410 on errors.
    """
    try:
        # Validate share_id format (prevent injection attacks)
        if not share_id or len(share_id) > 64 or not re.match(r'^[a-zA-Z0-9_-]+$', share_id):
            log_security_event("invalid_share_id", f"Invalid share ID format: {share_id}", None, None)
            raise HTTPException(status_code=404, detail="Share link not found")
        
        # Get share information
        if not hasattr(create_quick_share, 'shares'):
            create_quick_share.shares = {}
        
        share_info = create_quick_share.shares.get(share_id)
        
        if not share_info:
            log_security_event("share_not_found", f"Share not found: {share_id}", None, None)
            raise HTTPException(status_code=404, detail="Share link not found")
        
        # Check if share has expired
        expires_at = datetime.fromisoformat(share_info['expires_at'])
        if datetime.now() > expires_at:
            # Remove expired share
            del create_quick_share.shares[share_id]
            log_security_event("share_expired", f"Expired share accessed: {share_id}", None, None)
            raise HTTPException(status_code=410, detail="Share link has expired")
        
        file_path = share_info['file_path']
        
        # Validate path safety
        if not validate_path_safety(file_path):
            log_security_event("path_traversal_attempt", f"Path traversal in quick share: {file_path}", None, None)
            raise HTTPException(status_code=404, detail="File or folder not found")
        
        full_path = os.path.join(os.getcwd(), file_path)
        
        if not os.path.exists(full_path):
            log_security_event("file_not_found", f"File not found in quick share: {file_path}", None, None)
            raise HTTPException(status_code=404, detail="File or folder not found")
        
        # Check if it's a file or folder
        if os.path.isfile(full_path):
            # It's a file - return as FileResponse
            filename = os.path.basename(full_path)
            
            # Validate file extension
            if not validate_file_extension(filename):
                log_security_event("blocked_file_download", f"Blocked file download: {filename}", None, None)
                raise HTTPException(status_code=404, detail="File or folder not found")
            
            log_security_event("file_downloaded", f"File downloaded via quick share: {filename}", None, None)
            return FileResponse(
                full_path,
                filename=filename,
                media_type='application/octet-stream'
            )
        elif os.path.isdir(full_path):
            # It's a folder - create ZIP and return as StreamingResponse
            import tempfile
            import zipfile
            import io
            
            # Create a temporary ZIP file
            temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix='.zip')
            temp_zip.close()
            
            try:
                with zipfile.ZipFile(temp_zip.name, 'w', zipfile.ZIP_DEFLATED) as zipf:
                    for root, dirs, files in os.walk(full_path):
                        for file in files:
                            file_path = os.path.join(root, file)
                            # Validate file extension before adding to ZIP
                            if validate_file_extension(file):
                                # Calculate relative path for ZIP
                                arcname = os.path.relpath(file_path, full_path)
                                zipf.write(file_path, arcname)
                
                # Read the ZIP file and return as StreamingResponse
                with open(temp_zip.name, 'rb') as f:
                    zip_content = f.read()
                
                # Clean up temporary file
                os.unlink(temp_zip.name)
                
                # Get folder name for ZIP filename
                folder_name = os.path.basename(full_path)
                zip_filename = f"{folder_name}.zip"
                
                log_security_event("folder_downloaded", f"Folder downloaded via quick share: {folder_name}", None, None)
                return StreamingResponse(
                    io.BytesIO(zip_content),
                    media_type='application/zip',
                    headers={'Content-Disposition': f'attachment; filename="{zip_filename}"'}
                )
                
            except Exception as e:
                # Clean up temporary file on error
                if os.path.exists(temp_zip.name):
                    os.unlink(temp_zip.name)
                log_security_event("zip_creation_error", f"Error creating ZIP: {str(e)}", None, None)
                raise HTTPException(status_code=500, detail=f"Error creating ZIP: {str(e)}")
        else:
            raise HTTPException(status_code=404, detail="Path is neither file nor folder")
        
    except HTTPException:
        raise
    except Exception as e:
        log_security_event("quick_share_error", f"Error in quick share: {str(e)}", None, None)
        raise HTTPException(status_code=500, detail=f"Error downloading: {str(e)}")

@app.post("/unshare_file")
async def unshare_file(
    request: UnshareFileRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Unshare a file from another user.
    Args:
        request (UnshareFileRequest): File information and target user.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about the operation result.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID (the one unsharing the file)
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Find the target user by email or username
    target_user = db.query(User).filter(
        (User.email == request.shared_with) | (User.username == request.shared_with)
    ).first()
    
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")
    
    # Get file record
    file_record = db.query(File).filter(
        File.filename == request.filename,
        File.folder_name == request.folder_name,
        File.user_id == user.id
    ).first()
    
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found in database")
    
    # Find the shared file record
    shared_file = db.query(SharedFile).filter(
        SharedFile.original_file_id == file_record.id,
        SharedFile.shared_with_user_id == target_user.id,
        SharedFile.shared_by_user_id == user.id
    ).first()
    
    if not shared_file:
        raise HTTPException(status_code=404, detail="File is not shared with this user")
    
    try:
        # Delete the shared file record
        db.delete(shared_file)
        
        # Find and delete the shared file from target user's shared folder
        target_shared_folder = os.path.join(os.getcwd(), target_user.username, "shared")
        target_file_path = os.path.join(target_shared_folder, request.filename)
        
        # Check if file exists and delete it
        if os.path.exists(target_file_path):
            os.remove(target_file_path)
        
        # Delete the file record for the shared file
        shared_file_record = db.query(File).filter(
            File.filename == request.filename,
            File.folder_name == f"{target_user.username}/shared",
            File.user_id == target_user.id
        ).first()
        
        if shared_file_record:
            db.delete(shared_file_record)
        
        db.commit()
        
        return {
            "message": f"File {request.filename} unshared successfully from {target_user.username}"
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error unsharing file: {str(e)}")

@app.post("/unshare_folder")
async def unshare_folder(
    request: UnshareFolderRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Unshare a folder from another user.
    Args:
        request (UnshareFolderRequest): Folder information and target user.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about the operation result.
    Raises:
        HTTPException: 403/404 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID (the one unsharing the folder)
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Find the target user by email or username
    target_user = db.query(User).filter(
        (User.email == request.shared_with) | (User.username == request.shared_with)
    ).first()
    
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")
    
    # Find the shared folder record
    shared_folder = db.query(SharedFolder).filter(
        SharedFolder.folder_path == request.folder_path,
        SharedFolder.shared_with_user_id == target_user.id,
        SharedFolder.shared_by_user_id == user.id
    ).first()
    
    if not shared_folder:
        raise HTTPException(status_code=404, detail="Folder is not shared with this user")
    
    try:
        # Delete the shared folder record
        db.delete(shared_folder)
        
        # Remove the shared folder from target user's filesystem
        target_shared_folder = os.path.join(os.getcwd(), target_user.username, "shared", os.path.basename(request.folder_path))
        
        if os.path.exists(target_shared_folder):
            shutil.rmtree(target_shared_folder)
        
        # Delete all file records for files in the shared folder
        shared_files = db.query(File).filter(
            File.folder_name.like(f"{target_user.username}/shared/{os.path.basename(request.folder_path)}%"),
            File.user_id == target_user.id
        ).all()
        
        for shared_file in shared_files:
            db.delete(shared_file)
        
        db.commit()
        
        return {
            "message": f"Folder {os.path.basename(request.folder_path)} unshared successfully from {target_user.username}"
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error unsharing folder: {str(e)}")

@app.get("/security/status")
async def get_security_status(payload: dict = Depends(require_jwt_token)):
    """
    Get security status and statistics.
    Args:
        payload (dict): JWT token payload.
    Returns:
        dict: Security status information.
    """
    try:
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=403, detail="Invalid token")
        
        # Get user info
        db = SessionLocal()
        user = db.query(User).filter(User.username == username).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Check if user is admin (you can implement admin role logic here)
        is_admin = user.username == "admin"  # Simple admin check
        
        if not is_admin:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Get security statistics
        total_users = db.query(User).count()
        active_users = db.query(User).filter(User.is_active == True).count()
        locked_users = db.query(User).filter(User.account_locked_until.isnot(None)).count()
        total_files = db.query(File).count()
        
        # Get recent security events (last 24 hours)
        current_time = datetime.now()
        yesterday = current_time - timedelta(days=1)
        
        # This would require a security events table in a real implementation
        # For now, we'll return basic stats
        
        security_status = {
            "server_status": "secure",
            "security_features": {
                "rate_limiting": True,
                "file_validation": True,
                "path_traversal_protection": True,
                "account_lockout": True,
                "security_logging": True,
                "enhanced_password_validation": True
            },
            "statistics": {
                "total_users": total_users,
                "active_users": active_users,
                "locked_users": locked_users,
                "total_files": total_files,
                "max_file_size_mb": MAX_FILE_SIZE // (1024*1024),
                "blocked_file_types": len(BLOCKED_FILE_EXTENSIONS)
            },
            "configuration": {
                "max_login_attempts": MAX_LOGIN_ATTEMPTS,
                "lockout_duration_minutes": LOGIN_LOCKOUT_DURATION,
                "token_expiry_minutes": ACCESS_TOKEN_EXPIRE_MINUTES
            }
        }
        
        db.close()
        return security_status
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting security status: {str(e)}")

@app.post("/encrypt_file")
async def encrypt_file(
    request: EncryptFileRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Encrypt a file with a password.
    Args:
        request (EncryptFileRequest): File information and encryption password.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about the operation result.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Validate that the folder belongs to the authenticated user
    if not request.folder_name.startswith(username):
        raise HTTPException(status_code=403, detail="You are not authorized to access this folder")
    
    # Check if file exists
    file_path = os.path.join(os.getcwd(), request.folder_name, request.filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    # Get file record
    file_record = db.query(File).filter(
        File.filename == request.filename,
        File.folder_name == request.folder_name,
        File.user_id == user.id
    ).first()
    
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found in database")
    
    # Check if file is already encrypted
    encrypted_record = db.query(EncryptedFile).filter(EncryptedFile.file_id == file_record.id).first()
    if encrypted_record:
        raise HTTPException(status_code=409, detail="File is already encrypted")
    
    try:
        # Read file content
        with open(file_path, 'rb') as f:
            file_content = f.read()
        
        # Encrypt file content
        encrypted_content, salt = encrypt_file_content(file_content, request.encryption_password)
        
        # Write encrypted content back to file
        with open(file_path, 'wb') as f:
            f.write(encrypted_content)
        
        # Create encrypted file record
        encrypted_file = EncryptedFile(
            file_id=file_record.id,
            encryption_salt=base64.b64encode(salt).decode('utf-8'),
            encryption_algorithm="Fernet"
        )
        db.add(encrypted_file)
        
        # Update file record
        file_record.is_encrypted = True
        file_record.file_hash = hash_file_content(encrypted_content)
        file_record.file_size = len(encrypted_content)
        
        db.commit()
        
        log_security_event("file_encrypted", f"File encrypted: {request.filename}", None, username)
        
        return {
            "message": f"File {request.filename} encrypted successfully",
            "file_size": len(encrypted_content),
            "encryption_algorithm": "Fernet"
        }
        
    except Exception as e:
        db.rollback()
        log_security_event("encryption_error", f"Encryption failed: {str(e)}", None, username)
        raise HTTPException(status_code=500, detail=f"Error encrypting file: {str(e)}")

@app.post("/decrypt_file")
async def decrypt_file(
    request: DecryptFileRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Decrypt a file with a password.
    Args:
        request (DecryptFileRequest): File information and decryption password.
        payload (dict): JWT token payload.
        db (Session): SQLAlchemy session.
    Returns:
        dict: Message about the operation result.
    Raises:
        HTTPException: 403/404/500 on errors.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user ID
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Validate that the folder belongs to the authenticated user
    if not request.folder_name.startswith(username):
        raise HTTPException(status_code=403, detail="You are not authorized to access this folder")
    
    # Check if file exists
    file_path = os.path.join(os.getcwd(), request.folder_name, request.filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    # Get file record
    file_record = db.query(File).filter(
        File.filename == request.filename,
        File.folder_name == request.folder_name,
        File.user_id == user.id
    ).first()
    
    if not file_record:
        raise HTTPException(status_code=404, detail="File not found in database")
    
    # Check if file is encrypted
    encrypted_record = db.query(EncryptedFile).filter(EncryptedFile.file_id == file_record.id).first()
    if not encrypted_record:
        raise HTTPException(status_code=400, detail="File is not encrypted")
    
    try:
        # Read encrypted file content
        with open(file_path, 'rb') as f:
            encrypted_content = f.read()
        
        # Decode salt
        salt = base64.b64decode(encrypted_record.encryption_salt)
        
        # Decrypt file content
        try:
            decrypted_content = decrypt_file_content(encrypted_content, request.decryption_password, salt)
        except Exception:
            raise HTTPException(status_code=400, detail="Incorrect decryption password")
        
        # Write decrypted content back to file
        with open(file_path, 'wb') as f:
            f.write(decrypted_content)
        
        # Remove encrypted file record
        db.delete(encrypted_record)
        
        # Update file record
        file_record.is_encrypted = False
        file_record.file_hash = hash_file_content(decrypted_content)
        file_record.file_size = len(decrypted_content)
        
        db.commit()
        
        log_security_event("file_decrypted", f"File decrypted: {request.filename}", None, username)
        
        return {
            "message": f"File {request.filename} decrypted successfully",
            "file_size": len(decrypted_content)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        log_security_event("decryption_error", f"Decryption failed: {str(e)}", None, username)
        raise HTTPException(status_code=500, detail=f"Error decrypting file: {str(e)}")

@app.get("/security/status")
async def get_security_status(payload: dict = Depends(require_jwt_token)):
    """
    Get security status and statistics.
    Args:
        payload (dict): JWT token payload.
    Returns:
        dict: Security status information.
    """
    try:
        username = payload.get("sub")
        if not username:
            raise HTTPException(status_code=403, detail="Invalid token")
        
        # Get user info
        db = SessionLocal()
        user = db.query(User).filter(User.username == username).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Check if user is admin (you can implement admin role logic here)
        is_admin = user.username == "admin"  # Simple admin check
        
        if not is_admin:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Get security statistics
        total_users = db.query(User).count()
        active_users = db.query(User).filter(User.is_active == True).count()
        locked_users = db.query(User).filter(User.account_locked_until.isnot(None)).count()
        total_files = db.query(File).count()
        
        # Get recent security events (last 24 hours)
        current_time = datetime.now()
        yesterday = current_time - timedelta(days=1)
        
        # This would require a security events table in a real implementation
        # For now, we'll return basic stats
        
        security_status = {
            "server_status": "secure",
            "security_features": {
                "rate_limiting": True,
                "file_validation": True,
                "path_traversal_protection": True,
                "account_lockout": True,
                "security_logging": True,
                "enhanced_password_validation": True
            },
            "statistics": {
                "total_users": total_users,
                "active_users": active_users,
                "locked_users": locked_users,
                "total_files": total_files,
                "max_file_size_mb": MAX_FILE_SIZE // (1024*1024),
                "blocked_file_types": len(BLOCKED_FILE_EXTENSIONS)
            },
            "configuration": {
                "max_login_attempts": MAX_LOGIN_ATTEMPTS,
                "lockout_duration_minutes": LOGIN_LOCKOUT_DURATION,
                "token_expiry_minutes": ACCESS_TOKEN_EXPIRE_MINUTES
            }
        }
        
        db.close()
        return security_status
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting security status: {str(e)}")

# -----------------------------------
# Enhanced Security Functions
# -----------------------------------

def generate_secure_session_id() -> str:
    """Generate a secure session ID."""
    return str(uuid.uuid4())

def hash_token(token: str) -> str:
    """Hash JWT token for storage."""
    return hashlib.sha256(token.encode()).hexdigest()

def validate_session(session_id: str, user_id: int, db: Session) -> bool:
    """Validate if session is active and not expired."""
    session = db.query(UserSession).filter(
        UserSession.session_id == session_id,
        UserSession.user_id == user_id,
        UserSession.is_active == True,
        UserSession.expires_at > datetime.utcnow()
    ).first()
    
    if session:
        # Update last activity
        session.last_activity = datetime.utcnow()
        db.commit()
        return True
    return False

def create_session(user_id: int, token: str, ip_address: str, user_agent: str, db: Session) -> str:
    """Create a new user session."""
    session_id = generate_secure_session_id()
    token_hash = hash_token(token)
    expires_at = datetime.utcnow() + timedelta(minutes=SECURITY_CONFIG['session_timeout_minutes'])
    
    session = UserSession(
        user_id=user_id,
        session_id=session_id,
        token_hash=token_hash,
        ip_address=ip_address,
        user_agent=user_agent,
        expires_at=expires_at
    )
    
    db.add(session)
    db.commit()
    return session_id

def invalidate_session(session_id: str, db: Session) -> bool:
    """Invalidate a user session."""
    session = db.query(UserSession).filter(UserSession.session_id == session_id).first()
    if session:
        session.is_active = False
        db.commit()
        return True
    return False

def cleanup_expired_sessions(db: Session) -> int:
    """Clean up expired sessions."""
    expired_sessions = db.query(UserSession).filter(
        UserSession.expires_at < datetime.utcnow()
    ).all()
    
    count = len(expired_sessions)
    for session in expired_sessions:
        db.delete(session)
    
    db.commit()
    return count

def check_password_history(user_id: int, new_password: str, db: Session) -> bool:
    """Check if password was used recently."""
    password_history_size = SECURITY_CONFIG['password_history_size']
    
    # Get recent password hashes
    recent_passwords = db.query(PasswordHistory).filter(
        PasswordHistory.user_id == user_id
    ).order_by(PasswordHistory.created_at.desc()).limit(password_history_size).all()
    
    new_password_hash = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    for password_record in recent_passwords:
        if bcrypt.checkpw(new_password.encode('utf-8'), password_record.password_hash.encode('utf-8')):
            return False  # Password was used recently
    
    return True

def add_to_password_history(user_id: int, password_hash: str, db: Session):
    """Add password to history."""
    password_history = PasswordHistory(
        user_id=user_id,
        password_hash=password_hash
    )
    db.add(password_history)
    db.commit()

def log_security_event_enhanced(event_type: str, details: str, severity: str = "medium", 
                               user_ip: str = None, username: str = None, 
                               user_agent: str = None, request_path: str = None, 
                               request_method: str = None, db: Session = None):
    """Enhanced security event logging with database storage."""
    # Log to file
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "event_type": event_type,
        "severity": severity,
        "details": details,
        "user_ip": user_ip,
        "username": username,
        "user_agent": user_agent,
        "request_path": request_path,
        "request_method": request_method
    }
    
    # Add to in-memory list for quick access
    security_events.append(log_entry)
    
    # Keep only last 1000 events in memory
    if len(security_events) > 1000:
        security_events.pop(0)
    
    # Log to file with enhanced format
    log_record = security_logger.makeRecord(
        'security', logging.INFO, '', 0, 
        f"SECURITY_EVENT: {json.dumps(log_entry)}", 
        (), None
    )
    log_record.ip = user_ip or 'unknown'
    log_record.user = username or 'unknown'
    security_logger.handle(log_record)
    
    # Store in database if session available
    if db:
        try:
            security_event = SecurityEvent(
                event_type=event_type,
                severity=severity,
                details=details,
                user_ip=user_ip,
                username=username,
                user_agent=user_agent,
                request_path=request_path,
                request_method=request_method
            )
            db.add(security_event)
            db.commit()
        except Exception as e:
            print(f"Error storing security event in database: {e}")

def validate_file_content(file_content: bytes, filename: str) -> Tuple[bool, str]:
    """Validate file content for malicious patterns."""
    try:
        # Simple MIME type detection based on file extension
        file_extension = filename.lower().split('.')[-1] if '.' in filename else ''
        
        # Define text file extensions
        text_extensions = ['txt', 'md', 'json', 'xml', 'html', 'htm', 'css', 'js', 'py', 'java', 'cpp', 'c', 'h', 'sql', 'log', 'csv']
        
        # Check if it's a text file based on extension
        if file_extension in text_extensions:
            try:
                content_str = file_content.decode('utf-8', errors='ignore')
                
                # Check for script tags in text files
                if '<script' in content_str.lower():
                    return False, "File contains script tags"
                
                # Check for PHP code
                if '<?php' in content_str or '<?=' in content_str:
                    return False, "File contains PHP code"
                
                # Check for SQL injection patterns
                sql_patterns = [
                    r'\b(union|select|insert|update|delete|drop|create|alter|exec|execute)\b',
                    r'\b(or|and)\b\s+\d+\s*=\s*\d+',
                    r'--|#|/\*|\*/'
                ]
                
                for pattern in sql_patterns:
                    if re.search(pattern, content_str, re.IGNORECASE):
                        return False, f"File contains suspicious SQL patterns"
            except UnicodeDecodeError:
                # If we can't decode as UTF-8, it's likely not a text file
                pass
        
        # Check for executable file extensions
        executable_extensions = ['exe', 'bat', 'cmd', 'com', 'pif', 'scr', 'vbs', 'js', 'jar', 'msi', 'dmg', 'app']
        if file_extension in executable_extensions:
            return False, "File appears to be executable"
        
        # Check for common executable signatures in binary files
        if file_content.startswith(b'MZ') or file_content.startswith(b'PE\x00\x00'):
            return False, "File contains executable signature"
        
        return True, "File content validated successfully"
        
    except Exception as e:
        return False, f"Error validating file content: {str(e)}"

async def scan_file_for_viruses(file_path: str) -> Tuple[bool, str]:
    """Scan file for viruses (placeholder implementation)."""
    try:
        # This is a placeholder - in production, integrate with actual antivirus
        # For now, we'll do basic heuristic checks
        
        with open(file_path, 'rb') as f:
            content = f.read(1024)  # Read first 1KB
        
        # Check for common virus signatures (very basic)
        virus_signatures = [
            b'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*',
            b'MZ',  # DOS executable header
            b'PE\x00\x00',  # Windows executable header
        ]
        
        for signature in virus_signatures:
            if signature in content:
                return False, f"File contains suspicious signature: {signature}"
        
        # Check file size (suspiciously small files might be malicious)
        file_size = os.path.getsize(file_path)
        if file_size < 100 and not file_path.endswith('.txt'):
            return False, "File is suspiciously small"
        
        return True, "File passed virus scan"
        
    except Exception as e:
        return False, f"Error scanning file: {str(e)}"

def generate_csrf_token() -> str:
    """Generate CSRF token."""
    return secrets.token_urlsafe(32)

def validate_csrf_token(token: str, stored_token: str) -> bool:
    """Validate CSRF token."""
    return hmac.compare_digest(token, stored_token)

def sanitize_input(input_str: str) -> str:
    """Sanitize user input to prevent XSS and injection attacks."""
    if not input_str:
        return ""
    
    # Remove null bytes
    input_str = input_str.replace('\x00', '')
    
    # Remove control characters except newlines and tabs
    input_str = ''.join(char for char in input_str if ord(char) >= 32 or char in '\n\t')
    
    # HTML encode special characters
    html_entities = {
        '<': '&lt;',
        '>': '&gt;',
        '&': '&amp;',
        '"': '&quot;',
        "'": '&#x27;'
    }
    
    for char, entity in html_entities.items():
        input_str = input_str.replace(char, entity)
    
    return input_str

def validate_ip_address(ip: str) -> bool:
    """Validate IP address format."""
    try:
        import ipaddress
        ipaddress.ip_address(ip)
        return True
    except ValueError:
        return False

def get_real_ip(request: Request) -> str:
    """Get real IP address from request, handling proxies."""
    # Check for forwarded headers
    forwarded_for = request.headers.get('X-Forwarded-For')
    if forwarded_for:
        # Take the first IP in the list
        return forwarded_for.split(',')[0].strip()
    
    real_ip = request.headers.get('X-Real-IP')
    if real_ip:
        return real_ip
    
    # Fallback to client host
    return request.client.host if request.client else 'unknown'

def rate_limit_check(client_ip: str, endpoint: str, max_requests: int = None, window: int = None) -> bool:
    """Enhanced rate limiting check."""
    if max_requests is None:
        max_requests = SECURITY_CONFIG['rate_limit_max_requests']
    if window is None:
        window = SECURITY_CONFIG['rate_limit_window']
    
    current_time = time.time()
    key = f"{client_ip}:{endpoint}"
    
    if key not in file_upload_attempts:
        file_upload_attempts[key] = []
    
    # Remove old attempts
    file_upload_attempts[key] = [
        attempt_time for attempt_time in file_upload_attempts[key]
        if current_time - attempt_time < window
    ]
    
    # Check if limit exceeded
    if len(file_upload_attempts[key]) >= max_requests:
        return False
    
    # Add current attempt
    file_upload_attempts[key].append(current_time)
    return True

def encrypt_sensitive_data(data: str) -> str:
    """Encrypt sensitive data for storage."""
    # In production, use a proper encryption key management system
    key = os.getenv("ENCRYPTION_KEY", "default-key-change-in-production")
    fernet = Fernet(base64.urlsafe_b64encode(hashlib.sha256(key.encode()).digest()))
    return fernet.encrypt(data.encode()).decode()

def decrypt_sensitive_data(encrypted_data: str) -> str:
    """Decrypt sensitive data."""
    key = os.getenv("ENCRYPTION_KEY", "default-key-change-in-production")
    fernet = Fernet(base64.urlsafe_b64encode(hashlib.sha256(key.encode()).digest()))
    return fernet.decrypt(encrypted_data.encode()).decode()

def validate_file_upload_safety(file: UploadFile, max_size: int = None) -> Tuple[bool, str]:
    """Comprehensive file upload safety validation."""
    if max_size is None:
        max_size = SECURITY_CONFIG['max_request_size']
    
    # Check file size
    if hasattr(file, 'size') and file.size > max_size:
        return False, f"File too large. Maximum size is {max_size // (1024*1024)}MB"
    
    # Validate filename
    if not file.filename:
        return False, "No filename provided"
    
    # Check filename length
    if len(file.filename) > SECURITY_CONFIG['max_file_name_length']:
        return False, "Filename too long"
    
    # Validate file extension
    if not validate_file_extension(file.filename):
        return False, "File type not allowed"
    
    # Check for double extensions (e.g., file.txt.exe)
    name_parts = file.filename.split('.')
    if len(name_parts) > 2:
        # Check if any part looks like an executable extension
        suspicious_extensions = {'exe', 'bat', 'cmd', 'com', 'pif', 'scr', 'vbs', 'js', 'jar'}
        for part in name_parts[1:]:  # Skip the first part (filename)
            if part.lower() in suspicious_extensions:
                return False, "Suspicious file extension detected"
    
    return True, "File upload validation passed"

def create_audit_trail(action: str, user_id: int, details: str, db: Session):
    """Create audit trail entry."""
    try:
        # This could be expanded to a separate audit table
        log_security_event_enhanced(
            event_type="audit",
            details=f"Action: {action}, Details: {details}",
            severity="low",
            db=db
        )
    except Exception as e:
        print(f"Error creating audit trail: {e}")

# Enhanced security logging function (replaces the old one)
def log_security_event(event_type: str, details: str, user_ip: str = None, username: str = None):
    """Enhanced security event logging."""
    log_security_event_enhanced(
        event_type=event_type,
        details=details,
        severity="medium",
        user_ip=user_ip,
        username=username
    )

@app.post("/security/update_config")
async def update_security_config(
    request: SecurityConfigRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Update security configuration (admin only).
    Args:
        request (SecurityConfigRequest): Security configuration updates.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Updated configuration.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Check if user is admin
    user = db.query(User).filter(User.username == username).first()
    if not user or user.username != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Update configuration
    updated_config = {}
    
    if request.max_file_size is not None:
        global MAX_FILE_SIZE
        MAX_FILE_SIZE = request.max_file_size
        updated_config["max_file_size"] = request.max_file_size
    
    if request.max_login_attempts is not None:
        global MAX_LOGIN_ATTEMPTS
        MAX_LOGIN_ATTEMPTS = request.max_login_attempts
        updated_config["max_login_attempts"] = request.max_login_attempts
    
    if request.session_timeout_minutes is not None:
        SECURITY_CONFIG['session_timeout_minutes'] = request.session_timeout_minutes
        updated_config["session_timeout_minutes"] = request.session_timeout_minutes
    
    if request.enable_virus_scanning is not None:
        SECURITY_CONFIG['virus_scanning'] = request.enable_virus_scanning
        updated_config["enable_virus_scanning"] = request.enable_virus_scanning
    
    if request.enable_encryption is not None:
        SECURITY_CONFIG['encryption_at_rest'] = request.enable_encryption
        updated_config["enable_encryption"] = request.enable_encryption
    
    # Log configuration change
    log_security_event_enhanced(
        "config_updated",
        f"Security configuration updated: {updated_config}",
        severity="medium",
        username=username,
        db=db
    )
    
    return {
        "message": "Security configuration updated successfully",
        "updated_config": updated_config
    }

@app.get("/security/audit_log")
async def get_audit_log(
    request: AuditLogRequest = Depends(),
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get audit log entries (admin only).
    Args:
        request (AuditLogRequest): Audit log query parameters.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Audit log entries.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Check if user is admin
    user = db.query(User).filter(User.username == username).first()
    if not user or user.username != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Build query
    query = db.query(SecurityEvent)
    
    if request.start_date:
        query = query.filter(SecurityEvent.timestamp >= request.start_date)
    
    if request.end_date:
        query = query.filter(SecurityEvent.timestamp <= request.end_date)
    
    if request.event_type:
        query = query.filter(SecurityEvent.event_type == request.event_type)
    
    if request.severity:
        query = query.filter(SecurityEvent.severity == request.severity)
    
    if request.username:
        query = query.filter(SecurityEvent.username == request.username)
    
    # Apply pagination
    total_count = query.count()
    
    if request.offset:
        query = query.offset(request.offset)
    
    if request.limit:
        query = query.limit(request.limit)
    else:
        query = query.limit(100)  # Default limit
    
    # Get results
    events = query.order_by(SecurityEvent.timestamp.desc()).all()
    
    return {
        "events": [
            {
                "id": event.id,
                "event_type": event.event_type,
                "severity": event.severity,
                "details": event.details,
                "user_ip": event.user_ip,
                "username": event.username,
                "user_agent": event.user_agent,
                "request_path": event.request_path,
                "request_method": event.request_method,
                "timestamp": event.timestamp.isoformat(),
                "resolved": event.resolved,
                "resolution_notes": event.resolution_notes
            }
            for event in events
        ],
        "total_count": total_count,
        "limit": request.limit or 100,
        "offset": request.offset or 0
    }

@app.post("/security/block_ip")
async def block_ip_address(
    request: Request,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Block an IP address (admin only).
    Args:
        request (Request): HTTP request with IP address in body.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Block status.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Check if user is admin
    user = db.query(User).filter(User.username == username).first()
    if not user or user.username != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        body = await request.json()
        ip_address = body.get("ip_address")
        duration_minutes = body.get("duration_minutes", 60)
        
        if not ip_address:
            raise HTTPException(status_code=400, detail="IP address is required")
        
        if not validate_ip_address(ip_address):
            raise HTTPException(status_code=400, detail="Invalid IP address format")
        
        # Block the IP
        blocked_ips[ip_address] = datetime.now() + timedelta(minutes=duration_minutes)
        
        # Log the action
        log_security_event_enhanced(
            "ip_blocked_admin",
            f"IP {ip_address} blocked for {duration_minutes} minutes by admin",
            severity="high",
            username=username,
            user_ip=ip_address,
            db=db
        )
        
        return {
            "message": f"IP {ip_address} blocked for {duration_minutes} minutes",
            "blocked_until": blocked_ips[ip_address].isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error blocking IP: {str(e)}")

@app.post("/security/unblock_ip")
async def unblock_ip_address(
    request: Request,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Unblock an IP address (admin only).
    Args:
        request (Request): HTTP request with IP address in body.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Unblock status.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Check if user is admin
    user = db.query(User).filter(User.username == username).first()
    if not user or user.username != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        body = await request.json()
        ip_address = body.get("ip_address")
        
        if not ip_address:
            raise HTTPException(status_code=400, detail="IP address is required")
        
        if ip_address in blocked_ips:
            del blocked_ips[ip_address]
            
            # Log the action
            log_security_event_enhanced(
                "ip_unblocked_admin",
                f"IP {ip_address} unblocked by admin",
                severity="medium",
                username=username,
                user_ip=ip_address,
                db=db
            )
            
            return {"message": f"IP {ip_address} unblocked successfully"}
        else:
            return {"message": f"IP {ip_address} was not blocked"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error unblocking IP: {str(e)}")

@app.get("/security/blocked_ips")
async def get_blocked_ips(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get list of blocked IP addresses (admin only).
    Args:
        payload (dict): JWT token payload.
    Returns:
        dict: List of blocked IPs.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Check if user is admin
    user = db.query(User).filter(User.username == username).first()
    if not user or user.username != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    current_time = datetime.now()
    active_blocks = {}
    
    for ip, block_until in blocked_ips.items():
        if current_time < block_until:
            active_blocks[ip] = {
                "blocked_until": block_until.isoformat(),
                "remaining_minutes": int((block_until - current_time).total_seconds() / 60)
            }
    
    return {
        "blocked_ips": active_blocks,
        "total_blocked": len(active_blocks)
    }

@app.post("/security/cleanup_sessions")
async def cleanup_expired_sessions_endpoint(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Clean up expired sessions (admin only).
    Args:
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Cleanup results.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Check if user is admin
    user = db.query(User).filter(User.username == username).first()
    if not user or user.username != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        cleaned_count = cleanup_expired_sessions(db)
        
        # Log the action
        log_security_event_enhanced(
            "sessions_cleaned",
            f"Cleaned up {cleaned_count} expired sessions",
            severity="low",
            username=username,
            db=db
        )
        
        return {
            "message": f"Cleaned up {cleaned_count} expired sessions",
            "cleaned_count": cleaned_count
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error cleaning up sessions: {str(e)}")

@app.post("/security/scan_file")
async def scan_file_security(
    request: Request,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Scan a file for security issues (admin only).
    Args:
        request (Request): HTTP request with file path in body.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Scan results.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Check if user is admin
    user = db.query(User).filter(User.username == username).first()
    if not user or user.username != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        body = await request.json()
        file_path = body.get("file_path")
        
        if not file_path:
            raise HTTPException(status_code=400, detail="File path is required")
        
        full_path = os.path.join(os.getcwd(), file_path)
        
        if not os.path.exists(full_path):
            raise HTTPException(status_code=404, detail="File not found")
        
        # Perform security scan
        # Simple MIME type detection based on file extension
        file_extension = os.path.splitext(full_path)[1].lower()
        mime_type_map = {
            '.txt': 'text/plain',
            '.pdf': 'application/pdf',
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.doc': 'application/msword',
            '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            '.xls': 'application/vnd.ms-excel',
            '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            '.zip': 'application/zip',
            '.rar': 'application/x-rar-compressed',
            '.mp3': 'audio/mpeg',
            '.mp4': 'video/mp4',
            '.avi': 'video/x-msvideo',
            '.py': 'text/x-python',
            '.js': 'application/javascript',
            '.html': 'text/html',
            '.css': 'text/css',
            '.json': 'application/json',
            '.xml': 'application/xml'
        }
        file_type = mime_type_map.get(file_extension, 'application/octet-stream')
        
        scan_results = {
            "file_path": file_path,
            "file_size": os.path.getsize(full_path),
            "file_type": file_type,
            "scan_timestamp": datetime.now().isoformat()
        }
        
        # Virus scan
        if SECURITY_CONFIG['virus_scanning']:
            is_clean, virus_result = await scan_file_for_viruses(full_path)
            scan_results["virus_scan"] = {
                "is_clean": is_clean,
                "result": virus_result
            }
        
        # Content validation
        with open(full_path, 'rb') as f:
            content = f.read(1024)  # Read first 1KB for analysis
        
        is_valid, content_result = validate_file_content(content, os.path.basename(full_path))
        scan_results["content_validation"] = {
            "is_valid": is_valid,
            "result": content_result
        }
        
        # Log the scan
        log_security_event_enhanced(
            "file_scanned",
            f"Security scan performed on {file_path}",
            severity="low",
            username=username,
            db=db
        )
        
        return scan_results
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error scanning file: {str(e)}")

# Initialize security logging
security_logger.info("Server started with enhanced security features")
security_logger.info(f"Max file size: {MAX_FILE_SIZE // (1024*1024)}MB")
security_logger.info(f"Blocked file extensions: {len(BLOCKED_FILE_EXTENSIONS)}")
security_logger.info(f"Security configuration loaded: {len(SECURITY_CONFIG)} settings")

# Background task to clean up expired sessions periodically
async def periodic_cleanup():
    """Background task to clean up expired sessions and logs."""
    while True:
        try:
            db = SessionLocal()
            cleaned_sessions = cleanup_expired_sessions(db)
            
            if cleaned_sessions > 0:
                security_logger.info(f"Background cleanup: removed {cleaned_sessions} expired sessions")
            
            db.close()
            
            # Wait for 1 hour before next cleanup
            await asyncio.sleep(3600)
            
        except Exception as e:
            security_logger.error(f"Error in periodic cleanup: {e}")
            await asyncio.sleep(300)  # Wait 5 minutes on error

# Start background cleanup task
@app.on_event("startup")
async def startup_event():
    """Start background tasks on server startup."""
    asyncio.create_task(periodic_cleanup())
    security_logger.info("Background cleanup task started")

# ============================================================================
# GROUP MANAGEMENT ENDPOINTS
# ============================================================================

@app.post("/groups/create")
async def create_group(
    request: CreateGroupRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Create a new user group.
    Args:
        request (CreateGroupRequest): Group creation data.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Group creation result.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if group name already exists
    existing_group = db.query(UserGroup).filter(UserGroup.name == request.name).first()
    if existing_group:
        raise HTTPException(status_code=409, detail="Group name already exists")
    
    try:
        # Create the group
        new_group = UserGroup(
            name=request.name,
            description=request.description,
            created_by_user_id=user.id
        )
        db.add(new_group)
        db.commit()
        db.refresh(new_group)
        
        # Add creator as admin member
        member = UserGroupMember(
            group_id=new_group.id,
            user_id=user.id,
            added_by_user_id=user.id,
            is_admin=True
        )
        db.add(member)
        db.commit()
        
        # Log the action
        log_security_event_enhanced(
            "group_created",
            f"Group '{request.name}' created by {username}",
            severity="low",
            username=username,
            db=db
        )
        
        return {
            "message": f"Group '{request.name}' created successfully",
            "group": {
                "id": new_group.id,
                "name": new_group.name,
                "description": new_group.description,
                "created_by": username,
                "created_at": new_group.created_at.isoformat(),
                "member_count": 1
            }
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating group: {str(e)}")

@app.post("/groups/add_member")
async def add_group_member(
    request: AddGroupMemberRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Add a member to a group.
    Args:
        request (AddGroupMemberRequest): Member addition data.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Member addition result.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get current user
    current_user = db.query(User).filter(User.username == username).first()
    if not current_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get group
    group = db.query(UserGroup).filter(UserGroup.name == request.group_name).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    # Check if current user is admin of the group
    membership = db.query(UserGroupMember).filter(
        UserGroupMember.group_id == group.id,
        UserGroupMember.user_id == current_user.id,
        UserGroupMember.is_admin == True
    ).first()
    
    if not membership:
        raise HTTPException(status_code=403, detail="Only group admins can add members")
    
    # Get user to add (by username or email)
    try:
        username_to_add = get_username_from_email_or_username(request.user_identifier, db)
        user_to_add = db.query(User).filter(User.username == username_to_add).first()
        if not user_to_add:
            raise HTTPException(status_code=404, detail="User to add not found")
    except HTTPException:
        raise HTTPException(status_code=404, detail="User to add not found")
    
    # Check if user is already a member
    existing_member = db.query(UserGroupMember).filter(
        UserGroupMember.group_id == group.id,
        UserGroupMember.user_id == user_to_add.id
    ).first()
    
    if existing_member:
        raise HTTPException(status_code=409, detail="User is already a member of this group")
    
    try:
        # Add member
        new_member = UserGroupMember(
            group_id=group.id,
            user_id=user_to_add.id,
            added_by_user_id=current_user.id,
            is_admin=request.is_admin
        )
        db.add(new_member)
        db.commit()
        
        # Log the action
        log_security_event_enhanced(
            "group_member_added",
            f"User '{username_to_add}' added to group '{request.group_name}' by {username}",
            severity="low",
            username=username,
            db=db
        )
        
        return {
            "message": f"User '{username_to_add}' added to group '{request.group_name}' successfully",
            "member": {
                "username": username_to_add,
                "is_admin": request.is_admin,
                "added_by": username,
                "added_at": new_member.added_at.isoformat()
            }
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error adding member: {str(e)}")

@app.post("/groups/remove_member")
async def remove_group_member(
    request: RemoveGroupMemberRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Remove a member from a group.
    Args:
        request (RemoveGroupMemberRequest): Member removal data.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Member removal result.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get current user
    current_user = db.query(User).filter(User.username == username).first()
    if not current_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get group
    group = db.query(UserGroup).filter(UserGroup.name == request.group_name).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    # Check if current user is admin of the group
    membership = db.query(UserGroupMember).filter(
        UserGroupMember.group_id == group.id,
        UserGroupMember.user_id == current_user.id,
        UserGroupMember.is_admin == True
    ).first()
    
    if not membership:
        raise HTTPException(status_code=403, detail="Only group admins can remove members")
    
    # Get user to remove
    user_to_remove = db.query(User).filter(User.username == request.username).first()
    if not user_to_remove:
        raise HTTPException(status_code=404, detail="User to remove not found")
    
    # Check if user is a member
    member_to_remove = db.query(UserGroupMember).filter(
        UserGroupMember.group_id == group.id,
        UserGroupMember.user_id == user_to_remove.id
    ).first()
    
    if not member_to_remove:
        raise HTTPException(status_code=404, detail="User is not a member of this group")
    
    # Prevent removing the last admin
    if member_to_remove.is_admin:
        admin_count = db.query(UserGroupMember).filter(
            UserGroupMember.group_id == group.id,
            UserGroupMember.is_admin == True
        ).count()
        
        if admin_count <= 1:
            raise HTTPException(status_code=400, detail="Cannot remove the last admin from the group")
    
    try:
        # Remove member
        db.delete(member_to_remove)
        db.commit()
        
        # Log the action
        log_security_event_enhanced(
            "group_member_removed",
            f"User '{request.username}' removed from group '{request.group_name}' by {username}",
            severity="low",
            username=username,
            db=db
        )
        
        return {
            "message": f"User '{request.username}' removed from group '{request.group_name}' successfully"
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error removing member: {str(e)}")

@app.get("/groups/list")
async def list_groups(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    List all groups that the user is a member of.
    Args:
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: List of groups.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Get user's groups
        memberships = db.query(UserGroupMember).filter(
            UserGroupMember.user_id == user.id
        ).all()
        
        groups = []
        for membership in memberships:
            group = db.query(UserGroup).filter(UserGroup.id == membership.group_id).first()
            if group and group.is_active:
                # Get member count
                member_count = db.query(UserGroupMember).filter(
                    UserGroupMember.group_id == group.id
                ).count()
                
                # Get creator info
                creator = db.query(User).filter(User.id == group.created_by_user_id).first()
                
                groups.append({
                    "id": group.id,
                    "name": group.name,
                    "description": group.description,
                    "created_by": creator.username if creator else "Unknown",
                    "created_at": group.created_at.isoformat(),
                    "member_count": member_count,
                    "is_admin": membership.is_admin
                })
        
        return {
            "groups": groups,
            "total": len(groups)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing groups: {str(e)}")

@app.get("/groups/{group_name}/members")
async def list_group_members(
    group_name: str,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    List all members of a group.
    Args:
        group_name (str): Group name.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: List of group members.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get group
    group = db.query(UserGroup).filter(UserGroup.name == group_name).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    # Check if user is a member of the group
    membership = db.query(UserGroupMember).filter(
        UserGroupMember.group_id == group.id,
        UserGroupMember.user_id == user.id
    ).first()
    
    if not membership:
        raise HTTPException(status_code=403, detail="You are not a member of this group")
    
    try:
        # Get all members
        memberships = db.query(UserGroupMember).filter(
            UserGroupMember.group_id == group.id
        ).all()
        
        members = []
        for member in memberships:
            member_user = db.query(User).filter(User.id == member.user_id).first()
            if member_user:
                members.append({
                    "username": member_user.username,
                    "email": member_user.email,
                    "is_admin": member.is_admin,
                    "added_at": member.added_at.isoformat()
                })
        
        return {
            "group_name": group_name,
            "members": members,
            "total": len(members)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing group members: {str(e)}")

@app.post("/groups/share_file")
async def share_file_with_group(
    request: ShareFileWithGroupRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Share a file with a group.
    Args:
        request (ShareFileWithGroupRequest): File sharing data.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: File sharing result.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get group
    group = db.query(UserGroup).filter(UserGroup.name == request.group_name).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    # Check if user is a member of the group
    membership = db.query(UserGroupMember).filter(
        UserGroupMember.group_id == group.id,
        UserGroupMember.user_id == user.id
    ).first()
    
    if not membership:
        raise HTTPException(status_code=403, detail="You are not a member of this group")
    
    # Get file
    file = db.query(File).filter(
        File.filename == request.filename,
        File.folder_name == request.folder_name,
        File.user_id == user.id
    ).first()
    
    if not file:
        raise HTTPException(status_code=404, detail="File not found")
    
    # Check if already shared with group
    existing_share = db.query(GroupSharedFile).filter(
        GroupSharedFile.original_file_id == file.id,
        GroupSharedFile.shared_with_group_id == group.id
    ).first()
    
    if existing_share:
        raise HTTPException(status_code=409, detail="File is already shared with this group")
    
    try:
        # Share file with group
        group_share = GroupSharedFile(
            original_file_id=file.id,
            shared_with_group_id=group.id,
            shared_by_user_id=user.id
        )
        db.add(group_share)
        db.commit()
        
        # Log the action
        log_security_event_enhanced(
            "file_shared_with_group",
            f"File '{request.filename}' shared with group '{request.group_name}' by {username}",
            severity="low",
            username=username,
            db=db
        )
        
        return {
            "message": f"File '{request.filename}' shared with group '{request.group_name}' successfully"
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error sharing file: {str(e)}")

@app.post("/groups/share_folder")
async def share_folder_with_group(
    request: ShareFolderWithGroupRequest,
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Share a folder with a group.
    Args:
        request (ShareFolderWithGroupRequest): Folder sharing data.
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: Folder sharing result.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get group
    group = db.query(UserGroup).filter(UserGroup.name == request.group_name).first()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    # Check if user is a member of the group
    membership = db.query(UserGroupMember).filter(
        UserGroupMember.group_id == group.id,
        UserGroupMember.user_id == user.id
    ).first()
    
    if not membership:
        raise HTTPException(status_code=403, detail="You are not a member of this group")
    
    # Check if folder exists and belongs to user
    # If folder_path already contains username, use it as is
    if request.folder_path.startswith(f"{username}/"):
        folder_path = request.folder_path
    else:
        folder_path = f"{username}/{request.folder_path}"
    
    if not os.path.exists(folder_path):
        raise HTTPException(status_code=404, detail="Folder not found")
    
    # Check if already shared with group
    existing_share = db.query(GroupSharedFolder).filter(
        GroupSharedFolder.folder_path == request.folder_path,
        GroupSharedFolder.shared_with_group_id == group.id
    ).first()
    
    if existing_share:
        raise HTTPException(status_code=409, detail="Folder is already shared with this group")
    
    try:
        # Share folder with group
        group_share = GroupSharedFolder(
            folder_path=request.folder_path,
            shared_with_group_id=group.id,
            shared_by_user_id=user.id
        )
        db.add(group_share)
        db.commit()
        
        # Log the action
        log_security_event_enhanced(
            "folder_shared_with_group",
            f"Folder '{request.folder_path}' shared with group '{request.group_name}' by {username}",
            severity="low",
            username=username,
            db=db
        )
        
        return {
            "message": f"Folder '{request.folder_path}' shared with group '{request.group_name}' successfully"
        }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error sharing folder: {str(e)}")

@app.get("/groups/shared_files")
async def get_group_shared_files(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    username = payload.get("sub")
    print(f"[DEBUG] Username from JWT: {username}")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    print(f"[DEBUG] User found: {user.username if user else 'None'}")
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Get user's groups
        user_groups = db.query(UserGroupMember).filter(
            UserGroupMember.user_id == user.id
        ).all()
        print(f"[DEBUG] User groups count: {len(user_groups)}")
        
        shared_files = []
        for membership in user_groups:
            group = db.query(UserGroup).filter(UserGroup.id == membership.group_id).first()
            print(f"[DEBUG] Group: {group.name if group else 'None'}, Active: {group.is_active if group else 'N/A'}")
            if group and group.is_active:
                # Get files shared with this group
                group_shares = db.query(GroupSharedFile).filter(
                    GroupSharedFile.shared_with_group_id == group.id
                ).all()
                print(f"[DEBUG] Group shares count: {len(group_shares)}")
                
                for share in group_shares:
                    print(f"[DEBUG] Checking share by user_id: {share.shared_by_user_id}")
                    if share.shared_by_user_id != user.id:
                        file = db.query(File).filter(File.id == share.original_file_id).first()
                        print(f"[DEBUG] File found: {file.filename if file else 'None'}")
                        if file:
                            shared_by = db.query(User).filter(User.id == share.shared_by_user_id).first()
                            print(f"[DEBUG] Shared by: {shared_by.username if shared_by else 'None'}")
                            shared_files.append({
                                "filename": file.filename,
                                "folder_name": file.folder_name,
                                "file_size": file.file_size,
                                "shared_by": shared_by.username if shared_by else "Unknown",
                                "shared_at": share.created_at.isoformat(),
                                "group_name": group.name
                            })
        
        print(f"[DEBUG] Total shared files: {len(shared_files)}")
        return {
            "shared_files": shared_files,
            "total": len(shared_files)
        }
        
    except Exception as e:
        print(f"[ERROR] Exception in get_group_shared_files: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error getting shared files: {str(e)}")

@app.get("/groups/shared_folders")
async def get_group_shared_folders(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get folders shared with groups that the user is a member of.
    Args:
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: List of shared folders.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Get user's groups
        user_groups = db.query(UserGroupMember).filter(
            UserGroupMember.user_id == user.id
        ).all()
        
        shared_folders = []
        for membership in user_groups:
            group = db.query(UserGroup).filter(UserGroup.id == membership.group_id).first()
            if group and group.is_active:
                # Get folders shared with this group
                group_shares = db.query(GroupSharedFolder).filter(
                    GroupSharedFolder.shared_with_group_id == group.id
                ).all()
                
                for share in group_shares:
                    if share.shared_by_user_id != user.id:
                        shared_by = db.query(User).filter(User.id == share.shared_by_user_id).first()
                        shared_folders.append({
                            "folder_path": share.folder_path,
                            "shared_by": shared_by.username if shared_by else "Unknown",
                            "shared_at": share.created_at.isoformat(),
                            "group_name": group.name
                        })
        
        return {
            "shared_folders": shared_folders,
            "total": len(shared_folders)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting shared folders: {str(e)}")

@app.get("/groups/my_shared_files")
async def get_my_group_shared_files(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get files that the current user has shared with groups.
    Args:
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: List of files shared by the user with groups.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Get files shared by this user with groups
        group_shares = db.query(GroupSharedFile).filter(
            GroupSharedFile.shared_by_user_id == user.id
        ).all()
        
        shared_files = []
        for share in group_shares:
            file = db.query(File).filter(File.id == share.original_file_id).first()
            group = db.query(UserGroup).filter(UserGroup.id == share.shared_with_group_id).first()
            if file and group:
                shared_files.append({
                    "filename": file.filename,
                    "folder_name": file.folder_name,
                    "size_bytes": file.file_size,
                    "modification_date": file.uploaded_at.isoformat(),
                    "shared_at": share.created_at.isoformat(),
                    "group_name": group.name,
                    "group_description": group.description
                })
        
        return {
            "group_shared_files": shared_files,
            "total": len(shared_files)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting shared files: {str(e)}")

@app.get("/groups/my_shared_folders")
async def get_my_group_shared_folders(
    payload: dict = Depends(require_jwt_token),
    db: Session = Depends(get_db)
):
    """
    Get folders that the current user has shared with groups.
    Args:
        payload (dict): JWT token payload.
        db (Session): Database session.
    Returns:
        dict: List of folders shared by the user with groups.
    """
    username = payload.get("sub")
    if not username:
        raise HTTPException(status_code=403, detail="Invalid token")
    
    # Get user
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    try:
        # Get folders shared by this user with groups
        group_shares = db.query(GroupSharedFolder).filter(
            GroupSharedFolder.shared_by_user_id == user.id
        ).all()
        
        shared_folders = []
        for share in group_shares:
            group = db.query(UserGroup).filter(UserGroup.id == share.shared_with_group_id).first()
            if group:
                # Calculate folder stats (this would need to be implemented based on your folder structure)
                # For now, we'll use placeholder values
                file_count = 0
                folder_count = 0
                total_size = 0
                
                shared_folders.append({
                    "folder_name": share.folder_path.split('/')[-1],  # Get just the folder name
                    "folder_path": share.folder_path,
                    "total_size_bytes": total_size,
                    "modification_date": share.created_at.isoformat(),
                    "shared_at": share.created_at.isoformat(),
                    "group_name": group.name,
                    "group_description": group.description,
                    "file_count": file_count,
                    "folder_count": folder_count
                })
        
        return {
            "group_shared_folders": shared_folders,
            "total": len(shared_folders)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting shared folders: {str(e)}")

# -----------------------------------
# Account Deletion Endpoints
# -----------------------------------

@app.post("/request_account_deletion")
async def request_account_deletion(
    request: ResetPasswordRequest,  # Reuse the same model for email
    db: Session = Depends(get_db),
    api_key: str = Depends(require_api_key)
):
    """
    Request account deletion by sending a deletion token to user's email.
    Args:
        request (ResetPasswordRequest): Email address for account deletion.
        db (Session): Database session.
        api_key (str): API key from headers.
    Returns:
        dict: Message about deletion request status.
    Raises:
        HTTPException: 404 if user not found, 500 on email error.
    """
    user = db.query(User).filter(User.email == request.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if not user.verified:
        raise HTTPException(status_code=400, detail="Account must be verified before deletion")
    
    # Generate deletion token
    deletion_token = secrets.token_urlsafe(32)
    deletion_token_expiry = datetime.now(timezone.utc) + timedelta(hours=1)
    
    # Store deletion token in user record
    user.reset_token = deletion_token
    user.reset_token_expiry = deletion_token_expiry
    db.commit()
    
    # Send deletion email
    try:
        send_account_deletion_email(user.email, deletion_token, base_url=BASE_URL)
        return {"message": "Account deletion request sent to your email. Please check your inbox and follow the instructions."}
    except Exception as e:
        # Remove the token if email fails
        user.reset_token = None
        user.reset_token_expiry = None
        db.commit()
        raise HTTPException(status_code=500, detail="Failed to send deletion email. Please try again later.")

@app.post("/confirm_account_deletion")
async def confirm_account_deletion(
    request: ConfirmResetRequest,  # Reuse the same model for token and password
    db: Session = Depends(get_db),
    api_key: str = Depends(require_api_key)
):
    """
    Confirm account deletion with token and password verification.
    Args:
        request (ConfirmResetRequest): Token and password for account deletion.
        db (Session): Database session.
        api_key (str): API key from headers.
    Returns:
        dict: Message about deletion confirmation.
    Raises:
        HTTPException: 400 if invalid token or weak password.
    """
    # Waliduj nowe hasło
    if not validate_new_password(request.new_password):
        raise HTTPException(status_code=400, detail="Password does not meet security requirements")
    
    # Znajdź użytkownika z ważnym tokenem
    user = db.query(User).filter(
        User.reset_token == request.token,
        User.reset_token_expiry > datetime.utcnow()
    ).first()
    
    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    
    # Hashuj nowe hasło
    hashed_password = bcrypt.hashpw(request.new_password.encode('utf-8'), bcrypt.gensalt())
    user.password = hashed_password.decode('utf-8')
    
    # Wyczyść token
    user.reset_token = None
    user.reset_token_expiry = None
    db.commit()
    
    return {"message": "Password has been reset successfully"}

@app.post("/delete_account")
async def request_account_deletion(request: RequestAccountDeletionRequest, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Request account deletion by sending a token to the user's email.
    Args:
        request (RequestAccountDeletionRequest): JSON body with email.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: Success message (always the same for security).
    Raises:
        HTTPException: 429 if too many attempts.
    """
    email = request.email.lower()
    
    # Rate limiting - max 3 próby na godzinę
    current_time = time.time()
    if email in deletion_attempts:
        attempts = deletion_attempts[email]
        # Usuń stare próby (starsze niż 1 godzina)
        attempts = [t for t in attempts if current_time - t < 3600]
        
        if len(attempts) >= 3:
            raise HTTPException(status_code=429, detail="Too many deletion attempts. Please try again later.")
        
        attempts.append(current_time)
        deletion_attempts[email] = attempts
    else:
        deletion_attempts[email] = [current_time]
    
    # Sprawdź czy użytkownik istnieje
    user = db.query(User).filter(User.email == email).first()
    
    # Zawsze zwróć sukces, nawet jeśli użytkownik nie istnieje
    if user:
        # Generuj bezpieczny token
        deletion_token = secrets.token_urlsafe(32)
        expiry = datetime.utcnow() + timedelta(hours=1)
        
        # Zapisz token w bazie danych
        user.deletion_token = deletion_token
        user.deletion_token_expiry = expiry
        db.commit()
        
        # Wyślij email z linkiem usuwania konta
        try:
            send_account_deletion_email(user.email, deletion_token, base_url=BASE_URL)
        except Exception as e:
            print(f"[ERROR] Failed to send deletion email: {e}")
            # Nie przerywamy procesu, nawet jeśli email się nie wyśle
    
    return {"message": "Account deletion instructions have been sent to your email address."}

@app.post("/confirm_delete")
async def confirm_account_deletion(request: ConfirmAccountDeletionRequest, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Confirm account deletion with token.
    Args:
        request (ConfirmAccountDeletionRequest): JSON body with token.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: Success message.
    Raises:
        HTTPException: 400 if invalid token.
    """
    # Znajdź użytkownika z ważnym tokenem
    user = db.query(User).filter(
        User.deletion_token == request.token,
        User.deletion_token_expiry > datetime.utcnow()
    ).first()
    
    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired deletion token")
    
    # Usuń konto użytkownika i wszystkie powiązane dane
    try:
        # Usuń wszystkie ulubione dla plików tego użytkownika
        user_files = db.query(File).filter(File.user_id == user.id).all()
        for file in user_files:
            favorites_to_delete = db.query(Favorite).filter(Favorite.file_id == file.id).all()
            for favorite in favorites_to_delete:
                db.delete(favorite)
        
        # Usuń wszystkie udostępnione pliki gdzie ten użytkownik jest udostępniającym
        shared_files_as_sharer = db.query(SharedFile).filter(SharedFile.shared_by_user_id == user.id).all()
        for shared_file in shared_files_as_sharer:
            db.delete(shared_file)
        
        # Usuń wszystkie udostępnione pliki gdzie ten użytkownik jest odbiorcą
        shared_files_as_recipient = db.query(SharedFile).filter(SharedFile.shared_with_user_id == user.id).all()
        for shared_file in shared_files_as_recipient:
            db.delete(shared_file)
        
        # Usuń wszystkie udostępnione foldery gdzie ten użytkownik jest udostępniającym
        shared_folders_as_sharer = db.query(SharedFolder).filter(SharedFolder.shared_by_user_id == user.id).all()
        for shared_folder in shared_folders_as_sharer:
            db.delete(shared_folder)
        
        # Usuń wszystkie udostępnione foldery gdzie ten użytkownik jest odbiorcą
        shared_folders_as_recipient = db.query(SharedFolder).filter(SharedFolder.shared_with_user_id == user.id).all()
        for shared_folder in shared_folders_as_recipient:
            db.delete(shared_folder)
        
        # Usuń wszystkie członkostwa w grupach
        group_memberships = db.query(UserGroupMember).filter(UserGroupMember.user_id == user.id).all()
        for membership in group_memberships:
            db.delete(membership)
        
        # Usuń wszystkie rekordy historii haseł
        password_history_records = db.query(PasswordHistory).filter(PasswordHistory.user_id == user.id).all()
        for password_record in password_history_records:
            db.delete(password_record)
        
        # Usuń wszystkie sesje użytkownika
        user_sessions = db.query(UserSession).filter(UserSession.user_id == user.id).all()
        for session in user_sessions:
            db.delete(session)
        
        # Usuń wszystkie rekordy skanowania plików
        for file in user_files:
            file_scans = db.query(FileScan).filter(FileScan.file_id == file.id).all()
            for scan in file_scans:
                db.delete(scan)
        
        # Usuń wszystkie rekordy logów dostępu
        access_logs = db.query(AccessLog).filter(AccessLog.user_id == user.id).all()
        for log in access_logs:
            db.delete(log)
        
        # Usuń wszystkie rekordy historii zmian nazw
        for file in user_files:
            rename_records = db.query(RenameFile).filter(RenameFile.file_id == file.id).all()
            for rename_record in rename_records:
                db.delete(rename_record)
        
        # Usuń wszystkie zdarzenia bezpieczeństwa związane z tym użytkownikiem
        security_events = db.query(SecurityEvent).filter(SecurityEvent.username == user.username).all()
        for event in security_events:
            db.delete(event)
        
        # Usuń wszystkie udostępnione pliki grupowe gdzie ten użytkownik jest udostępniającym
        group_shared_files_as_sharer = db.query(GroupSharedFile).filter(GroupSharedFile.shared_by_user_id == user.id).all()
        for group_shared_file in group_shared_files_as_sharer:
            db.delete(group_shared_file)
        
        # Usuń wszystkie udostępnione foldery grupowe gdzie ten użytkownik jest udostępniającym
        group_shared_folders_as_sharer = db.query(GroupSharedFolder).filter(GroupSharedFolder.shared_by_user_id == user.id).all()
        for group_shared_folder in group_shared_folders_as_sharer:
            db.delete(group_shared_folder)
        
        # Usuń wszystkie rekordy zaszyfrowanych plików dla plików tego użytkownika
        for file in user_files:
            encrypted_file = db.query(EncryptedFile).filter(EncryptedFile.file_id == file.id).first()
            if encrypted_file:
                db.delete(encrypted_file)
        
        # Usuń wszystkie pliki tego użytkownika
        for file in user_files:
            db.delete(file)
        
        # Usuń folder użytkownika z systemu plików
        user_folder = os.path.join(os.getcwd(), user.username)
        if os.path.exists(user_folder):
            try:
                shutil.rmtree(user_folder)
            except Exception as e:
                print(f"[WARNING] Failed to delete user folder: {e}")
        
        # Usuń użytkownika z bazy danych
        db.delete(user)
        db.commit()
        
        return {"message": "Your account has been permanently deleted successfully"}
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error deleting account: {str(e)}")

@app.get("/delete-password")
async def validate_deletion_token(token: str, db: Session = Depends(get_db), api_key: str = Depends(require_api_key)):
    """
    Validate deletion token.
    Args:
        token (str): Deletion token from URL.
        db (Session): SQLAlchemy session.
        api_key (str): API key from headers.
    Returns:
        dict: Token validation status.
    """
    # Sprawdź czy token istnieje i jest ważny
    user = db.query(User).filter(
        User.deletion_token == token,
        User.deletion_token_expiry > datetime.utcnow()
    ).first()
    
    if user:
        return {"valid": True, "message": "Token is valid"}
    else:
        return {"valid": False, "message": "Invalid or expired token"}

# Uruchomienie serwera
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)