#!/bin/bash
# Backup Jellyfin Configuration Script
# Creates a timestamped backup of Jellyfin configuration before plugin installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Jellyfin Configuration Backup ==="
echo ""

# Detect Jellyfin configuration directory
JELLYFIN_CONFIG_DIR=""
BACKUP_DIR=""

# Try to find Jellyfin config directory
if [ -d "$HOME/.jellyfin" ]; then
    JELLYFIN_CONFIG_DIR="$HOME/.jellyfin"
    BACKUP_DIR="$HOME/.jellyfin/backups"
elif [ -d "/config" ]; then
    JELLYFIN_CONFIG_DIR="/config"
    BACKUP_DIR="/config/backups"
elif [ -d "/var/lib/jellyfin" ]; then
    JELLYFIN_CONFIG_DIR="/var/lib/jellyfin"
    BACKUP_DIR="/var/lib/jellyfin/backups"
elif [ -n "$JELLYFIN_CONFIG_DIR" ]; then
    JELLYFIN_CONFIG_DIR="$JELLYFIN_CONFIG_DIR"
    BACKUP_DIR="$JELLYFIN_CONFIG_DIR/backups"
else
    echo -e "${RED}ERROR: Could not locate Jellyfin configuration directory.${NC}"
    echo "Please set JELLYFIN_CONFIG_DIR environment variable."
    exit 1
fi

if [ ! -d "$JELLYFIN_CONFIG_DIR" ]; then
    echo -e "${RED}ERROR: Jellyfin configuration directory not found: $JELLYFIN_CONFIG_DIR${NC}"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="jellyfin_backup_${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "Configuration directory: $JELLYFIN_CONFIG_DIR"
echo "Backup directory: $BACKUP_DIR"
echo "Backup name: $BACKUP_NAME"
echo ""

# Create backup
echo "Creating backup..."
mkdir -p "$BACKUP_PATH"

# Backup important configuration files
FILES_TO_BACKUP=(
    "config"
    "data"
    "plugins"
    "root"
    "transcoding-temp"
)

for item in "${FILES_TO_BACKUP[@]}"; do
    if [ -e "$JELLYFIN_CONFIG_DIR/$item" ]; then
        echo "  Backing up: $item"
        cp -r "$JELLYFIN_CONFIG_DIR/$item" "$BACKUP_PATH/" 2>/dev/null || true
    fi
done

# Create backup manifest
cat > "$BACKUP_PATH/backup_manifest.txt" << EOF
Jellyfin Configuration Backup
============================
Timestamp: $(date)
Source: $JELLYFIN_CONFIG_DIR
Backup Location: $BACKUP_PATH

Backed up items:
$(ls -la "$BACKUP_PATH" | grep -v "^total" | grep -v "backup_manifest.txt")

Plugin: Real-Time HDR SRGAN Pipeline
Version: 1.0.0.0
EOF

# Create symlink to latest backup
LATEST_BACKUP="$BACKUP_DIR/latest"
rm -f "$LATEST_BACKUP"
ln -s "$BACKUP_NAME" "$LATEST_BACKUP"

echo ""
echo -e "${GREEN}✓ Backup created successfully!${NC}"
echo "Backup location: $BACKUP_PATH"
echo "Latest backup symlink: $LATEST_BACKUP"
echo ""

# Save backup path for restore script
echo "$BACKUP_PATH" > "$BACKUP_DIR/.last_backup_path"

exit 0
