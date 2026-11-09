#!/usr/bin/env node
// Garde statique « hors-ligne ». Échoue (code 1) si :
//   A. une page/feuille de style/script charge une ressource DISTANTE au chargement
//      (<script src=http…>, <link href=http…>, <img src=…>, @import/url(http…), import 'https://…', fetch('https://…') non local) ;
//   B. un script shell/Python/Node qui appelle Internet (curl, wget, git clone, apt/brew/pip/npm install, urlopen, fetch distant)
//      ne porte pas le garde-fou MOTION_OFFLINE.
// Exceptions documentées : scripts/offline-allow.txt  (« <regex de chemin>  # raison »).
// Les .md (documentation) ne sont jamais analysés.
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const SKIP = new Set(['.git', 'node_modules', 'vendor', '.lib', 'out', 'dist', '__pycache__']);
const allow = fs.existsSync(path.join(ROOT, 'scripts/offline-allow.txt'))
  ? fs.readFileSync(path.join(ROOT, 'scripts/offline-allow.txt'), 'utf8').split('\n')
      .map(l => l.replace(/#.*/, '').trim()).filter(Boolean).map(r => new RegExp(r))
  : [];

function* walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) { if (!SKIP.has(e.name)) yield* walk(path.join(dir, e.name)); }
    else yield path.join(dir, e.name);
  }
}

const REMOTE = String.raw`https?:\/\/(?!(?:127\.0\.0\.1|localhost|0\.0\.0\.0|\[::1\]|www\.w3\.org|schema\.org|purl\.org|xmlns)[:/"'\s])`;
const A_HTML = [
  new RegExp(String.raw`<(?:script|img|source|iframe|video|audio|embed|track)\b[^>]*\bsrc=["']${REMOTE}`, 'i'),
  new RegExp(String.raw`<link\b[^>]*\bhref=["']${REMOTE}`, 'i'),
  new RegExp(String.raw`@import\s+(?:url\()?["']?${REMOTE}`, 'i'),
  new RegExp(String.raw`url\(\s*["']?${REMOTE}`, 'i'),
];
const A_JS = [
  new RegExp(String.raw`\bimport\s*(?:[^'"\n]*from\s*)?\(?\s*["']${REMOTE}`),
  new RegExp(String.raw`\b(?:importScripts|new Worker|new SharedWorker)\(\s*["']${REMOTE}`),
  new RegExp(String.raw`\bfetch\(\s*["'\x60]${REMOTE}`),
];
const B_SH = /(?:^|[;&|(]\s*|\s)(?:curl|wget)\s|git clone|apt(?:-get)? install|brew install|pip3? install|uv pip install|\bnpm (?:i|install)\b(?![^\n]*--offline)/;
const NOT_NETWORK = /--no-index|--offline|--find-links/;   // installation depuis vendor/ : pas de réseau
const B_PY = /urllib\.request\.(?:urlopen|urlretrieve)|\brequests\.(?:get|post|put)\(|\bhttpx\.(?:get|post)\(/;
const B_JS = new RegExp(String.raw`\bfetch\(\s*["'\x60]${REMOTE}|\bhttps\.(?:get|request)\(`);   // node:http seul = serveur local, pas un appel

const isComment = (l, kind) => { const t = l.trim(); return kind === 'sh' || kind === 'py' ? t.startsWith('#') : t.startsWith('//') || t.startsWith('*') || t.startsWith('/*'); };
const bad = [], gated = [];
for (const file of walk(ROOT)) {
  const rel = path.relative(ROOT, file).split(path.sep).join('/');
  if (allow.some(r => r.test(rel))) continue;
  const ext = path.extname(file).toLowerCase();
  const kind = ext === '.sh' ? 'sh' : ext === '.py' ? 'py' : ['.mjs', '.cjs', '.js', '.ts', '.tsx', '.jsx'].includes(ext) ? 'js' : ['.html', '.htm', '.css'].includes(ext) ? 'html' : null;
  if (!kind || fs.statSync(file).size > 3e6) continue;
  const src = fs.readFileSync(file, 'utf8');
  const lines = src.split('\n');

  // A : ressources distantes chargées par les pages / le code navigateur
  const aPats = kind === 'html' ? A_HTML : kind === 'js' ? [...A_JS, ...(/<\w/.test(src) ? A_HTML : [])] : [];
  lines.forEach((l, i) => { if (!isComment(l, kind) && aPats.some(r => r.test(l))) bad.push(`A ${rel}:${i + 1}  ressource distante : ${l.trim().slice(0, 110)}`); });

  // B : appels réseau dans les scripts → garde-fou obligatoire
  const bPat = kind === 'sh' ? B_SH : kind === 'py' ? B_PY : kind === 'js' ? B_JS : null;
  if (bPat) {
    const hit = lines.findIndex(l => !isComment(l, kind) && bPat.test(l) && !NOT_NETWORK.test(l));
    if (hit >= 0) {
      if (/MOTION_OFFLINE/.test(src)) gated.push(rel);
      else bad.push(`B ${rel}:${hit + 1}  appel réseau sans garde MOTION_OFFLINE : ${lines[hit].trim().slice(0, 100)}`);
    }
  }
}
if (bad.length) { console.error(bad.join('\n')); console.error(`\n✗ offline-guard : ${bad.length} problème(s)`); process.exit(1); }
console.log(`✓ offline-guard : aucune ressource distante ; ${gated.length} script(s) réseau protégés par MOTION_OFFLINE`);
