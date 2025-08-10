import requests
import json
import time
import hashlib
import os
import tempfile
from datetime import datetime, timedelta

class SecurityTester:
    def __init__(self, base_url="http://localhost:8000", api_key="test_key"):
        self.base_url = base_url
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({
            "API_KEY": api_key,
            "Content-Type": "application/json"
        })
        self.test_results = []
        
    def log_test(self, test_name, success, details=""):
        """Logs test result"""
        result = {
            "test": test_name,
            "success": success,
            "details": details,
            "timestamp": datetime.now().isoformat()
        }
        self.test_results.append(result)
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name}: {details}")
        
    def test_rate_limiting(self):
        """Tests rate limiting"""
        print("\n🔒 Testing Rate Limiting...")
        
        for i in range(15):
            response = self.session.post(f"{self.base_url}/login", json={
                "email": "test@test.com",
                "password": "wrong_password"
            })
            
            if response.status_code == 429:
                self.log_test("Rate Limiting - Login", True, f"Blocked after {i+1} attempts")
                break
        else:
            self.log_test("Rate Limiting - Login", False, "Not blocked after 15 attempts")
            
        time.sleep(2)
        
    def test_file_upload_validation(self):
        """Tests file upload validation"""
        print("\n📁 Testing File Validation...")
        
        with tempfile.NamedTemporaryFile(suffix=".exe", delete=False) as f:
            f.write(b"fake executable content")
            temp_file = f.name
            
        try:
            with open(temp_file, 'rb') as file:
                response = self.session.post(f"{self.base_url}/upload_file", 
                    files={"file": file},
                    data={"folder_info": '{"folder": "testuser"}'}
                )
                
            if response.status_code == 415:
                self.log_test("File Upload - Blocked Extension", True, "Blocked .exe file")
            else:
                self.log_test("File Upload - Blocked Extension", False, f"Status: {response.status_code}")
                
        finally:
            os.unlink(temp_file)
            
    def test_path_traversal(self):
        """Tests path traversal protection"""
        print("\n🛡️ Testing Path Traversal...")
        
        malicious_paths = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            "....//....//....//etc/passwd"
        ]
        
        for path in malicious_paths:
            response = self.session.get(f"{self.base_url}/download_file/{path}")
            if response.status_code in [403, 404, 400]:
                self.log_test(f"Path Traversal - {path}", True, f"Blocked: {path}")
            else:
                self.log_test(f"Path Traversal - {path}", False, f"Status: {response.status_code}")
                
    def test_sql_injection(self):
        """Tests SQL injection protection"""
        print("\n💉 Testing SQL Injection...")
        
        sql_payloads = [
            "admin' OR '1'='1",
            "'; DROP TABLE users; --",
            "admin' UNION SELECT * FROM users --",
            "1' OR 1=1--",
            "admin' AND 1=1--"
        ]
        
        for payload in sql_payloads:
            response = self.session.post(f"{self.base_url}/login", json={
                "email": payload,
                "password": "test"
            })
            
            if response.status_code == 403:
                self.log_test(f"SQL Injection - {payload[:20]}...", True, "Blocked by WAF")
            else:
                self.log_test(f"SQL Injection - {payload[:20]}...", False, f"Status: {response.status_code}")
                
    def test_xss_protection(self):
        """Tests XSS protection"""
        print("\n🕷️ Testing XSS Protection...")
        
        xss_payloads = [
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "<img src=x onerror=alert('xss')>",
            "<iframe src=javascript:alert('xss')>",
            "<svg onload=alert('xss')>"
        ]
        
        for payload in xss_payloads:
            response = self.session.post(f"{self.base_url}/login", json={
                "email": payload,
                "password": "test"
            })
            
            if response.status_code == 403:
                self.log_test(f"XSS Protection - {payload[:20]}...", True, "Blocked by WAF")
            else:
                self.log_test(f"XSS Protection - {payload[:20]}...", False, f"Status: {response.status_code}")
                
    def test_password_validation(self):
        """Tests password validation"""
        print("\n🔐 Testing Password Validation...")
        
        weak_passwords = [
            "123456",
            "password",
            "qwerty",
            "admin",
            "test123",
            "abc123",
            "password123",
            "letmein",
            "welcome",
            "monkey"
        ]
        
        for password in weak_passwords:
            response = self.session.post(f"{self.base_url}/create_user", json={
                "username": f"testuser_{int(time.time())}",
                "email": f"test{int(time.time())}@test.com",
                "password": password
            })
            
            if response.status_code == 400:
                self.log_test(f"Password Validation - {password}", True, "Rejected weak password")
            else:
                self.log_test(f"Password Validation - {password}", False, f"Status: {response.status_code}")
                
    def test_file_encryption(self):
        """Tests file encryption"""
        print("\n🔒 Testing File Encryption...")
        
        login_response = self.session.post(f"{self.base_url}/login", json={
            "email": "admin",
            "password": "admin_password"
        })
        
        if login_response.status_code == 200:
            token = login_response.json().get("access_token")
            self.session.headers.update({"Authorization": f"Bearer {token}"})
            
            with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
                f.write("Test content for encryption")
                temp_file = f.name
                
            try:
                with open(temp_file, 'rb') as file:
                    upload_response = self.session.post(f"{self.base_url}/upload_file",
                        files={"file": file},
                        data={"folder_info": '{"folder": "admin"}'}
                    )
                    
                if upload_response.status_code == 200:
                    encrypt_response = self.session.post(f"{self.base_url}/encrypt_file", json={
                        "filename": os.path.basename(temp_file),
                        "folder_name": "admin",
                        "encryption_password": "strong_password_123!"
                    })
                    
                    if encrypt_response.status_code == 200:
                        self.log_test("File Encryption", True, "File encrypted successfully")
                    else:
                        self.log_test("File Encryption", False, f"Status: {encrypt_response.status_code}")
                else:
                    self.log_test("File Encryption", False, f"Upload failed: {upload_response.status_code}")
                    
            finally:
                os.unlink(temp_file)
        else:
            self.log_test("File Encryption", False, "Unable to log in")
            
    def test_security_headers(self):
        """Tests security headers"""
        print("\n🛡️ Testing Security Headers...")
        
        response = self.session.get(f"{self.base_url}/security/status")
        headers = response.headers
        
        security_headers = {
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "X-XSS-Protection": "1; mode=block",
            "Strict-Transport-Security": "max-age=",
            "Content-Security-Policy": "default-src",
            "Referrer-Policy": "strict-origin-when-cross-origin"
        }
        
        for header, expected_value in security_headers.items():
            if header in headers:
                header_value = headers[header]
                if expected_value in header_value:
                    self.log_test(f"Security Header - {header}", True, f"Present: {header_value[:50]}...")
                else:
                    self.log_test(f"Security Header - {header}", False, f"Invalid value: {header_value}")
            else:
                self.log_test(f"Security Header - {header}", False, "Header missing")
                
    def test_admin_endpoints(self):
        """Tests administrative endpoints"""
        print("\n👨‍💼 Testing Administrative Endpoints...")
        
        response = self.session.get(f"{self.base_url}/security/status")
        if response.status_code == 200:
            data = response.json()
            if "security_features" in data:
                self.log_test("Admin Endpoint - Security Status", True, "Security status available")
            else:
                self.log_test("Admin Endpoint - Security Status", False, "No security data")
        else:
            self.log_test("Admin Endpoint - Security Status", False, f"Status: {response.status_code}")
            
    def test_session_management(self):
        """Tests session management"""
        print("\n⏰ Testing Session Management...")
        
        response = self.session.get(f"{self.base_url}/validate_token")
        if response.status_code == 401:
            self.log_test("Session Management - Token Expiry", True, "Token expired correctly")
        else:
            self.log_test("Session Management - Token Expiry", False, f"Status: {response.status_code}")
            
    def test_audit_logging(self):
        """Tests audit logging"""
        print("\n📝 Testing Audit Logging...")
        
        log_file = "security.log"
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                lines = f.readlines()
                if len(lines) > 0:
                    self.log_test("Audit Logging", True, f"Found {len(lines)} log entries")
                else:
                    self.log_test("Audit Logging", False, "Log is empty")
        else:
            self.log_test("Audit Logging", False, "Log file does not exist")
            
    def run_all_tests(self):
        """Runs all tests"""
        print("🚀 Starting ServApp security tests")
        print("=" * 60)
        
        self.test_rate_limiting()
        self.test_file_upload_validation()
        self.test_path_traversal()
        self.test_sql_injection()
        self.test_xss_protection()
        self.test_password_validation()
        self.test_file_encryption()
        self.test_security_headers()
        self.test_admin_endpoints()
        self.test_session_management()
        self.test_audit_logging()
        
        # Summary
        print("\n" + "=" * 60)
        print("📊 TEST SUMMARY")
        print("=" * 60)
        
        passed = sum(1 for result in self.test_results if result["success"])
        total = len(self.test_results)
        
        print(f"✅ Tests passed: {passed}/{total}")
        print(f"❌ Tests failed: {total - passed}/{total}")
        print(f"📈 Success rate: {(passed/total)*100:.1f}%")
        
        print("\n📋 DETAILED RESULTS:")
        for result in self.test_results:
            status = "✅" if result["success"] else "❌"
            print(f"{status} {result['test']}: {result['details']}")
            
        with open("security_test_results.json", "w") as f:
            json.dump(self.test_results, f, indent=2)
            
        print(f"\n💾 Results saved to: security_test_results.json")
        
        return passed, total

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Test ServApp security features")
    parser.add_argument("--url", default="http://localhost:8000", help="Server URL")
    parser.add_argument("--api-key", default="test_key", help="API Key")
    
    args = parser.parse_args()
    
    tester = SecurityTester(args.url, args.api_key)
    passed, total = tester.run_all_tests()
    
    exit(0 if passed == total else 1)

if __name__ == "__main__":
    main()