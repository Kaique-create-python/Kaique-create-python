# Ápice Racing

Jogo de corrida 3D que roda direto no navegador. Câmera atrás do carro, física de derrapagem, nitro que carrega no drift, rivais com IA e três circuitos com clima próprio. Tudo é gerado por código: carros, pistas, cenário, texturas e trilha sonora. Não há nenhuma imagem ou arquivo de áudio externo.

## Como jogar

Abra `index.html` no navegador (precisa de internet para baixar o Three.js e as fontes) ou use a versão de arquivo único `dist/apice-racing.html`.

Para servir localmente:

```bash
cd apice-racing
python3 -m http.server 8000
# abra http://localhost:8000
```

| Tecla | Ação |
| --- | --- |
| W / ↑ | Acelerar |
| S / ↓ | Frear e dar ré |
| A D / ← → | Esterçar |
| Shift / N | Nitro |
| Espaço | Freio de mão (drift) |
| C | Trocar câmera: atrás do carro, alta ou vista de cima (2D) |
| P / Esc | Pausar |
| R | Reiniciar corrida |
| M | Música liga/desliga |

Controle (gamepad) funciona: gatilho direito acelera, esquerdo freia, A aciona o nitro. No celular aparecem botões na tela.

## O que tem

- **3 circuitos**: Distrito Neon (cidade à noite, muros com neon e prédios com janelas acesas), Dunas de Sal (deserto ao pôr do sol, barreira de pneus) e Serra Gelada (neve, pinheiros e placas de gelo na pista).
- **4 carros** com física diferente: Faísca GT (equilibrado), Trovão V12 (velocidade final), Libélula S (controle) e Javali 8 (arrancada). Cada um é o mais rápido em algum circuito.
- **IA** que segue um traçado ideal calculado por relaxação elástica da linha central, freia pelo perfil de velocidade da pista, desvia de quem está na frente e usa nitro nas retas. Quatro níveis de dificuldade.
- **Cronometragem**: voltas, melhor volta, torre de classificação com intervalos reais, recordes salvos no navegador.
- **Som sintetizado** com Web Audio: motor com troca de marchas, pneus cantando, batidas, turbo e uma trilha synthwave em Lá menor.
- **Pórtico de largada** com semáforo, arquibancada com público, partículas de fumaça, poeira, faíscas e chamas do nitro, marcas de pneu.

## Estrutura

```
apice-racing/
├── index.html          # site + HUD
├── css/style.css       # sistema visual (tokens no :root)
├── js/
│   ├── util.js         # matemática, armazenamento, entrada (teclado, toque, controle)
│   ├── audio.js        # motor, efeitos e trilha em Web Audio
│   ├── cars.js         # especificações e desenho vetorial dos carros
│   ├── tracks.js       # spline, traçado ideal, perfil de velocidade, cenário
│   ├── race.js         # simulação a 120 Hz: física, IA, voltas, colisões
│   ├── render.js       # renderizador 2D (vista de cima e minimapa)
│   ├── render3d.js     # renderizador 3D com Three.js
│   └── app.js          # site, garagem, grid, HUD, resultados
├── design/svg/         # carros e mapas exportados como SVG (usados no Figma)
├── tools/
│   ├── build.py            # gera dist/apice-racing.html (arquivo único)
│   ├── validate_tracks.js  # confere raio mínimo e folga entre trechos
│   ├── sim_test.js         # corrida só com IA, sem tela
│   └── export_svg.js       # exporta os SVGs de design/svg
└── dist/apice-racing.html
```

A simulação é plana (1 px = 10 cm) e independente da renderização: o mesmo estado alimenta a vista 3D e a vista de cima.

## Testes

```bash
node tools/validate_tracks.js     # geometria dos circuitos
node tools/sim_test.js 3 dificil  # 6 carros com IA completam 3 voltas em cada pista
python3 tools/build.py            # gera o arquivo único
```
