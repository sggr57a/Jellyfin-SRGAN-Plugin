# Fixes Applied for Plugin Issues

## Issue 1: SRGAN Plugin - "Failed to get resource ConfigurationPage.html"

### Root Cause
Embedded resource path mismatch between `.csproj` and `Plugin.cs`.

**Before:**
- `.csproj` embedded files as: `ConfigurationPage.html`
- `Plugin.cs` requested: `Jellyfin.Plugin.RealTimeHdrSrgan.ConfigurationPage.html`
- Result: ❌ Resource not found

### Fix Applied
Modified `jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj` lines 22-29:

```xml
<!-- BEFORE -->
<ItemGroup>
  <EmbeddedResource Include="..\ConfigurationPage.html" Link="ConfigurationPage.html" />
  <EmbeddedResource Include="..\ConfigurationPage.js" Link="ConfigurationPage.js" />
</ItemGroup>

<!-- AFTER -->
<ItemGroup>
  <EmbeddedResource Include="..\ConfigurationPage.html">
    <LogicalName>Jellyfin.Plugin.RealTimeHdrSrgan.ConfigurationPage.html</LogicalName>
  </EmbeddedResource>
  <EmbeddedResource Include="..\ConfigurationPage.js">
    <LogicalName>Jellyfin.Plugin.RealTimeHdrSrgan.ConfigurationPage.js</LogicalName>
  </EmbeddedResource>
</ItemGroup>
```

**Now:** Resource path matches what `Plugin.cs:80` requests ✓

---

## Issue 2: Webhook Plugin - Missing deps.json

### Root Cause
Webhook plugin was never built. You only modified source code but never compiled it.

**Missing files:**
- `Jellyfin.Plugin.Webhook.deps.json` ← Dependency manifest
- All dependency DLLs (Handlebars, MailKit, MQTTnet, etc.)

### Fix Applied
Created comprehensive build script: `build-and-deploy-all-plugins.sh`

**What it does:**
1. ✓ Builds both plugins with `dotnet build -c Release`
2. ✓ Generates `deps.json` automatically
3. ✓ Copies **all** required files (DLL + dependencies)
4. ✓ Auto-detects Jellyfin installation (bare metal or Docker)
5. ✓ Backs up existing plugins before overwriting
6. ✓ Restarts Jellyfin
7. ✓ Verifies installation

---

## How to Use the Fix

### On Your Jellyfin Server:

```bash
cd /path/to/project
./build-and-deploy-all-plugins.sh
```

The script will:
- Build both plugins
- Find your Jellyfin plugin directories
- Install everything correctly
- Restart Jellyfin

---

## What Gets Installed

### After successful deployment:

#### `/var/lib/jellyfin/plugins/Real-Time HDR SRGAN Pipeline_1.0.0.0/`
```
Jellyfin.Plugin.RealTimeHdrSrgan.dll    ← Rebuilt with fixed resource paths
backup-config.sh
gpu-detection.sh
restore-config.sh
meta.json
```

#### `/var/lib/jellyfin/plugins/Webhook_18.0.0.0/`
```
Jellyfin.Plugin.Webhook.dll             ← Patched with Path support
Jellyfin.Plugin.Webhook.deps.json       ← NOW PRESENT ✓
Handlebars.dll                          ← Dependency
MailKit.dll                             ← Dependency
MimeKit.dll                             ← Dependency
MQTTnet.dll                             ← Dependency
BouncyCastle.Cryptography.dll           ← Dependency
... (other dependencies)
meta.json
```

---

## Verification Commands

### Check if plugins loaded successfully:
```bash
# Bare metal
sudo journalctl -u jellyfin -n 50 | grep -i plugin

# Docker
docker logs jellyfin --tail 50 | grep -i plugin
```

**Expected output:**
```
[INF] Loaded plugin: Real-Time HDR SRGAN Pipeline 1.0.0.0
[INF] Real-Time HDR SRGAN Plugin v1.0.0.0 initialized
[INF] Loaded plugin: Webhook 18.0.0.0
```

### Verify files are present:
```bash
# SRGAN plugin
ls -lh /var/lib/jellyfin/plugins/Real-Time*HDR*/

# Webhook plugin
ls -lh /var/lib/jellyfin/plugins/Webhook_*/Jellyfin.Plugin.Webhook.deps.json
```

### Test webhook with Path variable:
1. Configure webhook in Jellyfin dashboard
2. Use this template:
   ```json
   {
     "Path": "{{Path}}",
     "Name": "{{Name}}"
   }
   ```
3. Play a movie
4. Check webhook receiver logs

**Expected payload:**
```json
{
  "Path": "/mnt/media/movies/Sample Movie.mkv",
  "Name": "Sample Movie"
}
```

---

## Troubleshooting

### "Failed to get resource" still appears

**Rebuild the plugin:**
```bash
cd jellyfin-plugin/Server
dotnet clean
dotnet build -c Release
sudo cp bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll \
        /var/lib/jellyfin/plugins/Real-Time*/
sudo systemctl restart jellyfin
```

### deps.json still missing

**Ensure you copied ALL files:**
```bash
# Don't just copy the DLL - copy EVERYTHING
sudo cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/* \
        /var/lib/jellyfin/plugins/Webhook_*/
```

### Jellyfin won't start

**Check logs:**
```bash
sudo journalctl -u jellyfin -n 100 --no-pager
```

**Common issues:**
- Wrong .NET version (need .NET 9.0)
- Missing dependency DLLs
- Permission issues

**Restore backup:**
```bash
sudo cp /var/lib/jellyfin/plugins/Real-Time*/*.dll.backup \
        /var/lib/jellyfin/plugins/Real-Time*/*.dll
sudo systemctl restart jellyfin
```

---

## Files Modified in This Fix

1. `jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj` - Fixed embedded resource paths
2. `build-and-deploy-all-plugins.sh` - Created comprehensive deployment script
3. `FIXES_APPLIED.md` - This document

## Previous Work (Already Complete)

- ✓ Enhanced `Plugin.cs` with logging and validation
- ✓ Enhanced `PluginConfiguration.cs` with validation attributes
- ✓ Enhanced `PluginApiController.cs` with error handling
- ✓ Patched webhook plugin with Path support in `DataObjectHelpers.cs`
- ✓ Created documentation (README, CHANGELOG, build.yaml)

---

## Summary

**Both issues are now fixed:**
1. ✅ SRGAN embedded resources will be found (after rebuild)
2. ✅ Webhook deps.json will be present (after proper build)

**Run the deployment script to apply all fixes.**
