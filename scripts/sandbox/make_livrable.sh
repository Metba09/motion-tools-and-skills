#!/usr/bin/env bash
# Construit le livrable miroir (tarball de SOURCE + SHA256SUMS + restore.sh + README) depuis un commit ANTÉRIEUR au pointeur.
#   scripts/sandbox/make_livrable.sh <source_commit> <dossier_sortie> [nom]
# Le tarball = `git archive <source_commit>` SANS les gros dossiers vendor/ (cache npm, wheels) : les lockfiles et
# vendor/SHA256SUMS y sont, les paquets restent dans Git (branche du dépôt) et ne sont pas dupliqués dans le miroir.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd); cd "$ROOT"
SRC=${1:?usage : make_livrable.sh <source_commit> <dossier_sortie> [nom]}; OUT=${2:?dossier de sortie}; NOM=${3:-motion-tools-bundle}
SRC=$(git rev-parse --verify "$SRC^{commit}")
TAR="$NOM-source.tar.gz"; mkdir -p "$OUT"
git archive --format=tar --prefix=motion-tools-and-skills/ "$SRC" -- . \
  ':(exclude)vendor/npm-cache' ':(exclude)vendor/npm-cache-extras' ':(exclude)vendor/npm-cache-browser' \
  ':(exclude)vendor/wheels' ':(exclude)vendor/wheels-audio' | gzip -n -9 > "$OUT/$TAR"
cat > "$OUT/restore.sh" <<'RESTORE'
#!/usr/bin/env bash
# Restaure la SOURCE du bundle (sans les paquets vendor/, qui sont dans la branche offline-bundle du dépôt).
#   ./restore.sh [dossier_cible]      (défaut : ./motion-tools-and-skills)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); DEST=${1:-./motion-tools-and-skills}
( cd "$HERE" && sha256sum -c SHA256SUMS )                       # vérifie AVANT d'ouvrir l'archive
mkdir -p "$DEST"; tar xzf "$HERE"/*-source.tar.gz -C "$DEST" --strip-components=1
echo "Source restaurée dans $DEST. Les paquets : cloner la branche offline-bundle de Metba09/motion-tools-and-skills"
echo "Le pointeur sandbox/BUNDLE.json est dans cette branche (il ne peut pas être dans le tarball : hash circulaire)."
RESTORE
chmod +x "$OUT/restore.sh"
cat > "$OUT/README.md" <<README
# $NOM (miroir)

Miroir **de la source** (lockfiles, scripts, CLAUDE.md…) du bundle hors-ligne de Metba09/motion-tools-and-skills.
Le **dépôt (branche \`offline-bundle\`) est la source de vérité** ; ce dossier n'en est qu'un miroir vérifiable.

- \`$TAR\` : \`git archive $SRC\` sans \`vendor/npm-cache*\` ni \`vendor/wheels*\` (les paquets restent dans Git, pas ici : taille).
- Le pointeur \`sandbox/BUNDLE.json\` (hash de ce tarball + empreintes des lockfiles) est committé APRÈS le tarball : il n'est donc pas dedans.
- Vérifier : \`python3 scripts/sandbox/verify_bundle.py --livrable <ce dossier>\` (depuis le dépôt) ou \`./restore.sh\`.
README
( cd "$OUT" && sha256sum "$TAR" restore.sh > SHA256SUMS )
echo "source_commit=$SRC"; echo "tarball=$OUT/$TAR"; ( cd "$OUT" && cat SHA256SUMS )
