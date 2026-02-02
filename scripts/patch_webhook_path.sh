#!/bin/bash
#
# Patch Webhook Plugin to Add {{Path}} Variable Support
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
HELPERS_FILE="${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs"

echo "=========================================================================="
echo "Patching Webhook Plugin for {{Path}} Variable Support"
echo "=========================================================================="
echo ""

if [ ! -f "${HELPERS_FILE}" ]; then
    echo "Error: DataObjectHelpers.cs not found at ${HELPERS_FILE}"
    echo "Please run ./scripts/setup_webhook_source.sh first"
    exit 1
fi

echo "Checking current DataObjectHelpers.cs..."

# Check if Path is already added
if grep -q '"Path".*item\.Path' "${HELPERS_FILE}"; then
    echo "✓ {{Path}} variable already present in DataObjectHelpers.cs"
    echo ""
    echo "Current implementation:"
    grep -A 2 -B 2 '"Path"' "${HELPERS_FILE}" || true
    exit 0
fi

echo "Adding {{Path}} variable support..."

# Create backup
cp "${HELPERS_FILE}" "${HELPERS_FILE}.backup"

# Find the AddBaseItemData method and add Path property
# We need to add this after adding other properties

# Check if we can find the method
if ! grep -q "AddBaseItemData" "${HELPERS_FILE}"; then
    echo "Error: AddBaseItemData method not found"
    echo "The webhook plugin structure may have changed"
    exit 1
fi

# Add Path property after the ItemId check
# This is the critical patch

# Try multiple patterns to find insertion point
LINE_NUM=""

# Try pattern 1: Look for dataObject["ItemId"]
LINE_NUM=$(grep -n 'dataObject\["ItemId"\]' "${HELPERS_FILE}" | tail -1 | cut -d: -f1)

# Try pattern 2: Look for any ItemId assignment
if [ -z "$LINE_NUM" ]; then
    LINE_NUM=$(grep -n '"ItemId".*=' "${HELPERS_FILE}" | tail -1 | cut -d: -f1)
fi

# Try pattern 3: Look for AddBaseItemData method
if [ -z "$LINE_NUM" ]; then
    # Find the AddBaseItemData method and insert near the end
    START_LINE=$(grep -n "AddBaseItemData" "${HELPERS_FILE}" | head -1 | cut -d: -f1)
    if [ -n "$START_LINE" ]; then
        # Find closing brace of method (rough estimate)
        LINE_NUM=$((START_LINE + 20))
    fi
fi

if [ -z "$LINE_NUM" ] || [ "$LINE_NUM" -eq 0 ]; then
    echo "Error: Could not find insertion point in DataObjectHelpers.cs"
    echo "Trying to insert after first dataObject assignment..."
    LINE_NUM=$(grep -n 'dataObject\[' "${HELPERS_FILE}" | head -1 | cut -d: -f1)
    
    if [ -z "$LINE_NUM" ]; then
        echo "Error: Could not find any dataObject assignments"
        mv "${HELPERS_FILE}.backup" "${HELPERS_FILE}"
        exit 1
    fi
fi

echo "  Inserting at line ${LINE_NUM}"

# Create the patch code
cat > /tmp/path_patch.txt << 'EOF'

        if (!string.IsNullOrEmpty(item.Path))
        {
            dataObject["Path"] = item.Path;
        }
EOF

# Insert the Path property after found line
{
    head -n "$LINE_NUM" "${HELPERS_FILE}"
    cat /tmp/path_patch.txt
    tail -n +$((LINE_NUM + 1)) "${HELPERS_FILE}"
} > "${HELPERS_FILE}.new"

mv "${HELPERS_FILE}.new" "${HELPERS_FILE}"
rm /tmp/path_patch.txt

echo "✓ Patch applied successfully"
echo ""
echo "Verifying patch..."
if grep -q '"Path".*item\.Path' "${HELPERS_FILE}"; then
    echo "✓ {{Path}} variable verified in DataObjectHelpers.cs"
    echo ""
    echo "Implementation:"
    grep -A 2 -B 2 '"Path"' "${HELPERS_FILE}"
else
    echo "✗ Patch verification failed"
    echo "Restoring backup..."
    mv "${HELPERS_FILE}.backup" "${HELPERS_FILE}"
    exit 1
fi

echo ""
echo "=========================================================================="
echo "Patch Complete!"
echo "=========================================================================="
echo ""
echo "Next steps:"
echo "1. Rebuild webhook plugin:"
echo "   cd ${REPO_DIR}/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook"
echo "   dotnet build -c Release"
echo ""
echo "2. Reinstall:"
echo "   cd ${REPO_DIR}"
echo "   sudo ./scripts/install_all.sh"
echo ""
echo "3. Test webhook with:"
echo "   curl -X POST http://localhost:8096/.../webhook-test"
echo ""
