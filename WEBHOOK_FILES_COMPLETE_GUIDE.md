# Webhook Plugin - Complete File Guide

## What Files Are Created and Where They Go

### Phase 1: Source Files (After `setup_webhook_source.sh`)

**Location:** `/root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/`

```
Jellyfin.Plugin.Webhook/
├── Configuration/
│   └── Web/
│       ├── config.html              ← UI for webhook settings
│       └── config.js                ← JavaScript for UI
├── Helpers/
│   └── DataObjectHelpers.cs         ← Contains {{Path}} patch
├── Models/
│   ├── NotificationType.cs
│   ├── GenericFormOption.cs
│   └── ... (other model files)
├── Notifiers/
│   ├── GenericNotifier.cs
│   ├── DiscordNotifier.cs
│   └── ... (other notifier files)
├── Jellyfin.Plugin.Webhook.csproj   ← Project file (our custom version)
└── NuGet.Config                      ← NuGet sources (our custom version)
```

**Critical Files:**
1. ✅ **DataObjectHelpers.cs** - Must contain Path patch:
   ```csharp
   if (!string.IsNullOrEmpty(item.Path))
   {
       dataObject["Path"] = item.Path;
   }
   ```

2. ✅ **config.html** - Embedded in DLL (specified in .csproj)
3. ✅ **config.js** - Embedded in DLL (specified in .csproj)

### Phase 2: Build Output (After `dotnet build -c Release`)

**Location:** `/root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/`

```
net9.0/
├── Jellyfin.Plugin.Webhook.dll              ← Main plugin DLL (includes config.html/js embedded)
├── Jellyfin.Plugin.Webhook.deps.json        ← Dependency info
├── Jellyfin.Plugin.Webhook.pdb              ← Debug symbols
├── Handlebars.Net.dll                       ← Template engine dependency
├── MailKit.dll                              ← Email notification dependency
├── MimeKit.dll                              ← Email MIME support
├── MQTTnet.dll                              ← MQTT support
├── MQTTnet.Extensions.ManagedClient.dll     ← MQTT client
├── BouncyCastle.Cryptography.dll            ← Crypto for email
└── ... (other dependency DLLs)
```

**What Gets Embedded:**
- `config.html` and `config.js` are **compiled into** the DLL as embedded resources
- These are NOT separate files after build - they're inside the DLL
- Jellyfin extracts them at runtime

### Phase 3: Jellyfin Installation (After `install_all.sh`)

**Location:** `/var/lib/jellyfin/plugins/Webhook_18.0.0.0/`
(Version number may vary: Webhook_17.0.0.0, Webhook_18.0.0.0, etc.)

```
Webhook_18.0.0.0/
├── Jellyfin.Plugin.Webhook.dll              ← Copied from build
├── Jellyfin.Plugin.Webhook.deps.json        ← Copied from build
├── Handlebars.Net.dll                       ← Copied from build
├── MailKit.dll                              ← Copied from build
├── MimeKit.dll                              ← Copied from build
├── MQTTnet.dll                              ← Copied from build
├── MQTTnet.Extensions.ManagedClient.dll     ← Copied from build
├── BouncyCastle.Cryptography.dll            ← Copied from build
└── ... (all other DLL dependencies)
```

**File Permissions:**
```bash
Owner: jellyfin:jellyfin
Permissions: 644 (rw-r--r--)
```

### Phase 4: Configuration (After `configure_webhook.py`)

**Location:** `/var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml`

```xml
<?xml version="1.0"?>
<PluginConfiguration>
  <ServerUrl></ServerUrl>
  <GenericOptions>
    <GenericOption>
      <NotificationTypes>
        <NotificationType>PlaybackStart</NotificationType>
      </NotificationTypes>
      <WebhookName>SRGAN 4K Upscaler</WebhookName>
      <WebhookUri>http://localhost:5000/upscale-trigger</WebhookUri>
      <EnableMovies>true</EnableMovies>
      <EnableEpisodes>true</EnableEpisodes>
      <Template>BASE64_ENCODED_JSON_WITH_PATH</Template>
      <!-- Template decodes to: {"Path":"{{Path}}","Name":"{{Name}}",...} -->
    </GenericOption>
  </GenericOptions>
</PluginConfiguration>
```

## Complete Installation Flow

### 1. Setup Webhook Source
```bash
./scripts/setup_webhook_source.sh
```

**What it does:**
1. Clones official webhook plugin from GitHub
2. Copies ALL source files to local directory
3. Restores our custom `.csproj` (with build fixes)
4. Restores our custom `NuGet.Config`
5. Lists files copied

**Files created:** ~50+ C# source files + config.html + config.js

### 2. Apply Path Patch
```bash
./scripts/patch_webhook_path.sh
```

**What it does:**
1. Finds `DataObjectHelpers.cs`
2. Locates insertion point (tries 3 different patterns)
3. Inserts Path property code:
   ```csharp
   if (!string.IsNullOrEmpty(item.Path))
   {
       dataObject["Path"] = item.Path;
   }
   ```
4. Verifies patch was applied

**Files modified:** `DataObjectHelpers.cs` (1 file)

### 3. Build Plugin
```bash
cd jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet build -c Release
```

**What it does:**
1. Compiles all C# source files
2. Embeds `config.html` and `config.js` into DLL
3. Packages dependencies
4. Creates `Jellyfin.Plugin.Webhook.dll` (~200KB)

**Files created:** DLL + ~10 dependency DLLs + deps.json (~2MB total)

### 4. Install to Jellyfin
```bash
sudo ./scripts/install_all.sh
```

