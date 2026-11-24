// Simulação sem tela: todos os carros com IA, confere se terminam e quanto batem.
// Uso: node tools/sim_test.js [voltas] [dificuldade]
'use strict';
const path = require('path');
const root = path.join(__dirname, '..', 'js');
for (const f of ['util.js', 'cars.js', 'tracks.js', 'race.js']) require(path.join(root, f));
const APX = globalThis.APX;
const laps = Number(process.argv[2] || 3);
const diff = process.argv[3] || 'dificil';
const { fmtTime } = APX.util;
let ok = true;
for (const track of APX.getTracks()) {
  const t0 = Date.now();
  // corrida "attract" = só IA
  const race = new APX.Race({ track, laps, attract: true, opponents: 6, difficulty: diff, seed: 42 });
  race.countdown = 0;
  const stats = { crash: 0, bump: 0, reset: 0, runoffSteps: 0, steps: 0 };
  const origReset = race.resetCar.bind(race);
  race.resetCar = (c) => { stats.reset++; origReset(c); };
  let simT = 0;
  while (race.state !== 'finished' && simT < 600) {
    race.step(APX.RACE_DT, null);
    simT += APX.RACE_DT;
    stats.steps++;
    for (const c of race.cars) if (c.surface === 'runoff') stats.runoffSteps++;
    for (const e of race.events) { if (e.type === 'crash' && e.power > 0.15) stats.crash++; if (e.type === 'bump') stats.bump++; }
    race.events.length = 0;
    race.particles.length = 0;
  }
  const st = race.standings();
  const best = Math.min(...race.cars.map((c) => c.bestLap || Infinity));
  const avgSpeedKmh = (track.N * track.ds * laps / (st[0].finishTime / 1000)) * 0.36;
  const done = race.cars.filter((c) => c.finished).length;
  if (done < race.cars.length) ok = false;
  console.log(`${track.name.padEnd(13)} vencedor ${fmtTime(st[0].finishTime)}  último ${fmtTime(st[st.length - 1].finishTime)}  melhor volta ${fmtTime(best)}  média ${avgSpeedKmh.toFixed(0)} km/h  ` +
    `terminaram ${done}/${race.cars.length}  batidas ${stats.crash}  toques ${stats.bump}  resets ${stats.reset}  fora ${(100 * stats.runoffSteps / (stats.steps * race.cars.length)).toFixed(1)}%  (${Date.now() - t0} ms)`);
  console.log('   ' + st.map((c) => `${c.place || '-'}º ${c.name} [${c.spec.name}] ${fmtTime(c.finishTime)}`).join(' | '));
}
process.exit(ok ? 0 : 1);
