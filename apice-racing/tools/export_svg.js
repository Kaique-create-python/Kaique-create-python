// Exporta carros (vista de cima, bico para cima) e mapas dos circuitos como SVG.
// Uso: node tools/export_svg.js [pasta-saida]   (padrão: design/svg)
'use strict';
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', 'js');
for (const f of ['util.js', 'cars.js', 'tracks.js']) require(path.join(root, f));
const APX = globalThis.APX;
const { shade } = APX.util;
const out = process.argv[2] || path.join(__dirname, '..', 'design', 'svg');
fs.mkdirSync(out, { recursive: true });

const S = 6; // escala
const HL = 23, HW = 11;
const PAD = 8;
const W = (HW * 2 + PAD * 2) * S, H = (HL * 2 + PAD * 2) * S;
// coordenadas locais do carro (bico em +x) -> SVG com bico para cima
const T = (x, y) => [((y + HW + PAD) * S).toFixed(1), ((-x + HL + PAD) * S).toFixed(1)];
const f = (n) => (n * S).toFixed(1);

function outline(shape) {
  const segs = APX.CAR_SHAPES.OUTLINES[shape];
  let d = '';
  let cur = [segs[0][1], segs[0][2]];
  d += 'M' + T(cur[0], cur[1]).join(' ');
  const list = [];
  for (let i = 1; i < segs.length; i++) {
    const s = segs[i];
    if (s[0] === 'L') d += ' L' + T(s[1], s[2]).join(' ');
    else d += ' C' + T(s[1], s[2]).join(' ') + ' ' + T(s[3], s[4]).join(' ') + ' ' + T(s[5], s[6]).join(' ');
    list.push({ s, from: cur });
    cur = s[0] === 'L' ? [s[1], s[2]] : [s[5], s[6]];
  }
  for (let i = list.length - 1; i >= 0; i--) {
    const { s, from } = list[i];
    if (s[0] === 'L') d += ' L' + T(from[0], -from[1]).join(' ');
    else d += ' C' + T(s[3], -s[4]).join(' ') + ' ' + T(s[1], -s[2]).join(' ') + ' ' + T(from[0], -from[1]).join(' ');
  }
  return d + ' Z';
}

// retângulo em coordenadas locais -> retângulo SVG (girado 90°)
function rect(x, y, w, h, r, fill, extra) {
  const [sx, sy] = T(x + w, y);
  return `<rect x="${sx}" y="${sy}" width="${f(h)}" height="${f(w)}" rx="${f(r || 0)}" fill="${fill}"${extra || ''}/>`;
}

