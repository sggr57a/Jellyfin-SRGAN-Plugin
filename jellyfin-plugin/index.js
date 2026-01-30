/**
 * Real-Time HDR SRGAN Pipeline Plugin for Jellyfin
 * Main plugin entry point
 */

const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

class RealTimeHDRSRGANPlugin {
    constructor(api, log) {
        this.api = api;
        this.log = log;
        this.pluginPath = __dirname;
    }

    /**
     * Initialize the plugin
     */
    async init() {
        this.log.info('Real-Time HDR SRGAN Pipeline plugin initialized');
        
        // Make scripts executable
        const scripts = ['gpu-detection.sh', 'backup-config.sh', 'restore-config.sh'];
        scripts.forEach(script => {
            const scriptPath = path.join(this.pluginPath, script);
            if (fs.existsSync(scriptPath)) {
                fs.chmodSync(scriptPath, '755');
            }
        });

        // Run GPU detection on startup
        this.detectGPU();
    }

    /**
     * Detect NVIDIA GPU
     */
    async detectGPU() {
        return new Promise((resolve, reject) => {
            const scriptPath = path.join(this.pluginPath, 'gpu-detection.sh');
            
            exec(`bash "${scriptPath}"`, (error, stdout, stderr) => {
                if (error) {
                    this.log.warn('GPU detection failed: ' + error.message);
                    resolve({ available: false, error: error.message });
                    return;
                }

                const output = stdout.toString();
                const gpuFound = output.includes('SUCCESS: NVIDIA GPU');
                
                this.log.info('GPU Detection: ' + (gpuFound ? 'NVIDIA GPU found' : 'No NVIDIA GPU found'));
                
                resolve({
                    available: gpuFound,
                    output: output,
                    error: stderr.toString()
                });
            });
        });
    }

    /**
     * Create backup of Jellyfin configuration
     */
    async createBackup() {
        return new Promise((resolve, reject) => {
            const scriptPath = path.join(this.pluginPath, 'backup-config.sh');
            
            exec(`bash "${scriptPath}"`, (error, stdout, stderr) => {
                if (error) {
                    this.log.error('Backup failed: ' + error.message);
                    reject(error);
                    return;
                }

                const output = stdout.toString();
                const backupPath = output.match(/Backup location: (.+)/)?.[1];
                
                this.log.info('Configuration backup created: ' + backupPath);
                
                resolve({
                    success: true,
                    backupPath: backupPath,
                    output: output
                });
            });
        });
    }

    /**
     * Restore Jellyfin configuration from backup
     */
    async restoreBackup(backupPath) {
        return new Promise((resolve, reject) => {
            const scriptPath = path.join(this.pluginPath, 'restore-config.sh');
            const command = backupPath 
                ? `bash "${scriptPath}" "${backupPath}"`
                : `bash "${scriptPath}"`;
            
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    this.log.error('Restore failed: ' + error.message);
                    reject(error);
                    return;
                }

                this.log.info('Configuration restored successfully');
                
                resolve({
                    success: true,
                    output: stdout.toString()
                });
            });
        });
    }

    /**
     * Get plugin configuration
     */
    getConfiguration() {
        return this.api.getPluginConfiguration(this.api.getCurrentUserId());
    }

    /**
     * Save plugin configuration
     */
    saveConfiguration(config) {
        return this.api.savePluginConfiguration(this.api.getCurrentUserId(), config);
    }
}

module.exports = RealTimeHDRSRGANPlugin;
