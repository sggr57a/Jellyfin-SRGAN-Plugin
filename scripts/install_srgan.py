import os
import sys
import json
import requests
import subprocess
from pathlib import Path

# --- CONFIGURATION ---
JELLYFIN_URL = "http://localhost:62096"
JELLYFIN_API_KEY = "8202d67509f44dcb9b56f3bb90057a76"  # Replace this!
LISTENER_PORT = 5000
WATCH_DIR = "/mnt/media"  # Base path for your NFS
APP_DIR = "/opt/srgan_upscaler"
USER_NAME = os.getlogin()

# --- 1. THE FLASK LISTENER SOURCE ---
LISTENER_CODE = f"""
from flask import Flask, request
import subprocess, os, threading, logging

app = Flask(__name__)
upscale_lock = threading.Lock()
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger("SRGAN_Locker")

def process_upscale(input_file, output_file):
    if not upscale_lock.acquire(blocking=True):
        return
    try:
        logger.info(f"🚀 Processing: {{input_file}}")
        subprocess.run([
            "docker", "compose", "-f", "{APP_DIR}/docker-compose.yml", 
            "run", "--rm", "srgan-upscaler", input_file, output_file
        ], check=True)
    except Exception as e:
        logger.error(f"❌ Error: {{e}}")
    finally:
        upscale_lock.release()

@app.route('/upscale-trigger', methods=['POST'])
def handle_play():
    data = request.json
    input_file = data.get('Item', {{}}).get('Path')
    if not input_file or "upscaled" in input_file.lower():
        return "Ignored", 200
    
    # Path logic: maps to /data/ within the container
    output_file = input_file.replace(".mkv", "_upscaled.ts").replace(".mp4", "_upscaled.ts")
    threading.Thread(target=process_upscale, args=(input_file, output_file)).start()
    return "Queued", 202

if __name__ == "__main__":
    app.run(host='0.0.0.0', port={LISTENER_PORT})
"""

# --- 2. THE SYSTEMD SERVICE SOURCE ---
SYSTEMD_UNIT = f"""
[Unit]
Description=SRGAN Webhook Listener
After=network.target docker.service

[Service]
Type=simple
User={USER_NAME}
WorkingDirectory={APP_DIR}
ExecStart=/usr/bin/python3 {APP_DIR}/listener.py
Restart=always

[Install]
WantedBy=multi-user.target
"""

def setup_jellyfin_webhook():
    print("📡 Configuring Jellyfin Webhook...")
    headers = {{"X-MediaBrowser-Token": JELLYFIN_API_KEY, "Content-Type": "application/json"}}
    
    # Get Plugin ID
    plugins = requests.get(f"{{JELLYFIN_URL}}/Plugins", headers=headers).json()
    webhook_plugin = next((p for p in plugins if p['Name'] == 'Webhook'), None)
    
    if not webhook_plugin:
        print("⚠️  Webhook plugin not found in Jellyfin! Install it manually first.")
        return

    config_url = f"{{JELLYFIN_URL}}/Plugins/{{webhook_plugin['Id']}}/Configuration"
    current_config = requests.get(config_url, headers=headers).json()
    
    template = {{
        "NotificationType": "{{{{NotificationType}}}}",
        "Item": {{ "Path": "{{{{{{ItemPath}}}}}}", "Name": "{{{{{{Name}}}}}}" }}
    }}

    new_dest = {{
        "Name": "SRGAN_Trigger",
        "Url": f"http://localhost:{{LISTENER_PORT}}/upscale-trigger",
        "Template": json.dumps(template),
        "NotificationTypes": ["PlaybackStart"],
        "ItemTypes": ["Movie", "Episode"],
        "EnableAllUsers": True,
        "HeaderKey": "Content-Type", "HeaderValue": "application/json"
    }}

    current_config.setdefault("GenericDestinations", []).append(new_dest)
    requests.post(config_url, headers=headers, data=json.dumps(current_config))
    print("✅ Webhook configured.")

def main():
    # Create Directories
    os.makedirs(APP_DIR, exist_ok=True)
    
    # Write Files
    with open(f"{{APP_DIR}}/listener.py", "w") as f: f.write(LISTENER_CODE)
    print(f"📄 Created listener.py in {{APP_DIR}}")

    # Install Systemd Service
    with open("/tmp/srgan.service", "w") as f: f.write(SYSTEMD_UNIT)
    subprocess.run(["sudo", "cp", "/tmp/srgan.service", "/etc/systemd/system/srgan.service"], check=True)
    subprocess.run(["sudo", "systemctl", "daemon-reload"], check=True)
    subprocess.run(["sudo", "systemctl", "enable", "--now", "srgan.service"], check=True)
    print("⚙️  Systemd service started.")

    # Configure Jellyfin if API key provided
    if JELLYFIN_API_KEY != "8202d67509f44dcb9b56f3bb90057a76":
        setup_jellyfin_webhook()

if __name__ == "__main__":
    main()
