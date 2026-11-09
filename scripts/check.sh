#!/usr/bin/env bash
# Vérification du bundle, à lancer à la main avant de conclure (rien ne se déclenche tout seul).
#   scripts/check.sh          rapide : intégrité SHA-256 + runtimes + test de fumée sans navigateur
#   scripts/check.sh --full   + doctor, lint, format, tests unitaires (= make check)
# Codes de sortie : 0 tout vert | 10 intégrité | 20 runtime ou setup manquant | 30 fumée/tests en échec.
. "$(dirname "$0")/env.sh"
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
FULL=0; case "${1:-}" in "") ;; --full) FULL=1 ;; *) die "usage : scripts/check.sh [--full]" ;; esac
t0=$SECONDS
fail() { local code=$1; shift; printf '%s✗%s %s\n' "$C_KO" "$C_OFF" "$*" >&2; exit "$code"; }

say "== intégrité"
if [ -f MANIFEST.sha256 ]; then
  sha256sum --quiet -c MANIFEST.sha256 || fail 10 "MANIFEST.sha256 : fichier(s) altéré(s) ou manquant(s) (voir ci-dessus)"
  ok "MANIFEST.sha256 : $(wc -l < MANIFEST.sha256) fichiers conformes"
elif [ -f "$VENDOR/SHA256SUMS" ]; then
  (cd "$VENDOR" && sha256sum --quiet --ignore-missing -c SHA256SUMS) || fail 10 "vendor/SHA256SUMS : écart (voir ci-dessus)"
  ok "vendor/SHA256SUMS : niveaux présents conformes"
else fail 10 "ni MANIFEST.sha256 ni vendor/SHA256SUMS : bundle incomplet"; fi

say "== runtimes"
node_ok || fail 20 "Node >= 22.12 requis (trouvé : $(node -v 2>/dev/null || echo aucun))"
tag=$("$(py_bin)" -c 'import sys;print(f"cp{sys.version_info.major}{sys.version_info.minor}")')
case "$tag" in cp312|cp313) ok "node $(node -v), python $tag" ;; *) fail 20 "Python $tag : wheels vendorisées pour cp312 et cp313 seulement" ;; esac
[ -d "${NODE_CORE[0]}/node_modules" ] || fail 20 "installation absente : lancer d'abord  bash scripts/run.sh setup"

if [ "$FULL" = 1 ]; then
  ko=()
  stage() { local name=$1; shift; printf '\n── %s\n' "$name"; if "$@"; then ok "$name"; else ko+=("$name"); warn "ÉCHEC : $name"; fi; }
  stage "doctor"          bash scripts/doctor.sh
  stage "lint"            bash scripts/lint.sh
  stage "format (bundle)" bash scripts/format.sh
  stage "tests"           bash scripts/test.sh
  echo
  [ ${#ko[@]} = 0 ] || fail 30 "${#ko[@]} étape(s) en échec : ${ko[*]}"
  ok "TOUT EST VERT ($((SECONDS-t0)) s)"
else
  say "== test de fumée (sans navigateur)"
  bash scripts/smoke.sh python fal transcribe lemo gates || fail 30 "test de fumée en échec"
  ok "CHECK RAPIDE VERT ($((SECONDS-t0)) s)"
fi
