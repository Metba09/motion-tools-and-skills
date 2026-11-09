#!/usr/bin/env bash
# Alias de ./setup.sh (même arguments : core | browser | extras | audio | all).
exec bash "$(cd "$(dirname "$0")/.." && pwd)/setup.sh" "$@"
