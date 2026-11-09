#!/bin/bash
# args: key path url
# --- Bundle hors-ligne : ce script télécharge ou installe depuis Internet. Refusé tant que MOTION_OFFLINE != 0.
[ "${MOTION_OFFLINE:-1}" = 0 ] || { echo "✗ $(basename "$0") : accès réseau requis ; le sandbox est hors-ligne (MOTION_OFFLINE=1). Voir CLAUDE.md « Session Chat »." >&2; exit 3; }
key="$1"; path="$2"; url="$3"
fn=$(basename "$path")
mkdir -p "/tmp/vcsl_raw/$key"
out="/tmp/vcsl_raw/$key/$fn"
if [ ! -s "$out" ]; then
  curl -s -f -L --retry 3 -m 300 -o "$out" "$url" || echo "FAIL $url"
fi
