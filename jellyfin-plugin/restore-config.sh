#!/bin/bash
#
# Restore Configuration Script for RealTimeHDRSRGAN Plugin
#

BACKUP_PATH="$1"

if [ -z "$BACKUP_PATH" ]; then
    echo "ERROR: Backup path not specified"
    echo "Usage: $0 <backup_path>"
    exit 1
fi

if [ ! -d "$BACKUP_PATH" ]; then
    echo "ERROR: Backup path does not exist: $BACKUP_PATH"
    exit 1
fi

echo "Restoring Jellyfin configuration from: $BACKUP_PATH"
cp -r "$BACKUP_PATH"/* /etc/jellyfin/
echo "Configuration restored successfully"
echo "Please restart Jellyfin for changes to take effect"
exit 0
