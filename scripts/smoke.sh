#!/usr/bin/env bash
# Tests de bout en bout (plus lents, avec navigateur) : prouvent que la chaîne marche HORS-LIGNE dans ce sandbox.
#   scripts/smoke.sh            tout
#   scripts/smoke.sh fal python  seulement ces étapes
. "$(dirname "$0")/env.sh"
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
TMP=$(mktemp -d /tmp/motion-smoke.XXXXXX); trap 'rm -rf "$TMP"' EXIT
ko=(); only=("$@")
want() { [ ${#only[@]} = 0 ] && return 0; local x; for x in "${only[@]}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
stage() { local id=$1 name=$2; shift 2; want "$id" || return 0; printf '\n── %s\n' "$name"; if "$@"; then ok "$name"; else ko+=("$id"); warn "ÉCHEC : $name"; fi; }
need_chrome() { [ -n "${CHROME_PATH:-}" ] || { echo "aucun navigateur : make setup-browser" >&2; return 1; }; }

t_python() { "$(py_bin)" -I - <<'PY'
import numpy as np, scipy.signal as ss, soundfile as sf, soxr, io
from PIL import Image
sr = 24000; t = np.arange(sr) / sr; x = (0.4 * np.sin(2 * np.pi * 440 * t)).astype('float32')
buf = io.BytesIO(); sf.write(buf, x, sr, format='WAV'); buf.seek(0); y, r = sf.read(buf, dtype='float32')
assert r == sr and abs(y - x).max() < 1e-3, "aller-retour WAV"
z = soxr.resample(y, sr, 48000); assert abs(len(z) - 2 * sr) <= 2, "rééchantillonnage"
f, p = ss.welch(y, sr, nperseg=2048); assert abs(f[p.argmax()] - 440) < 20, "spectre"
Image.new('RGB', (64, 64), (200, 30, 30)).save(io.BytesIO(), 'PNG')
print('numpy', np.__version__, '| scipy ok | soundfile ok | soxr ok | pillow ok')
PY
}
t_fal() {  # pipeline dioramas complet avec le mock (aucune clé, aucun réseau)
  local d=$TMP/dioramas; mkdir -p "$d"
  ( cd starters/dioramas && tar --exclude=node_modules --exclude=dist -cf - . ) | ( cd "$d" && tar -xf - )
  ln -s "$ROOT/starters/dioramas/node_modules" "$d/node_modules"
  cat > "$d/job.json" <<'J'
{"images":[{"id":"smoke-box","prompt":"a small red wooden box"}],"meshes":[{"id":"smoke-box","image":"smoke-box"}]}
J
  ( cd "$d" && MOTION_OFFLINE=1 node scripts/gen.mjs all job.json ) || return 1
  head -c4 "$d/assets/raw/smoke-box.glb" | grep -q glTF || { echo "GLB invalide" >&2; return 1; }
  head -c4 "$d/assets/src/smoke-box.png" | grep -q PNG  || { echo "PNG invalide" >&2; return 1; }
  node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1]));if(m.meshes["smoke-box"].status!=="done")process.exit(1)' "$d/assets/manifest.json"
}
t_transcribe() {
  command -v ffmpeg >/dev/null || { echo "ffmpeg absent" >&2; return 1; }
  ffmpeg -v error -y -f lavfi -i "color=c=black:s=320x180:d=4:r=25" -f lavfi -i "sine=f=300:d=4" -shortest "$TMP/t.mp4"
  node skills/talking-head-b-roll/scripts/transcribe.mjs "$TMP/t.mp4" "$TMP/t.json" --script "Bonjour tout le monde. Ceci est un test." >/dev/null
  node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1]));if(j.engine!=="script"||j.words.length!==8)process.exit(1)' "$TMP/t.json"
}
t_dioramas_build() { ( cd starters/dioramas && [ -d node_modules ] && npx --no-install vite build --outDir "$TMP/dioramas-dist" --emptyOutDir >/dev/null ) && find "$TMP/dioramas-dist/examples" -name index.html | grep -q .; }
t_scaffold() {  # $1 = kinetic-reel | painted-animation ; copie le template, installe hors-ligne, rend une planche-contact
  need_chrome || return 1
  bash "skills/$1/scripts/new_project.sh" "$TMP/$1" >/dev/null || return 1
  ( cd "$TMP/$1" && timeout 240 npm run --silent sheet -- --soft-gl ) || return 1
  find "$TMP/$1/out" -name '*.jpg' -size +5k | grep -q .
}
t_lemo() { out=$(MOTION_OFFLINE=1 sh skills/lemo-opuscar/scripts/setup.sh) && echo "$out" | grep -q '^LIB=' && [ -f "$ROOT/.lib/lemo-opuscar/styles/art-deco/STYLE.md" ] && [ -f "$ROOT/.lib/lemo-opuscar/AGENTS.md" ]; }
t_gates() {  # les scripts réseau doivent REFUSER proprement (code 3) hors-ligne
  local s; for s in starters/mg-styles-15/lib/audio/tools/download_vcsl.sh skills/motion-designer/scripts/setup_kokoro.sh; do
    MOTION_OFFLINE=1 bash "$s" >/dev/null 2>&1; [ $? = 3 ] || { echo "$s n'a pas refusé" >&2; return 1; }
  done
  MOTION_OFFLINE=1 node tools/tidewater-asset-pipeline/audio/search.mjs >/dev/null 2>&1; [ $? = 3 ]
}

stage python  "python core (wheels)"                 t_python
stage fal     "mock fal : image + maillage (dioramas)" t_fal
stage transcribe "transcription hors-ligne (script)"  t_transcribe
stage lemo    "lemo-opuscar : bibliothèque locale"    t_lemo
stage gates   "garde-fous réseau (code 3)"            t_gates
stage build   "dioramas : vite build"                 t_dioramas_build
stage kinetic "kinetic-reel : projet + planche-contact (navigateur)" t_scaffold kinetic-reel
stage painted "painted-animation : projet + planche-contact (navigateur)" t_scaffold painted-animation

echo
[ ${#ko[@]} = 0 ] && { ok "SMOKE : tout est vert"; exit 0; }
die "smoke : ${#ko[@]} étape(s) en échec : ${ko[*]}"
