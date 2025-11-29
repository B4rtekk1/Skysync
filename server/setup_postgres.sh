RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}=====================================${NC}"
echo -e "${CYAN}  Skysync PostgreSQL Setup           ${NC}"
echo -e "${CYAN}=====================================${NC}"
echo

if command -v psql >/dev/null 2>&1; then
    echo -e "${GREEN}[✓] PostgreSQL CLI (psql) found${NC}"
else
    echo -e "${RED}[✗] PostgreSQL CLI (psql) not found in PATH${NC}"
    echo -e "${YELLOW}Please install PostgreSQL and ensure 'psql' is in your PATH${NC}"
    exit 1
fi

echo
echo -e "${YELLOW}This script will:${NC}"
echo -e "  1. Create database 'skysync'"
echo -e "  2. Create user 'skysync_user'"
echo -e "  3. Grant necessary privileges"
echo -e "  4. Update your .env file"
echo

read -p "Enter PostgreSQL superuser name [default: postgres]: " pgUser
pgUser=${pgUser:-postgres}

echo
read -p "Enter database name [default: skysync]: " dbName
dbName=${dbName:-skysync}

echo
read -p "Enter application database user [default: skysync_user]: " appUser
appUser=${appUser:-skysync_user}

echo
read -s -p "Enter password for '$appUser' [default: skysync_password]: " appPasswordPlain
echo
appPasswordPlain=${appPasswordPlain:-skysync_password}

TEMP_SQL=$(mktemp)

cat > "$TEMP_SQL" <<EOF
-- Create database if not exists
SELECT 'CREATE DATABASE "$dbName"' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$dbName') \gexec

-- Create or alter user
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$appUser') THEN
      CREATE ROLE "$appUser" LOGIN PASSWORD '$appPasswordPlain';
   ELSE
      ALTER ROLE "$appUser" WITH PASSWORD '$appPasswordPlain';
   END IF;
END
\$\$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE "$dbName" TO "$appUser";

\c $dbName

GRANT ALL ON SCHEMA public TO "$appUser";
GRANT CREATE ON SCHEMA public TO "$appUser";

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$appUser";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$appUser";
EOF

echo
echo -e "${YELLOW}Creating PostgreSQL database and user...${NC}"

if psql -U "$pgUser" -v ON_ERROR_STOP=1 -f "$TEMP_SQL" >/dev/null 2>&1; then
    echo -e "${GREEN}[✓] Database and user created successfully!${NC}"
else
    echo -e "${RED}[✗] Error creating database/user${NC}"
    echo
    echo -e "${YELLOW}Error details:${NC}"
    psql -U "$pgUser" -f "$TEMP_SQL"
    echo
    echo -e "${YELLOW}Common fixes:${NC}"
    echo -e "  1. Check if password for user '$pgUser' is correct (you may be prompted)"
    echo -e "  2. Try running manually: psql -U $pgUser -f $TEMP_SQL"
    echo -e "  3. Check if PostgreSQL service is running"
    rm -f "$TEMP_SQL"
    exit 1
fi

rm -f "$TEMP_SQL"

echo
echo -e "${YELLOW}Updating .env file...${NC}"

encodedPassword=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$appPasswordPlain" 2>/dev/null || \
                   node -p "encodeURIComponent(process.argv[1])" "$appPasswordPlain" 2>/dev/null || \
                   echo "$appPasswordPlain")

DATABASE_URL="postgres://${appUser}:${encodedPassword}@localhost:5432/${dbName}?sslmode=disable"

if [ -f ".env" ]; then
    if grep -q "^DATABASE_URL=" .env; then
        sed -i.bak "s|^DATABASE_URL=.*|DATABASE_URL=$DATABASE_URL|" .env && rm -f .env.bak
    else
        echo "DATABASE_URL=$DATABASE_URL" >> .env
    fi
    echo -e "${GREEN}[✓] .env file updated${NC}"
elif [ -f ".env.example" ]; then
    cp .env.example .env
    sed -i.bak "s|^DATABASE_URL=.*|DATABASE_URL=$DATABASE_URL|" .env && rm -f .env.bak
    echo -e "${GREEN}[✓] .env file created from .env.example${NC}"
else
    echo "DATABASE_URL=$DATABASE_URL" > .env
    echo -e "${YELLOW}[!] .env file created (minimal)${NC}"
    echo -e "${YELLOW}Please add API_KEY and SECRET_KEY manually${NC}"
fi

echo
echo -e "${CYAN}=====================================${NC}"
echo -e "${GREEN}  Setup Complete! ✓${NC}"
echo -e "${CYAN}=====================================${NC}"
echo
echo -e "${YELLOW}Database Configuration:${NC}"
echo -e "  Database: $dbName"
echo -e "  User: $appUser"
echo -e "  Host: localhost:5432"
echo
echo -e "${YELLOW}Connection String:${NC}"
echo -e "  $DATABASE_URL"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Verify your .env file contains DATABASE_URL"
echo -e "  2. Run: go run main.go"
echo -e "  3. GORM will automatically create all tables"
echo
echo -e "${YELLOW}To verify the database:${NC}"
echo -e "  psql -U $appUser -d $dbName -h localhost"
echo

exit 0