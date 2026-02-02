# Quick Build - Webhook Plugin

## Status

The webhook plugin structure has been created with the essential build files:
- ✅ `Jellyfin.Plugin.Webhook.csproj` - Project file
- ✅ `build.yaml` - Build metadata
- ✅ `Directory.Build.props` - Build properties

## What's Missing

The full webhook plugin source code files are not included yet. This is a large plugin with many C# files including:
- Plugin.cs
- PluginConfiguration.cs
- Various notifier classes
- Destination handlers (Discord, Generic, etc.)
- Helper classes

## Options

### Option 1: Get from Official Repository (Recommended)

Clone the official Jellyfin webhook plugin and apply our {{Path}} patch:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin

# Clone official webhook plugin
git clone https://github.com/jellyfin/jellyfin-plugin-webhook.git temp-webhook

# Copy source files
cp -r temp-webhook/Jellyfin.Plugin.Webhook/* jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/

# Clean up
rm -rf temp-webhook

# Update to net9.0 and apply {{Path}} patch
# (The .csproj and build files are already updated)
```

### Option 2: Skip Webhook for Now

The RealTimeHDRSRGAN plugin can be built and installed without the webhook plugin:

```bash
# Set environment variable to skip webhook build
export SKIP_WEBHOOK_BUILD=1
sudo ./scripts/install_all.sh
```

### Option 3: Minimal Placeholder

Create a minimal webhook plugin that will compile but won't have all features:

This would require creating stub classes for all the required types, which is complex.

## Recommended Next Step

**Use Option 1** - Clone the official webhook plugin and use our configuration files:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin

# Backup our files
cp jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Jellyfin.Plugin.Webhook.csproj /tmp/
cp jellyfin-plugin-webhook/build.yaml /tmp/

# Clone official
git clone --depth 1 https://github.com/jellyfin/jellyfin-plugin-webhook.git temp-webhook

# Copy source
cp -r temp-webhook/Jellyfin.Plugin.Webhook/* jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/

# Restore our updated files
cp /tmp/Jellyfin.Plugin.Webhook.csproj jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/
cp /tmp/build.yaml jellyfin-plugin-webhook/

# Clean up
rm -rf temp-webhook

# Now you can build
cd jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet build -c Release
```

The key patch we need is in `Helpers/DataObjectHelpers.cs` to add the `{{Path}}` variable - this can be applied after cloning.

## Current Status

✅ RealTimeHDRSRGAN plugin - **READY TO BUILD**
⚠️ Webhook plugin - Needs source files (use Option 1 above)

You can proceed with building the RealTimeHDRSRGAN plugin now!
