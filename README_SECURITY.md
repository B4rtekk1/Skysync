# 🛡️ ServApp - Instrukcje Bezpieczeństwa

## Przegląd

Ten dokument zawiera instrukcje dotyczące wdrażania i konfiguracji ulepszeń bezpieczeństwa dla aplikacji ServApp. Wszystkie funkcje zostały zaprojektowane z myślą o maksymalnej ochronie przed różnymi typami ataków.

## 🚀 Szybka Instalacja

### 1. Instalacja Zależności

```bash
# Instalacja podstawowych zależności bezpieczeństwa
pip install -r requirements_security.txt

# Lub instalacja pojedynczych pakietów
pip install python-magic cryptography aiofiles pydantic[email]
```

### 2. Konfiguracja Zmiennych Środowiskowych

Utwórz lub zaktualizuj plik `.env`:

```env
# Podstawowa konfiguracja
SECRET_KEY=your-very-secure-secret-key-minimum-32-characters
API_KEY=your-secure-api-key-here
BASE_URL=http://localhost:8000

# Konfiguracja email
EMAIL=your-email@gmail.com
PASSWORD=your-app-password

# Ulepszona konfiguracja bezpieczeństwa
ENCRYPTION_KEY=your-secure-encryption-key-32-characters
SECURITY_LOG_LEVEL=INFO
ENABLE_VIRUS_SCANNING=true
ENABLE_ENCRYPTION=true
MAX_FILE_SIZE=104857600
SESSION_TIMEOUT_MINUTES=30
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_WINDOW=60
```

### 3. Uruchomienie Serwera

```bash
# Uruchomienie z ulepszonymi funkcjami bezpieczeństwa
python server.py

# Lub z uvicorn
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
```

## 🔧 Konfiguracja Szczegółowa

### Konfiguracja Bezpieczeństwa

Wszystkie ustawienia bezpieczeństwa są dostępne w słowniku `SECURITY_CONFIG` w pliku `server.py`:

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

### Konfiguracja Logowania

Logi bezpieczeństwa są zapisywane w pliku `security.log` z następującym formatem:

```
2024-01-15 10:30:00 - INFO - [192.168.1.100] [testuser] SECURITY_EVENT: {"event_type": "failed_login", "details": "Invalid password", "severity": "medium"}
```

## 🧪 Testowanie Bezpieczeństwa

### Uruchomienie Testów

```bash
# Testowanie wszystkich funkcji bezpieczeństwa
python test_security.py

# Testowanie z niestandardowymi parametrami
python test_security.py --url http://localhost:8000 --api-key your_api_key
```

### Testy Do Wykonania

1. **Rate Limiting** - Sprawdza blokowanie po przekroczeniu limitów
2. **File Upload Validation** - Testuje walidację plików
3. **Path Traversal** - Sprawdza ochronę przed path traversal
4. **SQL Injection** - Testuje ochronę przed SQL injection
5. **XSS Protection** - Sprawdza ochronę przed XSS
6. **Password Validation** - Testuje walidację haseł
7. **File Encryption** - Sprawdza szyfrowanie plików
8. **Security Headers** - Testuje nagłówki bezpieczeństwa
9. **Admin Endpoints** - Sprawdza endpointy administracyjne
10. **Session Management** - Testuje zarządzanie sesjami
11. **Audit Logging** - Sprawdza logowanie audytu

### Przykłady Testów Ręcznych

```bash
# Test rate limiting
for i in {1..15}; do
  curl -X POST http://localhost:8000/login \
    -H "Content-Type: application/json" \
    -H "API_KEY: your_key" \
    -d '{"email":"test","password":"wrong"}'
done

# Test path traversal
curl "http://localhost:8000/download_file/../../../etc/passwd"

# Test SQL injection
curl "http://localhost:8000/login?user=admin' OR '1'='1"

# Test XSS
curl "http://localhost:8000/login?user=<script>alert('xss')</script>"
```

## 📊 Monitorowanie

### Logi Bezpieczeństwa

Wszystkie zdarzenia bezpieczeństwa są logowane w pliku `security.log`:

```bash
# Przeglądanie logów w czasie rzeczywistym
tail -f security.log

# Filtrowanie zdarzeń
grep "failed_login" security.log
grep "waf_blocked" security.log
grep "rate_limit" security.log
```

### Endpointy Monitorowania

#### `/security/status`
Zwraca status bezpieczeństwa serwera:

```bash
curl -H "Authorization: Bearer your_token" \
     http://localhost:8000/security/status
```

#### `/security/audit_log`
Przeglądanie logów audytu:

```bash
curl -H "Authorization: Bearer your_token" \
     "http://localhost:8000/security/audit_log?limit=50&severity=high"
```

#### `/security/blocked_ips`
Lista zablokowanych adresów IP:

```bash
curl -H "Authorization: Bearer your_token" \
     http://localhost:8000/security/blocked_ips
```

