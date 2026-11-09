#!/bin/sh
# fetch.sh <repo path> : one file of the Rocketbox repo (LFS media URL, raw fallback), keeping its repo path
# --- Bundle hors-ligne : ce script télécharge ou installe depuis Internet. Refusé tant que MOTION_OFFLINE != 0.
[ "${MOTION_OFFLINE:-1}" = 0 ] || { echo "✗ $(basename "$0") : accès réseau requis ; le sandbox est hors-ligne (MOTION_OFFLINE=1). Voir CLAUDE.md « Session Chat »." >&2; exit 3; }
p="$1"; out="$(echo "$p" | sed 's#.*/Assets/##')"; mkdir -p "$(dirname "$out")"
u=$(printf '%s' "$p" | sed 's/ /%20/g')
curl -sfL -o "$out" "https://media.githubusercontent.com/media/microsoft/Microsoft-Rocketbox/master/$u" || curl -sfL -o "$out" "https://raw.githubusercontent.com/microsoft/Microsoft-Rocketbox/master/$u"
