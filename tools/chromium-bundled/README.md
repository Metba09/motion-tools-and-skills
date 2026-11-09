# chromium-bundled

Navigateur de secours du bundle hors-ligne. `scripts/chrome.sh` l'utilise **seulement** si aucun Chrome/Chromium
système n'est trouvé (`CHROME_PATH`, `google-chrome`, `chromium`…). Installé par `make setup-browser`
(cache : `vendor/npm-cache-browser`, ≈ 67 Mo).

- Binaire : *headless shell* de Chromium fourni par `@sparticuz/chromium` (licence MIT pour le paquet ; Chromium BSD).
- WebGL : rendu logiciel SwiftShader (pas de GPU). Les scripts de rendu (kinetic-reel, painted-animation…) l'activent avec **`--soft-gl`**
  (`npm run sheet -- --soft-gl`) : OBLIGATOIRE avec ce navigateur, sans quoi la page ne démarre pas.
- Limites : x86_64 glibc seulement ; pas de codecs propriétaires (H.264) → l'encodage vidéo reste fait par ffmpeg.
