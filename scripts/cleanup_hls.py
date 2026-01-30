#!/usr/bin/env python3
"""
Cleanup old HLS segments and directories.

Automatically removes HLS temporary files after the final upscaled file is created,
or removes abandoned HLS streams that are older than a specified age.
"""
import argparse
import os
import shutil
import sys
import time
from datetime import datetime


def get_size_mb(path):
    """Get size of file or directory in MB."""
    if os.path.isfile(path):
        return os.path.getsize(path) / (1024 * 1024)
    elif os.path.isdir(path):
        total = 0
        for dirpath, dirnames, filenames in os.walk(path):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                try:
                    total += os.path.getsize(filepath)
                except OSError:
                    pass
        return total / (1024 * 1024)
    return 0


def is_stream_complete(hls_dir):
    """Check if HLS stream is complete (has EXT-X-ENDLIST)."""
    playlist_path = os.path.join(hls_dir, "stream.m3u8")
    if not os.path.exists(playlist_path):
        return False
    
    try:
        with open(playlist_path, 'r') as f:
            content = f.read()
            return '#EXT-X-ENDLIST' in content
    except Exception:
        return False


def get_age_hours(path):
    """Get age of path in hours."""
    try:
        mtime = os.path.getmtime(path)
        age_seconds = time.time() - mtime
        return age_seconds / 3600
    except OSError:
        return 0


def cleanup_completed_streams(hls_base_dir, upscaled_dir, dry_run=False):
    """
    Remove HLS directories where the final upscaled file exists.
    
    Args:
        hls_base_dir: Base HLS directory (e.g., /data/upscaled/hls)
        upscaled_dir: Directory containing final upscaled files
        dry_run: If True, only show what would be deleted
    """
    if not os.path.exists(hls_base_dir):
        print(f"HLS directory does not exist: {hls_base_dir}")
        return
    
    print("Checking for completed streams...")
    print()
    
    removed_count = 0
    freed_space = 0
    
    for stream_name in os.listdir(hls_base_dir):
        hls_dir = os.path.join(hls_base_dir, stream_name)
        
        if not os.path.isdir(hls_dir):
            continue
        
        # Check if final file exists
        final_file = os.path.join(upscaled_dir, f"{stream_name}.ts")
        
        if os.path.exists(final_file):
            size_mb = get_size_mb(hls_dir)
            age_hours = get_age_hours(hls_dir)
            
            print(f"Stream: {stream_name}")
            print(f"  HLS dir: {hls_dir}")
            print(f"  Final file: {final_file} (exists)")
            print(f"  HLS size: {size_mb:.1f} MB")
            print(f"  Age: {age_hours:.1f} hours")
            
            if dry_run:
                print(f"  [DRY RUN] Would remove HLS directory")
            else:
                try:
                    shutil.rmtree(hls_dir)
                    print(f"  ✓ Removed HLS directory")
                    removed_count += 1
                    freed_space += size_mb
                except Exception as e:
                    print(f"  ❌ Error removing: {e}")
            print()
    
    if removed_count > 0:
        print(f"Cleanup summary:")
        print(f"  Removed: {removed_count} stream(s)")
        print(f"  Freed space: {freed_space:.1f} MB")
    else:
        print("No completed streams to clean up.")
    
    print()


