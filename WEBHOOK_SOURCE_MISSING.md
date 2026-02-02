# Webhook Plugin Source Files Missing

## Error
```
Error reading resource 'Jellyfin.Plugin.Webhook.Configuration.Web.config.html' 
-- 'Could not find a part of the path '/var/lib/jellyfin/plugins/Webhook_18.0.0.0/Configuration/Web/config.html'.'
```

## Cause

The webhook plugin structure was created but the actual source files (C# classes, configuration pages, etc.) are missing. We only have the build configuration files.

## Solution - Run Setup Script

### On Your Jellyfin Server:

```bash
cd /path/to/Jellyfin-SRGAN-Plugin

# Pull latest changes (includes setup script)
git pull origin main

# Run the webhook source setup script
./scripts/setup_webhook_source.sh

# This will:
# 1. Clone official Jellyfin webhook plugin
# 2. Copy all source files
# 3. Keep our custom .csproj and NuGet.Config
# 4. Clean up

# After it completes, run install again
sudo ./scripts/install_all.sh
```

## What the Script Does

1. ✅ Clones official webhook plugin from GitHub
2. ✅ Copies all source files to `jellyfin-plugin-webhook/`
3. ✅ Preserves our custom configuration:
   - `Jellyfin.Plugin.Webhook.csproj` (net9.0, Jellyfin.Controller 10.11.5)
   - `NuGet.Config` (nuget.org only, no GitHub auth)
   - `build.yaml` (targetAbi 10.11.5.0)
4. ✅ Cleans up temporary files

## Alternative: Skip Webhook Plugin

If you don't need the webhook plugin right now, you can modify `install_all.sh` to skip it:

```bash
# Before running install_all.sh, set:
export SKIP_WEBHOOK=1
sudo ./scripts/install_all.sh
```

The RealTimeHDRSRGAN plugin will still build and install successfully.

## After Running Setup Script

You should see all source files:

```bash
ls -la jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/

# Should show:
Configuration/
Destinations/
Helpers/
Notifiers/
Plugin.cs
PluginConfiguration.cs
(and many more files)
```

Then the webhook plugin will build successfully.

## Manual Method (if script fails)

```bash
cd /path/to/Jellyfin-SRGAN-Plugin

# Clone official plugin
git clone --depth 1 https://github.com/jellyfin/jellyfin-plugin-webhook.git temp

# Backup our files
cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Jellyfin.Plugin.Webhook.csproj /tmp/
cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/NuGet.Config /tmp/

# Copy source
cp -r temp/Jellyfin.Plugin.Webhook/* jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/

# Restore our files
cp /tmp/Jellyfin.Plugin.Webhook.csproj jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/
cp /tmp/NuGet.Config jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/

# Clean up
rm -rf temp
```

## Summary

✅ **Quick Fix**: Run `./scripts/setup_webhook_source.sh` on server  
✅ **Alternative**: Skip webhook with `export SKIP_WEBHOOK=1`  
✅ **After Fix**: Run `sudo ./scripts/install_all.sh` again  

The script is now in git - pull and run it! 🚀
