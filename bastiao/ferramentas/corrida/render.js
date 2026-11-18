// uso: node render.js <cena.json> <pasta_saida> [fps] [segundos]   (sem segundos: 1 quadro em t=cfg.t)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  for (const a of cfg.atores) if (typeof a.offsets === 'string') a.offsets = JSON.parse(fs.readFileSync(a.offsets, 'utf8'));
  const saida = process.argv[3]; fs.mkdirSync(saida, { recursive: true });
  const fps = Number(process.argv[4] || 30), seg = process.argv[5] ? Number(process.argv[5]) : null;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
  page.on('pageerror', e => console.log('pageerror:', e.message));
  await page.goto('http://127.0.0.1:' + (process.env.PORTA || 8765) + '/index.html');
  await page.waitForFunction(() => window.pronto === true);
  console.log('clips', await page.evaluate(() => window.carregar()));
  console.log('duracoes', await page.evaluate(c => window.montar(c), cfg));
  const tempos = seg ? Array.from({ length: Math.round(seg * fps) }, (_, i) => i / fps) : [cfg.t || 0];
  let i = 0;
  for (const t of tempos) {
    await page.evaluate(t => window.quadro(t), t);
    const el = await page.$('canvas');
    await el.screenshot({ path: path.join(saida, String(i++).padStart(4, '0') + '.png') });
  }
  console.log('quadros', i);
  await browser.close();
})();
