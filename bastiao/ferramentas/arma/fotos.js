const { chromium } = require('playwright'); const fs = require('fs');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
  p.on('pageerror', e => console.log('erro', e.message));
  await p.goto('http://127.0.0.1:8766/index.html'); await p.waitForFunction(() => window.pronto);
  const arma = JSON.parse(fs.readFileSync('arma.json')), bracos = JSON.parse(fs.readFileSync('arma_bracos.json'));
  await p.evaluate(d => window.montar(d), arma);
  for (const [nome, pos, alvo, fov] of [['lado', [3.2, 0.1, -0.3], [0, -0.1, -0.3], 34], ['tres4', [-2.0, 0.9, -2.3], [0, -0.15, -0.35], 34], ['detalhe', [0.9, 0.35, -0.9], [0, 0, -0.55], 30]]) {
    await p.evaluate(([a, b, c]) => window.foto(a, b, c), [pos, alvo, fov]); await (await p.$('canvas')).screenshot({ path: nome + '.png' }); }
  await p.evaluate(d => window.montar(d), bracos);
  // primeira pessoa: olho 0.62 acima e 0.42 à esquerda do punho, 0.55 atrás, olhando para frente (-Z)
  const mao = arma.pontos.Mao; const olho = [mao[0] - 0.42, mao[1] + 0.62, mao[2] + 0.55];
  await p.evaluate(([a, b, c]) => window.foto(a, b, c), [olho, [olho[0] + 0.05, olho[1] - 0.04, olho[2] - 5], 70]);
  await (await p.$('canvas')).screenshot({ path: 'primeira_pessoa.png' });
  await b.close(); console.log('ok');
})();
