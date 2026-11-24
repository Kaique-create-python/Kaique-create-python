/* Ápice Racing — utilitários, armazenamento e entrada (teclado, toque, controle) */
'use strict';
var APX = (typeof window !== 'undefined' ? (window.APX = window.APX || {}) : (globalThis.APX = globalThis.APX || {}));

(function (APX) {
  const TAU = Math.PI * 2;
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const approach = (v, target, step) => (v < target ? Math.min(v + step, target) : Math.max(v - step, target));
  const wrapAngle = (a) => {
    while (a > Math.PI) a -= TAU;
    while (a < -Math.PI) a += TAU;
    return a;
  };
  const damp = (a, b, lambda, dt) => lerp(a, b, 1 - Math.exp(-lambda * dt));

  function mulberry32(seed) {
    let s = seed >>> 0;
    return function () {
      s = (s + 0x6d2b79f5) | 0;
      let t = Math.imul(s ^ (s >>> 15), 1 | s);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function fmtTime(ms) {
    if (ms == null || !isFinite(ms) || ms < 0) return '-:--.---';
    const m = Math.floor(ms / 60000);
    const s = Math.floor(ms / 1000) % 60;
    const r = Math.floor(ms % 1000);
    return m + ':' + String(s).padStart(2, '0') + '.' + String(r).padStart(3, '0');
  }

  function fmtGap(ms) {
    if (ms == null || !isFinite(ms)) return '';
    const sign = ms < 0 ? '−' : '+';
    const a = Math.abs(ms);
    if (a >= 60000) return sign + fmtTime(a);
    return sign + (a / 1000).toFixed(3);
  }

  function shade(hex, amt) {
    // amt: -1..1 (escurece / clareia)
    const n = parseInt(hex.slice(1), 16);
    let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    if (amt >= 0) {
      r += (255 - r) * amt; g += (255 - g) * amt; b += (255 - b) * amt;
    } else {
      r *= 1 + amt; g *= 1 + amt; b *= 1 + amt;
    }
    return 'rgb(' + Math.round(r) + ',' + Math.round(g) + ',' + Math.round(b) + ')';
  }

  function rgba(hex, a) {
    const n = parseInt(hex.slice(1), 16);
    return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
  }

  const store = {
    get(key, fallback) {
      try {
        const v = localStorage.getItem('apice:' + key);
        return v == null ? fallback : JSON.parse(v);
      } catch (e) {
        return fallback;
      }
    },
    set(key, value) {
      try {
        localStorage.setItem('apice:' + key, JSON.stringify(value));
      } catch (e) { /* armazenamento indisponível: segue sem salvar */ }
    },
  };

  const CAPTURED = new Set([
    'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space',
    'KeyW', 'KeyA', 'KeyS', 'KeyD', 'ShiftLeft', 'ShiftRight', 'KeyN',
  ]);

  class Input {
    constructor() {
      this.down = new Set();
      this.pressed = new Set();
      this.capture = false;
      this.touch = { left: 0, right: 0, gas: 0, brake: 0, nitro: 0, hand: 0 };
      this.padPrev = {};
      this.usingPad = false;
      if (typeof window === 'undefined') return;
      window.addEventListener('keydown', (e) => {
        if (this.capture && CAPTURED.has(e.code)) e.preventDefault();
        if (!e.repeat) this.pressed.add(e.code);
        this.down.add(e.code);
        this.usingPad = false;
      });
      window.addEventListener('keyup', (e) => this.down.delete(e.code));
      window.addEventListener('blur', () => {
        this.down.clear();
        for (const k in this.touch) this.touch[k] = 0;
      });
    }

    consume(code) {
      const had = this.pressed.has(code);
      this.pressed.delete(code);
      return had;
    }

    clear() {
      this.pressed.clear();
    }

    pollPad() {
      // botões de controle viram "pressed" com códigos virtuais (Pad*)
      const pads = typeof navigator !== 'undefined' && navigator.getGamepads ? navigator.getGamepads() : [];
      let state = null;
      for (const gp of pads) {
        if (!gp) continue;
        const b = (i) => (gp.buttons[i] ? gp.buttons[i].value || (gp.buttons[i].pressed ? 1 : 0) : 0);
        state = {
          steer: Math.abs(gp.axes[0] || 0) > 0.12 ? gp.axes[0] : (b(15) - b(14)),
          gas: Math.max(b(7), b(12) ? 1 : 0),
          brake: Math.max(b(6), b(13) ? 1 : 0),
          nitro: b(0) > 0.5 || b(5) > 0.5,
          hand: b(2) > 0.5 || b(1) > 0.5,
          start: b(9) > 0.5,
          back: b(8) > 0.5,
        };
        if (state.gas > 0.05 || state.brake > 0.05 || Math.abs(state.steer) > 0.2 || state.nitro) this.usingPad = true;
        break;
      }
      if (state) {
        if (state.start && !this.padPrev.start) this.pressed.add('PadStart');
        if (state.back && !this.padPrev.back) this.pressed.add('PadBack');
        if (state.nitro && !this.padPrev.nitro) this.pressed.add('PadA');
        this.padPrev = state;
      }
      return state;
    }

    read() {
      const k = (c) => this.down.has(c);
      let steer = (k('ArrowRight') || k('KeyD') ? 1 : 0) - (k('ArrowLeft') || k('KeyA') ? 1 : 0);
      let gas = k('ArrowUp') || k('KeyW') ? 1 : 0;
      let brake = k('ArrowDown') || k('KeyS') ? 1 : 0;
      let nitro = k('ShiftLeft') || k('ShiftRight') || k('KeyN');
      let hand = k('Space');
      let analog = false;
      const t = this.touch;
      steer += t.right - t.left;
      gas = Math.max(gas, t.gas);
      brake = Math.max(brake, t.brake);
      nitro = nitro || !!t.nitro;
      hand = hand || !!t.hand;
      const pad = this.pollPad();
      if (pad) {
        if (Math.abs(pad.steer) > 0.12) { steer += pad.steer; analog = true; }
        gas = Math.max(gas, pad.gas);
        brake = Math.max(brake, pad.brake);
        nitro = nitro || pad.nitro;
        hand = hand || pad.hand;
      }
      return { steer: clamp(steer, -1, 1), gas, brake, nitro, hand, analog };
    }
  }

  APX.util = { TAU, clamp, lerp, approach, wrapAngle, damp, mulberry32, fmtTime, fmtGap, shade, rgba, store };
  APX.Input = Input;
})(APX);
