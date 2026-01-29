import os
import time
from pathlib import Path

# --- Configuration ---
WATCH_DIR = os.environ.get("UPSCALED_DIR", "/mnt/media/upscaled")
DAYS_TO_KEEP = int(os.environ.get("DAYS_TO_KEEP", "2"))
EXTENSION = os.environ.get("UPSCALED_EXT", ".ts")
USE_ATIME = os.environ.get("USE_ATIME", "0") == "1"

def cleanup():
    now = time.time()
    seconds_threshold = DAYS_TO_KEEP * 86400
    deleted_count = 0
    bytes_saved = 0

    if not os.path.isdir(WATCH_DIR):
        print(f"⚠️  Upscaled directory not found: {WATCH_DIR}")
        return

    print(f"🧹 Scanning for old upscaled files in {WATCH_DIR}...")

    # Recursively find all upscaled .ts files
    for path in Path(WATCH_DIR).rglob(f"*{EXTENSION}"):
        try:
            stat = path.stat()
            timestamp = stat.st_atime if USE_ATIME else stat.st_mtime
            file_age = now - timestamp

            if file_age > seconds_threshold:
                file_size = path.stat().st_size
                path.unlink()
                deleted_count += 1
                bytes_saved += file_size
                print(f"🗑️  Deleted: {path.name} (Unused for {DAYS_TO_KEEP}+ days)")

        except Exception as e:
            print(f"⚠️  Error processing {path.name}: {e}")

    gb_saved = bytes_saved / (1024**3)
    print(f"✨ Cleanup finished. Removed {deleted_count} files. Freed {gb_saved:.2f} GB.")

if __name__ == "__main__":
    cleanup()
