# Instrukcje Instalacji Funkcji Bezpieczeństwa

## 🚀 Szybka Instalacja

### 1. Zainstaluj Nowe Zależności
```bash
cd fileserver
pip install -r requirements.txt
```

### 2. Uruchom Migrację Bazy Danych
```bash
python migrate_database.py
```

### 3. Sprawdź Konfigurację
Upewnij się, że masz ustawione zmienne środowiskowe w pliku `.env`:
```bash
SECRET_KEY=your_very_secure_secret_key_here
API_KEY=your_api_key_here
BASE_URL=http://localhost:8000
```

### 4. Uruchom Serwer
```bash
uvicorn server:app --host 0.0.0.0 --port 8000
```

## 🔧 Szczegółowa Instalacja

### Krok 1: Przygotowanie Środowiska
```bash
# Utwórz wirtualne środowisko (opcjonalnie)
python -m venv venv
source venv/bin/activate  # Linux/Mac
# lub
venv\Scripts\activate  # Windows

# Zainstaluj zależności
pip install fastapi==0.104.1
pip install uvicorn==0.24.0
pip install sqlalchemy==2.0.23
pip install python-multipart==0.0.6
pip install python-jose[cryptography]==3.3.0
pip install bcrypt==4.1.2
pip install python-dotenv==1.0.0
pip install cryptography==41.0.7
```

### Krok 2: Konfiguracja Bezpieczeństwa
Utwórz plik `.env` w katalogu `fileserver`:
```bash
# Klucze bezpieczeństwa (ZMIEŃ TE WARTOŚCI!)
SECRET_KEY=your_super_secret_key_at_least_32_characters_long
API_KEY=your_api_key_for_client_authentication

# Konfiguracja serwera
BASE_URL=http://localhost:8000

# Opcjonalne ustawienia
MAX_LOGIN_ATTEMPTS=5
LOGIN_LOCKOUT_DURATION=15
MAX_FILE_SIZE=104857600  # 100MB w bajtach
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

### Krok 3: Migracja Bazy Danych
```bash
# Uruchom skrypt migracji
python migrate_database.py
```

Oczekiwany wynik:
```
Starting database migration...
Adding column failed_login_attempts to users table...
Adding column account_locked_until to users table...
Adding column last_login to users table...
Adding column is_active to users table...
Adding column created_at to users table...
Adding column file_size to files table...
Adding column file_hash to files table...
Adding column mime_type to files table...
Adding column uploaded_at to files table...
Adding column is_encrypted to files table...
Database migration completed successfully!

Migration Summary:
- Users in database: 0
- Files in database: 0
- New security features enabled
```

### Krok 4: Testowanie Instalacji
```bash
# Uruchom serwer
uvicorn server:app --host 0.0.0.0 --port 8000 --reload

# W nowym terminalu, przetestuj endpoint bezpieczeństwa
curl -X GET "http://localhost:8000/security/status" \
  -H "Authorization: Bearer your_token" \
  -H "API_KEY: your_api_key"
```

## 🔍 Weryfikacja Instalacji

### Sprawdź Logi Bezpieczeństwa
```bash
# Sprawdź czy plik logów jest tworzony
tail -f security.log
```

### Sprawdź Bazę Danych
```bash
# Sprawdź nowe tabele
sqlite3 server.db ".tables"
# Powinno pokazać: encrypted_files, security_events, users, files, favorites, shared_files, shared_folders

# Sprawdź nowe kolumny w tabeli users
sqlite3 server.db "PRAGMA table_info(users);"
```

### Testuj Nowe Funkcje
```bash
# 1. Test WAF - powinno zablokować
curl "http://localhost:8000/login?user=admin' OR '1'='1"

# 2. Test rate limiting - powinno zablokować po 10 próbach
for i in {1..11}; do
  curl -X POST http://localhost:8000/login \
    -H "Content-Type: application/json" \
    -H "API_KEY: your_api_key" \
    -d '{"email":"test","password":"wrong"}'
done

# 3. Test szyfrowania (po zalogowaniu)
curl -X POST http://localhost:8000/encrypt_file \
  -H "Authorization: Bearer your_token" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","folder_name":"user1","encryption_password":"strong_password123"}'
```

## ⚠️ Rozwiązywanie Problemów

### Problem: Błąd Importu cryptography
```bash
# Rozwiązanie: Zainstaluj ponownie
pip uninstall cryptography
pip install cryptography==41.0.7
```

### Problem: Błąd migracji bazy danych
```bash
# Rozwiązanie: Sprawdź uprawnienia
chmod 644 server.db
# lub usuń i utwórz ponownie
rm server.db
python migrate_database.py
```

### Problem: Błąd SECRET_KEY
```bash
# Rozwiązanie: Sprawdź plik .env
cat .env
# Upewnij się, że SECRET_KEY ma co najmniej 32 znaki
```

### Problem: Błąd API_KEY
```bash
# Rozwiązanie: Sprawdź nagłówki żądań
curl -H "API_KEY: your_api_key" http://localhost:8000/security/status
```

## 🔒 Najlepsze Praktyki Bezpieczeństwa

### 1. Zmień Domyślne Klucze
```bash
# Wygeneruj bezpieczny SECRET_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Wygeneruj bezpieczny API_KEY
python -c "import secrets; print(secrets.token_urlsafe(16))"
```

### 2. Skonfiguruj HTTPS
```bash
# Uruchom z certyfikatem SSL
uvicorn server:app --host 0.0.0.0 --port 443 --ssl-keyfile=key.pem --ssl-certfile=cert.pem
```

### 3. Monitoruj Logi
```bash
# Ustaw rotację logów
logrotate /etc/logrotate.d/security_logs
```

### 4. Regularne Backupy
```bash
# Backup bazy danych
sqlite3 server.db ".backup backup_$(date +%Y%m%d_%H%M%S).db"
```

## 📊 Monitorowanie Po Instalacji

### Sprawdź Status Bezpieczeństwa
```bash
# Endpoint dla administratorów
curl -X GET "http://localhost:8000/security/status" \
  -H "Authorization: Bearer admin_token" \
  -H "API_KEY: your_api_key"
```

### Monitoruj Zdarzenia
```bash
# Śledź logi w czasie rzeczywistym
tail -f security.log | grep -E "(waf_blocked|failed_login|file_encrypted)"

# Sprawdź statystyki dzienne
grep "$(date +%Y-%m-%d)" security.log | wc -l
```

### Sprawdź Wydajność
```bash
# Monitoruj użycie CPU podczas szyfrowania
top -p $(pgrep -f "uvicorn server:app")

# Sprawdź rozmiar bazy danych
ls -lh server.db
```

## ✅ Lista Kontrolna Instalacji

- [ ] Zainstalowano wszystkie zależności
- [ ] Utworzono plik `.env` z bezpiecznymi kluczami
- [ ] Uruchomiono migrację bazy danych
- [ ] Przetestowano endpoint `/security/status`
- [ ] Sprawdzono logi bezpieczeństwa
- [ ] Przetestowano WAF
- [ ] Przetestowano szyfrowanie plików
- [ ] Skonfigurowano HTTPS (opcjonalnie)
- [ ] Ustawiono monitoring logów

Po wykonaniu wszystkich kroków, serwer będzie miał najwyższy poziom bezpieczeństwa z nowymi funkcjami ochrony! 