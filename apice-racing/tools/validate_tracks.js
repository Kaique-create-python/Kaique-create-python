// Valida a geometria dos circuitos: raio mínimo e folga entre trechos.
// Uso: node tools/validate_tracks.js
'use strict';
const path = require('path');
const root = path.join(__dirname, '..', 'js');
require(path.join(root, 'util.js'));
require(path.join(root, 'tracks.js'));
const APX = globalThis.APX;

let ok = true;
for (const t of APX.getTracks()) {
  const { N, ds } = t;
  let minR = Infinity, minRi = 0;
  for (let i = 0; i < N; i++) {
    const r = 1 / Math.max(Math.abs(t.curv[i]), 1e-6);
    if (r < minR) { minR = r; minRi = i; }
  }
  // menor distância entre amostras separadas por mais de 1,2 km de pista... ou meia volta
  let minGap = Infinity, gi = 0, gj = 0;
  const sep = Math.round(Math.max(900, t.wall * 6) / ds);
  for (let i = 0; i < N; i += 2) {
    for (let j = i + sep; j < N; j += 2) {
      if (N - (j - i) < sep) continue;
      const d = Math.hypot(t.xs[i] - t.xs[j], t.ys[i] - t.ys[j]);
      if (d < minGap) { minGap = d; gi = i; gj = j; }
    }
  }
  const needGap = 2 * t.wall + 40;
  const needR = t.wall + 20;
  const good = minGap >= needGap && minR >= needR;
  if (!good) ok = false;
  console.log(
    `${t.name.padEnd(14)} ${String(t.lengthM).padStart(5)} m  curvas ${String(t.curves).padStart(2)}  ` +
    `raio mín ${minR.toFixed(0).padStart(4)} (precisa ${needR}) @${minRi} [${t.xs[minRi].toFixed(0)},${t.ys[minRi].toFixed(0)}]  ` +
    `folga mín ${minGap.toFixed(0).padStart(4)} (precisa ${needGap}) @${gi}/${gj}  ` +
    `decor ${t.decor.length} postes ${t.lamps.length} arquib ${t.stands.length}  ${good ? 'OK' : 'FALHOU'}`
  );
}
process.exit(ok ? 0 : 1);
