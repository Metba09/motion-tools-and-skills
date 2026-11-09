---
name: motion-tools-bundle
description: Utiliser le bundle hors-ligne motion-tools-and-skills (rendus motion design en code : kinetic-reel, painted-animation, dioramas, papermotion, lemo-opuscar, anatomy ; transcription locale). Déclencheurs : motion design hors-ligne, planche-contact, bundle autonome, sandbox sans réseau.
---

# motion-tools-bundle v@VERSION@

Bundle autonome : toutes les dépendances (npm, Python, Chromium embarqué, polices) sont dans `vendor/`. Aucun accès réseau n'est nécessaire ni tenté. Tous les chemins sont relatifs à la racine du bundle ; les commandes ci-dessous se lancent depuis cette racine.

## Déploiement

1. Si l'archive est fournie en morceaux, la reconstituer et vérifier : `cat motion-tools-bundle-v@VERSION@.tar.gz.part-* > motion-tools-bundle-v@VERSION@.tar.gz && sha256sum -c motion-tools-bundle-v@VERSION@.tar.gz.sha256`.
2. Décompresser : `tar xzf motion-tools-bundle-v@VERSION@.tar.gz`, puis `cd motion-tools-bundle`.
3. Installer (idempotent, sans saisie, ~15 s ; à refaire à chaque nouvelle session) : `bash scripts/run.sh setup`.
4. Vérifier : `bash scripts/check.sh` (~30 s, doit finir par « CHECK RAPIDE VERT »).

Prérequis système : Node >= 22.12, Python 3.12 ou 3.13, `ffmpeg` et `ffprobe` (non fournis). Voir `BUNDLE.md`.

## Utilisation

Point d'entrée unique : `bash scripts/run.sh <commande>` (`bash scripts/run.sh help` liste tout).

| Besoin | Commande | Sortie attendue |
|---|---|---|
| Créer un projet de rendu | `bash scripts/run.sh new kinetic-reel ./mon-projet` (ou `painted-animation`) | dossier prêt, dépendances installées hors-ligne |
| Planche-contact (aperçu) | `bash scripts/run.sh sheet ./mon-projet` | images dans `./mon-projet/out/` |
| Transcription locale | `bash scripts/run.sh transcribe video.mp4 sortie.json --script "Texte dit dans la vidéo."` | JSON de mots avec horodatage répartis sur l'audio |
| Diagnostic | `bash scripts/run.sh doctor` | outils, navigateur, niveaux installés |
| Vérification rapide | `bash scripts/check.sh` | intégrité SHA-256, runtimes, test de fumée |
| Vérification complète | `bash scripts/check.sh --full` | + diagnostic, contrôle de syntaxe, format, tests unitaires (~4 min) |
| Bout en bout | `bash scripts/run.sh smoke` | rendus avec navigateur, mock Fal, Python (~2 min) |

Codes de sortie de `scripts/check.sh` : 0 tout vert ; 10 intégrité ; 20 runtime ou installation manquante ; 30 test en échec. Un script du dépôt qui voudrait Internet s'arrête avec le code 3 : ce n'est pas une panne.

Pour exécuter un outil à la main : `. scripts/env.sh` (mode hors-ligne, navigateur détecté dans `CHROME_PATH`). Documentation de chaque outil : `skills/<nom>/SKILL.md` et `NOTES.md` ; méthode générale : `docs/techniques.md`. Ne lire que ce qui est nécessaire.

## Limites et pièges

- **Réseau interdit** : ne jamais lancer `npm install`, `pip install` ni `git clone`. Seule voie : `bash scripts/run.sh setup`.
- **Chromium embarqué** : les rendus doivent utiliser WebGL logiciel. `run.sh sheet` l'active ; pour un script direct, passer `--soft-gl`. Sans cela la page ne démarre pas.
- **Inutilisable ici** : Docker, GPU et WebGPU (`starters/tidewater-webgpu-fx` : build possible, rendu non), Blender, Unreal, ComfyUI.
- **Services externes remplacés** : Fal.ai fonctionne en mock (assets factices, `FAL_MOCK=1`) ; ElevenLabs, Hugging Face, Polyhaven, Freesound, VCSL et Google Fonts sont inaccessibles (polices locales fournies).
- **Non vendorisé** : modèles de voix, vision et analyse (`requirements/NOT-VENDORED.txt`). Les niveaux `extras` (Remotion, tidewater) et `audio` ne sont pas dans cette archive : `bash scripts/run.sh setup extras` répond par un refus clair.
- **Versions** : Python 3.12 ou 3.13 seulement ; une autre version fait échouer `check.sh` (code 20). npm : linux x86_64 uniquement. Pas de glyphes CJK dans les polices fournies.
- **Secrets** : aucun requis. `.env.example` documente les réglages facultatifs ; copier en `.env` si besoin.
- **Intégrité** : `MANIFEST.sha256` couvre tous les fichiers livrés. Un écart signifie une archive altérée : la retélécharger, ne pas corriger à la main.
- **Licences** : voir `LICENSES/REDISTRIBUTION.md` avant toute redistribution (composants à obligations signalés).
