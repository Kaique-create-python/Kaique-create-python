/* Ápice Racing — som 100% sintetizado com Web Audio (motor, pneus, batidas, trilha) */
'use strict';
(function (APX) {
  const { store, clamp } = APX.util;

  class AudioFX {
    constructor() {
      this.ctx = null;
      this.sfxOn = store.get('sfx', true);
      this.musicOn = store.get('music', true);
      this.engine = null;
      this.music = null;
    }

    init() {
      if (this.ctx) {
        if (this.ctx.state === 'suspended') this.ctx.resume().catch(() => {});
        return true;
      }
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return false;
      const ctx = (this.ctx = new AC());
      this.master = ctx.createGain();
      this.master.gain.value = 0.85;
      const comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -16;
      comp.ratio.value = 4;
      this.master.connect(comp).connect(ctx.destination);
      this.sfx = ctx.createGain();
      this.sfx.gain.value = this.sfxOn ? 1 : 0;
      this.sfx.connect(this.master);
      this.mus = ctx.createGain();
      this.mus.gain.value = this.musicOn ? 0.5 : 0;
      this.mus.connect(this.master);
      // ruído branco reutilizável
      const len = ctx.sampleRate * 2;
      const buf = ctx.createBuffer(1, len, ctx.sampleRate);
      const d = buf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
      this.noise = buf;
      // eco para a trilha
      this.delay = ctx.createDelay(1);
      this.delay.delayTime.value = 0.32;
      const fb = ctx.createGain();
      fb.gain.value = 0.32;
      const dl = ctx.createBiquadFilter();
      dl.type = 'lowpass';
      dl.frequency.value = 2400;
      this.delay.connect(dl).connect(fb).connect(this.delay);
      this.delayOut = ctx.createGain();
      this.delayOut.gain.value = 0.5;
      this.delay.connect(this.delayOut).connect(this.mus);
      return true;
    }

    setSfx(on) {
      this.sfxOn = on;
      store.set('sfx', on);
      if (this.sfx) this.sfx.gain.setTargetAtTime(on ? 1 : 0, this.ctx.currentTime, 0.05);
    }

    setMusic(on) {
      this.musicOn = on;
      store.set('music', on);
      if (this.mus) this.mus.gain.setTargetAtTime(on ? 0.5 : 0, this.ctx.currentTime, 0.1);
    }

    noiseSrc(loop) {
      const s = this.ctx.createBufferSource();
      s.buffer = this.noise;
      s.loop = !!loop;
      return s;
    }

    /* ---------- Motor ---------- */
    startEngine() {
      if (!this.ctx || this.engine) return;
      const ctx = this.ctx, t = ctx.currentTime;
      const out = ctx.createGain();
      out.gain.value = 0;
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 700;
      lp.Q.value = 4;
      const o1 = ctx.createOscillator(); o1.type = 'sawtooth';
      const o2 = ctx.createOscillator(); o2.type = 'square';
      const o3 = ctx.createOscillator(); o3.type = 'sine';
      const g1 = ctx.createGain(); g1.gain.value = 0.5;
      const g2 = ctx.createGain(); g2.gain.value = 0.22;
      const g3 = ctx.createGain(); g3.gain.value = 0.7;
      o1.connect(g1).connect(lp);
      o2.connect(g2).connect(lp);
      o3.connect(g3).connect(out);
      lp.connect(out);
      out.connect(this.sfx);
      // pneus: ruído em banda
      const sq = this.noiseSrc(true);
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass'; bp.frequency.value = 1500; bp.Q.value = 2.2;
      const sg = ctx.createGain(); sg.gain.value = 0;
      sq.connect(bp).connect(sg).connect(this.sfx);
      // vento / rolagem
      const wn = this.noiseSrc(true);
      const wl = ctx.createBiquadFilter(); wl.type = 'lowpass'; wl.frequency.value = 500;
      const wg = ctx.createGain(); wg.gain.value = 0;
      wn.connect(wl).connect(wg).connect(this.sfx);
      for (const o of [o1, o2, o3, sq, wn]) o.start(t);
      out.gain.setTargetAtTime(0.22, t, 0.2);
      this.engine = { o1, o2, o3, lp, out, sg, bp, wg, wl, nodes: [o1, o2, o3, sq, wn] };
    }

    updateEngine(rpm, load, speed01, slip, offroad) {
      const e = this.engine;
      if (!e) return;
      const t = this.ctx.currentTime;
      const f = 38 + rpm * 150;
      e.o1.frequency.setTargetAtTime(f, t, 0.03);
      e.o2.frequency.setTargetAtTime(f * 1.5 + 1.5, t, 0.03);
      e.o3.frequency.setTargetAtTime(f * 0.5, t, 0.03);
      e.lp.frequency.setTargetAtTime(420 + rpm * 1900 + load * 900, t, 0.05);
      e.out.gain.setTargetAtTime(0.13 + load * 0.12 + rpm * 0.05, t, 0.06);
      e.sg.gain.setTargetAtTime(clamp(slip, 0, 1) * 0.16, t, 0.05);
      e.bp.frequency.setTargetAtTime(offroad ? 420 : 1300 + speed01 * 500, t, 0.1);
      e.wg.gain.setTargetAtTime(speed01 * 0.09 + (offroad ? speed01 * 0.14 : 0), t, 0.1);
      e.wl.frequency.setTargetAtTime(offroad ? 900 : 400 + speed01 * 600, t, 0.1);
    }

    stopEngine() {
      const e = this.engine;
      if (!e) return;
      const t = this.ctx.currentTime;
      e.out.gain.setTargetAtTime(0, t, 0.08);
      e.sg.gain.setTargetAtTime(0, t, 0.05);
      e.wg.gain.setTargetAtTime(0, t, 0.05);
      for (const n of e.nodes) { try { n.stop(t + 0.5); } catch (err) { /* já parado */ } }
      this.engine = null;
    }

    /* ---------- Efeitos ---------- */
    beep(freq, dur, vol) {
      if (!this.ctx) return;
      const ctx = this.ctx, t = ctx.currentTime;
      const o = ctx.createOscillator();
      o.type = 'square';
      o.frequency.value = freq;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(vol || 0.16, t + 0.01);
      g.gain.setTargetAtTime(0, t + dur * 0.7, dur * 0.2);
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass'; lp.frequency.value = 3000;
      o.connect(lp).connect(g).connect(this.sfx);
      o.start(t);
      o.stop(t + dur + 0.2);
    }

    crash(power) {
      if (!this.ctx) return;
      const ctx = this.ctx, t = ctx.currentTime;
      const p = clamp(power, 0.1, 1);
      const n = this.noiseSrc(false);
      const lp = ctx.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.setValueAtTime(2400 * p + 400, t);
      lp.frequency.exponentialRampToValueAtTime(180, t + 0.35);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.5 * p, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
      n.connect(lp).connect(g).connect(this.sfx);
      n.start(t);
      n.stop(t + 0.45);
      const o = ctx.createOscillator();
      o.type = 'sine';
      o.frequency.setValueAtTime(120, t);
      o.frequency.exponentialRampToValueAtTime(40, t + 0.25);
      const og = ctx.createGain();
      og.gain.setValueAtTime(0.6 * p, t);
      og.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
      o.connect(og).connect(this.sfx);
      o.start(t);
      o.stop(t + 0.32);
    }

    whoosh(strength) {
      if (!this.ctx) return;
      const ctx = this.ctx, t = ctx.currentTime;
      const n = this.noiseSrc(false);
      const bp = ctx.createBiquadFilter();
      bp.type = 'bandpass'; bp.Q.value = 1.4;
      bp.frequency.setValueAtTime(300, t);
      bp.frequency.exponentialRampToValueAtTime(3200, t + 0.5);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.001, t);
      g.gain.exponentialRampToValueAtTime(0.32 * (strength || 1), t + 0.08);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.7);
      n.connect(bp).connect(g).connect(this.sfx);
      n.start(t);
      n.stop(t + 0.75);
    }

    chime(good) {
      if (!this.ctx) return;
      const notes = good ? [784, 988, 1319] : [659, 784];
      notes.forEach((f, i) => setTimeout(() => this.beep(f, 0.16, 0.09), i * 90));
    }

    /* ---------- Trilha (synthwave em Lá menor, 116 BPM) ---------- */
    startMusic() {
      if (!this.ctx || this.music) return;
      const ctx = this.ctx;
      const bpm = 116;
      const step = 60 / bpm / 4; // semicolcheia
      const chords = [
        [57, 60, 64], // Am
        [53, 57, 60], // F
        [48, 52, 55], // C
        [55, 59, 62], // G
      ];
      const bassRoots = [45, 41, 36, 43];
      const arpPat = [0, 1, 2, 1, 2, 0, 1, 2, 0, 2, 1, 2, 0, 1, 2, 1];
      const m = { step: 0, next: ctx.currentTime + 0.1, timer: null };
      const hz = (n) => 440 * Math.pow(2, (n - 69) / 12);
      const play = (time, s) => {
        const bar = Math.floor(s / 16) % 4;
        const i = s % 16;
        const ch = chords[bar];
        // baixo em colcheias
        if (i % 2 === 0) {
          const o = ctx.createOscillator(); o.type = 'sawtooth';
          o.frequency.value = hz(bassRoots[bar] + (i % 8 === 6 ? 12 : 0));
          const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.Q.value = 6;
          f.frequency.setValueAtTime(900, time); f.frequency.exponentialRampToValueAtTime(160, time + step * 1.8);
          const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, time);
          g.gain.exponentialRampToValueAtTime(0.32, time + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, time + step * 1.9);
          o.connect(f).connect(g).connect(this.mus); o.start(time); o.stop(time + step * 2);
        }
        // arpejo
        {
          const note = ch[arpPat[i]] + 12 + (i >= 12 ? 12 : 0);
          const o = ctx.createOscillator(); o.type = 'square';
          o.frequency.value = hz(note);
          const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 2200;
          const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, time);
          g.gain.exponentialRampToValueAtTime(0.06, time + 0.005); g.gain.exponentialRampToValueAtTime(0.0001, time + step * 0.9);
          o.connect(f).connect(g);
          g.connect(this.mus); g.connect(this.delay);
          o.start(time); o.stop(time + step);
        }
        // pad no começo do compasso
        if (i === 0) {
          for (const n of ch) {
            const o = ctx.createOscillator(); o.type = 'sawtooth';
            o.frequency.value = hz(n); o.detune.value = (Math.random() - 0.5) * 14;
            const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 900;
            const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, time);
            g.gain.exponentialRampToValueAtTime(0.035, time + 0.4); g.gain.exponentialRampToValueAtTime(0.0001, time + step * 16);
            o.connect(f).connect(g).connect(this.mus); o.start(time); o.stop(time + step * 16 + 0.05);
          }
        }
        // bumbo
        if (i % 4 === 0) {
          const o = ctx.createOscillator(); o.type = 'sine';
          o.frequency.setValueAtTime(140, time); o.frequency.exponentialRampToValueAtTime(42, time + 0.14);
          const g = ctx.createGain(); g.gain.setValueAtTime(0.55, time); g.gain.exponentialRampToValueAtTime(0.0001, time + 0.22);
          o.connect(g).connect(this.mus); o.start(time); o.stop(time + 0.24);
        }
        // caixa
        if (i === 4 || i === 12) {
          const n = this.noiseSrc(false);
          const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1800; f.Q.value = 0.8;
          const g = ctx.createGain(); g.gain.setValueAtTime(0.22, time); g.gain.exponentialRampToValueAtTime(0.0001, time + 0.16);
          n.connect(f).connect(g).connect(this.mus); n.start(time); n.stop(time + 0.18);
        }
        // chimbal
        if (i % 2 === 1) {
          const n = this.noiseSrc(false);
          const f = ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 7000;
          const g = ctx.createGain(); g.gain.setValueAtTime(0.06, time); g.gain.exponentialRampToValueAtTime(0.0001, time + 0.04);
          n.connect(f).connect(g).connect(this.mus); n.start(time); n.stop(time + 0.05);
        }
      };
      m.timer = setInterval(() => {
        while (m.next < ctx.currentTime + 0.12) {
          play(m.next, m.step);
          m.next += step;
          m.step = (m.step + 1) % 64;
        }
      }, 30);
      this.music = m;
    }

    stopMusic() {
      if (!this.music) return;
      clearInterval(this.music.timer);
      this.music = null;
    }
  }

  APX.AudioFX = AudioFX;
})(APX);
