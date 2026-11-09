#!/usr/bin/env bash
# Diagnostic de l'environnement : outils, navigateur, vendor/, niveaux installés. Code 1 si un prérequis DUR manque.
#   scripts/doctor.sh            rapport
#   scripts/doctor.sh --verify   + contrôle SHA-256 de vendor/ (lent : lit tout le cache)
. "$(dirname "$0")/lib.sh"
fail=0
row() { printf '  %-22s %s\n' "$1" "$2"; }
good() { row "$1" "${C_OK}✓${C_OFF} $2"; }
miss() { row "$1" "${C_KO}✗${C_OFF} $2"; fail=1; }
soft() { row "$1" "${C_WARN}!${C_OFF} $2"; }

say "== Outils"
if node_ok; then good node "$(node -v)"; else miss node "Node >= 22.12 requis (trouvé : $(node -v 2>/dev/null || echo aucun))"; fi
command -v npm >/dev/null && good npm "$(npm -v)" || miss npm "introuvable"
py=$(command -v python3 || true); if [ -n "$py" ]; then good python "$("$py" -V 2>&1) ($("$py" -c 'import sys;print(f"cp{sys.version_info.major}{sys.version_info.minor}")'))"; else miss python3 "introuvable"; fi
command -v ffmpeg >/dev/null && good ffmpeg "$(ffmpeg -version | head -1 | cut -d' ' -f3)" || soft ffmpeg "absent : encodage vidéo/audio impossible"
command -v ffprobe >/dev/null && good ffprobe "ok" || soft ffprobe "absent"
command -v git >/dev/null && good git "$(git --version | cut -d' ' -f3)" || soft git "absent"
command -v blender >/dev/null && good blender "présent" || soft blender "absent (tools/tidewater-asset-pipeline/blender/* inutilisable)"
if c=$("$ROOT/scripts/chrome.sh" 2>/dev/null); then good navigateur "$c"; else soft navigateur "aucun : make setup-browser (Chromium embarqué)"; fi

say "== Bundle (vendor/)"
for d in npm-cache npm-cache-browser npm-cache-extras wheels wheels-audio; do
  if [ -d "$VENDOR/$d" ]; then good "$d" "$(du -sh "$VENDOR/$d" | cut -f1)"; else
    case $d in npm-cache|wheels) miss "$d" "absent : scripts/fetch-bundle.sh" ;; *) soft "$d" "non inclus (niveau optionnel)" ;; esac
  fi
done
tag=$("${py:-python3}" -c 'import sys;print(f"cp{sys.version_info.major}{sys.version_info.minor}")' 2>/dev/null || echo '?')
[ -d "$VENDOR/wheels/$tag" ] && good "wheels $tag" "ok pour ce Python" || soft "wheels $tag" "aucune wheel pour ce Python : niveau Python sauté"

say "== Installé"
for p in "${NODE_CORE[@]}"; do
  if [ -f "$p/node_modules/.motion-stamp" ] && [ "$(cut -d- -f1 "$p/node_modules/.motion-stamp")" = "$(lock_hash "$p")" ]; then good "$(basename "$(dirname "$p")")/$(basename "$p")" "à jour"
  else soft "$p" "non installé : make setup"; fi
done
"${py:-python3}" -c 'import numpy, scipy, soundfile, soxr, PIL' 2>/dev/null && good "python core" "numpy scipy soundfile soxr pillow" || soft "python core" "non installé : make setup"
[ -f .lib/lemo-opuscar/AGENTS.md ] && good "lemo-opuscar" ".lib/lemo-opuscar" || soft "lemo-opuscar" "non assemblé : make setup"

say "== Mode"
row MOTION_OFFLINE "${MOTION_OFFLINE:-1}  (1 = aucun accès réseau, défaut)"

if [ "${1:-}" = --verify ]; then
  say "== Intégrité (SHA-256)"
  [ -f "$VENDOR/SHA256SUMS" ] || die "vendor/SHA256SUMS absent"
  (cd "$VENDOR" && sha256sum --quiet --ignore-missing -c SHA256SUMS) && good vendor "empreintes concordantes (niveaux présents)" || miss vendor "empreintes divergentes (bundle corrompu ou modifié)"
fi
[ $fail = 0 ] && ok "doctor : prérequis durs satisfaits" || die "doctor : prérequis manquants (voir ✗)"
