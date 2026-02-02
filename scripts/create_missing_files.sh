#!/bin/bash
#
# Create Missing Playback Overlay Files
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
PLUGIN_DIR="${REPO_DIR}/jellyfin-plugin"

echo "=========================================================================="
echo "Creating Missing Playback Overlay Files"
echo "=========================================================================="
echo ""

# Create playback-progress-overlay.js
echo "Creating playback-progress-overlay.js..."
cat > "${PLUGIN_DIR}/playback-progress-overlay.js" << 'EOJS'
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
EOJS

echo "✓ playback-progress-overlay.js created"

# Create playback-progress-overlay.css
echo "Creating playback-progress-overlay.css..."
cat > "${PLUGIN_DIR}/playback-progress-overlay.css" << 'EOCSS'
/**
 * Jellyfin Upscaling Progress Overlay Styles
 * Theme-aware with CSS variables
 */

.upscaling-progress-container {
    position: fixed;
    top: 20px;
    right: 20px;
    z-index: 10000;
    font-family: var(--font-family, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif);
    opacity: 0;
    transform: translateY(-20px);
    transition: opacity 0.3s ease, transform 0.3s ease;
    pointer-events: none;
}

.upscaling-progress-container.visible {
    opacity: 1;
    transform: translateY(0);
    pointer-events: all;
}

.upscaling-progress-content {
    background: var(--card-background, rgba(0, 0, 0, 0.9));
    border: 1px solid var(--card-border-color, rgba(255, 255, 255, 0.1));
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
    min-width: 320px;
    max-width: 400px;
    overflow: hidden;
}

.upscaling-progress-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 16px;
    background: var(--header-background, rgba(255, 255, 255, 0.05));
    border-bottom: 1px solid var(--card-border-color, rgba(255, 255, 255, 0.1));
}

.upscaling-icon {
    font-size: 20px;
}

.upscaling-title {
    flex: 1;
    font-weight: 600;
    font-size: 14px;
    color: var(--text-primary, #ffffff);
}

.upscaling-close {
    background: none;
    border: none;
    color: var(--text-secondary, #aaaaaa);
    font-size: 24px;
    line-height: 1;
    cursor: pointer;
    padding: 0;
    width: 24px;
    height: 24px;
    transition: color 0.2s ease;
}

.upscaling-close:hover {
    color: var(--text-primary, #ffffff);
}

.upscaling-progress-body {
    padding: 16px;
}

.upscaling-status {
    font-size: 13px;
    color: var(--text-secondary, #cccccc);
    margin-bottom: 12px;
}

.upscaling-progress-bar {
    position: relative;
    height: 24px;
    background: var(--progress-bg, rgba(255, 255, 255, 0.1));
    border-radius: 12px;
    overflow: hidden;
    margin-bottom: 12px;
}

.upscaling-progress-fill {
    position: absolute;
    top: 0;
    left: 0;
    height: 100%;
    background: linear-gradient(90deg, 
        var(--accent-color, #00a4dc) 0%,
        var(--accent-color-light, #52b8e7) 100%);
    border-radius: 12px;
    transition: width 0.5s ease;
}

.status-loading .upscaling-progress-fill {
    background: repeating-linear-gradient(
        90deg,
        rgba(255, 255, 255, 0.1),
        rgba(255, 255, 255, 0.1) 10px,
        rgba(255, 255, 255, 0.2) 10px,
        rgba(255, 255, 255, 0.2) 20px
    );
    animation: loading-sweep 1.5s linear infinite;
}

@keyframes loading-sweep {
    0% { background-position: 0 0; }
    100% { background-position: 40px 0; }
}

.status-processing .upscaling-progress-fill::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(90deg,
        transparent,
        rgba(255, 255, 255, 0.3),
        transparent
    );
    animation: shimmer 2s infinite;
}

@keyframes shimmer {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(100%); }
}

.status-complete .upscaling-progress-fill {
    background: linear-gradient(90deg,
        var(--success-color, #4caf50) 0%,
        var(--success-color-light, #66bb6a) 100%);
}

.upscaling-progress-text {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    font-size: 12px;
    font-weight: 600;
    color: var(--text-primary, #ffffff);
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.5);
    z-index: 1;
}

.upscaling-details {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    font-size: 12px;
    margin-bottom: 12px;
}

.upscaling-speed,
.upscaling-eta {
    color: var(--text-secondary, #aaaaaa);
}

.upscaling-speed.good {
    color: var(--success-color, #4caf50);
}

.upscaling-speed.slow {
    color: var(--warning-color, #ff9800);
}

.upscaling-switch-btn {
    width: 100%;
    padding: 10px;
    background: var(--accent-color, #00a4dc);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s ease;
}

.upscaling-switch-btn:hover {
    background: var(--accent-color-dark, #0082b3);
}

.upscaling-switch-btn:active {
    transform: scale(0.98);
}

/* Dark theme support */
@media (prefers-color-scheme: dark) {
    .upscaling-progress-content {
        background: rgba(20, 20, 20, 0.95);
        border-color: rgba(255, 255, 255, 0.1);
    }
}

/* Light theme support */
@media (prefers-color-scheme: light) {
    .upscaling-progress-content {
        background: rgba(255, 255, 255, 0.95);
        border-color: rgba(0, 0, 0, 0.1);
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
    }
    
    .upscaling-title,
    .upscaling-progress-text {
        color: #000000;
    }
    
    .upscaling-status,
    .upscaling-speed,
    .upscaling-eta {
        color: #666666;
    }
    
    .upscaling-close {
        color: #999999;
    }
    
    .upscaling-close:hover {
        color: #000000;
    }
}

/* Mobile responsive */
@media (max-width: 768px) {
    .upscaling-progress-container {
        top: 10px;
        right: 10px;
        left: 10px;
    }
    
    .upscaling-progress-content {
        min-width: auto;
        max-width: none;
    }
}
EOCSS

echo "✓ playback-progress-overlay.css created"

# Create centered variant
echo "Creating playback-progress-overlay-centered.css..."
cat > "${PLUGIN_DIR}/playback-progress-overlay-centered.css" << 'EOCSS2'
/**
 * Centered Loading Indicator Variant
 * More prominent display option
 */

.upscaling-progress-container.loading-centered {
    top: 50%;
    left: 50%;
    right: auto;
    transform: translate(-50%, -50%);
}

.upscaling-progress-container.loading-centered .upscaling-progress-content {
    min-width: 400px;
    padding: 24px;
}

.upscaling-progress-container.loading-centered .upscaling-icon {
    font-size: 32px;
}

.upscaling-progress-container.loading-centered .upscaling-title {
    font-size: 18px;
}

.upscaling-progress-container.loading-centered .upscaling-progress-bar {
    height: 32px;
}
EOCSS2

echo "✓ playback-progress-overlay-centered.css created"

echo ""
echo "=========================================================================="
echo "Files Created Successfully!"
echo "=========================================================================="
echo ""
echo "Created files:"
echo "  ✓ ${PLUGIN_DIR}/playback-progress-overlay.js"
echo "  ✓ ${PLUGIN_DIR}/playback-progress-overlay.css"
echo "  ✓ ${PLUGIN_DIR}/playback-progress-overlay-centered.css"
echo ""
echo "These files will be copied to /usr/share/jellyfin/web/ during install_all.sh"
echo ""
