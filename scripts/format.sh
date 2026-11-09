#!/usr/bin/env bash
# Hygiène des fichiers DU BUNDLE (scripts/, Makefile, setup.sh, requirements/, .env.example) :
# fins de ligne LF, pas d'espace en fin de ligne, newline final. L'amont n'a pas de formateur : on ne touche
# JAMAIS aux fichiers des skills / starters / tools.
#   scripts/format.sh           vérifie (code 1 s'il y a des écarts)
#   scripts/format.sh --write   corrige
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
mode=check; [ "${1:-}" = --write ] && mode=write
files=$( { printf '%s\n' scripts/* scripts/sandbox/* sandbox/BUNDLE.json Makefile setup.sh .env.example requirements/* tools/chromium-bundled/*.json tools/chromium-bundled/*.mjs tools/chromium-bundled/*.md
           find .claude -type f 2>/dev/null; } | grep -v '\.woff2$' | sort -u || true )
bad=0
for f in $files; do
  [ -f "$f" ] || continue
  if grep -q $'\r' "$f" || grep -qE '[[:blank:]]+$' "$f" || [ -n "$(tail -c1 "$f")" ]; then
    if [ $mode = write ]; then sed -i 's/\r$//; s/[[:blank:]]\+$//' "$f"; [ -n "$(tail -c1 "$f")" ] && printf '\n' >> "$f"; ok "corrigé $f"
    else warn "à corriger : $f"; bad=$((bad+1)); fi
  fi
done
[ $bad = 0 ] && ok "format : propre" || die "format : $bad fichier(s) à corriger (scripts/format.sh --write)"
