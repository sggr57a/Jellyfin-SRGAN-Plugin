/**
 * Real-Time HDR SRGAN Pipeline Plugin Configuration Page JavaScript
 */

// Load configuration on page load
document.addEventListener('DOMContentLoaded', function() {
    loadConfig();
    detectGPU(); // Auto-detect GPU on load
    loadBackupList();
});

/**
 * Load plugin configuration
 */
function loadConfig() {
    fetch('/Plugins/RealTimeHDRSRGAN/Configuration', {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(config => {
        document.getElementById('enableUpscaling').checked = config.enableUpscaling || false;
        document.getElementById('enableTranscoding').checked = config.enableTranscoding || false;
        document.getElementById('gpuDevice').value = config.gpuDevice || '0';
        document.getElementById('upscaleFactor').value = config.upscaleFactor || '2';
    })
    .catch(error => {
        console.error('Error loading config:', error);
        const config = JSON.parse(localStorage.getItem('hdrSrganConfig') || '{}');
        document.getElementById('enableUpscaling').checked = config.enableUpscaling || false;
        document.getElementById('enableTranscoding').checked = config.enableTranscoding || false;
        document.getElementById('gpuDevice').value = config.gpuDevice || '0';
        document.getElementById('upscaleFactor').value = config.upscaleFactor || '2';
    });
}

/**
 * Save plugin configuration
 */
function saveConfig() {
    const config = {
        enableUpscaling: document.getElementById('enableUpscaling').checked,
        enableTranscoding: document.getElementById('enableTranscoding').checked,
        gpuDevice: document.getElementById('gpuDevice').value,
        upscaleFactor: document.getElementById('upscaleFactor').value
    };

    fetch('/Plugins/RealTimeHDRSRGAN/Configuration', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(config)
    })
    .then(response => response.json())
    .then(result => {
        if (result && result.success === false) {
            localStorage.setItem('hdrSrganConfig', JSON.stringify(config));
            showStatus(result.error || 'Saved locally (server rejected update).', 'warning');
            return;
        }
        localStorage.setItem('hdrSrganConfig', JSON.stringify(config));
        showStatus('Configuration saved successfully', 'success');
    })
    .catch(error => {
        console.error('Error saving config:', error);
        localStorage.setItem('hdrSrganConfig', JSON.stringify(config));
        showStatus('Saved locally (server unavailable).', 'warning');
    });
}

/**
 * Detect NVIDIA GPU
 */
function detectGPU() {
    const btn = document.getElementById('detectGpuBtn');
    const statusDiv = document.getElementById('gpuStatus');
    const infoDiv = document.getElementById('gpuInfo');
    
    btn.disabled = true;
    btn.textContent = 'Detecting...';
    statusDiv.innerHTML = '<div class="status info">Detecting GPU...</div>';
    infoDiv.style.display = 'none';
    
    // In a real implementation, this would call the plugin API
    // For now, we'll simulate or use a fetch call
    fetch('/Plugins/RealTimeHDRSRGAN/DetectGPU', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(data => {
        btn.disabled = false;
        btn.textContent = 'Detect NVIDIA GPU';
        
        if (data.available) {
            statusDiv.innerHTML = '<div class="status success">✓ NVIDIA GPU detected and ready!</div>';
            infoDiv.textContent = data.output || 'GPU information available';
            infoDiv.style.display = 'block';
            
            // Update GPU device selector if multiple GPUs found
            updateGPUDeviceSelector(data.gpus || []);
        } else {
            statusDiv.innerHTML = '<div class="status error">✗ No NVIDIA GPU detected. Upscaling will not be available.</div>';
            infoDiv.style.display = 'none';
        }
    })
    .catch(error => {
        btn.disabled = false;
        btn.textContent = 'Detect NVIDIA GPU';
        statusDiv.innerHTML = '<div class="status error">Error detecting GPU: ' + error.message + '</div>';
        infoDiv.style.display = 'none';
        
        // Fallback: try to detect via shell script (if running in Node.js context)
        console.error('GPU detection error:', error);
    });
}

/**
 * Update GPU device selector with available GPUs
 */
function updateGPUDeviceSelector(gpus) {
    const select = document.getElementById('gpuDevice');
    const currentValue = select.value;
    
    // Clear existing options except "Auto-detect"
    while (select.options.length > 1) {
        select.remove(1);
    }
    
    // Add GPU options
    gpus.forEach((gpu, index) => {
        const option = document.createElement('option');
        option.value = index.toString();
        option.textContent = `GPU ${index}: ${gpu.name}`;
        select.appendChild(option);
    });
    
    // Restore previous selection if still valid
    if (currentValue && Array.from(select.options).some(opt => opt.value === currentValue)) {
        select.value = currentValue;
    }
}

/**
 * Create configuration backup
 */
function createBackup() {
    const btn = document.getElementById('createBackupBtn');
    const statusDiv = document.getElementById('backupStatus');
    
    btn.disabled = true;
    btn.textContent = 'Creating Backup...';
    statusDiv.innerHTML = '<div class="status info">Creating backup...</div>';
    
    fetch('/Plugins/RealTimeHDRSRGAN/CreateBackup', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(data => {
        btn.disabled = false;
        btn.textContent = 'Create Configuration Backup';
        
        if (data.success) {
            statusDiv.innerHTML = '<div class="status success">✓ Backup created successfully: ' + (data.backupPath || 'N/A') + '</div>';
            loadBackupList(); // Refresh backup list
        } else {
            statusDiv.innerHTML = '<div class="status error">✗ Backup failed: ' + (data.error || 'Unknown error') + '</div>';
        }
    })
    .catch(error => {
        btn.disabled = false;
        btn.textContent = 'Create Configuration Backup';
        statusDiv.innerHTML = '<div class="status error">Error creating backup: ' + error.message + '</div>';
    });
}

/**
 * Load list of available backups
 */
function loadBackupList() {
    const select = document.getElementById('restoreBackup');
    
    fetch('/Plugins/RealTimeHDRSRGAN/ListBackups', {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(data => {
        // Clear existing options except first
        while (select.options.length > 1) {
            select.remove(1);
        }
        
        // Add backup options
        if (data.backups && data.backups.length > 0) {
            data.backups.forEach(backup => {
                const option = document.createElement('option');
                option.value = backup.path;
                option.textContent = backup.name + ' (' + backup.date + ')';
                select.appendChild(option);
            });
        }
    })
    .catch(error => {
        console.error('Error loading backup list:', error);
    });
}

/**
 * Restore from backup
 */
function restoreBackup() {
    const select = document.getElementById('restoreBackup');
    const statusDiv = document.getElementById('restoreStatus');
    const backupPath = select.value;
    
    if (!backupPath) {
        statusDiv.innerHTML = '<div class="status warning">Please select a backup to restore</div>';
        return;
    }
    
    if (!confirm('WARNING: This will overwrite your current Jellyfin configuration. Continue?')) {
        return;
    }
    
    statusDiv.innerHTML = '<div class="status info">Restoring backup...</div>';
    
    fetch('/Plugins/RealTimeHDRSRGAN/RestoreBackup', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ backupPath: backupPath })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            statusDiv.innerHTML = '<div class="status success">✓ Configuration restored successfully. Please restart Jellyfin.</div>';
        } else {
            statusDiv.innerHTML = '<div class="status error">✗ Restore failed: ' + (data.error || 'Unknown error') + '</div>';
        }
    })
    .catch(error => {
        statusDiv.innerHTML = '<div class="status error">Error restoring backup: ' + error.message + '</div>';
    });
}

/**
 * Show status message
 */
function showStatus(message, type) {
    const statusDiv = document.getElementById('statusMessages');
    const statusElement = document.createElement('div');
    statusElement.className = 'status ' + (type || 'info');
    statusElement.textContent = message;
    statusDiv.appendChild(statusElement);
    
    // Remove after 5 seconds
    setTimeout(() => {
        statusElement.remove();
    }, 5000);
}
