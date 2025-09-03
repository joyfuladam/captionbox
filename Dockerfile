# Use Ubuntu 20.04 as base image
FROM ubuntu:20.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies and Python 3.9
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y \
    python3.9 \
    python3.9-venv \
    python3.9-dev \
    build-essential \
    portaudio19-dev \
    libasound2-dev \
    libasound2-plugins \
    libportaudio2 \
    libportaudiocpp0 \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    ffmpeg \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install pip for Python 3.9
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Create virtual environment and install Python dependencies
RUN python3.9 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip and install requirements
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Copy application files
COPY . .
COPY asound.conf /etc/asound.conf

# Copy and run audio setup script
COPY docker-audio-setup.sh /tmp/docker-audio-setup.sh
RUN chmod +x /tmp/docker-audio-setup.sh && \
    /tmp/docker-audio-setup.sh && \
    rm /tmp/docker-audio-setup.sh

# Create user and audio group matching host
RUN groupadd -g 29 audio || true && \
    useradd -u 1000 -g 1000 -G 29 nwtech || true && \
    mkdir -p /app/logs && \
    chmod +x /app/captionStable.py && \
    mkdir -p /run/user/1000 && \
    chown -R 1000:1000 /app && \
    chown -R 1000:29 /run/user/1000

# Create startup script
RUN echo '#!/bin/bash\n\
echo "Starting Caption Stable with audio support..."\n\
\n\
# Initialize audio\n\
/usr/local/bin/init-audio\n\
\n\
# Set audio environment variables\n\
export PULSE_RUNTIME_PATH=/tmp/pulse-audio\n\
export PULSE_STATE_PATH=/tmp/pulse-audio\n\
export PULSE_CLIENTCONFIG=/etc/pulse/client.conf\n\
export ALSA_PCM_CARD=0\n\
export ALSA_PCM_DEVICE=0\n\
\n\
# Test audio configuration\n\
echo "Testing audio configuration..."\n\
/usr/local/bin/test-audio\n\
\n\
# Start the application\n\
echo "Starting Caption Stable application..."\n\
cd /app\n\
exec python3 captionStable_docker.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose port 8000
EXPOSE 8000

# Set environment variables
ENV AZURE_SPEECH_KEY=""
ENV AZURE_SPEECH_REGION="eastus"
ENV PULSE_RUNTIME_PATH="/tmp/pulse-audio"
ENV PULSE_STATE_PATH="/tmp/pulse-audio"
ENV PULSE_CLIENTCONFIG="/etc/pulse/client.conf"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the application with audio support
CMD ["/app/start.sh"] 