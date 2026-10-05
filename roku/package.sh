#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
OUT="$DIST/plexflix-roku.zip"

mkdir -p "$DIST"
rm -f "$OUT"

# Roku packages are zip files with manifest at the archive root (no top-level folder).
(
  cd "$ROOT"
  zip -r "$OUT" manifest source components images \
    -x "*.DS_Store" \
    -x "dist/*" \
    -x "README.md" \
    -x "package.sh"
)

echo "Built $OUT"

if [[ "${1:-}" == "--deploy" ]]; then
  if [[ -z "${ROKU_IP:-}" || -z "${ROKU_PASSWORD:-}" ]]; then
    echo "Set ROKU_IP and ROKU_PASSWORD to deploy."
    exit 1
  fi
  echo "Deploying to http://$ROKU_IP/plugin_install ..."
  curl -sS --user "rokudev:${ROKU_PASSWORD}" \
    --digest \
    -F "mysubmit=Install" \
    -F "archive=@${OUT}" \
    "http://${ROKU_IP}/plugin_install"
  echo
  echo "Deploy request sent."
fi
