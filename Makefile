# Bundle hors-ligne : toute la logique vit dans des scripts classiques (scripts/*.sh, setup.sh), jamais dans un déclencheur automatique.
SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help setup setup-browser setup-extras setup-audio setup-all doctor check test lint format smoke offline-proof verify-bundle check-quick fetch release vendor bundle clean

help:  ## cette aide
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  \033[36m%-14s\033[0m %s\n",$$1,$$2}'

setup:          ## installe le noyau hors-ligne (npm x9 + Python core + bibliothèque lemo) — idempotent
	./setup.sh core
setup-browser:  ## installe le Chromium embarqué (si le sandbox n'a pas de Chrome)
	./setup.sh browser
setup-extras:   ## installe Remotion + tidewater (npm, lourd)
	./setup.sh extras
setup-audio:    ## installe le niveau Python « audio » (numba, librosa, pedalboard…)
	./setup.sh audio
setup-all:      ## tout installer
	./setup.sh all

doctor:         ## diagnostic : outils, navigateur, vendor/, niveaux installés (DOCTOR_ARGS=--verify pour les SHA-256)
	@bash scripts/doctor.sh $(DOCTOR_ARGS)
check:          ## « tout est vert ? » : intégrité + runtimes + doctor + lint + format + tests (à lancer avant de conclure)
	@bash scripts/check.sh --full
check-quick:    ## intégrité SHA-256 + runtimes + test de fumée (~1 min)
	@bash scripts/check.sh
test:           ## tests unitaires (anatomy, talking-head, papermotion)
	@bash scripts/test.sh
lint:           ## syntaxe shell/node/python/json + garde hors-ligne
	@bash scripts/lint.sh
format:         ## vérifie l'hygiène des fichiers du bundle (FORMAT_ARGS=--write pour corriger)
	@bash scripts/format.sh $(FORMAT_ARGS)
smoke:          ## bout en bout avec navigateur, mock fal, Python (SMOKE=python fal… pour choisir)
	@bash scripts/smoke.sh $(SMOKE)
offline-proof:  ## rejoue setup + check dans un espace réseau VIDE (preuve d'autonomie)
	@bash scripts/run-offline.sh bash -c 'make setup && make check'

verify-bundle:  ## pointeur sandbox/BUNDLE.json vs lockfiles (ARGS="--livrable DIR" pour vérifier aussi le tarball miroir)
	@python3 -I scripts/sandbox/verify_bundle.py $(ARGS)

fetch:          ## [RÉSEAU GitHub] récupère vendor/ par niveau depuis sandbox-vendor (ARGS="origin core browser")
	@bash scripts/fetch-bundle.sh $(ARGS)
release:        ## archive unique motion-tools-bundle-vX.Y.Z.tar.gz depuis HEAD (ARGS="--version 1.0.0 --tiers core,browser")
	@test -f scripts/release.sh || { echo "outil de maintenance : absent de ce bundle" >&2; exit 1; }
	@bash scripts/release.sh $(ARGS)

vendor:         ## [RÉSEAU] régénère vendor/ (cache npm, wheels, polices). Mainteneur seulement
	@bash scripts/vendor.sh all
bundle:         ## empaquette le dépôt + vendor/ en archives dans dist-bundle/
	@bash scripts/bundle.sh
clean:          ## supprime node_modules, .lib et les fichiers temporaires (garde vendor/)
	@find . -name node_modules -type d -prune -not -path './.git/*' -exec rm -rf {} + ; rm -rf .lib dist-bundle
