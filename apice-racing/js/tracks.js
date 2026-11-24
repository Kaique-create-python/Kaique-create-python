/* Ápice Racing — circuitos: geometria, traçado ideal, perfil de velocidade e cenário */
'use strict';
(function (APX) {
  const { clamp, lerp, wrapAngle, mulberry32 } = APX.util;

  const SPACING = 8; // px entre amostras da linha central (0,8 m)

  const THEMES = {
    night: {
      label: 'Noite', grip: 1.0,
      runoff: { grip: 0.78, drag: 0.85, maxMul: 0.72, kind: 'calçada' },
      ground: '#1B1E2B', groundLine: '#232838', asphalt: '#2A2D38', runoffCol: '#202331',
      edge: '#D9DEEA', curbA: '#E9EDF5', curbB: '#FF3B6B', barrier: '#3A4054',
      neonA: '#38E1FF', neonB: '#FF4FA3', dust: '#9AA3BA', sky: 'night',
    },
    desert: {
      label: 'Entardecer', grip: 0.97,
      runoff: { grip: 0.6, drag: 1.35, maxMul: 0.56, kind: 'areia' },
      ground: '#D9A066', groundLine: '#C98E55', asphalt: '#4A4448', runoffCol: '#C98F5A',
      edge: '#F6EFE6', curbA: '#F6EFE6', curbB: '#D3332F', barrier: '#1A1A1E',
      neonA: '#FFB347', neonB: '#FF6A3D', dust: '#E7B67C', sky: 'sunset',
    },
    snow: {
      label: 'Gelo', grip: 0.9,
      runoff: { grip: 0.5, drag: 1.15, maxMul: 0.6, kind: 'neve' },
      ground: '#E8EEF6', groundLine: '#D5DEEA', asphalt: '#3B4250', runoffCol: '#CFD9E6',
      edge: '#FFFFFF', curbA: '#FFFFFF', curbB: '#2F6BFF', barrier: '#F4F7FB',
      neonA: '#9FD8FF', neonB: '#2F6BFF', dust: '#FFFFFF', sky: 'snow',
    },
  };

  const DEFS = [
    {
      id: 'distrito', name: 'Distrito Neon', place: 'Circuito urbano noturno',
      blurb: 'Muros de concreto, letreiros acesos e curvas de esquina. Errou, bateu.',
      theme: 'night', hw: 94, runoff: 52, seed: 1107,
      points: [
        [500, 520], [1500, 470], [2350, 470], [2950, 760], [3150, 1250], [3650, 1330],
        [4150, 1700], [4080, 2420], [3450, 2720], [2850, 2380], [2250, 2700],
        [1450, 2830], [880, 2740], [640, 2330], [1120, 1960], [860, 1480], [420, 1180],
      ],
      pads: [0.32, 0.71],
    },
    {
      id: 'dunas', name: 'Dunas de Sal', place: 'Deserto ao entardecer',
      blurb: 'Retas longas, curvas de alta e areia fofa fora do asfalto.',
      theme: 'desert', hw: 104, runoff: 74, seed: 2203,
      points: [
        [620, 1850], [820, 900], [1550, 430], [2600, 520], [3350, 330], [4250, 640],
        [4560, 1350], [4050, 1950], [3350, 1830], [2800, 2120], [2780, 2600], [3250, 2830], [3200, 3250],
        [2550, 3400], [1600, 3220], [980, 2750],
      ],
      pads: [0.22, 0.6],
    },
    {
      id: 'serra', name: 'Serra Gelada', place: 'Montanha com gelo na pista',
      blurb: 'Grampos fechados e placas de gelo. Freie em linha reta.',
      theme: 'snow', hw: 98, runoff: 62, seed: 3331,
      points: [
        [720, 700], [1650, 480], [2330, 640], [2560, 1080], [2150, 1520], [2750, 1950], [3500, 1420],
        [4250, 1700], [4330, 2620], [3620, 3120], [2620, 2900], [1900, 3320],
        [1000, 3020], [1320, 2230], [700, 1720],
      ],
      pads: [0.42],
      ice: 7,
    },
  ];

  /* ---------- Spline Catmull-Rom centrípeta fechada ---------- */
  function catmullRomClosed(pts, steps) {
    const out = [];
    const n = pts.length;
    const d = (a, b) => Math.pow(Math.hypot(b[0] - a[0], b[1] - a[1]), 0.5) || 1e-4;
    for (let i = 0; i < n; i++) {
      const P0 = pts[(i - 1 + n) % n], P1 = pts[i], P2 = pts[(i + 1) % n], P3 = pts[(i + 2) % n];
      const t0 = 0, t1 = t0 + d(P0, P1), t2 = t1 + d(P1, P2), t3 = t2 + d(P2, P3);
      for (let s = 0; s < steps; s++) {
        const t = t1 + ((t2 - t1) * s) / steps;
        const mix = (A, B, ta, tb) => {
          const u = (tb - t) / (tb - ta), v = (t - ta) / (tb - ta);
          return [A[0] * u + B[0] * v, A[1] * u + B[1] * v];
        };
        const A1 = mix(P0, P1, t0, t1), A2 = mix(P1, P2, t1, t2), A3 = mix(P2, P3, t2, t3);
        const B1 = mix(A1, A2, t0, t2), B2 = mix(A2, A3, t1, t3);
        out.push(mix(B1, B2, t1, t2));
      }
    }
    return out;
  }

  function resample(dense, spacing) {
    const n = dense.length;
    const seg = new Float64Array(n);
    let total = 0;
    for (let i = 0; i < n; i++) {
      const a = dense[i], b = dense[(i + 1) % n];
      seg[i] = Math.hypot(b[0] - a[0], b[1] - a[1]);
      total += seg[i];
    }
    const N = Math.round(total / spacing);
    const ds = total / N;
    const xs = new Float32Array(N), ys = new Float32Array(N);
    let j = 0, acc = 0;
    for (let k = 0; k < N; k++) {
      const target = k * ds;
      while (acc + seg[j] < target && j < n - 1) { acc += seg[j]; j++; }
      const t = seg[j] > 0 ? (target - acc) / seg[j] : 0;
      const a = dense[j], b = dense[(j + 1) % n];
      xs[k] = a[0] + (b[0] - a[0]) * t;
      ys[k] = a[1] + (b[1] - a[1]) * t;
    }
    return { xs, ys, N, ds, length: total };
  }

  function rotateArr(arr, k) {
    const N = arr.length, out = new arr.constructor(N);
    for (let i = 0; i < N; i++) out[i] = arr[(i + k) % N];
    return out;
  }

  function computeFrames(xs, ys, N, ds) {
    const tx = new Float32Array(N), ty = new Float32Array(N), nx = new Float32Array(N), ny = new Float32Array(N);
    const ang = new Float32Array(N), curv = new Float32Array(N);
    for (let i = 0; i < N; i++) {
      const a = (i - 1 + N) % N, b = (i + 1) % N;
      let dx = xs[b] - xs[a], dy = ys[b] - ys[a];
      const l = Math.hypot(dx, dy) || 1;
      dx /= l; dy /= l;
      tx[i] = dx; ty[i] = dy; nx[i] = -dy; ny[i] = dx;
      ang[i] = Math.atan2(dy, dx);
    }
    const K = 3;
    for (let i = 0; i < N; i++) {
      curv[i] = wrapAngle(ang[(i + K) % N] - ang[(i - K + N) % N]) / (2 * K * ds);
    }
    return { tx, ty, nx, ny, ang, curv };
  }

  function smoothArr(arr, N, radius, passes) {
    let a = arr;
    for (let p = 0; p < passes; p++) {
      const out = new Float32Array(N);
      for (let i = 0; i < N; i++) {
        let s = 0;
        for (let k = -radius; k <= radius; k++) s += a[(i + k + N) % N];
        out[i] = s / (2 * radius + 1);
      }
      a = out;
    }
    return a;
  }

  function buildTrack(def) {
    const theme = THEMES[def.theme];
    const dense = catmullRomClosed(def.points, 48);
    let { xs, ys, N, ds, length } = resample(dense, SPACING);

    // suaviza levemente a geometria
    for (let p = 0; p < 2; p++) {
      const sx = smoothArr(xs, N, 2, 1), sy = smoothArr(ys, N, 2, 1);
      xs = sx; ys = sy;
    }

    // abre curvas fechadas demais: o muro interno precisa caber dentro do raio
    const minR = def.hw + def.runoff + 46;
    for (let it = 0; it < 400; it++) {
      const fr = computeFrames(xs, ys, N, ds);
      const cs = smoothArr(fr.curv, N, 6, 2);
      const mask = new Uint8Array(N);
      let bad = false;
      for (let i = 0; i < N; i++) {
        if (Math.abs(cs[i]) > 1 / minR) {
          bad = true;
          for (let k = -14; k <= 14; k++) mask[(i + k + N) % N] = 1;
        }
      }
      if (!bad) break;
      const sx = xs.slice(), sy = ys.slice();
      for (let i = 0; i < N; i++) {
        if (!mask[i]) continue;
        let ax = 0, ay = 0;
        for (let k = -6; k <= 6; k++) { ax += xs[(i + k + N) % N]; ay += ys[(i + k + N) % N]; }
        sx[i] = ax / 13; sy[i] = ay / 13;
      }
      xs = sx; ys = sy;
    }
    {
      const dense2 = [];
      for (let i = 0; i < N; i++) dense2.push([xs[i], ys[i]]);
      ({ xs, ys, N, ds, length } = resample(dense2, SPACING));
    }

    let f = computeFrames(xs, ys, N, ds);

    // largada: 72% de dentro do trecho mais reto
    const W = Math.round(760 / ds);
    let best = Infinity, bestI = 0;
    let acc = 0;
    for (let k = 0; k < W; k++) acc += Math.abs(f.curv[k]);
    for (let i = 0; i < N; i++) {
      if (acc < best) { best = acc; bestI = i; }
      acc += Math.abs(f.curv[(i + W) % N]) - Math.abs(f.curv[i]);
    }
    const start = (bestI + Math.round(W * 0.72)) % N;
    xs = rotateArr(xs, start);
    ys = rotateArr(ys, start);
    f = computeFrames(xs, ys, N, ds);

    const hw = def.hw;
    const curvS = smoothArr(f.curv, N, 6, 2);

    // traçado ideal: relaxação elástica dentro do corredor
    const lim = hw * 0.74;
    const off = new Float32Array(N);
    const px = new Float32Array(N), py = new Float32Array(N);
    const upd = () => {
      for (let i = 0; i < N; i++) { px[i] = xs[i] + f.nx[i] * off[i]; py[i] = ys[i] + f.ny[i] * off[i]; }
    };
    upd();
    for (let it = 0; it < 420; it++) {
      const k = it < 160 ? 14 : it < 320 ? 7 : 3;
      for (let i = 0; i < N; i++) {
        const a = (i - k + N) % N, b = (i + k) % N;
        const mx = (px[a] + px[b]) / 2, my = (py[a] + py[b]) / 2;
        const o = (mx - xs[i]) * f.nx[i] + (my - ys[i]) * f.ny[i];
        off[i] = clamp(lerp(off[i], o, 0.6), -lim, lim);
        px[i] = xs[i] + f.nx[i] * off[i];
        py[i] = ys[i] + f.ny[i] * off[i];
      }
    }
    const offS = smoothArr(off, N, 3, 2);
    const rx = new Float32Array(N), ry = new Float32Array(N);
    for (let i = 0; i < N; i++) { rx[i] = xs[i] + f.nx[i] * offS[i]; ry[i] = ys[i] + f.ny[i] * offS[i]; }
    const rf = computeFrames(rx, ry, N, ds);
    const rcurv = smoothArr(rf.curv, N, 4, 2);

    // bbox
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (let i = 0; i < N; i++) {
      minX = Math.min(minX, xs[i]); maxX = Math.max(maxX, xs[i]);
      minY = Math.min(minY, ys[i]); maxY = Math.max(maxY, ys[i]);
    }

    // contagem de curvas
    let curves = 0, inCurve = false;
    for (let i = 0; i < N; i++) {
      const c = Math.abs(curvS[i]);
      if (!inCurve && c > 1 / 520) { inCurve = true; curves++; }
      else if (inCurve && c < 1 / 900) inCurve = false;
    }

    const track = {
      def, id: def.id, name: def.name, place: def.place, blurb: def.blurb,
      theme, themeId: def.theme, hw, runoff: def.runoff, wall: hw + def.runoff,
      N, ds, length, xs, ys, tx: f.tx, ty: f.ty, nx: f.nx, ny: f.ny, ang: f.ang, curv: curvS,
      rOff: offS, rx, ry, rcurv,
      bounds: { minX, minY, maxX, maxY },
      lengthM: Math.round((N * ds) / 10),
      curves,
      profiles: new Map(),
      pads: [], ice: [], decor: [], lamps: [], stands: [],
    };

    buildFeatures(track);
    buildDecor(track);
    return track;
  }

  /* ---------- Consultas ---------- */
  function nearest(track, x, y, hint) {
    const N = track.N;
    let best = Infinity, bi = 0;
    if (hint != null && hint >= 0) {
      for (let k = -36; k <= 36; k++) {
        const i = (hint + k + N) % N;
        const dx = x - track.xs[i], dy = y - track.ys[i];
        const d = dx * dx + dy * dy;
        if (d < best) { best = d; bi = i; }
      }
      if (best < (track.wall + 60) * (track.wall + 60)) return bi;
      best = Infinity;
    }
    for (let i = 0; i < N; i += 2) {
      const dx = x - track.xs[i], dy = y - track.ys[i];
      const d = dx * dx + dy * dy;
      if (d < best) { best = d; bi = i; }
    }
    for (let k = -2; k <= 2; k++) {
      const i = (bi + k + N) % N;
      const dx = x - track.xs[i], dy = y - track.ys[i];
      const d = dx * dx + dy * dy;
      if (d < best) { best = d; bi = i; }
    }
    return bi;
  }

  function lateral(track, i, x, y) {
    return (x - track.xs[i]) * track.nx[i] + (y - track.ys[i]) * track.ny[i];
  }

  function distToTrack(track, x, y, step) {
    let best = Infinity;
    for (let i = 0; i < track.N; i += step || 3) {
      const dx = x - track.xs[i], dy = y - track.ys[i];
      const d = dx * dx + dy * dy;
      if (d < best) best = d;
    }
    return Math.sqrt(best);
  }

  // Perfil de velocidade alvo para um carro (usado pela IA)
  function profileFor(track, spec) {
    if (track.profiles.has(spec.id)) return track.profiles.get(spec.id);
    const N = track.N, ds = track.ds;
    const v = new Float32Array(N);
    const turn = spec.turn * 0.8 * track.theme.grip;
    const vm = spec.maxSpeed;
    for (let i = 0; i < N; i++) {
      const k = Math.max(Math.abs(track.rcurv[i]), 1e-5);
      // velocidade limite pela taxa de guinada: v <= turn*(1-0.35 v/vm)/k
      const base = turn / k;
      v[i] = Math.min(vm * 1.4, base / (1 + (0.35 * base) / vm));
    }
    const D = 620 * track.theme.grip;
    for (let pass = 0; pass < 2; pass++) {
      for (let j = N - 1; j >= 0; j--) {
        const nxt = v[(j + 1) % N];
        v[j] = Math.min(v[j], Math.sqrt(nxt * nxt + 2 * D * ds));
      }
    }
    // gelo: reduz o alvo nas placas
    for (const ic of track.ice) {
      for (let k = -40; k <= 10; k++) {
        const i = (ic.idx + k + N) % N;
        v[i] = Math.min(v[i], 380);
      }
    }
    track.profiles.set(spec.id, v);
    return v;
  }

  /* ---------- Elementos de pista ---------- */
  function buildFeatures(track) {
    const def = track.def, N = track.N;
    const rng = mulberry32(def.seed + 7);
    for (const frac of def.pads || []) {
      // acha o trecho mais reto perto da fração pedida
      let bi = Math.round(frac * N), bc = Infinity;
      for (let k = -60; k <= 60; k++) {
        const i = (Math.round(frac * N) + k + N) % N;
        let c = 0;
        for (let m = -12; m <= 12; m++) c += Math.abs(track.curv[(i + m + N) % N]);
        if (c < bc) { bc = c; bi = i; }
      }
      const off = track.rOff[bi] * 0.6;
      track.pads.push({
        idx: bi, off,
        x: track.xs[bi] + track.nx[bi] * off,
        y: track.ys[bi] + track.ny[bi] * off,
        a: track.ang[bi], len: 84, w: 56,
      });
    }
    const nIce = def.ice || 0;
    for (let n = 0; n < nIce; n++) {
      let i = Math.floor(((n + 0.5) / nIce) * N + (rng() - 0.5) * N * 0.06) % N;
      if (i < 60 || i > N - 80) i = (i + 140) % N;
      const side = rng() < 0.5 ? -1 : 1;
      const off = side * track.hw * (0.15 + rng() * 0.45);
      const r = 46 + rng() * 34;
      const blobs = [];
      for (let b = 0; b < 5; b++) {
        blobs.push({ dx: (rng() - 0.5) * r * 0.9, dy: (rng() - 0.5) * r * 0.6, r: r * (0.45 + rng() * 0.4) });
      }
      track.ice.push({ idx: i, x: track.xs[i] + track.nx[i] * off, y: track.ys[i] + track.ny[i] * off, r, a: track.ang[i], blobs });
    }
  }

  function placeStand(track, side) {
    // arquibancada ao longo da reta principal
    const N = track.N;
    const i = (N - Math.round(110 / track.ds)) % N;
    const dist = track.wall + 64;
    const len = 420, depth = 74;
    const cx = track.xs[i] + track.nx[i] * dist * side;
    const cy = track.ys[i] + track.ny[i] * dist * side;
    const a = track.ang[i];
    // verifica cantos
    const ca = Math.cos(a), sa = Math.sin(a);
    for (const [u, v] of [[-len / 2, -depth / 2], [len / 2, -depth / 2], [-len / 2, depth / 2], [len / 2, depth / 2], [0, 0]]) {
      const x = cx + u * ca - v * sa, y = cy + u * sa + v * ca;
      if (distToTrack(track, x, y, 2) < track.wall + 18) return null;
    }
    return { x: cx, y: cy, a, len, depth, side };
  }

  function buildDecor(track) {
    const rng = mulberry32(track.def.seed);
    const b = track.bounds;
    const M = 900;
    const x0 = b.minX - M, y0 = b.minY - M, x1 = b.maxX + M, y1 = b.maxY + M;
    track.world = { x0, y0, x1, y1 };
    const decor = [];
    const clearOf = (x, y, r, extra) => distToTrack(track, x, y, 3) > track.wall + r + (extra || 24);

    for (const side of [-1, 1]) {
      const st = placeStand(track, side);
      if (st) { track.stands.push(st); break; }
    }
    const nearStand = (x, y, r) => track.stands.some((s) => Math.hypot(x - s.x, y - s.y) < s.len / 2 + r + 30);

    // postes de luz/bandeiras ao longo da pista
    const lampEvery = Math.round((track.themeId === 'night' ? 250 : 520) / track.ds);
    for (let i = 0, k = 0; i < track.N; i += lampEvery, k++) {
      const side = k % 2 ? 1 : -1;
      const d = track.wall + 26;
      const x = track.xs[i] + track.nx[i] * d * side, y = track.ys[i] + track.ny[i] * d * side;
      if (distToTrack(track, x, y, 2) < track.wall + 10) continue;
      if (nearStand(x, y, 10)) continue;
      // braço do poste aponta para a pista
      const dx = -track.nx[i] * side, dy = -track.ny[i] * side;
      track.lamps.push({ x, y, a: track.ang[i] + (side > 0 ? Math.PI : 0), side, lx: x + dx * 80, ly: y + dy * 80 });
    }

    if (track.themeId === 'night') {
      const cell = 250;
      for (let gx = x0; gx < x1; gx += cell) {
        for (let gy = y0; gy < y1; gy += cell) {
          const w = 150 + rng() * 80, h = 150 + rng() * 80;
          const cx = gx + cell / 2 + (rng() - 0.5) * 20, cy = gy + cell / 2 + (rng() - 0.5) * 20;
          const r = Math.hypot(w, h) / 2;
          if (!clearOf(cx, cy, r, 34) || nearStand(cx, cy, r)) {
            // praça pequena com árvores se couber
            if (clearOf(cx, cy, 30, 30) && !nearStand(cx, cy, 30) && rng() < 0.35) {
              decor.push({ type: 'tree', x: cx, y: cy, r: 18 + rng() * 10, v: Math.floor(rng() * 3), rot: rng() * 6.28, layer: 1 });
            }
            continue;
          }
          const roof = Math.floor(rng() * 4);
          const details = [];
          const nd = 2 + Math.floor(rng() * 4);
          for (let d = 0; d < nd; d++) {
            details.push({ x: (rng() - 0.5) * (w - 50), y: (rng() - 0.5) * (h - 50), w: 14 + rng() * 22, h: 12 + rng() * 18 });
          }
          decor.push({
            type: 'bldg', x: cx, y: cy, w, h, r, roof, details,
            heli: rng() < 0.12, neon: rng() < 0.45 ? (rng() < 0.5 ? 'A' : 'B') : null,
            hgt: 14 + rng() * 26, layer: 1,
          });
        }
      }
    } else if (track.themeId === 'desert') {
      for (let n = 0; n < 26; n++) {
        const x = x0 + rng() * (x1 - x0), y = y0 + rng() * (y1 - y0);
        decor.push({ type: 'dune', x, y, rx: 260 + rng() * 380, ry: 90 + rng() * 140, rot: -0.5 + rng() * 0.3, layer: 0 });
      }
      for (let n = 0; n < 900; n++) {
        const x = x0 + rng() * (x1 - x0), y = y0 + rng() * (y1 - y0);
        const roll = rng();
        const type = roll < 0.42 ? 'rock' : roll < 0.75 ? 'bush' : 'cactus';
        const r = type === 'rock' ? 10 + rng() * 26 : type === 'bush' ? 8 + rng() * 10 : 9 + rng() * 6;
        if (!clearOf(x, y, r, 18) || nearStand(x, y, r)) continue;
        const pts = [];
        const np = 7 + Math.floor(rng() * 4);
        for (let k = 0; k < np; k++) {
          const t = (k / np) * Math.PI * 2;
          pts.push([Math.cos(t) * r * (0.7 + rng() * 0.35), Math.sin(t) * r * (0.7 + rng() * 0.35)]);
        }
        decor.push({ type, x, y, r, pts, rot: rng() * 6.28, v: Math.floor(rng() * 3), layer: type === 'rock' ? 0 : 1 });
      }
    } else {
      for (let n = 0; n < 4; n++) {
        const x = x0 + rng() * (x1 - x0), y = y0 + rng() * (y1 - y0);
        const rx = 200 + rng() * 220, ry = 120 + rng() * 140;
        if (!clearOf(x, y, Math.max(rx, ry), 40)) continue;
        decor.push({ type: 'lake', x, y, rx, ry, rot: rng() * 3, layer: 0 });
      }
      for (let n = 0; n < 1500; n++) {
        const x = x0 + rng() * (x1 - x0), y = y0 + rng() * (y1 - y0);
        const isRock = rng() < 0.14;
        const r = isRock ? 12 + rng() * 18 : 18 + rng() * 22;
        if (!clearOf(x, y, r * 0.7, 14) || nearStand(x, y, r)) continue;
        if (decor.some((d) => d.type === 'lake' && Math.hypot((x - d.x) / d.rx, (y - d.y) / d.ry) < 1.15)) continue;
        const pts = [];
        const np = 7 + Math.floor(rng() * 3);
        for (let k = 0; k < np; k++) {
          const t = (k / np) * Math.PI * 2;
          pts.push([Math.cos(t) * r * (0.72 + rng() * 0.3), Math.sin(t) * r * (0.72 + rng() * 0.3)]);
        }
        decor.push({ type: isRock ? 'srock' : 'pine', x, y, r, pts, rot: rng() * 6.28, v: Math.floor(rng() * 3), layer: isRock ? 0 : 1 });
      }
    }
    // ordena por Y para profundidade
    decor.sort((a, b) => a.layer - b.layer || a.y - b.y);
    track.decor = decor;
  }

  let cache = null;
  function getTracks() {
    if (!cache) cache = DEFS.map(buildTrack);
    return cache;
  }

  APX.TRACK_DEFS = DEFS;
  APX.THEMES = THEMES;
  APX.getTracks = getTracks;
  APX.trackFns = { nearest, lateral, distToTrack, profileFor };
})(APX);
