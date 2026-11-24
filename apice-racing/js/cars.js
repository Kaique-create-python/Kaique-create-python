/* Ápice Racing — carros: especificações e desenho vetorial visto de cima */
'use strict';
(function (APX) {
  const { shade, rgba } = APX.util;

  // velocidade em px/s (1 px = 0,1 m → 700 px/s ≈ 252 km/h)
  const CARS = [
    {
      id: 'faisca', name: 'Faísca GT', tag: 'Equilibrado', number: 7,
      blurb: 'Bom em tudo. O carro para aprender onde fica o ponto de frenagem.',
      maxSpeed: 705, accel: 540, grip: 7.6, turn: 2.95, nitro: 1.0, mass: 1.0,
      shape: 'gt', paint: '#FF6A1F', trim: '#14161F',
    },
    {
      id: 'trovao', name: 'Trovão V12', tag: 'Velocidade final', number: 12,
      blurb: 'Reta longa é com ele. Pesado na curva, pede frenagem cedo.',
      maxSpeed: 805, accel: 485, grip: 7.0, turn: 2.78, nitro: 1.15, mass: 1.22,
      shape: 'gran', paint: '#2F6BFF', trim: '#E9EDF5',
    },
    {
      id: 'libelula', name: 'Libélula S', tag: 'Controle', number: 3,
      blurb: 'Leve e colado no chão. Faz curva de alta como se fosse reta.',
      maxSpeed: 660, accel: 575, grip: 9.4, turn: 3.2, nitro: 0.9, mass: 0.84,
      shape: 'proto', paint: '#22C98A', trim: '#0E1A16',
    },
    {
      id: 'javali', name: 'Javali 8', tag: 'Arrancada', number: 88,
      blurb: 'Torque bruto na saída de curva. A traseira escapa fácil.',
      maxSpeed: 728, accel: 640, grip: 6.1, turn: 2.78, nitro: 1.1, mass: 1.3,
      shape: 'muscle', paint: '#FFC23A', trim: '#1A1408',
    },
  ];

  const PAINTS = [
    { id: 'laranja', name: 'Laranja Sinal', hex: '#FF6A1F' },
    { id: 'azul', name: 'Azul Volt', hex: '#2F6BFF' },
    { id: 'verde', name: 'Verde Box', hex: '#22C98A' },
    { id: 'amarelo', name: 'Amarelo Bandeira', hex: '#FFC23A' },
    { id: 'branco', name: 'Branco Gelo', hex: '#E9EDF5' },
    { id: 'vinho', name: 'Vinho', hex: '#C42A4A' },
    { id: 'roxo', name: 'Roxo Recorde', hex: '#8B5CFF' },
    { id: 'grafite', name: 'Grafite', hex: '#3A4154' },
  ];

  // Estatísticas normalizadas 0–100 para a garagem
  function statsOf(spec) {
    const n = (v, a, b) => Math.round(30 + ((v - a) / (b - a)) * 70);
    return {
      velocidade: n(spec.maxSpeed, 650, 810),
      aceleracao: n(spec.accel, 470, 645),
      controle: n(spec.grip * 0.6 + spec.turn * 1.6, 8.0, 10.8),
      nitro: n(spec.nitro, 0.88, 1.16),
    };
  }

  const HL = 23; // meio comprimento
  const HW = 11; // meia largura

  // Contornos (metade superior, do bico à traseira). Espelhados no eixo X.
  const OUTLINES = {
    gt: [
      ['M', 23, 0],
      ['C', 23, -5.5, 21.5, -8.8, 16, -10.2],
      ['L', 6, -10.8],
      ['C', -2, -11.4, -10, -11.4, -16, -10.8],
      ['C', -21.5, -10.2, -23, -7, -23, 0],
    ],
    gran: [
      ['M', 23.5, 0],
      ['C', 23.5, -6.5, 22.5, -9.2, 18, -10.4],
      ['L', 2, -10.9],
      ['C', -6, -11.2, -14, -11.2, -19, -10.6],
      ['C', -22.6, -10, -23, -6.5, -23, 0],
    ],
    proto: [
      ['M', 24, 0],
      ['C', 24, -2.6, 21, -5.2, 15, -6.4],
      ['C', 11, -7.4, 9, -10.8, 5, -11],
      ['L', -12, -11],
      ['C', -18, -11, -22.5, -9.5, -22.5, -6],
      ['L', -22.5, 0],
    ],
    muscle: [
      ['M', 23, 0],
      ['L', 23, -8.6],
      ['C', 23, -10.2, 22, -11, 20, -11.2],
      ['L', -18, -11.4],
      ['C', -21.6, -11.4, -23, -10.6, -23, -8],
      ['L', -23, 0],
    ],
  };

  const CABINS = {
    gt: { front: 7.5, back: -9, wF: 6.8, wB: 8.4, roofF: 3.5, roofB: -5.5 },
    gran: { front: 4, back: -11, wF: 7.2, wB: 8.6, roofF: 0.5, roofB: -8 },
    proto: { front: 9, back: -5, wF: 5.2, wB: 6.6, roofF: 9, roofB: -5 },
    muscle: { front: 5, back: -10, wF: 8, wB: 8.8, roofF: 1.5, roofB: -6.5 },
  };

  function outlinePath(shape) {
    const segs = OUTLINES[shape] || OUTLINES.gt;
    const p = new Path2D();
    // metade superior
    for (const s of segs) {
      if (s[0] === 'M') p.moveTo(s[1], s[2]);
      else if (s[0] === 'L') p.lineTo(s[1], s[2]);
      else p.bezierCurveTo(s[1], s[2], s[3], s[4], s[5], s[6]);
    }
    // metade inferior: percorre de volta, espelhando Y
    let cur = [segs[0][1], segs[0][2]];
    const list = [];
    for (let i = 1; i < segs.length; i++) {
      const s = segs[i];
      list.push({ s, from: cur });
      cur = s[0] === 'L' ? [s[1], s[2]] : [s[5], s[6]];
    }
    for (let i = list.length - 1; i >= 0; i--) {
      const { s, from } = list[i];
      if (s[0] === 'L') p.lineTo(from[0], -from[1]);
      else p.bezierCurveTo(s[3], -s[4], s[1], -s[2], from[0], -from[1]);
    }
    p.closePath();
    return p;
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  // Desenha o carro em coordenadas locais (bico apontando para +X)
  function drawCar(ctx, spec, paint, opts) {
    opts = opts || {};
    const trim = spec.trim || '#14161F';
    const body = outlinePath(spec.shape);
    const cab = CABINS[spec.shape] || CABINS.gt;

    // sombra projetada
    if (opts.shadow !== false) {
      ctx.save();
      ctx.translate(2.2, 3.2);
      ctx.fillStyle = 'rgba(0,0,0,0.42)';
      ctx.filter = typeof ctx.filter === 'string' ? 'blur(2.2px)' : 'none';
      ctx.fill(body);
      ctx.filter = 'none';
      ctx.restore();
    }

    // pneus
    ctx.fillStyle = '#0A0B0F';
    const wheelY = spec.shape === 'proto' ? 10.4 : 10.2;
    for (const wx of [13.5, -13.5]) {
      for (const sy of [-1, 1]) {
        roundRect(ctx, wx - 4.6, sy * wheelY - 2.6, 9.2, 5.2, 1.6);
        ctx.fill();
      }
    }

    // carroceria com degradê lateral (volume)
    const g = ctx.createLinearGradient(0, -HW, 0, HW);
    g.addColorStop(0, shade(paint, -0.45));
    g.addColorStop(0.22, shade(paint, -0.05));
    g.addColorStop(0.5, shade(paint, 0.18));
    g.addColorStop(0.78, shade(paint, -0.05));
    g.addColorStop(1, shade(paint, -0.5));
    ctx.fillStyle = g;
    ctx.fill(body);

    // brilho especular longitudinal
    const g2 = ctx.createLinearGradient(-HL, 0, HL, 0);
    g2.addColorStop(0, 'rgba(255,255,255,0)');
    g2.addColorStop(0.55, 'rgba(255,255,255,0.10)');
    g2.addColorStop(0.75, 'rgba(255,255,255,0.22)');
    g2.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = g2;
    ctx.fill(body);

    ctx.save();
    ctx.clip(body);

    // faixas de pintura
    ctx.fillStyle = rgba(trim.length === 7 ? trim : '#14161F', 0.9);
    if (spec.shape === 'proto') {
      ctx.fillRect(-24, -0.9, 48, 1.8);
    } else {
      ctx.fillRect(-24, -3.4, 48, 1.7);
      ctx.fillRect(-24, 1.7, 48, 1.7);
    }

    // cabine: para-brisa, teto e vidro traseiro
    ctx.beginPath();
    ctx.moveTo(cab.front, -cab.wF);
    ctx.quadraticCurveTo(cab.front + 2.4, 0, cab.front, cab.wF);
    ctx.lineTo(cab.back, cab.wB);
    ctx.quadraticCurveTo(cab.back - 1.6, 0, cab.back, -cab.wB);
    ctx.closePath();
    const gg = ctx.createLinearGradient(cab.back, 0, cab.front + 2, 0);
    gg.addColorStop(0, '#0B0E17');
    gg.addColorStop(0.7, '#1B2333');
    gg.addColorStop(1, '#3B4A66');
    ctx.fillStyle = gg;
    ctx.fill();

    if (spec.shape !== 'proto') {
      // teto na cor do carro
      ctx.beginPath();
      const rw = (cab.wF + cab.wB) / 2 - 1.4;
      roundRect(ctx, cab.roofB, -rw, cab.roofF - cab.roofB, rw * 2, 2.4);
      ctx.fillStyle = shade(paint, 0.06);
      ctx.fill();
      ctx.fillStyle = rgba(trim.length === 7 ? trim : '#14161F', 0.9);
      ctx.fillRect(cab.roofB, -3.4, cab.roofF - cab.roofB, 1.7);
      ctx.fillRect(cab.roofB, 1.7, cab.roofF - cab.roofB, 1.7);
      // reflexo no para-brisa
      ctx.strokeStyle = 'rgba(255,255,255,0.28)';
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(cab.front - 0.6, -cab.wF + 1.6);
      ctx.lineTo(cab.roofF + 1.2, -rw + 1.2);
      ctx.stroke();
    } else {
      // capacete do piloto (protótipo de cockpit aberto)
      ctx.beginPath();
      ctx.arc(1.5, 0, 3.4, 0, Math.PI * 2);
      ctx.fillStyle = '#F4F6FA';
      ctx.fill();
      ctx.fillStyle = shade(paint, -0.2);
      ctx.fillRect(2.2, -3.4, 1.4, 6.8);
    }

    // número no capô
    if (opts.number !== false) {
      const nx = spec.shape === 'gran' ? 12 : spec.shape === 'proto' ? 14 : 13.2;
      ctx.beginPath();
      ctx.arc(nx, 0, 3.6, 0, Math.PI * 2);
      ctx.fillStyle = '#F4F6FA';
      ctx.fill();
      ctx.save();
      ctx.translate(nx, 0);
      ctx.rotate(Math.PI / 2);
      ctx.fillStyle = '#0B0D14';
      ctx.font = '700 4.6px "JetBrains Mono", ui-monospace, monospace';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(String(spec.number), 0, 0.3);
      ctx.restore();
    }
    ctx.restore();

    // aerofólio traseiro
    ctx.fillStyle = shade(trim.length === 7 ? trim : '#14161F', 0.05);
    if (spec.shape !== 'muscle') {
      roundRect(ctx, -23.6, -10.6, 3.4, 21.2, 1);
      ctx.fill();
      ctx.fillStyle = shade(paint, -0.35);
      ctx.fillRect(-24, -11, 4.2, 1.6);
      ctx.fillRect(-24, 9.4, 4.2, 1.6);
    } else {
      ctx.fillRect(-22.6, -9.6, 1.6, 19.2);
    }

    // faróis
    ctx.fillStyle = '#FFF4D2';
    const hx = spec.shape === 'proto' ? 19.6 : spec.shape === 'muscle' ? 22 : 20.6;
    const hy = spec.shape === 'proto' ? 4.6 : 7.2;
    for (const sy of [-1, 1]) {
      ctx.beginPath();
      ctx.ellipse(hx, sy * hy, 1.5, 2.3, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    // lanternas
    ctx.fillStyle = opts.brake ? '#FF5466' : '#B3122A';
    for (const sy of [-1, 1]) {
      roundRect(ctx, -23.1, sy * 7.4 - 2, 1.4, 4, 0.5);
      ctx.fill();
    }

    // retrovisores
    if (spec.shape !== 'proto') {
      ctx.fillStyle = shade(paint, -0.25);
      for (const sy of [-1, 1]) {
        roundRect(ctx, cab.front - 2.4, sy * 11.6 - 0.9, 2.6, 1.8, 0.6);
        ctx.fill();
      }
    }

    // contorno
    ctx.lineWidth = 0.7;
    ctx.strokeStyle = 'rgba(0,0,0,0.55)';
    ctx.stroke(body);
  }

  const spriteCache = new Map();
  const SPRITE_SCALE = 3;

  function carSprite(spec, paint) {
    const key = spec.id + paint;
    if (spriteCache.has(key)) return spriteCache.get(key);
    const S = SPRITE_SCALE;
    const w = (HL * 2 + 14) * S;
    const h = (HW * 2 + 14) * S;
    const cv = document.createElement('canvas');
    cv.width = w;
    cv.height = h;
    const ctx = cv.getContext('2d');
    ctx.translate(w / 2, h / 2);
    ctx.scale(S, S);
    drawCar(ctx, spec, paint);
    const sprite = { canvas: cv, w: w / S, h: h / S };
    spriteCache.set(key, sprite);
    return sprite;
  }

  // Prévia grande para a garagem (bico para cima)
  function drawPreview(canvas, spec, paint) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const r = canvas.getBoundingClientRect();
    const w = Math.max(1, Math.round(r.width * dpr));
    const h = Math.max(1, Math.round(r.height * dpr));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
    }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const s = Math.min(w / ((HW * 2 + 12)), h / ((HL * 2 + 12))) * 0.92;
    ctx.translate(w / 2, h / 2);
    // marcação de box no chão
    ctx.strokeStyle = 'rgba(238,241,247,0.10)';
    ctx.lineWidth = 2 * dpr;
    ctx.setLineDash([6 * dpr, 6 * dpr]);
    ctx.strokeRect(-(HW + 5) * s, -(HL + 5) * s, (HW + 5) * 2 * s, (HL + 5) * 2 * s);
    ctx.setLineDash([]);
    ctx.scale(s, s);
    ctx.rotate(-Math.PI / 2);
    drawCar(ctx, spec, paint);
  }

  APX.CARS = CARS;
  APX.PAINTS = PAINTS;
  APX.carStats = statsOf;
  APX.carSprite = carSprite;
  APX.drawCar = drawCar;
  APX.drawCarPreview = drawPreview;
  APX.CAR_DIM = { HL, HW };
  APX.CAR_SHAPES = { OUTLINES, CABINS };
})(APX);
