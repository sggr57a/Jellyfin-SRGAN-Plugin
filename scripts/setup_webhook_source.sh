#!/bin/bash
#
# Fetch Webhook Plugin Source from Official Repository
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
WEBHOOK_DIR="${REPO_DIR}/jellyfin-plugin-webhook"

echo "=========================================================================="
echo "Fetching Webhook Plugin Source Files"
echo "=========================================================================="
echo ""

cd "${REPO_DIR}"

# Backup our custom files
echo "Backing up custom configuration files..."
mkdir -p /tmp/webhook-backup
cp "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook/Jellyfin.Plugin.Webhook.csproj" /tmp/webhook-backup/ 2>/dev/null || true
cp "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook/NuGet.Config" /tmp/webhook-backup/ 2>/dev/null || true
cp "${WEBHOOK_DIR}/build.yaml" /tmp/webhook-backup/ 2>/dev/null || true
cp "${WEBHOOK_DIR}/Directory.Build.props" /tmp/webhook-backup/ 2>/dev/null || true

# Clone official webhook plugin
echo "Cloning official Jellyfin webhook plugin..."
if [ -d "temp-webhook" ]; then
    rm -rf temp-webhook
fi

git clone --depth 1 https://github.com/jellyfin/jellyfin-plugin-webhook.git temp-webhook

# Copy source files
echo "Copying source files..."
cp -r temp-webhook/Jellyfin.Plugin.Webhook/* "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook/"

# Restore our custom files (with updated versions)
echo "Restoring custom configuration files..."
cp /tmp/webhook-backup/Jellyfin.Plugin.Webhook.csproj "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook/" 2>/dev/null || true
cp /tmp/webhook-backup/NuGet.Config "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook/" 2>/dev/null || true
cp /tmp/webhook-backup/build.yaml "${WEBHOOK_DIR}/" 2>/dev/null || true
cp /tmp/webhook-backup/Directory.Build.props "${WEBHOOK_DIR}/" 2>/dev/null || true

# Apply Path variable patch
echo "Applying {{Path}} variable patch..."
HELPERS_FILE="${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"

if [ -f "${HELPERS_FILE}" ]; then
    # Check if Path is already added
    if ! grep -q "\"Path\"" "${HELPERS_FILE}"; then
        echo "Adding {{Path}} variable support..."
        # This will be manually patched - for now just note it
        echo "  Note: DataObjectHelpers.cs may need manual {{Path}} patch"
    else
        echo "  {{Path}} variable already present"
    fi
fi

# Clean up
echo "Cleaning up..."
rm -rf temp-webhook
rm -rf /tmp/webhook-backup

echo ""
echo "=========================================================================="
echo "Webhook Plugin Source Files Ready!"
echo "=========================================================================="
echo ""
echo "Files copied:"
ls -la "${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook/" | head -20
echo ""
echo "You can now build the webhook plugin:"
echo "  cd ${WEBHOOK_DIR}/Jellyfin.Plugin.Webhook"
echo "  dotnet build -c Release"
echo ""
