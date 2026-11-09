#!/usr/bin/env bash
# new_project.sh <target-dir> [--keep-demo]
# Scaffolds a painted-animation project from the skill's template, installs deps and checks the toolchain.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
TARGET="${1:?usage: new_project.sh <target-dir> [--keep-demo]}"
KEEP_DEMO="${2:-}"

if [ -e "$TARGET/studio.html" ]; then echo "error: $TARGET already has a studio.html; not overwriting" >&2; exit 1; fi
mkdir -p "$TARGET"
( cd "$SKILL_DIR/template" && tar --exclude=node_modules -cf - . ) | ( cd "$TARGET" && tar -xf - )   # rsync is not always installed
mkdir -p "$TARGET/assets" "$TARGET/out/check"

# The demo is an example, not a template: unless asked, unhook it so the new video starts clean.
if [ "$KEEP_DEMO" != "--keep-demo" ]; then
  sed -i.bak 's|<script src="src/scenes/demo.js"></script>|<!-- <script src="src/scenes/demo.js"></script>  (example only) -->|' "$TARGET/studio.html" && rm -f "$TARGET/studio.html.bak"
fi

cd "$TARGET"
echo "== installing p5, p5.brush, puppeteer-core"
# Offline bundle (MOTION_OFFLINE != 0, the default): install from the vendored npm cache, no network.
if [ "${MOTION_OFFLINE:-1}" != 0 ]; then
  [ -f package-lock.json ] || { echo "error: package-lock.json missing in the template" >&2; exit 1; }
  npm ci --offline --silent --no-audit --no-fund --cache "$REPO_ROOT/vendor/npm-cache"
else
  npm install --silent
fi

echo "== toolchain"
command -v node   >/dev/null && echo "node   $(node -v)"   || echo "MISSING: node"
command -v ffmpeg >/dev/null && echo "ffmpeg ok"           || echo "MISSING: ffmpeg (brew install ffmpeg)"
if c=$("$REPO_ROOT/scripts/chrome.sh" 2>/dev/null); then echo "chrome $c"
else echo "MISSING: Chrome (make setup-browser at the repo root, or pass --chrome=<path> to render.mjs)"; fi
echo "== ready: $TARGET"