## 🔐 Zarządzanie Bezpieczeństwem

### Blokowanie IP

```bash
# Blokowanie adresu IP
curl -X POST http://localhost:8000/security/block_ip \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{"ip_address": "192.168.1.100", "duration_minutes": 60}'
```

### Odblokowanie IP

```bash
# Odblokowanie adresu IP
curl -X POST http://localhost:8000/security/unblock_ip \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{"ip_address": "192.168.1.100"}'
```

### Aktualizacja Konfiguracji

```bash
# Aktualizacja ustawień bezpieczeństwa
curl -X POST http://localhost:8000/security/update_config \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "max_file_size": 52428800,
    "session_timeout_minutes": 60,
    "enable_virus_scanning": true
  }'
```

## 🚨 Reakcja na Incydenty

### Automatyczne Reakcje

1. **Blokowanie IP** - Po przekroczeniu limitów rate limiting
2. **Blokowanie konta** - Po nieudanych próbach logowania
3. **Odrzucanie plików** - Pliki o niebezpiecznych rozszerzeniach
4. **Blokowanie ataków** - Przez Web Application Firewall

### Ręczne Akcje

1. **Monitorowanie logów** - Regularne sprawdzanie `security.log`
2. **Analiza wzorców** - Identyfikacja powtarzających się ataków
3. **Blokowanie IP** - Ręczne blokowanie podejrzanych adresów
4. **Aktualizacja konfiguracji** - Dostosowanie ustawień bezpieczeństwa

## 🔧 Rozwiązywanie Problemów

### Wysokie Zużycie Zasobów

```bash
# Sprawdzenie logów błędów
grep "ERROR" security.log

# Sprawdzenie liczby zablokowanych żądań
grep "waf_blocked" security.log | wc -l

# Sprawdzenie rate limiting
grep "rate_limit" security.log | wc -l
```

### Fałszywe Alarmy

1. **Dostosowanie wzorców WAF** - Modyfikacja w `server.py`
2. **Aktualizacja limitów** - Zmiana ustawień rate limiting
3. **Biała lista IP** - Dodanie zaufanych adresów

### Problemy z Sesjami

```bash
# Sprawdzenie wygasłych sesji
curl -H "Authorization: Bearer your_token" \
     http://localhost:8000/security/cleanup_sessions

# Sprawdzenie logów sesji
grep "session" security.log
```

## 📈 Metryki i Raporty

### Kluczowe Wskaźniki

- **Liczba zablokowanych kont**
- **Liczba zablokowanych IP**
- **Liczba odrzuconych plików**
- **Liczba prób path traversal**
- **Liczba żądań zablokowanych przez WAF**
- **Liczba zaszyfrowanych plików**

### Generowanie Raportów

```bash
# Raport dzienny
python -c "
import json
from datetime import datetime, timedelta

# Analiza logów z ostatnich 24 godzin
with open('security.log', 'r') as f:
    lines = f.readlines()

today = datetime.now().date()
events = []

for line in lines:
    if str(today) in line:
        events.append(line)

print(f'Zdarzenia z {today}: {len(events)}')
"
```

## 🔄 Aktualizacje i Konserwacja

### Regularne Zadania

1. **Codziennie** - Sprawdzanie logów bezpieczeństwa
2. **Cotygodniowo** - Przegląd statystyk bezpieczeństwa
3. **Miesięcznie** - Analiza trendów i aktualizacja konfiguracji
4. **Kwartalnie** - Testy penetracyjne i audyt bezpieczeństwa

### Aktualizacje Zależności

```bash
# Sprawdzenie aktualizacji
pip list --outdated

# Aktualizacja pakietów bezpieczeństwa
pip install --upgrade cryptography python-magic aiofiles

# Sprawdzenie podatności
safety check
```

## 📞 Wsparcie

### W przypadku problemów:

1. **Sprawdź logi** - Plik `security.log`
2. **Uruchom testy** - `python test_security.py`
3. **Sprawdź konfigurację** - Zmienne środowiskowe i `SECURITY_CONFIG`
4. **Skontaktuj się z zespołem** - W przypadku krytycznych problemów

### Przydatne Komendy

```bash
# Sprawdzenie statusu serwera
curl http://localhost:8000/security/status

# Sprawdzenie logów w czasie rzeczywistym
tail -f security.log

# Testowanie konkretnej funkcji
python test_security.py --test rate_limiting

# Backup bazy danych
sqlite3 server.db ".backup backup_$(date +%Y%m%d_%H%M%S).db"
```

## 📚 Dodatkowe Zasoby

- [Dokumentacja FastAPI](https://fastapi.tiangolo.com/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)

---

**Uwaga**: Ten dokument jest częścią systemu bezpieczeństwa ServApp. Regularnie aktualizuj konfigurację i monitoruj logi, aby zapewnić maksymalną ochronę aplikacji. 