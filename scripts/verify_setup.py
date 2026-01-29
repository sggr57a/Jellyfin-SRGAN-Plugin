#!/usr/bin/env python3
"""
Verification script to check SRGAN pipeline prerequisites and configuration.
"""
import os
import sys
import subprocess
import json


def check_command(command, name):
    """Check if a command is available."""
    try:
        result = subprocess.run(
            [command, "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        print(f"  ✓ {name} installed")
        return True
    except FileNotFoundError:
        print(f"  ✗ {name} NOT installed")
        return False
    except Exception as e:
        print(f"  ⚠ {name} check failed: {e}")
        return False


def check_docker_compose():
    """Check Docker Compose v2."""
    try:
        result = subprocess.run(
            ["docker", "compose", "version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            print(f"  ✓ Docker Compose v2 installed")
            print(f"    {result.stdout.strip()}")
            return True
        else:
            print(f"  ✗ Docker Compose v2 NOT working")
            return False
    except Exception as e:
        print(f"  ✗ Docker Compose v2 check failed: {e}")
        return False


def check_python_packages():
    """Check required Python packages."""
    required = ["flask", "requests"]
    all_installed = True

    for package in required:
        try:
            __import__(package)
            print(f"  ✓ Python package '{package}' installed")
        except ImportError:
            print(f"  ✗ Python package '{package}' NOT installed")
            all_installed = False

    return all_installed


def check_nvidia_gpu():
    """Check NVIDIA GPU availability."""
    try:
        result = subprocess.run(
            ["nvidia-smi"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            print(f"  ✓ NVIDIA GPU detected")
            # Extract GPU info
            lines = result.stdout.split('\n')
            for line in lines:
                if 'NVIDIA' in line or 'CUDA' in line:
                    print(f"    {line.strip()}")
            return True
        else:
            print(f"  ✗ nvidia-smi failed")
            return False
    except FileNotFoundError:
        print(f"  ✗ nvidia-smi NOT found (NVIDIA drivers not installed?)")
        return False
    except Exception as e:
        print(f"  ⚠ GPU check failed: {e}")
        return False


def check_docker_nvidia():
    """Check Docker NVIDIA runtime."""
    try:
        result = subprocess.run(
            ["docker", "run", "--rm", "--gpus", "all", "nvidia/cuda:12.1.0-base-ubuntu22.04", "nvidia-smi"],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0:
            print(f"  ✓ Docker can access NVIDIA GPU")
            return True
        else:
            print(f"  ✗ Docker cannot access GPU")
            print(f"    Install NVIDIA Container Toolkit")
            return False
    except Exception as e:
        print(f"  ⚠ Docker GPU check failed: {e}")
        return False


def check_directories():
    """Check required directories."""
    dirs = {
        "input": "./input",
        "output": "./output",
        "cache": "./cache",
        "models": "./models"
    }

    all_exist = True
    for name, path in dirs.items():
        if os.path.exists(path):
            print(f"  ✓ {name} directory exists: {path}")
        else:
            print(f"  ⚠ {name} directory missing: {path} (will be created)")
            all_exist = False

    return all_exist


def check_docker_compose_file():
    """Check docker-compose.yml configuration."""
    if not os.path.exists("docker-compose.yml"):
        print(f"  ✗ docker-compose.yml NOT found")
        return False

    print(f"  ✓ docker-compose.yml exists")

    # Check volume mounts
    with open("docker-compose.yml", "r") as f:
        content = f.read()

        if "srgan-upscaler" in content:
            print(f"  ✓ srgan-upscaler service defined")
        else:
            print(f"  ✗ srgan-upscaler service NOT found")
            return False

        if "/app/cache/queue.jsonl" in content or "SRGAN_QUEUE_FILE" in content:
            print(f"  ✓ Queue file configuration present")
        else:
            print(f"  ⚠ Queue file configuration not explicit")

    return True


def check_media_mount():
    """Check media mount point."""
    with open("docker-compose.yml", "r") as f:
        content = f.read()

        if "/mnt/media:/data" in content:
            media_path = "/mnt/media"
            if os.path.exists(media_path):
                print(f"  ✓ Media mount exists: {media_path}")
                return True
            else:
                print(f"  ✗ Media mount NOT found: {media_path}")
                print(f"    Update docker-compose.yml volume mount or create directory")
                return False
        else:
            print(f"  ⚠ Media mount configuration not standard")
            print(f"    Check docker-compose.yml volumes section")
            return None


def main():
    print("=" * 80)
    print("SRGAN Pipeline Setup Verification")
    print("=" * 80)
    print()

    results = []

    # System Requirements
    print("1. System Requirements")
    print("-" * 80)
    results.append(check_command("docker", "Docker"))
    results.append(check_docker_compose())
    results.append(check_command("python3", "Python 3"))
    results.append(check_python_packages())
    print()

    # GPU Requirements
    print("2. GPU Requirements")
    print("-" * 80)
    results.append(check_nvidia_gpu())
    gpu_docker = check_docker_nvidia()
    if gpu_docker is not None:
        results.append(gpu_docker)
    print()

    # Directory Structure
    print("3. Directory Structure")
    print("-" * 80)
    check_directories()  # Don't fail on missing dirs
    print()

    # Configuration Files
    print("4. Configuration Files")
    print("-" * 80)
    results.append(check_docker_compose_file())
    media_result = check_media_mount()
    if media_result is not None:
        results.append(media_result)
    print()

    # Environment Variables
    print("5. Environment Variables (Optional)")
    print("-" * 80)
    env_vars = {
        "UPSCALED_DIR": "/data/upscaled",
        "SRGAN_QUEUE_FILE": "./cache/queue.jsonl"
    }
    for var, default in env_vars.items():
        value = os.environ.get(var, default)
        print(f"  {var} = {value}")
    print()

    # Summary
    print("=" * 80)
    print("VERIFICATION SUMMARY")
    print("=" * 80)

    passed = sum(results)
    total = len(results)

    print(f"Checks Passed: {passed}/{total}")

    if passed == total:
        print("\n✓ All checks passed! Ready to start.")
        print("\nNext steps:")
        print("  1. Start the watchdog: python3 scripts/watchdog.py")
        print("  2. Test the webhook: python3 scripts/test_webhook.py --test-file /path/to/video.mkv")
        print("  3. Configure Jellyfin webhook plugin with:")
        print("     URL: http://<your-host>:5000/upscale-trigger")
        return 0
    else:
        print("\n⚠ Some checks failed. Please fix the issues above.")
        print("\nCommon fixes:")
        print("  - Install Flask: pip3 install flask requests")
        print("  - Install Docker: https://docs.docker.com/engine/install/")
        print("  - Install NVIDIA drivers: https://www.nvidia.com/download/index.aspx")
        print("  - Install NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html")
        return 1


if __name__ == "__main__":
    sys.exit(main())
