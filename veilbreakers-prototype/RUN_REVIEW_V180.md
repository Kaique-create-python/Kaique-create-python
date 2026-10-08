# VEILBREAKERS v1.8.0 — corrida de Kael

A corrida v1.7 usava seis imagens diferentes por direção, mas suas poses
laterais repetiam quase sempre a mesma perna à frente. O ciclo não mostrava
uma troca de apoio convincente. Os contact sheets Android antigos de corrida
e caminhada estavam cobertos pelo aviso de tela cheia e não comprovavam a
qualidade do movimento. Eles permanecem como registros históricos.

## Arte e seleção

As novas imagens foram geradas/editaram-se com a ferramenta integrada
`image_gen.imagegen`, com `transparent_background=true`, usando o model sheet
v1.7 como referência de identidade. Kael mantém cabelo preto, rosto pálido,
proporções compactas, armadura carvão/aço, tecido carmesim e uma espada nas
costas. Não houve acesso a ChatGPT Work, outra sessão Codex ou IAs do celular.

Três folhas completas foram examinadas. As duas primeiras foram rejeitadas
por repetir o membro próximo da câmera nos contatos laterais. A terceira
melhorou as botas de frente/costas e forneceu esses 12 quadros e os primeiros
três quadros laterais. Uma geração final de apenas seis sprites trouxe o meio
ciclo lateral oposto. As tentativas e os prompts literais estão documentados
em `project_archive/source_sheets/v18/PROMPT.txt`; as imagens rejeitadas não
são paths carregados nem ficam no pacote de runtime.

O resultado final tem contato, compressão e impulso de cada metade do ciclo,
com mudanças de braços, joelhos, oclusão das coxas e botas. A compressão e o
voo da segunda metade lateral têm silhuetas próprias. A leitura entre perna
próxima e distante ainda depende de oclusão e sombreamento, e há pequenas
variações de perspectiva/escala da pintura entre as fontes. Essa arte gerada
não equivale a uma animação de rig desenhada por um único animador.

## Contrato preservado

- Somente 24 frames de corrida mudam para `kael_v18/run/`.
- São seis quadros por direção: `down`, `up`, `left`, `right`.
- PNG RGBA 256×256, pivô fixo `(128,232)`, baseline 232 e altura corporal de
  referência 174px. Impulso/voo usa elevação interna de 4px nos quadros 2/5.
- O recorte isola componentes da própria folha gerada, preserva alpha e
  reamostra os pixels originais. Não desenha personagens, não espelha membros
  e não sintetiza frames. Cada direção de cada fonte compartilha uma escala.
- Idle, walk, combos, cast, inimigo e esfera continuam com seus 156 arquivos
  v17 e hashes históricos. Total de runtime permanece 180 PNGs.
- Manifesto híbrido `SPRITES_MANIFEST_V180.json`, versão 1.8.0/code22, contém
  os 180 registros. A corrida registra base 12 FPS e cadência por distância;
  a velocidade efetiva e as colisões são responsabilidade de GameView.

## Reconstrução e revisão

O pacote v17 permanece intacto. `run_v18_assets.zip.b64.part-*` contém apenas
o overlay v18: frames novos, fontes selecionadas, referência, prompt,
manifestos, folha runtime, contact sheet, GIF e esta revisão. A recuperação
decodifica v17 antes de aplicar esse overlay.

Para recortar e empacotar novamente:

```
python tools/prepare_run_v18.py --opposite-source app/src/main/assets/project_archive/source_sheets/v18/kael_run_opposite_half.png --package
```

`project_archive/source_sheets/v18/kael_run_manifest.json` registra crops,
eixos anatômicos, fatores compartilhados e SHA256 dos arquivos. A contact
sheet final está em `project_archive/previews/v18/kael_run_contact.png`; o GIF
`kael_run_preview.gif` mostra as quatro direções na escala dos sprites.

Esses arquivos são revisão de assets. Testes técnicos verificam quantidade,
RGBA, transparência, dimensões, hashes e contrato; não medem anatomia. A
validação Android do novo APK precisa mostrar o jogo sem o aviso de tela
cheia, em movimento normal e nas quatro direções, antes de afirmar que o
resultado foi verificado no dispositivo.
