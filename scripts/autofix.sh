#!/bin/bash
# Automatic Error Detection and Recovery System
# This script runs continuously to monitor the pipeline and auto-fix issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Logging
LOG_FILE="/var/log/srgan-autofix.log"
LAST_CHECK_FILE="/tmp/srgan-last-check"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if we should run (avoid running too frequently)
check_cooldown() {
    if [[ -f "$LAST_CHECK_FILE" ]]; then
        LAST_CHECK=$(cat "$LAST_CHECK_FILE")
        NOW=$(date +%s)
        DIFF=$((NOW - LAST_CHECK))
        
        # Only run checks every 5 minutes
        if [[ $DIFF -lt 300 ]]; then
            return 1
        fi
    fi
    
    date +%s > "$LAST_CHECK_FILE"
    return 0
}

# Issue 1: Container not running
fix_container_not_running() {
    log "ERROR: Container not running. Attempting restart..."
    
    cd "$REPO_DIR"
    docker compose down
    docker compose up -d
    
    sleep 5
    
    if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
        log "✓ Container restarted successfully"
        return 0
    else
        log "✗ Container restart failed"
        return 1
    fi
}

# Issue 2: Pipeline process not running
fix_pipeline_not_running() {
    log "ERROR: Pipeline process not running. Checking logs..."
    
    # Get last 50 lines of logs
    LOGS=$(docker logs srgan-upscaler --tail 50 2>&1)
    
    # Check for common errors
    if echo "$LOGS" | grep -q "Model.*not found"; then
        log "ERROR: Model file missing. Running setup_model.sh..."
        cd "$REPO_DIR"
        ./scripts/setup_model.sh
        docker restart srgan-upscaler
        return 0
    fi
    
    if echo "$LOGS" | grep -q "CUDA.*not available\|GPU.*not found"; then
        log "ERROR: GPU not accessible. Restarting Docker..."
        systemctl restart docker
        sleep 5
        docker compose up -d
        return 0
    fi
    
    if echo "$LOGS" | grep -q "ImportError\|ModuleNotFoundError"; then
        log "ERROR: Python import error. Rebuilding container..."
        cd "$REPO_DIR"
        docker compose down
        docker compose build --no-cache
        docker compose up -d
        return 0
    fi
    
    # Generic restart
    log "Performing generic container restart..."
    docker restart srgan-upscaler
    return 0
}

# Issue 3: Watchdog API not running
fix_watchdog_not_running() {
    log "ERROR: Watchdog API not running. Attempting restart..."
    
    systemctl restart srgan-watchdog-api
    sleep 2
    
    if systemctl is-active --quiet srgan-watchdog-api; then
        log "✓ Watchdog API restarted successfully"
        return 0
    else
        log "✗ Watchdog API restart failed. Check journalctl -u srgan-watchdog-api"
        return 1
    fi
}

# Issue 4: GPU not accessible
fix_gpu_not_accessible() {
    log "ERROR: GPU not accessible. Restarting Docker daemon..."
    
    systemctl restart docker
    sleep 5
    
    cd "$REPO_DIR"
    docker compose down
    docker compose up -d
    sleep 5
    
    if docker exec srgan-upscaler nvidia-smi >/dev/null 2>&1; then
        log "✓ GPU now accessible"
        return 0
    else
        log "✗ GPU still not accessible. May need system reboot"
        return 1
    fi
}

# Issue 5: Queue stuck with old jobs
fix_stuck_queue() {
    log "WARNING: Queue has old jobs. Backing up and clearing..."
    
    cd "$REPO_DIR"
    
    if [[ -f "./cache/queue.jsonl" ]]; then
        BACKUP_FILE="./cache/queue.jsonl.autobackup.$(date +%s)"
        cp "./cache/queue.jsonl" "$BACKUP_FILE"
        log "Backed up queue to: $BACKUP_FILE"
        
        > "./cache/queue.jsonl"
        log "✓ Queue cleared"
        return 0
    fi
    
    return 0
}

# Issue 6: Model file missing
fix_model_missing() {
    log "ERROR: Model file missing. Downloading..."
    
    cd "$REPO_DIR"
    ./scripts/setup_model.sh
    
    if docker exec srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
        log "✓ Model file downloaded successfully"
        return 0
    else
        log "✗ Model download failed"
        return 1
    fi
}

