#!/bin/bash
# Start the vendored roku-feed advanced-proxy, then multiview on :8095.
# The proxy is supervised: Chrome/Puppeteer/remux crashes used to leave
# Python up with :18787 dead (warm → connection refused → slate mosaic).
# Do NOT export PORT into the proxy's environment permanently — Node and
# Python both read it; leaking the proxy port makes multiview bind wrong.
set -euo pipefail

PROXY_PORT="${MULTIVIEW_PROXY_PORT:-18787}"
export PROXY_HEADLESS="${PROXY_HEADLESS:-true}"
export PROXY_HEADLESS_MODE="${PROXY_HEADLESS_MODE:-shell}"
export PROXY_HOST="${PROXY_HOST:-127.0.0.1:${PROXY_PORT}}"
export MULTIVIEW_PROXY_PORT="${PROXY_PORT}"
# Quieter Chrome; dbus socket is often missing in containers
export DBUS_SESSION_BUS_ADDRESS=/dev/null

PROXY_PID=""
PYTHON_PID=""
STOPPING=0

log() {
  echo "[entrypoint] $*"
}

kill_proxy() {
  if [[ -n "${PROXY_PID}" ]] && kill -0 "${PROXY_PID}" 2>/dev/null; then
    kill "${PROXY_PID}" 2>/dev/null || true
    wait "${PROXY_PID}" 2>/dev/null || true
  fi
  PROXY_PID=""
}

cleanup() {
  STOPPING=1
  if [[ -n "${PYTHON_PID}" ]] && kill -0 "${PYTHON_PID}" 2>/dev/null; then
    kill "${PYTHON_PID}" 2>/dev/null || true
  fi
  kill_proxy
}
trap cleanup EXIT INT TERM

proxy_ready() {
  curl -sf "http://127.0.0.1:${PROXY_PORT}/" >/dev/null 2>&1
}

start_proxy() {
  kill_proxy
  (
    cd /app/proxy
    exec env PORT="${PROXY_PORT}" node advanced-proxy.js
  ) &
  PROXY_PID=$!
  log "vendored proxy starting pid=${PROXY_PID} on :${PROXY_PORT}"
}

wait_proxy_ready() {
  local i
  for i in $(seq 1 60); do
    if proxy_ready; then
      return 0
    fi
    if ! kill -0 "${PROXY_PID}" 2>/dev/null; then
      wait "${PROXY_PID}" 2>/dev/null || true
      return 1
    fi
    sleep 0.5
  done
  return 1
}

# Restart Node whenever it exits. Python keeps serving /sessions either way.
supervise_proxy() {
  local backoff=1
  while [[ "${STOPPING}" -eq 0 ]]; do
    start_proxy
    if wait_proxy_ready; then
      log "vendored proxy ready on :${PROXY_PORT}"
      backoff=1
      wait "${PROXY_PID}" 2>/dev/null || true
      PROXY_PID=""
      if [[ "${STOPPING}" -ne 0 ]]; then
        break
      fi
      log "vendored proxy exited — restarting in ${backoff}s" >&2
    else
      log "vendored proxy failed to become ready — retry in ${backoff}s" >&2
      kill_proxy
    fi
    sleep "${backoff}"
    if [[ "${backoff}" -lt 15 ]]; then
      backoff=$((backoff + 1))
    fi
  done
}

supervise_proxy &
SUPERVISOR_PID=$!

for _ in $(seq 1 120); do
  if proxy_ready; then
    break
  fi
  if ! kill -0 "${SUPERVISOR_PID}" 2>/dev/null; then
    log "proxy supervisor exited before first ready" >&2
    exit 1
  fi
  sleep 0.5
done

if ! proxy_ready; then
  log "vendored proxy never became ready" >&2
  exit 1
fi

cd /app
# Multiview listens on 8095 (compose / default). Never inherit the proxy PORT.
export PORT="${MULTIVIEW_PORT:-8095}"
python3 -m multiview.server &
PYTHON_PID=$!
wait "${PYTHON_PID}"
exit_code=$?
STOPPING=1
kill "${SUPERVISOR_PID}" 2>/dev/null || true
wait "${SUPERVISOR_PID}" 2>/dev/null || true
exit "${exit_code}"
