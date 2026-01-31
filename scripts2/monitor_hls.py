#!/usr/bin/env python3
"""
Monitor HLS streaming progress in real-time.

Tracks segment generation, estimates completion time, and shows live statistics.
"""
import argparse
import os
import sys
import time
from datetime import datetime, timedelta


def get_video_duration(video_path):
    """Get video duration using ffprobe."""
    import subprocess
    try:
        cmd = [
            "ffprobe",
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            video_path
        ]
        result = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        return float(result.decode().strip())
    except Exception:
        return None


def monitor_hls_progress(hls_dir, segment_duration=6, video_duration=None):
    """
    Monitor HLS generation progress.
    
    Args:
        hls_dir: Directory containing HLS segments
        segment_duration: Duration of each segment in seconds
        video_duration: Total video duration (optional, for progress percentage)
    """
    print("=" * 70)
    print("HLS Streaming Monitor")
    print("=" * 70)
    print(f"HLS Directory: {hls_dir}")
    print(f"Segment duration: {segment_duration}s")
    
    if video_duration:
        print(f"Total video duration: {video_duration:.1f}s ({video_duration/60:.1f} min)")
    print()
    
    if not os.path.exists(hls_dir):
        print(f"⚠️  HLS directory does not exist yet: {hls_dir}")
        print("Waiting for upscaling to start...")
        
        # Wait for directory to be created
        for _ in range(30):
            if os.path.exists(hls_dir):
                break
            time.sleep(1)
        else:
            print("❌ Timeout: HLS directory not created after 30 seconds")
            sys.exit(1)
        
        print("✓ HLS directory created!")
        print()
    
    playlist_path = os.path.join(hls_dir, "stream.m3u8")
    start_time = time.time()
    last_segment_count = 0
    
    print("Monitoring progress (Press Ctrl+C to stop)...")
    print("-" * 70)
    
    try:
        while True:
            # Count segments
            segments = sorted([
                f for f in os.listdir(hls_dir)
                if f.startswith('segment_') and f.endswith('.ts')
            ]) if os.path.exists(hls_dir) else []
            
            segment_count = len(segments)
            current_duration = segment_count * segment_duration
            elapsed = time.time() - start_time
            
            # Check if completed
            is_complete = False
            if os.path.exists(playlist_path):
                with open(playlist_path, 'r') as f:
                    playlist_content = f.read()
                    is_complete = '#EXT-X-ENDLIST' in playlist_content
            
            # Calculate statistics
            if segment_count > last_segment_count:
                segments_per_sec = (segment_count - last_segment_count) / 2  # 2 second interval
                processing_rate = (segments_per_sec * segment_duration)  # seconds of video per second
            else:
                processing_rate = 0
            
            # Calculate progress percentage
            progress_pct = 0
            if video_duration and video_duration > 0:
                progress_pct = (current_duration / video_duration) * 100
            
            # Calculate ETA
            eta_str = "Unknown"
            if processing_rate > 0 and video_duration:
                remaining_seconds = video_duration - current_duration
                eta_seconds = remaining_seconds / processing_rate
                eta_str = str(timedelta(seconds=int(eta_seconds)))
            
            # Status indicator
            if is_complete:
                status = "✅ COMPLETE"
            elif segment_count > 0:
                status = "🔄 STREAMING"
            else:
                status = "⏳ STARTING"
            
            # Print status line (overwrite previous)
            status_line = (
                f"\rSegments: {segment_count:4d} | "
                f"Duration: {current_duration:6.1f}s"
            )
            
            if video_duration:
                status_line += f" | Progress: {progress_pct:5.1f}%"
            
            status_line += (
                f" | Rate: {processing_rate:4.2f}x | "
                f"ETA: {eta_str:>8s} | "
                f"{status}"
            )
            
            print(status_line, end="", flush=True)
            
            if is_complete:
                print()  # New line after completion
                break
            
            last_segment_count = segment_count
            time.sleep(2)
            
    except KeyboardInterrupt:
        print("\n" + "-" * 70)
        print("Monitoring stopped.")
    
    # Final summary
    print()
    print("Final Statistics:")
    print(f"  Total segments: {segment_count}")
    print(f"  Total duration processed: {current_duration:.1f}s ({current_duration/60:.1f} min)")
    print(f"  Total time elapsed: {elapsed:.1f}s ({elapsed/60:.1f} min)")
    
    if current_duration > 0 and elapsed > 0:
        avg_rate = current_duration / elapsed
        print(f"  Average processing rate: {avg_rate:.2f}x real-time")
        
        if avg_rate >= 1.0:
            print("  ✅ Performance: GOOD - Real-time or faster")
        elif avg_rate >= 0.8:
            print("  ⚠️  Performance: ACCEPTABLE - Close to real-time")
        else:
            print("  ❌ Performance: POOR - Significantly slower than real-time")
    
    if is_complete:
        print("  ✓ Stream completed successfully")
    else:
        print("  ⚠️  Stream incomplete (monitoring stopped early)")
    
    print()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Monitor HLS streaming progress in real-time.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Monitor HLS stream for a specific movie
  python3 monitor_hls.py /data/upscaled/hls/Movie
  
  # With known video duration for progress tracking
  python3 monitor_hls.py /data/upscaled/hls/Movie --video-duration 7200
  
  # Auto-detect duration from input file
  python3 monitor_hls.py /data/upscaled/hls/Movie --input-file /data/movies/Movie.mkv
  
  # Custom segment duration
  python3 monitor_hls.py /data/upscaled/hls/Movie --segment-duration 10
        """
    )
    parser.add_argument(
        "hls_dir",
        help="Path to HLS directory (e.g., /data/upscaled/hls/Movie)"
    )
    parser.add_argument(
        "--segment-duration",
        type=int,
        default=6,
        help="Segment duration in seconds (default: 6)"
    )
    parser.add_argument(
        "--video-duration",
        type=float,
        help="Total video duration in seconds (for progress tracking)"
    )
    parser.add_argument(
        "--input-file",
        help="Input video file (to auto-detect duration)"
    )
    
    args = parser.parse_args()
    
    # Auto-detect duration if input file provided
    video_duration = args.video_duration
    if args.input_file and not video_duration:
        print(f"Detecting video duration from: {args.input_file}")
        video_duration = get_video_duration(args.input_file)
        if video_duration:
            print(f"✓ Detected duration: {video_duration:.1f}s ({video_duration/60:.1f} min)")
        else:
            print("⚠️  Could not detect duration (ffprobe failed)")
        print()
    
    monitor_hls_progress(args.hls_dir, args.segment_duration, video_duration)


if __name__ == "__main__":
    main()
