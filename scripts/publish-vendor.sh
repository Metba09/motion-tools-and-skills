#!/usr/bin/env bash
# [RÉSEAU GitHub, droit d'écriture requis] Publie vendor/ (fichiers bruts) sur la branche ORPHELINE « sandbox-vendor ».
#   scripts/publish-vendor.sh [<remote-ou-url>]      (défaut : origin)
# Orpheline = aucun historique commun avec main : les clones de main ne téléchargent rien de tout ça.
# Un commit par niveau, poussés un à un (limite de taille des pushes). Chaque publication REMPLACE la branche (force) :
# l'historique ne grossit pas. Les fichiers sont conservés octet pour octet (.gitattributes de la branche : -text).
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
REMOTE=${1:-origin}; BRANCH=${VENDOR_BRANCH:-sandbox-vendor}
URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "$REMOTE")
for d in npm-cache wheels; do [ -d "$VENDOR/$d" ] || die "vendor/$d absent : rien à publier (lancer scripts/fetch-bundle.sh ou scripts/vendor.sh)"; done
( cd "$VENDOR" && sha256sum --quiet --ignore-missing -c SHA256SUMS ) || die "vendor/ ne concorde pas avec SHA256SUMS : ne pas publier"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
g() { git -C "$W" -c user.name="${GIT_AUTHOR_NAME:-bundle}" -c user.email="${GIT_AUTHOR_EMAIL:-bundle@localhost}" "$@"; }
git -C "$W" init -q -b "$BRANCH"
printf '* -text -diff -merge\n' > "$W/.gitattributes"
printf 'Paquets hors-ligne de motion-tools-and-skills (genere par scripts/publish-vendor.sh).\nRecuperer par niveau : scripts/fetch-bundle.sh [remote] core browser extras audio\n' > "$W/README.txt"
mkdir -p "$W/vendor"; cp -a "$VENDOR/SHA256SUMS" "$VENDOR/MANIFEST.json" "$W/vendor/"
g add -A; g commit -q -m "vendor : empreintes et manifeste"
first=1
for d in npm-cache wheels npm-cache-browser npm-cache-extras wheels-audio; do
  [ -d "$VENDOR/$d" ] || { warn "niveau absent, sauté : $d"; continue; }
  cp -a "$VENDOR/$d" "$W/vendor/$d"; rm -rf "$W/vendor/$d/_logs"
  g add -A; g commit -q -m "vendor : $d"
  git -C "$W" push -q --force "$URL" "$BRANCH:$BRANCH" 2>&1 | tail -2
  ok "poussé : $d ($(du -sh "$VENDOR/$d" | cut -f1))"; first=0
done
ok "branche $BRANCH publiée sur $REMOTE"
