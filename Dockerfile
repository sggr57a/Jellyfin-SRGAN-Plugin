# Real-Time HDR SRGAN Pipeline Dockerfile
# Use NVIDIA's official PyTorch image for best compatibility
#FROM nvcr.io/nvidia/pytorch:24.01-py3
FROM sggr57a/nvidia-cuda-ffmpeg:1.5

# Update and install system dependencies including FFmpeg
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    git \
    wget \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Verify FFmpeg and ffprobe are available
RUN which ffmpeg && which ffprobe && \
    ffmpeg -version && \
    ffprobe -version && \
    ffmpeg -formats 2>&1 | grep -E "matroska|mp4" && \
    ffmpeg -codecs 2>&1 | grep -E "hevc|h264"

# Set working directory
WORKDIR /app

ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install system dependencies for FFmpeg and NFS-related mounting
RUN apt-get update && apt-get install -y \
    dialog \
    whiptail \
    wget \
    ca-certificates \
    python3-pip \
    python3-dev \
    python3-setuptools \
    python3-distutils-extra \
    docker-compose-v2 \
    ninja-build \
    libprotobuf-dev \
    protobuf-compiler \
    libprotoc-dev \
    libopencv-dev \
    libtbb-dev \
    libtbb2 \
    libtbb-dev \
    libtbb2 \
    libusb-1.0-0-dev \
    libsm6 \
    libnuma-dev \
    libnuma1 \
    libxrender-dev \
    inotify-tools \
    libgomp1 \
    docker-buildx \
    nvidia-driver-580 \
    && rm -rf /var/lib/apt/lists/*

# Install .NET 9 SDK and ASP.NET Core runtime for Jellyfin plugin build/runtime
RUN distribution=$(. /etc/os-release; echo "$ID/$VERSION_ID") \
    && wget https://packages.microsoft.com/config/${distribution}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm -f packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-9.0 aspnetcore-runtime-9.0 \
    && rm -rf /var/lib/apt/lists/*

# Install NVIDIA toolkit
RUN apt update ; apt install -y nvidia-container-toolkit && nvidia-ctk runtime configure --runtime=docker 

# Set Python as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Install PyTorch packages FIRST from official PyTorch index
# CRITICAL: Must use PyTorch index, not PyPI, to get torchaudio.io module
RUN pip3 install --no-cache-dir \
    torch==2.4.0 \
    torchvision==0.19.0 \
    torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu121

# Verify torchaudio.io is available (fail build if not)
RUN python3 -c "import torchaudio; print(f'torchaudio version: {torchaudio.__version__}')" && \
    python3 -c "import torchaudio.io; print('✓ torchaudio.io available')" || \
    (echo "ERROR: torchaudio.io not available - PyTorch installation failed" && exit 1)

# Copy requirements and install other Python dependencies
COPY requirements.txt /app/
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy scripts directory (pipeline entrypoint + model live here)
COPY scripts/ /app/scripts/

# Copy Jellyfin plugin files into the image
COPY jellyfin-plugin/ /app/jellyfin-plugin/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh /app/scripts/*.py 2>/dev/null || true

# Install plugin files into Jellyfin plugin directory (if Jellyfin is present)
RUN mkdir -p /var/lib/jellyfin/plugins/RealTimeHDRSRGAN \
    && cp -Rv /app/jellyfin-plugin/* /var/lib/jellyfin/plugins/RealTimeHDRSRGAN/ \
    && (command -v systemctl >/dev/null && systemctl restart jellyfin.service || true)

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=0
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility

# Expose port if needed
# EXPOSE 8080

# install NVIDIA patch to remove restriction on number of encoding sessions
#RUN git clone https://github.com/sggr57a/nvidia-patch.git && cd nvidia-patch && bash ./patch.sh

# Clone NVIDIA patch (will be applied at runtime if GPU is detected)
RUN git clone https://github.com/sggr57a/nvidia-patch.git /opt/nvidia-patch || true

# Copy entrypoint script that applies patch at runtime
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entry point runs patch check then starts pipeline
ENTRYPOINT ["/entrypoint.sh"]
