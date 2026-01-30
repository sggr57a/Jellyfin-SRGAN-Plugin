using System;
using System.Collections.Generic;
using MediaBrowser.Common.Configuration;
using MediaBrowser.Common.Plugins;
using MediaBrowser.Model.Plugins;
using MediaBrowser.Model.Serialization;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.RealTimeHdrSrgan;

public class Plugin : BasePlugin<PluginConfiguration>, IHasWebPages
{
    private readonly ILogger<Plugin> _logger;

    public Plugin(IApplicationPaths applicationPaths, IXmlSerializer xmlSerializer, ILogger<Plugin> logger)
        : base(applicationPaths, xmlSerializer)
    {
        Instance = this;
        _logger = logger;
        
        _logger.LogInformation("Real-Time HDR SRGAN Plugin v{Version} initialized", Version?.ToString() ?? "Unknown");
        
        ValidateConfiguration();
    }

    public static Plugin? Instance { get; private set; }

    public override string Name => "Real-Time HDR SRGAN Pipeline";

    public override Guid Id => new Guid("a1b2c3d4-e5f6-7890-abcd-ef1234567890");
    
    public override string Description => "Real-time HDR upscaling and SRGAN processing pipeline for Jellyfin with HLS streaming support";

    private void ValidateConfiguration()
    {
        try
        {
            var config = Configuration;
            
            if (string.IsNullOrWhiteSpace(config.WatchdogUrl))
            {
                _logger.LogWarning("Watchdog URL is not configured, using default: http://localhost:5000");
                config.WatchdogUrl = "http://localhost:5000";
            }
            
            if (config.UpscaleFactor != "2" && config.UpscaleFactor != "4")
            {
                _logger.LogWarning("Invalid upscale factor '{Factor}', defaulting to 2", config.UpscaleFactor);
                config.UpscaleFactor = "2";
            }
            
            if (config.HlsDelaySeconds < 0 || config.HlsDelaySeconds > 300)
            {
                _logger.LogWarning("HLS delay {Delay} seconds is out of range (0-300), defaulting to 15", config.HlsDelaySeconds);
                config.HlsDelaySeconds = 15;
            }
            
            if (config.MaxConcurrentJobs < 1 || config.MaxConcurrentJobs > 10)
            {
                _logger.LogWarning("Max concurrent jobs {Jobs} is out of range (1-10), defaulting to 1", config.MaxConcurrentJobs);
                config.MaxConcurrentJobs = 1;
            }
            
            _logger.LogDebug("Configuration validated successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to validate configuration");
        }
    }

    public IEnumerable<PluginPageInfo> GetPages()
    {
        var basePath = GetType().Namespace ?? string.Empty;
        return new[]
        {
            new PluginPageInfo
            {
                Name = "ConfigurationPage",
                EmbeddedResourcePath = $"{basePath}.ConfigurationPage.html"
            },
            new PluginPageInfo
            {
                Name = "ConfigurationPage.js",
                EmbeddedResourcePath = $"{basePath}.ConfigurationPage.js"
            }
        };
    }
}
