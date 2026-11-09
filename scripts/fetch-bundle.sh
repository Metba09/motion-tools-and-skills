#!/usr/bin/env bash
# [RÉSEAU GitHub] Récupère vendor/ (paquets hors-ligne) depuis la branche orpheline « sandbox-vendor », par niveau.
#   scripts/fetch-bundle.sh [<remote-ou-url>] [niveaux : core browser extras audio]   (défaut : origin, core browser)
# Clone « blobless » + checkout creux : seuls les niveaux demandés sont téléchargés, puis copiés dans vendor/ et vérifiés (SHA-256).
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
REMOTE=${1:-origin}; shift || true; TIERS=("$@"); [ ${#TIERS[@]} = 0 ] && TIERS=(core browser)
BRANCH=${VENDOR_BRANCH:-sandbox-vendor}
URL=$(git remote get-url "$REMOTE" 2>/dev/null || echo "$REMOTE")
dirs_for() { case "$1" in core) echo "vendor/npm-cache vendor/wheels" ;; browser) echo vendor/npm-cache-browser ;; extras) echo vendor/npm-cache-extras ;; audio) echo vendor/wheels-audio ;; *) die "niveau inconnu : $1 (core browser extras audio)" ;; esac; }
pat=(/vendor/SHA256SUMS /vendor/MANIFEST.json); for t in "${TIERS[@]}"; do for d in $(dirs_for "$t"); do pat+=("/$d/"); done; done
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git clone -q --depth 1 --branch "$BRANCH" --filter=blob:none --sparse "$URL" "$W/v"
git -C "$W/v" sparse-checkout set --no-cone "${pat[@]}"
mkdir -p "$VENDOR"
for t in "${TIERS[@]}"; do for d in $(dirs_for "$t"); do
  [ -d "$W/v/$d" ] || die "niveau absent de la branche $BRANCH : $t ($d)"
  rm -rf "${VENDOR:?}/${d#vendor/}"; cp -a "$W/v/$d" "$VENDOR/${d#vendor/}"
done; ok "niveau $t copié dans vendor/"; done
cp -a "$W/v/vendor/SHA256SUMS" "$W/v/vendor/MANIFEST.json" "$VENDOR/"
( cd "$VENDOR" && sha256sum --quiet --ignore-missing -c SHA256SUMS ) || die "empreintes SHA-256 invalides : vendor/ corrompu"
ok "empreintes conformes ; lancer « make setup »"
