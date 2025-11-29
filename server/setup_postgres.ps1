Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Skysync PostgreSQL Setup" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

try {
    $null = Get-Command psql -ErrorAction Stop
    Write-Host "[✓] PostgreSQL CLI (psql) found" -ForegroundColor Green
} catch {
    Write-Host "[✗] PostgreSQL CLI (psql) not found in PATH" -ForegroundColor Red
    Write-Host "Please install PostgreSQL and add it to your PATH" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "  1. Create database 'skysync'" -ForegroundColor White
Write-Host "  2. Create user 'skysync_user'" -ForegroundColor White
Write-Host "  3. Grant necessary privileges" -ForegroundColor White
Write-Host "  4. Update your .env file" -ForegroundColor White
Write-Host ""

$pgUser = Read-Host "Enter PostgreSQL superuser name [default: postgres]"
if ([string]::IsNullOrWhiteSpace($pgUser)) {
    $pgUser = "postgres"
}

Write-Host ""
$dbName = Read-Host "Enter database name [default: skysync]"
if ([string]::IsNullOrWhiteSpace($dbName)) {
    $dbName = "skysync"
}

Write-Host ""
$appUser = Read-Host "Enter application database user [default: skysync_user]"
if ([string]::IsNullOrWhiteSpace($appUser)) {
    $appUser = "skysync_user"
}

Write-Host ""
$appPassword = Read-Host "Enter password for '$appUser' [default: skysync_password]" -AsSecureString
$appPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appPassword)
)
if ([string]::IsNullOrWhiteSpace($appPasswordPlain)) {
    $appPasswordPlain = "skysync_password"
}

Write-Host ""
Write-Host "Creating PostgreSQL database..." -ForegroundColor Yellow

$sqlCommands = @"
SELECT 'CREATE DATABASE $dbName' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$dbName')\gexec

DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$appUser') THEN
        CREATE USER $appUser WITH ENCRYPTED PASSWORD '$appPasswordPlain';
    ELSE
        ALTER USER $appUser WITH ENCRYPTED PASSWORD '$appPasswordPlain';
    END IF;
END
\$\$;

GRANT ALL PRIVILEGES ON DATABASE $dbName TO $appUser;

\c $dbName

GRANT ALL ON SCHEMA public TO $appUser;
GRANT CREATE ON SCHEMA public TO $appUser;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $appUser;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $appUser;
"@

$tempSqlFile = "temp_setup.sql"
$sqlCommands | Out-File -FilePath $tempSqlFile -Encoding UTF8

try {
    Write-Host "Executing SQL commands..." -ForegroundColor Yellow
    $output = psql -U $pgUser -f $tempSqlFile 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] Database created successfully!" -ForegroundColor Green
    } else {
        Write-Host "[✗] Error creating database" -ForegroundColor Red
        Write-Host "" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Yellow
        $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Host ""
        Write-Host "Common fixes:" -ForegroundColor Yellow
        Write-Host "  1. Check if password is correct for user '$pgUser'" -ForegroundColor White
        Write-Host "  2. Try running: psql -U $pgUser -f temp_setup.sql" -ForegroundColor White
        Write-Host "  3. Check if PostgreSQL service is running" -ForegroundColor White
        Remove-Item $tempSqlFile -ErrorAction SilentlyContinue
        exit 1
    }
} catch {
    Write-Host "[✗] Error: $_" -ForegroundColor Red
    Remove-Item $tempSqlFile -ErrorAction SilentlyContinue
    exit 1
}

Remove-Item $tempSqlFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Updating .env file..." -ForegroundColor Yellow

function Encode-UrlComponent {
    param([string]$value)
    return [System.Uri]::EscapeDataString($value)
}

$encodedPassword = Encode-UrlComponent $appPasswordPlain
$databaseUrl = "postgres://${appUser}:${encodedPassword}@localhost:5432/${dbName}?sslmode=disable"

if (Test-Path ".env") {
    $envContent = Get-Content ".env" -Raw
    
    if ($envContent -match "DATABASE_URL=") {
        $envContent = $envContent -replace "DATABASE_URL=.*", "DATABASE_URL=$databaseUrl"
    } else {
        $envContent += "`nDATABASE_URL=$databaseUrl`n"
    }
    
    $envContent | Out-File -FilePath ".env" -Encoding UTF8 -NoNewline
    Write-Host "[✓] .env file updated" -ForegroundColor Green
} else {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        $envContent = Get-Content ".env" -Raw
        $envContent = $envContent -replace "DATABASE_URL=.*", "DATABASE_URL=$databaseUrl"
        $envContent | Out-File -FilePath ".env" -Encoding UTF8 -NoNewline
        Write-Host "[✓] .env file created from .env.example" -ForegroundColor Green
    } else {
        "DATABASE_URL=$databaseUrl" | Out-File -FilePath ".env" -Encoding UTF8
        Write-Host "[!] .env file created (minimal)" -ForegroundColor Yellow
        Write-Host "Please add API_KEY and SECRET_KEY manually" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Setup Complete! ✓" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Database Configuration:" -ForegroundColor Yellow
Write-Host "  Database: $dbName" -ForegroundColor White
Write-Host "  User: $appUser" -ForegroundColor White
Write-Host "  Host: localhost:5432" -ForegroundColor White
Write-Host ""
Write-Host "Connection String:" -ForegroundColor Yellow
Write-Host "  $databaseUrl" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Verify your .env file contains DATABASE_URL" -ForegroundColor White
Write-Host "  2. Run: go run main.go" -ForegroundColor White
Write-Host "  3. GORM will automatically create all tables" -ForegroundColor White
Write-Host ""
Write-Host "To verify the database:" -ForegroundColor Yellow
Write-Host "  psql -U $appUser -d $dbName" -ForegroundColor White
Write-Host ""
