#!/usr/bin/env bash
# Affiche (stdout) le chemin d'un Chrome/Chromium exécutable, ou échoue avec un message clair.
# Ordre : $CHROME_PATH > navigateur système > Chromium embarqué (make setup-browser).
. "$(dirname "$0")/lib.sh"

for c in "${CHROME_PATH:-}" google-chrome google-chrome-stable chromium chromium-browser chrome \
         /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser \
         "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
  [ -n "$c" ] || continue
  if [ -x "$c" ]; then printf '%s\n' "$c"; exit 0; fi
  if p=$(command -v "$c" 2>/dev/null); then printf '%s\n' "$p"; exit 0; fi
done

if [ -f "$ROOT/tools/chromium-bundled/node_modules/@sparticuz/chromium/package.json" ]; then
  node "$ROOT/tools/chromium-bundled/path.mjs"; echo
  exit 0
fi

warn "aucun Chrome/Chromium : lancer « make setup-browser » (Chromium embarqué, hors-ligne) ou définir CHROME_PATH"
exit 1
