#!/bin/sh

set -eu

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to display errors
error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
    exit 1
}

# Function to display info
info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

# Function to display warnings
warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

# Check arguments
if [ $# -ne 1 ]; then
    error "Usage: $0 <path_to_database.db>"
fi

DB_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATIONS_DIR="${SCRIPT_DIR}/migrations"

# Check if sqlite3 is available
if ! command -v sqlite3 >/dev/null 2>&1; then
    error "sqlite3 is not installed"
fi

# Check if database file exists or can be created
if [ ! -f "$DB_PATH" ]; then
    warn "Database does not exist, will be created: $DB_PATH"
    DB_DIR="$(dirname "$DB_PATH")"
    if [ ! -d "$DB_DIR" ]; then
        mkdir -p "$DB_DIR" || error "Cannot create directory for database: $DB_DIR"
    fi
    touch "$DB_PATH" || error "Cannot create database file: $DB_PATH"
fi

# Check if migrations table exists
info "Checking migrations table..."
TABLE_EXISTS=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='migrations';" 2>/dev/null || echo "")

if [ -z "$TABLE_EXISTS" ]; then
    info "Creating migrations table..."
    sqlite3 "$DB_PATH" "CREATE TABLE migrations(
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT UNIQUE,
        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
    );" || error "Cannot create migrations table"
    info "Migrations table created successfully"
else
    info "Migrations table already exists"
fi

# Check if migrations directory exists
if [ ! -d "$MIGRATIONS_DIR" ]; then
    warn "Migrations directory does not exist, creating..."
    mkdir -p "$MIGRATIONS_DIR" || error "Cannot create migrations directory"
    info "Created directory: $MIGRATIONS_DIR"
    info "Add migration files to this directory and run the script again"
    exit 0
fi

# Get list of applied migrations from database
info "Fetching list of applied migrations..."
APPLIED_MIGRATIONS=$(sqlite3 "$DB_PATH" "SELECT name FROM migrations ORDER BY name;" 2>/dev/null || echo "")

# Get list of migration files from directory
info "Scanning migrations directory..."
TEMP_MIGRATIONS=$(mktemp)
trap "rm -f $TEMP_MIGRATIONS" EXIT INT TERM

find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sql" 2>/dev/null | while read -r file; do
    basename "$file"
done | sort > "$TEMP_MIGRATIONS"

# Check if there are any migration files
if [ ! -s "$TEMP_MIGRATIONS" ]; then
    info "No migration files found in $MIGRATIONS_DIR"
    exit 0
fi

MIGRATION_COUNT=$(wc -l < "$TEMP_MIGRATIONS")
info "Found $MIGRATION_COUNT migration file(s)"

# Find pending migrations
TEMP_PENDING=$(mktemp)
trap "rm -f $TEMP_MIGRATIONS $TEMP_PENDING" EXIT INT TERM

while read -r migration; do
    # Check if migration has already been applied
    if echo "$APPLIED_MIGRATIONS" | grep -qx "$migration"; then
        info "✓ $migration (already applied)"
    else
        echo "$migration" >> "$TEMP_PENDING"
        info "○ $migration (pending)"
    fi
done < "$TEMP_MIGRATIONS"

# Check if there are pending migrations
if [ ! -s "$TEMP_PENDING" ]; then
    info "All migrations are already applied"
    exit 0
fi

PENDING_COUNT=$(wc -l < "$TEMP_PENDING")
info ""
info "Found $PENDING_COUNT pending migration(s)"
info ""

# Prepare transaction with all migrations
info "Starting migration application in a single transaction..."

# Create temporary SQL file with entire transaction
TEMP_SQL=$(mktemp)
trap "rm -f $TEMP_MIGRATIONS $TEMP_PENDING $TEMP_SQL" EXIT INT TERM

echo "BEGIN TRANSACTION;" > "$TEMP_SQL"

while read -r migration; do
    migration_path="${MIGRATIONS_DIR}/${migration}"
    
    if [ ! -f "$migration_path" ]; then
        error "Migration file does not exist: $migration_path"
    fi
    
    info "Adding migration: $migration"
    
    # Add migration content
    echo "-- Migration: $migration" >> "$TEMP_SQL"
    cat "$migration_path" >> "$TEMP_SQL"
    echo "" >> "$TEMP_SQL"
    
    # Add record to migrations table
    echo "INSERT INTO migrations (name) VALUES ('$migration');" >> "$TEMP_SQL"
    echo "" >> "$TEMP_SQL"
done < "$TEMP_PENDING"

echo "COMMIT;" >> "$TEMP_SQL"

# Execute transaction
info "Executing transaction..."
if sqlite3 "$DB_PATH" < "$TEMP_SQL" 2>&1; then
    info ""
    info "✓ All migrations have been successfully applied!"
    info ""
    info "Applied migrations:"
    while read -r migration; do
        printf "  - %s\n" "$migration"
    done < "$TEMP_PENDING"
else
    error "Error during migration application. Transaction has been rolled back."
fi

exit 0
