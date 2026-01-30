using System.ComponentModel.DataAnnotations;
using MediaBrowser.Model.Plugins;

namespace Jellyfin.Plugin.RealTimeHdrSrgan;

public class PluginConfiguration : BasePluginConfiguration
{
    public bool EnableUpscaling { get; set; } = false;
    
    public bool EnableTranscoding { get; set; } = false;
    
    [Range(0, 99)]
    public string GpuDevice { get; set; } = "0";
    
    [RegularExpression("^(2|4)$")]
    public string UpscaleFactor { get; set; } = "2";
    
    public bool EnableHlsStreaming { get; set; } = true;
    
    [Url]
    public string WatchdogUrl { get; set; } = "http://localhost:5000";
    
    public string HlsServerHost { get; set; } = "localhost";
    
    [Range(1, 65535)]
    public string HlsServerPort { get; set; } = "8080";
    
    [Range(0, 300)]
    public int HlsDelaySeconds { get; set; } = 15;
    
    public bool AutoSwitchToHls { get; set; } = false;
    
    [RegularExpression("^(Debug|Info|Warning|Error)$")]
    public string LogLevel { get; set; } = "Info";
    
    [Range(1, 10)]
    public int MaxConcurrentJobs { get; set; } = 1;
    
    public bool EnableNotifications { get; set; } = true;
    
    public string OutputDirectory { get; set; } = "/data/upscaled";
    
    public int ConfigVersion { get; set; } = 1;
}
