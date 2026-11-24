/* Ápice Racing — simulação: física, IA, voltas, colisões, partículas e câmera */
'use strict';
(function (APX) {
  const { clamp, lerp, approach, wrapAngle, damp, mulberry32 } = APX.util;
  const { nearest, lateral, profileFor } = APX.trackFns;

  const DT = 1 / 120;

  const DIFFICULTY = {
    facil: { label: 'Fácil', skill: 0.8, aggr: 0.25 },
    medio: { label: 'Médio', skill: 0.89, aggr: 0.5 },
    dificil: { label: 'Difícil', skill: 0.96, aggr: 0.75 },
    insano: { label: 'Insano', skill: 1.02, aggr: 1 },
  };

  const DRIVERS = ['Rafa Lima', 'Bia Torres', 'Dudu Prado', 'Lia Moraes', 'Caio Nunes', 'Nina Sato', 'Téo Vidal', 'Malu Reis', 'Juca Melo'];
  const AI_PAINTS = ['#2F6BFF', '#22C98A', '#FFC23A', '#E9EDF5', '#C42A4A', '#8B5CFF', '#FF6A1F', '#3A4154', '#38E1FF'];

  const MAX_SKIDS = 2600;
  const MAX_PARTICLES = 1100;

  class Race {
    constructor(opts) {
      this.track = opts.track;
      this.laps = opts.laps || 3;
      this.attract = !!opts.attract;
      this.diff = DIFFICULTY[opts.difficulty] || DIFFICULTY.medio;
      this.rng = mulberry32(opts.seed || ((Math.random() * 1e9) | 0));
      this.state = this.attract ? 'racing' : 'countdown';
      this.countdown = this.attract ? 0 : 3.8;
      this.time = 0;
      this.clock = 0;
      this.acc = 0;
      this.cars = [];
      this.events = [];
      this.particles = [];
      this.skids = new Float32Array(MAX_SKIDS * 5);
      this.skidHead = 0;
      this.skidCount = 0;
      this.cam = { x: 0, y: 0, zoom: 1, shake: 0, vx: 0, vy: 0 };
      this.passTimes = new Map();
      this.finishOrder = [];
      this.player = null;
      this.lastLight = 4;

      const opponents = opts.opponents != null ? opts.opponents : 5;
      const total = this.attract ? opponents : opponents + 1;
      const playerSlot = this.attract ? -1 : Math.min(total - 1, Math.max(0, total - 2));
      const names = DRIVERS.slice();
      const paints = AI_PAINTS.filter((p) => !opts.player || p.toLowerCase() !== opts.player.paint.toLowerCase());
      for (let s = 0; s < total; s++) {
        let car;
        if (s === playerSlot) {
          car = this.makeCar(opts.player.spec, opts.player.paint, opts.player.name || 'Você', true);
          this.player = car;
        } else {
          const spec = APX.CARS[Math.floor(this.rng() * APX.CARS.length)];
          const name = names.splice(Math.floor(this.rng() * names.length), 1)[0];
          const paint = paints[(s + Math.floor(this.rng() * 3)) % paints.length];
          car = this.makeCar(spec, paint, name, false);
        }
        this.placeOnGrid(car, s);
        this.cars.push(car);
      }
      // câmera começa no foco
      const f = this.focusCar();
      this.cam.x = f.x;
      this.cam.y = f.y;
      this.cam.zoom = this.attract ? 0.62 : 0.95;
    }

    makeCar(spec, paint, name, isPlayer) {
      const r = this.rng;
      return {
        spec, paint, name, isPlayer,
        x: 0, y: 0, a: 0, vx: 0, vy: 0, av: 0,
        steer: 0, gas: 0, brake: 0, hand: false,
        nitro: 0.6, nitroOn: false, boostT: 0,
        idx: 0, prevIdx: 0, lap: 0, maxLap: 0, halfway: false,
        lapStart: null, lapTimes: [], bestLap: null, lastLap: null,
        finished: false, finishTime: null, place: 0,
        slip: 0, speed: 0, vf: 0, surface: 'asphalt', onIce: false,
        wrongT: 0, rpm: 0, gear: 1, shiftT: 0,
        skidL: null, skidR: null,
        stuckT: 0, reverseT: 0,
        auto: !isPlayer,
        ai: {
          skill: this.diff.skill * (0.97 + r() * 0.05),
          bias: (r() - 0.5) * 0.24 * this.track.hw,
          laneT: r() * 10, laneSpeed: 0.25 + r() * 0.3,
          avoid: 0, nitroWant: false, rubber: 1,
        },
      };
    }

    placeOnGrid(car, slot) {
      const tr = this.track, N = tr.N;
      const back = 70 + slot * 46;
      const i = (N - Math.round(back / tr.ds)) % N;
      const side = slot % 2 === 0 ? -1 : 1;
      const off = side * tr.hw * 0.42;
      car.x = tr.xs[i] + tr.nx[i] * off;
      car.y = tr.ys[i] + tr.ny[i] * off;
      car.a = tr.ang[i];
      car.idx = i;
      car.prevIdx = i;
      car.gridIdx = i;
      car.gridOff = off;
    }

    focusCar() {
      if (this.player && !this.attract) return this.player;
      const st = this.standings();
      return st[0];
    }

    /* ---------- Loop ---------- */
    update(frameDt, input) {
      frameDt = Math.min(frameDt, 0.1);
      this.acc += frameDt;
      let steps = 0;
      while (this.acc >= DT && steps < 12) {
        this.step(DT, input);
        this.acc -= DT;
        steps++;
      }
      if (steps >= 12) this.acc = 0;
      this.updateParticles(frameDt);
      this.updateCamera(frameDt);
    }

    step(dt, input) {
      this.clock += dt;
      if (this.state === 'countdown') {
        const before = this.countdown;
        this.countdown -= dt;
        const light = Math.ceil(this.countdown);
        if (light !== this.lastLight && light >= 0 && light <= 3) {
          this.lastLight = light;
          if (light >= 1) this.events.push({ type: 'light', n: light });
        }
        if (before > 0 && this.countdown <= 0) {
          this.state = 'racing';
          this.events.push({ type: 'go' });
        }
      } else {
        this.time += dt;
      }

      for (const car of this.cars) {
        let ctl;
        if (car.auto) ctl = this.aiControl(car, dt);
        else ctl = input || { steer: 0, gas: 0, brake: 0, nitro: false, hand: false };
        this.updateCar(car, ctl, dt);
      }
      this.collideCars();
      for (const car of this.cars) this.updateProgress(car, dt);

      // termina a corrida quando todos chegam ou depois de um tempo
      if (this.state === 'racing' || this.state === 'finishing') {
        const pending = this.cars.filter((c) => !c.finished).length;
        if (this.attract) {
          if (this.cars.some((c) => c.finished) && this.state !== 'finishing') {
            this.state = 'finishing';
            this.finishClock = this.clock;
          }
        } else if (this.player.finished && this.state !== 'finishing') {
          this.state = 'finishing';
          this.finishClock = this.clock;
        }
        if (this.state === 'finishing' && (pending === 0 || this.clock - this.finishClock > 40)) {
          this.state = 'finished';
          this.events.push({ type: 'all-finished' });
        }
      }
    }

    /* ---------- Física ---------- */
    surfaceAt(car) {
      const tr = this.track;
      const d = lateral(tr, car.idx, car.x, car.y);
      car.latOff = d;
      let s = { grip: tr.theme.grip, drag: 0, maxMul: 1, kind: 'asphalt' };
      if (Math.abs(d) > tr.hw + 2) {
        const r = tr.theme.runoff;
        s = { grip: r.grip, drag: r.drag, maxMul: r.maxMul, kind: 'runoff' };
      } else {
        for (const ic of tr.ice) {
          const dx = car.x - ic.x, dy = car.y - ic.y;
          if (dx * dx + dy * dy < ic.r * ic.r) { s = { grip: 0.34, drag: 0, maxMul: 1, kind: 'ice' }; break; }
        }
      }
      return s;
    }

    updateCar(car, ctl, dt) {
      const spec = car.spec;
      const racing = this.state !== 'countdown';
      const surf = this.surfaceAt(car);
      car.surface = surf.kind;

      // entradas suavizadas (teclado digital vira rampa)
      if (ctl.analog) car.steer = ctl.steer;
      else car.steer = approach(car.steer, ctl.steer, (Math.sign(ctl.steer) !== Math.sign(car.steer) ? 9 : 5.5) * dt);
      car.gas = racing ? ctl.gas : 0;
      car.brake = racing ? ctl.brake : 0;
      car.hand = racing && !!ctl.hand;
      car.revving = !racing && ctl.gas > 0;

      const fx = Math.cos(car.a), fy = Math.sin(car.a);
      let vf = car.vx * fx + car.vy * fy;
      let vl = -car.vx * fy + car.vy * fx;

      // nitro
      const wantNitro = racing && ctl.nitro && car.nitro > 0.02 && vf > 40;
      if (wantNitro && !car.nitroOn) this.events.push({ type: 'nitro', car });
      car.nitroOn = wantNitro;
      if (car.nitroOn) car.nitro = Math.max(0, car.nitro - dt / (2.4 * spec.nitro));
      else car.nitro = Math.min(1, car.nitro + dt * 0.018);
      if (car.boostT > 0) car.boostT -= dt;

      const rubber = car.auto && !car.isPlayer ? car.ai.rubber : 1;
      const skill = car.auto && !car.isPlayer ? car.ai.skill : 1;
      const boostMul = (car.nitroOn ? 1.24 : 1) * (car.boostT > 0 ? 1.18 : 1);
      const maxSpeed = spec.maxSpeed * surf.maxMul * boostMul * (car.isPlayer ? 1 : Math.min(1.06, skill + 0.04) * rubber);

      if (car.gas > 0) {
        if (vf >= -20) {
          const ratio = clamp(vf / maxSpeed, 0, 1.2);
          const a = spec.accel * car.gas * (1 - ratio * ratio * 0.92) * (car.isPlayer ? 1 : 0.92 + skill * 0.08) / spec.mass * Math.sqrt(spec.mass);
          vf += Math.max(a, -200) * dt;
        } else {
          vf += 1100 * car.gas * dt; // ré → freia
        }
      }
      if (car.brake > 0) {
        if (vf > 15) vf -= 980 * car.brake * surf.grip * dt;
        else vf = Math.max(vf - spec.accel * 0.55 * car.brake * dt, -spec.maxSpeed * 0.28);
      }
      if (car.nitroOn) vf += spec.accel * 0.75 * dt;
      if (car.boostT > 0) vf += spec.accel * 0.55 * dt;
      if (car.hand) vf -= Math.sign(vf) * Math.min(Math.abs(vf), 220 * dt);

      // arrasto
      vf -= vf * (0.18 + surf.drag) * dt;
      if (vf > maxSpeed) vf = lerp(vf, maxSpeed, 1 - Math.exp(-2.2 * dt));
      if (car.gas === 0 && car.brake === 0 && Math.abs(vf) < 6) vf = 0;

      // direção
      const sp = Math.abs(vf);
      const sf = clamp(sp / 170, 0, 1) * (1 - 0.35 * clamp(sp / spec.maxSpeed, 0, 1.1));
      const dir = vf >= 0 ? 1 : -1;
      let yawT = car.steer * spec.turn * sf * dir * (car.hand ? 1.4 : 1);
      if (surf.kind === 'ice') yawT *= 0.8;
      car.av = damp(car.av, yawT, surf.kind === 'ice' ? 4 : 11, dt);
      car.a = wrapAngle(car.a + car.av * dt);

      // aderência lateral
      let grip = spec.grip * surf.grip * (car.hand ? 0.22 : 1);
      if (car.isPlayer === false) grip *= 1.05;
      const vlBefore = vl;
      vl *= Math.exp(-grip * dt);
      // derrapagem rouba velocidade
      vf -= Math.abs(vlBefore - vl) * 0.12;

      car.vx = fx * vf - fy * vl;
      car.vy = fy * vf + fx * vl;
      car.slip = Math.abs(vl);
      car.vf = vf;
      car.speed = Math.hypot(car.vx, car.vy);

      // drift recarrega nitro
      if (car.slip > 110 && sp > 220 && surf.kind === 'asphalt') {
        car.nitro = Math.min(1, car.nitro + dt * 0.11);
        car.driftCharge = (car.driftCharge || 0) + dt;
      } else if (car.driftCharge) {
        if (car.driftCharge > 1 && car.isPlayer) this.events.push({ type: 'drift', car, secs: car.driftCharge });
        car.driftCharge = 0;
      }

      if (racing) {
        car.x += car.vx * dt;
        car.y += car.vy * dt;
      }

      // marcha e giro do motor
      const s01 = clamp(Math.abs(vf) / (spec.maxSpeed * 1.08), 0, 1);
      const G = [0, 0.16, 0.32, 0.48, 0.63, 0.78, 1.0];
      let gear = 1;
      while (gear < 6 && s01 > G[gear]) gear++;
      if (gear !== car.gear) { car.shiftT = 0.12; car.gear = gear; }
      car.shiftT = Math.max(0, car.shiftT - dt);
      const lo = G[gear - 1], hi = G[gear];
      let rpm = 0.25 + 0.75 * clamp((s01 - lo) / (hi - lo), 0, 1);
      if (!racing) rpm = car.revving ? 0.55 + Math.sin(this.clock * 23) * 0.05 + 0.2 : 0.2;
      if (car.shiftT > 0) rpm *= 0.88;
      if (car.slip > 140 && car.gas > 0) rpm = Math.min(1, rpm + 0.1);
      car.rpm = damp(car.rpm, vf < -5 ? 0.45 : rpm, 14, dt);

      this.trackConstraint(car, dt);
      this.surfaceEffects(car, surf, dt);
    }

    trackConstraint(car, dt) {
      const tr = this.track;
      car.prevIdx = car.idx;
      car.idx = nearest(tr, car.x, car.y, car.idx);
      const i = car.idx;
      const d = lateral(tr, i, car.x, car.y);
      const lim = tr.wall - 13;
      if (Math.abs(d) > lim) {
        const s = Math.sign(d);
        const nx = tr.nx[i] * s, ny = tr.ny[i] * s;
        const pen = Math.abs(d) - lim;
        car.x -= nx * pen;
        car.y -= ny * pen;
        const vn = car.vx * nx + car.vy * ny;
        if (vn > 0) {
          car.vx -= nx * vn * 1.35;
          car.vy -= ny * vn * 1.35;
          // atrito do muro
          car.vx *= 0.965;
          car.vy *= 0.965;
          car.av *= 0.6;
          if (vn > 50) {
            const power = clamp(vn / 420, 0, 1);
            this.events.push({ type: 'crash', car, power });
            if (car === this.focusCar()) this.cam.shake = Math.max(this.cam.shake, power * 12);
            const px = car.x + nx * 12, py = car.y + ny * 12;
            for (let k = 0; k < 6 + power * 18; k++) {
              this.spawn('spark', px, py,
                car.vx * 0.3 + (this.rng() - 0.5) * 260 - nx * this.rng() * 180,
                car.vy * 0.3 + (this.rng() - 0.5) * 260 - ny * this.rng() * 180,
                0.25 + this.rng() * 0.35, 2);
            }
          }
        } else if (car.speed > 120 && this.rng() < 0.3) {
          // raspando no muro
          this.spawn('spark', car.x + nx * 12, car.y + ny * 12, car.vx * 0.5, car.vy * 0.5, 0.2, 2);
        }
      }
    }

    surfaceEffects(car, surf, dt) {
      const r = this.rng;
      const c = Math.cos(car.a), s = Math.sin(car.a);
      const rearX = car.x - c * 14, rearY = car.y - s * 14;
      // marcas de pneu
      const marking = surf.kind !== 'runoff' && car.speed > 60 && (car.slip > 95 || (car.brake > 0.5 && car.vf > 260) || (car.hand && car.speed > 120));
      const wl = [rearX + s * 9, rearY - c * 9];
      const wr = [rearX - s * 9, rearY + c * 9];
      if (marking) {
        const alpha = clamp((car.slip - 60) / 260, 0.18, 0.55) * (surf.kind === 'ice' ? 0.4 : 1);
        if (car.skidL) this.addSkid(car.skidL[0], car.skidL[1], wl[0], wl[1], alpha);
        if (car.skidR) this.addSkid(car.skidR[0], car.skidR[1], wr[0], wr[1], alpha);
        car.skidL = wl;
        car.skidR = wr;
        if (r() < 0.55 && surf.kind === 'asphalt') {
          this.spawn('smoke', rearX + (r() - 0.5) * 12, rearY + (r() - 0.5) * 12,
            car.vx * 0.12 + (r() - 0.5) * 30, car.vy * 0.12 + (r() - 0.5) * 30, 0.9 + r() * 0.8, 10 + r() * 8);
        }
      } else {
        car.skidL = null;
        car.skidR = null;
      }
      // poeira fora da pista
      if (surf.kind === 'runoff' && car.speed > 70 && r() < 0.7) {
        this.spawn('dust', rearX + (r() - 0.5) * 16, rearY + (r() - 0.5) * 16,
          -car.vx * 0.1 + (r() - 0.5) * 60, -car.vy * 0.1 + (r() - 0.5) * 60, 0.8 + r() * 0.7, 12 + r() * 10);
      }
      // chamas do nitro
      if (car.nitroOn || car.boostT > 0.9) {
        for (let k = 0; k < 2; k++) {
          const ex = car.x - c * 24, ey = car.y - s * 24;
          this.spawn('flame', ex + (r() - 0.5) * 5, ey + (r() - 0.5) * 5,
            car.vx - c * (180 + r() * 120) + (r() - 0.5) * 40, car.vy - s * (180 + r() * 120) + (r() - 0.5) * 40,
            0.12 + r() * 0.12, 6 + r() * 4);
        }
      }
      // placas de turbo
      for (const p of this.track.pads) {
        const dx = car.x - p.x, dy = car.y - p.y;
        const ca = Math.cos(p.a), sa = Math.sin(p.a);
        const along = dx * ca + dy * sa, lat = -dx * sa + dy * ca;
        if (Math.abs(along) < p.len / 2 && Math.abs(lat) < p.w / 2) {
          if (car.boostT <= 0.8) this.events.push({ type: 'boost', car });
          car.boostT = 1.2;
        }
      }
    }

    collideCars() {
      const cars = this.cars;
      const R = 11;
      for (let i = 0; i < cars.length; i++) {
        const A = cars[i];
        for (let j = i + 1; j < cars.length; j++) {
          const B = cars[j];
          const dx0 = B.x - A.x, dy0 = B.y - A.y;
          if (dx0 * dx0 + dy0 * dy0 > 60 * 60) continue;
          const ca = Math.cos(A.a), sa = Math.sin(A.a), cb = Math.cos(B.a), sb = Math.sin(B.a);
          for (const oa of [-11, 11]) {
            for (const ob of [-11, 11]) {
              const ax = A.x + ca * oa, ay = A.y + sa * oa;
              const bx = B.x + cb * ob, by = B.y + sb * ob;
              const dx = bx - ax, dy = by - ay;
              const d2 = dx * dx + dy * dy;
              if (d2 >= 4 * R * R || d2 < 1e-6) continue;
              const d = Math.sqrt(d2);
              const nx = dx / d, ny = dy / d;
              const pen = 2 * R - d;
              const ma = A.spec.mass, mb = B.spec.mass, mt = ma + mb;
              A.x -= nx * pen * (mb / mt); A.y -= ny * pen * (mb / mt);
              B.x += nx * pen * (ma / mt); B.y += ny * pen * (ma / mt);
              const rv = (B.vx - A.vx) * nx + (B.vy - A.vy) * ny;
              if (rv < 0) {
                const jimp = (-(1 + 0.25) * rv) / (1 / ma + 1 / mb);
                A.vx -= (jimp / ma) * nx; A.vy -= (jimp / ma) * ny;
                B.vx += (jimp / mb) * nx; B.vy += (jimp / mb) * ny;
                // giro pelo toque fora do centro
                A.av += (oa > 0 ? -1 : 1) * clamp(-rv / 300, 0, 1) * 0.8 * Math.sign(-ca * ny + sa * nx || 1);
                B.av += (ob > 0 ? 1 : -1) * clamp(-rv / 300, 0, 1) * 0.8 * Math.sign(cb * ny - sb * nx || 1);
                if (-rv > 60) {
                  const power = clamp(-rv / 380, 0, 1);
                  this.events.push({ type: 'bump', car: A.isPlayer ? A : B.isPlayer ? B : null, power });
                  if (A.isPlayer || B.isPlayer) this.cam.shake = Math.max(this.cam.shake, power * 8);
                  for (let k = 0; k < 4 + power * 10; k++) {
                    this.spawn('spark', ax + nx * R, ay + ny * R,
                      (A.vx + B.vx) / 2 + (this.rng() - 0.5) * 240, (A.vy + B.vy) / 2 + (this.rng() - 0.5) * 240, 0.2 + this.rng() * 0.3, 2);
                  }
                }
              }
            }
          }
        }
      }
    }

    /* ---------- Voltas e posições ---------- */
    updateProgress(car, dt) {
      const tr = this.track, N = tr.N;
      const prev = car.prevIdx, idx = car.idx;
      if (prev > N * 0.8 && idx < N * 0.2) {
        if (car.lap === 0 || car.halfway) {
          car.lap++;
          car.halfway = false;
          if (car.lap > car.maxLap) {
            car.maxLap = car.lap;
            this.onLine(car);
          }
        }
      } else if (prev < N * 0.2 && idx > N * 0.8) {
        car.lap--;
        car.halfway = true;
      }
      if (idx > N * 0.45 && idx < N * 0.55) car.halfway = true;
      car.progress = car.lap * N + idx;

      // tempos de passagem para os intervalos
      if (this.state !== 'countdown' && !car.finished) {
        const key = Math.floor(car.progress / 12);
        if (!this.passTimes.has(key)) this.passTimes.set(key, this.time);
        car.gap = this.time - this.passTimes.get(key);
      }

      // contramão
      const v = car.speed;
      if (v > 70) {
        const dot = (car.vx * tr.tx[idx] + car.vy * tr.ty[idx]) / v;
        car.wrongT = dot < -0.35 ? car.wrongT + dt : Math.max(0, car.wrongT - dt * 2);
      } else {
        const fd = Math.cos(car.a) * tr.tx[idx] + Math.sin(car.a) * tr.ty[idx];
        if (fd > 0) car.wrongT = Math.max(0, car.wrongT - dt * 2);
      }

      // IA presa: dá ré e, se preciso, volta para a pista
      if (car.auto && this.state !== 'countdown' && !car.finished) {
        if (v < 30) car.stuckT += dt; else car.stuckT = Math.max(0, car.stuckT - dt * 2);
        if (car.stuckT > 1.2 && car.reverseT <= 0) car.reverseT = 0.9;
        if (car.stuckT > 4.5) this.resetCar(car);
      }
    }

    resetCar(car) {
      const tr = this.track;
      const i = car.idx;
      car.x = tr.rx[i];
      car.y = tr.ry[i];
      car.a = tr.ang[i];
      car.vx = car.vy = car.av = 0;
      car.stuckT = 0;
      car.reverseT = 0;
      if (car.isPlayer) this.events.push({ type: 'reset', car });
    }

    onLine(car) {
      const t = this.time;
      if (car.lap === 1) {
        car.lapStart = t;
        if (car.isPlayer && this.laps > 1) this.events.push({ type: 'lap-start', car, lap: 1 });
        if (this.laps === 1 && car.isPlayer) this.events.push({ type: 'final-lap', car });
        return;
      }
      const lapTime = (t - car.lapStart) * 1000;
      car.lapStart = t;
      car.lastLap = lapTime;
      car.lapTimes.push(lapTime);
      const wasBest = car.bestLap == null || lapTime < car.bestLap;
      if (wasBest) car.bestLap = lapTime;
      const raceBest = Math.min(...this.cars.filter((c) => c.bestLap != null).map((c) => c.bestLap));
      this.events.push({ type: 'lap', car, lapTime, personalBest: wasBest, overallBest: lapTime <= raceBest, lap: car.lap - 1 });
      if (car.lap > this.laps) {
        car.finished = true;
        car.finishTime = t * 1000;
        car.auto = true;
        this.finishOrder.push(car);
        car.place = this.finishOrder.length;
        this.events.push({ type: 'finish', car, place: car.place });
      } else if (car.lap === this.laps && car.isPlayer) {
        this.events.push({ type: 'final-lap', car });
      }
    }

    standings() {
      return this.cars.slice().sort((a, b) => {
        if (a.finished && b.finished) return a.finishTime - b.finishTime;
        if (a.finished) return -1;
        if (b.finished) return 1;
        return b.progress - a.progress;
      });
    }

    /* ---------- IA ---------- */
    aiControl(car, dt) {
      const tr = this.track, N = tr.N, ai = car.ai;
      const v = car.speed;
      const ctl = { steer: 0, gas: 0, brake: 0, nitro: false, hand: false, analog: true };

      if (car.reverseT > 0) {
        car.reverseT -= dt;
        const ti = (car.idx + 10) % N;
        const desired = Math.atan2(tr.ry[ti] - car.y, tr.rx[ti] - car.x);
        const diff = wrapAngle(desired - car.a);
        ctl.brake = 1;
        ctl.steer = clamp(-diff * 2, -1, 1);
        return ctl;
      }

      // borracha leve para manter a disputa
      if (this.player && !this.attract && !car.isPlayer) {
        const gap = (car.progress - this.player.progress) / N;
        ai.rubber = damp(ai.rubber, gap > 0.12 ? 0.955 : gap < -0.12 ? 1.04 : 1, 0.5, dt);
      }

      ai.laneT += dt * ai.laneSpeed;
      let lane = Math.sin(ai.laneT) * 0.14 * tr.hw + ai.bias;

      // desvia de quem está à frente
      const fx = Math.cos(car.a), fy = Math.sin(car.a);
      let avoidT = 0;
      for (const o of this.cars) {
        if (o === car) continue;
        const dx = o.x - car.x, dy = o.y - car.y;
        const d2 = dx * dx + dy * dy;
        if (d2 > 130 * 130) continue;
        const fwd = dx * fx + dy * fy;
        if (fwd < 5) continue;
        const side = -dx * fy + dy * fx;
        if (Math.abs(side) < 30 && o.speed < v + 30) {
          avoidT += (side > 0 ? -1 : 1) * 46 * (1 - Math.sqrt(d2) / 130);
        }
      }
      ai.avoid = damp(ai.avoid, avoidT, 3, dt);

      const la = Math.round((70 + v * 0.3) / tr.ds);
      const ti = (car.idx + la) % N;
      let off = tr.rOff[ti] + lane + ai.avoid;
      off = clamp(off, -tr.hw + 16, tr.hw - 16);
      const tx = tr.xs[ti] + tr.nx[ti] * off;
      const ty = tr.ys[ti] + tr.ny[ti] * off;
      const desired = Math.atan2(ty - car.y, tx - car.x);
      const diff = wrapAngle(desired - car.a);
      ctl.steer = clamp(diff * 2.7 - car.av * 0.1, -1, 1);

      const prof = profileFor(tr, car.spec);
      const look = (car.idx + 3) % N;
      let target = prof[look] * ai.skill * (car.finished ? 0.55 : 1);
      if (car.surface === 'runoff') target = Math.min(target, car.spec.maxSpeed * 0.5);
      if (Math.abs(diff) > 0.9) target = Math.min(target, 260);

      if (v < target) {
        ctl.gas = 1;
      } else if (v > target * 1.05) {
        ctl.brake = clamp((v - target) / 110, 0.15, 1);
      } else {
        ctl.gas = 0.3;
      }

      // nitro em reta
      if (!car.finished && car.nitro > 0.3 && v > 320) {
        const ahead = prof[(car.idx + 45) % N];
        if (ahead >= car.spec.maxSpeed * 0.98 && prof[look] >= car.spec.maxSpeed * 0.98) {
          if (!ai.nitroWant && this.rng() < this.diff.aggr * dt * 1.5) ai.nitroWant = true;
        } else ai.nitroWant = false;
      } else if (car.nitro <= 0.02) ai.nitroWant = false;
      ctl.nitro = ai.nitroWant;
      return ctl;
    }

    /* ---------- Partículas e marcas ---------- */
    spawn(type, x, y, vx, vy, life, size) {
      if (this.particles.length >= MAX_PARTICLES) this.particles.shift();
      this.particles.push({ type, x, y, vx, vy, life, max: life, size, rot: this.rng() * 6.28 });
    }

    updateParticles(dt) {
      const ps = this.particles;
      let w = 0;
      for (let i = 0; i < ps.length; i++) {
        const p = ps[i];
        p.life -= dt;
        if (p.life <= 0) continue;
        const drag = p.type === 'spark' ? 2.5 : p.type === 'flame' ? 6 : 1.6;
        p.vx *= Math.exp(-drag * dt);
        p.vy *= Math.exp(-drag * dt);
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        if (p.type === 'smoke' || p.type === 'dust') p.size += dt * 26;
        ps[w++] = p;
      }
      ps.length = w;
    }

    addSkid(x1, y1, x2, y2, a) {
      const k = this.skidHead * 5;
      const s = this.skids;
      s[k] = x1; s[k + 1] = y1; s[k + 2] = x2; s[k + 3] = y2; s[k + 4] = a;
      this.skidHead = (this.skidHead + 1) % MAX_SKIDS;
      this.skidCount = Math.min(MAX_SKIDS, this.skidCount + 1);
    }

    /* ---------- Câmera ---------- */
    updateCamera(dt) {
      const f = this.focusCar();
      if (!f) return;
      const cam = this.cam;
      const lead = this.attract ? 0.25 : 0.42;
      const tx = f.x + f.vx * lead, ty = f.y + f.vy * lead;
      cam.x = damp(cam.x, tx, 4.2, dt);
      cam.y = damp(cam.y, ty, 4.2, dt);
      const s01 = clamp(f.speed / f.spec.maxSpeed, 0, 1.3);
      const zt = this.attract ? 0.66 - s01 * 0.08 : 1.08 - s01 * 0.3 - (f.nitroOn ? 0.05 : 0);
      cam.zoom = damp(cam.zoom, zt, 1.6, dt);
      cam.shake = Math.max(0, cam.shake - dt * 30);
    }
  }

  APX.Race = Race;
  APX.DIFFICULTY = DIFFICULTY;
  APX.RACE_DT = DT;
})(APX);
