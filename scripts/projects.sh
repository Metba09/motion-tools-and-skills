# shellcheck shell=bash
# Source de vérité : quels projets Node sont installés, et dans quel niveau (tier).
# Chaque entrée est un dossier contenant package.json + package-lock.json.
#
#   core   : installé par `make setup`            -> vendor/npm-cache
#   extras : installé par `make setup-extras`     -> vendor/npm-cache-extras (lourd, optionnel)
#   browser: installé par `make setup-browser`    -> vendor/npm-cache-browser (Chromium de repli)

NODE_CORE=(
  skills/kinetic-reel/template
  skills/opus-visual-motion-engine/scripts
  skills/motion-graphics-music-video/scripts
  skills/painted-animation/template
  starters/dioramas
  starters/papermotion
  starters/mg-styles-15
  starters/pdoom-video-engine
  tools/lemo-core
)

NODE_EXTRAS=(
  skills/video-shotcraft/template   # Remotion + rspack : ~100 Mo de tarballs, rendu via Chrome système
  starters/tidewater-webgpu-fx      # paquet "webgpu" (Dawn) : 51 Mo, inutilisable sans GPU
)

# browser : Chromium embarqué, seulement utile si le sandbox n'a pas de Chrome système (`make setup-browser`)
NODE_BROWSER=(
  tools/chromium-bundled            # @sparticuz/chromium : ~67 Mo, WebGL via SwiftShader
)

# Niveaux Python (fichiers dans requirements/) : core est vendorisé ; audio aussi.
# Les niveaux voice / vision / analysis ne sont PAS vendorisés (modèles à télécharger, torch, GPU).
PY_TIERS_VENDORED=(core audio)
