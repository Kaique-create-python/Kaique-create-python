/* Ápice Racing — renderizador 3D (Three.js r128)
   A simulação continua plana (x, y em px); aqui ela vira mundo 3D: 1 px = 0,1 m, eixo Y para cima. */
'use strict';
(function (APX) {
  if (typeof THREE === 'undefined') return;
  const { clamp, lerp, damp, mulberry32, wrapAngle, shade } = APX.util;
  const K = 0.1;

  function webglOK() {
    try {
      const c = document.createElement('canvas');
      return !!(window.WebGLRenderingContext && (c.getContext('webgl2') || c.getContext('webgl')));
    } catch (e) {
      return false;
    }
  }

  /* ---------- Texturas ---------- */
  function texFromCanvas(c, opts) {
    opts = opts || {};
    const t = new THREE.CanvasTexture(c);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    if (opts.srgb !== false) t.encoding = THREE.sRGBEncoding;
    t.anisotropy = opts.aniso || 8;
    return t;
  }
  function canvasTex(w, h, draw, opts) {
    const c = APX.tex.makeCanvas(w, h);
    draw(c.getContext('2d'), w, h);
    return texFromCanvas(c, opts);
  }
  function radialTex(inner, outer) {
    return canvasTex(128, 128, (g, w, h) => {
      const gr = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
      gr.addColorStop(0, inner);
      gr.addColorStop(1, outer);
      g.fillStyle = gr;
      g.fillRect(0, 0, w, h);
    }, { srgb: false });
  }

  /* ---------- Geometria: varredura ao longo da pista ---------- */
  // profile: lista de [lateral_px (número ou função(i)), altura_m]
  function sweep(tr, profile, opts) {
    opts = opts || {};
    const N = tr.N, rows = N + 1, P = profile.length;
    const pos = new Float32Array(rows * P * 3);
    const uv = new Float32Array(rows * P * 2);
    const uS = opts.uScale || 1, vS = opts.vScale || 1;
    for (let r = 0; r < rows; r++) {
      const i = r % N;
      let acc = 0, px = 0, py = 0, pz = 0;
      for (let p = 0; p < P; p++) {
        const lat = typeof profile[p][0] === 'function' ? profile[p][0](i) : profile[p][0];
        const x = (tr.xs[i] + tr.nx[i] * lat) * K;
        const z = (tr.ys[i] + tr.ny[i] * lat) * K;
        const y = profile[p][1] + (opts.y || 0);
        if (p > 0) acc += Math.hypot(x - px, y - py, z - pz);
        px = x; py = y; pz = z;
        const k = (r * P + p);
        pos[k * 3] = x; pos[k * 3 + 1] = y; pos[k * 3 + 2] = z;
        uv[k * 2] = opts.uLat ? (lat * K) / uS : acc / uS;
        uv[k * 2 + 1] = (r * tr.ds * K) / vS;
      }
    }
    const idx = [];
    for (let r = 0; r < rows - 1; r++) {
      if (opts.mask && !opts.mask[r % N]) continue;
      for (let p = 0; p < P - 1; p++) {
        const a = r * P + p, b = r * P + p + 1, c = (r + 1) * P + p, d = (r + 1) * P + p + 1;
        idx.push(a, c, b, b, c, d);
      }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
    g.setIndex(idx);
    g.computeVertexNormals();
    return g;
  }

  // caixas alinhadas aos eixos, mescladas numa geometria só
  function boxesGeometry(boxes, uvScale) {
    const pos = [], nor = [], uv = [], idx = [];
    const faces = [
      [[1, 0, 0], [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]]],
      [[-1, 0, 0], [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]]],
      [[0, 0, 1], [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]]],
      [[0, 0, -1], [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]]],
      [[0, 1, 0], [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]]],
    ];
    for (const b of boxes) {
      const hx = b.sx / 2, hy = b.sy / 2, hz = b.sz / 2;
      for (let f = 0; f < faces.length; f++) {
        if (f === 4 && b.noTop) continue;
        const [n, vs] = faces[f];
        const base = pos.length / 3;
        const horiz = f < 2 ? b.sz : b.sx;
        vs.forEach((v, k) => {
          pos.push(b.x + v[0] * hx, b.y + v[1] * hy, b.z + v[2] * hz);
          nor.push(n[0], n[1], n[2]);
          if (f === 4) uv.push((v[0] + 1) / 2, (v[2] + 1) / 2);
          else uv.push(((k === 1 || k === 2 ? 1 : 0) * horiz + (b.uo || 0)) / (uvScale ? uvScale[0] : 1), ((v[1] + 1) / 2 * b.sy + (b.vo || 0)) / (uvScale ? uvScale[1] : 1));
        });
        idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
      }
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    g.setIndex(idx);
    return g;
  }

  function mergeGeoms(list) {
    // list: [{geo, matrix}] — só posição/normal/uv indexadas
    let pos = [], nor = [], uv = [], idx = [], off = 0;
    for (const { geo, matrix } of list) {
      const gg = geo.clone();
      if (matrix) gg.applyMatrix4(matrix);
      const p = gg.attributes.position.array, n = gg.attributes.normal.array;
      const u = gg.attributes.uv ? gg.attributes.uv.array : new Float32Array((p.length / 3) * 2);
      pos.push(...p); nor.push(...n); uv.push(...u);
      if (gg.index) for (const v of gg.index.array) idx.push(v + off);
      else for (let v = 0; v < p.length / 3; v++) idx.push(v + off);
      off += p.length / 3;
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    g.setIndex(idx);
    return g;
  }

  /* ---------- Carro 3D ---------- */
  const carGeoCache = new Map();
  function carShape(spec, scale) {
    const segs = APX.CAR_SHAPES.OUTLINES[spec.shape];
    const s = K * scale;
    const sh = new THREE.Shape();
    sh.moveTo(segs[0][1] * s, segs[0][2] * s);
    let cur = [segs[0][1], segs[0][2]];
    const list = [];
    for (let i = 1; i < segs.length; i++) {
      const g = segs[i];
      if (g[0] === 'L') sh.lineTo(g[1] * s, g[2] * s);
      else sh.bezierCurveTo(g[1] * s, g[2] * s, g[3] * s, g[4] * s, g[5] * s, g[6] * s);
      list.push({ g, from: cur });
      cur = g[0] === 'L' ? [g[1], g[2]] : [g[5], g[6]];
    }
    for (let i = list.length - 1; i >= 0; i--) {
      const { g, from } = list[i];
      if (g[0] === 'L') sh.lineTo(from[0] * s, -from[1] * s);
      else sh.bezierCurveTo(g[3] * s, -g[4] * s, g[1] * s, -g[2] * s, from[0] * s, -from[1] * s);
    }
    return sh;
  }

  function carGeometries(spec) {
    if (carGeoCache.has(spec.id)) return carGeoCache.get(spec.id);
    const body = new THREE.ExtrudeGeometry(carShape(spec, 0.93), {
      depth: 0.34, bevelEnabled: true, bevelThickness: 0.14, bevelSize: 0.12, bevelSegments: 3, curveSegments: 12,
    });
    body.rotateX(-Math.PI / 2);
    body.translate(0, 0.3, 0); // 0,16 → 0,78 m
    const C = APX.CAR_SHAPES.CABINS[spec.shape];
    let cabin = null, roof = null;
    if (spec.shape !== 'proto') {
      const s = K * 0.9;
      const cs = new THREE.Shape();
      cs.moveTo(C.front * s, -C.wF * s);
      cs.quadraticCurveTo((C.front + 2.4) * s, 0, C.front * s, C.wF * s);
      cs.lineTo(C.back * s, C.wB * s);
      cs.quadraticCurveTo((C.back - 1.6) * s, 0, C.back * s, -C.wB * s);
      cs.closePath();
      cabin = new THREE.ExtrudeGeometry(cs, { depth: 0.2, bevelEnabled: true, bevelThickness: 0.14, bevelSize: 0.1, bevelSegments: 3, curveSegments: 8 });
      cabin.rotateX(-Math.PI / 2);
      cabin.translate(0, 0.86, 0);
      const rw = ((C.wF + C.wB) / 2 - 1.6) * K;
      const rs = new THREE.Shape();
      const r0 = (C.roofB + 0.6) * K, r1 = (C.roofF - 0.4) * K;
      rs.moveTo(r0, -rw); rs.lineTo(r1, -rw); rs.lineTo(r1, rw); rs.lineTo(r0, rw); rs.closePath();
      roof = new THREE.ExtrudeGeometry(rs, { depth: 0.04, bevelEnabled: true, bevelThickness: 0.03, bevelSize: 0.05, bevelSegments: 2 });
      roof.rotateX(-Math.PI / 2);
      roof.translate(0, 1.2, 0);
    }
    const geos = { body, cabin, roof };
    carGeoCache.set(spec.id, geos);
    return geos;
  }

  const shared = {};
  function sharedGeo() {
    if (shared.tire) return shared;
    shared.tire = new THREE.CylinderGeometry(0.34, 0.34, 0.3, 20);
    shared.tire.rotateX(Math.PI / 2);
    shared.rim = new THREE.CylinderGeometry(0.21, 0.21, 0.32, 12);
    shared.rim.rotateX(Math.PI / 2);
    shared.tireMat = new THREE.MeshStandardMaterial({ color: 0x111216, roughness: 0.9 });
    shared.rimMat = new THREE.MeshStandardMaterial({ color: 0x8a90a0, metalness: 0.8, roughness: 0.3 });
    shared.glass = new THREE.MeshStandardMaterial({ color: 0x0b1020, metalness: 0.7, roughness: 0.12 });
    shared.dark = new THREE.MeshStandardMaterial({ color: 0x15171f, roughness: 0.6 });
    shared.head = new THREE.MeshStandardMaterial({ color: 0xfff4d2, emissive: 0xfff1c8, emissiveIntensity: 1.4 });
    shared.white = new THREE.MeshStandardMaterial({ color: 0xf4f6fa, roughness: 0.5 });
    shared.blob = radialTex('rgba(0,0,0,0.75)', 'rgba(0,0,0,0)');
    shared.blobMat = new THREE.MeshBasicMaterial({ map: shared.blob, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4 });
    shared.blobGeo = new THREE.PlaneGeometry(6.2, 3.4);
    shared.blobGeo.rotateX(-Math.PI / 2);
    shared.beamTex = texFromCanvas(APX.tex.coneStamp(256, 0.42, '#FFE9B8').canvas, { srgb: false });
    shared.beamGeo = new THREE.PlaneGeometry(22, 13);
    shared.beamGeo.rotateX(-Math.PI / 2);
    shared.beamGeo.translate(11 + 1.8, 0.07, 0);
    return shared;
  }

  function numberTex(n) {
    return canvasTex(128, 128, (g) => {
      g.fillStyle = '#F4F6FA';
      g.beginPath(); g.arc(64, 64, 62, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#0B0D14';
      g.font = '700 64px "JetBrains Mono", ui-monospace, monospace';
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(String(n), 64, 68);
    });
  }

  function buildCar(spec, paint, night, envI) {
    const sh = sharedGeo();
    const geos = carGeometries(spec);
    const car = new THREE.Group();
    const paintMat = new THREE.MeshStandardMaterial({ color: new THREE.Color(paint).convertSRGBToLinear(), metalness: 0.25, roughness: 0.32, envMapIntensity: envI });
    const trimMat = new THREE.MeshStandardMaterial({ color: new THREE.Color(spec.trim).convertSRGBToLinear(), roughness: 0.4, metalness: 0.2 });
    const tailMat = new THREE.MeshStandardMaterial({ color: 0x8a0c1c, emissive: 0xff2238, emissiveIntensity: 0.8 });

    const blob = new THREE.Mesh(sh.blobGeo, sh.blobMat);
    blob.position.y = 0.03;
    car.add(blob);

    const body = new THREE.Mesh(geos.body, paintMat);
    body.castShadow = true;
    car.add(body);
    if (geos.cabin) {
      const cab = new THREE.Mesh(geos.cabin, sh.glass);
      cab.castShadow = true;
      car.add(cab);
      const roof = new THREE.Mesh(geos.roof, paintMat);
      car.add(roof);
    } else {
      const helmet = new THREE.Mesh(new THREE.SphereGeometry(0.22, 16, 12), sh.white);
      helmet.position.set(0.15, 0.92, 0);
      car.add(helmet);
      const visor = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.12, 0.42), sh.glass);
      visor.position.set(0.4, 1.02, 0);
      car.add(visor);
    }
    // faixas
    const stripeZ = spec.shape === 'proto' ? [0] : [-0.255, 0.255];
    for (const z of stripeZ) {
      const st = new THREE.Mesh(new THREE.BoxGeometry(3.7, 0.02, spec.shape === 'proto' ? 0.18 : 0.16), trimMat);
      st.position.set(-0.1, 0.795, z);
      car.add(st);
      if (geos.roof) {
        const C = APX.CAR_SHAPES.CABINS[spec.shape];
        const rl = (C.roofF - C.roofB - 1) * K;
        const sr = new THREE.Mesh(new THREE.BoxGeometry(rl, 0.02, 0.16), trimMat);
        sr.position.set(((C.roofF + C.roofB) / 2 + 0.1) * K, 1.285, z);
        car.add(sr);
      }
    }
    // número
    const nx = spec.shape === 'gran' ? 1.15 : spec.shape === 'proto' ? 1.35 : 1.28;
    const disc = new THREE.Mesh(new THREE.CircleGeometry(0.34, 24), new THREE.MeshStandardMaterial({ map: numberTex(spec.number), roughness: 0.5 }));
    disc.rotation.set(-Math.PI / 2, 0, -Math.PI / 2);
    disc.position.set(nx, 0.8, 0);
    car.add(disc);
    // aerofólio
    if (spec.shape !== 'muscle') {
      const wing = new THREE.Mesh(new THREE.BoxGeometry(0.36, 0.05, 2.1), trimMat);
      wing.position.set(-2.12, 1.08, 0);
      wing.castShadow = true;
      car.add(wing);
      for (const z of [-1.04, 1.04]) {
        const ep = new THREE.Mesh(new THREE.BoxGeometry(0.46, 0.34, 0.05), paintMat);
        ep.position.set(-2.12, 0.96, z);
        car.add(ep);
        const strut = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.3, 0.05), sh.dark);
        strut.position.set(-2.05, 0.9, z * 0.55);
        car.add(strut);
      }
    } else {
      const lip = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.1, 1.9), trimMat);
      lip.position.set(-2.08, 0.82, 0);
      car.add(lip);
    }
    // faróis e lanternas
    const hx = spec.shape === 'proto' ? 1.86 : spec.shape === 'muscle' ? 2.12 : 1.96;
    const hz = spec.shape === 'proto' ? 0.46 : 0.7;
    for (const z of [-hz, hz]) {
      const hl = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.1, 0.36), sh.head);
      hl.position.set(hx, 0.6, z);
      car.add(hl);
      const tl = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.1, 0.4), tailMat);
      tl.position.set(-2.18, 0.62, z * 1.03);
      car.add(tl);
    }
    // rodas
    const wheels = [];
    const wz = spec.shape === 'proto' ? 1.0 : 0.98;
    for (const wx of [1.32, -1.32]) {
      for (const z of [-wz, wz]) {
        const w = new THREE.Group();
        const tire = new THREE.Mesh(sh.tire, sh.tireMat);
        tire.castShadow = true;
        const rim = new THREE.Mesh(sh.rim, sh.rimMat);
        w.add(tire, rim);
        w.position.set(wx, 0.34, z);
        car.add(w);
        wheels.push({ g: w, front: wx > 0, spin: tire, rim });
      }
    }
    // feixe dos faróis no chão (noite)
    let beam = null;
    if (night) {
      beam = new THREE.Mesh(sh.beamGeo, new THREE.MeshBasicMaterial({ map: sh.beamTex, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -6 }));
      car.add(beam);
    }
    car.rotation.order = 'YXZ';
    car.userData = { wheels, tailMat, paintMat, beam, roll: 0 };
    return car;
  }

  /* ---------- Partículas (pontos com sprite) ---------- */
  function particleSystem(max, additive, tex) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(max * 3), 3));
    g.setAttribute('size', new THREE.BufferAttribute(new Float32Array(max), 1));
    g.setAttribute('alpha', new THREE.BufferAttribute(new Float32Array(max), 1));
    g.setAttribute('pcolor', new THREE.BufferAttribute(new Float32Array(max * 3), 3));
    g.setDrawRange(0, 0);
    const m = new THREE.ShaderMaterial({
      uniforms: { map: { value: tex }, scale: { value: 600 } },
      vertexShader: `attribute float size; attribute float alpha; attribute vec3 pcolor; varying float vA; varying vec3 vC; uniform float scale;
        void main(){ vA = alpha; vC = pcolor; vec4 mv = modelViewMatrix * vec4(position, 1.0); gl_PointSize = size * scale / max(0.5, -mv.z); gl_Position = projectionMatrix * mv; }`,
      fragmentShader: `uniform sampler2D map; varying float vA; varying vec3 vC;
        void main(){ vec4 t = texture2D(map, gl_PointCoord); gl_FragColor = vec4(vC, vA * t.a); if (gl_FragColor.a < 0.004) discard; }`,
      transparent: true, depthWrite: false,
      blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
    });
    const pts = new THREE.Points(g, m);
    pts.frustumCulled = false;
    return pts;
  }

  /* ---------- Renderer 3D ---------- */
  class Renderer3D {
    constructor(canvas) {
      this.cv = canvas;
      this.quality = 'high';
      this.gl = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
      this.gl.outputEncoding = THREE.sRGBEncoding;
      this.gl.toneMapping = THREE.ACESFilmicToneMapping;
      this.gl.toneMappingExposure = 1.05;
      this.gl.shadowMap.enabled = true;
      this.gl.shadowMap.type = THREE.PCFSoftShadowMap;
      this.camera = new THREE.PerspectiveCamera(62, 1, 0.4, 2600);
      this.camMode = 'chase';
      this.yaw = 0;
      this.camPos = new THREE.Vector3();
      this.track = null;
      this.race = null;
      this.time = 0;
      this.pmrem = new THREE.PMREMGenerator(this.gl);
      this.resize();
    }

    setQuality(q) {
      this.quality = q;
      this.gl.shadowMap.enabled = q !== 'low';
      if (this.sun) this.sun.castShadow = q !== 'low';
      this.resize();
    }

    resize() {
      const r = this.cv.getBoundingClientRect();
      const w = Math.max(1, r.width), h = Math.max(1, r.height);
      const max = this.quality === 'low' ? 1 : this.quality === 'mid' ? 1.3 : 2;
      this.gl.setPixelRatio(Math.min(window.devicePixelRatio || 1, max));
      this.gl.setSize(w, h, false);
      this.camera.aspect = w / h;
      this.camera.updateProjectionMatrix();
      this.w = w; this.h = h;
    }

    dispose() {
      if (!this.scene) return;
      this.scene.traverse((o) => {
        if (o.geometry) o.geometry.dispose();
        if (o.material) {
          const ms = Array.isArray(o.material) ? o.material : [o.material];
          for (const m of ms) {
            for (const key of ['map', 'emissiveMap']) if (m[key]) m[key].dispose();
            m.dispose();
          }
        }
      });
      if (this.envRT) this.envRT.dispose();
    }

    /* ---------- Cena da pista ---------- */
    setTrack(tr) {
      if (this.track === tr) return;
      this.dispose();
      this.track = tr;
      this.race = null;
      const th = tr.theme, id = tr.themeId;
      const night = id === 'night';
      this.night = night;
      const scene = (this.scene = new THREE.Scene());
      const rng = mulberry32(tr.def.seed + 99);

      // céu
      const skyCols = night ? ['#04050C', '#0B0E22', '#1D1A3E', '#2B1C40'] : id === 'desert' ? ['#262457', '#7A3E78', '#E0697A', '#FFB46B'] : ['#8FA6C4', '#B7C6DA', '#DCE4EE', '#EEF2F7'];
      const skyTex = canvasTex(8, 512, (g, w, h) => {
        const gr = g.createLinearGradient(0, 0, 0, h);
        gr.addColorStop(0, skyCols[0]); gr.addColorStop(0.35, skyCols[1]); gr.addColorStop(0.47, skyCols[2]); gr.addColorStop(0.5, skyCols[3]); gr.addColorStop(1, skyCols[3]);
        g.fillStyle = gr; g.fillRect(0, 0, w, h);
      });
      const sky = new THREE.Mesh(new THREE.SphereGeometry(2000, 32, 16), new THREE.MeshBasicMaterial({ map: skyTex, side: THREE.BackSide, fog: false, depthWrite: false }));
      sky.renderOrder = -10;
      scene.add(sky);
      this.sky = sky;
      if (night) {
        const n = 900, sp = new Float32Array(n * 3);
        for (let i = 0; i < n; i++) {
          const a = rng() * Math.PI * 2, e = 0.08 + rng() * 1.3;
          sp[i * 3] = Math.cos(a) * Math.cos(e) * 1800; sp[i * 3 + 1] = Math.sin(e) * 1800; sp[i * 3 + 2] = Math.sin(a) * Math.cos(e) * 1800;
        }
        const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.BufferAttribute(sp, 3));
        const stars = new THREE.Points(sg, new THREE.PointsMaterial({ color: 0xcfd8ff, size: 2.2, sizeAttenuation: false, fog: false, transparent: true, opacity: 0.8 }));
        sky.add(stars);
      }
      if (id === 'desert') {
        const sun = new THREE.Mesh(new THREE.CircleGeometry(70, 32), new THREE.MeshBasicMaterial({ color: 0xffd08a, fog: false }));
        sun.position.set(-1400, 140, 900);
        sun.lookAt(0, 0, 0);
        sky.add(sun);
        const halo = new THREE.Mesh(new THREE.CircleGeometry(260, 32), new THREE.MeshBasicMaterial({ map: radialTex('rgba(255,190,120,0.7)', 'rgba(255,120,80,0)'), transparent: true, fog: false, depthWrite: false }));
        halo.position.set(-1390, 140, 895);
        halo.lookAt(0, 0, 0);
        sky.add(halo);
      }

      // névoa e luz
      if (night) scene.fog = new THREE.FogExp2(0x0b0d1f, 0.0042);
      else if (id === 'desert') scene.fog = new THREE.Fog(0xd98466, 160, 900);
      else scene.fog = new THREE.Fog(0xdde5ef, 70, 520);
      const hemi = night ? new THREE.HemisphereLight(0x5266a8, 0x0b0c16, 0.7) : id === 'desert' ? new THREE.HemisphereLight(0xffd7b0, 0x6e3f35, 0.75) : new THREE.HemisphereLight(0xe4ecff, 0x7d8aa0, 0.78);
      scene.add(hemi);
      const sun = new THREE.DirectionalLight(night ? 0x8ea4ff : id === 'desert' ? 0xffa868 : 0xffffff, night ? 0.45 : id === 'desert' ? 1.9 : 1.25);
      this.sunOffset = night ? new THREE.Vector3(30, 60, -20) : id === 'desert' ? new THREE.Vector3(-70, 38, 45) : new THREE.Vector3(40, 70, -30);
      sun.castShadow = this.quality !== 'low';
      sun.shadow.mapSize.set(2048, 2048);
      const sc = sun.shadow.camera;
      sc.left = -45; sc.right = 45; sc.top = 45; sc.bottom = -45; sc.near = 1; sc.far = 220;
      sun.shadow.bias = -0.0006;
      sun.shadow.normalBias = 0.02;
      scene.add(sun);
      scene.add(sun.target);
      this.sun = sun;

      // reflexos (ambiente gerado)
      const env = new THREE.Scene();
      env.add(new THREE.Mesh(new THREE.SphereGeometry(10, 24, 12), new THREE.MeshBasicMaterial({ map: skyTex, side: THREE.BackSide })));
      const panel = (color, x, y, z, w, h) => {
        const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color, side: THREE.DoubleSide }));
        m.position.set(x, y, z); m.lookAt(0, 0, 0); env.add(m);
      };
      if (night) { panel(0x38e1ff, 6, 2, 4, 6, 0.6); panel(0xff4fa3, -6, 2, -4, 6, 0.6); panel(0xffd08a, 0, 8, 0, 4, 4); }
      else if (id === 'desert') { panel(0xffe0b0, -6, 3, 4, 7, 5); panel(0xffffff, 0, 9, 0, 5, 5); }
      else { panel(0xffffff, 0, 9, 0, 9, 9); panel(0xdfe8ff, 6, 3, -4, 6, 3); }
      this.envRT = this.pmrem.fromScene(env, 0.04);
      scene.environment = this.envRT.texture;

      // texturas do chão
      const tile = (key, base, opts, seed) => {
        const t = texFromCanvas(APX.tex.noiseTile(512, base, opts, seed));
        return t;
      };
      let ground, runoff, asphalt;
      if (night) {
        ground = tile('g', th.ground, { variance: 6, grid: 'rgba(255,255,255,0.05)', gridSize: 128 }, 1);
        runoff = tile('r', th.runoffCol, { variance: 7, speck: 0.01, speckAmt: 14 }, 2);
        asphalt = tile('a', th.asphalt, { variance: 9, speck: 0.02, speckAmt: 18, cracks: 'rgba(0,0,0,0.18)' }, 3);
      } else if (id === 'desert') {
        ground = tile('g', th.ground, { variance: 7, ripple: 6, tint: [1, 0.85, 0.65] }, 4);
        runoff = tile('r', th.runoffCol, { variance: 9, speck: 0.08, speckAmt: 34, tint: [1, 0.85, 0.7] }, 5);
        asphalt = tile('a', th.asphalt, { variance: 9, speck: 0.02, speckAmt: 20 }, 6);
      } else {
        ground = tile('g', th.ground, { variance: 4, speck: 0.004, speckAmt: 12, tint: [0.9, 0.95, 1] }, 7);
        runoff = tile('r', th.runoffCol, { variance: 5, speck: 0.02, speckAmt: 10, tint: [0.9, 0.95, 1] }, 8);
        asphalt = tile('a', th.asphalt, { variance: 8, speck: 0.025, speckAmt: 22, tint: [0.95, 1, 1.1] }, 9);
      }
      const gw = 3400;
      ground.repeat.set(gw / 26, gw / 26);
      const gmesh = new THREE.Mesh(new THREE.PlaneGeometry(gw, gw), new THREE.MeshStandardMaterial({ map: ground, roughness: 0.95 }));
      gmesh.rotation.x = -Math.PI / 2;
      const b = tr.bounds;
      gmesh.position.set(((b.minX + b.maxX) / 2) * K, 0, ((b.minY + b.maxY) / 2) * K);
      gmesh.receiveShadow = true;
      scene.add(gmesh);
      this.center = gmesh.position.clone();

      const flat = (lats, y, map, uS, vS, extra) => {
        const geo = sweep(tr, lats.map((l) => [l, 0]), Object.assign({ y, uScale: uS, vScale: vS, uLat: true }, extra || {}));
        const mat = new THREE.MeshStandardMaterial(Object.assign({ map, roughness: 0.9, side: THREE.DoubleSide, polygonOffset: true, polygonOffsetFactor: -1 - y * 40, polygonOffsetUnits: -1 }, (extra && extra.mat) || {}));
        const m = new THREE.Mesh(geo, mat);
        m.receiveShadow = true;
        scene.add(m);
        return m;
      };
      const W = tr.wall + 6;
      flat([-W - 6, W + 6], 0.01, runoff, 26, 26);
      // zebras nas curvas
      const curbTex = canvasTex(4, 64, (g, w, h) => { g.fillStyle = th.curbA; g.fillRect(0, 0, w, h / 2); g.fillStyle = th.curbB; g.fillRect(0, h / 2, w, h / 2); });
      const mask = new Uint8Array(tr.N);
      for (let i = 0; i < tr.N; i++) mask[i] = Math.abs(tr.curv[i]) > 1 / 650 ? 1 : 0;
      for (const s of [1, -1]) {
        const geo = sweep(tr, [[s * tr.hw - s * 2, 0], [s * (tr.hw + 13), 0.06]], { y: 0.02, uScale: 1, vScale: 2.8, mask });
        const m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ map: curbTex, roughness: 0.6, side: THREE.DoubleSide, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }));
        m.receiveShadow = true;
        scene.add(m);
      }
      flat([-tr.hw, tr.hw], 0.03, asphalt, 12, 12, { mat: { roughness: 0.82, metalness: 0.0, envMapIntensity: 0.5 } });
      // borracha no traçado
      const rub = sweep(tr, [[(i) => tr.rOff[i] - 26, 0], [(i) => tr.rOff[i] + 26, 0]], { y: 0.035, uScale: 1, vScale: 10 });
      const rubTex = canvasTex(64, 4, (g, w) => { const gr = g.createLinearGradient(0, 0, w, 0); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(0.5, 'rgba(0,0,0,0.32)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, 4); }, { srgb: false });
      scene.add(new THREE.Mesh(rub, new THREE.MeshBasicMaterial({ map: rubTex, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -3 })));
      // faixas brancas
      for (const s of [1, -1]) {
        const g = sweep(tr, [[s * (tr.hw - 8.5), 0], [s * (tr.hw - 5.5), 0]], { y: 0.04, uScale: 1, vScale: 10 });
        scene.add(new THREE.Mesh(g, new THREE.MeshStandardMaterial({ color: 0xe8ecf4, roughness: 0.6, side: THREE.DoubleSide, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 })));
      }
      if (night) {
        const dash = canvasTex(4, 64, (g, w, h) => { g.clearRect(0, 0, w, h); g.fillStyle = 'rgba(255,214,120,0.75)'; g.fillRect(0, 0, w, h * 0.42); }, { srgb: false });
        const g = sweep(tr, [[-1.6, 0], [1.6, 0]], { y: 0.04, uScale: 1, vScale: 8 });
        scene.add(new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: dash, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 })));
      }

      this.buildBarriers(scene, tr, rng);
      this.buildStart(scene, tr);
      this.buildFeatures(scene, tr);
      this.buildDecor(scene, tr, rng);
      this.buildHorizon(scene, tr, rng);

      // marcas de pneu (instâncias reaproveitadas como anel)
      const skidGeo = new THREE.PlaneGeometry(1, 1);
      skidGeo.rotateX(-Math.PI / 2);
      const skidMat = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, blending: THREE.MultiplyBlending, premultipliedAlpha: false, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -5, polygonOffsetUnits: -5 });
      const skids = new THREE.InstancedMesh(skidGeo, skidMat, 2600);
      skids.count = 0;
      skids.frustumCulled = false;
      skids.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      scene.add(skids);
      this.skids = skids;
      this.skidSeen = 0;
      this.skidColor = id === 'snow' ? [0.55, 0.6, 0.72] : id === 'desert' ? [0.5, 0.42, 0.38] : [0.35, 0.35, 0.38];

      // partículas
      const soft = texFromCanvas(APX.tex.softStamp(64, '#ffffff', 0.25), { srgb: false });
      this.pSoft = particleSystem(1200, false, soft);
      this.pGlow = particleSystem(1200, true, soft);
      scene.add(this.pSoft, this.pGlow);
      this.dustCol = new THREE.Color(th.dust);

      // neve caindo
      this.snow = null;
      if (id === 'snow') {
        const n = 1800, p = new Float32Array(n * 3);
        for (let i = 0; i < n; i++) { p[i * 3] = (rng() - 0.5) * 120; p[i * 3 + 1] = rng() * 40; p[i * 3 + 2] = (rng() - 0.5) * 120; }
        const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(p, 3));
        this.snow = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: 0.16, transparent: true, opacity: 0.9, depthWrite: false }));
        this.snow.frustumCulled = false;
        scene.add(this.snow);
      }

      // farol do jogador (só à noite)
      this.spot = null;
      if (night) {
        const spot = new THREE.SpotLight(0xfff0d0, 3.2, 70, 0.55, 0.6, 1.3);
        scene.add(spot, spot.target);
        this.spot = spot;
      }
    }

    buildBarriers(scene, tr, rng) {
      const id = tr.themeId, th = tr.theme;
      const W = tr.wall + 6;
      if (id === 'night') {
        const concrete = new THREE.MeshStandardMaterial({ color: 0x3a4054, roughness: 0.85, side: THREE.DoubleSide });
        for (const s of [1, -1]) {
          const g = sweep(tr, [[s * W, 0], [s * W, 1.05], [s * (W + 5), 1.15], [s * (W + 10), 1.05], [s * (W + 10), 0]], { uScale: 1, vScale: 4 });
          const m = new THREE.Mesh(g, concrete);
          m.castShadow = true; m.receiveShadow = true;
          scene.add(m);
          const col = new THREE.Color(s > 0 ? th.neonA : th.neonB);
          const strip = sweep(tr, [[s * (W - 0.3), 0.72], [s * (W - 0.3), 0.86]], { uScale: 1, vScale: 4 });
          scene.add(new THREE.Mesh(strip, new THREE.MeshBasicMaterial({ color: col, side: THREE.DoubleSide, toneMapped: false })));
          const glowTex = canvasTex(4, 64, (gg, w, h) => { const gr = gg.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.5, 'rgba(255,255,255,1)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); gg.fillStyle = gr; gg.fillRect(0, 0, w, h); }, { srgb: false });
          glowTex.wrapT = THREE.ClampToEdgeWrapping;
          const glow = sweep(tr, [[s * (W - 0.6), 0.1], [s * (W - 0.6), 1.5]], { uScale: 1, vScale: 1 });
          // uv.v ao longo da pista; queremos degradê na altura: troca u/v
          const uv = glow.attributes.uv;
          for (let k = 0; k < uv.count; k++) { const v = k % 2; uv.setXY(k, uv.getY(k), v); }
          glowTex.wrapS = THREE.RepeatWrapping;
          scene.add(new THREE.Mesh(glow, new THREE.MeshBasicMaterial({ map: glowTex, color: col, transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false })));
          // luz no chão refletida pelo neon
          const fl = sweep(tr, [[s * (W - 40), 0], [s * (W - 1), 0]], { y: 0.05, uScale: 1, vScale: 1 });
          const uv2 = fl.attributes.uv;
          for (let k = 0; k < uv2.count; k++) { const v = k % 2; uv2.setXY(k, uv2.getY(k), v * 0.5); }
          scene.add(new THREE.Mesh(fl, new THREE.MeshBasicMaterial({ map: glowTex, color: col, transparent: true, opacity: 0.22, blending: THREE.AdditiveBlending, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -6, toneMapped: false })));
        }
      } else if (id === 'desert') {
        const g = new THREE.CylinderGeometry(0.42, 0.42, 0.82, 8);
        g.translate(0, 0.41, 0);
        const mat = new THREE.MeshStandardMaterial({ color: 0x17171b, roughness: 0.85 });
        const step = Math.max(1, Math.round(9.4 / tr.ds));
        const count = Math.ceil(tr.N / step) * 2 * 2;
        const inst = new THREE.InstancedMesh(g, mat, count);
        const m4 = new THREE.Matrix4();
        let k = 0;
        for (const s of [1, -1]) {
          for (let i = 0; i < tr.N; i += step) {
            for (let row = 0; row < 2; row++) {
              const lat = s * (W + 2 + row * 8.6);
              const x = (tr.xs[i] + tr.nx[i] * lat) * K, z = (tr.ys[i] + tr.ny[i] * lat) * K;
              m4.makeTranslation(x, row * 0.0, z);
              const sc = 1 + (rng() - 0.5) * 0.06;
              m4.scale(new THREE.Vector3(sc, row ? 1.6 : 1.0, sc));
              m4.setPosition(x, 0, z);
              inst.setMatrixAt(k++, m4);
            }
          }
        }
        inst.count = k;
        inst.castShadow = false;
        inst.receiveShadow = true;
        scene.add(inst);
        // faixa vermelha/branca nos pneus da frente
        const band = new THREE.MeshStandardMaterial({ color: 0xd3332f, roughness: 0.7, side: THREE.DoubleSide });
        for (const s of [1, -1]) {
          const bg = sweep(tr, [[s * (W - 2.4), 0.5], [s * (W - 2.4), 0.78]], { uScale: 1, vScale: 4 });
          scene.add(new THREE.Mesh(bg, band));
        }
      } else {
        const snowMat = new THREE.MeshStandardMaterial({ color: 0xf6f9ff, roughness: 1, side: THREE.DoubleSide });
        const fenceTex = canvasTex(64, 64, (g, w, h) => {
          g.clearRect(0, 0, w, h);
          g.strokeStyle = '#FF7A2F'; g.lineWidth = 4;
          for (let x = -h; x < w; x += 16) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x + h, h); g.stroke(); g.beginPath(); g.moveTo(x + h, 0); g.lineTo(x, h); g.stroke(); }
          g.fillStyle = '#FF7A2F'; g.fillRect(0, 0, w, 5);
        });
        for (const s of [1, -1]) {
          const g = sweep(tr, [[s * (W - 10), 0], [s * (W - 2), 0.8], [s * (W + 6), 1.25], [s * (W + 16), 0.9], [s * (W + 26), 0]], { uScale: 1, vScale: 4 });
          const m = new THREE.Mesh(g, snowMat);
          m.castShadow = true; m.receiveShadow = true;
          scene.add(m);
          const f = sweep(tr, [[s * (W + 30), 0], [s * (W + 30), 1.3]], { uScale: 1.3, vScale: 1.3 });
          const uv = f.attributes.uv;
          for (let k = 0; k < uv.count; k++) { const v = k % 2; uv.setXY(k, uv.getY(k), v); }
          scene.add(new THREE.Mesh(f, new THREE.MeshBasicMaterial({ map: fenceTex, transparent: true, alphaTest: 0.4, side: THREE.DoubleSide })));
        }
      }
    }

    buildStart(scene, tr) {
      const i = 0;
      const x = tr.xs[i] * K, z = tr.ys[i] * K, a = tr.ang[i];
      const g = new THREE.Group();
      g.position.set(x, 0, z);
      g.rotation.y = -a;
      scene.add(g);
      // quadriculado
      const chk = canvasTex(64, 512, (c, w, h) => {
        const n = 16, sq = h / n;
        for (let r = 0; r < n; r++) for (let q = 0; q < 2; q++) { c.fillStyle = (r + q) % 2 ? '#111318' : '#F4F6FA'; c.fillRect(q * (w / 2), r * sq, w / 2, sq); }
      });
      chk.wrapS = chk.wrapT = THREE.ClampToEdgeWrapping;
      const line = new THREE.Mesh(new THREE.PlaneGeometry(2.2, tr.hw * 2 * K), new THREE.MeshStandardMaterial({ map: chk, roughness: 0.6, polygonOffset: true, polygonOffsetFactor: -5, polygonOffsetUnits: -5 }));
      line.rotation.x = -Math.PI / 2;
      line.position.set(-1.1, 0.05, 0);
      line.receiveShadow = true;
      g.add(line);
      // pórtico de largada
      const span = (tr.hw + 30) * K;
      const steel = new THREE.MeshStandardMaterial({ color: 0x2a2f40, roughness: 0.5, metalness: 0.6 });
      for (const s of [-1, 1]) {
        const p = new THREE.Mesh(new THREE.BoxGeometry(0.6, 8, 0.6), steel);
        p.position.set(0, 4, s * span);
        p.castShadow = true;
        g.add(p);
      }
      const beam = new THREE.Mesh(new THREE.BoxGeometry(1.2, 1.6, span * 2 + 0.6), steel);
      beam.position.set(0, 7.6, 0);
      beam.castShadow = true;
      g.add(beam);
      const sign = canvasTex(1024, 128, (c, w, h) => {
        c.fillStyle = '#0C0E1A'; c.fillRect(0, 0, w, h);
        c.fillStyle = '#FF6A1F'; c.fillRect(0, h - 14, w, 14);
        c.fillStyle = '#EEF1F7';
        c.font = '900 92px "Big Shoulders Display", "Arial Narrow", sans-serif';
        c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText('ÁPICE  ·  LARGADA / CHEGADA', w / 2, h / 2 - 4);
      });
      sign.wrapS = sign.wrapT = THREE.ClampToEdgeWrapping;
      const signMat = new THREE.MeshBasicMaterial({ map: sign, toneMapped: false });
      for (const s of [-1, 1]) {
        const pl = new THREE.Mesh(new THREE.PlaneGeometry(span * 2, 1.5), signMat);
        pl.position.set(s * 0.61, 7.6, 0);
        pl.rotation.y = s > 0 ? Math.PI / 2 : -Math.PI / 2;
        g.add(pl);
      }
      // semáforo
      this.lights = [];
      const housing = new THREE.Mesh(new THREE.BoxGeometry(0.7, 1.0, 3.6), new THREE.MeshStandardMaterial({ color: 0x08090f, roughness: 0.4 }));
      housing.position.set(-0.4, 6.3, 0);
      g.add(housing);
      for (let k = 0; k < 3; k++) {
        const m = new THREE.MeshBasicMaterial({ color: 0x2a1418, toneMapped: false });
        const l = new THREE.Mesh(new THREE.SphereGeometry(0.36, 16, 12), m);
        l.position.set(-0.8, 6.3, (k - 1) * 1.1);
        g.add(l);
        this.lights.push(m);
      }
      // pintura ÁPICE no asfalto
      const pi = Math.round(150 / tr.ds);
      const word = canvasTex(512, 128, (c, w, h) => {
        c.clearRect(0, 0, w, h);
        c.fillStyle = 'rgba(255,255,255,0.22)';
        c.font = '900 120px "Big Shoulders Display", "Arial Narrow", sans-serif';
        c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText('ÁPICE', w / 2, h / 2 + 6);
      }, { srgb: false });
      word.wrapS = word.wrapT = THREE.ClampToEdgeWrapping;
      const wm = new THREE.Mesh(new THREE.PlaneGeometry(12, 3), new THREE.MeshBasicMaterial({ map: word, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -5, polygonOffsetUnits: -5 }));
      wm.rotation.set(-Math.PI / 2, 0, -tr.ang[pi] + Math.PI / 2);
      wm.position.set(tr.xs[pi] * K, 0.05, tr.ys[pi] * K);
      scene.add(wm);
    }

    buildFeatures(scene, tr) {
      // placas de turbo
      const padTex = canvasTex(256, 128, (c, w, h) => {
        c.fillStyle = 'rgba(8,20,40,0.85)'; c.fillRect(0, 0, w, h);
        c.strokeStyle = '#38E1FF'; c.lineWidth = 6; c.strokeRect(3, 3, w - 6, h - 6);
        c.lineWidth = 14; c.lineJoin = 'miter';
        for (let k = 0; k < 4; k++) { const x = 30 + k * 52; c.beginPath(); c.moveTo(x, 22); c.lineTo(x + 34, h / 2); c.lineTo(x, h - 22); c.stroke(); }
      });
      padTex.wrapS = padTex.wrapT = THREE.ClampToEdgeWrapping;
      this.padMats = [];
      for (const p of tr.pads) {
        const m = new THREE.MeshBasicMaterial({ map: padTex, toneMapped: false, polygonOffset: true, polygonOffsetFactor: -5, polygonOffsetUnits: -5 });
        const mesh = new THREE.Mesh(new THREE.PlaneGeometry(p.len * K, p.w * K), m);
        mesh.rotation.set(-Math.PI / 2, 0, -p.a);
        mesh.position.set(p.x * K, 0.055, p.y * K);
        scene.add(mesh);
        this.padMats.push(m);
      }
      // gelo
      const iceMat = new THREE.MeshStandardMaterial({ color: 0xd8f0ff, roughness: 0.05, metalness: 0.1, transparent: true, opacity: 0.6, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4, envMapIntensity: 2 });
      for (const ic of tr.ice) {
        const g = new THREE.Group();
        g.position.set(ic.x * K, 0.05, ic.y * K);
        g.rotation.y = -ic.a;
        for (const bl of ic.blobs) {
          const m = new THREE.Mesh(new THREE.CircleGeometry(1, 24), iceMat);
          m.rotation.x = -Math.PI / 2;
          m.scale.set(bl.r * 1.3 * K, bl.r * 0.8 * K, 1);
          m.position.set(bl.dx * K, 0, bl.dy * K);
          g.add(m);
        }
        scene.add(g);
      }
    }

    buildDecor(scene, tr, rng) {
      const id = tr.themeId, th = tr.theme;
      const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), v = new THREE.Vector3(), sc = new THREE.Vector3();
      const up = new THREE.Vector3(0, 1, 0);
      const instance = (geo, mat, items, fn, shadow) => {
        if (!items.length) return null;
        const im = new THREE.InstancedMesh(geo, mat, items.length);
        items.forEach((d, k) => { fn(d, k); im.setMatrixAt(k, m4); });
        im.castShadow = shadow !== false;
        im.receiveShadow = true;
        scene.add(im);
        return im;
      };

      // postes / bandeiras
      const lamps = tr.lamps;
      if (id === 'night') {
        const pole = new THREE.CylinderGeometry(0.09, 0.14, 8, 8); pole.translate(0, 4, 0);
        const arm = new THREE.BoxGeometry(2.4, 0.12, 0.14); arm.translate(1.2, 7.9, 0);
        const head = new THREE.BoxGeometry(0.9, 0.16, 0.42); head.translate(2.2, 7.78, 0);
        const poleMat = new THREE.MeshStandardMaterial({ color: 0x596079, roughness: 0.5, metalness: 0.5 });
        const headMat = new THREE.MeshBasicMaterial({ color: 0xffe2a6, toneMapped: false });
        const setL = (l) => {
          const dir = Math.atan2(l.ly - l.y, l.lx - l.x);
          q.setFromAxisAngle(up, -dir);
          m4.compose(v.set(l.x * K, 0, l.y * K), q, sc.set(1, 1, 1));
        };
        instance(pole, poleMat, lamps, setL);
        instance(arm, poleMat, lamps, setL);
        instance(head, headMat, lamps, setL, false);
        // poças de luz
        const pool = new THREE.PlaneGeometry(18, 18); pool.rotateX(-Math.PI / 2);
        const poolMat = new THREE.MeshBasicMaterial({ map: radialTex('rgba(255,196,120,0.55)', 'rgba(255,160,80,0)'), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -6, polygonOffsetUnits: -6, toneMapped: false });
        instance(pool, poolMat, lamps, (l) => {
          m4.compose(v.set((l.x + (l.lx - l.x) * 0.45) * K, 0.06, (l.y + (l.ly - l.y) * 0.45) * K), q.identity(), sc.set(1, 1, 1));
        }, false);
      } else {
        const pole = new THREE.CylinderGeometry(0.06, 0.06, 4.2, 6); pole.translate(0, 2.1, 0);
        const flag = new THREE.PlaneGeometry(1.4, 0.9); flag.translate(0.72, 3.7, 0);
        const poleMat = new THREE.MeshStandardMaterial({ color: 0xe9edf5, roughness: 0.5 });
        const flagMat = new THREE.MeshStandardMaterial({ color: id === 'snow' ? 0x2f6bff : 0xffc23a, side: THREE.DoubleSide, roughness: 0.8 });
        const setL = (l) => { q.setFromAxisAngle(up, rng() * 6); m4.compose(v.set(l.x * K, 0, l.y * K), q, sc.set(1, 1, 1)); };
        instance(pole, poleMat, lamps, setL);
        this.flags = instance(flag, flagMat, lamps, setL);
      }

      const items = (type) => tr.decor.filter((d) => d.type === type);
      if (id === 'night') {
        // prédios mesclados com janelas acesas
        const facade = canvasTex(256, 512, (c, w, h) => {
          c.fillStyle = '#171A28'; c.fillRect(0, 0, w, h);
          const cols = 8, rows = 24, cw = w / cols, rh = h / rows;
          const r = mulberry32(17);
          for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
            const p = r();
            c.fillStyle = p < 0.22 ? '#FFD38A' : p < 0.3 ? '#9FD8FF' : '#0D0F18';
            c.fillRect(x * cw + 6, y * rh + 5, cw - 12, rh - 10);
          }
        });
        const emiss = canvasTex(256, 512, (c, w, h) => {
          c.fillStyle = '#000'; c.fillRect(0, 0, w, h);
          const cols = 8, rows = 24, cw = w / cols, rh = h / rows;
          const r = mulberry32(17);
          for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
            const p = r();
            if (p < 0.3) { c.fillStyle = p < 0.22 ? '#FFC870' : '#7FC8FF'; c.fillRect(x * cw + 6, y * rh + 5, cw - 12, rh - 10); }
          }
        });
        const bl = items('bldg');
        const walls = [], roofs = [], neonA = [], neonB = [];
        for (const d of bl) {
          const H = 10 + d.hgt * 1.7;
          walls.push({ x: d.x * K, y: H / 2, z: d.y * K, sx: d.w * K, sy: H, sz: d.h * K, noTop: true, uo: rng() * 24, vo: Math.floor(rng() * 8) * 3 });
          roofs.push({ x: d.x * K, y: H + 0.05, z: d.y * K, sx: d.w * K - 0.2, sy: 0.1, sz: d.h * K - 0.2 });
          for (const a of d.details) roofs.push({ x: (d.x + a.x) * K, y: H + 0.8, z: (d.y + a.y) * K, sx: a.w * K, sy: 1.6, sz: a.h * K });
          if (d.neon) {
            const arr = d.neon === 'A' ? neonA : neonB;
            const wx = d.w * K, wz = d.h * K, t = 0.25;
            arr.push({ x: d.x * K, y: H + 0.4, z: d.y * K - wz / 2, sx: wx, sy: t, sz: t });
            arr.push({ x: d.x * K, y: H + 0.4, z: d.y * K + wz / 2, sx: wx, sy: t, sz: t });
            arr.push({ x: d.x * K - wx / 2, y: H + 0.4, z: d.y * K, sx: t, sy: t, sz: wz });
            arr.push({ x: d.x * K + wx / 2, y: H + 0.4, z: d.y * K, sx: t, sy: t, sz: wz });
          }
        }
        if (walls.length) {
          const wm = new THREE.Mesh(boxesGeometry(walls, [24, 72]), new THREE.MeshStandardMaterial({ map: facade, emissiveMap: emiss, emissive: 0xffffff, emissiveIntensity: 1.1, roughness: 0.7, metalness: 0.2 }));
          wm.castShadow = true; wm.receiveShadow = true;
          scene.add(wm);
          const rm = new THREE.Mesh(boxesGeometry(roofs), new THREE.MeshStandardMaterial({ color: 0x2c3043, roughness: 0.9 }));
          rm.castShadow = true;
          scene.add(rm);
          if (neonA.length) scene.add(new THREE.Mesh(boxesGeometry(neonA), new THREE.MeshBasicMaterial({ color: th.neonA, toneMapped: false })));
          if (neonB.length) scene.add(new THREE.Mesh(boxesGeometry(neonB), new THREE.MeshBasicMaterial({ color: th.neonB, toneMapped: false })));
        }
        const trees = items('tree');
        const tg = new THREE.IcosahedronGeometry(1, 1); tg.translate(0, 1.4, 0);
        instance(tg, new THREE.MeshStandardMaterial({ color: 0x1f4236, roughness: 0.9, flatShading: true }), trees, (d) => {
          m4.compose(v.set(d.x * K, 0, d.y * K), q.identity(), sc.set(d.r * K * 1.6, d.r * K * 1.5, d.r * K * 1.6));
        });
      } else if (id === 'desert') {
        const dunes = items('dune');
        const dg = new THREE.SphereGeometry(1, 24, 10, 0, Math.PI * 2, 0, Math.PI / 2);
        instance(dg, new THREE.MeshStandardMaterial({ color: 0xc4834c, roughness: 1 }), dunes, (d) => {
          q.setFromAxisAngle(up, -d.rot);
          m4.compose(v.set(d.x * K, -0.4, d.y * K), q, sc.set(d.rx * K, 3 + (d.ry % 7), d.ry * K));
        }, false);
        const rocks = items('rock');
        instance(new THREE.DodecahedronGeometry(1, 0), new THREE.MeshStandardMaterial({ color: 0x9a6442, roughness: 0.95, flatShading: true }), rocks, (d) => {
          q.setFromEuler(new THREE.Euler(d.rot, d.rot * 2, 0));
          const s = d.r * K;
          m4.compose(v.set(d.x * K, s * 0.3, d.y * K), q, sc.set(s * 1.2, s * 0.8, s));
        });
        const bushes = items('bush');
        instance(new THREE.IcosahedronGeometry(1, 0), new THREE.MeshStandardMaterial({ color: 0x8a7f45, roughness: 1, flatShading: true }), bushes, (d) => {
          const s = d.r * K; m4.compose(v.set(d.x * K, s * 0.4, d.y * K), q.identity(), sc.set(s, s * 0.7, s));
        });
        const cg = mergeGeoms([
          { geo: new THREE.CylinderGeometry(0.32, 0.38, 4.2, 8).translate(0, 2.1, 0) },
          { geo: new THREE.CylinderGeometry(0.22, 0.24, 1.6, 8).translate(0, 0.8, 0), matrix: new THREE.Matrix4().makeTranslation(0.75, 1.8, 0) },
          { geo: new THREE.CylinderGeometry(0.2, 0.22, 1.3, 8).translate(0, 0.65, 0), matrix: new THREE.Matrix4().makeTranslation(-0.7, 2.3, 0) },
          { geo: new THREE.CylinderGeometry(0.2, 0.2, 0.75, 8).rotateZ(Math.PI / 2), matrix: new THREE.Matrix4().makeTranslation(0.4, 1.8, 0) },
          { geo: new THREE.CylinderGeometry(0.18, 0.18, 0.7, 8).rotateZ(Math.PI / 2), matrix: new THREE.Matrix4().makeTranslation(-0.38, 2.3, 0) },
        ]);
        instance(cg, new THREE.MeshStandardMaterial({ color: 0x3f7d4e, roughness: 0.8 }), items('cactus'), (d) => {
          q.setFromAxisAngle(up, d.rot); const s = 0.8 + (d.r % 5) * 0.12;
          m4.compose(v.set(d.x * K, 0, d.y * K), q, sc.set(s, s, s));
        });
      } else {
        const lakes = items('lake');
        for (const d of lakes) {
          const m = new THREE.Mesh(new THREE.CircleGeometry(1, 40), new THREE.MeshStandardMaterial({ color: 0x9cc9e6, roughness: 0.08, metalness: 0.2, envMapIntensity: 1.6 }));
          m.rotation.set(-Math.PI / 2, 0, -d.rot);
          m.scale.set(d.rx * K, d.ry * K, 1);
          m.position.set(d.x * K, 0.04, d.y * K);
          m.receiveShadow = true;
          scene.add(m);
        }
        const pineGeo = mergeGeoms([
          { geo: new THREE.CylinderGeometry(0.18, 0.24, 1.4, 6).translate(0, 0.7, 0) },
          { geo: new THREE.ConeGeometry(1.7, 2.6, 7).translate(0, 2.3, 0) },
          { geo: new THREE.ConeGeometry(1.35, 2.3, 7).translate(0, 3.6, 0) },
          { geo: new THREE.ConeGeometry(0.95, 2.0, 7).translate(0, 4.8, 0) },
        ]);
        const pines = items('pine');
        const pm = instance(pineGeo, new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.9, flatShading: true }), pines, (d) => {
          q.setFromAxisAngle(up, d.rot); const s = d.r * K * 0.75;
          m4.compose(v.set(d.x * K, 0, d.y * K), q, sc.set(s, s * (1.1 + (d.v * 0.15)), s));
        });
        if (pm) {
          const greens = [0x143a2a, 0x18402f, 0x1c3f29];
          pines.forEach((d, k) => pm.setColorAt(k, new THREE.Color(greens[d.v % 3])));
          pm.instanceColor.needsUpdate = true;
          // neve no topo
          const capGeo = new THREE.ConeGeometry(0.62, 1.1, 7).translate(0, 5.55, 0);
          instance(capGeo, new THREE.MeshStandardMaterial({ color: 0xf7faff, roughness: 1, flatShading: true }), pines, (d) => {
            q.setFromAxisAngle(up, d.rot); const s = d.r * K * 0.75;
            m4.compose(v.set(d.x * K, 0, d.y * K), q, sc.set(s, s * (1.1 + (d.v * 0.15)), s));
          });
        }
        instance(new THREE.DodecahedronGeometry(1, 0), new THREE.MeshStandardMaterial({ color: 0x7d8699, roughness: 0.95, flatShading: true }), items('srock'), (d) => {
          q.setFromEuler(new THREE.Euler(d.rot, d.rot * 2, 0)); const s = d.r * K;
          m4.compose(v.set(d.x * K, s * 0.3, d.y * K), q, sc.set(s * 1.2, s * 0.8, s));
        });
      }

      // arquibancadas
      for (const st of tr.stands) {
        const g = new THREE.Group();
        g.position.set(st.x * K, 0, st.y * K);
        g.rotation.y = -st.a;
        scene.add(g);
        const len = st.len * K, dep = st.depth * K;
        const crowd = canvasTex(1024, 128, (c, w, h) => {
          c.fillStyle = '#2A2F40'; c.fillRect(0, 0, w, h);
          const r = mulberry32(5);
          const cols = ['#FF6A1F', '#2F6BFF', '#FFC23A', '#E9EDF5', '#22C98A', '#C42A4A', '#F4B9A0', '#8B5CFF', '#38E1FF'];
          for (let row = 0; row < 6; row++) {
            c.fillStyle = row % 2 ? '#3A4157' : '#343B50'; c.fillRect(0, row * (h / 6), w, h / 6 - 2);
            for (let x = 4; x < w; x += 9) { if (r() < 0.1) continue; c.fillStyle = cols[Math.floor(r() * cols.length)]; c.beginPath(); c.arc(x + (r() - 0.5) * 2, row * (h / 6) + 10, 3.4, 0, Math.PI * 2); c.fill(); }
          }
        });
        crowd.wrapS = crowd.wrapT = THREE.ClampToEdgeWrapping;
        // degraus inclinados afastando da pista (eixo +z local = normal da pista)
        const s = st.side;
        const slope = new THREE.PlaneGeometry(len, Math.hypot(dep, 6));
        const seats = new THREE.Mesh(slope, new THREE.MeshStandardMaterial({ map: crowd, roughness: 0.9, side: THREE.DoubleSide }));
        seats.rotation.x = s * (Math.PI / 2 - Math.atan2(6, dep));
        seats.position.set(0, 3.2, 0);
        seats.receiveShadow = true;
        g.add(seats);
        const back = new THREE.Mesh(new THREE.BoxGeometry(len, 7, 0.4), new THREE.MeshStandardMaterial({ color: 0x23283a, roughness: 0.8 }));
        back.position.set(0, 3.5, s * (dep / 2 + 0.2));
        back.castShadow = true;
        g.add(back);
        const roofTex = canvasTex(256, 8, (c, w, h) => { for (let x = 0; x < w; x += 16) { c.fillStyle = (x / 16) % 2 ? '#FF6A1F' : '#F1F3F8'; c.fillRect(x, 0, 16, h); } });
        roofTex.repeat.set(len / 20, 1);
        const roof = new THREE.Mesh(new THREE.BoxGeometry(len + 1, 0.3, dep + 2), new THREE.MeshStandardMaterial({ map: roofTex, roughness: 0.6 }));
        roof.position.set(0, 9, s * 0.6);
        roof.castShadow = true;
        g.add(roof);
        for (const px of [-len / 2, 0, len / 2]) {
          const col = new THREE.Mesh(new THREE.BoxGeometry(0.4, 9, 0.4), new THREE.MeshStandardMaterial({ color: 0x3a4054 }));
          col.position.set(px, 4.5, -s * (dep / 2 - 0.5));
          g.add(col);
        }
      }
    }

    buildHorizon(scene, tr, rng) {
      const id = tr.themeId;
      const c = this.center;
      if (id === 'night') {
        const boxes = [];
        for (let i = 0; i < 160; i++) {
          const a = (i / 160) * Math.PI * 2 + rng() * 0.02;
          const r = 520 + rng() * 260;
          const H = 30 + rng() * 140;
          const w = 18 + rng() * 30;
          boxes.push({ x: c.x + Math.cos(a) * r, y: H / 2, z: c.z + Math.sin(a) * r, sx: w, sy: H, sz: w, noTop: false, uo: rng() * 24, vo: rng() * 30 });
        }
        const facadeE = canvasTex(128, 256, (g, w, h) => {
          g.fillStyle = '#000'; g.fillRect(0, 0, w, h);
          const r = mulberry32(41);
          for (let y = 0; y < 32; y++) for (let x = 0; x < 8; x++) { if (r() < 0.28) { g.fillStyle = r() < 0.7 ? '#FFC870' : '#7FC8FF'; g.fillRect(x * 16 + 4, y * 8 + 2, 8, 4); } }
        });
        const m = new THREE.Mesh(boxesGeometry(boxes, [30, 60]), new THREE.MeshStandardMaterial({ color: 0x0f1220, emissiveMap: facadeE, emissive: 0xffffff, emissiveIntensity: 0.9, roughness: 0.9 }));
        scene.add(m);
      } else {
        const g = new THREE.ConeGeometry(1, 1, 6, 1);
        g.translate(0, 0.5, 0);
        const mat = new THREE.MeshStandardMaterial({ color: id === 'desert' ? 0x9a5844 : 0xf2f6fb, roughness: 1, flatShading: true });
        const n = 70;
        const im = new THREE.InstancedMesh(g, mat, n);
        const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), v = new THREE.Vector3(), s = new THREE.Vector3();
        for (let i = 0; i < n; i++) {
          const a = (i / n) * Math.PI * 2 + rng() * 0.05;
          const r = 700 + rng() * 380;
          const rad = 80 + rng() * 140;
          const H = id === 'desert' ? 40 + rng() * 90 : 90 + rng() * 170;
          q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), rng() * 6);
          m4.compose(v.set(c.x + Math.cos(a) * r, -2, c.z + Math.sin(a) * r), q, s.set(rad, H, rad * (0.7 + rng() * 0.5)));
          im.setMatrixAt(i, m4);
        }
        scene.add(im);
      }
    }

    /* ---------- Carros da corrida ---------- */
    setRace(race) {
      if (this.race === race) return;
      if (this.carGroup) {
        this.scene.remove(this.carGroup);
        this.carGroup.traverse((o) => { if (o.material && o.material.map && o.material.map !== sharedGeo().beamTex) o.material.map.dispose(); });
      }
      this.race = race;
      this.carGroup = new THREE.Group();
      this.scene.add(this.carGroup);
      this.carMeshes = new Map();
      for (const c of race.cars) {
        const m = buildCar(c.spec, c.paint, this.night, this.night ? 1.3 : this.track.themeId === 'desert' ? 0.8 : 0.5);
        this.carGroup.add(m);
        this.carMeshes.set(c, m);
      }
      this.skids.count = 0;
      this.skidSeen = 0;
      this.lastSkidHead = 0;
      this.yaw = race.focusCar() ? race.focusCar().a : 0;
      this.camInit = false;
      this.focusIdx = 0;
    }

    /* ---------- Quadro ---------- */
    draw(race, dt, opts) {
      opts = opts || {};
      this.setTrack(race.track);
      this.setRace(race);
      this.time += dt;
      const tr = race.track;
      const focus = race.focusCar();
      if (!focus) return;

      // carros
      for (const c of race.cars) {
        const m = this.carMeshes.get(c);
        m.position.set(c.x * K, 0, c.y * K);
        m.rotation.y = -c.a;
        const ud = m.userData;
        // rolagem lateral e arfagem (sensação de peso)
        const latAcc = clamp(c.av * c.vf / 700, -1, 1);
        ud.roll = damp(ud.roll, -latAcc * 0.06, 8, dt);
        ud.pitch = damp(ud.pitch || 0, (c.brake > 0.1 && c.vf > 30 ? -0.028 : 0) + (c.gas > 0 && c.vf < 300 ? 0.016 : 0), 6, dt);
        m.rotation.x = ud.roll;
        m.rotation.z = ud.pitch;
        for (const w of ud.wheels) {
          if (w.front) w.g.rotation.y = -c.steer * 0.42;
          w.spin.rotation.z -= (c.vf * K * dt) / 0.34;
          w.rim.rotation.z = w.spin.rotation.z;
        }
        const braking = c.brake > 0.1 && c.vf > 10;
        ud.tailMat.emissiveIntensity = braking ? 3.2 : this.night ? 1.2 : 0.6;
      }

      this.updateCamera(race, focus, dt, opts);
      this.updateSkids(race);
      this.updateParticles(race);

      // semáforo do pórtico
      if (this.lights) {
        let lit = 0, green = false;
        if (race.state === 'countdown') lit = race.countdown > 3 ? 0 : race.countdown > 2 ? 1 : race.countdown > 1 ? 2 : 3;
        else green = race.time < 2.5;
        this.lights.forEach((m, k) => m.color.setHex(green ? 0x2bd98a : k < lit ? 0xff2b4a : 0x2a1418));
      }
      for (const m of this.padMats || []) m.map.offset.x = -((this.time * 1.6) % 1);

      // sol/sombra acompanham o foco
      const fx = focus.x * K, fz = focus.y * K;
      this.sun.position.set(fx + this.sunOffset.x, this.sunOffset.y, fz + this.sunOffset.z);
      this.sun.target.position.set(fx, 0, fz);
      this.sky.position.set(this.camera.position.x, 0, this.camera.position.z);

      if (this.spot && race.player && !race.attract) {
        const p = race.player;
        const ca = Math.cos(p.a), sa = Math.sin(p.a);
        this.spot.position.set((p.x + ca * 20) * K, 1.0, (p.y + sa * 20) * K);
        this.spot.target.position.set((p.x + ca * 260) * K, 0, (p.y + sa * 260) * K);
      }
      if (this.snow) {
        const pa = this.snow.geometry.attributes.position, arr = pa.array;
        const cx = this.camera.position.x, cz = this.camera.position.z;
        for (let i = 0; i < arr.length; i += 3) {
          arr[i + 1] -= dt * (3 + (i % 7) * 0.4);
          arr[i] += Math.sin(this.time + i) * dt * 0.6;
          if (arr[i + 1] < 0) arr[i + 1] += 40;
          let dx = arr[i] - cx, dz = arr[i + 2] - cz;
          if (dx > 60) arr[i] -= 120; else if (dx < -60) arr[i] += 120;
          if (dz > 60) arr[i + 2] -= 120; else if (dz < -60) arr[i + 2] += 120;
        }
        pa.needsUpdate = true;
      }

      this.gl.render(this.scene, this.camera);
    }

    updateCamera(race, f, dt, opts) {
      const cam = this.camera;
      const s01 = clamp(f.speed / f.spec.maxSpeed, 0, 1.3);
      let dist, height, look, fov;
      let targetYaw = f.a;
      if (f.speed > 80) targetYaw = f.a + wrapAngle(Math.atan2(f.vy, f.vx) - f.a) * 0.45;
      if (race.attract) {
        // câmera de TV: gira devagar em volta do líder
        targetYaw = f.a + Math.PI * 0.08 + Math.sin(this.time * 0.17) * 0.9;
        dist = 13; height = 5.2; look = 2; fov = 52;
      } else if (this.camMode === 'high') {
        dist = 17; height = 10.5; look = 7; fov = 58 + s01 * 6;
      } else {
        dist = 7.2 + s01 * 0.8; height = 2.55; look = 6; fov = 62 + s01 * 9 + (f.nitroOn ? 6 : 0);
      }
      if (cam.aspect < 1) { fov += 14; dist += 1.6; height += 0.5; }
      if (race.state === 'countdown' && !race.attract) {
        const k = Math.pow(clamp(race.countdown / 3.8, 0, 1), 1.5);
        targetYaw += k * 2.6;
        dist += k * 7;
        height += k * 2.5;
      }
      if (!this.camInit) { this.yaw = targetYaw; this.camInit = true; }
      this.yaw += wrapAngle(targetYaw - this.yaw) * (1 - Math.exp(-(race.attract ? 1.5 : 5.5) * dt));
      const cx = f.x * K, cz = f.y * K;
      const sh = race.cam.shake * 0.02;
      const px = cx - Math.cos(this.yaw) * dist + (Math.random() - 0.5) * sh;
      const pz = cz - Math.sin(this.yaw) * dist + (Math.random() - 0.5) * sh;
      cam.position.set(px, height + (Math.random() - 0.5) * sh, pz);
      cam.lookAt(cx + Math.cos(f.a) * look, 1.0, cz + Math.sin(f.a) * look);
      if (Math.abs(cam.fov - fov) > 0.05) {
        cam.fov = damp(cam.fov, fov, 3, dt);
        cam.updateProjectionMatrix();
      }
    }

    updateSkids(race) {
      const n = race.skidCount;
      if (!n) { this.skids.count = 0; return; }
      const head = race.skidHead;
      const s = race.skids;
      const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), v = new THREE.Vector3(), sc = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
      const col = new THREE.Color();
      // escreve só os segmentos novos desde o último quadro
      let k = this.lastSkidHead;
      let guard = 0;
      while (k !== head && guard < 2600) {
        const o = k * 5;
        const x1 = s[o] * K, z1 = s[o + 1] * K, x2 = s[o + 2] * K, z2 = s[o + 3] * K, a = s[o + 4];
        const len = Math.hypot(x2 - x1, z2 - z1) + 0.05;
        q.setFromAxisAngle(up, -Math.atan2(z2 - z1, x2 - x1));
        m4.compose(v.set((x1 + x2) / 2, 0.048, (z1 + z2) / 2), q, sc.set(len, 1, 0.42));
        this.skids.setMatrixAt(k, m4);
        const t = clamp(a * 1.6, 0, 1);
        col.setRGB(lerp(1, this.skidColor[0], t), lerp(1, this.skidColor[1], t), lerp(1, this.skidColor[2], t));
        this.skids.setColorAt(k, col);
        k = (k + 1) % 2600;
        guard++;
      }
      if (guard) {
        this.skids.instanceMatrix.needsUpdate = true;
        if (this.skids.instanceColor) this.skids.instanceColor.needsUpdate = true;
      }
      this.lastSkidHead = head;
      this.skids.count = n;
    }

    updateParticles(race) {
      const ps = race.particles;
      const soft = this.pSoft.geometry.attributes, glow = this.pGlow.geometry.attributes;
      let ns = 0, ng = 0;
      const dc = this.dustCol;
      const scale = (this.h * this.gl.getPixelRatio() * 0.5) / Math.tan((this.camera.fov * Math.PI) / 360);
      this.pSoft.material.uniforms.scale.value = scale;
      this.pGlow.material.uniforms.scale.value = scale;
      for (const p of ps) {
        const t = p.life / p.max;
        if (p.type === 'smoke' || p.type === 'dust') {
          if (ns >= 1200) continue;
          const y = 0.4 + (1 - t) * (p.type === 'smoke' ? 1.6 : 0.9);
          soft.position.setXYZ(ns, p.x * K, y, p.y * K);
          soft.size.setX(ns, p.size * K * 2.2);
          soft.alpha.setX(ns, (p.type === 'smoke' ? (this.night ? 0.28 : 0.4) : 0.5) * t);
          if (p.type === 'smoke') soft.pcolor.setXYZ(ns, 0.85, 0.87, 0.9);
          else soft.pcolor.setXYZ(ns, dc.r, dc.g, dc.b);
          ns++;
        } else {
          if (ng >= 1200) continue;
          const flame = p.type === 'flame';
          glow.position.setXYZ(ng, p.x * K, flame ? 0.55 : 0.35 + (1 - t) * 0.6, p.y * K);
          glow.size.setX(ng, flame ? 0.18 + p.size * K * t * 0.6 : 0.2);
          glow.alpha.setX(ng, flame ? t * 0.45 : t);
          if (flame) { if (t > 0.5) glow.pcolor.setXYZ(ng, 0.4, 0.75, 1); else glow.pcolor.setXYZ(ng, 1, 0.55, 0.15); }
          else glow.pcolor.setXYZ(ng, 1, 0.75 + 0.25 * t, 0.35 * t);
          ng++;
        }
      }
      for (const a of [soft, glow]) { a.position.needsUpdate = true; a.size.needsUpdate = true; a.alpha.needsUpdate = true; a.pcolor.needsUpdate = true; }
      this.pSoft.geometry.setDrawRange(0, ns);
      this.pGlow.geometry.setDrawRange(0, ng);
    }

    /* minimapa: reaproveita o do 2D */
    drawMinimap(race, canvas) {
      if (!this.mini2d) this.mini2d = { mini: null };
      APX.Renderer.prototype.drawMinimap.call(this.mini2d, race, canvas);
    }
  }

  APX.Renderer3D = Renderer3D;
  APX.webgl3D = webglOK();
})(APX);
