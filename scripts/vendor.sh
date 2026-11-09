#!/usr/bin/env bash
# Régénère vendor/ (cache npm, wheels Python, polices). SEUL script qui a besoin du réseau
# (registre npm + PyPI) : à lancer par le mainteneur, pas dans une session hors-ligne.
#
#   scripts/vendor.sh npm      cache npm core + extras (lockfiles créés s'ils manquent)
#   scripts/vendor.sh python   wheels cp312 + cp313 (Linux x86_64) : core -> vendor/wheels, audio -> vendor/wheels-audio
#   scripts/vendor.sh fonts    polices @fontsource -> fichiers locaux (voir scripts/fonts.mjs)
#   scripts/vendor.sh sums     SHA256SUMS + MANIFEST.json
#   scripts/vendor.sh all      tout, dans cet ordre
#   --update                   regénère aussi les lockfiles existants (sinon on les respecte)
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
UPDATE=0; CMD=${1:-all}; [ "${2:-}" = --update ] && UPDATE=1; [ "$CMD" = --update ] && { UPDATE=1; CMD=all; }
npm_env

ensure_lock() {  # $1 = dossier projet
  if [ ! -f "$1/package-lock.json" ] || [ "$UPDATE" = 1 ]; then
    (cd "$1" && npm install --package-lock-only --ignore-scripts)
    ok "lockfile : $1"
  fi
}

fill_cache() {  # $1 = dossier de cache, puis les projets
  local cache=$1; shift
  rm -rf "$cache"; mkdir -p "$cache"
  for p in "$@"; do
    [ -f "$p/package.json" ] || die "projet absent : $p"
    ensure_lock "$p"
    local had=0; [ -d "$p/node_modules" ] && had=1
    # --ignore-scripts : on ne veut que les tarballs (les scripts d'installation tournent au `make setup`).
    (cd "$p" && npm ci --ignore-scripts --cache "$cache" >/dev/null)
    [ "$had" = 0 ] && rm -rf "$p/node_modules"
    ok "cache npm <- $p"
  done
  say "   $(du -sh "$cache" | cut -f1)  $cache"
}

vendor_npm() {
  fill_cache "$VENDOR/npm-cache" "${NODE_CORE[@]}"
  fill_cache "$VENDOR/npm-cache-extras" "${NODE_EXTRAS[@]}"
  fill_cache "$VENDOR/npm-cache-browser" "${NODE_BROWSER[@]}"
}

# Télécharge un niveau Python pour une version donnée, uniquement des wheels manylinux x86_64.
py_download() {  # $1=version (3.12) $2=dossier $3=fichier requirements
  pip download -q -d "$2" --only-binary=:all: --python-version "$1" --implementation cp \
    --platform manylinux2014_x86_64 --platform manylinux_2_17_x86_64 --platform manylinux_2_27_x86_64 \
    --platform manylinux_2_28_x86_64 --platform manylinux_2_34_x86_64 --platform manylinux_2_35_x86_64 \
    -r "$3" 2>&1 | grep -vE 'yanked|Reason for being' || true
}

vendor_python() {
  rm -rf "$VENDOR/wheels" "$VENDOR/wheels-audio"
  for v in 3.12 3.13; do
    local tag=cp${v/./}
    mkdir -p "$VENDOR/wheels/$tag" "$VENDOR/wheels-audio/$tag"
    py_download "$v" "$VENDOR/wheels/$tag" requirements/core.txt
    py_download "$v" "$VENDOR/wheels-audio/$tag" requirements/audio.txt
    # le niveau audio inclut core : on ne garde que ce qui n'est pas déjà dans wheels/
    for f in "$VENDOR/wheels/$tag"/*; do rm -f "$VENDOR/wheels-audio/$tag/$(basename "$f")"; done
    ok "wheels $tag : core $(du -sh "$VENDOR/wheels/$tag" | cut -f1), audio $(du -sh "$VENDOR/wheels-audio/$tag" | cut -f1)"
  done
}

vendor_fonts() { node scripts/fonts.mjs; }

vendor_sums() {
  rm -rf "$VENDOR"/*/_logs   # journaux de debug npm : inutiles, et npm les efface à l'usage
  (cd "$VENDOR" && find . -type f ! -name SHA256SUMS ! -name MANIFEST.json ! -path '*/_logs/*' -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
  python3 - "$VENDOR" <<'PY'
import json, os, sys, datetime
v = sys.argv[1]
def size(d):
    return sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(os.path.join(v, d)) for f in fs) if os.path.isdir(os.path.join(v, d)) else 0
m = {"generated": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
     "target": "linux-x64 glibc, Node >= 22.12, Python 3.12 ou 3.13",
     "dirs_bytes": {d: size(d) for d in ("npm-cache", "npm-cache-extras", "npm-cache-browser", "wheels", "wheels-audio")}}
json.dump(m, open(os.path.join(v, "MANIFEST.json"), "w"), indent=2)
print(json.dumps(m["dirs_bytes"]))
PY
  ok "SHA256SUMS + MANIFEST.json"
}

case "$CMD" in
  npm) vendor_npm ;;
  python) vendor_python ;;
  fonts) vendor_fonts ;;
  sums) vendor_sums ;;
  all) vendor_npm; vendor_python; vendor_fonts; vendor_sums ;;
  *) die "usage : vendor.sh {npm|python|fonts|sums|all} [--update]" ;;
esac
