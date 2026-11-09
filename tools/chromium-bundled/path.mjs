// Affiche le chemin d'un Chromium exécutable. @sparticuz/chromium décompresse son binaire (brotli) dans /tmp
// à la première demande (≈1 s), sans aucun accès réseau.
import chromium from '@sparticuz/chromium';
process.stdout.write(await chromium.executablePath());
