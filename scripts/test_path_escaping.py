#!/usr/bin/env python3
"""
Test path escaping for FFmpeg tee muxer
"""

def _escape_tee_path(path):
    """
    Escape special characters in file paths for FFmpeg tee muxer.
    Tee muxer treats [, ], :, | as special characters.
    """
    # Escape special characters for tee muxer
    path = path.replace("'", "'\\''")  # Single quotes
    path = path.replace("[", r"\[")    # Opening bracket
    path = path.replace("]", r"\]")    # Closing bracket
    path = path.replace(":", r"\:")    # Colon (in non-URL contexts)
    return path


def test_escaping():
    """Test various problematic filenames"""
    
    test_cases = [
        (
            "/root/upscaled/hls/Back to the Future (1985) [Bluray-1080p]",
            r"/root/upscaled/hls/Back to the Future (1985) \[Bluray-1080p\]"
        ),
        (
            "/media/Movie [2160p] [HDR].mkv",
            r"/media/Movie \[2160p\] \[HDR\].mkv"
        ),
        (
            "/media/Show: Season 1.mp4",
            r"/media/Show\: Season 1.mp4"
        ),
        (
            "/media/Movie's [Director's Cut].mp4",
            r"/media/Movie'\''s \[Director'\''s Cut\].mp4"
        ),
        (
            "/media/Normal_Movie.mp4",
            r"/media/Normal_Movie.mp4"
        ),
    ]
    
    print("Testing path escaping for FFmpeg tee muxer:")
    print("=" * 80)
    print()
    
    all_passed = True
    
    for i, (input_path, expected_output) in enumerate(test_cases, 1):
        result = _escape_tee_path(input_path)
        passed = result == expected_output
        all_passed = all_passed and passed
        
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"Test {i}: {status}")
        print(f"  Input:    {input_path}")
        print(f"  Expected: {expected_output}")
        print(f"  Got:      {result}")
        print()
    
    print("=" * 80)
    if all_passed:
        print("✅ All tests passed!")
        return 0
    else:
        print("❌ Some tests failed")
        return 1


if __name__ == "__main__":
    import sys
    sys.exit(test_escaping())
