# shellcheck shell=bash
# À SOURCER (pas à exécuter) avant de lancer un outil du dépôt :   . scripts/env.sh
# Met l'environnement en mode « hors-ligne » et pointe tous les outils vers le même navigateur.
# Ne fait pas `set -e` : on ne veut pas tuer le shell de l'appelant.

MOTION_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
export MOTION_ROOT

# .env (copie de .env.example) : seulement des réglages, jamais requis.
if [ -f "$MOTION_ROOT/.env" ]; then set -a; . "$MOTION_ROOT/.env"; set +a; fi

# Hors-ligne PAR DÉFAUT : tout script qui voudrait Internet s'arrête net (code 3) au lieu de bloquer.
export MOTION_OFFLINE="${MOTION_OFFLINE:-1}"
if [ "$MOTION_OFFLINE" != 0 ]; then
  export NPM_CONFIG_OFFLINE=true HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 HF_DATASETS_OFFLINE=1
  export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 PUPPETEER_SKIP_DOWNLOAD=1 PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1
  export NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false NPM_CONFIG_UPDATE_NOTIFIER=false
fi

# Un seul navigateur pour tous : chaque projet lit sa propre variable.
if [ -z "${CHROME_PATH:-}" ]; then CHROME_PATH=$("$MOTION_ROOT/scripts/chrome.sh" 2>/dev/null) || CHROME_PATH=; fi
if [ -n "$CHROME_PATH" ]; then
  export CHROME_PATH
  export PLAYWRIGHT_CHROME="${PLAYWRIGHT_CHROME:-$CHROME_PATH}" CHROMIUM_PATH="${CHROMIUM_PATH:-$CHROME_PATH}" \
         DIORAMA_CHROME="${DIORAMA_CHROME:-$CHROME_PATH}" MG_CHROME="${MG_CHROME:-$CHROME_PATH}" \
         PUPPETEER_EXECUTABLE_PATH="${PUPPETEER_EXECUTABLE_PATH:-$CHROME_PATH}"
fi
