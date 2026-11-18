# BIZARRE BATTLEGROUNDS — leia antes de continuar

Jogo JoJo de Kaique. **Universe 10774214555; Place 108061345551908.**
Ele usa Android/Termux, sem Roblox Studio. Responda em português com comandos curtos.
Repositório: `Kaique-create-python/Kaique-create-python`, ramo
`claude/context-capture-w0uo2t`, pasta `bizarre/`.

## AJUSTE-19 — entrega atual (Claude): HUD novo

Correção posterior ChatGPT: docs/CORRECAO_AJUSTE19.md e .json. O validador Luau ainda
rejeitava18/19, causando Destino/pacote incorreto no Saved40/41. Corrigido e instalador19
regenerado, baseline19 original registrada.50checks/85Python offline aprovados; teste
Roblox/publicação19 continuam pendentes. Só Validacao14 muda no jogo; HUD/VFX preservados.

Leia docs/README_AJUSTE19.md. Build `python3 bizarre/tools/gerar_ajuste19.py` (bases 14-18,
confirmação PUBLICAR AJUSTE19). Visual em Interface (UI.HUD, UI.FACE, UI.paralelo,
UI.barraInclinada, UI.cartaoGolpe, UI.botaoRedondo), HUD.luau, Controles.luau e defaults do Layout17.
Prévia: tools/previa_hud19.luau/.py. Teste: tools/tests_hud19.luau. Só testado offline.
Próxima etapa20: baseline19.json já guarda a AJ19 original; registrar também a Source do validador corrigido ao aceitar20. Sincronizar Python, validador Luau e teste do instalador real; não só package/runtime.

## AJUSTE-18 — (Claude, sobre a AJ17)

Pedido do Kaique: usar as skills de Roblox para melhorar VFX, animação e design, e melhorar o
instalador se possível. Leia docs/README_AJUSTE18.md e docs/VALIDACAO_AJUSTE18.md.
Build: `python3 bizarre/tools/gerar_ajuste18.py` (bases 14/15/16/17, estado18 separado,
confirmação PUBLICAR AJUSTE18). Testado só offline (49/49); não assumir instalação/publicação18
até o Kaique dizer. A AJ17 também não tem confirmação: a AJ18 já inclui tudo da AJ17.

- Acerto em degraus nos seis kits (VFXReceitas/15/16: impacto no contato, outras camadas a cada
  0,025–0,05 s); `VFXPiloto._politicaContato` tira brilhos Light/Core de ~1 s do acerto e limita
  camadas longas a 0,45 s; `brilho` realça o Punch do pacote; luz de impacto `BB_LuzContato18`
  (máx. 8, 1 por dono a cada 0,12 s); `ctx.segurar` congela o pico junto com a pausa dos corpos
  (Efeitos: 0,04/0,08, nunca em rajada/bloqueio); `Camera.socoFov`/`impulsoFov` (−6°, Back Out,
  desligado com o tremor); Animador aceita AnimationConstraint.
- Instalador: comando novo `instalar` (`Runtime.install` = test + publish, uma chave só, mesmas
  travas). `testar`, `testar-nuvem`, `publicar` e `resume` continuam iguais.
- Ferramentas novas: `tools/tests_vfx18.luau`, `tools/teste_nuvem18.luau`,
  `tools/previa_vfx18.py` (prévia offline com as texturas reais; o cache é uma pasta fora do repo
  com `<id>.png` de cada textura, baixadas da API pública de miniaturas; resultado em
  `docs/previa_hit18.jpg`), `tools/migracao18.py` (Place AJ13 do repo migrado pelos instaladores 14→17 do git e AJ18
  sobre cada um; confere fontes, objetos e blocos de propriedade).
- Pendentes: sons de espada (ElevenLabs ocupado na AJ13) e os sons de impacto/explosão que o
  Kaique vai mandar; conferência no celular dos 5 itens do README18.
- Próxima etapa: copiar gerar_ajuste18 → 19, criar `installer14/baseline18.json` (sha256 das
  fontes `src/` no commit da AJ18), aceitar 19 em package/runtime (tuplas e regex do resume),
  teste_nuvem19 com `cfg.stage>=18` no bloco da 18 e acrescentar a AJ18 em `ETAPAS` da migração.

## AJUSTE-17 — preparada pelo ChatGPT (histórico; sem confirmação de instalação)

Kaique confirmou no chat em12/11/2026: AJUSTE-16 publicada e funcionando.
A AJ17 implementa contatos legíveis, cronologia remota ORA/MUDA, botões personalizáveis,
preferências persistidas e laboratório de treino, mais contraste visual.
Leia docs/README_AJUSTE17.md e VALIDACAO_AJUSTE17.md. Build: tools/gerar_ajuste17.py.
IA somente testes locais; não assumir teste Saved ou publicação17 até resultado do dono.
Não pedir novamente se16 funciona. Preservar ~/.bizarre_instalador e qualquer active-write.
Sem setup/assets-upload; testar/testar-nuvem/publicar/resume com BIZARRE_AJUSTE17.py.
Confirmação própria PUBLICAR AJUSTE17, fontes14/15/16 reconhecidas e estado17 separado.
As seções antigas abaixo são histórico; não regenerar instaladores anteriores com fontes17.

## AJUSTE-16 — publicada e funcionando

Confirmação visual/instalação veio do usuário. Artefato anterior preservado em dist/.
Mapa, câmera, Golpes/Regras, estatísticas e mídias continuam preservados na17.

