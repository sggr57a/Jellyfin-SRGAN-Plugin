# Build Error Fix - Missing EntityFrameworkCore.Analyzers

## Error Message

```
error NETSDK1064: Package Microsoft.EntityFrameworkCore.Analyzers, version 9.0.11 
was not found. It might have been deleted since NuGet restore. Otherwise, NuGet 
restore might have only partially completed, which might have been due to maximum 
path length restrictions.
```

## Root Cause

The `Jellyfin.Controller` package has a dependency on `Microsoft.EntityFrameworkCore.Analyzers` version 9.0.11, but it wasn't being resolved properly because:

1. The old `Directory.Packages.props` file was interfering with package resolution
2. The transitive dependency wasn't being restored correctly

## Fix Applied ✅

### 1. Removed Conflicting File
**Deleted**: `jellyfin-plugin/Server/Directory.Packages.props`
- This file had an old SDK version reference (10.8.0.0)
- It was interfering with proper package resolution

### 2. Added Missing Dependency
**Updated**: `jellyfin-plugin/Server/RealTimeHdrSrgan.Plugin.csproj`

Added explicit reference:
```xml
<PackageReference Include="Microsoft.EntityFrameworkCore.Analyzers" Version="9.0.11" />
```

## Try Building Again

```bash
cd /path/to/jellyfin-plugin
./build-plugin.sh
```

The script will:
1. Clear NuGet cache
2. Restore packages (including EntityFrameworkCore.Analyzers)
3. Build successfully

## What Changed in the .csproj File

**Before:**
```xml
<ItemGroup>
  <PackageReference Include="Jellyfin.Controller" Version="10.11.5" />
</ItemGroup>
```

**After:**
```xml
<ItemGroup>
  <PackageReference Include="Jellyfin.Controller" Version="10.11.5" />
  <PackageReference Include="Microsoft.EntityFrameworkCore.Analyzers" Version="9.0.11" />
</ItemGroup>
```

## Why This Works

- `Jellyfin.Controller` depends on Entity Framework analyzers
- By explicitly adding it, we ensure it gets restored
- Removing the old `Directory.Packages.props` prevents version conflicts

## Expected Output

After running `./build-plugin.sh`:

```
==========================================
RealTimeHDRSRGAN Plugin Builder
==========================================

✓ Found dotnet: 9.0.x

Clearing NuGet cache...
Cleaning previous builds...
Restoring packages...
  Determining projects to restore...
  Restored RealTimeHdrSrgan.Plugin.csproj (in X.Xs)

Building plugin...
  RealTimeHdrSrgan.Plugin -> /path/to/bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

==========================================
✓ Build complete!
==========================================
```

## If Error Persists

If you still get the error, try manually:

```bash
cd jellyfin-plugin/Server

# Clear everything
dotnet nuget locals all --clear
rm -rf bin obj

# Force restore with verbose output
dotnet restore --force --verbosity detailed

# Build
dotnet build -c Release
```

This will show exactly what packages are being restored and help identify any remaining issues.

## Files Modified

1. ✅ `Server/RealTimeHdrSrgan.Plugin.csproj` - Added EntityFrameworkCore.Analyzers reference
2. ✅ `Server/Directory.Packages.props` - DELETED (was causing conflicts)

## Summary

The build should now succeed. The changes ensure all required dependencies are properly resolved.
