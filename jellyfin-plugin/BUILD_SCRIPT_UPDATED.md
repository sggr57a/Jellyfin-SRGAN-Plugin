# Build Script Updated - Now Includes Cache Clearing

## What Was Added

The build script (`jellyfin-plugin/build-plugin.sh`) now includes:

### ✅ For Native Builds (with dotnet SDK):
```bash
1. Clearing NuGet cache...
   dotnet nuget locals all --clear

2. Cleaning previous builds...
   dotnet clean -c Release

3. Restoring packages...
   dotnet restore --force

4. Building plugin...
   dotnet build -c Release
```

### ✅ For Docker Builds:
```bash
docker run --rm \
  -v "$(pwd):/src" \
  -w /src \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  sh -c "dotnet nuget locals all --clear && 
         dotnet restore --force && 
         dotnet clean -c Release && 
         dotnet build -c Release"
```

## Why This Matters

The cache clearing fixes the **410 Gone** error by:
1. **Clearing old cached packages** from the defunct Jellyfin NuGet feed
2. **Forcing fresh restore** of packages from nuget.org
3. **Ensuring clean build** without old artifacts

## How to Use the Updated Script

### Simple Way:
```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin
./build-plugin.sh
```

The script will:
1. ✅ Check if dotnet is installed
2. ✅ Clear NuGet cache automatically
3. ✅ Restore packages from correct source (nuget.org)
4. ✅ Build the plugin
5. ✅ Show deployment instructions

### What You'll See:

```
==========================================
RealTimeHDRSRGAN Plugin Builder
==========================================

✓ Found dotnet: 9.0.x

Clearing NuGet cache...
info : Clearing NuGet HTTP cache: /Users/.../.nuget/v3-cache
info : Clearing NuGet global packages folder: /Users/.../.nuget/packages
info : Local resources cleared.

Cleaning previous builds...
Build succeeded.

Restoring packages...
  Determining projects to restore...
  Restored /path/to/RealTimeHdrSrgan.Plugin.csproj (in 2.3s)

Building plugin...
  RealTimeHdrSrgan.Plugin -> /path/to/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

==========================================
✓ Build complete!
==========================================
```

## No More Manual Steps Needed

Before, you had to manually:
```bash
dotnet nuget locals all --clear
dotnet restore
dotnet build -c Release
```

Now, just run:
```bash
./build-plugin.sh
```

And it does everything for you!

## What Gets Cleared

The `dotnet nuget locals all --clear` command clears:
- ✅ HTTP cache (downloaded package metadata)
- ✅ Global packages folder (actual package files)
- ✅ Temp cache
- ✅ Plugins cache

This ensures no old references to the defunct `repo.jellyfin.org` remain.

## If You Already Ran the Build

If you already tried building and got the 410 error, just run the script again:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin
./build-plugin.sh
```

It will clear the cache and rebuild from scratch using the correct package sources.

## Summary of All Changes

### Files Modified:
1. ✅ `Server/NuGet.Config` - Updated package sources (removed defunct feed)
2. ✅ `Server/RealTimeHdrSrgan.Plugin.csproj` - Using Jellyfin.Controller 10.11.5
3. ✅ `manifest.json` - Updated targetAbi to 10.11.5.0
4. ✅ `build.yaml` - Updated targetAbi to 10.11.5.0
5. ✅ `build-plugin.sh` - Now includes cache clearing and restore steps

### Documentation Created:
1. ✅ `BUILD_ERROR_410_FIX.md` - Explains the 410 error and fix
2. ✅ This file - Build script updates

## Ready to Build!

Just run:
```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin
./build-plugin.sh
```

The build should now succeed! 🎉
