# A/B test older PlexFlix hero builds
#
# From your plexflix repo root. Sideload roku/dist/plexflix-roku.zip after each package.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BRANCH="$(git branch --show-current)"
echo "Current branch: ${BRANCH:-detached}"
echo "Stash any local edits first if needed: git stash push -u -m 'wip before hero A/B'"
echo

package_at() {
  local ref="$1"
  local label="$2"
  echo "=== ${label} (${ref}) ==="
  git checkout --detach "${ref}"
  (cd roku && ./package.sh)
  echo "Sideload: ${ROOT}/roku/dist/plexflix-roku.zip"
  echo "Press Enter after testing to continue..."
  read -r _
}

# Version → commit map (from git history)
package_at 254a4ea "v0.4.1 — tall hero, soft washes"
package_at 30d5f0d "v0.4.2 — tall hero, lighter washes"
package_at 813ed5a "v0.4.3 — 680px crop hero"
package_at 9e29ab1 "v0.4.5 — hero seam fix"
package_at 2e8ac35 "v0.4.7 — peeks + sidebar version"

echo "Returning to ${BRANCH:-main}..."
if [[ -n "${BRANCH}" ]]; then
  git checkout "${BRANCH}"
else
  git checkout cursor/roku-plexflix-channel-9284
fi

echo
echo "Or jump to one manually:"
echo "  git checkout --detach 254a4ea && (cd roku && ./package.sh)   # 0.4.1"
echo "  git checkout --detach 30d5f0d && (cd roku && ./package.sh)   # 0.4.2"
echo "  git checkout --detach 813ed5a && (cd roku && ./package.sh)   # 0.4.3"
echo "  git checkout cursor/roku-plexflix-channel-9284               # back"
