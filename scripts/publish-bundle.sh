#!/usr/bin/env bash
# [RÉSEAU GitHub, droit d'écriture requis] Publie dist-bundle/ sur la branche orpheline « sandbox-bundle » du dépôt.
#   scripts/publish-bundle.sh [<remote-ou-url>]     (défaut : origin)   ; lancer d'abord `make bundle`
# La branche ne contient QUE les archives (pas d'historique commun avec main) : un clone partiel la récupère seule.
# Les gros fichiers sont découpés en morceaux de 90 Mo (limite GitHub : 100 Mo par fichier).
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
REMOTE=${1:-origin}; BRANCH=${BUNDLE_BRANCH:-sandbox-bundle}
SRC=${BUNDLE_DIR:-dist-bundle}   # dist-bundle (make bundle) ou dist-release (make release)
[ -d "$SRC" ] || die "$SRC absent : lancer « make bundle » ou « make release » d'abord"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git -C "$W" init -q -b "$BRANCH"
git -C "$W" config user.name "${GIT_AUTHOR_NAME:-bundle}"; git -C "$W" config user.email "${GIT_AUTHOR_EMAIL:-bundle@localhost}"
for f in "$SRC"/*.tar.gz; do
  n=$(basename "$f")
  if [ "$(stat -c %s "$f")" -gt 94371840 ]; then split -b 90M -d -a 3 "$f" "$W/$n.part-"; else cp "$f" "$W/$n"; fi
done
if [ -f "$SRC/SHA256SUMS" ]; then cp "$SRC/SHA256SUMS" "$W/SHA256SUMS"; else cat "$SRC"/*.sha256 > "$W/SHA256SUMS"; fi
printf 'Bundle hors-ligne de motion-tools-and-skills (genere par scripts/publish-bundle.sh).\nArchives > 90 Mo : fichiers NOM.tar.gz.part-000, -001... Reconstituer puis verifier :\n  cat NOM.tar.gz.part-* > NOM.tar.gz && sha256sum -c SHA256SUMS\nPuis : tar xzf NOM.tar.gz && cd motion-tools-bundle && bash scripts/run.sh setup && bash scripts/check.sh\n' > "$W/README.txt"
git -C "$W" add -A; git -C "$W" commit -q -m "sandbox-bundle $(date -u +%F)"
git -C "$W" push --force "$(git -C "$ROOT" remote get-url "$REMOTE" 2>/dev/null || echo "$REMOTE")" "$BRANCH:$BRANCH"
ok "branche $BRANCH publiée sur $REMOTE"
