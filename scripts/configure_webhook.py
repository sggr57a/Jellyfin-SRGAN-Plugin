#!/usr/bin/env python3
"""
Configure Jellyfin Webhook Plugin for SRGAN Pipeline
Creates/updates the webhook configuration XML file to trigger upscaling on playback.
"""

import base64
import json
import os
import sys
import xml.etree.ElementTree as ET
from xml.dom import minidom

def create_webhook_template():
    """Create the JSON template for webhook payload (will be Base64 encoded)."""
    template = {
        "Path": "{{Path}}",
        "Name": "{{Name}}",
        "ItemType": "{{ItemType}}",
        "ItemId": "{{ItemId}}",
        "NotificationUsername": "{{NotificationUsername}}",
        "UserId": "{{UserId}}",
        "NotificationType": "{{NotificationType}}",
        "ServerName": "{{ServerName}}"
    }
    return json.dumps(template, separators=(',', ':'))

def base64_encode_template(template_json):
    """Base64 encode the template as required by Jellyfin webhook plugin."""
    return base64.b64encode(template_json.encode('utf-8')).decode('utf-8')

def create_generic_option(watchdog_url):
    """Create a GenericOption XML element for SRGAN webhook."""
    option = ET.Element('GenericOption')
    
    # NotificationTypes array with PlaybackStart (enum value 3)
    notification_types = ET.SubElement(option, 'NotificationTypes')
    notification_type = ET.SubElement(notification_types, 'NotificationType')
    notification_type.text = 'PlaybackStart'
    
    # Webhook metadata
    webhook_name = ET.SubElement(option, 'WebhookName')
    webhook_name.text = 'SRGAN 4K Upscaler'
    
    webhook_uri = ET.SubElement(option, 'WebhookUri')
    webhook_uri.text = f'{watchdog_url}/upscale-trigger'
    
    # Item type filters
    enable_movies = ET.SubElement(option, 'EnableMovies')
    enable_movies.text = 'true'
    
    enable_episodes = ET.SubElement(option, 'EnableEpisodes')
    enable_episodes.text = 'true'
    
    enable_series = ET.SubElement(option, 'EnableSeries')
    enable_series.text = 'false'
    
    enable_seasons = ET.SubElement(option, 'EnableSeasons')
    enable_seasons.text = 'false'
    
    enable_albums = ET.SubElement(option, 'EnableAlbums')
    enable_albums.text = 'false'
    
    enable_songs = ET.SubElement(option, 'EnableSongs')
    enable_songs.text = 'false'
    
    enable_videos = ET.SubElement(option, 'EnableVideos')
    enable_videos.text = 'false'
    
    # Template settings
    send_all_properties = ET.SubElement(option, 'SendAllProperties')
    send_all_properties.text = 'false'
    
    trim_whitespace = ET.SubElement(option, 'TrimWhitespace')
    trim_whitespace.text = 'false'
    
    skip_empty = ET.SubElement(option, 'SkipEmptyMessageBody')
    skip_empty.text = 'false'
    
    enable_webhook = ET.SubElement(option, 'EnableWebhook')
    enable_webhook.text = 'true'
    
    # Base64-encoded template
    template_json = create_webhook_template()
    template_b64 = base64_encode_template(template_json)
    template_elem = ET.SubElement(option, 'Template')
    template_elem.text = template_b64
    
    # User filter (empty array)
    user_filter = ET.SubElement(option, 'UserFilter')
    
    # Headers and Fields (empty arrays for GenericOption)
    headers = ET.SubElement(option, 'Headers')
    fields = ET.SubElement(option, 'Fields')
    
    return option

def webhook_exists(root, watchdog_url):
    """Check if SRGAN webhook already exists in configuration."""
    generic_options = root.find('.//GenericOptions')
    if generic_options is None:
        return False
    
    target_uri = f'{watchdog_url}/upscale-trigger'
    for option in generic_options.findall('GenericOption'):
        webhook_uri = option.find('WebhookUri')
        if webhook_uri is not None and webhook_uri.text == target_uri:
            return True
    return False

def create_webhook_config(watchdog_url, config_path):
    """Create or update webhook configuration XML file."""
    
    # Try to load existing configuration
    if os.path.exists(config_path):
        try:
            tree = ET.parse(config_path)
            root = tree.getroot()
            print(f"Loaded existing webhook configuration from {config_path}")
            
            # Check if SRGAN webhook already exists
            if webhook_exists(root, watchdog_url):
                print(f"✓ SRGAN webhook already configured for {watchdog_url}/upscale-trigger")
                return True
            
        except ET.ParseError as e:
            print(f"Warning: Could not parse existing config ({e}), creating new configuration")
            root = None
    else:
        root = None
    
    # Create new configuration if needed
    if root is None:
        root = ET.Element('PluginConfiguration')
        server_url = ET.SubElement(root, 'ServerUrl')
        server_url.text = ''
        
        # Create empty arrays for other webhook types
        discord_options = ET.SubElement(root, 'DiscordOptions')
        generic_form_options = ET.SubElement(root, 'GenericFormOptions')
        gotify_options = ET.SubElement(root, 'GotifyOptions')
        pushbullet_options = ET.SubElement(root, 'PushbulletOptions')
        pushover_options = ET.SubElement(root, 'PushoverOptions')
        slack_options = ET.SubElement(root, 'SlackOptions')
        smtp_options = ET.SubElement(root, 'SmtpOptions')
        mqtt_options = ET.SubElement(root, 'MqttOptions')
    
    # Find or create GenericOptions array
    generic_options = root.find('GenericOptions')
    if generic_options is None:
        generic_options = ET.SubElement(root, 'GenericOptions')
    
    # Add SRGAN webhook
    srgan_option = create_generic_option(watchdog_url)
    generic_options.append(srgan_option)
    
    # Pretty print XML
    xml_str = minidom.parseString(ET.tostring(root)).toprettyxml(indent="  ")
    
    # Remove extra blank lines
    xml_str = '\n'.join([line for line in xml_str.split('\n') if line.strip()])
    
    # Write to file
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, 'w') as f:
        f.write(xml_str)
    
    print(f"✓ Webhook configuration written to {config_path}")
    print(f"  Webhook: SRGAN 4K Upscaler")
    print(f"  Endpoint: {watchdog_url}/upscale-trigger")
    print(f"  Trigger: PlaybackStart")
    print(f"  Types: Movies, Episodes")
    return True

def main():
    """Main entry point."""
    # Parse arguments
    watchdog_url = sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:5000'
    config_path = sys.argv[2] if len(sys.argv) > 2 else '/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml'
    
    # Normalize watchdog URL (remove trailing slash)
    watchdog_url = watchdog_url.rstrip('/')
    
    print(f"Configuring Jellyfin webhook for SRGAN pipeline...")
    print(f"  Watchdog URL: {watchdog_url}")
    print(f"  Config path: {config_path}")
    print()
    
    try:
        success = create_webhook_config(watchdog_url, config_path)
        if success:
            print()
            print("✓ Webhook configuration complete!")
            print("  Restart Jellyfin to apply changes:")
            print("  sudo systemctl restart jellyfin")
            return 0
        else:
            return 1
    except PermissionError:
        print(f"\n✗ Permission denied writing to {config_path}")
        print("  Run with sudo: sudo python3 scripts/configure_webhook.py")
        return 1
    except Exception as e:
        print(f"\n✗ Error: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
