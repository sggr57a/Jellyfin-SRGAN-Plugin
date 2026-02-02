# Plugin Versions - Verified and Corrected

## Summary

All plugin versions have been verified and corrected to match Jellyfin 10.11.5 and .NET 9.0.

## RealTimeHDRSRGAN Plugin

### Version Information
- **Plugin Version**: 1.0.0.0
- **Target ABI**: 10.11.5.0 (Jellyfin 10.11.5)
- **Target Framework**: net9.0 (.NET 9.0)
- **GUID**: a1b2c3d4-e5f6-7890-abcd-ef1234567890

### Dependencies
```xml
<PackageReference Include="Jellyfin.Controller" Version="10.11.5" />
<PackageReference Include="Microsoft.EntityFrameworkCore.Analyzers" Version="9.0.11" />
```

### Files
- **manifest.json**: targetAbi = "10.11.5.0" ✅
- **build.yaml**: targetAbi = "10.11.5.0" ✅
- **RealTimeHdrSrgan.Plugin.csproj**:
  - TargetFramework = net9.0 ✅
  - Jellyfin.Controller = 10.11.5 ✅

## Webhook Plugin (Patched)

### Version Information
- **Plugin Version**: 18
- **Target ABI**: 10.11.5.0 (Jellyfin 10.11.5) ✅ CORRECTED
- **Target Framework**: net9.0 (.NET 9.0)
- **GUID**: 71552A5A-5C5C-4350-A2AE-EBE451A30173

### Dependencies
```xml
<PackageReference Include="Jellyfin.Controller" Version="10.11.5" /> ✅ CORRECTED
<PackageReference Include="MailKit" Version="4.14.1" />
<PackageReference Include="Handlebars.Net" Version="2.1.6" />
<PackageReference Include="Microsoft.Extensions.Http" Version="10.0.1" />
<PackageReference Include="MQTTnet.Extensions.ManagedClient" Version="4.3.7.1207" />
```

### Files Updated
- **build.yaml**: targetAbi = "10.11.5.0" ✅ CORRECTED (was 10.11.0.0)
- **Jellyfin.Plugin.Webhook.csproj**:
  - TargetFramework = net9.0 ✅
  - Jellyfin.Controller = 10.11.5 ✅ CORRECTED (was 10.*-*)

### Patch Features
- ✅ Exposes {{Path}} variable in DataObjectHelpers.cs
- ✅ All standard webhook functionality intact
- ✅ Compatible with Jellyfin 10.11.5

## install_all.sh Updates

### Step 2: RealTimeHDRSRGAN Plugin Build

**IMPROVED**:
```bash
# Now includes:
- dotnet nuget locals all --clear
- dotnet restore --force
- Proper ownership (jellyfin:jellyfin)
- Correct file permissions
- Shows target version in output
```

### Step 2.3: Webhook Plugin Build

**CORRECTED**:
```bash
# Now includes:
- dotnet nuget locals all --clear
- dotnet restore --force
- Copies ALL DLLs (including dependencies)
- Stops/starts Jellyfin properly
- Sets correct ownership
```

### Step 9: Webhook Configuration (NEW)

**ADDED**:
```bash
# Automatically configures webhook:
- Creates XML configuration
- Sets up PlaybackStart trigger
- Includes {{Path}} variable template
- Restarts Jellyfin to apply
```

## Compatibility Matrix

| Component | Version | Target | Status |
|-----------|---------|--------|--------|
| **Jellyfin Server** | 10.11.5+ | - | ✅ Required |
| **RealTimeHDRSRGAN Plugin** | 1.0.0 | 10.11.5 | ✅ Compatible |
| **Webhook Plugin** | 18 | 10.11.5 | ✅ Compatible |
| **.NET Runtime** | 9.0 | - | ✅ Required |
| **Jellyfin.Controller** | 10.11.5 | - | ✅ Used |

## What Was Changed

### 1. Webhook Plugin .csproj
**Before**:
```xml
<PackageReference Include="Jellyfin.Controller" Version="10.*-*" />
```

**After**:
```xml
<PackageReference Include="Jellyfin.Controller" Version="10.11.5" />
```

