/* Ápice Racing — controlador do site: garagem, circuitos, grid, HUD, resultados e recordes */
'use strict';
(function (APX) {
  const { store, fmtTime, fmtGap, clamp } = APX.util;
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const reduced = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  const KMH = 0.36;

  const carById = (id) => APX.CARS.find((c) => c.id === id) || APX.CARS[0];
  const tracks = APX.getTracks();
  const trackById = (id) => tracks.find((t) => t.id === id) || tracks[0];
  const paintName = (hex) => (APX.PAINTS.find((p) => p.hex.toLowerCase() === hex.toLowerCase()) || { name: 'Personalizada' }).name;

  const state = {
    carId: store.get('car2', 'relampago'),
    paint: store.get('paint', null),
    trackId: store.get('track', 'distrito'),
    laps: store.get('laps', 3),
    difficulty: store.get('difficulty', 'medio'),
    opponents: store.get('opponents', 5),
    name: store.get('name', ''),
    camera: store.get('camera', 'chase'),
  };
  if (!['chase', 'high', 'top'].includes(state.camera)) state.camera = 'chase';
  const use3D = !!(APX.Renderer3D && APX.webgl3D);
  const CAM_LABEL = { chase: 'Câmera atrás do carro', high: 'Câmera alta', top: 'Vista de cima' };
  if (!APX.CARS.some((c) => c.id === state.carId)) state.carId = 'relampago';
  if (!state.paint) state.paint = carById(state.carId).paint;

  const input = new APX.Input();
  const audio = new APX.AudioFX();

  function save() {
    store.set('car2', state.carId);
    store.set('paint', state.paint);
    store.set('track', state.trackId);
    store.set('laps', state.laps);
    store.set('difficulty', state.difficulty);
    store.set('opponents', state.opponents);
    store.set('name', state.name);
    store.set('camera', state.camera);
  }

  function shortName(n) {
    const p = n.trim().split(/\s+/);
    if (p.length < 2) return n.toUpperCase().slice(0, 12);
    return (p[0][0] + '. ' + p[p.length - 1]).toUpperCase();
  }

  /* ================= Garagem ================= */
  function buildGarage() {
    const wrap = $('#cars');
    wrap.innerHTML = '';
    for (const c of APX.CARS) {
      const st = APX.carStats(c);
      const el = document.createElement('div');
      el.className = 'car-card';
      el.setAttribute('role', 'radio');
      el.tabIndex = 0;
      el.dataset.car = c.id;
      el.innerHTML = `
        <div class="car-stage">
          <span class="car-num">${c.model ? '3D' : '#' + c.number}</span>
          <span class="car-chosen">No grid</span>
          <canvas aria-hidden="true"></canvas>
        </div>
        <div class="car-body">
          <span class="car-tag">${c.tag}</span>
          <h3>${c.name}</h3>
          <p class="car-blurb">${c.blurb}</p>
          <dl class="stats">
            ${[['Velocidade', st.velocidade], ['Aceleração', st.aceleracao], ['Controle', st.controle], ['Nitro', st.nitro]]
              .map(([k, v]) => `<div><dt>${k}</dt><dd><span class="bar"><i style="--v:${v}%"></i></span><b>${v}</b></dd></div>`).join('')}
          </dl>
          <p class="car-spec"><span>Vel. máx <b>${Math.round(c.maxSpeed * KMH)} km/h</b></span><span>Peso <b>${(c.mass * 1100).toLocaleString('pt-BR', { maximumFractionDigits: 0 })} kg</b></span></p>
        </div>`;
      el.addEventListener('click', () => selectCar(c.id));
      el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); selectCar(c.id); }
        if (e.key === 'ArrowRight' || e.key === 'ArrowDown' || e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
          e.preventDefault();
          const i = APX.CARS.indexOf(c);
          const n = APX.CARS[(i + (e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : APX.CARS.length - 1)) % APX.CARS.length];
          selectCar(n.id);
          $(`.car-card[data-car="${n.id}"]`).focus();
        }
      });
      wrap.appendChild(el);
    }
    syncGarage();
  }

  function syncGarage() {
    for (const el of $$('.car-card')) {
      const on = el.dataset.car === state.carId;
      el.setAttribute('aria-checked', String(on));
      el.tabIndex = on ? 0 : -1;
      const c = carById(el.dataset.car);
      if (c.model) drawModelCard($('canvas', el), c);
      else APX.drawCarPreview($('canvas', el), c, on ? state.paint : c.paint);
    }
    const sel = carById(state.carId);
    for (const sw of $$('.swatch')) sw.disabled = !!sel.model;
    $('.paint').classList.toggle('locked', !!sel.model);
    for (const s of $$('.swatch')) s.setAttribute('aria-checked', String(s.dataset.hex.toLowerCase() === state.paint.toLowerCase()));
    $('#paint-name').textContent = carById(state.carId).model ? 'Original do modelo 3D' : paintName(state.paint);
    syncSetup();
  }

  // card do carro 3D: desenha o contorno 2D e troca pela foto do modelo quando carregar
  function drawModelCard(canvas, c) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const r = canvas.getBoundingClientRect();
    const w = Math.max(1, Math.round(r.width * dpr)), h = Math.max(1, Math.round(r.height * dpr));
    if (canvas.dataset.model === w + 'x' + h) return;
    APX.drawCarPreview(canvas, c, c.paint);
    if (!APX.carModelPreview || !use3D) return;
    APX.carModelPreview(c.model, w, h).then((img) => {
      if (!img) return;
      canvas.width = w; canvas.height = h;
      const ctx = canvas.getContext('2d');
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, w, h);
      ctx.drawImage(img, 0, 0);
      canvas.dataset.model = w + 'x' + h;
    });
  }

  function selectCar(id) {
    if (state.carId !== id) state.paint = carById(id).paint;
    state.carId = id;
    save();
    syncGarage();
  }

  function buildPaints() {
    const wrap = $('#swatches');
    wrap.innerHTML = '';
    for (const p of APX.PAINTS) {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'swatch';
      b.setAttribute('role', 'radio');
      b.setAttribute('aria-label', p.name);
      b.title = p.name;
      b.dataset.hex = p.hex;
      b.style.setProperty('--c', p.hex);
      b.addEventListener('click', () => {
        if (carById(state.carId).model) return;
        state.paint = p.hex;
        save();
        syncGarage();
      });
      wrap.appendChild(b);
    }
  }

  /* ================= Circuitos ================= */
  function buildTracks() {
    const wrap = $('#tracks');
    wrap.innerHTML = '';
    const rec = store.get('records', {});
    for (const t of tracks) {
      const el = document.createElement('div');
      el.className = 'track-card';
      el.setAttribute('role', 'radio');
      el.tabIndex = 0;
      el.dataset.track = t.id;
      const best = rec[t.id] && rec[t.id].lap ? fmtTime(rec[t.id].lap.ms) : 'sem tempo';
      el.innerHTML = `
        <div class="track-stage" data-theme-id="${t.themeId}">
          <span class="track-theme">${t.theme.label}</span>
          <canvas aria-hidden="true"></canvas>
        </div>
        <div class="track-body">
          <span class="track-place">${t.place}</span>
          <h3>${t.name}</h3>
          <p class="track-blurb">${t.blurb}</p>
          <dl class="track-facts">
            <div><dt>Extensão</dt><dd>${t.lengthM.toLocaleString('pt-BR')} m</dd></div>
            <div><dt>Curvas</dt><dd>${t.curves}</dd></div>
            <div><dt>Recorde</dt><dd>${best}</dd></div>
          </dl>
        </div>`;
      el.addEventListener('click', () => selectTrack(t.id));
      el.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); selectTrack(t.id); }
        if (e.key.startsWith('Arrow')) {
          e.preventDefault();
          const i = tracks.indexOf(t);
          const n = tracks[(i + (e.key === 'ArrowRight' || e.key === 'ArrowDown' ? 1 : tracks.length - 1)) % tracks.length];
          selectTrack(n.id);
          $(`.track-card[data-track="${n.id}"]`).focus();
        }
      });
      wrap.appendChild(el);
    }
    syncTracks();
  }

  function syncTracks() {
    for (const el of $$('.track-card')) {
      const on = el.dataset.track === state.trackId;
      el.setAttribute('aria-checked', String(on));
      el.tabIndex = on ? 0 : -1;
      APX.drawTrackThumb($('canvas', el), trackById(el.dataset.track), '#FF6A1F');
    }
    syncSetup();
  }

  function selectTrack(id) {
    state.trackId = id;
    save();
    syncTracks();
  }

  /* ================= Grid de largada ================= */
  function seg(id, name, options, value, onChange) {
    const wrap = $(id);
    wrap.innerHTML = '';
    for (const [val, label] of options) {
      const l = document.createElement('label');
      const inp = document.createElement('input');
      inp.type = 'radio';
      inp.name = name;
      inp.id = name + '-' + val;
      inp.value = String(val);
      inp.checked = String(val) === String(value);
      inp.addEventListener('change', () => onChange(val));
      const span = document.createElement('span');
      span.textContent = label;
      l.append(inp, span);
      wrap.appendChild(l);
    }
  }

  function buildSetup() {
    seg('#seg-laps', 'laps', [[1, '1'], [3, '3'], [5, '5']], state.laps, (v) => { state.laps = v; save(); syncSetup(); });
    seg('#seg-opponents', 'opponents', [[3, '3'], [5, '5'], [7, '7']], state.opponents, (v) => { state.opponents = v; save(); syncSetup(); });
    seg('#seg-difficulty', 'difficulty', Object.entries(APX.DIFFICULTY).map(([k, d]) => [k, d.label]), state.difficulty, (v) => { state.difficulty = v; save(); syncSetup(); });
    const nm = $('#driver-name');
    nm.value = state.name;
    nm.addEventListener('input', () => { state.name = nm.value.trim().slice(0, 14); save(); });
    $('#setup-form').addEventListener('submit', (e) => { e.preventDefault(); startRace(); });
    syncSetup();
  }

  function syncSetup() {
    const c = carById(state.carId), t = trackById(state.trackId);
    const line = $('#setup-line');
    if (!line) return;
    line.textContent = `${c.name} ${t.themeId === 'night' ? 'no' : 'na'} ${t.name}`;
    const total = (t.lengthM * state.laps) / 1000;
    const rec = store.get('records', {});
    const best = rec[t.id] && rec[t.id].lap ? fmtTime(rec[t.id].lap.ms) : '—';
    $('#setup-facts').innerHTML = [
      ['Pintura', paintName(state.paint)],
      ['Distância', `${total.toLocaleString('pt-BR', { maximumFractionDigits: 2 })} km · ${state.laps} ${state.laps === 1 ? 'volta' : 'voltas'}`],
      ['Grid', `${state.opponents + 1} carros · você larga em ${state.opponents}º`],
      ['IA', APX.DIFFICULTY[state.difficulty].label],
      ['Seu recorde', best],
    ].map(([k, v]) => `<li><span>${k}</span><b>${v}</b></li>`).join('');
    $('#hero-pick').textContent = `${c.name} · ${t.name} · ${state.laps} ${state.laps === 1 ? 'volta' : 'voltas'} · IA ${APX.DIFFICULTY[state.difficulty].label.toLowerCase()}`;
  }

  /* ================= Recordes ================= */
  function renderRecords() {
    const rec = store.get('records', {});
    const body = $('#records tbody');
    body.innerHTML = tracks.map((t) => {
      const r = rec[t.id] || {};
      const lap = r.lap;
      const races = r.race || {};
      const raceTxt = Object.keys(races).sort((a, b) => a - b).map((l) => `${l} ${Number(l) === 1 ? 'volta' : 'voltas'} em ${fmtTime(races[l].ms)}`).join(' · ');
      if (!lap) return `<tr><td>${t.name}</td><td class="empty" colspan="4">Sem volta registrada. Complete uma corrida aqui para marcar seu tempo.</td></tr>`;
      const d = new Date(lap.date);
      return `<tr><td>${t.name}</td><td class="t best">${fmtTime(lap.ms)}</td><td>${lap.car}</td><td class="t">${raceTxt || '—'}</td><td class="t">${d.toLocaleDateString('pt-BR')}</td></tr>`;
    }).join('');
  }

  function saveRecords(race) {
    const p = race.player;
    const rec = store.get('records', {});
    const r = rec[race.track.id] || (rec[race.track.id] = {});
    const flags = { lap: false, race: false };
    if (p.bestLap != null && (!r.lap || p.bestLap < r.lap.ms)) {
      r.lap = { ms: p.bestLap, car: p.spec.name, date: Date.now() };
      flags.lap = true;
    }
    if (p.finished) {
      r.race = r.race || {};
      const prev = r.race[race.laps];
      if (!prev || p.finishTime < prev.ms) {
        r.race[race.laps] = { ms: p.finishTime, car: p.spec.name, date: Date.now() };
        flags.race = true;
      }
    }
    store.set('records', rec);
    return flags;
  }

  /* ================= Som ================= */
  function syncSoundButtons() {
    for (const id of ['#toggle-music', '#pause-music']) $(id).setAttribute('aria-pressed', String(audio.musicOn));
    for (const id of ['#toggle-sfx', '#pause-sfx']) $(id).setAttribute('aria-pressed', String(audio.sfxOn));
  }
  function toggleMusic() {
    audio.setMusic(!audio.musicOn);
    if (game && audio.musicOn && audio.ctx) audio.startMusic();
    syncSoundButtons();
  }
  function toggleSfx() {
    audio.setSfx(!audio.sfxOn);
    syncSoundButtons();
  }

  /* ================= Vitrine (corrida de demonstração no topo) ================= */
  const hero = { race: null, renderer: null, raf: 0, last: 0, visible: true, trackIdx: 0, towerT: 0 };

  function newHeroRace() {
    const track = tracks[hero.trackIdx % tracks.length];
    hero.trackIdx++;
    hero.race = new APX.Race({ track, laps: 3, attract: true, opponents: 6, difficulty: 'dificil', featured: use3D ? APX.CARS.find((c) => c.model) : null });
    // pula a largada parada para a vitrine já abrir em movimento
    for (let i = 0; i < 120 * 6; i++) hero.race.step(APX.RACE_DT, null);
    hero.race.events.length = 0;
    hero.race.particles.length = 0;
    const f = hero.race.focusCar();
    hero.race.cam.x = f.x;
    hero.race.cam.y = f.y;
    $('#tower-track').textContent = track.name;
  }

  function heroFrame(ts) {
    hero.raf = 0;
    if (!hero.renderer || game) return;
    const dt = hero.last ? Math.min(0.05, (ts - hero.last) / 1000) : 1 / 60;
    hero.last = ts;
    const r = hero.race;
    r.update(dt, null);
    r.events.length = 0;
    hero.renderer.draw(r, dt, { reducedMotion: reduced });
    hero.towerT -= dt;
    if (hero.towerT <= 0) { hero.towerT = 0.5; updateHeroTower(); }
    if (r.state === 'finished' || (r.state === 'finishing' && r.clock - r.finishClock > 6)) newHeroRace();
    if (hero.visible && !document.hidden && !reduced) hero.raf = requestAnimationFrame(heroFrame);
  }

  function updateHeroTower() {
    const r = hero.race;
    const st = r.standings();
    const lead = st[0];
    $('#tower-lap').textContent = `V ${clamp(Math.max(1, lead.lap), 1, r.laps)}/${r.laps}`;
    renderTower($('#tower-list'), r, st, 7);
  }

  function renderTower(list, r, st, max) {
    const rows = st.slice(0, max);
    if (list.children.length !== rows.length) {
      list.innerHTML = rows.map(() => '<li><span class="t-pos"></span><span class="t-sw"></span><span class="t-name"></span><span class="t-gap"></span></li>').join('');
    }
    rows.forEach((c, i) => {
      const li = list.children[i];
      li.classList.toggle('me', !!c.isPlayer);
      li.children[0].textContent = i + 1;
      li.children[1].style.background = c.paint;
      li.children[2].textContent = c.isPlayer ? (c.name || 'Você').toUpperCase() : shortName(c.name);
      let gap;
      if (i === 0) gap = c.finished ? 'FIM' : 'LÍDER';
      else if (c.finished && st[0].finished) gap = fmtGap(c.finishTime - st[0].finishTime);
      else if (st[0].progress - c.progress > r.track.N) gap = '+' + Math.floor((st[0].progress - c.progress) / r.track.N) + 'V';
      else gap = c.gap != null ? fmtGap(c.gap * 1000).replace(/(\.\d)\d\d$/, '$1') : '';
      li.children[3].textContent = gap;
      li.children[3].classList.toggle('lead', i === 0);
    });
  }

  function startHero() {
    if (!hero.renderer) {
      if (use3D) {
        try {
          const c3 = $('#hero-canvas-3d');
          c3.hidden = false;
          hero.renderer = new APX.Renderer3D(c3);
          $('#hero-canvas').hidden = true;
        } catch (err) {
          $('#hero-canvas-3d').hidden = true;
          hero.renderer = null;
        }
      }
      if (!hero.renderer) hero.renderer = new APX.Renderer($('#hero-canvas'));
      newHeroRace();
    }
    hero.renderer.resize();
    if (reduced) {
      hero.renderer.draw(hero.race, 0, { reducedMotion: true });
      updateHeroTower();
      return;
    }
    if (!hero.raf && hero.visible && !game) {
      hero.last = 0;
      hero.raf = requestAnimationFrame(heroFrame);
    }
  }

  function stopHero() {
    if (hero.raf) cancelAnimationFrame(hero.raf);
    hero.raf = 0;
  }

  /* ================= Corrida ================= */
  let game = null;
  let renderer = null; // 2D (vista de cima + minimapa)
  let renderer3d = null;

  function activeRenderer() {
    return renderer3d && state.camera !== 'top' ? renderer3d : renderer;
  }

  function applyCamera() {
    const is3d = !!renderer3d && state.camera !== 'top';
    $('#game-canvas-3d').hidden = !is3d;
    $('#game-canvas').hidden = is3d;
    if (renderer3d) renderer3d.camMode = state.camera;
    activeRenderer().resize();
  }

  function cycleCamera() {
    const order = renderer3d ? ['chase', 'high', 'top'] : ['top'];
    state.camera = order[(order.indexOf(state.camera) + 1) % order.length];
    save();
    if (game) {
      applyCamera();
      toast(CAM_LABEL[state.camera], 'small', 900);
    }
  }

  function buildGaugeTicks() {
    const g = $('#gauge-ticks');
    const max = 300;
    let html = '';
    for (let v = 0; v <= max; v += 50) {
      const t = v / max;
      const a = ((135 + t * 270) * Math.PI) / 180;
      const x1 = 100 + Math.cos(a) * 66, y1 = 100 + Math.sin(a) * 66;
      const x2 = 100 + Math.cos(a) * 58, y2 = 100 + Math.sin(a) * 58;
      const tx = 100 + Math.cos(a) * 99, ty = 100 + Math.sin(a) * 99;
      html += `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}"/>`;
      if (v % 100 === 0) html += `<text x="${tx.toFixed(1)}" y="${ty.toFixed(1)}">${v}</text>`;
    }
    g.innerHTML = html;
  }

  function startRace() {
    audio.init();
    audio.loadSamples('assets/audio/');
    const track = trackById(state.trackId);
    const spec = carById(state.carId);
    const race = new APX.Race({
      track,
      laps: state.laps,
      difficulty: state.difficulty,
      opponents: state.opponents,
      player: { spec, paint: state.paint, name: state.name || 'Você' },
    });
    const gameEl = $('#game');
    gameEl.hidden = false;
    document.body.classList.add('racing');
    input.capture = true;
    input.clear();
    stopHero();
    if (!renderer) renderer = new APX.Renderer($('#game-canvas'));
    if (use3D && !renderer3d) {
      try {
        $('#game-canvas-3d').hidden = false;
        renderer3d = new APX.Renderer3D($('#game-canvas-3d'));
      } catch (err) {
        renderer3d = null;
      }
    }
    if (!renderer3d && state.camera !== 'top') state.camera = 'top';
    applyCamera();
    game = {
      race, last: 0, raf: 0, paused: false, resultsShown: false, finishAt: null,
      hudT: 0, perf: [], toastT: 0, lights: 0, flags: null,
    };
    $('#pause').hidden = true;
    $('#results').hidden = true;
    $('#toasts').innerHTML = '';
    $('#wrong').hidden = true;
    const lights = $('#lights');
    lights.className = 'lights';
    $$('span', lights).forEach((s) => s.classList.remove('on'));
    $('#hud-total').textContent = '/' + race.cars.length;
    $('#hud-best').className = '';
    audio.startEngine();
    if (audio.musicOn) audio.startMusic();
    (renderer3d && state.camera !== 'top' ? $('#game-canvas-3d') : $('#game-canvas')).focus({ preventScroll: true });
    game.raf = requestAnimationFrame(frame);
  }

  function restartRace() {
    endRace(true);
    startRace();
  }

  function endRace(keepOverlay) {
    if (!game) return;
    cancelAnimationFrame(game.raf);
    game = null;
    audio.stopEngine();
    audio.stopMusic();
    input.capture = false;
    if (!keepOverlay) {
      $('#game').hidden = true;
      document.body.classList.remove('racing');
      if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
      renderRecords();
      buildTracks();
      startHero();
    }
  }

  function setPaused(p) {
    if (!game || game.resultsShown) return;
    game.paused = p;
    $('#pause').hidden = !p;
    if (p) {
      audio.updateEngine(0, 0, 0, 0, false);
      if (audio.engine) audio.engine.out.gain.setTargetAtTime(0, audio.ctx.currentTime, 0.05);
      $('#btn-resume').focus();
    } else {
      game.last = 0;
      (renderer3d && state.camera !== 'top' ? $('#game-canvas-3d') : $('#game-canvas')).focus({ preventScroll: true });
    }
  }

  function frame(ts) {
    if (!game) return;
    const g = game;
    const dt = g.last ? Math.min(0.05, (ts - g.last) / 1000) : 1 / 60;
    g.last = ts;

    // teclas de sistema
    if (input.consume('Escape') || input.consume('KeyP') || input.consume('PadStart')) {
      if (!g.resultsShown) setPaused(!g.paused);
    }
    if (input.consume('KeyR') || input.consume('PadBack')) { restartRace(); return; }
    if (input.consume('KeyM')) toggleMusic();
    if (input.consume('KeyC')) cycleCamera();
    if (g.resultsShown && (input.consume('Enter') || input.consume('PadA'))) { restartRace(); return; }

    const ctl = input.read();
    if (!g.paused) g.race.update(dt, ctl);
    activeRenderer().draw(g.race, g.paused ? 0 : dt, { reducedMotion: reduced });
    if (!game) return;
    updateHud(dt);
    drainEvents();
    adaptQuality(dt);
    game.raf = requestAnimationFrame(frame);
  }

  function adaptQuality(dt) {
    const g = game;
    g.perf.push(dt);
    if (g.perf.length < 120) return;
    const avg = g.perf.reduce((a, b) => a + b, 0) / g.perf.length;
    g.perf.length = 0;
    const ar = activeRenderer();
    if (avg > 1 / 42 && ar.quality !== 'low') {
      ar.setQuality(ar.quality === 'high' ? 'mid' : 'low');
    }
  }

  function updateHud(dt) {
    const g = game, r = g.race, p = r.player;
    const st = r.standings();
    const pos = st.indexOf(p) + 1;
    setText('#hud-pos', pos);
    setText('#hud-lap', `${clamp(Math.max(1, p.lap), 1, r.laps)}/${r.laps}`);
    setText('#hud-time', fmtTime(r.time * 1000));
    setText('#hud-cur', p.lapStart != null && !p.finished ? fmtTime((r.time - p.lapStart) * 1000) : p.finished ? fmtTime(p.lastLap) : '-:--.---');
    setText('#hud-best', fmtTime(p.bestLap));
    const kmh = Math.round(p.speed * KMH);
    setText('#hud-speed', kmh);
    setText('#hud-gear', r.state === 'countdown' ? 'N' : p.vf < -5 ? 'R' : p.gear + 'ª');
    const fill = $('#gauge-fill');
    fill.style.strokeDashoffset = String(100 - clamp(kmh / 300, 0, 1) * 100);
    $('.gauge').classList.toggle('nitro-on', p.nitroOn || p.boostT > 0);
    const nb = $('#hud-nitro');
    nb.style.width = (p.nitro * 100).toFixed(1) + '%';
    nb.classList.toggle('full', p.nitro > 0.98);
    $('#wrong').hidden = !(p.wrongT > 0.8 && r.state === 'racing');

    // semáforo
    const lights = $('#lights');
    if (r.state === 'countdown') {
      const lit = r.countdown > 3 ? 0 : r.countdown > 2 ? 1 : r.countdown > 1 ? 2 : 3;
      if (lit !== g.lights) {
        g.lights = lit;
        $$('span', lights).forEach((s, i) => s.classList.toggle('on', i < lit));
      }
    } else if (!lights.classList.contains('out')) {
      if (!lights.classList.contains('go')) {
        lights.classList.add('go');
        setTimeout(() => lights.classList.add('out'), 900);
      }
    }

    g.hudT -= dt;
    if (g.hudT <= 0) {
      g.hudT = 0.25;
      renderTower($('#hud-tower'), r, st, Math.min(8, st.length));
      renderer.drawMinimap(r, $('#minimap'));
      if (g.resultsShown) fillResults();
    } else {
      renderer.drawMinimap(r, $('#minimap'));
    }

    // som do motor
    if (!g.paused) {
      audio.updateEngine(p.rpm, r.state === 'countdown' ? (p.revving ? 0.8 : 0) : p.gas, clamp(p.speed / p.spec.maxSpeed, 0, 1),
        clamp((p.slip - 70) / 200, 0, 1) * (p.surface === 'runoff' ? 0.3 : 1), p.surface === 'runoff' && p.speed > 60);
    }

    if (g.finishAt != null && !g.resultsShown && performance.now() > g.finishAt) showResults();
  }

  const textCache = new Map();
  function setText(sel, v) {
    const s = String(v);
    if (textCache.get(sel) === s) return;
    textCache.set(sel, s);
    $(sel).textContent = s;
  }

  function toast(html, cls, ms) {
    const box = $('#toasts');
    const el = document.createElement('div');
    el.className = 'toast ' + (cls || '');
    el.innerHTML = html;
    box.appendChild(el);
    while (box.children.length > 3) box.firstChild.remove();
    setTimeout(() => {
      el.classList.add('out');
      setTimeout(() => el.remove(), 320);
    }, ms || 1500);
  }

  function drainEvents() {
    const r = game.race;
    const p = r.player;
    const focus = p;
    for (const e of r.events) {
      switch (e.type) {
        case 'light': audio.beep(440, 0.22, 0.14); break;
        case 'go':
          audio.beep(880, 0.5, 0.16);
          audio.playSample('aceleracao', 1.5, 0.84, audio.engineBus);
          toast('VAI!', 'go', 900);
          break;
        case 'crash': {
          const d = Math.hypot(e.car.x - focus.x, e.car.y - focus.y);
          if (d < 700) audio.crash(e.power * (e.car === p ? 1 : 0.5 * (1 - d / 700)));
          break;
        }
        case 'bump': if (e.car === p) audio.crash(e.power * 0.6); break;
        case 'nitro': if (e.car === p) audio.whoosh(1); break;
        case 'boost':
          if (e.car === p) { audio.whoosh(1.3); toast('TURBO', 'volt small', 700); }
          break;
        case 'drift':
          if (e.car === p && e.secs > 1.2) toast(`DRIFT ${e.secs.toFixed(1).replace('.', ',')} s<small>+ nitro</small>`, 'volt small', 1100);
          break;
        case 'lap':
          if (e.car === p && e.lap < r.laps) {
            const cls = e.overallBest ? 'best' : e.personalBest ? 'pb' : '';
            const tag = e.overallBest ? 'melhor volta da corrida' : e.personalBest ? 'sua melhor volta' : 'volta ' + e.lap;
            toast(`${fmtTime(e.lapTime)}<small>${tag}</small>`, cls, 1800);
            audio.chime(e.personalBest);
            const hb = $('#hud-best');
            hb.className = e.overallBest ? 'ob' : 'pb';
          }
          break;
        case 'final-lap':
          if (e.car === p) { toast('Última volta', 'signal', 1600); audio.beep(660, 0.12, 0.1); setTimeout(() => audio.beep(660, 0.12, 0.1), 160); }
          break;
        case 'finish':
          if (e.car === p) {
            game.flags = saveRecords(r);
            toast(`${e.place}º lugar<small>bandeira quadriculada</small>`, e.place === 1 ? 'pb' : 'signal', 2200);
            if (!audio.playSample('torcida', 0.8, 1)) audio.chime(true);
            game.finishAt = performance.now() + 2200;
          }
          break;
        case 'all-finished':
          if (game.resultsShown) fillResults();
          break;
        default: break;
      }
    }
    r.events.length = 0;
  }

  function showResults() {
    const g = game, r = g.race;
    g.resultsShown = true;
    $('#results-track').textContent = `${r.track.name} · ${r.laps} ${r.laps === 1 ? 'volta' : 'voltas'} · IA ${r.diff.label.toLowerCase()}`;
    $('#results-place').textContent = r.player.place + 'º';
    const f = g.flags || {};
    const notes = [];
    if (f.lap) notes.push(`<b>Novo recorde de volta</b> no circuito: ${fmtTime(r.player.bestLap)}`);
    if (f.race) notes.push(`Melhor corrida de ${r.laps} ${r.laps === 1 ? 'volta' : 'voltas'}: ${fmtTime(r.player.finishTime)}`);
    $('#results-note').innerHTML = notes.join(' · ') || `Tempo total ${fmtTime(r.player.finishTime)} · melhor volta ${fmtTime(r.player.bestLap)}`;
    fillResults();
    $('#results').hidden = false;
    $('#btn-again').focus();
  }

  function fillResults() {
    const r = game.race;
    const st = r.standings();
    const winner = st[0];
    const raceBest = Math.min(...r.cars.map((c) => (c.bestLap == null ? Infinity : c.bestLap)));
    $('#results-body').innerHTML = st.map((c, i) => {
      let t;
      if (c.finished) t = i === 0 ? fmtTime(c.finishTime) : fmtGap(c.finishTime - winner.finishTime);
      else {
        const behind = Math.floor((winner.progress - c.progress) / r.track.N);
        t = `<span class="running">${behind >= 1 ? '+' + behind + ' volta' + (behind > 1 ? 's' : '') : 'em pista'}</span>`;
      }
      const bl = c.bestLap != null ? `<span class="${c.bestLap === raceBest ? 'ob' : ''}">${fmtTime(c.bestLap)}</span>` : '—';
      return `<tr class="${c.isPlayer ? 'me' : ''}"><td class="pos">${i + 1}</td><td><span class="sw" style="background:${c.paint}"></span>${c.isPlayer ? (c.name || 'Você') : c.name}</td><td>${c.spec.name}</td><td class="mono">${t}</td><td class="mono">${bl}</td></tr>`;
    }).join('');
  }

  /* ================= Toque ================= */
  function setupTouch() {
    const enable = () => document.body.classList.add('is-touch');
    if (window.matchMedia && matchMedia('(pointer: coarse)').matches) enable();
    window.addEventListener('touchstart', enable, { once: true, passive: true });
    for (const b of $$('#touch button')) {
      const k = b.dataset.k;
      const on = (e) => { e.preventDefault(); input.touch[k] = 1; b.classList.add('on'); try { b.setPointerCapture(e.pointerId); } catch (err) { /* ok */ } };
      const off = (e) => { e.preventDefault(); input.touch[k] = 0; b.classList.remove('on'); };
      b.addEventListener('pointerdown', on);
      b.addEventListener('pointerup', off);
      b.addEventListener('pointercancel', off);
      b.addEventListener('lostpointercapture', off);
      b.addEventListener('contextmenu', (e) => e.preventDefault());
    }
  }

  /* ================= Inicialização ================= */
  function wire() {
    $('#hero-race').addEventListener('click', startRace);
    $('#top-race').addEventListener('click', startRace);
    $('#toggle-music').addEventListener('click', () => { audio.init(); audio.loadSamples('assets/audio/'); toggleMusic(); });
    $('#toggle-sfx').addEventListener('click', () => { audio.init(); audio.loadSamples('assets/audio/'); toggleSfx(); });
    $('#pause-music').addEventListener('click', toggleMusic);
    $('#pause-sfx').addEventListener('click', toggleSfx);
    $('#hud-pause').addEventListener('click', () => setPaused(true));
    $('#hud-camera').addEventListener('click', cycleCamera);
    $('#btn-resume').addEventListener('click', () => setPaused(false));
    $('#btn-restart').addEventListener('click', restartRace);
    $('#btn-exit').addEventListener('click', () => endRace(false));
    $('#btn-again').addEventListener('click', restartRace);
    $('#btn-menu').addEventListener('click', () => { endRace(false); window.scrollTo({ top: 0 }); });
    $('#btn-tracks').addEventListener('click', () => {
      endRace(false);
      $('#pistas').scrollIntoView({ block: 'start' });
    });
    $('#hud-fullscreen').addEventListener('click', () => {
      const el = $('#game');
      if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
      else if (el.requestFullscreen) el.requestFullscreen().catch(() => {});
    });
    window.addEventListener('resize', () => {
      if (game) activeRenderer().resize();
      if (hero.renderer) { hero.renderer.resize(); if (reduced) hero.renderer.draw(hero.race, 0, { reducedMotion: true }); }
      syncGarage();
      syncTracks();
    });
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        if (game && !game.paused && !game.resultsShown) setPaused(true);
        stopHero();
      } else if (!game) startHero();
    });
    if ('IntersectionObserver' in window) {
      new IntersectionObserver((ents) => {
        hero.visible = ents[0].isIntersecting;
        if (hero.visible) startHero(); else stopHero();
      }).observe($('#inicio'));
    }
    window.addEventListener('keydown', (e) => {
      if (!game && e.code === 'KeyM' && !(e.target instanceof HTMLInputElement)) { audio.init(); toggleMusic(); }
    });
  }

  function boot() {
    buildPaints();
    buildGarage();
    buildTracks();
    buildSetup();
    renderRecords();
    buildGaugeTicks();
    setupTouch();
    syncSoundButtons();
    wire();
    startHero();
    if (use3D && APX.loadCarModel) {
      const mc = APX.CARS.find((c) => c.model);
      if (mc) APX.loadCarModel(mc.model).then(() => syncGarage());
    }
    const total = tracks.reduce((a, t) => a + t.lengthM, 0);
    $('#footer-meta').textContent = `Física a 120 Hz · ${tracks.length} circuitos · ${total.toLocaleString('pt-BR')} m de asfalto`;
  }

  // gancho de inspeção (testes automatizados e console)
  APX.debug = { get game() { return game; }, get hero() { return hero; }, get r3d() { return renderer3d; }, state };

  // espera as fontes para os números dos carros e textos do canvas saírem certos
  const ready = document.fonts && document.fonts.ready ? Promise.race([document.fonts.ready, new Promise((r) => setTimeout(r, 1500))]) : Promise.resolve();
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => ready.then(boot));
  else ready.then(boot);
})(APX);
