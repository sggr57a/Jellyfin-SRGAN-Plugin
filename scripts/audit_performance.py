#!/usr/bin/env python3
"""
Performance auditing tool for monitoring upscaling FPS in real-time.

Monitors the output file as it's being written and calculates:
- Actual processing FPS
- Real-time multiplier (actual FPS / target FPS)
- Performance status (STABLE if >= 1.0x, SLOW if < 1.0x)
"""
import argparse
import os
import subprocess
import sys
import time


def check_ffprobe():
    """Check if ffprobe is available."""
    try:
        subprocess.run(
            ["ffprobe", "-version"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def get_frame_count(output_file):
    """Get current frame count from file using ffprobe."""
    cmd = [
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-count_packets", "-show_entries", "stream=nb_read_packets",
        "-of", "csv=p=0", output_file
    ]

    try:
        result = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
        return int(result.decode().strip())
    except (subprocess.CalledProcessError, ValueError) as exc:
        return None


def get_perf_stats(output_ts_file, target_fps, sample_seconds):
    """Calculates live FPS and real-time multiplier."""
    print(f"📊 Auditing: {os.path.basename(output_ts_file)}")
    print(f"🎯 Target FPS: {target_fps}")
    print(f"⏱️  Sample interval: {sample_seconds}s")
    print()
    print("Waiting for initial frame count...")

    # Wait for file to have some frames
    start_frames = None
    for attempt in range(10):
        start_frames = get_frame_count(output_ts_file)
        if start_frames is not None and start_frames > 0:
            break
        time.sleep(1)

    if start_frames is None or start_frames == 0:
        print("❌ Could not read frame count from file")
        print("   File may be empty or still initializing")
        return

    print(f"✓ Initial frame count: {start_frames}")
    print()
    print("Monitoring performance (Press Ctrl+C to stop)...")
    print("-" * 70)

    start_time = time.time()
    last_frames = start_frames
    last_time = start_time

    try:
        while True:
            time.sleep(sample_seconds)

            current_frames = get_frame_count(output_ts_file)
            if current_frames is None:
                print("\r⚠️  Could not read frame count, retrying...", end="", flush=True)
                continue

            current_time = time.time()
            elapsed_total = current_time - start_time
            elapsed_sample = current_time - last_time

            # Calculate FPS for this sample period
            frames_this_sample = current_frames - last_frames
            sample_fps = frames_this_sample / elapsed_sample if elapsed_sample > 0 else 0

            # Calculate overall average FPS
            total_frames = current_frames - start_frames
            avg_fps = total_frames / elapsed_total if elapsed_total > 0 else 0

            # Calculate real-time multiplier
            multiplier = avg_fps / target_fps if target_fps > 0 else 0

            # Determine status
            if multiplier >= 1.0:
                status = "✅ STABLE"
            elif multiplier >= 0.8:
                status = "⚠️  SLOW"
            else:
                status = "❌ VERY SLOW"

            # Print stats (overwrite previous line)
            print(
                f"\rFrames: {current_frames:6d} | "
                f"Sample FPS: {sample_fps:6.2f} | "
                f"Avg FPS: {avg_fps:6.2f} | "
                f"Multiplier: {multiplier:5.2f}x | "
                f"{status}",
                end="",
                flush=True
            )

            last_frames = current_frames
            last_time = current_time

    except KeyboardInterrupt:
        print("\n" + "-" * 70)
        print("Audit stopped.")

        # Final summary
        final_frames = get_frame_count(output_ts_file)
        if final_frames is not None:
            total_elapsed = time.time() - start_time
            total_frames = final_frames - start_frames
            final_avg_fps = total_frames / total_elapsed if total_elapsed > 0 else 0
            final_multiplier = final_avg_fps / target_fps if target_fps > 0 else 0

            print()
            print("Final Statistics:")
            print(f"  Total frames processed: {total_frames}")
            print(f"  Total time: {total_elapsed:.1f}s")
            print(f"  Average FPS: {final_avg_fps:.2f}")
            print(f"  Real-time multiplier: {final_multiplier:.2f}x")
            print()

            if final_multiplier >= 1.0:
                print("✅ Performance: GOOD - Processing faster than or equal to real-time")
            elif final_multiplier >= 0.8:
                print("⚠️  Performance: ACCEPTABLE - Processing slightly slower than real-time")
            else:
                print("❌ Performance: POOR - Processing significantly slower than real-time")
    except Exception as exc:
        print(f"\n❌ Error during monitoring: {exc}")
        sys.exit(1)

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Audit live upscaling performance by monitoring output FPS.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Monitor default output file
  python3 audit_performance.py

  # Monitor specific file with custom target FPS
  python3 audit_performance.py --output /data/upscaled/movie.ts --target-fps 24

  # Use shorter sample interval for faster updates
  python3 audit_performance.py --sample-seconds 2

  # Use environment variables
  OUTPUT_FILE=/data/upscaled/movie.ts TARGET_FPS=30 python3 audit_performance.py
        """
    )
    parser.add_argument(
        "--output",
        default=os.environ.get("OUTPUT_FILE", "/mnt/media/upscaled/test_movie.ts"),
        help="Path to the growing output .ts file (default: %(default)s)",
    )
    parser.add_argument(
        "--target-fps",
        type=float,
        default=float(os.environ.get("TARGET_FPS", "23.976")),
        help="Expected source FPS (default: %(default)s)",
    )
    parser.add_argument(
        "--sample-seconds",
        type=float,
        default=float(os.environ.get("SAMPLE_SECONDS", "5")),
        help="Sample interval in seconds (default: %(default)s)",
    )
    args = parser.parse_args()

    print("=" * 70)
    print("SRGAN Performance Auditor")
    print("=" * 70)
    print()

    # Check prerequisites
    if not check_ffprobe():
        print("❌ Error: ffprobe not found")
        print("   Please install ffmpeg:")
        print("   - Ubuntu: sudo apt install ffmpeg")
        print("   - macOS: brew install ffmpeg")
        sys.exit(1)

    # Validate arguments
    if args.target_fps <= 0:
        print(f"❌ Error: Invalid target FPS: {args.target_fps}")
        print("   Target FPS must be greater than 0")
        sys.exit(1)

    if args.sample_seconds <= 0:
        print(f"❌ Error: Invalid sample interval: {args.sample_seconds}")
        print("   Sample interval must be greater than 0")
        sys.exit(1)

    # Check if output file exists
    if not os.path.exists(args.output):
        print(f"❌ Error: Output file not found: {args.output}")
        print()
        print("The file must exist before monitoring can start.")
        print("Start an upscaling job first, then run this script.")
        print()
        print("Example:")
        print("  1. Start upscaling: docker compose run srgan-upscaler input.mkv output.ts")
        print("  2. Monitor progress: python3 audit_performance.py --output output.ts")
        sys.exit(1)

    # Check if file is readable
    try:
        with open(args.output, 'rb') as f:
            f.read(1)
    except PermissionError:
        print(f"❌ Error: No permission to read file: {args.output}")
        sys.exit(1)
    except Exception as exc:
        print(f"❌ Error: Cannot read file: {exc}")
        sys.exit(1)

    # Start monitoring
    get_perf_stats(
        args.output,
        target_fps=args.target_fps,
        sample_seconds=args.sample_seconds
    )


if __name__ == "__main__":
    main()
