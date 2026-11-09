#!/usr/bin/env bash
# Tests unitaires existants du dépôt (rapides, sans navigateur). Nécessite `make setup` pour papermotion.
. "$(dirname "$0")/env.sh"
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
ko=()
stage() { local name=$1; shift; printf '\n── %s\n' "$name"; if "$@"; then ok "$name"; else ko+=("$name"); warn "ÉCHEC : $name"; fi; }
pm() { cd starters/papermotion && { [ -d node_modules ] || { echo "node_modules absent -> make setup" >&2; return 1; }; } && "$@"; }

# anatomy : les tests supposent des pages déjà construites (générées ici, ignorées par git) ; les 3 tests
# react-*.test.mjs exigent esbuild, absent du bundle (amont sans package.json) -> exclus, voir CLAUDE.md.
anatomy() {
  cd skills/anatomy
  (cd examples/dial-indicator && node build.mjs --light >/dev/null)
  (cd examples/dial-indicator && node build.mjs >/dev/null)
  (cd examples/turning-dial && node build.mjs --verify --light >/dev/null)
  local f files=(); for f in scripts/*.test.mjs; do case $f in */react-*) ;; *) files+=("$f") ;; esac; done
  node --test "${files[@]}"
}
stage "anatomy (node --test)"        bash -c "$(declare -f anatomy); anatomy"
stage "talking-head timing"          node --test skills/talking-head-b-roll/scripts/timing.test.mjs
stage "papermotion : vitest"         bash -c "$(declare -f pm); pm npm test --silent"
stage "papermotion : tsc --noEmit"   bash -c "$(declare -f pm); pm npm run --silent typecheck"

[ ${#ko[@]} = 0 ] && { ok "tests : tout est vert"; exit 0; }
die "tests : ${#ko[@]} étape(s) en échec : ${ko[*]}"
