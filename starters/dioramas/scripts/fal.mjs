// Shared fal client. Reads FAL_KEY from the environment or a .env file in the project root.
//
// Offline bundle: with MOTION_OFFLINE != 0 (the default there) or FAL_MOCK=1, NO request leaves the machine:
// ./fal-mock.mjs answers instead, with valid but fake assets (a coloured PNG, a one-cube GLB), so the whole
// pipeline (manifest, resume, optimize, render) can be exercised. Real generation needs MOTION_OFFLINE=0 and FAL_KEY.
import { config } from 'dotenv';
import fs from 'node:fs';
import path from 'node:path';
import { mockBytes } from './fal-mock.mjs';

config({ quiet: true });
export const MOCK = process.env.FAL_MOCK === '1' || ((process.env.MOTION_OFFLINE ?? '1') !== '0' && process.env.FAL_MOCK !== '0');
let fal;
if (MOCK) {
  ({ fal } = await import('./fal-mock.mjs'));
  console.warn('[fal] MODE MOCK : aucune requête réseau, assets factices (FAL_MOCK=0 + MOTION_OFFLINE=0 + FAL_KEY pour du réel).');
} else {
  if (!process.env.FAL_KEY) throw new Error('FAL_KEY missing: copy .env.example to .env and add your fal key');
  ({ fal } = await import('@fal-ai/client'));
  fal.config({ credentials: process.env.FAL_KEY });
}

export { fal };

export const ROOT = path.resolve(import.meta.dirname, '..');
const MANIFEST = path.join(ROOT, 'assets', 'manifest.json');

export function readManifest() {
  try { return JSON.parse(fs.readFileSync(MANIFEST, 'utf8')); } catch { return { images: {}, meshes: {} }; }
}
// Serialize manifest writes so concurrent jobs never clobber each other.
let chain = Promise.resolve();
export function updateManifest(fn) {
  chain = chain.then(() => {
    const m = readManifest();
    fn(m);
    fs.writeFileSync(MANIFEST, JSON.stringify(m, null, 2));
  });
  return chain;
}

export async function download(url, dest) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  if (url.startsWith('mock://')) { fs.writeFileSync(dest, mockBytes(url)); return dest; }
  for (let attempt = 0; attempt < 4; attempt++) {
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      fs.writeFileSync(dest, Buffer.from(await res.arrayBuffer()));
      return dest;
    } catch (e) {
      if (attempt === 3) throw e;
      await new Promise(r => setTimeout(r, 2000 * (attempt + 1)));
    }
  }
}

export async function uploadFile(file) {
  const buf = fs.readFileSync(file);
  const ext = path.extname(file).slice(1).toLowerCase();
  const type = ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' : ext === 'webp' ? 'image/webp' : 'image/png';
  return fal.storage.upload(new Blob([buf], { type }));
}
