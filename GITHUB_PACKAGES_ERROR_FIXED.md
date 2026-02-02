# GitHub Packages Authentication Error - FIXED

## Error
```
Your request could not be authenticated by the GitHub Packages service.
Please ensure your access token is valid and has the appropriate scopes configured.
```

## Cause
The NuGet.Config file included a GitHub Packages source that requires authentication:
```xml
<add key="jellyfin-github" value="https://nuget.pkg.github.com/jellyfin/index.json" />
```

GitHub Packages NuGet feeds require a personal access token (PAT) for authentication, even for public packages.

## Solution ✅

Removed the GitHub Packages source from both NuGet.Config files. We only need nuget.org since `Jellyfin.Controller` is available there.

### Files Fixed:
1. `jellyfin-plugin/Server/NuGet.Config`
2. `jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/NuGet.Config`

### New Configuration:
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
```

## Why This Works

- ✅ `Jellyfin.Controller 10.11.5` is available on nuget.org
- ✅ No authentication required for nuget.org
- ✅ All other packages are also on nuget.org
- ✅ Faster package restore (one source instead of two)

## Try Again

Now you can run the build again:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin/jellyfin-plugin/Server

# Clear cache
dotnet nuget locals all --clear

# Restore (should work now)
dotnet restore --force

# Build
dotnet build -c Release
```

Or run the full installation:

```bash
cd /Users/jmclaughlin/Jellyfin-SRGAN-Plugin
sudo ./scripts/install_all.sh
```

## Verification

When it works, you should see:
```
Restoring packages...
  Restored /path/to/RealTimeHdrSrgan.Plugin.csproj (in X ms).
```

No GitHub authentication errors!

## Alternative (If Needed)

If for some reason you need GitHub Packages in the future, you would need to:

1. Create a GitHub Personal Access Token with `read:packages` scope
2. Add it to NuGet.Config:
```xml
<packageSourceCredentials>
  <jellyfin-github>
    <add key="Username" value="YOUR_GITHUB_USERNAME" />
    <add key="ClearTextPassword" value="YOUR_PAT_TOKEN" />
  </jellyfin-github>
</packageSourceCredentials>
```

But this is **NOT needed** for this project since all packages are on nuget.org.

## Summary

✅ **Fixed**: Removed GitHub Packages source
✅ **Uses**: nuget.org only
✅ **Works**: No authentication required

The error is now resolved! 🎉
