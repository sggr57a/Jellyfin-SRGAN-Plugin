# Technical Specification: Jellyfin-SRGAN-Plugin

## Task Assessment

**Difficulty**: Medium

While the existing codebase provides a solid foundation, completing a production-ready Jellyfin plugin involves moderate complexity including:
- Multi-language integration (C#, Python, JavaScript)
- Cross-platform compatibility considerations
- Plugin packaging and distribution
- Integration testing across components
- Documentation and deployment procedures

## 1. Technical Context

### Current State Analysis

The project already contains substantial infrastructure:

#### Existing Components
1. **Jellyfin Plugin (C#)** - `jellyfin-plugin/Server/`
   - Core plugin class with GUID and metadata
   - Configuration page (HTML/JS)
   - API controller with endpoints for:
     - GPU detection
     - Configuration backup/restore
     - HLS status checking
     - Upscaling triggers
   - Uses .NET 9.0 targeting Jellyfin 10.8+

2. **Python Backend** - `scripts/`
   - `watchdog.py`: Flask webhook receiver (port 5000)
   - `srgan_pipeline.py`: FFmpeg-based video upscaling
   - Various monitoring and testing utilities

3. **Client-Side UI**
   - Configuration page (HTML/CSS/JS)
   - Progress overlay scripts
   - HLS streaming integration

4. **Infrastructure**
   - Docker container with NVIDIA GPU support
   - systemd service for watchdog
   - nginx for HLS serving

### Technology Stack

**Plugin (Server-side)**
- Language: C# (.NET 9.0)
- Framework: Jellyfin Plugin SDK
- Dependencies:
  - MediaBrowser.Common
  - MediaBrowser.Model
  - ASP.NET Core (for API controllers)

**Processing Pipeline**
- Language: Python 3.8+
- Core Dependencies:
  - Flask 3.0.3+ (webhook API)
  - PyTorch 2.4.0+ with CUDA 12.1 (optional AI model)
  - opencv-python, Pillow (image processing)
  - FFmpeg (video processing)

**Container**
- Base: `sggr57a/nvidia-cuda-ffmpeg:1.5`
- Runtime: NVIDIA Container Runtime
- GPU: NVIDIA CUDA-capable (RTX series recommended)

**Client-side**
- Vanilla JavaScript
- HTML5/CSS3
- No external JS frameworks

### Build System

**Plugin Build**
- Tool: dotnet CLI
- Project: `RealTimeHdrSrgan.Plugin.csproj`
- Output: DLL assembly
- Embedded resources: HTML/JS configuration pages
- Content files: Shell scripts for GPU detection and config management

**Container Build**
- Tool: Docker Compose
- Services: hdr-srgan-pipeline, srgan-upscaler, hls-server, (optional) jellyfin
- Networks: hdr-srgan-network (bridge)

## 2. Requirements Clarification

**Critical Question**: The task description "Jellyfin-SRGAN-Plugin" is ambiguous. Please clarify what specifically needs to be done:

### Option A: Complete Plugin Development
- Finish any incomplete features in the existing plugin
- Add comprehensive error handling
- Implement proper logging
- Add unit/integration tests
- Create plugin packaging for distribution

### Option B: Plugin Enhancement
- Add new features (e.g., advanced configuration, monitoring dashboard)
- Improve UI/UX
- Add more transcoding profiles
- Enhanced GPU management

### Option C: Plugin Packaging & Distribution
- Create JPRM-compatible plugin manifest
- Package for Jellyfin plugin repository
- Create installation documentation
- Version management and releases

### Option D: Bug Fixes & Stabilization
- Fix existing issues
- Improve error handling
- Add validation
- Performance optimization

**Recommendation**: Based on the current state, I suggest Option A (Complete Plugin Development) combined with Option C (Packaging), as the plugin appears functional but may need:
1. Proper packaging for distribution
2. Comprehensive testing
3. Production-ready error handling
4. Complete documentation

## 3. Implementation Approach

Assuming we proceed with completing plugin development and packaging (Options A + C):

### 3.1 Plugin Architecture

```
jellyfin-plugin/
├── Server/
│   ├── Plugin.cs              # Main plugin class
│   ├── PluginConfiguration.cs # Configuration model
│   └── Controllers/
│       └── PluginApiController.cs # REST API endpoints
├── ConfigurationPage.html     # Admin UI
├── ConfigurationPage.js       # UI logic
├── manifest.json             # Plugin metadata
├── build.yaml                # JPRM build config (to be created)
└── README.md                 # Plugin documentation (to be created)
```

### 3.2 Key Features

**Core Plugin Functionality** (Already Implemented)
- ✅ GPU detection and configuration
- ✅ Configuration backup/restore
- ✅ HLS streaming status checks
- ✅ Manual upscaling triggers
- ✅ Configuration persistence

**Webhook Integration** (External - Already Implemented)
- Uses separate patched webhook plugin in `jellyfin-plugin-webhook/`
- Communicates with Python watchdog via HTTP

**Video Processing** (External - Already Implemented)
- Docker container with Python pipeline
- FFmpeg with NVIDIA hardware acceleration
- Optional AI model support

### 3.3 Integration Points

```
┌─────────────────────────────────────────────────────────┐
│ Jellyfin Server                                         │
│  ├─ RealTimeHdrSrgan Plugin (C#)                       │
│  │   └─ API Endpoints (/Plugins/RealTimeHDRSRGAN/*)   │
│  │                                                       │
│  └─ Webhook Plugin (Patched)                           │
│      └─ POST to watchdog on playback                   │
└──────────────┬──────────────────────────────────────────┘
               │
               │ HTTP
               ▼
┌──────────────────────────────────────────────────────────┐
│ Python Watchdog (Flask) - Port 5000                      │
│  ├─ /upscale-trigger (receives webhooks)                │
│  ├─ /hls-status/{filename} (HLS availability)           │
│  └─ /health (health check)                              │
└──────────────┬───────────────────────────────────────────┘
               │
               │ Queue (JSONL file)
               ▼
┌──────────────────────────────────────────────────────────┐
│ Docker Container (srgan-upscaler)                        │
│  ├─ srgan_pipeline.py (video processing)                │
│  ├─ FFmpeg with NVENC/NVDEC                             │
│  └─ Optional PyTorch SRGAN model                        │
└──────────────┬───────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────┐
│ Output                                                    │
│  ├─ /data/upscaled/{filename}.ts (final file)           │
│  └─ /data/upscaled/hls/{filename}/*.ts (HLS segments)   │
└───────────────────────────────────────────────────────────┘
```

### 3.4 Patterns and Conventions

Based on existing code review:

**C# Conventions**
- Namespace: `Jellyfin.Plugin.RealTimeHdrSrgan`
- API Route prefix: `/Plugins/RealTimeHDRSRGAN`
- Async methods for HTTP calls
- Structured logging (to be enhanced)
- IActionResult return types with JSON responses

**Configuration Pattern**
- Extends `BasePluginConfiguration`
- Properties auto-saved by Jellyfin framework
- Exposed via REST API for client access

**Error Handling Pattern**
- Current: Returns `{success: false, error: "message"}` in responses
- Should add: Proper exception logging, validation

**Client-Side Pattern**
- Direct DOM manipulation (no frameworks)
- Fetch API for AJAX calls
- Event-driven UI updates

## 4. Source Code Structure Changes

### Files to Create

1. **`jellyfin-plugin/build.yaml`**
   - JPRM (Jellyfin Plugin Repository Manager) configuration
   - Defines build process, dependencies, target Jellyfin version

2. **`jellyfin-plugin/README.md`**
   - Plugin-specific documentation
   - Installation instructions
   - Configuration guide
   - Troubleshooting

3. **`jellyfin-plugin/CHANGELOG.md`**
   - Version history
   - Breaking changes
   - New features per release

4. **`jellyfin-plugin/Server/Logging/PluginLogger.cs`** (optional)
   - Structured logging wrapper
   - Consistent log formatting

### Files to Modify

1. **`jellyfin-plugin/Server/Plugin.cs`**
   - Add version information
   - Add initialization logging
   - Add configuration validation on load

2. **`jellyfin-plugin/Server/Controllers/PluginApiController.cs`**
   - Add comprehensive error handling
   - Add request/response logging
   - Add input validation
   - Add rate limiting (if needed)
   - Add cancellation token support for async operations

3. **`jellyfin-plugin/Server/PluginConfiguration.cs`**
   - Add data validation attributes
   - Add default value initialization
   - Add configuration migration support (for version updates)

4. **`jellyfin-plugin/ConfigurationPage.js`**
   - Add error handling for API calls
   - Add loading states
   - Add success/error notifications
   - Add configuration validation

5. **`jellyfin-plugin/manifest.json`**
   - Update version
   - Add proper changelog
   - Ensure GUID is unique and documented

### Files to Keep As-Is

- Shell scripts (gpu-detection.sh, backup-config.sh, restore-config.sh)
- ConfigurationPage.html (minor updates only if needed)
- Supporting JavaScript files (hls-streaming.js, playback-progress-overlay.js)

## 5. Data Model / API / Interface Changes

### Configuration Model Enhancements

```csharp
public class PluginConfiguration : BasePluginConfiguration
{
    // Existing
    public bool EnableUpscaling { get; set; } = false;
    public bool EnableTranscoding { get; set; } = false;
    public string GpuDevice { get; set; } = "0";
    public string UpscaleFactor { get; set; } = "2";
    public bool EnableHlsStreaming { get; set; } = true;
    public string WatchdogUrl { get; set; } = "http://localhost:5000";
    public string HlsServerHost { get; set; } = "localhost";
    public string HlsServerPort { get; set; } = "8080";
    public int HlsDelaySeconds { get; set; } = 15;
    public bool AutoSwitchToHls { get; set; } = false;
    
    // Proposed additions
    public string LogLevel { get; set; } = "Info"; // Debug, Info, Warning, Error
    public int MaxConcurrentJobs { get; set; } = 1;
    public bool EnableNotifications { get; set; } = true;
    public string OutputDirectory { get; set; } = "/data/upscaled";
    public int ConfigVersion { get; set; } = 1; // For migration
}
```

### API Endpoints (Current)

All endpoints under `/Plugins/RealTimeHDRSRGAN`:

| Method | Endpoint | Purpose | Status |
|--------|----------|---------|--------|
| POST | `/DetectGPU` | Detect available NVIDIA GPUs | ✅ Implemented |
| POST | `/CreateBackup` | Backup Jellyfin config | ✅ Implemented |
| POST | `/RestoreBackup` | Restore from backup | ✅ Implemented |
| GET | `/ListBackups` | List available backups | ✅ Implemented |
| GET | `/Configuration` | Get current config | ✅ Implemented |
| POST | `/Configuration` | Save configuration | ✅ Implemented |
| POST | `/CheckHlsStatus` | Check HLS stream availability | ✅ Implemented |
| POST | `/TriggerUpscale` | Manually trigger upscaling | ✅ Implemented |
| GET | `/GetHlsUrl` | Get HLS stream URL | ✅ Implemented |

### Proposed API Additions

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/Status` | Get plugin health and statistics |
| GET | `/Jobs` | List current/recent upscaling jobs |
| POST | `/Jobs/{id}/Cancel` | Cancel a specific job |
| GET | `/Logs` | Get recent plugin logs |
| POST | `/TestConnection` | Test watchdog connectivity |

### External API Dependencies

**Watchdog API** (Python Flask - Port 5000):
- `POST /upscale-trigger`: Queue upscaling job
- `GET /hls-status/{filename}`: Check HLS availability
- `GET /health`: Health check

**HLS Server** (nginx - Port 8080):
- `GET /hls/{filename}/stream.m3u8`: HLS playlist
- `GET /hls/{filename}/segment_*.ts`: HLS segments

## 6. Verification Approach

### 6.1 Build Verification

**Plugin Build**
```bash
cd jellyfin-plugin/Server
dotnet build -c Release
# Expected: 0 errors, 0 warnings
# Output: bin/Release/net9.0/Jellyfin.Plugin.RealTimeHdrSrgan.dll
```

**Container Build**
```bash
docker compose build srgan-upscaler
# Expected: Successful build
# Verify: docker images | grep srgan
```

### 6.2 Unit Testing

**C# Plugin Tests** (to be created)
```bash
cd jellyfin-plugin/Server.Tests
dotnet test
```

Test coverage:
- Configuration validation
- API endpoint responses
- Error handling paths
- Script execution mocking

### 6.3 Integration Testing

**Test Sequence**:

1. **Plugin Installation**
   ```bash
   # Copy plugin to Jellyfin
   cp -r jellyfin-plugin/Server/bin/Release/net9.0/* \
      /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/
   
   # Restart Jellyfin
   sudo systemctl restart jellyfin
   
   # Verify plugin loaded
   curl http://localhost:8096/Plugins | jq '.[] | select(.Name == "Real-Time HDR SRGAN Pipeline")'
   ```

2. **API Endpoint Testing**
   ```bash
   # Test GPU detection
   curl -X POST http://localhost:8096/Plugins/RealTimeHDRSRGAN/DetectGPU
   
   # Test configuration
   curl http://localhost:8096/Plugins/RealTimeHDRSRGAN/Configuration
   
   # Test health
   curl http://localhost:5000/health
   ```

3. **Webhook Integration Test**
   ```bash
   # Use existing test script
   python3 scripts/test_webhook.py --test-file /path/to/video.mkv
   ```

4. **HLS Streaming Test**
   ```bash
   # Use existing test script
   ./scripts/test_hls_streaming.sh
   ```

5. **End-to-End Test**
   - Play a video in Jellyfin
   - Verify webhook triggers watchdog
   - Verify job queued and processed
   - Verify HLS stream becomes available
   - Verify final file created

### 6.4 Linting and Code Quality

**C# Linting**
```bash
cd jellyfin-plugin/Server
dotnet format --verify-no-changes
# Or if project uses jellyfin.ruleset (from webhook plugin)
dotnet build /p:EnforceCodeStyleInBuild=true
```

**Python Linting** (existing scripts)
```bash
cd scripts
# Check if ruff or pylint is configured
ruff check . || pylint *.py
```

### 6.5 Manual Verification Checklist

- [ ] Plugin appears in Jellyfin Dashboard → Plugins
- [ ] Configuration page loads without errors
- [ ] GPU detection works and displays results
- [ ] Configuration saves and persists across restarts
- [ ] Backup/restore functions work
- [ ] Webhook triggers upscaling jobs
- [ ] HLS streaming works (if enabled)
- [ ] Progress overlay displays correctly
- [ ] Logs show expected output
- [ ] No errors in Jellyfin logs

## 7. Dependencies and Prerequisites

### Runtime Dependencies

**Plugin Runtime**:
- Jellyfin Server 10.8.0+
- .NET 9.0 Runtime (ASP.NET Core)
- Bash (for helper scripts)

**Processing Pipeline**:
- Docker Engine 20.10+
- NVIDIA Container Toolkit
- NVIDIA GPU with CUDA support
- NVIDIA drivers 525.x+

**Python Watchdog**:
- Python 3.8+
- Flask 3.0.3+
- requests 2.32.3+

### Build Dependencies

**Plugin Build**:
- .NET 9.0 SDK
- Jellyfin libraries (MediaBrowser.Common, MediaBrowser.Model)
  - Usually located in `/usr/lib/jellyfin/bin/` or configured via `JellyfinLibDir`

**Container Build**:
- Docker Compose v2
- Internet connection (for base image pull)

### Development Dependencies

- Git (for version control)
- Text editor / IDE with C# support
- Optional: JPRM (Jellyfin Plugin Repository Manager)

## 8. Risks and Considerations

### Technical Risks

1. **Jellyfin Library Compatibility**
   - Risk: MediaBrowser libraries may change between Jellyfin versions
   - Mitigation: Pin to specific Jellyfin version, test on multiple versions

2. **GPU Availability**
   - Risk: Plugin assumes NVIDIA GPU is available
   - Mitigation: Graceful degradation, clear error messages

3. **Path Mapping Complexity**
   - Risk: File paths differ between Jellyfin container and host
   - Mitigation: Configuration options for path translation, clear documentation

4. **Webhook Plugin Dependency**
   - Risk: Requires patched webhook plugin for `Path` variable
   - Mitigation: Include patched plugin or contribute upstream

### Operational Risks

1. **Performance Impact**
   - Risk: Upscaling is resource-intensive
   - Mitigation: Queue management, configuration limits

2. **Storage Requirements**
   - Risk: Upscaled files require significant disk space
   - Mitigation: Cleanup scripts, configuration options

3. **Network Requirements**
   - Risk: HLS streaming requires good network bandwidth
   - Mitigation: Configurable quality settings, local network recommendation

## 9. Open Questions

Please provide guidance on the following:

1. **Project Scope**: Which option (A/B/C/D from section 2) should be prioritized?

2. **Distribution Method**: Should the plugin be:
   - Packaged for official Jellyfin repository?
   - Distributed as standalone release (GitHub releases)?
   - Both?

3. **Testing Environment**: Is there access to:
   - A Jellyfin test instance?
   - NVIDIA GPU hardware for testing?
   - Sample video files for testing?

4. **Version Strategy**: What should the initial release version be?
   - 1.0.0 (stable release)?
   - 0.9.0 (beta)?
   - Match another component's version?

5. **Webhook Plugin**: Should the patched webhook plugin be:
   - Included in this repository?
   - Maintained separately?
   - Contributed back to official Jellyfin webhook plugin?

6. **Documentation**: What level of documentation is needed?
   - Basic README?
   - Full user guide?
   - Developer documentation?
   - Video tutorials?

## 10. Success Criteria

The implementation will be considered successful when:

1. **Build Success**
   - Plugin builds without errors
   - All dependencies resolve correctly
   - Package is created successfully

2. **Installation Success**
   - Plugin installs via Jellyfin plugin manager or manual installation
   - Configuration page accessible and functional
   - No errors in Jellyfin logs on startup

3. **Functional Success**
   - GPU detection works correctly
   - Configuration saves and loads
   - Backup/restore functions work
   - API endpoints respond correctly
   - Integration with watchdog works

4. **Quality Success**
   - Code passes linting
   - No compiler warnings
   - Logs are informative and appropriate level
   - Error messages are user-friendly

5. **Documentation Success**
   - Installation instructions are clear
   - Configuration options are documented
   - Troubleshooting guide covers common issues
   - Code is reasonably commented
