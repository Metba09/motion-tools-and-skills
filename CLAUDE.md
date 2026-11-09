# motion-tools-and-skills : consignes pour l'agent

Dépôt d'outils, skills et starters de motion design en code. Voir `README.md` (carte du dépôt) et `docs/techniques.md`.
**Toute la logique est dans des scripts classiques** (`make …`, `./setup.sh`, `scripts/*.sh`, `npm run …`). Les fichiers de
`.claude/commands/` ne sont que de fins wrappers qui appellent ces mêmes commandes : Claude Code n'est jamais requis.

## Session Chat (sandbox claude.ai, hors-ligne)

Le sandbox repart de zéro à chaque session et n'a **pas d'Internet** (hors GitHub et registres npm/PyPI, que ce bundle n'utilise pas).
Tout est vendorisé dans `vendor/` (cache npm, wheels Python cp312/cp313 linux-x86_64, polices).

**Récupérer les paquets** : `vendor/` lourd n'est PAS dans `main` ni dans `offline-bundle` ; il est sur la branche orpheline `sandbox-vendor`.
`make fetch ARGS="origin core browser"` (ou `bash scripts/fetch-bundle.sh <remote> core browser`) copie les niveaux voulus dans `vendor/` et vérifie les SHA-256
(niveaux : core, browser, extras, audio). Alternative : l'archive prête à l'emploi de la branche `sandbox-bundle` (voir son README.txt).

**Installer (sans saisie, idempotent, relançable) :**

```bash
make setup          # = ./setup.sh core : npm x9 projets + Python core + bibliothèque lemo (.lib/lemo-opuscar)
```

**Tester / conclure (à lancer à la main AVANT de rendre la main, remplace les hooks) :**

```bash
make check          # doctor + lint + format + tests ; doit finir par « TOUT EST VERT »
make smoke          # bout en bout (navigateur, mock fal, Python) — facultatif, ~2 min
make offline-proof  # rejoue setup + check dans un espace réseau vide (preuve d'autonomie)
```

Niveaux facultatifs : `make setup-browser` (Chromium embarqué si aucun Chrome système), `make setup-extras` (Remotion, tidewater, ~170 Mo),
`make setup-audio` (numba, librosa, pedalboard, matplotlib). `make doctor` dit ce qui est installé ; `make help` liste tout.
Avant un `git commit` : `make format FORMAT_ARGS=--write && make check`.

**Convention `MOTION_OFFLINE`** (défaut `1`, posée par `scripts/env.sh`, à sourcer : `. scripts/env.sh`) : un script qui exigerait Internet
s'arrête avec le **code 3** et un message clair ; les services externes sont remplacés par des mocks. `MOTION_OFFLINE=0` est réservé au mainteneur (réseau).

**Inutilisable dans le sandbox** (ne pas essayer, ne pas contourner) :
- Docker / conteneurs ; GPU et WebGPU (`starters/tidewater-webgpu-fx` : build possible, rendu non) ; Blender (`tools/tidewater-asset-pipeline/blender`, `skills/3d-product`) ; Unreal, ComfyUI.
- Services externes : Fal.ai (**mock** automatique dans `starters/dioramas`, voir `.env.example`), ElevenLabs, Hugging Face, Polyhaven, Freesound, VCSL, Google Fonts (polices locales `fonts/fonts.css` à côté de chaque page).
- Modèles lourds non vendorisés (voix/TTS/whisper, vision, analyse) : voir `requirements/NOT-VENDORED.txt`. Transcription : moteur `--script "texte"` (hors-ligne) de `skills/talking-head-b-roll/scripts/transcribe.mjs`.
- Wheels Python seulement pour CPython 3.12 et 3.13 ; npm : linux-x64 uniquement ; glyphes CJK absents des polices embarquées.
- Rendu navigateur : `scripts/chrome.sh` choisit `$CHROME_PATH` > Chrome système > Chromium embarqué ; WebGL logiciel (SwiftShader), lent mais correct. **Avec le Chromium embarqué, passer `--soft-gl`** aux scripts de rendu (`npm run sheet -- --soft-gl`, `node render.mjs --soft-gl …`) : sans cette option la page ne démarre pas.

**À lire à la demande** (ne pas tout charger) :
- Skills : `skills/<nom>/SKILL.md` + `NOTES.md` ; sous-agents / métadonnées d’agents : `skills/*/agents/` (ex. `skills/video-production-skills/skills/*/agents/`, `skills/anatomy/agents/openai.yaml`).
- Commandes projet : `.claude/commands/{setup,check,smoke,doctor,offline-proof}.md` (wrappers de `make`).
- Méthode générale : `docs/techniques.md` ; guides : `docs/guides/` ; styles de film : `prompts/film-styles/`.
- Pointeur de bundle : `sandbox/BUNDLE.json` (empreintes SHA-256 des lockfiles + tarball miroir dans claude-memory). `make verify-bundle` le contrôle (aussi dans `make lint`) ; après `make vendor` il est volontairement périmé : régénérer avec `scripts/sandbox/make_livrable.sh` puis `scripts/sandbox/write_bundle.py`. Le dépôt est la source de vérité, le livrable un miroir.
- Détails du bundle : `scripts/projects.sh` (projets par niveau), `scripts/vendor.sh` (régénération, mainteneur), `vendor/MANIFEST.json`.

## Règles de travail

- Ne pas relancer `npm install`/`pip install` « en ligne » : `make setup` est la seule voie (lockfiles + vendor/).
- `scripts/offline-guard.mjs` (dans `make lint`) échoue si une page charge une ressource distante ou si un script réseau n'a pas le garde `MOTION_OFFLINE`. Exceptions : `scripts/offline-allow.txt`.
- Tests anatomy : construisent d'abord des pages d'exemple (ignorées par git) ; les 3 tests `react-*` exigent `esbuild`, non vendorisé, et sont exclus de `scripts/test.sh`.
- Ne pas écrire de secrets : copier `.env.example` en `.env` (ignoré par git) si besoin.
