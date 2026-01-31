#!/bin/bash
#
# Test webhook template by sending sample payloads
#

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           WEBHOOK TEMPLATE TESTER                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if watchdog is running
if ! curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "❌ Watchdog is not responding at http://localhost:5000"
    echo ""
    echo "Start it with:"
    echo "  python3 scripts/watchdog.py"
    echo ""
    echo "Or:"
    echo "  sudo systemctl start srgan-watchdog"
    echo ""
    exit 1
fi

echo "✓ Watchdog is running"
echo ""

# Test 1: Correct payload
echo "═══════════════════════════════════════════════════════════════"
echo "Test 1: CORRECT payload (how it should work)"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Sending:"
echo '{"Item":{"Path":"/mnt/media/test.mkv","Name":"Test","Type":"Movie"}}'
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item":{"Path":"/mnt/media/test.mkv","Name":"Test","Type":"Movie"}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "Response code: $HTTP_CODE"
echo "Response body:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_CODE" == "404" ]; then
    echo "✓ GOOD: Webhook parsed the payload and looked for the file"
    echo "  (404 = file not found, but that's OK for testing)"
elif [ "$HTTP_CODE" == "200" ]; then
    echo "✓ PERFECT: Webhook accepted the payload!"
else
    echo "⚠️  Unexpected response code: $HTTP_CODE"
fi

echo ""
echo "Press Enter to continue..."
read

# Test 2: Empty Path
echo "═══════════════════════════════════════════════════════════════"
echo "Test 2: EMPTY Path (your current issue)"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Sending:"
echo '{"Item":{"Path":"","Name":"","Type":""}}'
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item":{"Path":"","Name":"","Type":""}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "Response code: $HTTP_CODE"
echo "Response body:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_CODE" == "400" ]; then
    echo "✓ DETECTED: Watchdog correctly detected empty Path"
    echo "  This is what happens with your current Jellyfin config"
else
    echo "⚠️  Unexpected response code: $HTTP_CODE"
fi

echo ""
echo "Press Enter to continue..."
read

# Test 3: Missing Path key
echo "═══════════════════════════════════════════════════════════════"
echo "Test 3: MISSING Path key"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Sending:"
echo '{"Item":{"Name":"Test","Type":"Movie"}}'
echo "(Notice: No 'Path' field)"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"Item":{"Name":"Test","Type":"Movie"}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "Response code: $HTTP_CODE"
echo "Response body:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_CODE" == "400" ]; then
    echo "✓ DETECTED: Watchdog correctly detected missing Path key"
else
    echo "⚠️  Unexpected response code: $HTTP_CODE"
fi

echo ""
echo "Press Enter to continue..."
read

# Test 4: Missing Item
echo "═══════════════════════════════════════════════════════════════"
echo "Test 4: MISSING Item section"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Sending:"
echo '{"User":{"Name":"Test"}}'
echo "(Notice: No 'Item' section)"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: application/json" \
  -d '{"User":{"Name":"Test"}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "Response code: $HTTP_CODE"
echo "Response body:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_CODE" == "400" ]; then
    echo "✓ DETECTED: Watchdog correctly detected missing Item"
else
    echo "⚠️  Unexpected response code: $HTTP_CODE"
fi

echo ""
echo "Press Enter to continue..."
read

# Test 5: Wrong Content-Type
echo "═══════════════════════════════════════════════════════════════"
echo "Test 5: WRONG Content-Type"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Sending with Content-Type: text/plain"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST http://localhost:5000/upscale-trigger \
  -H "Content-Type: text/plain" \
  -d '{"Item":{"Path":"/mnt/media/test.mkv"}}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "Response code: $HTTP_CODE"
echo "Response body:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
echo ""

if [ "$HTTP_CODE" == "400" ] || [ "$HTTP_CODE" == "404" ]; then
    echo "✓ Watchdog handled wrong Content-Type"
    echo "  (may parse as JSON anyway with warning)"
else
    echo "⚠️  Unexpected response code: $HTTP_CODE"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "                      TEST SUMMARY                             "
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "The watchdog can detect and report these issues:"
echo "  ✓ Empty Path (Template variables not filled)"
echo "  ✓ Missing Path key (Incomplete template)"
echo "  ✓ Missing Item section (Wrong template)"
echo "  ✓ Wrong Content-Type (Config issue)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "YOUR JELLYFIN WEBHOOK SHOULD SEND:"
echo ""
echo "Content-Type: application/json"
echo ""
echo "Body:"
echo '{'
echo '  "Item": {'
echo '    "Path": "/mnt/media/movies/film.mkv",    ← ACTUAL PATH'
echo '    "Name": "Film Name",'
echo '    "Type": "Movie"'
echo '  },'
echo '  "User": {'
echo '    "Name": "YourUsername"'
echo '  },'
echo '  "Event": "PlaybackStart"'
echo '}'
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "If you're getting errors, check these in Jellyfin webhook:"
echo ""
echo "1. Notification Type: ☑ Playback Start"
echo "2. Item Type: ☑ Movie, ☑ Episode"
echo "3. Request Content Type: application/json"
echo "4. Template uses: {{Item.Path}} (double braces)"
echo ""
echo "Run diagnostics: ./scripts/check_webhook_logs.sh"
echo "Full guide: IMMEDIATE_FIX.md"
echo ""
