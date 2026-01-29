import os
import queue
import threading
from typing import Optional, Tuple

import torch
import torchaudio


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
            f"SRGAN model not found at {model_path}. Provide the Swift-SRGAN weights."
        )

    force_state = os.environ.get("SRGAN_MODEL_FORMAT", "").lower() == "pth"
    if model_path.endswith((".pt", ".ts")) and not force_state:
        model = torch.jit.load(model_path, map_location=device)
        model.eval()
        return model

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
    return model


def _parse_fps(frame_rate: Optional[object], fallback: float = 24.0) -> float:
    if frame_rate is None:
        return fallback
    if isinstance(frame_rate, (int, float)):
        return float(frame_rate)
    if isinstance(frame_rate, str):
        if "/" in frame_rate:
            num, den = frame_rate.split("/", 1)
            try:
                return float(num) / float(den)
            except (ValueError, ZeroDivisionError):
                return fallback
        try:
            return float(frame_rate)
        except ValueError:
            return fallback
    return fallback


def _select_video_stream(reader: torchaudio.io.StreamReader) -> Tuple[int, object]:
    primary_info = reader.get_src_stream_info(0)
    if getattr(primary_info, "media_type", None) == "video":
        return 0, primary_info

    num_streams = getattr(reader, "num_src_streams", 1)
    for idx in range(num_streams):
        info = reader.get_src_stream_info(idx)
        if getattr(info, "media_type", None) == "video":
            return idx, info
    raise RuntimeError("No video stream found in input.")


def _pick_decoder(codec_name: Optional[str]) -> Optional[str]:
    if not codec_name:
        return None
    codec = codec_name.lower()
    if "hevc" in codec or "h265" in codec:
        return "hevc_cuvid"
    if "h264" in codec or "avc" in codec:
        return "h264_cuvid"
    return None


def _infer_scale(scale: float) -> int:
    try:
        return max(1, int(round(scale)))
    except (TypeError, ValueError):
        return 4


def _output_dtype(fmt: str) -> Tuple[torch.dtype, float]:
    if fmt in {"rgb48le", "bgr48le"}:
        return torch.uint16, 65535.0
    return torch.uint8, 255.0


class _WriterThread:
    def __init__(self, writer: torchaudio.io.StreamWriter, queue_size: int = 6):
        self.writer = writer
        self.queue: "queue.Queue[object]" = queue.Queue(maxsize=queue_size)
        self.sentinel = object()
        self.thread = threading.Thread(target=self._run, name="writer-thread", daemon=True)
        self.thread.start()

    def _run(self) -> None:
        while True:
            item = self.queue.get()
            if item is self.sentinel:
                break
            stream_index, chunk = item
            self.writer.write_video_chunk(stream_index, chunk)
            self.queue.task_done()

    def write(self, stream_index: int, chunk: torch.Tensor) -> None:
        self.queue.put((stream_index, chunk))

    def close(self) -> None:
        self.queue.join()
        self.queue.put(self.sentinel)
        self.thread.join()


def upscale(input_path: str, output_path: str, width=None, height=None, scale=2.0):
    torch.backends.cudnn.benchmark = True
    device = os.environ.get("SRGAN_DEVICE") or (
        "cuda" if torch.cuda.is_available() else "cpu"
    )
    model_path = os.environ.get(
        "SRGAN_MODEL_PATH", "/app/models/swift_srgan_4x.pth"
    )
    scale_factor = _infer_scale(scale)
    model = _load_model(model_path, device, scale=scale_factor)
    use_fp16 = device.startswith("cuda") and os.environ.get("SRGAN_FP16", "1") == "1"
    if use_fp16:
        model = model.half()

    reader = torchaudio.io.StreamReader(input_path)
    video_stream_idx, video_info = _select_video_stream(reader)
    src_width = int(getattr(video_info, "width", 0) or 0)
    src_height = int(getattr(video_info, "height", 0) or 0)
    fps = _parse_fps(getattr(video_info, "frame_rate", None))

    hwaccel = os.environ.get("SRGAN_FFMPEG_HWACCEL", "0") == "1"
    decoder = _pick_decoder(getattr(video_info, "codec_name", None))
    decoder = decoder if hwaccel else None

    input_format = os.environ.get("SRGAN_INPUT_PIX_FMT", "rgb48le")
    reader.add_basic_video_stream(
        frames_per_chunk=1,
        stream_index=video_stream_idx,
        format=input_format,
        width=src_width or None,
        height=src_height or None,
        decoder=decoder,
        hwaccel="cuda" if hwaccel else None,
        device=device,
    )

    if width and height:
        out_width, out_height = int(width), int(height)
    else:
        out_width = int((src_width or 0) * scale_factor)
        out_height = int((src_height or 0) * scale_factor)

    encoder = os.environ.get("SRGAN_FFMPEG_ENCODER", "libx264")
    preset_default = "p1" if "nvenc" in encoder else "fast"
    preset = os.environ.get("SRGAN_FFMPEG_PRESET", preset_default)
    delay = os.environ.get("SRGAN_FFMPEG_DELAY", "0")
    color_primaries = os.environ.get("SRGAN_COLOR_PRIMARIES", "bt2020")
    color_trc = os.environ.get("SRGAN_COLOR_TRC", "smpte2084")
    output_format = os.environ.get("SRGAN_OUTPUT_PIX_FMT", input_format)

    encoder_options = {"preset": preset, "delay": delay}
    if "hevc_nvenc" in encoder:
        encoder_options["profile"] = "main10"
        encoder_options["color_primaries"] = color_primaries
        encoder_options["color_trc"] = color_trc

    output_container = "mpegts" if output_path.lower().endswith(".ts") else None
    writer = torchaudio.io.StreamWriter(output_path, format=output_container)
    writer.add_video_stream(
        frame_rate=fps,
        width=out_width,
        height=out_height,
        format=output_format,
        encoder=encoder,
        encoder_option=encoder_options,
    )
    writer.open()
    writer_thread = _WriterThread(writer)

    try:
        for (video_chunk,) in reader.stream():
            if video_chunk is None:
                continue
            if video_chunk.dim() == 3:
                video_chunk = video_chunk.unsqueeze(0)

            video_chunk = video_chunk.to(device, non_blocking=True)
            if video_chunk.dtype in (torch.uint8, torch.uint16):
                scale_value = 255.0 if video_chunk.dtype == torch.uint8 else 65535.0
                video_chunk = video_chunk.float() / scale_value
            else:
                video_chunk = video_chunk.float()

            with torch.no_grad():
                if use_fp16:
                    with torch.autocast("cuda", dtype=torch.float16):
                        output = model(video_chunk.half())
                else:
                    output = model(video_chunk)

            if output.dim() == 3:
                output = output.unsqueeze(0)
            if out_width and out_height and output.shape[-2:] != (
                out_height,
                out_width,
            ):
                output = torch.nn.functional.interpolate(
                    output, size=(out_height, out_width), mode="bicubic", align_corners=False
                )

            out_dtype, out_scale = _output_dtype(output_format)
            output = output.clamp(0, 1).mul(out_scale).round().to(out_dtype)
            if device.startswith("cuda") and output.device.type != "cuda":
                output = output.to(device, non_blocking=True)

            writer_thread.write(0, output)
    finally:
        writer_thread.close()
        writer.close()
        reader.close()
