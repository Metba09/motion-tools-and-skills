#!/usr/bin/env bash
# Installation HORS-LIGNE, idempotente, sans aucune question. À relancer à chaque nouvelle session
# (le sandbox repart de zéro) : ce qui est déjà installé et à jour est sauté.
#
#   ./setup.sh            noyau : npm (9 projets) + Python « core » (numpy, scipy, soundfile, soxr, pillow)
#   ./setup.sh browser    Chromium embarqué (utile seulement s'il n'y a aucun Chrome système)
#   ./setup.sh extras     Remotion + tidewater (npm)
#   ./setup.sh audio      Python « audio » seulement (numba, librosa, pedalboard, matplotlib…)
#   ./setup.sh all        tout
#
# Source unique des paquets : vendor/ (cache npm + wheels). Aucun accès réseau n'est tenté.
. "$(dirname "$0")/scripts/lib.sh"
cd "$ROOT"
npm_env
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 PUPPETEER_SKIP_DOWNLOAD=1 PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 NPM_CONFIG_OFFLINE=true

WHAT=${1:-core}
case "$WHAT" in core|browser|extras|audio|all) ;; *) die "usage : ./setup.sh [core|browser|extras|audio|all]" ;; esac

node_ok || die "Node >= 22.12 requis (trouvé : $(node -v 2>/dev/null || echo aucun))"
command -v npm >/dev/null || die "npm introuvable"
[ -d "$VENDOR" ] || die "vendor/ absent. Récupérer le bundle : scripts/fetch-bundle.sh (GitHub, branche sandbox-vendor) — ou le régénérer avec scripts/vendor.sh (réseau npm/PyPI requis)."

# --- npm ---------------------------------------------------------------------------------------------------
install_node_tier() {  # $1 = nom du cache (npm-cache, npm-cache-extras…), puis la liste des projets
  local cache="$VENDOR/$1"; shift
  [ -d "$cache/_cacache" ] || die "cache npm absent : $cache (niveau non récupéré : scripts/fetch-bundle.sh <remote> core browser extras audio)"
  local p stamp want
  for p in "$@"; do
    [ -f "$p/package-lock.json" ] || die "lockfile absent : $p/package-lock.json"
    want="$(lock_hash "$p")-node$(node -p 'process.versions.node.split(".")[0]')"
    stamp="$p/node_modules/.motion-stamp"
    if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$want" ]; then ok "à jour        $p"; continue; fi
    printf '… installation %s\n' "$p"
    if ! log=$(cd "$p" && npm ci --offline --no-audit --no-fund --cache "$cache" 2>&1); then
      printf '%s\n' "$log" | tail -15 >&2
      die "npm ci a échoué dans $p (cache : $cache)"
    fi
    printf '%s' "$want" > "$stamp"
    ok "installé      $p"
  done
}

# --- Python ------------------------------------------------------------------------------------------------
py_tag() { "$(py_bin)" -c 'import sys;print(f"cp{sys.version_info.major}{sys.version_info.minor}")'; }

install_py_tier() {  # $1 = core|audio  $2 = dossier wheels  $3 = module de test d'import
  local tier=$1 dir=$2 probe=$3 tag py req="$ROOT/requirements/$1.txt"
  py=$(py_bin); tag=$(py_tag)
  if [ ! -d "$dir/$tag" ]; then
    warn "Python $tag : aucune wheel dans $dir/$tag -> niveau Python « $tier » SAUTÉ (les outils Node restent utilisables)."
    PY_PARTIAL=1; return 0
  fi
  local stamp="$HOME/.cache/motion-bundle/py-$tier.stamp" want
  want="$(sha256sum "$req" | cut -d' ' -f1)-$tag"
  if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$want" ] && "$py" -c "$probe" 2>/dev/null; then ok "à jour        python/$tier ($tag)"; return 0; fi
  printf '… installation python/%s (%s)\n' "$tier" "$tag"
  local finds=(--find-links "$VENDOR/wheels/$tag")
  [ "$tier" = audio ] && finds+=(--find-links "$dir/$tag")
  local opts=(--disable-pip-version-check --quiet "${finds[@]}" -r "$req")
  if ! "$py" -m pip install --no-index --break-system-packages "${opts[@]}" 2>/tmp/motion-pip.err; then
    # paquet système (apt) qu'on ne peut pas désinstaller : on installe à côté
    "$py" -m pip install --no-index --break-system-packages --ignore-installed "${opts[@]}" 2>>/tmp/motion-pip.err \
      || { tail -12 /tmp/motion-pip.err >&2; die "pip a échoué (niveau $tier, $tag)"; }
  fi
  mkdir -p "$(dirname "$stamp")"; printf '%s' "$want" > "$stamp"
  ok "installé      python/$tier ($tag)"
}

PY_PARTIAL=0
case "$WHAT" in
  core|all)
    say "== npm (noyau)";   install_node_tier npm-cache "${NODE_CORE[@]}"
    say "== python (core)"; install_py_tier core "$VENDOR/wheels" 'import numpy, scipy, soundfile, soxr, PIL'
    bash "$ROOT/scripts/assemble-lemo.sh" >/dev/null && ok "bibliothèque lemo-opuscar assemblée (.lib/lemo-opuscar)"
    ;;
esac
case "$WHAT" in browser|all)
  say "== navigateur (Chromium embarqué)"; install_node_tier npm-cache-browser "${NODE_BROWSER[@]}" ;;
esac
case "$WHAT" in extras|all)
  say "== npm (extras)";   install_node_tier npm-cache-extras "${NODE_EXTRAS[@]}" ;;
esac
case "$WHAT" in audio|all)
  say "== python (audio)"; install_py_tier audio "$VENDOR/wheels-audio" 'import numba, librosa, pedalboard, pyloudnorm, matplotlib' ;;
esac

say ""
if [ "$PY_PARTIAL" = 1 ]; then warn "installation PARTIELLE (voir les avertissements Python ci-dessus)"; else ok "setup « $WHAT » terminé"; fi
say "Étape suivante : make doctor   puis   make check"
