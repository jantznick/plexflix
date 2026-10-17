# Built from the repo root. Vendors roku-feed advanced-proxy; ffmpeg builds the mosaic.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    NODE_ENV=production \
    PROXY_HEADLESS=true \
    MULTIVIEW_PROXY_PORT=18787 \
    PROXY_HOST=127.0.0.1:18787 \
    PUPPETEER_CACHE_DIR=/app/proxy/.cache/puppeteer

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
        ffmpeg python3 \
        # Chromium runtime deps for the vendored puppeteer proxy
        fonts-liberation libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 \
        libcairo2 libcups2t64 libdbus-1-3 libdrm2 libgbm1 libglib2.0-0t64 \
        libgtk-3-0t64 libnspr4 libnss3 libpango-1.0-0 libx11-6 libxcb1 \
        libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2 \
        libu2f-udev libvulkan1 \
        wget xdg-utils dbus \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY multiview/proxy/package.json multiview/proxy/package-lock.json ./proxy/
WORKDIR /app/proxy
RUN npm ci --omit=dev \
    && ln -sfn /app/proxy/node_modules /app/node_modules

WORKDIR /app
COPY multiview/proxy/ ./proxy/
COPY multiview/src/ ./src/
COPY multiview/multiview /app/multiview
COPY multiview/entrypoint.sh /app/entrypoint.sh
COPY roku/fonts/Outfit-SemiBold.ttf /app/fonts/Outfit-SemiBold.ttf
RUN chmod +x /app/entrypoint.sh

EXPOSE 8095
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8095/healthz', timeout=3)"

CMD ["/app/entrypoint.sh"]
