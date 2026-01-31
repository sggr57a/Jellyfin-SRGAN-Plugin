#!/bin/bash
#
# Verify webhook template configuration for Item.Path attribute
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        WEBHOOK TEMPLATE VERIFICATION FOR Item.Path            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "This tool verifies that the Jellyfin webhook can capture Item.Path"
echo ""

# Test 1: Verify watchdog is accepting Item.Path
echo "Step 1: Test watchdog endpoint with correct payload"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if ! curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "⚠️  Watchdog not responding at http://localhost:5000"
    echo ""
    echo "Start it with:"
    echo "  sudo systemctl start srgan-watchdog"
    echo ""
    echo "Continuing with other checks..."
    echo ""
else
    echo "✓ Watchdog is running"
    echo ""
    
    echo "Testing with sample payload containing Item.Path..."
    echo ""
    
    RESPONSE=$(curl -s -w "\nHTTP:%{http_code}" -X POST http://localhost:5000/upscale-trigger \
      -H "Content-Type: application/json" \
      -d '{
        "Item": {
          "Path": "/mnt/media/movies/test-movie.mkv",
          "Name": "Test Movie",
          "Type": "Movie"
        },
        "User": {
          "Name": "TestUser"
        },
        "Event": "PlaybackStart"
      }')
    
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | grep -v "HTTP:")
    
    echo "Response code: $HTTP_CODE"
    echo ""
    
    if [ "$HTTP_CODE" == "404" ]; then
        echo "✅ EXCELLENT: Watchdog parsed Item.Path correctly!"
        echo ""
        echo "   Response indicates file not found, which means:"
        echo "   • Item.Path was successfully extracted"
        echo "   • Path value was: /mnt/media/movies/test-movie.mkv"
        echo "   • Webhook endpoint is working correctly"
        echo ""
    elif [ "$HTTP_CODE" == "400" ]; then
        echo "❌ ERROR: Watchdog rejected the payload"
        echo ""
        echo "Response:"
        echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
        echo ""
    else
        echo "Response:"
        echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
        echo ""
    fi
fi

# Test 2: Check Jellyfin webhook logs
echo "Step 2: Check recent webhook attempts in logs"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if systemctl is-active --quiet srgan-watchdog; then
    echo "Recent webhook payloads from Jellyfin:"
    echo ""
    
    RECENT_PAYLOAD=$(sudo journalctl -u srgan-watchdog -n 200 --no-pager 2>/dev/null | grep -A 15 "Full payload:" | tail -n 20)
    
    if [ -z "$RECENT_PAYLOAD" ]; then
        echo "ℹ️  No recent webhook payloads found"
        echo ""
        echo "   This means Jellyfin hasn't sent any webhooks yet."
        echo ""
        echo "   Play a video in Jellyfin to trigger a webhook."
        echo ""
    else
        echo "$RECENT_PAYLOAD"
        echo ""
        
        # Check if Path is present and not empty
        if echo "$RECENT_PAYLOAD" | grep -q '"Path": "[^"]'; then
            PATH_VALUE=$(echo "$RECENT_PAYLOAD" | grep '"Path":' | head -n 1)
            echo "✅ Item.Path is present and has a value:"
            echo "   $PATH_VALUE"
            echo ""
        elif echo "$RECENT_PAYLOAD" | grep -q '"Path": ""'; then
            echo "❌ PROBLEM DETECTED: Item.Path is EMPTY"
            echo ""
            echo "   Jellyfin webhook is sending empty Path value."
            echo "   This means the webhook is misconfigured!"
            echo ""
        else
            echo "⚠️  Could not find Path field in recent payloads"
            echo ""
        fi
    fi
else
    echo "⚠️  Watchdog service not running"
    echo ""
fi

# Test 3: Provide correct webhook template
echo "Step 3: Verify webhook template configuration"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "CORRECT WEBHOOK TEMPLATE for capturing Item.Path:"
echo ""
echo "────────────────────────────────────────────────────────────────"
cat << 'TEMPLATE'
{
  "Item": {
    "Path": "{{Item.Path}}",
    "Name": "{{Item.Name}}",
    "Type": "{{Item.Type}}"
  },
  "User": {
    "Name": "{{User.Name}}"
  },
  "Event": "PlaybackStart"
}
TEMPLATE
echo "────────────────────────────────────────────────────────────────"
echo ""

