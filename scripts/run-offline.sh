#!/usr/bin/env bash
# Exécute une commande dans un espace réseau VIDE (aucune interface) : preuve que rien n'a besoin d'Internet.
#   scripts/run-offline.sh make setup
# Repli (sans unshare) : proxys cassés + MOTION_OFFLINE=1 — moins strict, signalé clairement.
# Espace réseau vide, mais on allume « lo » : Chrome/vite/vitest parlent en local sur 127.0.0.1 (rien ne sort).
if unshare -rn true 2>/dev/null; then
  exec unshare -rn bash -c 'python3 "$0/scripts/lo-up.py" 2>/dev/null || ip link set lo up 2>/dev/null || true; exec "$@"' "$(cd "$(dirname "$0")/.." && pwd)" "$@"
fi
echo "! unshare indisponible : repli proxy cassé (moins strict que l'isolement réseau)" >&2
export MOTION_OFFLINE=1 HTTP_PROXY=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 NO_PROXY=127.0.0.1,localhost
exec "$@"
