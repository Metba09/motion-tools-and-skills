// Faux client fal, 100 % local : mêmes méthodes que @fal-ai/client (subscribe, queue.*, storage.upload),
// mais les « résultats » sont des URL mock:// que download() (fal.mjs) matérialise en fichiers valides :
//   mock://image/<h>.png  -> PNG 512x512 (objet flou sur fond blanc, couleur dérivée de la requête)
//   mock://mesh/<h>.glb   -> GLB valide (cube coloré, PBR) : se charge dans three.js / gltf-transform
// Sert à tester tout le pipeline (manifest, reprise, optimisation, rendu) sans clé ni réseau. Les assets sont factices.
import crypto from 'node:crypto';
import zlib from 'node:zlib';

const h = (...parts) => crypto.createHash('sha1').update(parts.map(p => typeof p === 'string' ? p : JSON.stringify(p)).join('|')).digest('hex').slice(0, 10);
const hue = (id) => parseInt(id.slice(0, 4), 16) % 360;
function hsl(hDeg, s, l) {
  const k = n => (n + hDeg / 30) % 12, a = s * Math.min(l, 1 - l);
  const f = n => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  return [f(0), f(8), f(4)].map(x => Math.round(x * 255));
}

export function pngBytes(id, size = 512) {
  const [r, g, b] = hsl(hue(id), 0.55, 0.5);
  const raw = Buffer.alloc((size * 3 + 1) * size);
  for (let y = 0; y < size; y++) {
    const row = y * (size * 3 + 1); raw[row] = 0;
    for (let x = 0; x < size; x++) {
      const d = Math.hypot(x - size / 2, y - size / 2) / (size * 0.32), t = Math.min(1, Math.max(0, 1 - d)) ** 0.8;
      const o = row + 1 + x * 3;
      raw[o] = 255 - (255 - r) * t; raw[o + 1] = 255 - (255 - g) * t; raw[o + 2] = 255 - (255 - b) * t;
    }
  }
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(zlib.crc32(td) >>> 0);
    return Buffer.concat([len, td, crc]);
  };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

export function glbBytes(id) {
  // cube de 1 m, 24 sommets (normales par face) + 36 indices
  const faces = [[[1, 0, 0], [0, 1, 0], [0, 0, 1]], [[-1, 0, 0], [0, 0, 1], [0, 1, 0]], [[0, 1, 0], [0, 0, 1], [1, 0, 0]],
    [[0, -1, 0], [1, 0, 0], [0, 0, 1]], [[0, 0, 1], [1, 0, 0], [0, 1, 0]], [[0, 0, -1], [0, 1, 0], [1, 0, 0]]];
  const pos = [], nor = [], idx = [];
  faces.forEach(([n, u, v], f) => {
    for (const [a, b] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
      for (let k = 0; k < 3; k++) pos.push(0.5 * (n[k] + a * u[k] + b * v[k]));
      nor.push(...n);
    }
    const o = f * 4; idx.push(o, o + 1, o + 2, o, o + 2, o + 3);
  });
  const bin = Buffer.concat([Buffer.from(new Float32Array(pos).buffer), Buffer.from(new Float32Array(nor).buffer), Buffer.from(new Uint16Array(idx).buffer)]);
  const [r, g, b] = hsl(hue(id), 0.55, 0.5).map(x => +(x / 255).toFixed(3));
  const json = {
    asset: { version: '2.0', generator: 'motion-bundle fal-mock' }, scene: 0, scenes: [{ nodes: [0] }], nodes: [{ mesh: 0, name: `mock-${id}` }],
    meshes: [{ primitives: [{ attributes: { POSITION: 0, NORMAL: 1 }, indices: 2, material: 0 }] }],
    materials: [{ pbrMetallicRoughness: { baseColorFactor: [r, g, b, 1], metallicFactor: 0.1, roughnessFactor: 0.7 } }],
    buffers: [{ byteLength: bin.length }],
    bufferViews: [{ buffer: 0, byteOffset: 0, byteLength: 288, target: 34962 }, { buffer: 0, byteOffset: 288, byteLength: 288, target: 34962 }, { buffer: 0, byteOffset: 576, byteLength: 72, target: 34963 }],
    accessors: [{ bufferView: 0, componentType: 5126, count: 24, type: 'VEC3', min: [-0.5, -0.5, -0.5], max: [0.5, 0.5, 0.5] },
      { bufferView: 1, componentType: 5126, count: 24, type: 'VEC3' }, { bufferView: 2, componentType: 5123, count: 36, type: 'SCALAR' }],
  };
  const pad = (buf, byte) => Buffer.concat([buf, Buffer.alloc((4 - buf.length % 4) % 4, byte)]);
  const j = pad(Buffer.from(JSON.stringify(json)), 0x20), bn = pad(bin, 0);
  const head = Buffer.alloc(12); head.write('glTF'); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + j.length + 8 + bn.length, 8);
  const ch = (len, type) => { const c = Buffer.alloc(8); c.writeUInt32LE(len, 0); c.write(type, 4); return c; };
  return Buffer.concat([head, ch(j.length, 'JSON'), j, ch(bn.length, 'BIN\0'), bn]);
}

// Octets d'une URL mock:// (utilisé par download()).
export function mockBytes(url) {
  const m = /^mock:\/\/(image|mesh|upload)\/([0-9a-f]+)/.exec(url);
  if (!m) throw new Error(`URL mock inconnue : ${url}`);
  return m[1] === 'mesh' ? glbBytes(m[2]) : pngBytes(m[2]);
}

const meshResult = (id, endpoint) => {
  const glb = { url: `mock://mesh/${id}.glb`, file_size: glbBytes(id).length };
  if (/rig|animat/i.test(endpoint)) return { rigged_character_glb: glb, animation_glb: glb, basic_animations: {} };
  return { model_glb: glb, thumbnail: { url: `mock://image/${id}.png` } };
};

export const fal = {
  config() {},
  async subscribe(endpoint, { input } = {}) {
    const id = h(endpoint, input ?? {});
    return { requestId: `mock-${id}`, data: { images: [{ url: `mock://image/${id}.png` }] } };
  },
  queue: {
    async submit(endpoint, { input } = {}) { return { request_id: `mock-${h(endpoint, input ?? {})}` }; },
    async status() { return { status: 'COMPLETED' }; },
    async result(endpoint, { requestId } = {}) { return { requestId, data: meshResult(String(requestId).replace(/^mock-/, ''), endpoint) }; },
  },
  storage: { async upload(blob) { return `mock://upload/${h(Buffer.from(await blob.arrayBuffer()).toString('base64').slice(0, 4096))}`; } },
};
