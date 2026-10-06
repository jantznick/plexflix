# Built from the repo root (see docker-compose.yml) so the channel's own font
# can be used for the "Reconnecting" slates.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# ffmpeg decodes the feeds; GStreamer tiles and encodes. plugins-base has the
# compositor, plugins-ugly x264enc, plugins-bad hlssink2, voaacenc and the
# VA / NVENC encoders (which only register when the hardware is there).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg python3 python3-gi ca-certificates \
        gir1.2-gstreamer-1.0 gir1.2-gst-plugins-base-1.0 \
        gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
        intel-media-va-driver mesa-va-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY multiview/multiview /app/multiview
COPY roku/fonts/Outfit-SemiBold.ttf /app/fonts/Outfit-SemiBold.ttf

EXPOSE 8095
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8095/healthz', timeout=3)"

CMD ["python3", "-m", "multiview.server"]
