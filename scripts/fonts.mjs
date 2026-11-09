#!/usr/bin/env node
// Remplace les polices Google Fonts des pages HTML par des fichiers locaux (woff2, sous-ensemble latin).
//
// Pourquoi : le sandbox de session ne joint ni fonts.googleapis.com ni fonts.gstatic.com. Les mêmes polices
// existent sur le registre npm (@fontsource, licence OFL) : on les récupère UNE fois (réseau npm requis,
// donc côté mainteneur : `scripts/vendor.sh fonts`) et on commit le résultat à côté de chaque page :
//   <dossier de la page>/fonts/fonts.css  +  fonts/*.woff2
// Idempotent : une page déjà réécrite (plus de lien Google) est ignorée.
//
// Limites assumées : sous-ensemble latin seulement (Noto Sans SC et Ma Shan Zheng perdent leurs glyphes CJK) ;
// pas d'axe optique opsz (Newsreader, Fraunces) : on prend les graisses statiques.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const ROOT = path.resolve(import.meta.dirname, '..');
const SKIP_DIRS = new Set(['.git', 'node_modules', 'vendor', 'out', 'dist']);

function* walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) { if (!SKIP_DIRS.has(e.name)) yield* walk(path.join(dir, e.name)); }
    else if (e.name.endsWith('.html')) yield path.join(dir, e.name);
  }
}

const LINK_RE = /<link\b[^>]*\bhref=["']https?:\/\/fonts\.(googleapis|gstatic)\.com[^"']*["'][^>]*>\s*\n?/gi;
const CSS_RE = /href=["'](https?:\/\/fonts\.googleapis\.com\/css2\?[^"']+)["']/i;

// "Name:ital,wght@0,300;1,400" -> [{ family, weight, italic }]
function parseCss2(url) {
  const out = [];
  const u = new URL(url.replace(/&amp;/g, '&'));
  for (const fam of u.searchParams.getAll('family')) {
    const [rawName, spec] = fam.split(':');
    const family = rawName.replace(/\+/g, ' ');
    if (!spec) { out.push({ family, weight: 400, italic: false }); continue; }
    const [axesRaw, valsRaw] = spec.split('@');
    const axes = axesRaw.split(',');
    for (const tuple of valsRaw.split(';')) {
      const vals = tuple.split(',');
      let weight = 400, italic = false;
      axes.forEach((ax, i) => {
        if (ax === 'ital') italic = vals[i] === '1';
        else if (ax === 'wght') {
          const [lo, hi] = vals[i].split('..').map(Number);
          weight = lo;
          if (hi) for (let w = Math.ceil(lo / 100) * 100; w <= hi; w += 100) out.push({ family, weight: w, italic });
        }
      });
      out.push({ family, weight, italic });
    }
  }
  return out;
}

const slug = (f) => f.toLowerCase().replace(/\s+/g, '-');
const key = (f) => `${f.family}|${f.weight}|${f.italic}`;

// 1. inventaire des pages à réécrire
const pages = [];
for (const file of walk(ROOT)) {
  const src = fs.readFileSync(file, 'utf8');
  if (!/fonts\.googleapis\.com/.test(src)) continue;
  const faces = new Map();
  for (const m of src.matchAll(new RegExp(CSS_RE.source, 'gi'))) for (const f of parseCss2(m[1])) faces.set(key(f), f);
  pages.push({ file, src, faces: [...faces.values()] });
}
if (!pages.length) { console.log('fonts.mjs : rien à faire (plus aucune police Google dans les pages).'); process.exit(0); }

// 2. installation des paquets @fontsource (un seul npm install, dans un dossier temporaire)
const families = [...new Set(pages.flatMap((p) => p.faces.map((f) => f.family)))].sort();
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'fonts-'));
fs.writeFileSync(path.join(tmp, 'package.json'), '{"name":"fonts-tmp","private":true}');
console.log(`fonts.mjs : ${pages.length} page(s), ${families.length} famille(s) -> @fontsource`);
execFileSync('npm', ['install', '--no-audit', '--no-fund', '--ignore-scripts', ...families.map((f) => `@fontsource/${slug(f)}`)],
  { cwd: tmp, stdio: ['ignore', 'ignore', 'inherit'] });
const FS = (fam) => path.join(tmp, 'node_modules', '@fontsource', slug(fam), 'files');

// 3. écriture des fichiers locaux + réécriture des pages
let bad = 0;
for (const p of pages) {
  const dir = path.join(path.dirname(p.file), 'fonts');
  fs.mkdirSync(dir, { recursive: true });
  const css = [`/* Généré par scripts/fonts.mjs : polices @fontsource (OFL), sous-ensemble latin. Ne pas éditer à la main. */`];
  for (const f of p.faces.sort((a, b) => key(a).localeCompare(key(b)))) {
    const style = f.italic ? 'italic' : 'normal';
    const name = `${slug(f.family)}-latin-${f.weight}-${style}.woff2`;
    const from = path.join(FS(f.family), name);
    if (!fs.existsSync(from)) { console.error(`✗ absent de @fontsource : ${f.family} ${f.weight} ${style} (${name})`); bad++; continue; }
    fs.copyFileSync(from, path.join(dir, name));
    css.push(`@font-face{font-family:'${f.family}';font-style:${style};font-weight:${f.weight};font-display:block;src:url('./${name}') format('woff2');}`);
  }
  fs.writeFileSync(path.join(dir, 'fonts.css'), css.join('\n') + '\n');
  let out = p.src.replace(LINK_RE, '');
  out = out.replace(/<\/head>/i, '<link rel="stylesheet" href="fonts/fonts.css">\n</head>');
  fs.writeFileSync(p.file, out);
  console.log(`✓ ${path.relative(ROOT, p.file)} : ${p.faces.length} fonte(s) locales`);
}
fs.rmSync(tmp, { recursive: true, force: true });
if (bad) { console.error(`${bad} police(s) introuvable(s) : voir ci-dessus.`); process.exit(1); }
