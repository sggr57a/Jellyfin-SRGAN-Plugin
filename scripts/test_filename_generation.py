#!/usr/bin/env python3
"""
Test intelligent filename generation
"""

import re
import os

def _resolution_to_label(height):
    """Convert resolution height to standard label."""
    if height >= 2160:
        return "2160p"  # 4K
    elif height >= 1440:
        return "1440p"  # 2K
    elif height >= 1080:
        return "1080p"  # Full HD
    elif height >= 720:
        return "720p"   # HD
    elif height >= 576:
        return "576p"   # SD
    elif height >= 480:
        return "480p"   # SD
    else:
        return f"{height}p"


def _generate_output_filename(input_path, output_dir, target_height, is_hdr=False, output_ext=".mkv"):
    """
    Generate intelligent output filename with resolution and HDR tags.
    """
    basename = os.path.basename(input_path)
    name_without_ext = os.path.splitext(basename)[0]
    
    # Remove existing resolution tags
    resolution_patterns = [
        r'[-\s]?(480|576|720|1080|1440|2160)[pi]\b',
        r'\[?\b4K\b\]?',
        r'\[?\b2K\b\]?',
        r'\[?\bHD\b\]?',
        r'\[?\bFHD\b\]?',
        r'\[?\bUHD\b\]?',
        r'\[?\bSD\b\]?',
    ]
    
    for pattern in resolution_patterns:
        name_without_ext = re.sub(pattern, '', name_without_ext, flags=re.IGNORECASE)
    
    # Remove existing HDR tags
    hdr_patterns = [
        r'\[?\bHDR10?\b\]?',
        r'\[?\bHDR\b\]?',
        r'\[?\bDolby Vision\b\]?',
        r'\[?\bHLG\b\]?',
    ]
    
    for pattern in hdr_patterns:
        name_without_ext = re.sub(pattern, '', name_without_ext, flags=re.IGNORECASE)
    
    # Clean up multiple spaces and brackets
    name_without_ext = re.sub(r'\s+', ' ', name_without_ext)
    name_without_ext = re.sub(r'\[\s*\]', '', name_without_ext)
    name_without_ext = name_without_ext.strip()
    
    # Add new resolution tag
    new_resolution = _resolution_to_label(target_height)
    name_without_ext = f"{name_without_ext} [{new_resolution}]"
    
    # Add HDR tag if applicable
    if is_hdr:
        name_without_ext = f"{name_without_ext} [HDR]"
    
    # Generate final output path
    output_filename = f"{name_without_ext}{output_ext}"
    return os.path.join(output_dir, output_filename)


def test_filename_generation():
    """Test various filename patterns"""
    
    test_cases = [
        # (input, target_height, is_hdr, expected_output)
        ("Movie (2020) [720p].mkv", 2160, False, "Movie (2020) [2160p].mkv"),
        ("Movie (2020) [1080p].mkv", 2160, True, "Movie (2020) [2160p] [HDR].mkv"),
        ("Movie (2020).mkv", 2160, False, "Movie (2020) [2160p].mkv"),
        ("Movie (2020) [Bluray-720p].mkv", 2160, False, "Movie (2020) [Bluray] [2160p].mkv"),
        ("Show S01E01 [1080p] [HDR].mkv", 2160, True, "Show S01E01 [2160p] [HDR].mkv"),
        ("Old Movie [480p] [SD].avi", 1080, False, "Old Movie [1080p].mkv"),
        ("Movie [4K] [HDR10].mkv", 2160, True, "Movie [2160p] [HDR].mkv"),
        ("Back to the Future (1985) [Bluray-1080p].mp4", 2160, False, "Back to the Future (1985) [Bluray] [2160p].mkv"),
        ("Movie (2020) [2160p].mkv", 2160, False, "Movie (2020) [2160p].mkv"),
        ("Movie [HD] [720p].mkv", 2160, True, "Movie [2160p] [HDR].mkv"),
    ]
    
    output_dir = "/output"
    
    print("Testing Intelligent Filename Generation")
    print("=" * 80)
    print()
    
    passed = 0
    failed = 0
    
    for i, (input_file, height, is_hdr, expected) in enumerate(test_cases, 1):
        result = _generate_output_filename(input_file, output_dir, height, is_hdr)
        result_basename = os.path.basename(result)
        
        if result_basename == expected:
            status = "✓ PASS"
            passed += 1
        else:
            status = "✗ FAIL"
            failed += 1
        
        print(f"Test {i}: {status}")
        print(f"  Input:    {input_file}")
        print(f"  Height:   {height}p" + (" (HDR)" if is_hdr else ""))
        print(f"  Expected: {expected}")
        print(f"  Got:      {result_basename}")
        print()
    
    print("=" * 80)
    print(f"Results: {passed} passed, {failed} failed")
    print()
    
    return failed == 0


if __name__ == "__main__":
    import sys
    success = test_filename_generation()
    sys.exit(0 if success else 1)
