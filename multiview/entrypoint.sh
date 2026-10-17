#!/bin/bash
# Start the vendored roku-feed advanced-proxy, then multiview on :8095.
# Do NOT export PORT — Node and Python both read it; leaking the proxy port
# makes multiview try to bind the same address (EADDRINUSE).
set -euo pipefail

PROXY_PORT="${MULTIVIEW_PROXY_PORT:-18787}"
export PROXY_HEADLESS="${PROXY_HEADLESS:-true}"
export PROXY_HOST="${PROXY_HOST:-127.0.0.1:${PROXY_PORT}}"
export MULTIVIEW_PROXY_PORT="${PROXY_PORT}"

cd /app/proxy
PORT="${PROXY_PORT}" node advanced-proxy.js &
proxy_pid=$!

cleanup() {
  kill "$proxy_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:${PROXY_PORT}/" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$proxy_pid" 2>/dev/null; then
    echo "[entrypoint] vendored proxy exited before becoming ready" >&2
    wait "$proxy_pid" || true
    exit 1
  fi
  sleep 0.5
done

cd /app
# Multiview listens on 8095 (compose / default). Never inherit the proxy PORT.
export PORT="${MULTIVIEW_PORT:-8095}"
exec python3 -m multiview.server
