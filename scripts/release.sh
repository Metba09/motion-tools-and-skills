#!/usr/bin/env bash
# Assemble l'archive unique du bundle (outil de maintenance, sans réseau). Travaille sur une COPIE du commit HEAD :
# le dépôt n'est jamais modifié.
#   scripts/release.sh [--version 1.0.0] [--tiers core,browser,extras,audio] [--out DIR]
# Sortie : DIR/motion-tools-bundle-vX.Y.Z.tar.gz (+ .sha256), DIR/stage/ (contenu avant compression).
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
VERSION=1.0.0; TIERS=core,browser; OUT=$ROOT/dist-release
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION=$2; shift 2 ;; --tiers) TIERS=$2; shift 2 ;; --out) OUT=$(mkdir -p "$2" && cd "$2" && pwd); shift 2 ;;
    *) die "usage : scripts/release.sh [--version X.Y.Z] [--tiers core,browser,extras,audio] [--out DIR]" ;;
  esac
done
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version SemVer attendue (X.Y.Z) : $VERSION"
git diff --quiet HEAD -- . || die "modifications non commitées : l'archive est construite depuis HEAD, commiter d'abord"
NAME=motion-tools-bundle; ST=$OUT/stage/$NAME; COMMIT=$(git rev-parse HEAD); BRANCH=$(git branch --show-current)
rm -rf "$OUT/stage"; mkdir -p "$ST"

say "== copie de HEAD ($COMMIT) vers $ST"
excl=(--exclude=_logs)
has() { case ",$TIERS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
# vendor/ : jamais lu dans Git (branche sandbox-vendor) mais sur disque, niveau par niveau (scripts/fetch-bundle.sh).
git archive HEAD | tar -x -C "$ST" "${excl[@]}"
vdirs=(npm-cache wheels); has browser && vdirs+=(npm-cache-browser); has extras && vdirs+=(npm-cache-extras); has audio && vdirs+=(wheels-audio)
( cd "$VENDOR" && sha256sum --quiet --ignore-missing -c SHA256SUMS ) || die "vendor/ absent ou altéré : lancer scripts/fetch-bundle.sh <remote> $(printf '%s ' ${TIERS//,/ })"
for d in "${vdirs[@]}"; do [ -d "$VENDOR/$d" ] || die "vendor/$d absent : scripts/fetch-bundle.sh"; mkdir -p "$ST/vendor"; cp -a "$VENDOR/$d" "$ST/vendor/$d"; done
rm -rf "$ST"/vendor/*/_logs
# Fichiers de maintenance du dépôt, retirés À LA RACINE seulement (starters/papermotion/.claude est du contenu amont, conservé).
( cd "$ST" && rm -rf CLAUDE.md .claude release scripts/release.sh .gitattributes )

# Références à l'outil de développement retirées des fichiers du bundle (CLAUDE.md n'est pas livré ; SKILL.md le remplace).
sed -i 's/CLAUDE\.md « Session Chat »/SKILL.md « Limites et pièges »/; s/CLAUDE\.md/SKILL.md/g' "$ST/scripts/test.sh" "$ST/requirements/NOT-VENDORED.txt" "$ST/scripts/sandbox/make_livrable.sh"
sed 's/@VERSION@/'"$VERSION"'/g' release/SKILL.md > "$ST/SKILL.md"
python3 release/metadata.py "$ST" --version "$VERSION" --commit "$COMMIT" --branch "$BRANCH" --tiers "$TIERS"

say "== contrôle : aucune référence à l'outil de développement dans les fichiers du bundle"
if hits=$(cd "$ST" && grep -rIniE 'claude code|CLAUDE\.md|\.claude/|plugin\.json|\bhooks?\b|slash command' SKILL.md BUNDLE.md scripts Makefile setup.sh requirements sandbox .env.example tools/chromium-bundled/README.md 2>/dev/null); then
  printf '%s\n' "$hits" | head -10 >&2; die "références interdites trouvées (ci-dessus)"; fi
ok "aucune"
say "== contrôle : aucun secret ni chemin absolu"
if hits=$(cd "$ST" && grep -rIlE '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})' --exclude-dir=vendor . ); then printf '%s\n' "$hits" >&2; die "secret probable"; fi
if hits=$(cd "$ST" && grep -rInE '/home/[a-z]+/|/Users/[A-Za-z]+/' --include=*.sh --include=setup.sh --include=Makefile scripts setup.sh Makefile 2>/dev/null); then printf '%s\n' "$hits" >&2; die "chemin absolu en dur"; fi
find "$ST" \( -name '.env' -o -name '*.pem' -o -name '*.key' \) -not -path '*/vendor/*' | grep . >&2 && die "fichier sensible présent"
ok "aucun"

say "== MANIFEST.sha256"
( cd "$ST" && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum | sed 's#  \./#  #' > MANIFEST.sha256 )
ok "$(wc -l < "$ST/MANIFEST.sha256") fichiers"

say "== archive"
TAR="$OUT/$NAME-v$VERSION.tar.gz"
tar --sort=name --mtime="@$(git show -s --format=%ct HEAD)" --owner=0 --group=0 --numeric-owner -C "$OUT/stage" -cf - "$NAME" | gzip -n -6 > "$TAR"
( cd "$OUT" && sha256sum "$(basename "$TAR")" > "$(basename "$TAR").sha256" && cat "$(basename "$TAR").sha256" )
ok "$(du -h "$TAR" | cut -f1) : $TAR   (dossier : $(du -sh "$ST" | cut -f1))"
