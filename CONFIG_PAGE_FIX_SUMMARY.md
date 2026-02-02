# Configuration Page Fix - Quick Summary

## Problem
Plugin settings page shows "Can't gather plugin details" despite plugin being Active.

## Cause
- Incorrect page registration (two pages instead of one)
- External JavaScript reference (doesn't work with embedded resources)
- Wrong page name property

## Files Fixed

### 1. jellyfin-plugin/Server/Plugin.cs
Changed `GetPages()` to register single page with correct name:
```csharp
// Now returns single page with this.Name
public IEnumerable<PluginPageInfo> GetPages()
{
    return new[]
    {
        new PluginPageInfo
        {
            Name = this.Name,
            EmbeddedResourcePath = GetType().Namespace + ".ConfigurationPage.html"
        }
    };
}
```

### 2. jellyfin-plugin/ConfigurationPage.html
Embedded JavaScript inline instead of external reference:
```html
<!-- Removed: <script src="ConfigurationPage.js"></script> -->
<!-- Added: Inline <script> with all JS code -->
```

## How to Apply

### Quick Fix
```bash
sudo ./scripts/install_all.sh
```

### Manual Fix
```bash
cd jellyfin-plugin/Server
dotnet clean
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release

sudo systemctl stop jellyfin
sudo cp bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
sudo chown -R jellyfin:jellyfin /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
sudo systemctl start jellyfin
```

## Verify
Dashboard → Plugins → Real-Time HDR SRGAN Pipeline → Settings

Should now load with:
- ✅ GPU Detection section
- ✅ Plugin Settings (Enable Upscaling, GPU Device, etc.)
- ✅ Backup & Restore section

## Full Details
See: `PLUGIN_CONFIG_PAGE_FIX.md`
