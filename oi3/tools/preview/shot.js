// Tira prints da prévia three.js com Playwright.
// uso: node shot.js <pecas.json> <saida.png> '<json opts>'  (vários: arquivo de lote)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const lote = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'] });
  for (const item of lote) {
    const pecas = JSON.parse(fs.readFileSync(item.pecas, 'utf8'));
    const extra = item.extra ? JSON.parse(fs.readFileSync(item.extra, 'utf8')) : [];
    const page = await browser.newPage({ viewport: { width: item.opts.w || 1280, height: item.opts.h || 720 } });
    page.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
    page.on('pageerror', e => console.log('pageerror:', e.message));
    await page.goto('file://' + path.join(__dirname, 'render.html'));
    const filtroSrc = item.filtro || null;
    await page.evaluate(({ pecas, extra, opts, filtroSrc }) => {
      if (filtroSrc) opts.filtro = new Function('p', filtroSrc);
      return window.renderCena(pecas.concat(extra), opts);
    }, { pecas, extra, opts: item.opts, filtroSrc });
    await page.waitForTimeout(150);
    await page.screenshot({ path: item.saida });
    console.log('ok', item.saida);
    await page.close();
  }
  await browser.close();
})();
