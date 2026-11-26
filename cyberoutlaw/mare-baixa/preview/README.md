# Prévia de Maré Baixa

O renderizador usa as peças, câmeras, luzes e inscrições do `visualizacao.json` exportado pelo gerador Luau. O Three.js usa os mapas PBR locais, a iluminação dos postes, sombras e reflexos planares da geometria. O Chromium grava um PNG por câmera.

## Gerar as imagens

São necessários Node.js 20 ou posterior, Three.js r180, Playwright e Chromium. Instale as dependências locais na raiz do projeto se elas ainda estiverem ausentes.

```sh
npm install --no-save three@0.180.0 playwright
npx playwright install chromium
```

Na raiz do projeto, execute o comando abaixo depois de exportar o cenário.

```sh
node preview/render.mjs --map entrega/visualizacao.json \
  --materials materials --output preview/final --width 1600 --height 900
```

Use `--shot Canal` para renderizar uma câmera ou repita `--shot` para selecionar várias. `--help` mostra os controles de exposição, bloom, névoa e reflexos. É possível passar a pasta com `manifest.json` ou o caminho do manifesto diretamente em `--materials`.

## Dependências em outros caminhos

`THREE_ROOT` e `PLAYWRIGHT_ROOT` apontam para as pastas dos pacotes. `CHROMIUM_PATH` aponta para o executável. Sem essas variáveis, o renderizador procura os módulos locais e o Chromium instalado pelo Playwright ou em `/usr/bin/chromium`.

```sh
THREE_ROOT=/projeto/node_modules/three \
PLAYWRIGHT_ROOT=/projeto/node_modules/playwright \
CHROMIUM_PATH=/usr/bin/chromium \
node preview/render.mjs --map entrega/visualizacao.json --shot Canal
```
