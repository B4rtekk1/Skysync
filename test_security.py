#!/usr/bin/env python3
"""
Skrypt testowy dla funkcji bezpieczeństwa ServApp
Testuje wszystkie nowe funkcje bezpieczeństwa wprowadzone do serwera.
"""

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
        """Loguje wynik testu"""
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
        """Testuje rate limiting"""
        print("\n🔒 Testowanie Rate Limiting...")
        
        # Test prób logowania
        for i in range(15):
            response = self.session.post(f"{self.base_url}/login", json={
                "email": "test@test.com",
                "password": "wrong_password"
            })
            
            if response.status_code == 429:
                self.log_test("Rate Limiting - Login", True, f"Zablokowano po {i+1} próbach")
                break
        else:
            self.log_test("Rate Limiting - Login", False, "Nie zablokowano po 15 próbach")
            
        # Czekaj na odblokowanie
        time.sleep(2)
        
    def test_file_upload_validation(self):
        """Testuje walidację uploadu plików"""
        print("\n📁 Testowanie Walidacji Plików...")
        
        # Test zabronionego rozszerzenia
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
                self.log_test("File Upload - Blocked Extension", True, "Zablokowano plik .exe")
            else:
                self.log_test("File Upload - Blocked Extension", False, f"Status: {response.status_code}")
                
        finally:
            os.unlink(temp_file)
            
    def test_path_traversal(self):
        """Testuje ochronę przed path traversal"""
        print("\n🛡️ Testowanie Path Traversal...")
        
        malicious_paths = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            "....//....//....//etc/passwd"
        ]
        
        for path in malicious_paths:
            response = self.session.get(f"{self.base_url}/download_file/{path}")
            if response.status_code in [403, 404, 400]:
                self.log_test(f"Path Traversal - {path}", True, f"Zablokowano: {path}")
            else:
                self.log_test(f"Path Traversal - {path}", False, f"Status: {response.status_code}")
                
    def test_sql_injection(self):
        """Testuje ochronę przed SQL injection"""
        print("\n💉 Testowanie SQL Injection...")
        
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
                self.log_test(f"SQL Injection - {payload[:20]}...", True, "Zablokowano przez WAF")
            else:
                self.log_test(f"SQL Injection - {payload[:20]}...", False, f"Status: {response.status_code}")
                
    def test_xss_protection(self):
        """Testuje ochronę przed XSS"""
        print("\n🕷️ Testowanie XSS Protection...")
        
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
                self.log_test(f"XSS Protection - {payload[:20]}...", True, "Zablokowano przez WAF")
            else:
                self.log_test(f"XSS Protection - {payload[:20]}...", False, f"Status: {response.status_code}")
                
    def test_password_validation(self):
        """Testuje walidację haseł"""
        print("\n🔐 Testowanie Walidacji Haseł...")
        
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
                self.log_test(f"Password Validation - {password}", True, "Odrzucono słabe hasło")
            else:
                self.log_test(f"Password Validation - {password}", False, f"Status: {response.status_code}")
                
    def test_file_encryption(self):
        """Testuje szyfrowanie plików"""
        print("\n🔒 Testowanie Szyfrowania Plików...")
        
        # Najpierw musimy się zalogować
        login_response = self.session.post(f"{self.base_url}/login", json={
            "email": "admin",  # Zakładamy, że admin istnieje
            "password": "admin_password"
        })
        
        if login_response.status_code == 200:
            token = login_response.json().get("access_token")
            self.session.headers.update({"Authorization": f"Bearer {token}"})
            
            # Utwórz testowy plik
            with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
                f.write("Test content for encryption")
                temp_file = f.name
                
            try:
                # Upload pliku
                with open(temp_file, 'rb') as file:
                    upload_response = self.session.post(f"{self.base_url}/upload_file",
                        files={"file": file},
                        data={"folder_info": '{"folder": "admin"}'}
                    )
                    
                if upload_response.status_code == 200:
                    # Test szyfrowania
                    encrypt_response = self.session.post(f"{self.base_url}/encrypt_file", json={
                        "filename": os.path.basename(temp_file),
                        "folder_name": "admin",
                        "encryption_password": "strong_password_123!"
                    })
                    
                    if encrypt_response.status_code == 200:
                        self.log_test("File Encryption", True, "Plik został zaszyfrowany")
                    else:
                        self.log_test("File Encryption", False, f"Status: {encrypt_response.status_code}")
                else:
                    self.log_test("File Encryption", False, f"Upload failed: {upload_response.status_code}")
                    
            finally:
                os.unlink(temp_file)
        else:
            self.log_test("File Encryption", False, "Nie można się zalogować")
            
    def test_security_headers(self):
        """Testuje nagłówki bezpieczeństwa"""
        print("\n🛡️ Testowanie Nagłówków Bezpieczeństwa...")
        
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
                    self.log_test(f"Security Header - {header}", True, f"Obecny: {header_value[:50]}...")
                else:
                    self.log_test(f"Security Header - {header}", False, f"Nieprawidłowa wartość: {header_value}")
            else:
                self.log_test(f"Security Header - {header}", False, "Brak nagłówka")
                
    def test_admin_endpoints(self):
        """Testuje endpointy administracyjne"""
        print("\n👨‍💼 Testowanie Endpointów Administracyjnych...")
        
        # Test statusu bezpieczeństwa
        response = self.session.get(f"{self.base_url}/security/status")
        if response.status_code == 200:
            data = response.json()
            if "security_features" in data:
                self.log_test("Admin Endpoint - Security Status", True, "Dostępny status bezpieczeństwa")
            else:
                self.log_test("Admin Endpoint - Security Status", False, "Brak danych bezpieczeństwa")
        else:
            self.log_test("Admin Endpoint - Security Status", False, f"Status: {response.status_code}")
            
    def test_session_management(self):
        """Testuje zarządzanie sesjami"""
        print("\n⏰ Testowanie Zarządzania Sesjami...")
        
        # Test wygaśnięcia tokenu
        response = self.session.get(f"{self.base_url}/validate_token")
        if response.status_code == 401:
            self.log_test("Session Management - Token Expiry", True, "Token wygasł prawidłowo")
        else:
            self.log_test("Session Management - Token Expiry", False, f"Status: {response.status_code}")
            
    def test_audit_logging(self):
        """Testuje logowanie audytu"""
        print("\n📝 Testowanie Logowania Audytu...")
        
        # Sprawdź czy logi są generowane
        log_file = "security.log"
        if os.path.exists(log_file):
            # Sprawdź ostatnie wpisy
            with open(log_file, 'r') as f:
                lines = f.readlines()
                if len(lines) > 0:
                    self.log_test("Audit Logging", True, f"Znaleziono {len(lines)} wpisów w logu")
                else:
                    self.log_test("Audit Logging", False, "Log jest pusty")
        else:
            self.log_test("Audit Logging", False, "Plik logu nie istnieje")
            
    def run_all_tests(self):
        """Uruchamia wszystkie testy"""
        print("🚀 Rozpoczynanie testów bezpieczeństwa ServApp")
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
        
        # Podsumowanie
        print("\n" + "=" * 60)
        print("📊 PODSUMOWANIE TESTÓW")
        print("=" * 60)
        
        passed = sum(1 for result in self.test_results if result["success"])
        total = len(self.test_results)
        
        print(f"✅ Testy zaliczone: {passed}/{total}")
        print(f"❌ Testy niezaliczone: {total - passed}/{total}")
        print(f"📈 Procent sukcesu: {(passed/total)*100:.1f}%")
        
        # Szczegółowe wyniki
        print("\n📋 SZCZEGÓŁOWE WYNIKI:")
        for result in self.test_results:
            status = "✅" if result["success"] else "❌"
            print(f"{status} {result['test']}: {result['details']}")
            
        # Zapisz wyniki do pliku
        with open("security_test_results.json", "w") as f:
            json.dump(self.test_results, f, indent=2)
            
        print(f"\n💾 Wyniki zapisane w: security_test_results.json")
        
        return passed, total

def main():
    """Główna funkcja"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Test funkcji bezpieczeństwa ServApp")
    parser.add_argument("--url", default="http://localhost:8000", help="URL serwera")
    parser.add_argument("--api-key", default="test_key", help="API Key")
    
    args = parser.parse_args()
    
    tester = SecurityTester(args.url, args.api_key)
    passed, total = tester.run_all_tests()
    
    # Zwróć kod wyjścia
    exit(0 if passed == total else 1)

if __name__ == "__main__":
    main() 