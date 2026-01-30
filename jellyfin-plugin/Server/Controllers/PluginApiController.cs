using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.RealTimeHdrSrgan.Controllers;

[ApiController]
[Route("Plugins/RealTimeHDRSRGAN")]
public class PluginApiController : ControllerBase
{
    private readonly string _pluginDir;
    private readonly ILogger<PluginApiController> _logger;
    private static readonly HttpClient _httpClient = new HttpClient();

    public PluginApiController(ILogger<PluginApiController> logger)
    {
        _logger = logger;
        var assemblyPath = Plugin.Instance?.AssemblyFilePath;
        _pluginDir = assemblyPath != null ? Path.GetDirectoryName(assemblyPath)! : AppContext.BaseDirectory;
        
        _logger.LogDebug("PluginApiController initialized with plugin directory: {PluginDir}", _pluginDir);
    }

    [HttpPost("DetectGPU")]
    public IActionResult DetectGpu()
    {
        try
        {
            _logger.LogInformation("GPU detection requested");
            
            var scriptPath = Path.Combine(_pluginDir, "gpu-detection.sh");
            
            if (!System.IO.File.Exists(scriptPath))
            {
                _logger.LogError("GPU detection script not found at: {ScriptPath}", scriptPath);
                return Ok(new { available = false, error = $"Script not found: {scriptPath}" });
            }
            
            var (exitCode, output, error) = RunScript(scriptPath);
            var available = exitCode == 0 && output.Contains("SUCCESS", StringComparison.OrdinalIgnoreCase);

            _logger.LogInformation("GPU detection completed. Available: {Available}, ExitCode: {ExitCode}", available, exitCode);
            
            if (!string.IsNullOrWhiteSpace(error))
            {
                _logger.LogWarning("GPU detection stderr: {Error}", error);
            }

            return Ok(new
            {
                available,
                output,
                error,
                gpus = Array.Empty<object>()
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during GPU detection");
            return Ok(new { available = false, error = ex.Message });
        }
    }

    [HttpPost("CreateBackup")]
    public IActionResult CreateBackup()
    {
        try
        {
            _logger.LogInformation("Backup creation requested");
            
            var scriptPath = Path.Combine(_pluginDir, "backup-config.sh");
            
            if (!System.IO.File.Exists(scriptPath))
            {
                _logger.LogError("Backup script not found at: {ScriptPath}", scriptPath);
                return Ok(new { success = false, error = $"Script not found: {scriptPath}" });
            }
            
            var (exitCode, output, error) = RunScript(scriptPath);
            
            if (exitCode != 0)
            {
                _logger.LogError("Backup creation failed with exit code {ExitCode}: {Error}", exitCode, error);
                return Ok(new { success = false, error });
            }

            var backupPath = ExtractBackupPath(output);
            _logger.LogInformation("Backup created successfully at: {BackupPath}", backupPath);
            
            return Ok(new { success = true, backupPath, output });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during backup creation");
            return Ok(new { success = false, error = ex.Message });
        }
    }

    [HttpPost("RestoreBackup")]
    public IActionResult RestoreBackup([FromBody] RestoreRequest request)
    {
        try
        {
            _logger.LogInformation("Backup restore requested for: {BackupPath}", request.BackupPath);
            
            var scriptPath = Path.Combine(_pluginDir, "restore-config.sh");
            
            if (!System.IO.File.Exists(scriptPath))
            {
                _logger.LogError("Restore script not found at: {ScriptPath}", scriptPath);
                return Ok(new { success = false, error = $"Script not found: {scriptPath}" });
            }
            
            var args = string.IsNullOrWhiteSpace(request.BackupPath) ? string.Empty : request.BackupPath;
            var (exitCode, output, error) = RunScript(scriptPath, args);
            
            if (exitCode != 0)
            {
                _logger.LogError("Backup restore failed with exit code {ExitCode}: {Error}", exitCode, error);
                return Ok(new { success = false, error });
            }

            _logger.LogInformation("Backup restored successfully");
            return Ok(new { success = true, output });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during backup restoration");
            return Ok(new { success = false, error = ex.Message });
        }
    }

    [HttpGet("ListBackups")]
    public IActionResult ListBackups()
    {
        try
        {
            _logger.LogDebug("Listing backups");
            
            var backupDirs = GetBackupDirectories();
            var backups = new List<object>();

            foreach (var dir in backupDirs.Where(Directory.Exists))
            {
                try
                {
                    foreach (var path in Directory.GetDirectories(dir, "jellyfin_backup_*"))
                    {
                        var name = Path.GetFileName(path);
                        var date = ParseBackupDate(name);
                        backups.Add(new { name, path, date });
                    }
                }
                catch (UnauthorizedAccessException uae)
                {
                    _logger.LogWarning(uae, "Unauthorized access to backup directory: {Dir}", dir);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error reading backup directory: {Dir}", dir);
                }
            }

            _logger.LogInformation("Found {Count} backups", backups.Count);
            return Ok(new { backups });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing backups");
            return Ok(new { backups = Array.Empty<object>(), error = ex.Message });
        }
    }

    [HttpGet("Configuration")]
    public IActionResult GetConfiguration()
    {
        try
        {
            _logger.LogDebug("Configuration requested");
            
            var config = Plugin.Instance?.Configuration;
            if (config == null)
            {
                _logger.LogWarning("Plugin configuration is null, returning defaults");
                return Ok(new PluginConfiguration());
            }

            return Ok(new
            {
                enableUpscaling = config.EnableUpscaling,
                enableTranscoding = config.EnableTranscoding,
                gpuDevice = config.GpuDevice,
                upscaleFactor = config.UpscaleFactor,
                enableHlsStreaming = config.EnableHlsStreaming,
                watchdogUrl = config.WatchdogUrl,
                hlsServerHost = config.HlsServerHost,
                hlsServerPort = config.HlsServerPort,
                hlsDelaySeconds = config.HlsDelaySeconds,
                autoSwitchToHls = config.AutoSwitchToHls,
                logLevel = config.LogLevel,
                maxConcurrentJobs = config.MaxConcurrentJobs,
                enableNotifications = config.EnableNotifications,
                outputDirectory = config.OutputDirectory,
                configVersion = config.ConfigVersion
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving configuration");
            return Ok(new PluginConfiguration());
        }
    }

    [HttpPost("Configuration")]
    public IActionResult SaveConfiguration([FromBody] PluginConfiguration request)
    {
        try
        {
            _logger.LogInformation("Configuration save requested");
            
            var plugin = Plugin.Instance;
            if (plugin == null)
            {
                _logger.LogError("Plugin instance is null");
                return Ok(new { success = false, error = "Plugin not initialized." });
            }

            var allowedUpscale = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "2", "4" };
            if (!allowedUpscale.Contains(request.UpscaleFactor ?? string.Empty))
            {
                _logger.LogWarning("Invalid upscale factor provided: {Factor}", request.UpscaleFactor);
                return Ok(new { success = false, error = "Upscale factor must be 2 or 4." });
            }

            plugin.Configuration.EnableUpscaling = request.EnableUpscaling;
            plugin.Configuration.EnableTranscoding = request.EnableTranscoding;
            plugin.Configuration.GpuDevice = string.IsNullOrWhiteSpace(request.GpuDevice) ? "0" : request.GpuDevice;
            plugin.Configuration.UpscaleFactor = request.UpscaleFactor ?? "2";
            plugin.Configuration.EnableHlsStreaming = request.EnableHlsStreaming;
            plugin.Configuration.WatchdogUrl = request.WatchdogUrl;
            plugin.Configuration.HlsServerHost = request.HlsServerHost;
            plugin.Configuration.HlsServerPort = request.HlsServerPort;
            plugin.Configuration.HlsDelaySeconds = request.HlsDelaySeconds;
            plugin.Configuration.AutoSwitchToHls = request.AutoSwitchToHls;
            plugin.Configuration.LogLevel = request.LogLevel;
            plugin.Configuration.MaxConcurrentJobs = request.MaxConcurrentJobs;
            plugin.Configuration.EnableNotifications = request.EnableNotifications;
            plugin.Configuration.OutputDirectory = request.OutputDirectory;
            plugin.Configuration.ConfigVersion = request.ConfigVersion;
            
            plugin.SaveConfiguration();
            
            _logger.LogInformation("Configuration saved successfully");
            return Ok(new { success = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving configuration");
            return Ok(new { success = false, error = ex.Message });
        }
    }

    [HttpPost("CheckHlsStatus")]
    public async Task<IActionResult> CheckHlsStatus([FromBody] HlsStatusRequest request, CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogDebug("HLS status check requested for: {FilePath}", request.FilePath);
            
            var watchdogUrl = Plugin.Instance?.Configuration?.WatchdogUrl ?? "http://localhost:5000";
            var filename = Path.GetFileName(request.FilePath ?? string.Empty);
            
            if (string.IsNullOrEmpty(filename))
            {
                _logger.LogWarning("Invalid file path provided for HLS status check");
                return Ok(new { success = false, error = "Invalid file path" });
            }

            _httpClient.Timeout = TimeSpan.FromSeconds(5);
            
            var url = $"{watchdogUrl}/hls-status/{filename}";
            _logger.LogDebug("Checking HLS status at: {Url}", url);
            
            var response = await _httpClient.GetAsync(url, cancellationToken);
            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            
            var status = response.IsSuccessStatusCode ? "available" : "not_found";
            _logger.LogInformation("HLS status for {Filename}: {Status}", filename, status);
            
            return Ok(new 
            { 
                success = true, 
                status,
                data = JsonSerializer.Deserialize<JsonElement>(content)
            });
        }
        catch (TaskCanceledException ex)
        {
            _logger.LogWarning(ex, "HLS status check timed out or was cancelled");
            return Ok(new { success = false, error = "Request timed out" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking HLS status");
            return Ok(new { success = false, error = ex.Message });
        }
    }

    [HttpPost("TriggerUpscale")]
    public async Task<IActionResult> TriggerUpscale([FromBody] UpscaleRequest request, CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Manual upscale trigger requested for: {FilePath}", request.FilePath);
            
            var watchdogUrl = Plugin.Instance?.Configuration?.WatchdogUrl ?? "http://localhost:5000";
            
            if (string.IsNullOrEmpty(request.FilePath))
            {
                _logger.LogWarning("Upscale trigger called with empty file path");
                return Ok(new { success = false, error = "File path is required" });
            }

            _httpClient.Timeout = TimeSpan.FromSeconds(10);
            
            var payload = new
            {
                Item = new
                {
                    Path = request.FilePath,
                    Name = Path.GetFileNameWithoutExtension(request.FilePath)
                }
            };
            
            var json = JsonSerializer.Serialize(payload);
            var httpContent = new StringContent(json, Encoding.UTF8, "application/json");
            
            var url = $"{watchdogUrl}/upscale-trigger";
            _logger.LogDebug("Sending upscale trigger to: {Url}", url);
            
            var response = await _httpClient.PostAsync(url, httpContent, cancellationToken);
            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            
            var result = JsonSerializer.Deserialize<JsonElement>(content);
            
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Upscale triggered successfully for: {FilePath}", request.FilePath);
            }
            else
            {
                _logger.LogWarning("Upscale trigger failed with status: {StatusCode}", response.StatusCode);
            }
            
            return Ok(new 
            { 
                success = response.IsSuccessStatusCode,
                data = result
            });
        }
        catch (TaskCanceledException ex)
        {
            _logger.LogWarning(ex, "Upscale trigger timed out or was cancelled");
            return Ok(new { success = false, error = "Request timed out" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error triggering upscale");
            return Ok(new { success = false, error = ex.Message });
        }
    }

    [HttpGet("GetHlsUrl")]
    public IActionResult GetHlsUrl([FromQuery] string filePath)
    {
        try
        {
            _logger.LogDebug("HLS URL requested for: {FilePath}", filePath);
            
            if (string.IsNullOrEmpty(filePath))
            {
                _logger.LogWarning("GetHlsUrl called with empty file path");
                return Ok(new { success = false, error = "File path is required" });
            }

            var filename = Path.GetFileNameWithoutExtension(filePath);
            var hlsServerHost = Plugin.Instance?.Configuration?.HlsServerHost ?? "localhost";
            var hlsServerPort = Plugin.Instance?.Configuration?.HlsServerPort ?? "8080";
            var hlsUrl = $"http://{hlsServerHost}:{hlsServerPort}/hls/{filename}/stream.m3u8";
            
            _logger.LogInformation("Generated HLS URL for {Filename}: {HlsUrl}", filename, hlsUrl);
            
            return Ok(new 
            { 
                success = true,
                hlsUrl = hlsUrl,
                filename = filename
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating HLS URL");
            return Ok(new { success = false, error = ex.Message });
        }
    }

    private static (int exitCode, string output, string error) RunScript(string scriptPath, string? args = null)
    {
        if (!System.IO.File.Exists(scriptPath))
        {
            return (1, string.Empty, $"Script not found: {scriptPath}");
        }

        var psi = new ProcessStartInfo
        {
            FileName = "bash",
            Arguments = string.IsNullOrWhiteSpace(args) ? $"\"{scriptPath}\"" : $"\"{scriptPath}\" \"{args}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false
        };

        using var process = Process.Start(psi);
        if (process == null)
        {
            return (1, string.Empty, "Failed to start script process.");
        }

        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();
        return (process.ExitCode, output, error);
    }

    private static string? ExtractBackupPath(string output)
    {
        const string marker = "Backup location:";
        foreach (var line in output.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            if (line.Contains(marker, StringComparison.OrdinalIgnoreCase))
            {
                return line.Split(marker, StringSplitOptions.RemoveEmptyEntries).Last().Trim();
            }
        }
        return null;
    }

    private static IEnumerable<string> GetBackupDirectories()
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        return new[]
        {
            Path.Combine(home, ".jellyfin", "backups"),
            "/config/backups",
            "/var/lib/jellyfin/backups"
        };
    }

    private static string ParseBackupDate(string name)
    {
        var parts = name.Split('_');
        if (parts.Length >= 3)
        {
            var timestamp = $"{parts[^2]}_{parts[^1]}";
            if (DateTime.TryParseExact(timestamp, "yyyyMMdd_HHmmss", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var dt))
            {
                return dt.ToString("yyyy-MM-dd HH:mm:ss");
            }
        }
        return string.Empty;
    }

    public sealed class RestoreRequest
    {
        public string? BackupPath { get; set; }
    }

    public sealed class HlsStatusRequest
    {
        public string? FilePath { get; set; }
    }

    public sealed class UpscaleRequest
    {
        public string? FilePath { get; set; }
    }
}