# Main diagnostic function
run_diagnostics() {
    log "Running automated diagnostics..."
    
    ISSUES_FOUND=0
    ISSUES_FIXED=0
    
    # Check 1: Container running
    if ! docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
        ((ISSUES_FOUND++))
        log "Issue detected: Container not running"
        
        if fix_container_not_running; then
            ((ISSUES_FIXED++))
        fi
    fi
    
    # Check 2: Pipeline process
    if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
        if ! docker exec srgan-upscaler pgrep -f "srgan_pipeline.py" >/dev/null 2>&1; then
            ((ISSUES_FOUND++))
            log "Issue detected: Pipeline process not running"
            
            if fix_pipeline_not_running; then
                ((ISSUES_FIXED++))
            fi
        fi
    fi
    
    # Check 3: Watchdog API
    if ! systemctl is-active --quiet srgan-watchdog-api 2>/dev/null; then
        ((ISSUES_FOUND++))
        log "Issue detected: Watchdog API not running"
        
        if fix_watchdog_not_running; then
            ((ISSUES_FIXED++))
        fi
    fi
    
    # Check 4: GPU access
    if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
        if ! docker exec srgan-upscaler nvidia-smi >/dev/null 2>&1; then
            ((ISSUES_FOUND++))
            log "Issue detected: GPU not accessible"
            
            if fix_gpu_not_accessible; then
                ((ISSUES_FIXED++))
            fi
        fi
    fi
    
    # Check 5: Model file
    if docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
        if ! docker exec srgan-upscaler test -f /app/models/swift_srgan_4x.pth 2>/dev/null; then
            ((ISSUES_FOUND++))
            log "Issue detected: Model file missing"
            
            if fix_model_missing; then
                ((ISSUES_FIXED++))
            fi
        fi
    fi
    
    # Check 6: Queue health (check if too many old jobs)
    if [[ -f "$REPO_DIR/cache/queue.jsonl" ]]; then
        QUEUE_SIZE=$(cat "$REPO_DIR/cache/queue.jsonl" 2>/dev/null | wc -l | tr -d ' \r' || echo "0")
        # Ensure QUEUE_SIZE is a valid number
        if [[ ! "$QUEUE_SIZE" =~ ^[0-9]+$ ]]; then
            QUEUE_SIZE="0"
        fi
        
        if [[ $QUEUE_SIZE -gt 10 ]] 2>/dev/null; then
            ((ISSUES_FOUND++))
            log "Issue detected: Queue has $QUEUE_SIZE jobs (possibly stuck)"
            
            if fix_stuck_queue; then
                ((ISSUES_FIXED++))
            fi
        fi
    fi
    
    # Summary
    if [[ $ISSUES_FOUND -eq 0 ]]; then
        log "✓ All checks passed. System healthy."
    else
        log "Summary: Found $ISSUES_FOUND issues, fixed $ISSUES_FIXED"
        
        # Run verification after fixes
        if [[ $ISSUES_FIXED -gt 0 ]]; then
            log "Running post-fix verification..."
            cd "$REPO_DIR"
            ./scripts/verify_all_features.sh | tail -5 | tee -a "$LOG_FILE"
        fi
    fi
}

# Check for processing errors in recent logs
check_recent_errors() {
    if ! docker ps --format '{{.Names}}' | grep -q "^srgan-upscaler$"; then
        return
    fi
    
    # Get logs from last 5 minutes
    RECENT_LOGS=$(docker logs srgan-upscaler --since 5m 2>&1)
    
    # Check for critical errors
    if echo "$RECENT_LOGS" | grep -qi "ERROR.*AI model upscaling failed"; then
        log "Detected AI model failure in recent logs"
        run_diagnostics
    fi
    
    if echo "$RECENT_LOGS" | grep -qi "ERROR.*Input file does not exist"; then
        log "Detected input file access error - may be volume mount issue"
        
        # Check if volume is mounted read-only
        MOUNT_INFO=$(docker inspect srgan-upscaler 2>/dev/null | grep -A 5 "Mounts")
        if echo "$MOUNT_INFO" | grep -q '"RW": false'; then
            log "ERROR: Volume mounted read-only. Need to update docker-compose.yml"
            log "Run: sed -i 's|/mnt/media:/mnt/media|/mnt/media:/mnt/media:rw|' docker-compose.yml"
            log "Then: docker compose down && docker compose up -d"
        fi
    fi
    
    if echo "$RECENT_LOGS" | grep -qi "CUDA.*out of memory"; then
        log "Detected GPU memory exhaustion"
        log "Restarting container to clear GPU memory..."
        docker restart srgan-upscaler
    fi
}

# Main execution
main() {
    log "===== Auto-Fix Service Started ====="
    
    # Check cooldown
    if ! check_cooldown; then
        # Too soon since last check
        exit 0
    fi
    
    # Run diagnostics
    run_diagnostics
    
    # Check for recent errors
    check_recent_errors
    
    log "===== Auto-Fix Service Completed ====="
}

# Run main function
main "$@"
