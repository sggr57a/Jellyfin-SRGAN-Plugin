# Webhook Plugin Integration Changes

## Summary

Added patched Jellyfin webhook plugin with `{{Path}}` variable support to enable file path access in webhook templates.

## Changes Made

### 1. Integrated Patched Webhook Plugin

**Directory**: `jellyfin-plugin-webhook/`
- Cloned from https://github.com/jellyfin/jellyfin-plugin-webhook
- Applied Path variable patch to `Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs:64-67`
- Added `PATCH_NOTES.md` documenting the patch

### 2. Updated Watchdog Service

**File**: `scripts/watchdog.py:65`
- Changed Path extraction to support both flat and nested structures:
  ```python
  input_file = data.get("Path") or data.get("Item", {}).get("Path")
  ```
- Updated error messages to reference `{{Path}}` (flat) syntax
- Changed documentation references to `WEBHOOK_CONFIGURATION_CORRECT.md`

### 3. Enhanced Installation Script

**File**: `scripts/install_all.sh:84-122`
- Added Step 2.3: Build and install patched webhook plugin
- Detects `jellyfin-plugin-webhook/` directory
- Builds with `dotnet build -c Release`
- Installs DLL to `/var/lib/jellyfin/plugins/Webhook/`
- Added to installation summary output
- Updated documentation references

### 4. Created New Documentation

**File**: `WEBHOOK_CONFIGURATION_CORRECT.md`
- Complete webhook setup guide for patched plugin
- Explains flat `{{Path}}` template structure
- Troubleshooting for empty Path values
- Build and install instructions

**File**: `jellyfin-webhook-config.json`
- Reference configuration using flat structure
- Correct template with `{{Path}}`, `{{Name}}`, etc.

### 5. Updated Existing Documentation

**Files**: `README.md`, `GETTING_STARTED.md`, `TROUBLESHOOTING.md`
- Updated all references from `WEBHOOK_SETUP.md` to `WEBHOOK_CONFIGURATION_CORRECT.md`
- Added webhook plugin build instructions to README
- Updated template examples to use flat structure
- Added warning about stock plugin limitations

**File**: `WEBHOOK_SETUP.md`
- Prepended deprecation notice
- Points to `WEBHOOK_CONFIGURATION_CORRECT.md`

## Technical Details

### Why This Patch Is Needed

The stock Jellyfin webhook plugin does not expose the `BaseItem.Path` property in template variables. This prevents accessing file paths in webhook payloads, which is required for:
- External processing (upscaling, transcoding)
- File-based automation
- Media management workflows

### Template Structure Change

**Old (Nested - Doesn't Work)**:
```json
{
  "Item": {
    "Path": "{{Item.Path}}"
  }
}
```

**New (Flat - Works with Patch)**:
```json
{
  "Path": "{{Path}}",
  "Name": "{{Name}}"
}
```

Jellyfin webhook templates use a flat variable namespace, not nested objects.

### Backward Compatibility

The watchdog service supports both structures for graceful migration:
```python
input_file = data.get("Path") or data.get("Item", {}).get("Path")
```

## Testing

To verify the changes:

1. Build patched plugin:
   ```bash
   cd jellyfin-plugin-webhook
   dotnet build -c Release
   ```

2. Run install script:
   ```bash
   ./scripts/install_all.sh
   ```

3. Configure webhook in Jellyfin using flat template from `WEBHOOK_CONFIGURATION_CORRECT.md`

4. Test webhook:
   ```bash
   python3 scripts/test_webhook.py --test-file /path/to/video.mkv
   ```

## Files Modified

- `scripts/watchdog.py`
- `scripts/install_all.sh`
- `README.md`
- `GETTING_STARTED.md`
- `TROUBLESHOOTING.md`
- `WEBHOOK_SETUP.md` (deprecated with notice)

## Files Created

- `WEBHOOK_CONFIGURATION_CORRECT.md`
- `jellyfin-webhook-config.json`
- `jellyfin-plugin-webhook/` (directory with patched plugin)
- `jellyfin-plugin-webhook/PATCH_NOTES.md`
- `CHANGES.md` (this file)

## Next Steps

Users should:
1. Run `./scripts/install_all.sh` to build and install the patched plugin
2. Restart Jellyfin
3. Reconfigure webhooks using `WEBHOOK_CONFIGURATION_CORRECT.md`
4. Test with a video playback
