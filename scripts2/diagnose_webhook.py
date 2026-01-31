#!/usr/bin/env python3
"""
Webhook diagnostic tool - helps identify webhook configuration issues
"""

import json
import sys

def diagnose_payload(payload_json):
    """Diagnose issues with webhook payload"""

    print("╔════════════════════════════════════════════════════════════════╗")
    print("║           WEBHOOK PAYLOAD DIAGNOSTIC TOOL                      ║")
    print("╚════════════════════════════════════════════════════════════════╝")
    print()

    try:
        data = json.loads(payload_json)
    except json.JSONDecodeError as e:
        print("❌ CRITICAL: Invalid JSON")
        print(f"   Error: {e}")
        print()
        print("   This means the webhook template is not valid JSON.")
        print("   Copy the template EXACTLY from WEBHOOK_SETUP.md")
        return False

    print("✓ JSON is valid")
    print()
    print("Payload structure:")
    print(json.dumps(data, indent=2))
    print()
    print("═" * 70)
    print()

    # Check for Item key
    if "Item" not in data:
        print("❌ CRITICAL: Missing 'Item' key")
        print()
        print("   Expected structure:")
        print("   {")
        print('     "Item": { ... }')
        print("   }")
        print()
        print("   Your template is missing the Item section.")
        print()
        print("   Copy the correct template from WEBHOOK_SETUP.md")
        return False

    print("✓ 'Item' key exists")

    # Check if Item is a dict
    item = data.get("Item")
    if not isinstance(item, dict):
        print()
        print(f"❌ CRITICAL: 'Item' is not a dictionary (it's a {type(item).__name__})")
        print()
        print(f"   Received: {item}")
        print()
        print("   Expected: dictionary with Path, Name, Type fields")
        return False

    # Check if Item is empty
    if not item:
        print()
        print("❌ CRITICAL: 'Item' is an empty dictionary")
        print()
        print("   Your template has 'Item': {} with no fields")
        print()
        print("   Expected:")
        print("   {")
        print('     "Item": {')
        print('       "Path": "{{Item.Path}}"')
        print("     }")
        print("   }")
        return False

    print(f"✓ 'Item' is a dictionary with {len(item)} key(s)")

    # Check Item.Path
    print(f"   Keys in Item: {list(item.keys())}")
    print()

    if "Path" not in item:
        print("❌ CRITICAL: Missing 'Item.Path' key")
        print()
        print("   Expected:")
        print("   {")
        print('     "Item": {')
        print('       "Path": "{{Item.Path}}"')
        print("     }")
        print("   }")
        print()
        print("   Add Path field to your template.")
        return False

    print("✓ 'Item.Path' key exists")

    path_value = item.get("Path")

    # Check if path is empty
    if not path_value or path_value == "":
        print()
        print("❌ CRITICAL: Item.Path is EMPTY")
        print()
        print("   This is the EXACT problem you're experiencing!")
        print()
        print("╔════════════════════════════════════════════════════════════╗")
        print("║  ROOT CAUSE: Jellyfin is NOT filling template variables   ║")
        print("╚════════════════════════════════════════════════════════════╝")
        print()
        print("WHY THIS HAPPENS:")
        print()
        print("1. ❌ 'Playback Start' is NOT CHECKED")
        print("   Location: Notification Type section")
        print("   Without this: {{Item.Path}} has no value")
        print()
        print("2. ❌ 'Movie' or 'Episode' is NOT CHECKED")
        print("   Location: Item Type section")
        print("   Without this: Webhook doesn't fire for videos")
        print()
        print("3. ❌ Template uses {{{Item.Path}}} (triple braces)")
        print("   Should be: {{Item.Path}} (double braces)")
        print()
        print("═" * 70)
        print()
        print("IMMEDIATE FIX:")
        print()
        print("Step 1: Open Jellyfin in your browser")
        print()
        print("Step 2: Navigate to:")
        print("   Dashboard → Plugins → Webhooks")
        print()
        print("Step 3: Click on your webhook name to edit it")
        print()
        print("Step 4: Scroll down to 'Notification Type'")
        print("   Find and CHECK the box:")
        print("   ☑ Playback Start    ← CHECK THIS!")
        print()
        print("Step 5: Scroll down to 'Item Type'")
        print("   Find and CHECK these boxes:")
        print("   ☑ Movie             ← CHECK THIS!")
        print("   ☑ Episode           ← CHECK THIS!")
        print()
        print("Step 6: Scroll to bottom and click SAVE")
        print()
        print("Step 7: Restart watchdog:")
        print("   sudo systemctl restart srgan-watchdog")
        print()
        print("Step 8: Play a video in Jellyfin and check logs:")
        print("   sudo journalctl -u srgan-watchdog -f")
        print()
        print("═" * 70)
        print()
        return False

    # Check if it looks like an unfilled template variable
    if path_value.startswith("{{") and path_value.endswith("}}"):
        print()
        print("❌ CRITICAL: Template variable NOT filled")
        print()
        print(f"   Received literal: {path_value}")
        print("   Expected: /mnt/media/movies/film.mkv")
        print()
        print("   This means Jellyfin is sending the template literally,")
        print("   without replacing {{Item.Path}} with the actual path.")
        print()
        print("CAUSE: Wrong template syntax or Jellyfin bug")
        print()
        print("FIX:")
        print('   1. Make sure template uses {{Item.Path}} (double braces)')
        print('   2. NOT {{{Item.Path}}} (triple braces)')
        print("   3. Update Jellyfin webhook plugin to latest version")
        print()
        return False

    print(f"✓ 'Item.Path' has value: {path_value}")
    print()

    # Check if path looks valid
    if not path_value.startswith("/"):
        print("⚠️  WARNING: Path doesn't start with /")
        print(f"   Path: {path_value}")
        print()
        print("   This might be a Windows path or relative path.")
        print("   Expected: /mnt/media/movies/film.mkv")
        print()

    # Summary
    print("═" * 70)
    print()
    print("✅ WEBHOOK PAYLOAD LOOKS GOOD!")
    print()
    print("   The webhook is configured correctly and Jellyfin is")
    print("   filling in the template variables.")
    print()
    print("   If you're still getting errors, the issue is likely:")
    print("   - File doesn't exist at that path")
    print("   - Path mismatch between Jellyfin and watchdog host")
    print("   - Permissions issue")
    print()
    print("   Check if file exists:")
    print(f"   ls -lh {path_value}")
    print()

    return True


def main():
    print()
    print("Webhook Payload Diagnostic Tool")
    print("=" * 70)
    print()

    if len(sys.argv) > 1:
        # Read from command line argument
        payload = sys.argv[1]
    else:
        # Read from stdin
        print("Paste the webhook payload from logs (the JSON between the lines):")
        print("Then press Ctrl+D (or Ctrl+Z on Windows)")
        print()
        payload = sys.stdin.read()

    if not payload.strip():
        print("❌ No payload provided")
        print()
        print("Usage:")
        print("  1. Copy the payload from watchdog logs:")
        print("     sudo journalctl -u srgan-watchdog -n 100 | grep -A 20 'Full payload'")
        print()
        print("  2. Run this script and paste the JSON:")
        print("     python3 scripts/diagnose_webhook.py")
        print()
        print("  3. Or provide as argument:")
        print('     python3 scripts/diagnose_webhook.py \'{"Item":{"Path":"..."}}\' ')
        print()
        return 1

    success = diagnose_payload(payload.strip())

    print()
    print("═" * 70)

    if success:
        print("✅ No issues detected")
        return 0
    else:
        print("❌ Issues found - follow the fix instructions above")
        return 1


if __name__ == "__main__":
    sys.exit(main())
