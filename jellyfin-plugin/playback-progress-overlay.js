/**
 * Jellyfin Upscaling Progress Overlay
 * Shows real-time upscaling progress during video playback
 */

(function() {
    'use strict';

    const CONFIG = {
        watchdogUrl: 'http://localhost:5000',
        pollInterval: 2000,
        showDelay: 1000,
        autoHide: true,
        hideDelay: 10000,
        showLoadingImmediately: true
    };

    class UpscalingProgressOverlay {
        constructor() {
            this.container = null;
            this.pollTimer = null;
            this.currentFile = null;
            this.isVisible = false;
            this.init();
        }

        init() {
            this.createUI();
            this.setupEventListeners();
            console.log('[Progress] Upscaling Progress Overlay loaded');
        }

        createUI() {
            if (this.container) return;

            this.container = document.createElement('div');
            this.container.className = 'upscaling-progress-container';
            this.container.innerHTML = `
                <div class="upscaling-progress-content">
                    <div class="upscaling-progress-header">
                        <span class="upscaling-icon">🎬</span>
                        <span class="upscaling-title">4K Upscaling</span>
                        <button class="upscaling-close" aria-label="Close">×</button>
                    </div>
                    <div class="upscaling-progress-body">
                        <div class="upscaling-status">Preparing...</div>
                        <div class="upscaling-progress-bar">
                            <div class="upscaling-progress-fill"></div>
                            <div class="upscaling-progress-text">0%</div>
                        </div>
                        <div class="upscaling-details">
                            <div class="upscaling-speed">Speed: --</div>
                            <div class="upscaling-eta">ETA: --</div>
                        </div>
                        <button class="upscaling-switch-btn" style="display:none;">
                            Switch to Upscaled Stream
                        </button>
                    </div>
                </div>
            `;

            document.body.appendChild(this.container);

            // Setup close button
            this.container.querySelector('.upscaling-close').addEventListener('click', () => {
                this.hide();
            });

            // Setup switch button
            this.container.querySelector('.upscaling-switch-btn').addEventListener('click', () => {
                this.switchToUpscaledStream();
            });
        }

        setupEventListeners() {
            // Listen for video playback events
            document.addEventListener('playbackstart', (e) => {
                const videoPath = this.getVideoPath(e);
                if (videoPath) {
                    this.start(videoPath);
                }
            });

            // Keyboard shortcut: U key to toggle
            document.addEventListener('keydown', (e) => {
                if (e.key === 'u' || e.key === 'U') {
                    this.toggle();
                }
            });
        }

        getVideoPath(event) {
            try {
                const mediaSource = event.detail?.mediaSource;
                if (mediaSource?.Path) {
                    return mediaSource.Path;
                }
            } catch (error) {
                console.error('[Progress] Error getting video path:', error);
            }
            return null;
        }

        start(filePath) {
            console.log('[Progress] Starting monitoring for:', filePath);
            this.currentFile = filePath;
            
            if (CONFIG.showLoadingImmediately) {
                this.showLoading();
            }

            this.startPolling();
        }

        showLoading() {
            if (!this.container) this.createUI();
            
            const content = this.container.querySelector('.upscaling-progress-content');
            content.classList.add('status-loading');
            content.classList.remove('status-processing', 'status-complete');

            this.container.querySelector('.upscaling-status').textContent = 'Preparing 4K upscaling...';
            this.container.querySelector('.upscaling-progress-fill').style.width = '0%';
            this.container.querySelector('.upscaling-progress-text').textContent = '0%';
            this.container.querySelector('.upscaling-speed').textContent = 'Speed: --';
            this.container.querySelector('.upscaling-eta').textContent = 'ETA: --';

            this.show();
        }

        startPolling() {
            this.stopPolling();
            
            this.pollTimer = setInterval(() => {
                this.updateProgress();
            }, CONFIG.pollInterval);

            // Initial update
            this.updateProgress();
        }

        stopPolling() {
            if (this.pollTimer) {
                clearInterval(this.pollTimer);
                this.pollTimer = null;
            }
        }

        async updateProgress() {
            if (!this.currentFile) return;

            try {
                const filename = this.currentFile.split('/').pop();
                const response = await fetch(`${CONFIG.watchdogUrl}/progress/${filename}`);
                
                if (!response.ok) {
                    if (response.status === 404) {
                        // Not started yet, keep loading state
                        return;
                    }
                    throw new Error(`HTTP ${response.status}`);
                }

                const data = await response.json();
                this.renderProgress(data);

            } catch (error) {
                console.error('[Progress] Error fetching progress:', error);
            }
        }

        renderProgress(data) {
            if (!this.container) return;

            const content = this.container.querySelector('.upscaling-progress-content');
            const statusEl = this.container.querySelector('.upscaling-status');
            const fillEl = this.container.querySelector('.upscaling-progress-fill');
            const textEl = this.container.querySelector('.upscaling-progress-text');
            const speedEl = this.container.querySelector('.upscaling-speed');
            const etaEl = this.container.querySelector('.upscaling-eta');
            const switchBtn = this.container.querySelector('.upscaling-switch-btn');

            // Update status
            if (data.status === 'processing') {
                content.classList.add('status-processing');
                content.classList.remove('status-loading', 'status-complete');
                statusEl.textContent = data.message || 'Upscaling in progress...';
            } else if (data.status === 'complete') {
                content.classList.add('status-complete');
                content.classList.remove('status-loading', 'status-processing');
                statusEl.textContent = '✓ Upscaling Complete!';
                
                if (CONFIG.autoHide) {
                    setTimeout(() => this.hide(), CONFIG.hideDelay);
                }
            }

            // Update progress bar
            const progress = Math.min(100, Math.max(0, data.progress || 0));
            fillEl.style.width = `${progress}%`;
            textEl.textContent = `${Math.round(progress)}%`;

            // Update speed
            if (data.processing_rate) {
                const speed = data.processing_rate.toFixed(1);
                speedEl.textContent = `Speed: ${speed}x`;
                speedEl.className = data.processing_rate >= 1.0 ? 'upscaling-speed good' : 'upscaling-speed slow';
            }

            // Update ETA
            if (data.eta_seconds) {
                etaEl.textContent = `ETA: ${this.formatTime(data.eta_seconds)}`;
            }

            // Show/hide switch button
            if (data.available && data.segments > 2) {
                switchBtn.style.display = 'block';
                switchBtn.dataset.hlsUrl = data.hls_url;
            } else {
                switchBtn.style.display = 'none';
            }
        }

        formatTime(seconds) {
            if (seconds < 60) {
                return `${Math.round(seconds)}s`;
            } else if (seconds < 3600) {
                const mins = Math.floor(seconds / 60);
                const secs = Math.round(seconds % 60);
                return `${mins}m ${secs}s`;
            } else {
                const hours = Math.floor(seconds / 3600);
                const mins = Math.round((seconds % 3600) / 60);
                return `${hours}h ${mins}m`;
            }
        }

        switchToUpscaledStream() {
            const switchBtn = this.container.querySelector('.upscaling-switch-btn');
            const hlsUrl = switchBtn.dataset.hlsUrl;

            if (!hlsUrl) {
                console.error('[Progress] No HLS URL available');
                return;
            }

            console.log('[Progress] Switching to upscaled stream:', hlsUrl);
            
            // Trigger stream switch (implementation depends on Jellyfin player integration)
            if (window.JellyfinHLS && window.JellyfinHLS.switchStream) {
                window.JellyfinHLS.switchStream(hlsUrl);
            } else {
                alert('Stream switching not yet implemented. HLS URL: ' + hlsUrl);
            }

            this.hide();
        }

        show() {
            if (!this.container) this.createUI();
            this.container.classList.add('visible');
            this.isVisible = true;
        }

        hide() {
            if (this.container) {
                this.container.classList.remove('visible');
            }
            this.isVisible = false;
            this.stopPolling();
        }

        toggle() {
            if (this.isVisible) {
                this.hide();
            } else {
                this.show();
            }
        }
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            window.JellyfinUpscalingProgress = new UpscalingProgressOverlay();
        });
    } else {
        window.JellyfinUpscalingProgress = new UpscalingProgressOverlay();
    }

    console.log('[Progress] Upscaling Progress Overlay initialized');
})();
