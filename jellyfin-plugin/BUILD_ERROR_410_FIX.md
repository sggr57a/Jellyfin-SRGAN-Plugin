# Build Error Fix - Jellyfin NuGet Feed 410 Gone

## Problem

When building the plugin, you get this error:

```
error NU1301: Failed to retrieve information about 'Jellyfin.Controller' from remote source 
'https://repo.jellyfin.org/releases/nuget/...'
Response status code does not indicate success: 410 (Gone).
```

## Root Cause

The old Jellyfin NuGet feed URL (`https://repo.jellyfin.org/releases/nuget/`) has been shut down (HTTP 410 = Gone). 

Jellyfin packages are now only available on:
1. **nuget.org** (official NuGet repository)
2. **GitHub Packages** (for pre-release versions)

## Fix Applied ✅

### 1. Updated NuGet.Config

**File**: `jellyfin-plugin/Server/NuGet.Config`

**Changed from:**
```xml
<add key="jellyfin" value="https://repo.jellyfin.org/releases/nuget/" />
```

**Changed to:**
```xml
<add key="jellyfin-github" value="https://nuget.pkg.github.com/jellyfin/index.json" />
```

Note: The GitHub feed is there for reference, but we'll primarily use nuget.org.

### 2. Updated Package Reference

**File**: `jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj`

**Changed from:**
```xml
<PackageReference Include="Jellyfin.Controller" Version="10.11.*" />
```

**Changed to:**
```xml
<PackageReference Include="Jellyfin.Controller" Version="10.11.5" />
```

Using specific version 10.11.5 (latest stable) from nuget.org.

### 3. Updated Target ABI

**Files**: `manifest.json` and `build.yaml`

Updated `targetAbi` from `10.11.0.0` to `10.11.5.0` to match the package version.

## Build Now

Try building again:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin/Server

# Clear NuGet cache (optional but recommended)
dotnet nuget locals all --clear

# Restore packages
dotnet restore

# Build
dotnet build -c Release
```

## Using Docker Build

If you're building with Docker:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin

docker run --rm \
  -v "$(pwd)/Server:/src" \
  -w /src \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  sh -c "dotnet nuget locals all --clear && dotnet restore && dotnet build -c Release"
```

## Verify Build Success

After successful build, you should see:

```bash
ls -la Server/bin/Release/net9.0/
```

You should see:
- `Jellyfin.Plugin.RealTimeHdrSrgan.dll` (your plugin)
- `Jellyfin.Controller.dll` (dependency)
- Other dependency DLLs

## If Build Still Fails

### Issue: Still getting 410 error
**Solution**: Make sure you cleared the NuGet cache:
```bash
dotnet nuget locals all --clear
rm -rf ~/.nuget/packages/jellyfin.controller
```

### Issue: Package not found on nuget.org
**Check**: Verify the package exists:
```bash
curl https://api.nuget.org/v3/registration5-gz-semver2/jellyfin.controller/index.json
```

### Issue: GitHub authentication required
**Solution**: We're using nuget.org (no auth needed). The GitHub source is just a fallback.

### Issue: Wrong .NET version
**Check**: Make sure you have .NET 9.0 SDK:
```bash
dotnet --version
# Should show 9.x.x
```

## What Changed in Jellyfin Package Distribution

**Before (2024 and earlier):**
- Jellyfin hosted their own NuGet feed at `repo.jellyfin.org`
- All packages available there

**Now (2025+):**
- Official releases on **nuget.org** (public, no auth)
- Pre-release/dev builds on **GitHub Packages** (may require auth)
- Old feed permanently shut down (410 Gone)

## Package Information

- **Package**: Jellyfin.Controller
- **Version**: 10.11.5 (latest stable)
- **Target Framework**: .NET 9.0
- **Source**: https://www.nuget.org/packages/Jellyfin.Controller/10.11.5
- **Published**: Available now on nuget.org

## Next Steps After Successful Build

1. Verify build artifacts exist
2. Deploy to Jellyfin plugins directory
3. Restart Jellyfin
4. Check Dashboard → Plugins

See `PLUGIN_NOT_SUPPORTED_FIX.md` for deployment instructions.

## Quick Command Reference

```bash
# Clear cache and rebuild
cd jellyfin-plugin/Server
dotnet nuget locals all --clear
dotnet restore --force
dotnet build -c Release

# Check what was downloaded
ls ~/.nuget/packages/jellyfin.controller/

# Verify build output
ls -la bin/Release/net9.0/

# Deploy (example for Docker)
docker cp bin/Release/net9.0/. jellyfin:/config/plugins/RealTimeHDRSRGAN/
docker restart jellyfin
```

The build should now work successfully!
