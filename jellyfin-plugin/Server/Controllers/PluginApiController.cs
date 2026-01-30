using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;

namespace Jellyfin.Plugin.RealTimeHdrSrgan.Controllers;

[ApiController]
[Route("Plugins/RealTimeHDRSRGAN")]
public class PluginApiController : ControllerBase
{
    private readonly string _pluginDir;

    public PluginApiController()
    {
        var assemblyPath = Plugin.Instance?.AssemblyFilePath;
        _pluginDir = assemblyPath != null ? Path.GetDirectoryName(assemblyPath)! : AppContext.BaseDirectory;
    }

    [HttpPost("DetectGPU")]
    public IActionResult DetectGpu()
    {
        var scriptPath = Path.Combine(_pluginDir, "gpu-detection.sh");
        var (exitCode, output, error) = RunScript(scriptPath);
        var available = exitCode == 0 && output.Contains("SUCCESS", StringComparison.OrdinalIgnoreCase);

        return Ok(new
        {
            available,
            output,
            error,
            gpus = Array.Empty<object>()
        });
    }

    [HttpPost("CreateBackup")]
    public IActionResult CreateBackup()
    {
        var scriptPath = Path.Combine(_pluginDir, "backup-config.sh");
        var (exitCode, output, error) = RunScript(scriptPath);
        if (exitCode != 0)
        {
            return Ok(new { success = false, error });
        }

        var backupPath = ExtractBackupPath(output);
        return Ok(new { success = true, backupPath, output });
    }

    [HttpPost("RestoreBackup")]
    public IActionResult RestoreBackup([FromBody] RestoreRequest request)
    {
        var scriptPath = Path.Combine(_pluginDir, "restore-config.sh");
        var args = string.IsNullOrWhiteSpace(request.BackupPath) ? string.Empty : request.BackupPath;
        var (exitCode, output, error) = RunScript(scriptPath, args);
        if (exitCode != 0)
        {
            return Ok(new { success = false, error });
        }

        return Ok(new { success = true, output });
    }

    [HttpGet("ListBackups")]
    public IActionResult ListBackups()
    {
        var backupDirs = GetBackupDirectories();
        var backups = new List<object>();

        foreach (var dir in backupDirs.Where(Directory.Exists))
        {
            foreach (var path in Directory.GetDirectories(dir, "jellyfin_backup_*"))
            {
                var name = Path.GetFileName(path);
                var date = ParseBackupDate(name);
                backups.Add(new { name, path, date });
            }
        }

        return Ok(new { backups });
    }

    [HttpGet("Configuration")]
    public IActionResult GetConfiguration()
    {
        var config = Plugin.Instance?.Configuration;
        if (config == null)
        {
            return Ok(new PluginConfiguration());
        }

        return Ok(new
        {
            enableUpscaling = config.EnableUpscaling,
            enableTranscoding = config.EnableTranscoding,
            gpuDevice = config.GpuDevice,
            upscaleFactor = config.UpscaleFactor
        });
    }

    [HttpPost("Configuration")]
    public IActionResult SaveConfiguration([FromBody] PluginConfiguration request)
    {
        var plugin = Plugin.Instance;
        if (plugin == null)
        {
            return Ok(new { success = false, error = "Plugin not initialized." });
        }

        var allowedUpscale = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "2", "4" };
        if (!allowedUpscale.Contains(request.UpscaleFactor ?? string.Empty))
        {
            return Ok(new { success = false, error = "Upscale factor must be 2 or 4." });
        }

        plugin.Configuration.EnableUpscaling = request.EnableUpscaling;
        plugin.Configuration.EnableTranscoding = request.EnableTranscoding;
        plugin.Configuration.GpuDevice = string.IsNullOrWhiteSpace(request.GpuDevice) ? "0" : request.GpuDevice;
        plugin.Configuration.UpscaleFactor = request.UpscaleFactor ?? "2";
        plugin.SaveConfiguration();

        return Ok(new { success = true });
    }

    [HttpPost("CheckHlsStatus")]
    public async Task<IActionResult> CheckHlsStatus([FromBody] HlsStatusRequest request)
    {
        var watchdogUrl = Plugin.Instance?.Configuration?.WatchdogUrl ?? "http://localhost:5000";
        var filename = Path.GetFileName(request.FilePath ?? string.Empty);
        
        if (string.IsNullOrEmpty(filename))
        {
            return Ok(new { success = false, error = "Invalid file path" });
        }

        try
        {
            using var client = new HttpClient();
            client.Timeout = TimeSpan.FromSeconds(5);
            
            var url = $"{watchdogUrl}/hls-status/{filename}";
            var response = await client.GetAsync(url);
            var content = await response.Content.ReadAsStringAsync();
            
            return Ok(new 
            { 
                success = true, 
                status = response.IsSuccessStatusCode ? "available" : "not_found",
                data = JsonSerializer.Deserialize<JsonElement>(content)
            });
        }
        catch (Exception ex)
        {
            return Ok(new { success = false, error = ex.Message });
        }
    }

    [HttpPost("TriggerUpscale")]
    public async Task<IActionResult> TriggerUpscale([FromBody] UpscaleRequest request)
    {
        var watchdogUrl = Plugin.Instance?.Configuration?.WatchdogUrl ?? "http://localhost:5000";
        
        if (string.IsNullOrEmpty(request.FilePath))
        {
            return Ok(new { success = false, error = "File path is required" });
        }

        try
        {
            using var client = new HttpClient();
            client.Timeout = TimeSpan.FromSeconds(10);
            
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
            var response = await client.PostAsync(url, httpContent);
            var content = await response.Content.ReadAsStringAsync();
            
            var result = JsonSerializer.Deserialize<JsonElement>(content);
            
            return Ok(new 
            { 
                success = response.IsSuccessStatusCode,
                data = result
            });
        }
        catch (Exception ex)
        {
            return Ok(new { success = false, error = ex.Message });
        }
    }

    [HttpGet("GetHlsUrl")]
    public IActionResult GetHlsUrl([FromQuery] string filePath)
    {
        if (string.IsNullOrEmpty(filePath))
        {
            return Ok(new { success = false, error = "File path is required" });
        }

        var filename = Path.GetFileNameWithoutExtension(filePath);
        var hlsServerHost = Plugin.Instance?.Configuration?.HlsServerHost ?? "localhost";
        var hlsServerPort = Plugin.Instance?.Configuration?.HlsServerPort ?? "8080";
        var hlsUrl = $"http://{hlsServerHost}:{hlsServerPort}/hls/{filename}/stream.m3u8";
        
        return Ok(new 
        { 
            success = true,
            hlsUrl = hlsUrl,
            filename = filename
        });
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
