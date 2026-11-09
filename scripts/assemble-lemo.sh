#!/usr/bin/env bash
# Assemble, par liens symboliques, la « bibliothèque » que le skill lemo-opuscar attend ($LIB), à partir des
# morceaux déjà présents dans ce dépôt. Idempotent. Aucun réseau. Résultat : .lib/lemo-opuscar/
. "$(dirname "$0")/lib.sh"
LIB="$ROOT/.lib/lemo-opuscar"
mkdir -p "$LIB/.venv/bin"
R=../..   # .lib/lemo-opuscar -> racine du dépôt : liens relatifs, le dépôt reste déplaçable
link() { ln -sfn "$1" "$2"; }

link "$R/tools/lemo-core/core"   "$LIB/core"
link "$R/tools/lemo-core/tools"  "$LIB/tools"
link "$R/prompts/film-styles"    "$LIB/styles"
for f in AGENTS DIRECTOR TECHNIQUE MAINTAINING MY-STYLES; do link "$R/docs/guides/lemo-opuscar/$f.md" "$LIB/$f.md"; done
for f in package.json package-lock.json requirements.txt requirements-voice.txt requirements-music.txt; do
  link "$R/tools/lemo-core/$f" "$LIB/$f"
done
link "$R/tools/lemo-core/node_modules" "$LIB/node_modules"   # vide tant que ./setup.sh n'a pas tourné
# Les guides appellent "$LIB/.venv/bin/python" : on le fait pointer vers le Python du système (paquets installés par setup.sh).
py=$(py_bin)
for n in python python3; do link "$py" "$LIB/.venv/bin/$n"; done
printf '%s\n' "$LIB"
