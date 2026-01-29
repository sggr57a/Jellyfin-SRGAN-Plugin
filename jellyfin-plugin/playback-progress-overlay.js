/**
 * Jellyfin Upscaling Progress Overlay
 *
 * Displays real-time upscaling progress in the Jellyfin playback info overlay.
 * Shows progress bar, ETA, processing speed, and status messages.
 */

(function() {
    'use strict';

    const CONFIG = {
        watchdogUrl: 'http://localhost:5000',
        pollInterval: 2000,  // Check every 2 seconds
        showDelay: 1000,     // Show overlay after 1 second
        autoHide: true,      // Auto-hide when complete
        hideDelay: 10000,    // Hide after 10 seconds when complete
        showLoadingImmediately: true,  // Show "Loading..." immediately on playback
        centerLoadingIndicator: false  // Center loading indicator (true) or top-right (false)
    };

    let currentMediaPath = null;
    let progressInterval = null;
    let overlayElement = null;
    let lastProgress = 0;
    let isLoading = false;
    let videoIsPlaying = false;  // Track if video has actually started playing

    /**
     * Create the progress overlay UI
     */
    function createProgressOverlay() {
        if (overlayElement) {
            return overlayElement;
        }

        // Create container
        const container = document.createElement('div');
        container.id = 'upscaling-progress-overlay';
        container.className = 'upscaling-progress-container hidden';

        // Create HTML structure
        container.innerHTML = `
            <div class="upscaling-progress-content">
                <div class="upscaling-header">
                    <span class="upscaling-icon">🎬</span>
                    <span class="upscaling-title">4K Upscaling</span>
                    <button class="upscaling-close" title="Close">&times;</button>
                </div>
                <div class="upscaling-status">
                    <span class="status-text">Starting upscale process...</span>
                </div>
                <div class="upscaling-progress-bar-container">
                    <div class="upscaling-progress-bar">
                        <div class="upscaling-progress-fill"></div>
                    </div>
                    <span class="upscaling-progress-text">0%</span>
                </div>
                <div class="upscaling-details">
                    <div class="upscaling-detail-item">
                        <span class="detail-label">Processing Speed:</span>
                        <span class="detail-value" id="processing-speed">--</span>
                    </div>
                    <div class="upscaling-detail-item">
                        <span class="detail-label">ETA:</span>
                        <span class="detail-value" id="eta">--</span>
                    </div>
                    <div class="upscaling-detail-item">
                        <span class="detail-label">Segments:</span>
                        <span class="detail-value" id="segments">--</span>
                    </div>
                </div>
                <div class="upscaling-actions">
                    <button class="upscaling-btn upscaling-btn-switch hidden" id="switch-to-hls">
                        Switch to Upscaled Stream
                    </button>
                </div>
            </div>
        `;

        // Add close button handler
        const closeBtn = container.querySelector('.upscaling-close');
        closeBtn.addEventListener('click', () => {
            hideOverlay();
        });

        // Add switch button handler
        const switchBtn = container.querySelector('#switch-to-hls');
        switchBtn.addEventListener('click', () => {
            const hlsUrl = switchBtn.dataset.hlsUrl;
            if (hlsUrl && window.JellyfinHLS) {
                window.JellyfinHLS.switchStream(hlsUrl);
                showNotification('Switched to upscaled stream!');
                hideOverlay();
            }
        });

        document.body.appendChild(container);
        overlayElement = container;

        return container;
    }

    /**
     * Show the progress overlay
     */
    function showOverlay() {
        const overlay = createProgressOverlay();
        overlay.classList.remove('hidden');
        isLoading = false;  // Clear loading state when showing full overlay
    }

    /**
     * Show loading state immediately
     */
    function showLoadingState() {
        const overlay = createProgressOverlay();
        const content = overlay.querySelector('.upscaling-progress-content');

        // Set loading state
        isLoading = true;
        content.classList.add('loading-state');

        // Add centered class if configured
        if (CONFIG.centerLoadingIndicator) {
            overlay.classList.add('loading-state');
        }

        // Update to loading UI
        const statusText = overlay.querySelector('.status-text');
        statusText.textContent = 'Preparing 4K upscaling...';

        const progressFill = overlay.querySelector('.upscaling-progress-fill');
        const progressText = overlay.querySelector('.upscaling-progress-text');
        progressFill.style.width = '0%';
        progressText.textContent = '0%';

        // Hide details during loading
        const details = overlay.querySelector('.upscaling-details');
        const actions = overlay.querySelector('.upscaling-actions');
        details.style.display = 'none';
        actions.style.display = 'none';

        // Show immediately
        overlay.classList.remove('hidden');

        console.log('[Progress] Loading state shown (centered: ' + CONFIG.centerLoadingIndicator + ')');
    }

    /**
     * Clear loading state
     */
    function clearLoadingState() {
        if (!isLoading) return;

        const overlay = overlayElement;
        if (!overlay) return;

        const content = overlay.querySelector('.upscaling-progress-content');
        content.classList.remove('loading-state');

        // Remove centered class
        overlay.classList.remove('loading-state');

        // Show details
        const details = overlay.querySelector('.upscaling-details');
        const actions = overlay.querySelector('.upscaling-actions');
        details.style.display = '';
        actions.style.display = '';

        isLoading = false;
        console.log('[Progress] Loading state cleared');
    }

    /**
     * Hide the progress overlay
     */
    function hideOverlay() {
        if (overlayElement) {
            overlayElement.classList.add('hidden');
        }
    }

    /**
     * Update the progress overlay with new data
     */
    function updateProgress(data) {
        const overlay = createProgressOverlay();

        // Only clear loading state if video is actually playing
        // Keep showing "Loading..." until playback begins
        if (isLoading && videoIsPlaying) {
            clearLoadingState();
        }

        // Update progress bar
        const progressFill = overlay.querySelector('.upscaling-progress-fill');
        const progressText = overlay.querySelector('.upscaling-progress-text');
        const progress = data.progress || 0;

        progressFill.style.width = `${progress}%`;
        progressText.textContent = `${Math.round(progress)}%`;

        // Update status message
        const statusText = overlay.querySelector('.status-text');
        statusText.textContent = data.message || 'Processing...';

        // Update processing speed
        const speedElement = overlay.querySelector('#processing-speed');
        if (data.processing_rate) {
            const rate = data.processing_rate;
            const speedClass = rate >= 1.0 ? 'speed-good' : 'speed-slow';
            speedElement.textContent = `${rate.toFixed(2)}x`;
            speedElement.className = `detail-value ${speedClass}`;

            if (rate < 1.0) {
                speedElement.title = 'Processing slower than real-time';
            }
        } else {
            speedElement.textContent = '--';
        }

        // Update ETA
        const etaElement = overlay.querySelector('#eta');
        if (data.eta_seconds !== null && data.eta_seconds !== undefined) {
            etaElement.textContent = formatTime(data.eta_seconds);
        } else {
            etaElement.textContent = '--';
        }

        // Update segments
        const segmentsElement = overlay.querySelector('#segments');
        if (data.segments !== undefined) {
            segmentsElement.textContent = data.segments;
        } else {
            segmentsElement.textContent = '--';
        }

        // Show/hide switch button
        const switchBtn = overlay.querySelector('#switch-to-hls');
        if (data.available && data.hls_url && data.segments > 2) {
            switchBtn.classList.remove('hidden');
            switchBtn.dataset.hlsUrl = data.hls_url;
        } else {
            switchBtn.classList.add('hidden');
        }

        // Change color based on status
        const content = overlay.querySelector('.upscaling-progress-content');
        content.className = 'upscaling-progress-content';

        if (data.status === 'complete') {
            content.classList.add('status-complete');
            statusText.textContent = '✓ Upscaling Complete!';

            // Auto-hide after delay
            if (CONFIG.autoHide) {
                setTimeout(() => {
                    hideOverlay();
                }, CONFIG.hideDelay);
            }
        } else if (data.status === 'finalizing') {
            content.classList.add('status-finalizing');
        } else if (data.status === 'processing') {
            content.classList.add('status-processing');
        }

        // Show overlay if hidden
        if (progress > 0 && overlayElement.classList.contains('hidden')) {
            setTimeout(() => {
                showOverlay();
            }, CONFIG.showDelay);
        }

        lastProgress = progress;
    }

    /**
     * Format seconds to human-readable time
     */
    function formatTime(seconds) {
        if (seconds < 60) {
            return `${seconds}s`;
        } else if (seconds < 3600) {
            const mins = Math.floor(seconds / 60);
            const secs = seconds % 60;
            return `${mins}m ${secs}s`;
        } else {
            const hours = Math.floor(seconds / 3600);
            const mins = Math.floor((seconds % 3600) / 60);
            return `${hours}h ${mins}m`;
        }
    }

    /**
     * Show notification
     */
    function showNotification(message) {
        // Try Jellyfin's notification system
        if (window.Dashboard && window.Dashboard.alert) {
            window.Dashboard.alert(message);
        } else {
            console.log(`[Progress] ${message}`);
        }
    }

    /**
     * Fetch progress from watchdog
     */
    async function fetchProgress(filename) {
        try {
            const response = await fetch(`${CONFIG.watchdogUrl}/progress/${filename}`);

            if (!response.ok) {
                if (response.status === 404) {
                    // Not started yet
                    return null;
                }
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            return data;

        } catch (error) {
            console.error('[Progress] Failed to fetch:', error);
            return null;
        }
    }

    /**
     * Poll for progress updates
     */
    async function pollProgress(mediaPath) {
        const filename = mediaPath.split('/').pop();
        const data = await fetchProgress(filename);

        if (data) {
            updateProgress(data);

            // Stop polling if complete
            if (data.status === 'complete' && CONFIG.autoHide) {
                setTimeout(() => {
                    stopPolling();
                }, CONFIG.hideDelay);
            }
        }
    }

    /**
     * Start polling for progress
     */
    function startPolling(mediaPath) {
        console.log('[Progress] Starting progress monitoring:', mediaPath);

        currentMediaPath = mediaPath;

        // Clear existing interval
        if (progressInterval) {
            clearInterval(progressInterval);
        }

        // Initial fetch
        pollProgress(mediaPath);

        // Poll periodically
        progressInterval = setInterval(() => {
            pollProgress(mediaPath);
        }, CONFIG.pollInterval);
    }

    /**
     * Stop polling
     */
    function stopPolling() {
        console.log('[Progress] Stopping progress monitoring');

        if (progressInterval) {
            clearInterval(progressInterval);
            progressInterval = null;
        }

        currentMediaPath = null;
        lastProgress = 0;
    }

    /**
     * Handle playback start
     */
    function onPlaybackStart(mediaPath) {
        console.log('[Progress] Playback started:', mediaPath);

        // Reset playing flag
        videoIsPlaying = false;

        // Show loading indicator immediately
        if (CONFIG.showLoadingImmediately) {
            showLoadingState();
        }

        // Start monitoring after short delay
        setTimeout(() => {
            startPolling(mediaPath);
        }, 2000);
    }

    /**
     * Handle when video actually starts playing
     */
    function onVideoPlaying() {
        console.log('[Progress] Video playback confirmed');
        videoIsPlaying = true;

        // Clear loading state now that video is playing
        if (isLoading) {
            clearLoadingState();
        }
    }

    /**
     * Handle playback stop
     */
    function onPlaybackStop() {
        console.log('[Progress] Playback stopped');
        stopPolling();
        hideOverlay();
        isLoading = false;
        videoIsPlaying = false;
    }

    /**
     * Initialize keyboard shortcuts
     */
    function initKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Toggle overlay with 'U' key
            if (e.key === 'u' || e.key === 'U') {
                if (overlayElement && !overlayElement.classList.contains('hidden')) {
                    hideOverlay();
                } else if (currentMediaPath) {
                    showOverlay();
                }
            }

            // ESC to close
            if (e.key === 'Escape' && overlayElement && !overlayElement.classList.contains('hidden')) {
                hideOverlay();
            }
        });
    }

    /**
     * Initialize the progress overlay
     */
    function initialize() {
        console.log('[Progress] Initializing upscaling progress overlay');

        // Create overlay element
        createProgressOverlay();

        // Initialize keyboard shortcuts
        initKeyboardShortcuts();

        // Hook into HLS streaming integration if available
        if (window.JellyfinHLS) {
            const originalCheckStatus = window.JellyfinHLS.checkStatus;

            window.JellyfinHLS.checkStatus = async function(mediaPath) {
                const result = await originalCheckStatus.call(this, mediaPath);

                // Start progress monitoring if upscaling detected
                if (result && (result.status === 'streaming' || result.status === 'started')) {
                    startPolling(mediaPath);
                }

                return result;
            };
        }

        // Monitor video elements
        const observer = new MutationObserver(() => {
            const videoElement = document.querySelector('video');

            if (videoElement && !videoElement.dataset.progressMonitored) {
                videoElement.dataset.progressMonitored = 'true';

                // Listen for actual playback start
                videoElement.addEventListener('playing', onVideoPlaying);

                // Also clear loading on timeupdate (backup)
                videoElement.addEventListener('timeupdate', () => {
                    if (!videoIsPlaying && videoElement.currentTime > 0) {
                        onVideoPlaying();
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

        console.log('[Progress] Progress overlay initialized');
        console.log('[Progress] Press "U" key to toggle progress overlay');
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initialize);
    } else {
        initialize();
    }

    // Export for manual control
    window.JellyfinUpscalingProgress = {
        show: showOverlay,
        hide: hideOverlay,
        start: startPolling,
        stop: stopPolling,
        config: CONFIG
    };

    console.log('[Progress] Upscaling Progress Overlay loaded');
    console.log('[Progress] Manual controls available via window.JellyfinUpscalingProgress');
})();
