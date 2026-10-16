#!/bin/bash
# Start the vendored roku-feed advanced-proxy (same code), then multiview.
set -euo pipefail

# Use 18787 by default so we don't collide with the LAN roku-feed proxy on :8787
# when running with network_mode: host.
export PROXY_HEADLESS="${PROXY_HEADLESS:-true}"
export PORT="${MULTIVIEW_PROXY_PORT:-18787}"
export PROXY_HOST="${PROXY_HOST:-127.0.0.1:${PORT}}"

cd /app/proxy
node advanced-proxy.js &
proxy_pid=$!

cleanup() {
  kill "$proxy_pid" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
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
exec python3 -m multiview.server
