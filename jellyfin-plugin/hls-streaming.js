/**
 * Jellyfin HLS Streaming Integration
 * 
 * Automatically switches to upscaled HLS stream when available.
 * This script should be injected into Jellyfin's web interface.
 */

(function() {
    'use strict';
    
    const CONFIG = {
        watchdogUrl: 'http://localhost:5000',
        hlsServerUrl: 'http://localhost:8080',
        checkInterval: 2000, // Check every 2 seconds
        maxRetries: 30, // Maximum 60 seconds (30 * 2s)
        autoSwitch: false // Set to true to automatically switch streams
    };
    
    let currentMediaPath = null;
    let hlsCheckInterval = null;
    let retryCount = 0;
    
    /**
     * Check if HLS stream is available for the current media
     */
    async function checkHlsStatus(mediaPath) {
        const filename = mediaPath.split('/').pop();
        const basename = filename.replace(/\.[^/.]+$/, ''); // Remove extension
        
        try {
            const response = await fetch(`${CONFIG.watchdogUrl}/hls-status/${filename}`);
            const data = await response.json();
            
            return {
                available: response.ok,
                status: data.status,
                hlsUrl: data.hls_url,
                segments: data.segments || 0,
                complete: data.complete || false
            };
        } catch (error) {
            console.log('[HLS] Status check failed:', error.message);
            return { available: false, status: 'error' };
        }
    }
    
    /**
     * Trigger upscaling for a media file
     */
    async function triggerUpscale(mediaPath) {
        try {
            const response = await fetch(`${CONFIG.watchdogUrl}/upscale-trigger`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    Item: {
                        Path: mediaPath,
                        Name: mediaPath.split('/').pop().replace(/\.[^/.]+$/, '')
                    }
                })
            });
            
            const data = await response.json();
            console.log('[HLS] Upscale triggered:', data);
            
            return {
                success: response.ok,
                data: data
            };
        } catch (error) {
            console.error('[HLS] Failed to trigger upscale:', error);
            return { success: false, error: error.message };
        }
    }
    
    /**
     * Show notification to user
     */
    function showNotification(message, type = 'info') {
        // Try to use Jellyfin's notification system if available
        if (window.Dashboard && window.Dashboard.alert) {
            window.Dashboard.alert(message);
        } else if (window.Notification && Notification.permission === 'granted') {
            new Notification('HLS Streaming', { body: message });
        } else {
            console.log(`[HLS] ${type.toUpperCase()}: ${message}`);
        }
    }
    
    /**
     * Switch to HLS stream
     */
    function switchToHlsStream(hlsUrl) {
        console.log('[HLS] Switching to HLS stream:', hlsUrl);
        
        // Find the video element
        const videoElement = document.querySelector('video');
        
        if (!videoElement) {
            console.error('[HLS] Video element not found');
            return false;
        }
        
        const currentTime = videoElement.currentTime;
        const wasPlaying = !videoElement.paused;
        
        // Check if HLS.js is available
        if (window.Hls && Hls.isSupported()) {
            const hls = new Hls();
            hls.loadSource(hlsUrl);
            hls.attachMedia(videoElement);
            
            hls.on(Hls.Events.MANIFEST_PARSED, function() {
                console.log('[HLS] Manifest loaded, seeking to', currentTime);
                videoElement.currentTime = currentTime;
                if (wasPlaying) {
                    videoElement.play();
                }
            });
            
            showNotification('Switched to 4K upscaled stream!', 'success');
            return true;
        } 
        // Native HLS support (Safari, etc)
        else if (videoElement.canPlayType('application/vnd.apple.mpegurl')) {
            videoElement.src = hlsUrl;
            videoElement.addEventListener('loadedmetadata', function() {
                videoElement.currentTime = currentTime;
                if (wasPlaying) {
                    videoElement.play();
                }
            });
            
            showNotification('Switched to 4K upscaled stream!', 'success');
            return true;
        } else {
            console.error('[HLS] HLS playback not supported');
            showNotification('HLS playback not supported in this browser', 'error');
            return false;
        }
    }
    
    /**
     * Monitor for HLS stream availability
     */
    async function monitorHlsStream(mediaPath) {
        console.log('[HLS] Monitoring for stream:', mediaPath);
        
        const status = await checkHlsStatus(mediaPath);
        
        if (status.available) {
            if (status.status === 'ready') {
                // Final file is ready, use that instead
                console.log('[HLS] Final upscaled file is ready');
                clearInterval(hlsCheckInterval);
                showNotification('Upscaled version is ready for next playback', 'info');
                return;
            }
            
            if (status.status === 'streaming' && status.segments > 0) {
                console.log('[HLS] Stream available with', status.segments, 'segments');
                
                if (CONFIG.autoSwitch) {
                    clearInterval(hlsCheckInterval);
                    switchToHlsStream(status.hlsUrl);
                } else {
                    clearInterval(hlsCheckInterval);
                    
                    // Show option to switch
                    const shouldSwitch = confirm(
                        '4K upscaled stream is now available!\n\n' +
                        'Would you like to switch to the upscaled version?\n' +
                        '(Your current position will be preserved)'
                    );
                    
                    if (shouldSwitch) {
                        switchToHlsStream(status.hlsUrl);
                    }
                }
                return;
            }
        }
        
        retryCount++;
        
        if (retryCount >= CONFIG.maxRetries) {
            console.log('[HLS] Max retries reached, stopping monitor');
            clearInterval(hlsCheckInterval);
            showNotification('Upscaled stream not available, continuing with original', 'info');
        }
    }
    
    /**
     * Handle playback start event
     */
    async function onPlaybackStart(mediaPath) {
        console.log('[HLS] Playback started:', mediaPath);
        currentMediaPath = mediaPath;
        retryCount = 0;
        
        // Clear any existing interval
        if (hlsCheckInterval) {
            clearInterval(hlsCheckInterval);
        }
        
        // Check if upscaled version already exists
        const initialStatus = await checkHlsStatus(mediaPath);
        
        if (initialStatus.available && initialStatus.status === 'ready') {
            console.log('[HLS] Upscaled version already exists');
            return;
        }
        
        // Trigger upscaling
        const result = await triggerUpscale(mediaPath);
        
        if (!result.success) {
            console.error('[HLS] Failed to trigger upscale');
            return;
        }
        
        if (result.data.status === 'ready') {
            console.log('[HLS] Using existing upscaled file');
            return;
        }
        
        showNotification('Starting 4K upscaling... Stream will be available in ~15 seconds', 'info');
        
        // Start monitoring for HLS stream
        hlsCheckInterval = setInterval(() => {
            monitorHlsStream(mediaPath);
        }, CONFIG.checkInterval);
    }
    
    /**
     * Handle playback stop event
     */
    function onPlaybackStop() {
        console.log('[HLS] Playback stopped');
        
        if (hlsCheckInterval) {
            clearInterval(hlsCheckInterval);
            hlsCheckInterval = null;
        }
        
        currentMediaPath = null;
        retryCount = 0;
    }
    
    /**
     * Initialize the HLS integration
     */
    function initialize() {
        console.log('[HLS] Initializing HLS streaming integration');
        
        // Hook into Jellyfin's playback events
        if (window.PlaybackManager) {
            const originalPlayMethod = window.PlaybackManager.play;
            
            window.PlaybackManager.play = function(...args) {
                const result = originalPlayMethod.apply(this, args);
                
                // Extract media path from playback info
                if (args[0] && args[0].items && args[0].items[0]) {
                    const item = args[0].items[0];
                    if (item.Path) {
                        setTimeout(() => onPlaybackStart(item.Path), 1000);
                    }
                }
                
                return result;
            };
            
            const originalStopMethod = window.PlaybackManager.stop;
            
            window.PlaybackManager.stop = function(...args) {
                onPlaybackStop();
                return originalStopMethod.apply(this, args);
            };
            
            console.log('[HLS] Hooked into PlaybackManager');
        }
        
        // Alternative: Monitor video elements
        const observer = new MutationObserver(() => {
            const videoElement = document.querySelector('video');
            
            if (videoElement && !videoElement.dataset.hlsMonitored) {
                videoElement.dataset.hlsMonitored = 'true';
                
                videoElement.addEventListener('play', () => {
                    const src = videoElement.src || videoElement.currentSrc;
                    if (src && !src.includes('.m3u8')) {
                        // Extract path if possible
                        console.log('[HLS] Video playing:', src);
                    }
                });
                
                videoElement.addEventListener('ended', onPlaybackStop);
                videoElement.addEventListener('pause', () => {
                    if (videoElement.ended) {
                        onPlaybackStop();
                    }
                });
            }
        });
        
        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
        
        console.log('[HLS] Video element monitor started');
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }
    
    // Export for manual control
    window.JellyfinHLS = {
        checkStatus: checkHlsStatus,
        triggerUpscale: triggerUpscale,
        switchStream: switchToHlsStream,
        config: CONFIG
    };
    
    console.log('[HLS] HLS Streaming integration loaded');
    console.log('[HLS] Manual controls available via window.JellyfinHLS');
})();
