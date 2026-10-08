# VEILBREAKERS v1.7.0 — revisão e recuperação da arte

Origem: `Kaique-create-python/Kaique-create-python`, branch **veilbreakers-apk-build**, commit anterior `bc70c03b0ee04e46b4b04abea6726ba9e06ffa9f`. Package `com.veilbreakers.prototype`, versionCode **21**, versionName **1.7.0**.

## Identidade e método

O idle original mais coerente definiu o Kael: cabelo preto curto/desgrenhado, rosto pálido, armadura carvão com aço gasto, capa escura com tecido carmesim, botas/luvas pretas e uma espada. O model sheet novo é a referência das animações. A marca do peito foi aproximada ao VIII definido pela história. O estilo mantém as proporções compactas do protagonista; não foi transformado em outro personagem.

A arte nova foi realmente gerada e editada com `image_gen`. Os scripts Python somente isolam células, recortam, escalam com fatores documentados, colocam pivôs e montam folhas/previews. Não desenham personagens procedurais para simular geração de imagem. Edições que apresentaram direção incorreta, espada duplicada, fases repetidas ou efeitos cortados foram rejeitadas antes da integração. Algumas tentativas rejeitadas ficam no arquivo, identificadas pelas notas e fora dos paths carregados.

## Antes e depois / assets substituídos no carregamento

| Conjunto antigo | Achado | Conjunto usado em v1.7 |
|---|---|---|
| `kael/move/move_r0_f*` a `move_r3_f*` | Idle de identidade útil, mas conjuntos posteriores divergiam | `kael_v17/idle/`: 16 frames da mesma referência |
| `kael/move/move_r4_f*`, `move_r5_f*`, `kael_v14/side/walk_*`, `run_*` | Walk/run laterais idênticos por hash, fragmentos vizinhos e escala por bounds | `kael_v17/walk/` e `run/`: 24 + 24 poses distintas, quatro direções |
| `kael_v14/combo/*`, `kael_v15/combo/*`, antigas sequências `kael/attack/*` | Escalas diferentes entre vertical/lateral, leitura direcional de VFX fraca | `kael_v17/combo/`: 36 poses, C1 direto, C2 diagonal, C3 finisher, corpo ancorado |
| `kael_v16/magic_cast_sheet.png` | Só três fases, fragmentos de pés de outra linha e VFX muito grande | `kael_v17/cast/`: 20 poses, release autorado em .28s e sockets de mão |
| `fx_v16/arcana_orb_sheet.png` | Seis fases com impacto pouco distinto e fragmento vizinho | `fx_v17/orb_0..7.png`: núcleo escuro, energia controlada, ruptura e dissipação próprias |
| `enemy_v14/idle_front_*`, `chase_side_*`, `attack_side_*`, `hurt_front_*`, `death_front_*` | Movimento/ataque lateral espelhado, pouca leitura de direção | `enemy_v17/`: 52 poses, quatro direções desenhadas, hurt/death próprios |

Os pacotes e fontes históricos são preservados para recuperação. GameView carrega obrigatoriamente os arquivos v17; a falta de um deles interrompe o carregamento com erro claro. As novas imagens não ficam sem uso em assets.

## Contrato técnico

- Kael/enemy: RGBA 256×256, pivot (128,232), baseline 232. Kael neutro ~174px, Veilborn ~168px.
- Os 36 combos usam RGBA **512×256**, pivot **(256,232)**; a largura adicional preserva espada e corpo sem reduzir somente a pose de impacto.
- Esfera: RGBA 160×160, pivot (80,80). O núcleo de voo foi centralizado; aura e impacto mantêm escala compartilhada.
- O runtime calcula pivotX como metade da largura e usa escala corporal constante. Bounds de partículas não deslocam pés nem redimensionam o personagem.
- Manifesto principal: `SPRITES_MANIFEST_V170.json`, com ordem, direção, dimensões, FPS, duração, pivô, baseline, hit/release e SHA256 para todos os 180 PNGs.
- Manifestos específicos e scripts preservam fonte selecionada, coordenadas de recorte, escalas e sockets. Pequenas diferenças de perspectiva da arte gerada são descritas nas notas; não equivalem a uma animação desenhada por um único animador ou a um rig 3D.

## Revisão e verificação

As contact sheets finais foram abertas e revisadas célula a célula: rosto/cabelo/armadura, duas pernas e dois braços, arma única, direção, recortes, vizinhos, transparência, padding, baseline e escala. GIFs mostram ciclos na escala do sprite; eles são previews de assets, não capturas do Android.

`validate_v17_assets.py` confere 180 arquivos, dimensões, bordas transparentes, metadados e hashes de walk/run distintos. `verify_apk_v17.py` confere os bytes empacotados e a versão com `aapt`. Esses checks técnicos não avaliam anatomia ou suavidade.

O modo debug de revisão usa os renderizadores reais de GameView, captura todas as poses por índice e reproduz ciclos com `review_frame=-1`; ele não altera o save. O workflow preserva `runtime_summary.json`, logcat, screenshots, contact sheets e vídeo. O resultado real e a revisão manual dessas capturas devem ser consultados no run correspondente; este documento não declara um run bem-sucedido antes de ele ocorrer.

## Reconstrução sem chat

1. Checkout da branch obrigatória.
2. Instalar Python e `python -m pip install -r tools/requirements-art.txt`.
3. `python tools/recover_workflow_assets.py`: decodifica todos os pacotes históricos e aplica v17 por último.
4. `python tools/validate_v17_assets.py`.
5. Com JDK17, Android SDK35/build-tools35 e Gradle8.7: `gradle --no-daemon assembleDebug`.
6. O workflow entrega `VEILBREAKERS_v1.7.0_Codex.apk`, contexto atualizado e `VEILBREAKERS_v1.7.0_Arte.zip`.

Para recortar novamente as fontes novas: `tools/kael_locomotion.py`, `kael_combo.py`, `enemy_art.py`, `prepare_cast_v17.py`, `prepare_orb_v17.py`. As folhas originais selecionadas e as folhas de runtime com células perfeitamente separadas estão em `source_sheets/v17/`; frames individuais estão nos diretórios de runtime e, quando indicado, também no arquivo. As previews ficam em `previews/v17/`. A história completa permanece em `HISTORIA_COMPLETA.txt`.
