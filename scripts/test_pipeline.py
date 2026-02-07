#!/usr/bin/env python3
"""
Test SRGAN pipeline
"""

import requests
import os

# --- Configuration ---
WEBHOOK_URL = os.environ.get("WEBHOOK_URL", "http://localhost:5000/upscale-trigger")
# Use an actual file path that exists on your NFS share for a real test
TEST_FILE_PATH = os.environ.get("TEST_FILE_PATH", "/mnt/media/incoming/test_movie.mkv")

def simulate_playback(file_path):
    print(f"📡 Simulating Jellyfin Playback for: {file_path}")
    
    # This matches the Handlebars template we configured in the Master Script
    payload = {
        "NotificationType": "PlaybackStart",
        "Item": {
            "Path": file_path,
            "Name": os.path.basename(file_path)
        },
        "User": {
            "Name": "TestAdmin"
        }
    }

    try:
        response = requests.post(WEBHOOK_URL, json=payload)
        if response.status_code in (200, 202):
            print("✅ Success: Task accepted and queued by the listener.")
            print("📜 Check logs: 'journalctl -u srgan-watchdog.service -f'")
        else:
            print(f"❌ Failed: Listener returned {response.status_code}")
            print(f"Response: {response.text}")
    except requests.exceptions.ConnectionError:
        print("❌ Error: Could not connect to the listener. Is the watchdog running?")

if __name__ == "__main__":
    # Create a dummy file if testing logic only; use a real video for a full hardware test
    if not os.path.exists(TEST_FILE_PATH):
        print(f"⚠️  Note: {TEST_FILE_PATH} does not exist. The listener will ignore this.")
    
    simulate_playback(TEST_FILE_PATH)
