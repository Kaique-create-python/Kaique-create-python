# Ferramentas de verificação da Etapa 3 (pacote do ChatGPT)

Rodam no Lune, sem Roblox e sem chave nenhuma.

- `fluxo_mapa_real.luau`: roda o trecho "abertura inteira" do `teste_nuvem.luau` de verdade, com o
  mapa Sector7World do place, raycast contra as peças e jogadores falsos (como na nuvem, que não deixa
  criar Player). `pavel` coloca o corpo do Pavel no cenário (foi assim que achamos o braço dele
  bloqueando o rádio). `duracoes.json` usa as durações reais das vozes.
- `teste_contrato.luau` + `glb_ossos.luau`: monta os 46 ossos a partir do próprio GLB e testa o
  `MonsterImportContract` em 15 situações (igual ao arquivo, giro do importador, rotações zeradas,
  troca de eixo, escala, deitado, raiz deslocada...).

- `monstro_sem_fisica.luau`: roda o trecho "monstro real" do teste imitando a nuvem SEM física
  (a documentação da Open Cloud diz que a execução Luau não roda física). Lê as 35 animações .rbxm
  de verdade e confere marcadores, duração e nomes de ossos. `passo`/`semPasso` imita a nuvem
  deixando ou não `Animator:StepAnimations`; `semRoar`, `ossoErrado` e `proibido` estragam de
  propósito para provar que a conferência reprova (ou só avisa, quando a nuvem não deixa ler).

Os arquivos `dist/CORRIGIR_ETAPA3_3.py` e `dist/CORRIGIR_ETAPA3_4.py` (este inclui o 3) aplicam as mudanças de `docs/CORRECAO4_ETAPA3_CHATGPT.patch` na
pasta já extraída no celular (mantém os recibos de assets; não reenvia nada).

`dist/CORRIGIR_ETAPA3_7.py` inclui as correções 3 a 6 e acrescenta o menu da bodycam com abertura em 3D,
as legendas estilo Miside (letra por letra, quebrando em pedaços), o clique da lanterna, a tela tensa na
perseguição e 4 sons novos do monstro (`audio/sources/eleven_*.mp3`, reaproveitados pelo `AUDIO_PLAN.json`).
Cria os arquivos novos, troca só versões conhecidas e, se o `AUDIO_PLAN.json` for de outra versão, troca
só os 8 sons dela. Depois dela: `preparar-audio` (Enter, sem chave) → `assets` → `testar-nuvem` → `publicar`.
Patch: `docs/CORRECAO7_MENU3D_LEGENDAS_SONS.patch`.

- `sim_criatura.luau`: roda o `Criatura.luau` INTEIRO no Lune (carregar, rondar, ver, rugir, perseguir,
  bote e garra) com o mapa Sector7World real (raycast em caixas orientadas), jogadores falsos que andam
  ou correm por rotas e animações falsas que disparam os marcadores nos tempos do catálogo. Cenários:
  `anda`, `corre`, `foge_sul`, `corre_sul`, `oficina`, `dois`. Reprova se o monstro entrar na oficina,
  sair da área, sair do chão, sair do eixo do corredor ou não rugir; nos cenários andando exige o bote.
  Uso: `lune run sim_criatura.luau <Criatura.luau> <CriaturaCore.luau> <MonsterCatalog.luau> <place.rbxl> <cenario>`.

`dist/CORRIGIR_ETAPA3_8.py` inclui as correções 3 a 7 e destrava o `testar-nuvem` que parou em
"fonte desconhecida: Criatura": a versão 17 do Place tinha a "Perseguição v2" e o `MonstroSom` feitos pelo
Antigravity no Studio (salvos, não publicados). Foram conferidos e juntados (merge de 3 vias, sem conflito)
e o `release_builder.py` ganhou `REVISADAS`: as versões conferidas de cada script Bastiao* que o instalador
pode trocar. Outra fonte desconhecida continua bloqueada. Patch: `docs/CORRECAO8_PERSEGUICAO_V2_ANTIGRAVITY.patch`.
