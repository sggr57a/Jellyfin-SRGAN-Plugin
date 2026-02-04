#!/bin/bash
# Clear job queue to remove any old HLS/TS jobs

QUEUE_FILE="${SRGAN_QUEUE_FILE:-./cache/queue.jsonl}"

if [[ -f "$QUEUE_FILE" ]]; then
    echo "Clearing job queue: $QUEUE_FILE"
    
    # Backup old queue
    if [[ -s "$QUEUE_FILE" ]]; then
        backup_file="${QUEUE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$QUEUE_FILE" "$backup_file"
        echo "✓ Backed up to: $backup_file"
    fi
    
    # Clear the queue
    > "$QUEUE_FILE"
    echo "✓ Queue cleared"
    echo ""
    echo "All old jobs removed. New jobs will use direct MKV/MP4 output only."
else
    echo "Queue file not found: $QUEUE_FILE"
    echo "Nothing to clear."
fi
