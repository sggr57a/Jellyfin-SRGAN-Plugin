#!/usr/bin/env python3
"""
SRGAN AI Upscaling using FFmpeg for video I/O
Replaces torchaudio.io with direct FFmpeg subprocess calls
"""

import os
import subprocess
import sys
import tempfile
from typing import Optional

import numpy as np
import torch
from PIL import Image


class _ResidualBlock(torch.nn.Module):
    def __init__(self, channels: int):
        super().__init__()
        self.block = torch.nn.Sequential(
            torch.nn.Conv2d(channels, channels, kernel_size=3, padding=1),
            torch.nn.PReLU(),
            torch.nn.Conv2d(channels, channels, kernel_size=3, padding=1),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return x + self.block(x)


class _UpsampleBlock(torch.nn.Module):
    def __init__(self, channels: int, scale: int):
        super().__init__()
        self.block = torch.nn.Sequential(
            torch.nn.Conv2d(channels, channels * (scale**2), kernel_size=3, padding=1),
            torch.nn.PixelShuffle(scale),
            torch.nn.PReLU(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.block(x)


class _SRGANGenerator(torch.nn.Module):
    def __init__(self, scale: int = 4, num_blocks: int = 16, channels: int = 64):
        super().__init__()
        self.scale = scale
        self.input = torch.nn.Sequential(
            torch.nn.Conv2d(3, channels, kernel_size=9, padding=4),
            torch.nn.PReLU(),
        )
        self.residual = torch.nn.Sequential(
            *[_ResidualBlock(channels) for _ in range(num_blocks)]
        )
        self.trunk = torch.nn.Conv2d(channels, channels, kernel_size=3, padding=1)

        upsample_blocks = []
        remaining = scale
        while remaining > 1:
            upsample_blocks.append(_UpsampleBlock(channels, 2))
            remaining //= 2
        self.upsample = torch.nn.Sequential(*upsample_blocks)

        self.output = torch.nn.Conv2d(channels, 3, kernel_size=9, padding=4)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        head = self.input(x)
        trunk = self.trunk(self.residual(head))
        out = self.upsample(head + trunk)
        return self.output(out)


def _load_model(model_path: str, device: str, scale: int) -> torch.nn.Module:
    if not os.path.exists(model_path):
        raise NotImplementedError(
            f"SRGAN model not found at {model_path}. Download swift_srgan_4x.pth first."
        )

    checkpoint = torch.load(model_path, map_location=device)
    if isinstance(checkpoint, dict):
        state = (
            checkpoint.get("state_dict")
            or checkpoint.get("generator")
            or checkpoint.get("model")
            or checkpoint
        )
    else:
        state = checkpoint

    model = _SRGANGenerator(scale=scale)
    model.load_state_dict(state, strict=False)
    model.eval()
    model = model.to(device)
    return model


def _denoise_tensor(tensor: torch.Tensor, strength: float = 0.5) -> torch.Tensor:
    """Apply Gaussian denoising to reduce artifacts before AI upscaling"""
    if strength <= 0:
        return tensor

    kernel_size = max(3, int(strength * 7) | 1)
    sigma = strength * 2.0

    # Create Gaussian kernel
    x = torch.arange(kernel_size, dtype=torch.float32, device=tensor.device) - (kernel_size - 1) / 2
    gauss_1d = torch.exp(-x**2 / (2 * sigma**2))
    gauss_1d = gauss_1d / gauss_1d.sum()
    
    kernel_2d = gauss_1d.view(-1, 1) @ gauss_1d.view(1, -1)
    kernel_2d = kernel_2d.view(1, 1, kernel_size, kernel_size)

    # Apply to each channel
    from torch.nn.functional import conv2d, pad
    denoised = []
    for c in range(tensor.shape[1]):
        channel = tensor[:, c:c+1, :, :]
        p = kernel_size // 2
        channel_padded = pad(channel, (p, p, p, p), mode='reflect')
        denoised_channel = conv2d(channel_padded, kernel_2d, padding=0)
        denoised.append(denoised_channel)

    denoised_tensor = torch.cat(denoised, dim=1)
    alpha = min(1.0, strength)
    return tensor * (1 - alpha) + denoised_tensor * alpha


def upscale(input_path: str, output_path: str, width=None, height=None, scale=2.0):
    """
    AI upscale video using SRGAN model with FFmpeg for video I/O
    
    This version uses FFmpeg subprocess instead of torchaudio.io for better compatibility
    """
    print("=" * 80, file=sys.stderr)
    print("AI Upscaling with FFmpeg backend", file=sys.stderr)
    print("=" * 80, file=sys.stderr)
    print("", file=sys.stderr)
    
    # Setup
    device = os.environ.get("SRGAN_DEVICE", "cuda" if torch.cuda.is_available() else "cpu")
    model_path = os.environ.get("SRGAN_MODEL_PATH", "/app/models/swift_srgan_4x.pth")
    scale_factor = int(scale) if scale >= 2 else 2
    use_fp16 = device == "cuda" and os.environ.get("SRGAN_FP16", "1") == "1"
    enable_denoise = os.environ.get("SRGAN_DENOISE", "1") == "1"
    denoise_strength = float(os.environ.get("SRGAN_DENOISE_STRENGTH", "0.5"))
    
    print(f"Configuration:", file=sys.stderr)
    print(f"  Model: {model_path}", file=sys.stderr)
    print(f"  Device: {device}", file=sys.stderr)
    print(f"  FP16: {use_fp16}", file=sys.stderr)
    print(f"  Scale: {scale_factor}x", file=sys.stderr)
    print(f"  Denoising: {'Enabled' if enable_denoise else 'Disabled'}", file=sys.stderr)
    if enable_denoise:
        print(f"  Denoise Strength: {denoise_strength}", file=sys.stderr)
    print("", file=sys.stderr)
    
    # Load model
    print("Loading AI model...", file=sys.stderr)
    model = _load_model(model_path, device, scale=scale_factor)
    if use_fp16:
        model = model.half()
    print("✓ Model loaded", file=sys.stderr)
    print("", file=sys.stderr)
    
    # Get input video info
    print("Analyzing input video...", file=sys.stderr)
    probe_cmd = [
        "ffprobe", "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height,r_frame_rate,codec_name",
        "-of", "default=noprint_wrappers=1",
        input_path
    ]
    probe_output = subprocess.check_output(probe_cmd, text=True)
    
    # Parse video info
    info = {}
    for line in probe_output.strip().split('\n'):
        if '=' in line:
            key, value = line.split('=', 1)
            info[key] = value
    
    src_width = int(info.get('width', 1920))
    src_height = int(info.get('height', 1080))
    fps_str = info.get('r_frame_rate', '24/1')
    if '/' in fps_str:
        num, den = map(int, fps_str.split('/'))
        fps = num / den if den > 0 else 24
    else:
        fps = float(fps_str)
    
    out_width = int(width) if width else src_width * scale_factor
    out_height = int(height) if height else src_height * scale_factor
    
    print(f"✓ Input: {src_width}x{src_height} @ {fps:.2f} fps", file=sys.stderr)
    print(f"✓ Output: {out_width}x{out_height}", file=sys.stderr)
    print("", file=sys.stderr)
    
    # Validate output format
    output_ext = os.path.splitext(output_path)[1].lower()
    if output_ext not in ['.mkv', '.mp4']:
        raise ValueError(f"Unsupported output format: {output_ext}. Only .mkv and .mp4 supported.")
    
    # Start FFmpeg to read frames
    print("Starting AI upscaling...", file=sys.stderr)
    ffmpeg_input = [
        "ffmpeg", "-i", input_path,
        "-f", "rawvideo",
        "-pix_fmt", "rgb24",
        "-"
    ]
    
    # Start FFmpeg to write frames
    encoder = os.environ.get("SRGAN_FFMPEG_ENCODER", "hevc_nvenc")
    preset = os.environ.get("SRGAN_FFMPEG_PRESET", "p4" if "nvenc" in encoder else "fast")
    
    ffmpeg_output = [
        "ffmpeg", "-y",
        "-f", "rawvideo",
        "-pix_fmt", "rgb24",
        "-s", f"{out_width}x{out_height}",
        "-r", str(fps),
        "-i", "-",  # Read from stdin
        "-i", input_path,  # For audio/subtitle streams
        "-map", "0:v:0",  # Video from pipe
        "-map", "1:a?",   # Audio from input file
        "-map", "1:s?",   # Subtitles from input file
        "-c:v", encoder,
        "-preset", preset,
    ]
    
    # Quality settings
    if "nvenc" in encoder.lower():
        ffmpeg_output.extend(["-cq", "23"])
    else:
        ffmpeg_output.extend(["-crf", "18"])
    
    ffmpeg_output.extend([
        "-c:a", "copy",
        "-c:s", "copy",
        output_path
    ])
    
    # Process video frame by frame
    input_proc = subprocess.Popen(ffmpeg_input, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output_proc = subprocess.Popen(ffmpeg_output, stdin=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=10**8)
    
    frame_size = src_width * src_height * 3  # RGB24
    frame_count = 0
    
    try:
        while True:
            # Check if output process has died
            if output_proc.poll() is not None:
                stderr_output = output_proc.stderr.read().decode('utf-8', errors='replace')
                raise RuntimeError(f"FFmpeg encoder died unexpectedly:\n{stderr_output}")
            
            # Read frame
            frame_data = input_proc.stdout.read(frame_size)
            if len(frame_data) != frame_size:
                if len(frame_data) == 0:
                    break  # End of video
                else:
                    print(f"Warning: Incomplete frame data ({len(frame_data)} bytes), skipping", file=sys.stderr)
                    break
            
            # Convert to tensor (copy to make writable)
            frame = np.frombuffer(frame_data, dtype=np.uint8).reshape(src_height, src_width, 3).copy()
            frame_tensor = torch.from_numpy(frame).permute(2, 0, 1).unsqueeze(0).float() / 255.0
            frame_tensor = frame_tensor.to(device)
            
            # Apply denoising
            if enable_denoise:
                frame_tensor = _denoise_tensor(frame_tensor, denoise_strength)
            
            # AI upscale
            with torch.no_grad():
                if use_fp16:
                    with torch.autocast("cuda", dtype=torch.float16):
                        upscaled = model(frame_tensor.half())
                else:
                    upscaled = model(frame_tensor)
            
            # Resize if needed
            if upscaled.shape[-2:] != (out_height, out_width):
                upscaled = torch.nn.functional.interpolate(
                    upscaled, size=(out_height, out_width),
                    mode='bicubic', align_corners=False
                )
            
            # Convert back to bytes
            upscaled = upscaled.clamp(0, 1).mul(255).round().byte()
            upscaled = upscaled.squeeze(0).permute(1, 2, 0).cpu().numpy()
            
            # Write frame
            try:
                output_proc.stdin.write(upscaled.tobytes())
            except BrokenPipeError:
                stderr_output = output_proc.stderr.read().decode('utf-8', errors='replace')
                raise RuntimeError(f"FFmpeg encoder pipe broken:\n{stderr_output}")
            
            frame_count += 1
            if frame_count % 30 == 0:
                print(f"  Processed {frame_count} frames...", file=sys.stderr)
        
        print("", file=sys.stderr)
        print(f"✓ Processed {frame_count} frames total", file=sys.stderr)
        
    except Exception as e:
        # Clean up processes on error
        try:
            input_proc.kill()
        except:
            pass
        try:
            output_proc.kill()
        except:
            pass
        raise
    finally:
        # Normal cleanup
        try:
            input_proc.stdout.close()
        except:
            pass
        input_proc.wait()
        
        try:
            output_proc.stdin.close()
        except:
            pass
        output_proc.wait()
        
        # Check for FFmpeg errors
        if output_proc.returncode != 0:
            stderr_output = output_proc.stderr.read().decode('utf-8', errors='replace')
            print(f"FFmpeg encoder error (exit code {output_proc.returncode}):", file=sys.stderr)
            print(stderr_output, file=sys.stderr)
    
    print("✓ AI upscaling complete", file=sys.stderr)
    print("=" * 80, file=sys.stderr)
