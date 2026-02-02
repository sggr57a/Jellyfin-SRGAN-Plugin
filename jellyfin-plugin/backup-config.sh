#!/bin/bash
#
# Backup Configuration Script for RealTimeHDRSRGAN Plugin
#

BACKUP_DIR="/var/lib/jellyfin/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/jellyfin_backup_$TIMESTAMP"

echo "Creating Jellyfin configuration backup..."
mkdir -p "$BACKUP_DIR"

if [ -d "/etc/jellyfin" ]; then
    cp -r /etc/jellyfin "$BACKUP_PATH"
    echo "Backup created successfully"
    echo "Backup location: $BACKUP_PATH"
    exit 0
else
    echo "ERROR: /etc/jellyfin directory not found"
    exit 1
fi
