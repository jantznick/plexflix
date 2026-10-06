# Built from the repo root (see docker-compose.yml) so the channel's own font
# can be used for the "Reconnecting" slates.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# ffmpeg 6.1 here has libx264, NVENC, Quick Sync (libvpl) and VAAPI built in;
# the VA drivers cover Intel iGPUs and AMD for ENCODER=h264_vaapi / h264_qsv
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg python3 ca-certificates intel-media-va-driver mesa-va-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY multiview/multiview /app/multiview
COPY roku/fonts/Outfit-SemiBold.ttf /app/fonts/Outfit-SemiBold.ttf

EXPOSE 8095
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8095/healthz', timeout=3)"

CMD ["python3", "-m", "multiview.server"]
