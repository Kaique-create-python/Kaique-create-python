/* Ápice Racing — renderizador Canvas 2D: pista, cenário, carros, luz e partículas */
'use strict';
(function (APX) {
  const { clamp, mulberry32, rgba, shade } = APX.util;

  function makeCanvas(w, h) {
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    return c;
  }

  /* ---------- Texturas procedurais ---------- */
  function hexRGB(hex) {
    const n = parseInt(hex.slice(1), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  function noiseTile(size, base, opts, seed) {
    const rng = mulberry32(seed);
    const c = makeCanvas(size, size);
    const ctx = c.getContext('2d');
    const img = ctx.createImageData(size, size);
    const [r0, g0, b0] = hexRGB(base);
    const v = opts.variance || 8;
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        let n = (rng() - 0.5) * 2 * v;
        if (opts.ripple) n += Math.sin((x * 0.05 + Math.sin(y * 0.02) * 2.2) + y * 0.11) * opts.ripple;
        if (opts.speck && rng() < opts.speck) n += (rng() < 0.5 ? -1 : 1) * (opts.speckAmt || 26);
        const k = (y * size + x) * 4;
        img.data[k] = clamp(r0 + n * (opts.tint ? opts.tint[0] : 1), 0, 255);
        img.data[k + 1] = clamp(g0 + n * (opts.tint ? opts.tint[1] : 1), 0, 255);
        img.data[k + 2] = clamp(b0 + n * (opts.tint ? opts.tint[2] : 1), 0, 255);
        img.data[k + 3] = 255;
      }
    }
    ctx.putImageData(img, 0, 0);
    if (opts.grid) {
      ctx.strokeStyle = opts.grid;
      ctx.lineWidth = 2;
      for (let p = 0; p <= size; p += opts.gridSize) {
        ctx.beginPath(); ctx.moveTo(p, 0); ctx.lineTo(p, size); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0, p); ctx.lineTo(size, p); ctx.stroke();
      }
    }
    if (opts.cracks) {
      ctx.strokeStyle = opts.cracks;
      ctx.lineWidth = 1.2;
      for (let i = 0; i < 6; i++) {
        let x = rng() * size, y = rng() * size;
        ctx.beginPath(); ctx.moveTo(x, y);
        for (let s = 0; s < 6; s++) { x += (rng() - 0.5) * 40; y += (rng() - 0.5) * 40; ctx.lineTo(x, y); }
        ctx.stroke();
      }
    }
    return c;
  }

  function softStamp(size, color, inner) {
    const c = makeCanvas(size, size);
    const ctx = c.getContext('2d');
    const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
    g.addColorStop(0, color);
    g.addColorStop(inner || 0.35, rgbaFrom(color, 0.55));
    g.addColorStop(1, rgbaFrom(color, 0));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, size, size);
    return c;
  }

  function rgbaFrom(color, a) {
    if (color.startsWith('#')) return rgba(color, a);
    const m = color.match(/rgba?\(([^)]+)\)/);
    const p = m[1].split(',').map((s) => s.trim());
    return 'rgba(' + p[0] + ',' + p[1] + ',' + p[2] + ',' + a + ')';
  }

  function coneStamp(len, spread, color) {
    const w = len, h = Math.ceil(Math.tan(spread) * len * 2) + 4;
    const c = makeCanvas(w, h);
    const ctx = c.getContext('2d');
    const g = ctx.createRadialGradient(0, h / 2, 0, 0, h / 2, len);
    g.addColorStop(0, rgbaFrom(color, 1));
    g.addColorStop(0.4, rgbaFrom(color, 0.55));
    g.addColorStop(1, rgbaFrom(color, 0));
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, h / 2 - 6);
    ctx.lineTo(len, 0);
    ctx.lineTo(len, h);
    ctx.lineTo(0, h / 2 + 6);
    ctx.closePath();
    ctx.filter = 'blur(6px)';
    ctx.fill();
    ctx.filter = 'none';
    return { canvas: c, w, h };
  }

  /* ---------- Sprites de cenário ---------- */
  function pineSprite(r, variant, seed) {
    const S = 2;
    const size = Math.ceil(r * 2 + 30);
    const c = makeCanvas(size * S, size * S);
    const ctx = c.getContext('2d');
    ctx.scale(S, S);
    ctx.translate(size / 2, size / 2);
    const rng = mulberry32(seed);
    // sombra
    ctx.fillStyle = 'rgba(40,60,100,0.22)';
    ctx.beginPath();
    ctx.ellipse(8, 7, r * 0.95, r * 0.8, 0.5, 0, Math.PI * 2);
    ctx.fill();
    const greens = [['#16392C', '#1F4D3A', '#2B664C'], ['#173B33', '#22533F', '#2F6E52'], ['#1A3A2A', '#264F36', '#356B45']][variant % 3];
    for (let layer = 0; layer < 3; layer++) {
      const rr = r * (1 - layer * 0.28);
      const spikes = 9 + layer;
      ctx.beginPath();
      for (let k = 0; k < spikes * 2; k++) {
        const t = (k / (spikes * 2)) * Math.PI * 2 + layer * 0.3;
        const rad = k % 2 === 0 ? rr : rr * (0.62 + rng() * 0.08);
        ctx.lineTo(Math.cos(t) * rad - layer * 1.4, Math.sin(t) * rad - layer * 1.4);
      }
      ctx.closePath();
      ctx.fillStyle = greens[layer];
      ctx.fill();
      // neve nas pontas
      ctx.fillStyle = 'rgba(245,250,255,0.85)';
      for (let k = 0; k < spikes; k++) {
        if (rng() < 0.55) continue;
        const t = (k / spikes) * Math.PI * 2 + layer * 0.3 + 0.15;
        ctx.beginPath();
        ctx.arc(Math.cos(t) * rr * 0.72 - layer * 1.4, Math.sin(t) * rr * 0.72 - layer * 1.4, 1.6 + rng() * 2.2, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.beginPath();
    ctx.arc(-4, -4, 2.4, 0, Math.PI * 2);
    ctx.fill();
    return { canvas: c, size };
  }

  function treeSprite(r, variant, seed) {
    const S = 2;
    const size = Math.ceil(r * 2 + 24);
    const c = makeCanvas(size * S, size * S);
    const ctx = c.getContext('2d');
    ctx.scale(S, S);
    ctx.translate(size / 2, size / 2);
    const rng = mulberry32(seed);
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.beginPath();
    ctx.arc(5, 6, r, 0, Math.PI * 2);
    ctx.fill();
    const cols = [['#163028', '#1F4236', '#2A5646'], ['#1A2E2C', '#24423C', '#30574F'], ['#1C2A22', '#28402F', '#35553C']][variant % 3];
    for (let i = 0; i < 3; i++) {
      ctx.fillStyle = cols[i];
      for (let k = 0; k < 6; k++) {
        const t = rng() * Math.PI * 2;
        const d = r * 0.35 * (1 - i * 0.3);
        ctx.beginPath();
        ctx.arc(Math.cos(t) * d - i * 2, Math.sin(t) * d - i * 2, r * (0.62 - i * 0.14), 0, Math.PI * 2);
        ctx.fill();
      }
    }
    return { canvas: c, size };
  }

  function standSprite(st, seed) {
    const S = 2;
    const c = makeCanvas(Math.ceil(st.len * S), Math.ceil(st.depth * S));
    const ctx = c.getContext('2d');
    ctx.scale(S, S);
    const rng = mulberry32(seed);
    // estrutura
    ctx.fillStyle = '#2A2F40';
    ctx.fillRect(0, 0, st.len, st.depth);
    // degraus: 5 fileiras
    const rows = 5;
    for (let r = 0; r < rows; r++) {
      const y = 6 + r * ((st.depth - 16) / rows);
      ctx.fillStyle = r % 2 ? '#3A4157' : '#343B50';
      ctx.fillRect(4, y, st.len - 8, (st.depth - 16) / rows - 2);
      // público
      const cols = ['#FF6A1F', '#2F6BFF', '#FFC23A', '#E9EDF5', '#22C98A', '#C42A4A', '#F4B9A0', '#8B5CFF', '#38E1FF'];
      for (let x = 8; x < st.len - 8; x += 5.2) {
        if (rng() < 0.12) continue;
        ctx.fillStyle = cols[Math.floor(rng() * cols.length)];
        ctx.beginPath();
        ctx.arc(x + (rng() - 0.5) * 1.5, y + 3 + (rng() - 0.5) * 1.5, 1.7, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    // cobertura listrada
    ctx.fillStyle = 'rgba(255,255,255,0.08)';
    ctx.fillRect(0, st.depth - 8, st.len, 8);
    for (let x = 0; x < st.len; x += 24) {
      ctx.fillStyle = (x / 24) % 2 ? '#FF6A1F' : '#F1F3F8';
      ctx.fillRect(x, st.depth - 8, 24, 8);
    }
    ctx.fillStyle = '#F1F3F8';
    ctx.font = '700 11px "Big Shoulders Display", "Arial Narrow", sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('ÁPICE', st.len / 2, 4.5);
    return c;
  }

  /* ---------- Renderer ---------- */
  class Renderer {
    constructor(canvas) {
      this.cv = canvas;
      this.ctx = canvas.getContext('2d', { alpha: false });
      this.dpr = 1;
      this.w = 1;
      this.h = 1;
      this.quality = 'high';
      this.light = makeCanvas(2, 2);
      this.lctx = this.light.getContext('2d');
      this.flakes = [];
      this.frame = 0;
      this.stamps = {
        soft: softStamp(128, '#ffffff', 0.25),
        amber: softStamp(128, '#FFB347', 0.2),
        red: softStamp(64, '#FF2D47', 0.3),
        flame: softStamp(64, '#FF8A2A', 0.3),
        blue: softStamp(64, '#5CC8FF', 0.3),
        cyan: softStamp(128, '#38E1FF', 0.2),
        cone: coneStamp(300, 0.38, '#ffffff'),
        coneWarm: coneStamp(300, 0.38, '#FFE2A8'),
      };
      this.resize();
    }

    setQuality(q) {
      this.quality = q;
      this.resize();
    }

    resize() {
      const r = this.cv.getBoundingClientRect();
      const max = this.quality === 'low' ? 1 : this.quality === 'mid' ? 1.5 : 2;
      this.dpr = Math.min(window.devicePixelRatio || 1, max);
      this.w = Math.max(1, r.width);
      this.h = Math.max(1, r.height);
      const W = Math.round(this.w * this.dpr), H = Math.round(this.h * this.dpr);
      if (this.cv.width !== W || this.cv.height !== H) {
        this.cv.width = W;
        this.cv.height = H;
      }
      const q = this.quality === 'low' ? 0.33 : 0.5;
      this.lq = q;
      const lw = Math.ceil(this.w * q), lh = Math.ceil(this.h * q);
      if (this.light.width !== lw || this.light.height !== lh) {
        this.light.width = lw;
        this.light.height = lh;
      }
      // base de zoom conforme a tela (celular vê mais pista)
      this.baseZoom = clamp(Math.min(this.w, this.h * 1.25) / 900, 0.56, 1.35);
    }

    setTrack(track) {
      if (this.track === track) return;
      this.track = track;
      const th = track.theme;
      const t = track.themeId;
      const ctx = this.ctx;
      const tiles = {};
      const SZ = 512;
      if (t === 'night') {
        tiles.ground = noiseTile(SZ, th.ground, { variance: 6, grid: 'rgba(255,255,255,0.035)', gridSize: 128 }, 1);
        tiles.runoff = noiseTile(SZ, th.runoffCol, { variance: 7, speck: 0.01, speckAmt: 14 }, 2);
        tiles.asphalt = noiseTile(SZ, th.asphalt, { variance: 9, speck: 0.02, speckAmt: 18, cracks: 'rgba(0,0,0,0.18)' }, 3);
      } else if (t === 'desert') {
        tiles.ground = noiseTile(SZ, th.ground, { variance: 7, ripple: 6, tint: [1, 0.85, 0.65] }, 4);
        tiles.runoff = noiseTile(SZ, th.runoffCol, { variance: 9, speck: 0.08, speckAmt: 34, tint: [1, 0.85, 0.7] }, 5);
        tiles.asphalt = noiseTile(SZ, th.asphalt, { variance: 9, speck: 0.02, speckAmt: 20 }, 6);
      } else {
        tiles.ground = noiseTile(SZ, th.ground, { variance: 4, speck: 0.004, speckAmt: 12, tint: [0.9, 0.95, 1] }, 7);
        tiles.runoff = noiseTile(SZ, th.runoffCol, { variance: 5, speck: 0.02, speckAmt: 10, tint: [0.9, 0.95, 1] }, 8);
        tiles.asphalt = noiseTile(SZ, th.asphalt, { variance: 8, speck: 0.025, speckAmt: 22, tint: [0.95, 1, 1.1] }, 9);
      }
      this.pat = {};
      const m = typeof DOMMatrix !== 'undefined' ? new DOMMatrix().scale(0.5) : null;
      for (const k in tiles) {
        const p = ctx.createPattern(tiles[k], 'repeat');
        if (m && p.setTransform) p.setTransform(m);
        this.pat[k] = p;
      }
      this.dustStamp = softStamp(64, th.dust, 0.3);

      // caminhos
      const N = track.N;
      const poly = (fx, fy) => {
        const p = new Path2D();
        p.moveTo(fx(0), fy(0));
        for (let i = 1; i < N; i++) p.lineTo(fx(i), fy(i));
        p.closePath();
        return p;
      };
      const off = (d) => poly((i) => track.xs[i] + track.nx[i] * d, (i) => track.ys[i] + track.ny[i] * d);
      this.pCenter = poly((i) => track.xs[i], (i) => track.ys[i]);
      this.pRacing = poly((i) => track.rx[i], (i) => track.ry[i]);
      this.pEdgeL = off(track.hw - 7);
      this.pEdgeR = off(-(track.hw - 7));
      this.pWallL = off(track.wall + 6);
      this.pWallR = off(-(track.wall + 6));
      // zebras só nas curvas
      const curb = (sign) => {
        const p = new Path2D();
        let on = false;
        const d = (track.hw + 6) * sign;
        for (let i = 0; i <= N; i++) {
          const k = i % N;
          const c = Math.abs(track.curv[k]) > 1 / 650;
          const x = track.xs[k] + track.nx[k] * d, y = track.ys[k] + track.ny[k] * d;
          if (c && !on) { p.moveTo(x, y); on = true; }
          else if (c && on) p.lineTo(x, y);
          else if (!c && on) { p.lineTo(x, y); on = false; }
        }
        return p;
      };
      this.pCurbL = curb(1);
      this.pCurbR = curb(-1);

      // sprites de cenário
      this.decorSprites = new Map();
      let sd = 100;
      for (const d of track.decor) {
        if (d.type === 'pine' || d.type === 'tree') {
          const key = d.type + d.v + Math.round(d.r / 4);
          if (!this.decorSprites.has(key)) {
            this.decorSprites.set(key, d.type === 'pine' ? pineSprite(Math.round(d.r / 4) * 4, d.v, sd++) : treeSprite(Math.round(d.r / 4) * 4, d.v, sd++));
          }
          d.sprite = key;
        }
      }
      this.standSprites = track.stands.map((s, i) => standSprite(s, 500 + i));

      // minimapa
      this.mini = null;

      // neve
      this.flakes = [];
      if (t === 'snow') {
        const rng = mulberry32(77);
        for (let i = 0; i < 160; i++) this.flakes.push({ x: rng(), y: rng(), z: 0.4 + rng() * 0.9, ph: rng() * 6.28 });
      }
    }

    /* ---------- Quadro ---------- */
    draw(race, dt, opts) {
      opts = opts || {};
      const ctx = this.ctx, tr = race.track, th = tr.theme, cam = race.cam;
      this.frame++;
      this.setTrack(tr);
      const dpr = this.dpr, W = this.w, H = this.h;
      const z = cam.zoom * this.baseZoom;
      const sx = cam.shake ? (Math.random() - 0.5) * cam.shake : 0;
      const sy = cam.shake ? (Math.random() - 0.5) * cam.shake : 0;
      const k = dpr * z;
      const ox = dpr * (W / 2 + sx) - cam.x * k;
      const oy = dpr * (H / 2 + sy) - cam.y * k;
      const pad = 140;
      const view = {
        x0: cam.x - W / 2 / z - pad, x1: cam.x + W / 2 / z + pad,
        y0: cam.y - H / 2 / z - pad, y1: cam.y + H / 2 / z + pad,
      };
      this.view = view;
      const inView = (x, y, r) => x + r > view.x0 && x - r < view.x1 && y + r > view.y0 && y - r < view.y1;

      ctx.setTransform(k, 0, 0, k, ox, oy);
      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 1;
      ctx.lineJoin = 'round';
      ctx.lineCap = 'round';

      // chão
      ctx.fillStyle = this.pat.ground;
      ctx.fillRect(view.x0, view.y0, view.x1 - view.x0, view.y1 - view.y0);

      // cenário baixo (dunas, lagos, rochas)
      for (const d of tr.decor) {
        if (d.layer !== 0) continue;
        const r = d.rx || d.r || 40;
        if (!inView(d.x, d.y, r + 20)) continue;
        this.drawDecor(ctx, d, th, race.clock);
      }

      // área de escape
      ctx.strokeStyle = this.pat.runoff;
      ctx.lineWidth = (tr.wall + 4) * 2;
      ctx.stroke(this.pCenter);

      // muros / barreiras
      this.drawBarriers(ctx, tr);

      // zebras
      ctx.lineCap = 'butt';
      ctx.lineWidth = 12;
      ctx.strokeStyle = th.curbA;
      ctx.stroke(this.pCurbL);
      ctx.stroke(this.pCurbR);
      ctx.setLineDash([14, 14]);
      ctx.strokeStyle = th.curbB;
      ctx.stroke(this.pCurbL);
      ctx.stroke(this.pCurbR);
      ctx.setLineDash([]);
      ctx.lineCap = 'round';

      // asfalto
      ctx.strokeStyle = this.pat.asphalt;
      ctx.lineWidth = tr.hw * 2;
      ctx.stroke(this.pCenter);
      // borracha no traçado ideal
      ctx.strokeStyle = 'rgba(0,0,0,0.16)';
      ctx.lineWidth = 34;
      ctx.stroke(this.pRacing);
      ctx.strokeStyle = 'rgba(0,0,0,0.1)';
      ctx.lineWidth = 64;
      ctx.stroke(this.pRacing);
      // faixas de borda
      ctx.strokeStyle = rgba(th.edge.length === 7 ? th.edge : '#ffffff', 0.85);
      ctx.lineWidth = 3;
      ctx.stroke(this.pEdgeL);
      ctx.stroke(this.pEdgeR);
      if (tr.themeId === 'night') {
        ctx.setLineDash([34, 46]);
        ctx.strokeStyle = 'rgba(255,214,120,0.35)';
        ctx.lineWidth = 3;
        ctx.stroke(this.pCenter);
        ctx.setLineDash([]);
      }

      this.drawStartArea(ctx, race);
      this.drawPadsIce(ctx, tr, race.clock);
      this.drawSkids(ctx, race, th);

      // carros
      const focus = race.focusCar();
      for (const car of race.cars) {
        if (!inView(car.x, car.y, 40)) continue;
        this.drawCarAt(ctx, car);
      }
      this.drawParticles(ctx, race, inView, th);

      // cenário alto
      for (const d of tr.decor) {
        if (d.layer !== 1) continue;
        const r = d.r || Math.max(d.w || 0, d.h || 0);
        if (!inView(d.x, d.y, r + 40)) continue;
        this.drawDecor(ctx, d, th, race.clock);
      }
      for (let i = 0; i < tr.stands.length; i++) {
        const s = tr.stands[i];
        if (!inView(s.x, s.y, s.len)) continue;
        ctx.save();
        ctx.translate(s.x, s.y);
        ctx.rotate(s.a + (s.side < 0 ? Math.PI : 0));
        ctx.fillStyle = 'rgba(0,0,0,0.35)';
        ctx.fillRect(-s.len / 2 + 10, -s.depth / 2 + 12, s.len, s.depth);
        ctx.drawImage(this.standSprites[i], -s.len / 2, -s.depth / 2, s.len, s.depth);
        ctx.restore();
      }
      for (const l of tr.lamps) {
        if (!inView(l.x, l.y, 40)) continue;
        this.drawLamp(ctx, l, tr, race.clock);
      }

      // indicador do jogador antes e logo depois da largada
      if (race.player && !race.attract && (race.state === 'countdown' || race.time < 3)) {
        const p = race.player;
        const bob = Math.sin(race.clock * 6) * 3;
        ctx.save();
        ctx.translate(p.x, p.y - 38 + bob);
        ctx.fillStyle = '#FF6A1F';
        ctx.beginPath();
        ctx.moveTo(-9, -8); ctx.lineTo(9, -8); ctx.lineTo(0, 4); ctx.closePath();
        ctx.fill();
        ctx.fillStyle = '#EEF1F7';
        ctx.font = '800 13px "Big Shoulders Display", "Arial Narrow", sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('VOCÊ', 0, -13);
        ctx.restore();
      }

      // iluminação
      if (tr.themeId === 'night') this.drawNight(ctx, race, k, ox, oy, z, sx, sy, inView);
      else this.drawDayGlow(ctx, race, inView);

      // efeitos de tela
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 1;
      if (tr.themeId === 'desert') {
        const g = ctx.createLinearGradient(0, 0, W, H);
        g.addColorStop(0, 'rgba(255,170,90,0.14)');
        g.addColorStop(1, 'rgba(110,40,90,0.16)');
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, W, H);
      } else if (tr.themeId === 'snow') {
        ctx.fillStyle = 'rgba(170,200,255,0.07)';
        ctx.fillRect(0, 0, W, H);
        this.drawSnow(ctx, race, dt, W, H, z);
      }
      if (focus && (focus.nitroOn || focus.boostT > 0.6) && !opts.reducedMotion) this.drawSpeedLines(ctx, W, H, focus);
    }

    drawBarriers(ctx, tr) {
      const t = tr.themeId;
      if (t === 'night') {
        ctx.strokeStyle = 'rgba(0,0,0,0.35)';
        ctx.lineWidth = 18;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.strokeStyle = '#3A4054';
        ctx.lineWidth = 12;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.strokeStyle = '#4D556E';
        ctx.lineWidth = 4;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
      } else if (t === 'desert') {
        ctx.setLineDash([0.01, 19]);
        ctx.strokeStyle = 'rgba(80,40,20,0.35)';
        ctx.lineWidth = 20;
        ctx.save(); ctx.translate(4, 4);
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.restore();
        ctx.strokeStyle = '#141417';
        ctx.lineWidth = 17;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.strokeStyle = '#34343B';
        ctx.lineWidth = 7;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.setLineDash([]);
      } else {
        ctx.strokeStyle = 'rgba(110,140,190,0.28)';
        ctx.lineWidth = 38;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.strokeStyle = '#F7FAFF';
        ctx.lineWidth = 28;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.setLineDash([10, 8]);
        ctx.strokeStyle = '#FF7A2F';
        ctx.lineWidth = 2.5;
        ctx.stroke(this.pWallL); ctx.stroke(this.pWallR);
        ctx.setLineDash([]);
      }
    }

    drawStartArea(ctx, race) {
      const tr = race.track;
      // quadriculado de largada/chegada
      const i = 0;
      ctx.save();
      ctx.translate(tr.xs[i], tr.ys[i]);
      ctx.rotate(tr.ang[i]);
      const sq = 11;
      const n = Math.ceil((tr.hw * 2) / sq);
      for (let r = 0; r < 2; r++) {
        for (let c = 0; c < n; c++) {
          ctx.fillStyle = (r + c) % 2 ? '#111318' : '#F4F6FA';
          const y = -tr.hw + c * sq;
          ctx.fillRect(-sq + r * sq, y, sq, Math.min(sq, tr.hw - y));
        }
      }
      ctx.restore();
      // boxes do grid
      ctx.strokeStyle = 'rgba(255,255,255,0.75)';
      ctx.lineWidth = 2.5;
      ctx.lineCap = 'butt';
      for (const car of race.cars) {
        const gi = car.gridIdx;
        if (gi == null) continue;
        const x = tr.xs[gi] + tr.nx[gi] * car.gridOff, y = tr.ys[gi] + tr.ny[gi] * car.gridOff;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(tr.ang[gi]);
        ctx.beginPath();
        ctx.moveTo(18, -16); ctx.lineTo(30, -16); ctx.lineTo(30, 16); ctx.lineTo(18, 16);
        ctx.stroke();
        ctx.restore();
      }
      ctx.lineCap = 'round';
      // pintura no asfalto
      const pi = Math.round(150 / tr.ds);
      ctx.save();
      ctx.translate(tr.xs[pi], tr.ys[pi]);
      ctx.rotate(tr.ang[pi] + Math.PI / 2);
      ctx.fillStyle = 'rgba(255,255,255,0.12)';
      ctx.font = '900 64px "Big Shoulders Display", "Arial Narrow", sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('ÁPICE', 0, 0);
      ctx.restore();
    }

    drawPadsIce(ctx, tr, time) {
      for (const ic of tr.ice) {
        if (!this.isVisible(ic.x, ic.y, ic.r * 1.6)) continue;
        ctx.save();
        ctx.translate(ic.x, ic.y);
        ctx.rotate(ic.a);
        ctx.fillStyle = 'rgba(205,236,255,0.55)';
        for (const b of ic.blobs) {
          ctx.beginPath();
          ctx.ellipse(b.dx, b.dy, b.r * 1.3, b.r * 0.8, 0, 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.strokeStyle = 'rgba(255,255,255,0.65)';
        ctx.lineWidth = 2;
        for (let s = -1; s <= 1; s++) {
          ctx.beginPath();
          ctx.moveTo(-ic.r * 0.5, s * ic.r * 0.25 - 4);
          ctx.lineTo(ic.r * 0.3, s * ic.r * 0.25 + 4);
          ctx.stroke();
        }
        ctx.restore();
      }
      for (const p of tr.pads) {
        if (!this.isVisible(p.x, p.y, 80)) continue;
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.a);
        ctx.fillStyle = 'rgba(10,20,40,0.55)';
        ctx.fillRect(-p.len / 2, -p.w / 2, p.len, p.w);
        ctx.strokeStyle = '#38E1FF';
        ctx.lineWidth = 2;
        ctx.strokeRect(-p.len / 2, -p.w / 2, p.len, p.w);
        for (let c = 0; c < 4; c++) {
          const ph = (time * 3 - c * 0.25) % 1;
          ctx.globalAlpha = 0.35 + 0.65 * (ph < 0 ? ph + 1 : ph);
          ctx.strokeStyle = '#38E1FF';
          ctx.lineWidth = 5;
          ctx.lineJoin = 'miter';
          const x = -p.len / 2 + 16 + c * 18;
          ctx.beginPath();
          ctx.moveTo(x, -p.w / 2 + 10);
          ctx.lineTo(x + 12, 0);
          ctx.lineTo(x, p.w / 2 - 10);
          ctx.stroke();
        }
        ctx.lineJoin = 'round';
        ctx.globalAlpha = 1;
        ctx.restore();
      }
    }

    isVisible(x, y, r) {
      const v = this.view;
      return x + r > v.x0 && x - r < v.x1 && y + r > v.y0 && y - r < v.y1;
    }

    drawSkids(ctx, race, th) {
      const s = race.skids, n = race.skidCount;
      if (!n) return;
      const col = race.track.themeId === 'snow' ? '30,40,60' : race.track.themeId === 'desert' ? '25,15,10' : '5,5,8';
      ctx.lineWidth = 4.5;
      ctx.lineCap = 'round';
      const buckets = [0.2, 0.32, 0.44, 0.56];
      const v = this.view;
      for (let b = 0; b < buckets.length; b++) {
        ctx.beginPath();
        let any = false;
        for (let i = 0; i < n; i++) {
          const k = i * 5;
          const a = s[k + 4];
          const bi = a < 0.26 ? 0 : a < 0.38 ? 1 : a < 0.5 ? 2 : 3;
          if (bi !== b) continue;
          const x = s[k], y = s[k + 1];
          if (x < v.x0 || x > v.x1 || y < v.y0 || y > v.y1) continue;
          ctx.moveTo(x, y);
          ctx.lineTo(s[k + 2], s[k + 3]);
          any = true;
        }
        if (any) {
          ctx.strokeStyle = 'rgba(' + col + ',' + buckets[b] + ')';
          ctx.stroke();
        }
      }
    }

    drawCarAt(ctx, car) {
      const sp = APX.carSprite(car.spec, car.paint);
      ctx.save();
      ctx.translate(car.x, car.y);
      ctx.rotate(car.a);
      ctx.drawImage(sp.canvas, -sp.w / 2, -sp.h / 2, sp.w, sp.h);
      ctx.restore();
    }

    drawParticles(ctx, race, inView, th) {
      const ps = race.particles;
      const soft = this.stamps.soft;
      const night = race.track.themeId === 'night';
      // fumaça e poeira
      for (const p of ps) {
        if (p.type !== 'smoke' && p.type !== 'dust') continue;
        if (!inView(p.x, p.y, p.size)) continue;
        const t = p.life / p.max;
        ctx.globalAlpha = (p.type === 'smoke' ? (night ? 0.22 : 0.34) : 0.42) * t;
        const img = p.type === 'smoke' ? soft : this.dustStamp;
        ctx.drawImage(img, p.x - p.size, p.y - p.size, p.size * 2, p.size * 2);
      }
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = 'lighter';
      for (const p of ps) {
        if (p.type === 'spark') {
          if (!inView(p.x, p.y, 20)) continue;
          const t = p.life / p.max;
          ctx.strokeStyle = 'rgba(255,' + Math.round(170 + 80 * t) + ',' + Math.round(90 * t) + ',' + t + ')';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(p.x - p.vx * 0.03, p.y - p.vy * 0.03);
          ctx.stroke();
        } else if (p.type === 'flame') {
          if (!inView(p.x, p.y, 20)) continue;
          const t = p.life / p.max;
          const s = p.size * (0.6 + t);
          ctx.globalAlpha = t;
          ctx.drawImage(t > 0.5 ? this.stamps.blue : this.stamps.flame, p.x - s, p.y - s, s * 2, s * 2);
          ctx.globalAlpha = 1;
        }
      }
      ctx.globalCompositeOperation = 'source-over';
    }

    drawDecor(ctx, d, th, time) {
      switch (d.type) {
        case 'bldg': {
          const { x, y, w, h } = d;
          ctx.fillStyle = 'rgba(0,0,0,0.42)';
          ctx.fillRect(x - w / 2 + d.hgt * 0.4, y - h / 2 + d.hgt * 0.55, w, h);
          const roofs = ['#262A3A', '#2C3043', '#23273A', '#2E2A3C'];
          ctx.fillStyle = roofs[d.roof];
          ctx.fillRect(x - w / 2, y - h / 2, w, h);
          ctx.strokeStyle = '#363C52';
          ctx.lineWidth = 5;
          ctx.strokeRect(x - w / 2 + 2.5, y - h / 2 + 2.5, w - 5, h - 5);
          ctx.strokeStyle = 'rgba(255,255,255,0.06)';
          ctx.lineWidth = 1;
          ctx.strokeRect(x - w / 2 + 8, y - h / 2 + 8, w - 16, h - 16);
          for (const a of d.details) {
            ctx.fillStyle = 'rgba(0,0,0,0.3)';
            ctx.fillRect(x + a.x - a.w / 2 + 3, y + a.y - a.h / 2 + 4, a.w, a.h);
            ctx.fillStyle = '#3D4459';
            ctx.fillRect(x + a.x - a.w / 2, y + a.y - a.h / 2, a.w, a.h);
            ctx.fillStyle = '#4A5269';
            ctx.fillRect(x + a.x - a.w / 2 + 2, y + a.y - a.h / 2 + 2, a.w - 4, 3);
          }
          if (d.heli) {
            ctx.strokeStyle = 'rgba(255,214,120,0.6)';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(x, y, Math.min(w, h) * 0.28, 0, Math.PI * 2);
            ctx.stroke();
            ctx.fillStyle = 'rgba(255,214,120,0.6)';
            ctx.font = '900 34px "Big Shoulders Display", "Arial Narrow", sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('H', x, y + 2);
          }
          break;
        }
        case 'tree':
        case 'pine': {
          const sp = this.decorSprites.get(d.sprite);
          if (!sp) break;
          ctx.save();
          ctx.translate(d.x, d.y);
          ctx.rotate(d.rot);
          ctx.drawImage(sp.canvas, -sp.size / 2, -sp.size / 2, sp.size, sp.size);
          ctx.restore();
          break;
        }
        case 'dune': {
          ctx.save();
          ctx.translate(d.x, d.y);
          ctx.rotate(d.rot);
          const g = ctx.createRadialGradient(-d.rx * 0.2, -d.ry * 0.3, 0, 0, 0, d.rx);
          g.addColorStop(0, 'rgba(255,214,160,0.35)');
          g.addColorStop(0.6, 'rgba(210,150,90,0.12)');
          g.addColorStop(1, 'rgba(160,100,60,0)');
          ctx.fillStyle = g;
          ctx.beginPath();
          ctx.ellipse(0, 0, d.rx, d.ry, 0, 0, Math.PI * 2);
          ctx.fill();
          ctx.restore();
          break;
        }
        case 'lake': {
          ctx.save();
          ctx.translate(d.x, d.y);
          ctx.rotate(d.rot);
          ctx.fillStyle = '#C9E4F4';
          ctx.beginPath();
          ctx.ellipse(0, 0, d.rx + 10, d.ry + 10, 0, 0, Math.PI * 2);
          ctx.fill();
          const g = ctx.createLinearGradient(-d.rx, -d.ry, d.rx, d.ry);
          g.addColorStop(0, '#A8D6F0');
          g.addColorStop(1, '#7FB8DD');
          ctx.fillStyle = g;
          ctx.beginPath();
          ctx.ellipse(0, 0, d.rx, d.ry, 0, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = 'rgba(255,255,255,0.55)';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(-d.rx * 0.6, -d.ry * 0.1); ctx.lineTo(-d.rx * 0.1, d.ry * 0.15); ctx.lineTo(d.rx * 0.2, -d.ry * 0.3);
          ctx.moveTo(-d.rx * 0.1, d.ry * 0.15); ctx.lineTo(d.rx * 0.05, d.ry * 0.6);
          ctx.moveTo(d.rx * 0.2, -d.ry * 0.3); ctx.lineTo(d.rx * 0.6, -d.ry * 0.05);
          ctx.stroke();
          ctx.restore();
          break;
        }
        case 'rock':
        case 'srock': {
          ctx.save();
          ctx.translate(d.x, d.y);
          ctx.rotate(d.rot);
          const snow = d.type === 'srock';
          ctx.fillStyle = snow ? 'rgba(60,90,140,0.2)' : 'rgba(90,40,20,0.28)';
          ctx.beginPath();
          d.pts.forEach((p, i) => (i ? ctx.lineTo(p[0] + 7, p[1] + 5) : ctx.moveTo(p[0] + 7, p[1] + 5)));
          ctx.closePath();
          ctx.fill();
          const g = ctx.createLinearGradient(-d.r, -d.r, d.r, d.r);
          g.addColorStop(0, snow ? '#9AA3B5' : '#B07A52');
          g.addColorStop(1, snow ? '#596276' : '#6B4129');
          ctx.fillStyle = g;
          ctx.beginPath();
          d.pts.forEach((p, i) => (i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])));
          ctx.closePath();
          ctx.fill();
          if (snow) {
            ctx.fillStyle = 'rgba(250,252,255,0.92)';
            ctx.beginPath();
            d.pts.forEach((p, i) => (i ? ctx.lineTo(p[0] * 0.6 - 2, p[1] * 0.6 - 2) : ctx.moveTo(p[0] * 0.6 - 2, p[1] * 0.6 - 2)));
            ctx.closePath();
            ctx.fill();
          } else {
            ctx.strokeStyle = 'rgba(255,220,180,0.25)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(d.pts[0][0] * 0.4, d.pts[0][1] * 0.4);
            ctx.lineTo(d.pts[3][0] * 0.5, d.pts[3][1] * 0.5);
            ctx.stroke();
          }
          ctx.restore();
          break;
        }
        case 'bush': {
          ctx.fillStyle = 'rgba(90,40,20,0.22)';
          ctx.beginPath();
          ctx.arc(d.x + 6, d.y + 4, d.r, 0, Math.PI * 2);
          ctx.fill();
          const cols = ['#8A7F45', '#7B6F3A', '#9A8E52'];
          for (let i = 0; i < 4; i++) {
            ctx.fillStyle = cols[(i + d.v) % 3];
            const a = d.rot + i * 1.7;
            ctx.beginPath();
            ctx.arc(d.x + Math.cos(a) * d.r * 0.4, d.y + Math.sin(a) * d.r * 0.4, d.r * 0.6, 0, Math.PI * 2);
            ctx.fill();
          }
          break;
        }
        case 'cactus': {
          ctx.save();
          ctx.translate(d.x, d.y);
          ctx.rotate(d.rot);
          ctx.fillStyle = 'rgba(90,40,20,0.3)';
          ctx.beginPath();
          ctx.ellipse(d.r * 1.4, d.r * 0.7, d.r * 1.6, d.r * 0.6, 0.45, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = '#3F7D4E';
          ctx.beginPath();
          ctx.arc(0, 0, d.r, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = '#4F9660';
          ctx.beginPath();
          ctx.arc(-d.r * 0.9, 0, d.r * 0.5, 0, Math.PI * 2);
          ctx.arc(d.r * 0.9, d.r * 0.2, d.r * 0.45, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = 'rgba(20,50,30,0.55)';
          ctx.lineWidth = 1;
          for (let k = 0; k < 6; k++) {
            const a = (k / 6) * Math.PI * 2;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(Math.cos(a) * d.r, Math.sin(a) * d.r);
            ctx.stroke();
          }
          ctx.restore();
          break;
        }
        default:
          break;
      }
    }

    drawLamp(ctx, l, tr, time) {
      if (tr.themeId === 'night') {
        ctx.save();
        ctx.translate(l.x, l.y);
        ctx.rotate(l.a);
        ctx.strokeStyle = '#596079';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(0, 22);
        ctx.stroke();
        ctx.fillStyle = '#1A1E2A';
        ctx.beginPath();
        ctx.arc(0, 0, 5, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#FFE0A0';
        ctx.fillRect(-4, 20, 8, 6);
        ctx.restore();
      } else {
        // posto de sinalização com bandeira tremulando
        ctx.save();
        ctx.translate(l.x, l.y);
        ctx.fillStyle = 'rgba(0,0,0,0.25)';
        ctx.beginPath();
        ctx.arc(3, 3, 7, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#E9EDF5';
        ctx.beginPath();
        ctx.arc(0, 0, 6, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#FF6A1F';
        ctx.beginPath();
        ctx.arc(0, 0, 3, 0, Math.PI * 2);
        ctx.fill();
        const w = Math.sin(time * 6 + l.x) * 4;
        ctx.fillStyle = tr.themeId === 'snow' ? '#2F6BFF' : '#FFC23A';
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.quadraticCurveTo(12, -6 + w, 24, -2 + w);
        ctx.lineTo(24, 10 + w);
        ctx.quadraticCurveTo(12, 6 + w, 0, 10);
        ctx.closePath();
        ctx.fill();
        ctx.restore();
      }
    }

    drawNight(ctx, race, k, ox, oy, z, sx, sy, inView) {
      const tr = race.track;
      const lc = this.lctx, q = this.lq;
      const L = this.light;
      lc.setTransform(1, 0, 0, 1, 0, 0);
      lc.globalCompositeOperation = 'source-over';
      lc.clearRect(0, 0, L.width, L.height);
      lc.fillStyle = 'rgba(6,8,24,0.6)';
      lc.fillRect(0, 0, L.width, L.height);
      lc.globalCompositeOperation = 'destination-out';
      const lk = q * z;
      lc.setTransform(lk, 0, 0, lk, q * (this.w / 2 + sx) - race.cam.x * lk, q * (this.h / 2 + sy) - race.cam.y * lk);
      const soft = this.stamps.soft;
      lc.globalAlpha = 0.9;
      for (const l of tr.lamps) {
        if (!inView(l.lx, l.ly, 220)) continue;
        const r = 200;
        lc.drawImage(soft, l.lx - r, l.ly - r, r * 2, r * 2);
      }
      for (const p of tr.pads) {
        if (!inView(p.x, p.y, 120)) continue;
        lc.drawImage(soft, p.x - 70, p.y - 70, 140, 140);
      }
      const cone = this.stamps.cone;
      for (const car of race.cars) {
        if (!inView(car.x, car.y, 320)) continue;
        lc.save();
        lc.translate(car.x, car.y);
        lc.rotate(car.a);
        lc.globalAlpha = 0.95;
        lc.drawImage(cone.canvas, 16, -cone.h / 2, cone.w, cone.h);
        lc.globalAlpha = 0.7;
        lc.drawImage(soft, -40, -40, 80, 80);
        lc.restore();
      }
      lc.globalAlpha = 1;
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.drawImage(L, 0, 0, this.cv.width, this.cv.height);

      // brilho aditivo
      ctx.setTransform(k, 0, 0, k, ox, oy);
      ctx.globalCompositeOperation = 'lighter';
      const th = tr.theme;
      ctx.lineJoin = 'round';
      ctx.strokeStyle = rgba(th.neonA, 0.12);
      ctx.lineWidth = 22;
      ctx.stroke(this.pWallL);
      ctx.strokeStyle = rgba(th.neonB, 0.12);
      ctx.stroke(this.pWallR);
      ctx.lineWidth = 3;
      ctx.strokeStyle = rgba(th.neonA, 0.95);
      ctx.stroke(this.pWallL);
      ctx.strokeStyle = rgba(th.neonB, 0.95);
      ctx.stroke(this.pWallR);
      const amber = this.stamps.amber;
      ctx.globalAlpha = 0.22;
      for (const l of tr.lamps) {
        if (!inView(l.lx, l.ly, 160)) continue;
        ctx.drawImage(amber, l.lx - 130, l.ly - 130, 260, 260);
      }
      ctx.globalAlpha = 1;
      // neon dos prédios
      for (const d of tr.decor) {
        if (d.type !== 'bldg' || !d.neon) continue;
        if (!inView(d.x, d.y, d.r + 30)) continue;
        const col = d.neon === 'A' ? th.neonA : th.neonB;
        ctx.strokeStyle = rgba(col, 0.16);
        ctx.lineWidth = 14;
        ctx.strokeRect(d.x - d.w / 2 + 4, d.y - d.h / 2 + 4, d.w - 8, d.h - 8);
        ctx.strokeStyle = rgba(col, 0.85);
        ctx.lineWidth = 2;
        ctx.strokeRect(d.x - d.w / 2 + 4, d.y - d.h / 2 + 4, d.w - 8, d.h - 8);
      }
      const warm = this.stamps.coneWarm;
      for (const car of race.cars) {
        if (!inView(car.x, car.y, 320)) continue;
        ctx.save();
        ctx.translate(car.x, car.y);
        ctx.rotate(car.a);
        ctx.globalAlpha = 0.1;
        ctx.drawImage(warm.canvas, 16, -warm.h / 2, warm.w, warm.h);
        ctx.globalAlpha = 1;
        this.tailLights(ctx, car, 1);
        ctx.restore();
      }
      for (const p of tr.pads) {
        if (!inView(p.x, p.y, 120)) continue;
        ctx.globalAlpha = 0.35;
        ctx.drawImage(this.stamps.cyan, p.x - 80, p.y - 80, 160, 160);
        ctx.globalAlpha = 1;
      }
      ctx.globalCompositeOperation = 'source-over';
    }

    tailLights(ctx, car, strength) {
      const red = this.stamps.red;
      const braking = car.brake > 0.1 && car.vf > 10;
      const s = braking ? 22 : 12;
      ctx.globalAlpha = (braking ? 0.95 : 0.45) * strength;
      ctx.drawImage(red, -24 - s / 2, -7.4 - s / 2, s, s);
      ctx.drawImage(red, -24 - s / 2, 7.4 - s / 2, s, s);
      ctx.globalAlpha = 1;
    }

    drawDayGlow(ctx, race, inView) {
      ctx.globalCompositeOperation = 'lighter';
      for (const car of race.cars) {
        if (!inView(car.x, car.y, 40)) continue;
        if (!(car.brake > 0.1 && car.vf > 10)) continue;
        ctx.save();
        ctx.translate(car.x, car.y);
        ctx.rotate(car.a);
        this.tailLights(ctx, car, 0.6);
        ctx.restore();
      }
      ctx.globalCompositeOperation = 'source-over';
    }

    drawSnow(ctx, race, dt, W, H, z) {
      const cam = race.cam;
      ctx.fillStyle = 'rgba(255,255,255,0.85)';
      const t = race.clock;
      for (const f of this.flakes) {
        const px = ((f.x * W - cam.x * z * f.z * 0.6 + Math.sin(t * 0.8 + f.ph) * 20 + t * 18 * f.z) % W + W) % W;
        const py = ((f.y * H - cam.y * z * f.z * 0.6 + t * 40 * f.z) % H + H) % H;
        const r = 1 + f.z * 1.6;
        ctx.globalAlpha = 0.35 + f.z * 0.4;
        ctx.beginPath();
        ctx.arc(px, py, r, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalAlpha = 1;
    }

    drawSpeedLines(ctx, W, H, car) {
      const n = 22;
      const cx = W / 2, cy = H / 2;
      ctx.strokeStyle = 'rgba(255,255,255,0.16)';
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const a = Math.random() * Math.PI * 2;
        const r0 = Math.max(W, H) * (0.42 + Math.random() * 0.2);
        const r1 = r0 + 60 + Math.random() * 120;
        ctx.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0);
        ctx.lineTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
      }
      ctx.stroke();
    }

    /* ---------- Minimapa ---------- */
    drawMinimap(race, canvas) {
      const tr = race.track;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const r = canvas.getBoundingClientRect();
      const W = Math.round(r.width * dpr), H = Math.round(r.height * dpr);
      if (!W || !H) return;
      if (canvas.width !== W || canvas.height !== H) { canvas.width = W; canvas.height = H; this.mini = null; }
      const ctx = canvas.getContext('2d');
      if (!this.mini || this.mini.track !== tr) {
        const b = tr.bounds;
        const pad = 12 * dpr;
        const s = Math.min((W - pad * 2) / (b.maxX - b.minX), (H - pad * 2) / (b.maxY - b.minY));
        const ox = (W - (b.maxX - b.minX) * s) / 2 - b.minX * s;
        const oy = (H - (b.maxY - b.minY) * s) / 2 - b.minY * s;
        const base = makeCanvas(W, H);
        const bc = base.getContext('2d');
        bc.lineJoin = 'round';
        bc.beginPath();
        for (let i = 0; i < tr.N; i += 2) {
          const x = tr.xs[i] * s + ox, y = tr.ys[i] * s + oy;
          if (i === 0) bc.moveTo(x, y); else bc.lineTo(x, y);
        }
        bc.closePath();
        bc.strokeStyle = 'rgba(238,241,247,0.18)';
        bc.lineWidth = 9 * dpr;
        bc.stroke();
        bc.strokeStyle = 'rgba(238,241,247,0.85)';
        bc.lineWidth = 2.5 * dpr;
        bc.stroke();
        // linha de chegada
        const x0 = tr.xs[0] * s + ox, y0 = tr.ys[0] * s + oy;
        bc.strokeStyle = '#FF6A1F';
        bc.lineWidth = 3 * dpr;
        bc.beginPath();
        bc.moveTo(x0 - tr.nx[0] * 8 * dpr, y0 - tr.ny[0] * 8 * dpr);
        bc.lineTo(x0 + tr.nx[0] * 8 * dpr, y0 + tr.ny[0] * 8 * dpr);
        bc.stroke();
        this.mini = { track: tr, s, ox, oy, base };
      }
      const m = this.mini;
      ctx.clearRect(0, 0, W, H);
      ctx.drawImage(m.base, 0, 0);
      for (const car of race.cars) {
        if (car === race.player) continue;
        ctx.fillStyle = car.paint;
        ctx.beginPath();
        ctx.arc(car.x * m.s + m.ox, car.y * m.s + m.oy, 3.6 * dpr, 0, Math.PI * 2);
        ctx.fill();
      }
      if (race.player) {
        const p = race.player;
        ctx.fillStyle = '#EEF1F7';
        ctx.beginPath();
        ctx.arc(p.x * m.s + m.ox, p.y * m.s + m.oy, 6.5 * dpr, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = p.paint;
        ctx.beginPath();
        ctx.arc(p.x * m.s + m.ox, p.y * m.s + m.oy, 4.2 * dpr, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  /* ---------- Miniatura de pista (cards) ---------- */
  function drawTrackThumb(canvas, track, accent) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const r = canvas.getBoundingClientRect();
    const W = Math.max(1, Math.round(r.width * dpr)), H = Math.max(1, Math.round(r.height * dpr));
    canvas.width = W;
    canvas.height = H;
    const ctx = canvas.getContext('2d');
    const b = track.bounds;
    const pad = 22 * dpr;
    const s = Math.min((W - pad * 2) / (b.maxX - b.minX), (H - pad * 2) / (b.maxY - b.minY));
    const ox = (W - (b.maxX - b.minX) * s) / 2 - b.minX * s;
    const oy = (H - (b.maxY - b.minY) * s) / 2 - b.minY * s;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    for (let i = 0; i < track.N; i += 2) {
      const x = track.xs[i] * s + ox, y = track.ys[i] * s + oy;
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.strokeStyle = 'rgba(238,241,247,0.10)';
    ctx.lineWidth = 16 * dpr;
    ctx.stroke();
    ctx.strokeStyle = 'rgba(238,241,247,0.9)';
    ctx.lineWidth = 3.5 * dpr;
    ctx.stroke();
    // setores coloridos (3)
    const cols = [accent || '#FF6A1F', '#45E0FF', '#FFC23A'];
    for (let sct = 0; sct < 3; sct++) {
      ctx.beginPath();
      const a = Math.floor((sct * track.N) / 3), e = Math.floor(((sct + 1) * track.N) / 3);
      for (let i = a; i <= e; i += 2) {
        const k = i % track.N;
        const x = track.xs[k] * s + ox, y = track.ys[k] * s + oy;
        if (i === a) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.strokeStyle = cols[sct];
      ctx.globalAlpha = 0.9;
      ctx.lineWidth = 3.5 * dpr;
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
    // largada
    const x0 = track.xs[0] * s + ox, y0 = track.ys[0] * s + oy;
    ctx.fillStyle = '#EEF1F7';
    ctx.beginPath();
    ctx.arc(x0, y0, 5 * dpr, 0, Math.PI * 2);
    ctx.fill();
    // seta de sentido
    const i2 = Math.round(track.N * 0.04);
    const ax = track.xs[i2] * s + ox, ay = track.ys[i2] * s + oy;
    ctx.save();
    ctx.translate(ax, ay);
    ctx.rotate(track.ang[i2]);
    ctx.fillStyle = '#EEF1F7';
    ctx.beginPath();
    ctx.moveTo(7 * dpr, 0);
    ctx.lineTo(-4 * dpr, -5 * dpr);
    ctx.lineTo(-4 * dpr, 5 * dpr);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  APX.Renderer = Renderer;
  APX.drawTrackThumb = drawTrackThumb;
  APX.tex = { noiseTile, softStamp, coneStamp, makeCanvas };
})(APX);