function carSvg(spec, paint) {
  const C = APX.CAR_SHAPES.CABINS[spec.shape];
  const trim = spec.trim;
  const body = outline(spec.shape);
  const parts = [];
  parts.push(`<defs>
<linearGradient id="b-${spec.id}" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${shade(paint, -0.45)}"/><stop offset="0.22" stop-color="${shade(paint, -0.05)}"/><stop offset="0.5" stop-color="${shade(paint, 0.18)}"/><stop offset="0.78" stop-color="${shade(paint, -0.05)}"/><stop offset="1" stop-color="${shade(paint, -0.5)}"/></linearGradient>
<linearGradient id="g-${spec.id}" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#0B0E17"/><stop offset="0.7" stop-color="#1B2333"/><stop offset="1" stop-color="#3B4A66"/></linearGradient>
</defs>`);
  // pneus
  const wy = spec.shape === 'proto' ? 10.4 : 10.2;
  for (const wx of [13.5, -13.5]) for (const sy of [-1, 1]) parts.push(rect(wx - 4.6, sy * wy - 2.6, 9.2, 5.2, 1.6, '#0A0B0F'));
  parts.push(`<path d="${body}" fill="url(#b-${spec.id})" stroke="#000000" stroke-opacity="0.55" stroke-width="${f(0.7)}"/>`);
  // faixas
  if (spec.shape === 'proto') parts.push(rect(-21, -0.9, 42, 1.8, 0, trim, ' opacity="0.9"'));
  else { parts.push(rect(-21.5, -3.4, 43.5, 1.7, 0, trim, ' opacity="0.9"')); parts.push(rect(-21.5, 1.7, 43.5, 1.7, 0, trim, ' opacity="0.9"')); }
  // cabine
  const p1 = T(C.front, -C.wF), q1 = T(C.front + 2.4, 0), p2 = T(C.front, C.wF), p3 = T(C.back, C.wB), q2 = T(C.back - 1.6, 0), p4 = T(C.back, -C.wB);
  parts.push(`<path d="M${p1.join(' ')} Q${q1.join(' ')} ${p2.join(' ')} L${p3.join(' ')} Q${q2.join(' ')} ${p4.join(' ')} Z" fill="url(#g-${spec.id})"/>`);
  if (spec.shape !== 'proto') {
    const rw = (C.wF + C.wB) / 2 - 1.4;
    parts.push(rect(C.roofB, -rw, C.roofF - C.roofB, rw * 2, 2.4, shade(paint, 0.06)));
    parts.push(rect(C.roofB, -3.4, C.roofF - C.roofB, 1.7, 0, trim, ' opacity="0.9"'));
    parts.push(rect(C.roofB, 1.7, C.roofF - C.roofB, 1.7, 0, trim, ' opacity="0.9"'));
  } else {
    const [cx, cy] = T(1.5, 0);
    parts.push(`<circle cx="${cx}" cy="${cy}" r="${f(3.4)}" fill="#F4F6FA"/>`);
    parts.push(rect(2.2, -3.4, 1.4, 6.8, 0, shade(paint, -0.2)));
  }
  // número
  const nx = spec.shape === 'gran' ? 12 : spec.shape === 'proto' ? 14 : 13.2;
  const [ncx, ncy] = T(nx, 0);
  parts.push(`<circle cx="${ncx}" cy="${ncy}" r="${f(3.6)}" fill="#F4F6FA"/>`);
  // aerofólio
  if (spec.shape !== 'muscle') {
    parts.push(rect(-23.6, -10.6, 3.4, 21.2, 1, shade(trim, 0.05)));
    parts.push(rect(-24, -11, 4.2, 1.6, 0, shade(paint, -0.35)));
    parts.push(rect(-24, 9.4, 4.2, 1.6, 0, shade(paint, -0.35)));
  } else parts.push(rect(-22.6, -9.6, 1.6, 19.2, 0, shade(trim, 0.05)));
  // faróis e lanternas
  const hx = spec.shape === 'proto' ? 19.6 : spec.shape === 'muscle' ? 22 : 20.6;
  const hy = spec.shape === 'proto' ? 4.6 : 7.2;
  for (const sy of [-1, 1]) {
    const [ex, ey] = T(hx, sy * hy);
    parts.push(`<ellipse cx="${ex}" cy="${ey}" rx="${f(2.3)}" ry="${f(1.5)}" fill="#FFF4D2"/>`);
    parts.push(rect(-23.1, sy * 7.4 - 2, 1.4, 4, 0.5, '#B3122A'));
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${parts.join('')}</svg>`;
}

function trackSvg(t, size) {
  const b = t.bounds;
  const pad = 24;
  const s = Math.min((size - pad * 2) / (b.maxX - b.minX), (size * 0.7 - pad * 2) / (b.maxY - b.minY));
  const w = Math.round((b.maxX - b.minX) * s + pad * 2), h = Math.round((b.maxY - b.minY) * s + pad * 2);
  const P = (i) => [((t.xs[i] - b.minX) * s + pad).toFixed(1), ((t.ys[i] - b.minY) * s + pad).toFixed(1)];
  const step = 10;
  const all = [];
  for (let i = 0; i < t.N; i += step) all.push(P(i).join(' '));
  const full = 'M' + all.join(' L') + ' Z';
  const cols = ['#FF6A1F', '#45E0FF', '#FFC23A'];
  const sectors = [0, 1, 2].map((k) => {
    const a = Math.floor((k * t.N) / 3), e = Math.floor(((k + 1) * t.N) / 3);
    const pts = [];
    for (let i = a; i <= e; i += step) pts.push(P(i % t.N).join(' '));
    pts.push(P(e % t.N).join(' '));
    return `<path d="M${pts.join(' L')}" fill="none" stroke="${cols[k]}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/>`;
  });
  const [sx, sy] = P(0);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><path d="${full}" fill="none" stroke="#EEF1F7" stroke-opacity="0.12" stroke-width="22" stroke-linejoin="round"/>${sectors.join('')}<circle cx="${sx}" cy="${sy}" r="8" fill="#EEF1F7"/></svg>`;
}

const manifest = { cars: {}, tracks: {} };
for (const c of APX.CARS) {
  const svg = carSvg(c, c.paint);
  fs.writeFileSync(path.join(out, `carro-${c.id}.svg`), svg);
  manifest.cars[c.id] = svg;
}
for (const t of APX.getTracks()) {
  const svg = trackSvg(t, 520);
  fs.writeFileSync(path.join(out, `circuito-${t.id}.svg`), svg);
  manifest.tracks[t.id] = svg;
}
if (process.argv[3]) fs.writeFileSync(process.argv[3], JSON.stringify(manifest));
console.log('SVGs em', out, Object.keys(manifest.cars).length, 'carros,', Object.keys(manifest.tracks).length, 'circuitos');