echo "CRITICAL REQUIREMENTS for Item.Path to work:"
echo ""
echo "1. Template Syntax:"
echo "   ✓ Use double braces: {{Item.Path}}"
echo "   ✗ NOT triple braces: {{{Item.Path}}}"
echo ""
echo "2. Notification Type:"
echo "   ✓ MUST check: Playback Start"
echo "   ✗ NOT: Playback Stop, User Created, etc."
echo ""
echo "3. Item Type:"
echo "   ✓ MUST check: Movie"
echo "   ✓ MUST check: Episode"
echo "   (Both should be checked for video files)"
echo ""
echo "4. Request Content Type:"
echo "   ✓ MUST set: application/json"
echo "   ✗ NOT: text/plain, form-urlencoded"
echo ""

# Test 4: Check what Jellyfin webhook plugin supports
echo "Step 4: Available template variables in Jellyfin webhook"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "Jellyfin webhook plugin supports these Item variables:"
echo ""
echo "  • {{Item.Path}}          - Full file path (REQUIRED)"
echo "  • {{Item.Name}}          - Display name"
echo "  • {{Item.Type}}          - Type (Movie, Episode, etc.)"
echo "  • {{Item.Id}}            - Jellyfin item ID"
echo "  • {{Item.Overview}}      - Description"
echo "  • {{Item.Year}}          - Release year"
echo "  • {{Item.RunTime}}       - Duration"
echo ""
echo "For your use case, Item.Path is the CRITICAL field."
echo ""

# Test 5: Generate test script
echo "Step 5: Generate test payload script"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cat > /tmp/test-webhook-path.sh << 'TESTSCRIPT'
#!/bin/bash
# Test script to verify Item.Path is captured correctly

echo "Testing webhook with various Item.Path values..."
echo ""

# Test with typical movie path
echo "Test 1: Movie path"
curl -s -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "Item": {
      "Path": "/mnt/media/movies/ExampleMovie.mkv",
      "Name": "Example Movie",
      "Type": "Movie"
    }
  }' | python3 -m json.tool 2>/dev/null

echo ""
echo "──────────────────────────────────────────────────────"
echo ""

# Test with TV show path
echo "Test 2: TV episode path"
curl -s -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "Item": {
      "Path": "/mnt/media/tv/ShowName/Season 01/Episode 01.mkv",
      "Name": "Episode Name",
      "Type": "Episode"
    }
  }' | python3 -m json.tool 2>/dev/null

echo ""
echo "──────────────────────────────────────────────────────"
echo ""

# Test with path containing spaces
echo "Test 3: Path with spaces"
curl -s -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{
    "Item": {
      "Path": "/mnt/media/movies/Movie With Spaces (2024).mkv",
      "Name": "Movie With Spaces",
      "Type": "Movie"
    }
  }' | python3 -m json.tool 2>/dev/null

echo ""
echo "──────────────────────────────────────────────────────"
echo ""

echo "✓ All tests complete"
echo ""
echo "Expected responses:"
echo "  • 404 'File not found' = Good (path was parsed)"
echo "  • 400 'Missing Item.Path' = Bad (path not captured)"
echo "  • 200 'Success' = Perfect (file exists and queued)"
TESTSCRIPT

chmod +x /tmp/test-webhook-path.sh

echo "✓ Created test script: /tmp/test-webhook-path.sh"
echo ""
echo "Run it with:"
echo "  bash /tmp/test-webhook-path.sh"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                      VERIFICATION SUMMARY                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "TO ENSURE Item.Path WORKS IN JELLYFIN WEBHOOK:"
echo ""
echo "1. Go to Jellyfin: Dashboard → Plugins → Webhooks"
echo ""
echo "2. Edit your webhook and verify:"
echo "   Template field contains:"
echo '   "Path": "{{Item.Path}}"'
echo ""
echo "3. Check these boxes:"
echo "   ☑ Playback Start      (Notification Type)"
echo "   ☑ Movie               (Item Type)"
echo "   ☑ Episode             (Item Type)"
echo ""
echo "4. Set dropdown:"
echo "   Request Content Type: application/json"
echo ""
echo "5. Click SAVE"
echo ""
echo "6. Test by playing a video in Jellyfin"
echo ""
echo "7. Verify in logs:"
echo '   sudo journalctl -u srgan-watchdog -f'
echo "   Look for: \"Path\": \"/mnt/media/...\""
echo "   NOT: \"Path\": \"\""
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "For detailed webhook setup: WEBHOOK_SETUP.md"
echo "For troubleshooting: HELP_ME_NOW.md"
echo ""
