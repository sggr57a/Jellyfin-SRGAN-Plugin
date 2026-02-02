using MediaBrowser.Model.Plugins;

namespace Jellyfin.Plugin.RealTimeHdrSrgan;

public class PluginConfiguration : BasePluginConfiguration
{
    public bool EnableUpscaling { get; set; } = false;
    public bool EnableTranscoding { get; set; } = false;
    public string GpuDevice { get; set; } = "0";
    public string UpscaleFactor { get; set; } = "2";

    // HLS Streaming Configuration
    public bool EnableHlsStreaming { get; set; } = true;
    public string WatchdogUrl { get; set; } = "http://localhost:5000";
    public string HlsServerHost { get; set; } = "localhost";
    public string HlsServerPort { get; set; } = "8080";
    public int HlsDelaySeconds { get; set; } = 15;
    public bool AutoSwitchToHls { get; set; } = false;
}
