# Verificação AJUSTE-18

49/49 comandos locais aprovados: 44 runners Luau focados (inclui o novo `tests_vfx18`), geral
34/34 casos, Python 75/75 (6 novos do instalador 18), lint 0, `git diff --check` e o instalador
autocontido `testar` sem rede. Resultados em RESULTADOS_AJUSTE18.json.

- **tests_vfx18 (novo):** receitas reais dos seis kits (M1 1º e 4º soco): 1ª camada no contato e
  as outras em degraus de 0–0,06 s; SP/TW começam pelo impacto de direção; o soco do pacote tem
  brilho ≥ 2. Renderer real (`Cliente/VFXPiloto`) com o catálogo real (`assets/vfx14`): uma luz por
  acerto, emissor `Light` com 0 emissões e desligado, `Hit1` com Brightness ≥ 2, estrelas com vida
  ≤ 0,46 s; a luz perde brilho enquanto o alcance cresce e some; bloqueio não acende luz; mesmo dono
  não acende duas luzes no mesmo instante; limpeza total. Pico segurado: com `segurar=0,08` o efeito
  anda 0,03 s e para até o fim da pausa, depois volta a andar; sem pausa não para. Câmera: o soco de
  FOV fica entre −5,5° e −7°, pico ≈ −6° em 0,05 s, rebote 0–1°, zero fora de 0–0,3 s e com força 0.
  Fontes: Efeitos só chama o soco no nível ≥ 2, a pausa do efeito é a mesma dos corpos (0,04/0,08) e
  rajada/defesa não seguram; Camera respeita o tremor desligado; Animador aceita AnimationConstraint.
- **tests_vfx14 ajustado:** o teste de massa contava ≥ 240 clones no instante 0. Com os degraus as
  camadas entram até 0,05 s, então ele avança 0,06 s e conta os clones marcados `BB_VFX14`. O limite
  de 240 não mudou.
- **test_vfx14_assets:** procura o `lune` também pelo PATH (antes só o caminho do ambiente do ChatGPT).
- **Instalador 18:** confirmação própria `PUBLICAR AJUSTE18`; recibo de outro instalador fica
  intacto e indica o `resume` certo; `instalar` faz Saved + teste + publicação com uma pergunta só;
  confirmação errada não publica e deixa o teste aprovado guardado para `publicar`; teste na nuvem
  reprovado não pergunta nada e não publica; perda da resposta do Saved nunca repete o POST; o
  builder reconhece hashes 14/15/16/17 e o teste nativo fica abaixo de 200 KB (32.000 bytes).
- **Teste nativo 18** (`tools/teste_nuvem18.luau`): todos os casos da 17 mais os dados da 18
  (degraus nos seis kits e a política de contato do renderer). Tem que passar no `instalar` ou no
  `testar-nuvem` antes de publicar.

## Migração do Place (`tools/migracao18.py`)

O Place AJ13 do repositório (`dist/BB_place.rbxl`, mapa Morioh completo) foi migrado em cadeia
pelos instaladores de cada etapa tirados do git: AJ14 (b39b17d) → AJ15 (0bf3abe) → AJ16 (39f5801)
→ AJ17 (87c3acf), cada etapa idempotente. Depois o AJ18 foi aplicado sobre cada ponto de partida:

| Partida | Instâncias | Fontes AJ18 | Objetos removidos | Blocos de propriedade iguais | Idempotente |
|---|---|---|---|---|---|
| AJ14 | 185097 → 185210 | 68/68 | 0 (97 novos = catálogo15 da AJ15) | 275/275 | sim |
| AJ15 | 185196 → 185210 | 68/68 | 0 | 486/486 | sim |
| AJ16 | 185201 → 185210 | 68/68 | 0 | 486/486 | sim |
| AJ17 | 185210 → 185210 | 68/68 | 0 | 486/486 | sim |

Partindo da AJ16 (publicada) ou da AJ17 o resultado é o mesmo arquivo, byte a byte. Parts do mapa:
162.429 antes e depois. Esses Places foram montados a partir do repositório; não são um backup do
jogo ao vivo. Build repetido do instalador produz bytes idênticos; tamanho/hash em ENTREGA_AJUSTE18.json.

## Limites

Não houve execução autenticada no Roblox, renderização/física real, replicação nem medição de FPS no
Android. A prévia `tools/previa_vfx18.py` simula as partículas com as texturas reais dos pacotes
(flipbook, sequências, arrasto, LightEmission, ZOffset); não é captura do Roblox. A luz do impacto,
a pausa do pico e o soco de FOV só podem ser vistos no cliente, no celular.

## Skills aplicadas

roblox-vfx, roblox-feel-audio-vfx, roblox-animation-vfx, roblox-camera, roblox-lighting,
roblox-combat-tools, roblox-engine-2026, roblox-luau-patterns, roblox-physics, roblox-pitfalls,
roblox-gui, roblox-ui-layout, roblox-ui-maker, roblox-input e roblox-store-art-pack. Regras usadas:
intensidade só cai depois do impacto; camadas em degraus de 0,025–0,05 s; sem bolha branca cheia;
luz de impacto que apaga enquanto o alcance cresce; hit stop congela também o efeito; FOV punch de
5–7° com Back Out e desligado junto com o tremor; Avatar Joint Upgrade (AnimationConstraint).
Nada de efeito desenhado por código (regra do dono): só camadas dos pacotes da loja.
