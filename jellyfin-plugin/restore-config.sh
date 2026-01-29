#!/bin/bash
# Restore Jellyfin Configuration Script
# Restores Jellyfin configuration from a backup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Jellyfin Configuration Restore ==="
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

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}ERROR: Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

# Check if backup path is provided as argument
if [ -n "$1" ]; then
    RESTORE_PATH="$1"
else
    # Try to use last backup
    if [ -f "$BACKUP_DIR/.last_backup_path" ]; then
        RESTORE_PATH=$(cat "$BACKUP_DIR/.last_backup_path")
    else
        # Use latest symlink
        if [ -L "$BACKUP_DIR/latest" ]; then
            RESTORE_PATH="$BACKUP_DIR/$(readlink "$BACKUP_DIR/latest")"
        else
            echo -e "${RED}ERROR: No backup specified and no default backup found.${NC}"
            echo ""
            echo "Available backups:"
            ls -1 "$BACKUP_DIR" | grep -E "^jellyfin_backup_" || echo "  (none)"
            echo ""
            echo "Usage: $0 [backup_path]"
            exit 1
        fi
    fi
fi

# Resolve full path
if [[ "$RESTORE_PATH" != /* ]]; then
    RESTORE_PATH="$BACKUP_DIR/$RESTORE_PATH"
fi

if [ ! -d "$RESTORE_PATH" ]; then
    echo -e "${RED}ERROR: Backup not found: $RESTORE_PATH${NC}"
    exit 1
fi

echo "Configuration directory: $JELLYFIN_CONFIG_DIR"
echo "Backup to restore: $RESTORE_PATH"
echo ""

# Confirm restore
echo -e "${YELLOW}WARNING: This will overwrite your current Jellyfin configuration!${NC}"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

# Stop Jellyfin if running (optional, user may want to do this manually)
if systemctl is-active --quiet jellyfin 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}Jellyfin service is running.${NC}"
    echo "It's recommended to stop Jellyfin before restoring."
    echo "Stop Jellyfin now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Stopping Jellyfin..."
        sudo systemctl stop jellyfin || true
        JELLYFIN_STOPPED=true
    fi
fi

echo ""
echo "Restoring backup..."

# Restore files
for item in config data plugins root transcoding-temp; do
    if [ -d "$RESTORE_PATH/$item" ]; then
        echo "  Restoring: $item"
        # Backup current version first
        if [ -e "$JELLYFIN_CONFIG_DIR/$item" ]; then
            mv "$JELLYFIN_CONFIG_DIR/$item" "$JELLYFIN_CONFIG_DIR/${item}.old.$(date +%s)" 2>/dev/null || true
        fi
        cp -r "$RESTORE_PATH/$item" "$JELLYFIN_CONFIG_DIR/" 2>/dev/null || true
    fi
done

echo ""
echo -e "${GREEN}✓ Configuration restored successfully!${NC}"
echo ""

# Restart Jellyfin if we stopped it
if [ "$JELLYFIN_STOPPED" = true ]; then
    echo "Starting Jellyfin..."
    sudo systemctl start jellyfin || true
    echo -e "${GREEN}✓ Jellyfin restarted${NC}"
fi

echo ""
echo "Restore complete. Please verify Jellyfin is working correctly."

exit 0
