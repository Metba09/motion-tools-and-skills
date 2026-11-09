#!/usr/bin/env bash
# Vérifications statiques, SANS dépendance installée : syntaxe shell / Node / Python / JSON + garde hors-ligne.
# À lancer à la main avant de conclure (make lint) : rien ne se déclenche tout seul.
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
fails=0; n=0
find_files() { find . \( -name .git -o -name node_modules -o -name vendor -o -name .lib -o -name out -o -name dist \) -prune -o -type f -name "$1" -print; }
step() { printf '%-34s' "$1"; }

step "shell (bash -n)"; bad=0; c=0
while read -r f; do c=$((c+1)); head -1 "$f" | grep -q '^#!/bin/sh\|^#!/usr/bin/env sh' && sh -n "$f" 2>/dev/null || bash -n "$f" 2>/dev/null || { echo; warn "syntaxe shell : $f"; bad=$((bad+1)); }; done < <(find_files '*.sh')
[ $bad = 0 ] && ok "$c fichiers" || { fails=$((fails+bad)); }

step "node (--check)"; bad=0; c=0
while read -r f; do c=$((c+1)); node --check "$f" 2>/dev/null || { echo; warn "syntaxe node : $f"; bad=$((bad+1)); }; done < <(find_files '*.mjs'; find_files '*.cjs')
[ $bad = 0 ] && ok "$c fichiers" || { fails=$((fails+bad)); }

step "python (compile)"
if out=$(find_files '*.py' | "$(py_bin)" -I -c '
import sys
bad = n = 0
for f in sys.stdin.read().split():
    n += 1
    try: compile(open(f, encoding="utf-8").read(), f, "exec")
    except SyntaxError as e: print(f"{f}:{e.lineno}: {e.msg}"); bad += 1
print(f"__n={n}"); sys.exit(1 if bad else 0)'); then ok "$(printf '%s' "$out" | sed -n 's/__n=\(.*\)/\1 fichiers/p')"
else echo; printf '%s\n' "$out" | grep -v '^__n=' >&2; fails=$((fails+1)); fi

step "json (parse)"
if out=$(find_files '*.json' | grep -v 'package-lock.json' | "$(py_bin)" -I -c '
import sys, json, os
bad = n = 0
for f in sys.stdin.read().split():
    if os.path.getsize(f) > 8_000_000: continue
    n += 1
    try: json.load(open(f, encoding="utf-8"))
    except Exception as e: print(f"{f}: {e}"); bad += 1
print(f"__n={n}"); sys.exit(1 if bad else 0)'); then ok "$(printf '%s' "$out" | sed -n 's/__n=\(.*\)/\1 fichiers/p')"
else echo; printf '%s\n' "$out" | grep -v '^__n=' >&2; fails=$((fails+1)); fi

step "pointeur de bundle"
if out=$("$(py_bin)" -I -c 'import json; json.load(open("sandbox/BUNDLE.json", encoding="utf-8"))' 2>&1 && "$(py_bin)" -I scripts/sandbox/verify_bundle.py 2>&1); then printf '%s\n' "$out" | sed 's/^✓ verify-bundle : //'
else echo; printf '%s\n' "$out" >&2; fails=$((fails+1)); fi

step "garde hors-ligne"; node scripts/offline-guard.mjs >/tmp/guard.out 2>&1 && sed 's/^✓ offline-guard : //' /tmp/guard.out || { echo; cat /tmp/guard.out >&2; fails=$((fails+1)); }

[ $fails = 0 ] && ok "lint : tout est vert" || die "lint : $fails étape(s) en échec"