def cleanup_old_streams(hls_base_dir, max_age_hours=24, dry_run=False):
    """
    Remove HLS directories older than max_age_hours.
    
    Useful for cleaning up abandoned or failed streams.
    
    Args:
        hls_base_dir: Base HLS directory
        max_age_hours: Maximum age in hours before removal
        dry_run: If True, only show what would be deleted
    """
    if not os.path.exists(hls_base_dir):
        print(f"HLS directory does not exist: {hls_base_dir}")
        return
    
    print(f"Checking for streams older than {max_age_hours} hours...")
    print()
    
    removed_count = 0
    freed_space = 0
    
    for stream_name in os.listdir(hls_base_dir):
        hls_dir = os.path.join(hls_base_dir, stream_name)
        
        if not os.path.isdir(hls_dir):
            continue
        
        age_hours = get_age_hours(hls_dir)
        
        if age_hours > max_age_hours:
            size_mb = get_size_mb(hls_dir)
            is_complete = is_stream_complete(hls_dir)
            
            print(f"Stream: {stream_name}")
            print(f"  Path: {hls_dir}")
            print(f"  Age: {age_hours:.1f} hours")
            print(f"  Size: {size_mb:.1f} MB")
            print(f"  Complete: {is_complete}")
            
            if dry_run:
                print(f"  [DRY RUN] Would remove (too old)")
            else:
                try:
                    shutil.rmtree(hls_dir)
                    print(f"  ✓ Removed (too old)")
                    removed_count += 1
                    freed_space += size_mb
                except Exception as e:
                    print(f"  ❌ Error removing: {e}")
            print()
    
    if removed_count > 0:
        print(f"Cleanup summary:")
        print(f"  Removed: {removed_count} old stream(s)")
        print(f"  Freed space: {freed_space:.1f} MB")
    else:
        print(f"No streams older than {max_age_hours} hours found.")
    
    print()


def cleanup_all(hls_base_dir, upscaled_dir, max_age_hours=24, dry_run=False):
    """Run both cleanup operations."""
    print("=" * 70)
    print("HLS Cleanup")
    print("=" * 70)
    print(f"HLS directory: {hls_base_dir}")
    print(f"Upscaled directory: {upscaled_dir}")
    print(f"Max age: {max_age_hours} hours")
    print(f"Mode: {'DRY RUN' if dry_run else 'LIVE'}")
    print()
    
    # Cleanup completed streams first
    cleanup_completed_streams(hls_base_dir, upscaled_dir, dry_run)
    
    # Then cleanup old streams
    cleanup_old_streams(hls_base_dir, max_age_hours, dry_run)
    
    print("=" * 70)
    print("Cleanup complete!")
    print("=" * 70)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Cleanup old HLS segments and directories.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Dry run (show what would be deleted)
  python3 cleanup_hls.py --dry-run
  
  # Remove completed streams (where final file exists)
  python3 cleanup_hls.py --completed-only
  
  # Remove streams older than 24 hours
  python3 cleanup_hls.py --max-age 24
  
  # Remove streams older than 48 hours
  python3 cleanup_hls.py --max-age 48
  
  # Custom directories
  python3 cleanup_hls.py --hls-dir /custom/hls --upscaled-dir /custom/upscaled
  
Cron job example (run daily at 3 AM):
  0 3 * * * /usr/bin/python3 /path/to/cleanup_hls.py --max-age 24
        """
    )
    parser.add_argument(
        "--hls-dir",
        default="/data/upscaled/hls",
        help="Base HLS directory (default: /data/upscaled/hls)"
    )
    parser.add_argument(
        "--upscaled-dir",
        default="/data/upscaled",
        help="Directory containing final upscaled files (default: /data/upscaled)"
    )
    parser.add_argument(
        "--max-age",
        type=float,
        default=24,
        help="Maximum age in hours before removal (default: 24)"
    )
    parser.add_argument(
        "--completed-only",
        action="store_true",
        help="Only remove completed streams (where final file exists)"
    )
    parser.add_argument(
        "--old-only",
        action="store_true",
        help="Only remove old streams (ignore whether final file exists)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be deleted without actually deleting"
    )
    
    args = parser.parse_args()
    
    if args.completed_only:
        print("=" * 70)
        print("HLS Cleanup (Completed Streams Only)")
        print("=" * 70)
        print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
        print()
        cleanup_completed_streams(args.hls_dir, args.upscaled_dir, args.dry_run)
    elif args.old_only:
        print("=" * 70)
        print("HLS Cleanup (Old Streams Only)")
        print("=" * 70)
        print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
        print()
        cleanup_old_streams(args.hls_dir, args.max_age, args.dry_run)
    else:
        cleanup_all(args.hls_dir, args.upscaled_dir, args.max_age, args.dry_run)


if __name__ == "__main__":
    main()
