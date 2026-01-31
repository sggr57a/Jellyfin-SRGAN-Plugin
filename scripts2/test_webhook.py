#!/usr/bin/env python3
"""
Test script for verifying webhook configuration and connectivity.
"""
import requests
import json
import sys
import os
import argparse


def test_health_check(base_url):
    """Test the health check endpoint."""
    print("=" * 80)
    print("Testing Health Check Endpoint")
    print("=" * 80)
    try:
        response = requests.get(f"{base_url}/health", timeout=5)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        if response.status_code == 200:
            print("✓ Health check PASSED")
            return True
        else:
            print("✗ Health check FAILED")
            return False
    except requests.exceptions.ConnectionError:
        print("✗ CONNECTION ERROR: Cannot connect to watchdog")
        print("  Make sure watchdog.py is running:")
        print("  python3 scripts/watchdog.py")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


def test_webhook_with_test_file(base_url, test_file):
    """Test webhook with a real file path."""
    print("\n" + "=" * 80)
    print("Testing Webhook with Test File")
    print("=" * 80)

    if not os.path.exists(test_file):
        print(f"✗ Test file does not exist: {test_file}")
        return False

    print(f"Test file: {test_file}")

    payload = {
        "Item": {
            "Path": test_file,
            "Name": os.path.basename(test_file),
            "Type": "Movie"
        },
        "User": {
            "Name": "TestUser"
        },
        "Event": "PlaybackStart"
    }

    print(f"\nSending payload:")
    print(json.dumps(payload, indent=2))

    try:
        response = requests.post(
            f"{base_url}/upscale-trigger",
            json=payload,
            timeout=10
        )
        print(f"\nStatus Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")

        if response.status_code == 200:
            print("✓ Webhook test PASSED")
            print("\nCheck the watchdog logs to see if the job was queued.")
            return True
        else:
            print("✗ Webhook test FAILED")
            return False

    except requests.exceptions.ConnectionError:
        print("✗ CONNECTION ERROR: Cannot connect to watchdog")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


def test_webhook_minimal(base_url):
    """Test webhook with minimal payload."""
    print("\n" + "=" * 80)
    print("Testing Webhook with Minimal Payload")
    print("=" * 80)

    payload = {
        "Item": {
            "Path": "/nonexistent/test/file.mkv"
        }
    }

    print(f"Sending minimal payload:")
    print(json.dumps(payload, indent=2))

    try:
        response = requests.post(
            f"{base_url}/upscale-trigger",
            json=payload,
            timeout=10
        )
        print(f"\nStatus Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")

        if response.status_code == 404:
            print("✓ Webhook correctly rejected nonexistent file")
            return True
        else:
            print("⚠ Webhook accepted nonexistent file (unexpected)")
            return False

    except Exception as e:
        print(f"✗ Error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Test SRGAN webhook configuration"
    )
    parser.add_argument(
        "--host",
        default="localhost",
        help="Watchdog host (default: localhost)"
    )
    parser.add_argument(
        "--port",
        type=int,
        default=5000,
        help="Watchdog port (default: 5000)"
    )
    parser.add_argument(
        "--test-file",
        help="Path to a real video file to test with"
    )
    args = parser.parse_args()

    base_url = f"http://{args.host}:{args.port}"

    print("SRGAN Webhook Test Suite")
    print("=" * 80)
    print(f"Testing watchdog at: {base_url}")
    print()

    results = []

    # Test 1: Health check
    results.append(("Health Check", test_health_check(base_url)))

    # Test 2: Minimal payload
    results.append(("Minimal Payload", test_webhook_minimal(base_url)))

    # Test 3: Real file (if provided)
    if args.test_file:
        results.append(("Real File Test", test_webhook_with_test_file(base_url, args.test_file)))
    else:
        print("\n" + "=" * 80)
        print("Skipping Real File Test (no --test-file provided)")
        print("=" * 80)
        print("To test with a real file, run:")
        print(f"  python3 {sys.argv[0]} --test-file /path/to/video.mkv")

    # Summary
    print("\n" + "=" * 80)
    print("TEST SUMMARY")
    print("=" * 80)
    for name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{status}: {name}")

    all_passed = all(result for _, result in results)

    if all_passed:
        print("\n✓ All tests passed!")
        return 0
    else:
        print("\n✗ Some tests failed. Check the output above for details.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
