# shellcheck shell=bash
# Fonctions communes aux scripts du bundle. À sourcer : . "$(dirname "$0")/lib.sh"
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VENDOR=${MOTION_VENDOR:-$ROOT/vendor}
# shellcheck source=projects.sh
. "$ROOT/scripts/projects.sh"

if [ -t 1 ]; then C_OK=$'\033[32m'; C_KO=$'\033[31m'; C_WARN=$'\033[33m'; C_OFF=$'\033[0m'; else C_OK=; C_KO=; C_WARN=; C_OFF=; fi
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$C_KO" "$C_OFF" "$*" >&2; exit 1; }

# npm toujours hors-ligne et sans bruit : le cache vendorisé est la seule source.
npm_env() {
  export NPM_CONFIG_FUND=false NPM_CONFIG_AUDIT=false NPM_CONFIG_UPDATE_NOTIFIER=false \
         NPM_CONFIG_PROGRESS=false NPM_CONFIG_LOGLEVEL=${NPM_CONFIG_LOGLEVEL:-error}
}

# Empreinte du lockfile : sert à savoir si node_modules est déjà à jour (idempotence).
lock_hash() { sha256sum "$1/package-lock.json" | cut -d' ' -f1; }

# Version majeure.mineure de Node >= 22.12 ?
node_ok() {
  command -v node >/dev/null || return 1
  node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=12)?0:1)'
}

py_bin() { command -v python3 || command -v python || die "python3 introuvable"; }