## AJUSTE-15 — continuação atual

Leia [README_AJUSTE15.md](docs/README_AJUSTE15.md) e [PLANO_AJUSTE15.md](docs/PLANO_AJUSTE15.md).
AJ14 teve teste nativo aprovado e publicação v36 confirmada pelo usuário. AJ15 atualiza SC/MR,
preparada/testada offline; não assumir instalação/publicação15 sem resultado do usuário.
Use BIZARRE_AJUSTE15.py testar/testar-nuvem/publicar/resume; confirmação PUBLICAR AJUSTE15.
Preservar inteiro ~/.bizarre_instalador e14; não repetirsetup/assetsupload. Gerar com tools/gerar_ajuste15.py.
As instruções14 abaixo são histórico/base, não substituir a15 por14 ao continuar.

## Estado atual

- Kaique confirmou que a **AJUSTE-13 instalada** tem animação e câmera funcionando.
- A **AJUSTE-14** é o piloto de combate/VFX de **Star Platinum e The World**.
  Os outros quatro kits mantêm seu comportamento; o perfil de iluminação é global.
- Leia [README_AJUSTE14.md](docs/README_AJUSTE14.md), o plano aprovado
  [PLANO_AJUSTE14.md](docs/PLANO_AJUSTE14.md) e [VALIDACAO_AJUSTE14.md](docs/VALIDACAO_AJUSTE14.md).
- Testes locais e inspeção do Place são verificações offline. Não representam uma partida,
  renderização, física, autorização online de texturas, FPS ou publicação no Roblox.
  O último resultado real da instalação sempre vem de Kaique.

## Instalar a AJUSTE-14

O instalador novo baixa o **Place completo atual** e altera somente Sources reconhecidas,
acrescentando módulos e o catálogo visual sanitizado. Não reconstrói Morioh.
Não usar o antigo `install --substituir` para esta entrega.

```sh
python ~/BIZARRE_AJUSTE14.py testar
python ~/BIZARRE_AJUSTE14.py testar-nuvem
```

`testar` confere a integridade offline, sem chave/rede. `testar-nuvem` pede a chave oculta,
preserva backup, cria **Saved** se necessário e testa essa versão no motor. A versão
Published continua a mesma. Somente após **TESTE APROVADO**, com autorização do dono:

```sh
python ~/BIZARRE_AJUSTE14.py publicar
```

Ele exige `PUBLICAR AJUSTE14`. Se a resposta de um envio ficar incerta, use `resume`;
nunca repetir POST ou apagar `~/.bizarre_instalador/active-write.json`.
Preserve toda a pasta `~/.bizarre_instalador`, inclusive recibos anteriores.

## Regras

- Nunca pedir senha, cookie ou chave no chat; nunca colocar segredo em código, arquivo ou log.
  Chave somente `getpass` no Termux, mantida em memória durante o comando.
- Nunca publicar sem confirmação, resetar Place/DataStore ou trocar de universo.
- Fonte desconhecida bloqueia e exporta ZIP para revisão; não forçar ou reconstruir uma base.
- Manter Morioh/colisões, seis Stands, R6, andar/correr do dono, mira manual/Shift Lock,
  distância de câmera aprovada, IDs de mídia, áudios e progresso.
- VFX são dos pacotes reais enviados pelo dono. Código de modelos externos nunca é executado.
  Texturas/sons opcionais indisponíveis recebem aviso/fallback; não inventar IDs nem reenviar mídias.
- ORA/MUDA completos 4,6 s, sem cancelamento voluntário. Qualidade alta, sem redução automática
  por FPS nesta etapa. Não ampliar o piloto aos quatro outros kits sem validar com Kaique.

## Fontes e ferramentas

- `src/ReplicatedStorage/BB/PerfilCombate14.luau`: política de sequência, buffer e extensão aérea.
- `src/ServerScriptService/BB_Servidor/`: validação de golpes, hitbox, projéteis e sessões de tempo.
- `src/ReplicatedStorage/BB/VFXReceitas.luau`, `Cliente/VFXPiloto.luau`, `Cliente/Apresentacao14.luau`:
  receitas, renderer e integração de previsão/confirmação.
- `assets/vfx14/`: catálogo RBXM/XML, manifesto de origem e propriedades.
- `Cliente/Camera.luau`, `Cinematica.luau`, `AmbienteVisual14.luau`: câmera, ULT e iluminação.
- `Cliente/PreviaVFX14.luau`: **ADM → PRÉVIA VFX**, cena local de 6,2 s sem dano/remotos/áudio de ataque.
- `installer14/`, `tools/gerar_ajuste14.py`: patcher e protocolo de envio. Baseline AJ13 registrada
  em `installer14/baseline13.json`; `tools/teste_nuvem14.luau` é o teste nativo desta entrega.
- `tools/instalador_modelo.py` e o montador antigo são históricos, não o caminho AJ14.

Build, da raiz do repositório:

```sh
python3 bizarre/tools/gerar_instalador.py AJUSTE-14
/caminho/do/lune run bizarre/tools/teste_geral.luau
python3 bizarre/tools/lint.py
cd bizarre
python3 -m unittest discover -s tests
```

Rode também os testes `tools/tests_*14*.luau` descritos no relatório de validação. Ao mudar
uma Source, gere novamente o instalador e seus hashes; não entregar só um fragmento.