**What it does:**
1. Stops Jellyfin service
2. Backs up existing webhook DLL
3. Copies **ALL DLLs** from build output to `/var/lib/jellyfin/plugins/Webhook_*/`
4. Copies `deps.json`
5. Sets ownership to `jellyfin:jellyfin`
6. Sets permissions to `644`
7. Starts Jellyfin service

**Files copied:** 10-15 DLL files

### 5. Configure Webhook
```bash
sudo python3 scripts/configure_webhook.py http://localhost:5000
```

**What it does:**
1. Creates/updates webhook XML configuration
2. Adds SRGAN webhook entry
3. Sets PlaybackStart trigger
4. Includes `{{Path}}` in template
5. Enables Movies and Episodes

**Files created/modified:** `Jellyfin.Plugin.Webhook.xml` (1 file)

## Verification Commands

### Check Source Files Present
```bash
ls -la /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/

# Should show:
# - Helpers/DataObjectHelpers.cs
# - Configuration/Web/config.html
# - Configuration/Web/config.js
# - Jellyfin.Plugin.Webhook.csproj
```

### Check Path Patch Applied
```bash
grep -A 3 '"Path".*item\.Path' /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/Helpers/DataObjectHelpers.cs

# Should show:
# if (!string.IsNullOrEmpty(item.Path))
# {
#     dataObject["Path"] = item.Path;
# }
```

### Check Build Output
```bash
ls -lh /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook/bin/Release/net9.0/

# Should show:
# - Jellyfin.Plugin.Webhook.dll (200KB+)
# - Handlebars.Net.dll
# - MailKit.dll
# - MQTTnet.dll
# - etc.
```

### Check Installed Files
```bash
WEBHOOK_DIR=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" | head -1)
ls -lh $WEBHOOK_DIR/

# Should show:
# -rw-r--r-- jellyfin jellyfin  Jellyfin.Plugin.Webhook.dll
# -rw-r--r-- jellyfin jellyfin  Handlebars.Net.dll
# -rw-r--r-- jellyfin jellyfin  MailKit.dll
# etc.
```

### Check Configuration
```bash
cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml | grep -A 2 "<Template>"

# Should show Base64 encoded template
# Decode it:
cat /var/lib/jellyfin/plugins/configurations/Jellyfin.Plugin.Webhook.xml | \
  grep "<Template>" | \
  sed 's/<Template>//;s/<\/Template>//' | \
  base64 -d | \
  python3 -m json.tool

# Should show: {"Path":"{{Path}}","Name":"{{Name}}",...}
```

### Check Embedded Resources
```bash
WEBHOOK_DIR=$(find /var/lib/jellyfin/plugins -maxdepth 1 -type d -name "Webhook_*" | head -1)
strings $WEBHOOK_DIR/Jellyfin.Plugin.Webhook.dll | grep -E "config\.(html|js)"

# Should show:
# Configuration.Web.config.html
# Configuration.Web.config.js
```

## Complete Verification Script

Run this to check everything:
```bash
./scripts/verify_webhook_build.sh
```

**Checks:**
1. ✅ All source files present
2. ✅ Path patch applied to DataObjectHelpers.cs
3. ✅ Build output exists with all DLLs
4. ✅ Embedded resources in DLL
5. ✅ Files installed to Jellyfin plugins directory
6. ✅ Correct permissions and ownership
7. ✅ Configuration includes {{Path}}
8. ✅ Jellyfin recognizes the plugin

## File Count Summary

**Source files:** ~50+ files (after setup_webhook_source.sh)
**Build output:** ~15 files (after dotnet build)
**Installed files:** ~15 files (after install_all.sh)
**Config files:** 1 file (Jellyfin.Plugin.Webhook.xml)

**Total files involved:** ~80+ files

## Critical Files Checklist

### Must Exist:
- [x] Source: `DataObjectHelpers.cs` with Path patch
- [x] Source: `config.html` and `config.js`
- [x] Build: `Jellyfin.Plugin.Webhook.dll` with embedded resources
- [x] Build: All dependency DLLs (Handlebars, MailKit, MQTTnet, etc.)
- [x] Installed: All DLLs in `/var/lib/jellyfin/plugins/Webhook_*/`
- [x] Config: `Jellyfin.Plugin.Webhook.xml` with {{Path}} template

### Must Be Correct:
- [x] Ownership: `jellyfin:jellyfin`
- [x] Permissions: `644` on all DLLs
- [x] Embedded: `config.html` and `config.js` in DLL
- [x] Patched: Path property in DataObjectHelpers.cs

## Troubleshooting Missing Files

### If source files missing:
```bash
./scripts/setup_webhook_source.sh
```

### If DataObjectHelpers.cs not patched:
```bash
./scripts/patch_webhook_path.sh
```

### If build output missing:
```bash
cd /root/Jellyfin-SRGAN-Plugin/jellyfin-plugin-webhook/Jellyfin.Plugin.Webhook
dotnet clean
dotnet restore --force
dotnet build -c Release
```

### If installed files missing:
```bash
sudo ./scripts/install_all.sh
```

### If config.html/js not embedded:
Check `.csproj` has:
```xml
<ItemGroup>
  <EmbeddedResource Include="Configuration\Web\config.html" />
  <EmbeddedResource Include="Configuration\Web\config.js" />
</ItemGroup>
```

Then rebuild.

## Success Indicators

✅ `verify_webhook_build.sh` passes all checks
✅ All ~15 DLL files present in Jellyfin plugins directory
✅ config.html and config.js embedded in DLL
✅ DataObjectHelpers.cs has Path patch
✅ Webhook configuration includes {{Path}}
✅ File permissions are correct (644, jellyfin:jellyfin)
✅ Jellyfin recognizes the plugin

**When all these pass, the patched webhook plugin is complete!** 🎉
