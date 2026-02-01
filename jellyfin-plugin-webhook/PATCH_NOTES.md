# Jellyfin Webhook Plugin - Path Variable Patch

## What This Patch Does

This is a patched version of the official Jellyfin webhook plugin that adds support for the `{{Path}}` template variable.

### Changes Made

**File**: `Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs`

**Lines 64-67** (added):
```csharp
if (!string.IsNullOrEmpty(item.Path))
{
    dataObject["Path"] = item.Path;
}
```

This exposes the `BaseItem.Path` property to webhook templates, allowing you to access the file system path of media items.

## Why This Patch Is Needed

The stock Jellyfin webhook plugin does not expose the `Path` property from `BaseItem`. This means webhook templates cannot access the file path of media being played, which is required for:

- External processing pipelines (upscaling, transcoding, etc.)
- File-based automation workflows
- Media management scripts

## Usage

After installing this patched plugin, you can use `{{Path}}` in your webhook templates:

```json
{
  "Path": "{{Path}}",
  "Name": "{{Name}}",
  "ItemType": "{{ItemType}}"
}
```

This will populate with values like:
```json
{
  "Path": "/mnt/media/movies/Sample.mkv",
  "Name": "Sample Movie",
  "ItemType": "Movie"
}
```

## Building

```bash
dotnet build -c Release
```

## Installing

```bash
# Linux
sudo cp bin/Release/net9.0/Jellyfin.Plugin.Webhook.dll /var/lib/jellyfin/plugins/Webhook/

# Docker
docker cp bin/Release/net9.0/Jellyfin.Plugin.Webhook.dll jellyfin:/config/plugins/Webhook/
```

Restart Jellyfin after installing.

## Compatibility

- Based on: Official Jellyfin Webhook Plugin
- Jellyfin Version: 10.8+
- .NET Version: 9.0

## Upstream

Original plugin: https://github.com/jellyfin/jellyfin-plugin-webhook

## Notes

This patch is minimal and non-breaking. All existing webhook functionality remains unchanged.
