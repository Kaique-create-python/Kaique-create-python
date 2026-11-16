// PROJETO BASTIÃO :: tira as fotos da prévia 3D com o Chromium do Playwright
// uso: node bastiao/ferramentas/previa/shot.js <lote.json>
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const lote = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'] });
  for (const item of lote) {
    const pecas = JSON.parse(fs.readFileSync(item.pecas, 'utf8'));
    const page = await browser.newPage({ viewport: { width: item.opts.w, height: item.opts.h } });
    page.on('pageerror', e => console.log('pageerror:', e.message));
    await page.goto('file://' + path.join(__dirname, 'render.html'));
    await page.evaluate(({ pecas, opts }) => window.renderCena(pecas, opts), { pecas, opts: item.opts });
    await page.waitForTimeout(120);
    await page.screenshot({ path: item.saida });
    console.log('ok', item.saida);
    await page.close();
  }
  await browser.close();
})();
