#!/usr/bin/env bash
# Empaquette le dépôt + vendor/ en archives dans dist-bundle/ (une par niveau, pour ne télécharger que le nécessaire).
#   scripts/bundle.sh            -> dist-bundle/{source,vendor-core,vendor-browser,vendor-extras,vendor-audio}.tar.gz + SHA256SUMS
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
OUT=dist-bundle; rm -rf "$OUT"; mkdir -p "$OUT"
tgz() { local name=$1; shift; tar -czf "$OUT/$name.tar.gz" --owner=0 --group=0 "$@" && ok "$name  $(du -h "$OUT/$name.tar.gz" | cut -f1)"; }

# Source : tout sauf ce qui est régénérable ou lourd.
tgz source --exclude=./node_modules --exclude='*/node_modules' --exclude=./.git --exclude=./.lib --exclude=./vendor \
           --exclude=./dist-bundle --exclude='*/out' -C "$ROOT" .
# vendor : un niveau = une archive (core = cache npm noyau + wheels core + empreintes).
tgz vendor-core    -C "$ROOT" vendor/npm-cache vendor/wheels vendor/SHA256SUMS vendor/MANIFEST.json
[ -d vendor/npm-cache-browser ] && tgz vendor-browser -C "$ROOT" vendor/npm-cache-browser
[ -d vendor/npm-cache-extras ]  && tgz vendor-extras  -C "$ROOT" vendor/npm-cache-extras
[ -d vendor/wheels-audio ]      && tgz vendor-audio   -C "$ROOT" vendor/wheels-audio
( cd "$OUT" && sha256sum ./*.tar.gz | sed 's#\./##' > SHA256SUMS )
ok "archives dans $OUT/ ; vérifier : (cd $OUT && sha256sum -c SHA256SUMS)"
say "Installer ailleurs : tar xzf source.tar.gz -C <dir> && tar xzf vendor-core.tar.gz -C <dir> && cd <dir> && make setup"