**Why**: Specific version prevents NuGet resolution issues and ensures compatibility.

### 2. Webhook Plugin build.yaml
**Before**:
```yaml
targetAbi: "10.11.0.0"
```

**After**:
```yaml
targetAbi: "10.11.5.0"
```

**Why**: Must match actual Jellyfin.Controller package version.

### 3. install_all.sh Step 2
**Added**:
- Cache clearing before build
- Forced package restore
- Proper ownership and permissions
- Version information in output

**Why**: Prevents build errors and ensures clean installations.

### 4. install_all.sh Step 2.3
**Added**:
- Cache clearing before build
- Forced package restore
- Copy ALL DLLs (not just main)
- Jellyfin stop/start handling

**Why**: Webhook plugin has dependencies that must be included.

## Build Verification

### RealTimeHDRSRGAN Plugin
```bash
cd jellyfin-plugin/Server
dotnet restore
dotnet build -c Release

# Should output:
# -> Jellyfin.Plugin.RealTimeHdrSrgan.dll
# -> Using Jellyfin.Controller 10.11.5
# -> Using EntityFrameworkCore.Analyzers 9.0.11
```

### Webhook Plugin
```bash
cd jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet restore
dotnet build -c Release

# Should output:
# -> Jellyfin.Plugin.Webhook.dll
# -> Using Jellyfin.Controller 10.11.5
# -> Plus: Handlebars.dll, MailKit.dll, MQTTnet.dll, etc.
```

## Deployment Verification

### Check Installed Versions

**RealTimeHDRSRGAN**:
```bash
ls -la /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
# Should show:
# - Jellyfin.Plugin.RealTimeHdrSrgan.dll
# - Jellyfin.Controller.dll (10.11.5)
# - Microsoft.EntityFrameworkCore.Analyzers.dll
# - gpu-detection.sh, backup-config.sh, restore-config.sh
```

**Webhook**:
```bash
ls -la /var/lib/jellyfin/plugins/Webhook/
# Should show:
# - Jellyfin.Plugin.Webhook.dll
# - Jellyfin.Controller.dll (10.11.5)
# - Handlebars.dll
# - MailKit.dll
# - MimeKit.dll
# - BouncyCastle.Cryptography.dll
# - MQTTnet.dll
# - MQTTnet.Extensions.ManagedClient.dll
```

### Check in Jellyfin Dashboard

1. Open Jellyfin → Dashboard → Plugins
2. Should see:
   - **Real-Time HDR SRGAN Pipeline** (v1.0.0)
   - **Webhook** (v18)
3. Both should show "Active" status
4. Click each to verify configuration pages load

## Troubleshooting Version Issues

### Error: "Target ABI not supported"
**Cause**: Plugin built for wrong Jellyfin version
**Fix**:
```bash
# Check Jellyfin version
jellyfin --version
# Should be 10.11.5 or higher

# If not, upgrade Jellyfin first
```

### Error: "Assembly version mismatch"
**Cause**: Jellyfin.Controller version doesn't match
**Fix**:
```bash
# Clear cache and rebuild
cd [plugin-directory]
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release
```

### Error: "Method not found" or "Type load exception"
**Cause**: Missing dependencies or wrong .NET version
**Fix**:
```bash
# Check .NET version
dotnet --version
# Should be 9.0.x

# Ensure all DLLs are copied
sudo cp bin/Release/net9.0/*.dll /var/lib/jellyfin/plugins/[PluginName]/
```

## Version History

### v1.0 (Current)
- ✅ Jellyfin 10.11.5 compatibility
- ✅ .NET 9.0 target
- ✅ Corrected all package versions
- ✅ Improved build process
- ✅ Automatic configuration

## Summary

All plugins now correctly target:
- **Jellyfin**: 10.11.5
- **.NET**: 9.0
- **Jellyfin.Controller**: 10.11.5

The `install_all.sh` script now:
- ✅ Clears NuGet cache before building
- ✅ Forces package restore
- ✅ Copies all required dependencies
- ✅ Sets correct permissions
- ✅ Automatically configures webhook
- ✅ Handles Jellyfin restart properly

Everything is version-aligned and ready to build! 🎉
