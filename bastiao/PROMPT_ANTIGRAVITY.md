# PROJETO BASTIÃO — contexto para continuar (Antigravity)

Jogo de terror no Roblox. Place 89520940302906, Universe 10776462844.
AGORA você trabalha DIRETO no Roblox Studio pelo plugin (MCP do Studio), no PC. Não use Termux,
Open Cloud nem os instaladores `.py` (eles eram o caminho antigo, do celular). Responda sempre em
português, simples e passo a passo.

Como trabalhar no Studio:
- Os scripts do Bastião já estão no Place (ServerScriptService.BastiaoServidor, ReplicatedStorage.
  BastiaoCompartilhado, StarterPlayerScripts.BastiaoCliente). Edite-os lá; o GitHub é referência.
- Antes de mexer, salve uma cópia do Place (File > Save to File) como backup.
- Teste com Play no Studio (lá a física roda: monstro andando, animações e sons dá para ver).
- Publicar (File > Publish to Roblox) só quando o dono pedir e depois de testar.

## Regras que nunca podem ser quebradas
1. Nunca peça a chave Open Cloud no chat. O instalador pede escondido no Termux (getpass).
2. Nunca resetar o Place nem DataStores (progresso dos jogadores).
3. Não apagar/mover/editar o mapa `workspace.Sector7World`, o HUD da bodycam (`Sector7Client`)
   nem scripts `Sector7.*`. Só ACRESCENTAR coisas com nome `Bastiao*`.
4. Efeitos visuais só de pacotes da Creator Store (nada desenhado por código ou IA).
5. Publicar só depois de testar no Studio e com o dono confirmando.
6. Não pôr nome de modelo de IA em commits. E-mail do dono é privado.

## Código
GitHub: `Kaique-create-python/Kaique-create-python`, branch `claude/context-capture-w0uo2t`,
pasta `bastiao/`. Leia `bastiao/README.md`, `bastiao/LEIA_CHATGPT.md`,
`bastiao/ferramentas/etapa3/LEIA.md` e os patches em `bastiao/docs/CORRECAO*_*.patch`.

## Estado atual
- Etapa 1 e 2 publicadas: abertura (Pavel NPC, rádio, módulo, enfermaria, alarme, oficina,
  terminal), 3 línguas PT/EN/RU, som com eco/rádio.
- Etapa 3 (pacote do ChatGPT `BASTIAO_ETAPA3.py`, extraído no celular em
  `~/.bastiao_etapa3/pacote_41f942860b4357c61692`) instalada com as correções
  `bastiao/dist/CORRIGIR_ETAPA3_3.py`, `_4.py` e `_5.py` (aplicar no lugar; nunca baixar um pacote
  novo inteiro, senão perde os recibos e reenvia assets duplicados).
- Monstro 731-A: modelo GLB 46 ossos + 35 animações (rbxm) já enviados ao Roblox. Aparece quando
  a porta de contenção destrava e o alarme liga; anda pelos trilhos dos corredores (grafo em
  `src/server/Criatura.luau`), persegue quem vê, nunca entra na oficina (sala segura).
  Correção 5 (andar/perseguir + rugido mais alto e grave) entregue; falta confirmar no jogo.
- Teste na nuvem (Open Cloud Luau execution) NÃO roda física nem cria Player: o teste já usa
  jogadores falsos e confere o conteúdo das animações em vez de tocá-las.
- 36 sons novos não foram gerados (ElevenLabs gratuito bloqueado). No Studio, dá para usar sons
  da biblioteca do Roblox (Toolbox > Audio) ou importar arquivos que o dono mandar.
- Se a correção 5 (`bastiao/dist/CORRIGIR_ETAPA3_5.py`) ainda não estiver no Place, aplique à mão
  as mudanças de `bastiao/docs/CORRECAO5_MONSTRO_ANDAR_SOM.patch` nos scripts Criatura e Foley.

## O que fazer agora
1. Confirmar com o dono se o monstro anda, persegue e ruge forte após a correção 5.
2. Melhorar o encontro: primeira aparição marcante no corredor do meio (luz piscando, rugido),
   batidas na porta da oficina depois de trancar, sons de passos/respiração mais pesados.
3. Próxima etapa da história conforme o plano mestre (abaixo): objetivo "piso" depois da lista.

## Arquivos (links abertos)
- Plano mestre (PDF): https://drive.google.com/file/d/1O52ssdla6Fp0fqIGe4tnK0GN9v2XYvvK/view
- História completa: https://drive.google.com/file/d/1WjiJiwCCpoNwlGUOqgw787qGXSTDxKyg/view
- Contexto completo (zip): https://drive.google.com/file/d/1WSohe20iPa5BXgN-j5uPRwpkdsr0VeZ7/view
- Monstro 35 animações R6 (zip): https://drive.google.com/file/d/1TOVV4_t-RW0hpFs95JGWEwrKIur__uwa/view
- Monstro + áudio Etapa 3 (zip): https://drive.google.com/file/d/1lGW-BuktjsmldjTeloO2ESG19dThOjZw/view
- Prévia das animações (vídeo): https://drive.google.com/file/d/1kvCddvBmKKKE3KTEsL6CQCZvLzl2clCe/view

## Correção 7 (feita depois deste prompt): menu 3D, legendas Miside, lanterna e sons
`bastiao/dist/CORRIGIR_ETAPA3_7.py` (patch em `bastiao/docs/CORRECAO7_MENU3D_LEGENDAS_SONS.patch`) já faz
os itens 1 a 4 abaixo pelo caminho do celular: módulo novo `BastiaoCliente/Efeitos` (abertura 3D do menu
por cima do `S7BodycamMenu` sem editar o Sector7, clique da lanterna pelo atributo `FlashlightOn`,
tela tensa na perseguição), legendas letra por letra que quebram em pedaços (`BastiaoCliente/Interface`)
e 4 sons novos do monstro (ElevenLabs). Se ela já estiver no Place, só confira no Play e ajuste; não
refaça. Ainda faltam uns 30 sons pequenos (portas, rádio, cliques, passos dos soldados).

## Correção 8: o que você salvou no Studio foi juntado
A "Perseguição v2" (Criatura) e o `MonstroSom` que você salvou no Place (versão 17, sem publicar) foram
conferidos e juntados com a correção 7 em `bastiao/dist/CORRIGIR_ETAPA3_8.py`
(patch `bastiao/docs/CORRECAO8_PERSEGUICAO_V2_ANTIGRAVITY.patch`). O `MonstroSom` agora é ligado pelo
`BastiaoCliente` com `passos=false` (os passos do monstro já saem pelo Foley).
IMPORTANTE: o instalador do celular só troca scripts Bastiao* que ele reconhece. Se você editar um
script Bastiao* no Studio e salvar, o próximo `testar-nuvem` do celular para com "fonte desconhecida"
(de propósito, para não apagar seu trabalho). Avise o dono para mandar o ZIP de revisão ao Claude.

## Pedidos do dono que ficaram para você (fazer no Studio, testar com Play)
A correção 6 (`bastiao/dist/CORRIGIR_ETAPA3_6.py`, patch em `bastiao/docs/CORRECAO6_MONSTRO_SOM_FORTE.patch`)
já deixa o rugido no máximo (grave, estourado, eco, mais longo), os passos 5x com eco e o monstro
sem boiar. Se ela não estiver no Place, aplique o patch à mão. Depois faça:

1. **Menu com abertura cabulosa em 3D** (o menu da bodycam é do `Sector7Client`: o dono AUTORIZOU
   mexer nele agora, mas faça backup e não quebre câmera, lanterna, fôlego e HUD). Animação de
   abertura com profundidade (ViewportFrame/CanvasGroup, peças entrando em camadas, leve parallax,
   brilho e ruído de bodycam), bem detalhado e legível no celular. Pode usar Figma para desenhar.
2. **Diálogos estilo "Miside" (jogo da Mita)**: as legendas (`BastiaoCliente/Interface`) aparecem
   letra por letra com leve profundidade 3D (rotação/escala por letra) e, ao sumir, se quebram em
   pedacinhos que caem e somem. Manter as 3 línguas (PT/EN/RU) e o tamanho legível no celular.
3. **Sons pequenos**: clique da lanterna (ligar/desligar; detecte a luz da lanterna mudando, sem
   editar a lógica do Sector7), passos dos jogadores mais presentes, rangidos e metais do bunker.
   ElevenLabs só se o dono tiver plano pago (a conta grátis foi bloqueada). Sem pago, use sons
   da biblioteca do Roblox (Toolbox > Audio).
4. **Monstro**: conferir no Play que ele ronda, vê, ruge virado para o jogador, persegue e nunca
   entra na oficina. Deixar a perseguição tensa (luzes piscando perto dele, tremor leve de câmera).

## Correção 9: o monstro mata (jumpscare), passos no pé, menu 3D de verdade e Pavel vestido
`bastiao/dist/CORRIGIR_ETAPA3_9.py` (patch em `bastiao/docs/CORRECAO9_JUMPSCARE_PASSOS_MENU_PAVEL.patch`):
- **Captura**: quando a garra alcança alguém, o monstro segura a vítima na frente dele e toca
  `30_JUMPSCARE_FRONTAL_GRAB` (ou `31_JUMPSCARE_FROM_BEHIND` se ela estava de costas). No marcador
  `Impact` a vítima morre (`Health = 0`) e depois o monstro solta e volta a rondar. Atributos:
  `BastiaoCapturado`/`BastiaoCapturaTipo` no jogador; `BastiaoCapturaVitima`/`BastiaoCapturaSerial` no monstro.
- **Jumpscare** (cliente, `BastiaoCliente/Efeitos`): câmera presa no rosto do monstro, tremor, FOV 42,
  estática, clarão vermelho no rugido e corte para preto no golpe; a câmera volta ao renascer.
- **Oficina**: quem se tranca lá ouve o monstro esmurrar a porta (`17_ESMURRAR_PORTA`, tremor e som
  `impacto_porta`); na busca ele fareja e olha para os lados (03/04/05/15).
- **Passos**: saem nos marcadores do pé da animação (`Foot*`/`Land`), bem mais altos na corrida.
- **Menu 3D**: o efeito espera o painel do menu ter tamanho real antes de animar (antes abria normal).
- **Pavel**: uniforme soviético do catálogo (`ApplyDescription`: jaqueta 6865584651, calça 6866147363,
  ushanka 46348897), aponta ao chegar, acena uma vez para cada jogador e olha em volta quando parado.
- 6 sons novos do ElevenLabs: jumpscare, impacto na porta, lanterna liga/desliga, menu abre, legenda quebra.
Se editar esses scripts no Studio, o `testar-nuvem` do celular volta a parar com "fonte desconhecida"
(de propósito). Peça ao dono para mandar o ZIP de revisão ao Claude antes.

## Correção 11: menu 3D de verdade + capítulo 2 (parte 1) com o AK-74
`bastiao/dist/CORRIGIR_ETAPA3_11.py` vai EM CIMA da `CORRIGIR_ETAPA3_10_CODEX.py` (recusa se ela não estiver
aplicada). Patch em `bastiao/docs/CORRECAO11_MENU3D_CAPITULO2_ARMA.patch` (base: pacote depois da 10 do Codex).
- **Menu 3D** (`BastiaoCliente/Efeitos`): cópia só visual do `CameraMenu` num SurfaceGui (AlwaysOnTop) sobre uma
  placa fina na frente da câmera, alinhada pelos cantos do painel (ViewportPointToRay, corrigindo a barra do topo
  pela diferença `fx.AbsolutePosition`); gira 82° em perspectiva e encaixa; o painel real volta no fim.
- **Capítulo 2** (`Capitulo02` junta-se ao `Capitulo01` sem mexer nele): depois de `s8_lista_fim` → armário abre
  (`Cenario02`, parede norte da oficina, x 81,5) → `pegar_fuzil` → porta da oficina abre, Pavel vai para a porta
  blindada do anel leste (`pavel2`) → evento `monstro_recuou` (kind `criatura`) ou zona `porta_blindada`
  (59, 3, -389) → fala do elevador sem energia → fim da parte 1 (checkpoint `fim_cap2a`). Próximo: subestação.
- **Arma** (`BastiaoServidor/Arma` + `BastiaoCliente/Arma` + `BastiaoCompartilhado/ArmaModelo`): AK-74 de 62 peças;
  o servidor confere cadência (600/min), munição (30 + 90), origem perto da cabeça e parede no caminho; o acerto no
  monstro é por cápsula (as peças dele têm CanQuery=false). `Criatura.atingir` dá tranco (25/26), 7 acertos em 3,2 s
  → cambaleia/atordoado (27/28) 2,6 s, levanta (29) e foge 9 s; 4 acertos durante uma captura soltam a vítima viva.
- Efeitos com texturas da Creator Store (lista com autores em `Arma.TEXTURAS`). Sons novos do ElevenLabs:
  `ak_tiro`, `ak_recarga`, `bala_carne`, `passos_longe`, `tres_toques_parede`, `alarme`, `portas`.
- Faltam no ElevenLabs: `ak_vazio`, `capsula`, `bala_concreto` e as falas `pavel_armario`, `pavel_instrucao`,
  `pavel_porta`, `pavel_recuou`, `pavel_elevador` (por enquanto só legenda).

## Correção 12: AK-74 detalhado
`bastiao/dist/CORRIGIR_ETAPA3_12.py` vai em cima da 11. Patch: `bastiao/docs/CORRECAO12_ARMA_DETALHADA.patch`.
- Cápsulas com física própria por raio: quicam com tinido, deitam, rolam e somem em 30 s (máx. 60).
- Recuo no padrão do AK-74 e tremor de tela; as mãos tremem com o monstro a menos de 35 studs.
- Recarga em quadros-chave: tática em 2,1 s (fica 30+1) e vazia em 2,6 s (o pente cai no chão e a mão puxa o ferrolho).
- Modo AUTO/SEMI e clique seco que já puxa a recarga.
- Fumaça no cano depois da rajada; clarões laterais do freio de boca.
- Sons novos:
  - prontos: `capsula`, `capsula_b`, `ak_vazio`, `ak_pente_sai`, `ak_pente_entra`, `ak_ferrolho`;
  - ainda gerados pelo `preparar-audio`: `bala_concreto`, `bala_metal`, `pente_chao`.

## Correção 13: mãos, HUD da arma e uniforme SWAT
`bastiao/dist/CORRIGIR_ETAPA3_13.py` vai em cima da 12. Patch: `bastiao/docs/CORRECAO13_MAOS_HUD_SWAT.patch`.
- Luvas táticas com dedos ("Dir*"/"Esq*" no `ArmaModelo`).
- Arma mais baixa, longe e girada (prévia com a mesma conta do cliente: `PREVIA_MAOS_PRIMEIRA_PESSOA.png`).
- O HUD da arma mede os GuiButtons das outras telas e escolhe lugar livre.
- `Pavel.vestirSwat`: veste os jogadores com itens do catálogo. O Pavel usa o mesmo kit, sem balaclava.
  - camisa 1455700999, calça 1455701482;
  - capacete 6602077191, fone 6602071898, óculos 5164438849;
  - balaclava 6238724671, colete 7246494294.

## Correção 14: capítulo 2, parte 2 (a subestação)
`bastiao/dist/CORRIGIR_ETAPA3_14.py` vai em cima da 13. Patch: `bastiao/docs/CORRECAO14_SUBESTACAO.patch`.
- `Cenario03` esconde a `UtilitiesOuterWall` (x 112) e a refaz em volta de uma porta. Nada é apagado.
- Corredor e rampa de 24 studs para baixo até o salão. Salão: x 172..226, z -428..-372, piso em y -23.5.
- Nós novos: `cap2_sub_ir` → zona `subestacao` → 3 fusíveis + `colocar_fusiveis` (relata `fusiveis_ok`) → `religar_disjuntor` → luz volta.
- Depois da luz: `monstro_isca` chama `criatura.atrair(pos)` (API nova no `Criatura`) → zona `porta_blindada` → `c2_descida` → fim (checkpoint `fim_cap2`).
- Próximo: capítulo 3, o andar sem número (o elevador desce).

## Correção 15: capítulo 3, parte 1 (A Guarnição: infectados e blackout)
`bastiao/dist/CORRIGIR_ETAPA3_15.py` vai em cima da 14. Patch: `bastiao/docs/CORRECAO15_CAPITULO3_INFECTADOS.patch`.
- `Capitulo03.juntar(Capitulo02.juntar(Capitulo01))`: a saída da `cap2_descida` vai para `cap3_chegada`.
  - Os efeitos da chegada põem todos na cabine, entregam fuzis e deixam 3 infectados dormindo.
  - Depois vêm, nesta ordem:
    1. zona `cap3_quartel`;
    2. `pegar_cartao`, que dispara o blackout (`luz3=apagada`, atributo `BastiaoBlackout` no workspace) e a onda (`infectados3=acordados`);
    3. evento de criatura `infectados_mortos`;
    4. `abrir_arsenal`;
    5. fim, com o checkpoint `fim_cap3a`.
- `Cenario04`: o andar sem número em y -120 (x -24..24, z -250..-76), longe de todo o resto.
  - Salas: cabine, saguão, corredor, alojamento e arsenal.
  - Detalhes: grades de ventilação que caem, o corpo do tenente com o cartão e 3 caixas de munição.
- `Infectados` (servidor):
  - Clones R6 do StarterCharacter com o uniforme soviético (catálogo), pele doente e olhos Neon.
  - Andam com PathfindingService.
  - Tiro no corpo tira 34; na cabeça, 100. A garra tira 18. Morrem com ragdoll (BallSocket).
  - Atributos para o cliente: `BastiaoEstado`, `BastiaoGrito`, `BastiaoAtaque`, `BastiaoDor`, `BastiaoMorto`, `BastiaoSemente`.
  - A arma do servidor chama `infectados.atingir` e `ouvir`.
- `InfectadosCliente`:
  - Animação procedural no `Motor6D.Transform` (curvado, manca, braço mole, espasmos na cabeça, garra, tranco).
  - Sons na cabeça deles.
  - `ColorCorrection` do blackout quando a câmera está abaixo de y -80.
- Sons do ElevenLabs: `infectado_idle_1/2`, `infectado_grito_1/2`, `infectado_ataque_1/2`, `infectado_dor`, `infectado_morte` e `blackout`.
- Próximo: capítulo 3, parte 2 (o que o arsenal guarda).

## Correção 16: HUD limpo, mira no centro, braços R6, maleta (RE4), soldados e 731-A que aprende
`bastiao/dist/CORRIGIR_ETAPA3_16.py` vai em cima da 15. Patch: `bastiao/docs/CORRECAO16_HUD_MALETA_BRACOS_IA.patch`.
Prévias: `PREVIA_HUD_PC.png`, `PREVIA_HUD_CELULAR.png`, `PREVIA_MALETA_RE4.png`, `PREVIA_BRACOS_R6.png` (também no Figma).
- `Interface`: o `UIStroke` das letras segue o `TextTransparency` (`seguirTexto`); sem isso ficava o contorno preto
  "fantasma" das letras apagadas. As legendas sobem para `DisplayOrder` 12.
- `Arma` (cliente):
  - Mira numa `ScreenGui` própria (`BastiaoMira`) com `ScreenInsets.None`: o centro dela é o centro da câmera.
  - HUD (`BastiaoArmaHUD`, `DisplayOrder` 11, abaixo das falas) com ícones da Creator Store (`Arma.ICONES`).
  - `ocupados()` reserva a área da fala (`Legendas`) e do objetivo (`Topo`).
  - Primeira pessoa: `ArmaModelo.primeiraPessoa` monta braços R6 (`Right Arm`/`Left Arm`, 1x2x1 x 0,45) com luvas e o fuzil 2,4x.
    - O cliente põe `Humanoid` + `Shirt` do jogador nos braços.
    - Pose: `POSE` (0.35, -0.75, -1.45) e `POSE_ANG` (6, 34, 0).
  - Sacar/guardar animado (`troca`). Teclas 1/2, `ButtonY` e a troca rápida (fuzil | mãos | maleta).
- `Arma` (servidor): `api.empunhar(j, bool)` e o remoto `BastiaoArmaEquipar`.
  - Atributo `BastiaoArmaNaMao`. Guardado: o fuzil vai para as costas (solda no `Torso`) e `atirar`/`recarregar` devolvem `guardada`.
  - Na mão do boneco o fuzil tem escala 1,6 (`Arma.ESCALA_MAO`).
  - Cada tiro chama `criatura.ouvir(origem, 150)`.
- `Maleta` (cliente, novo): grade 10x6 estilo RE4.
  - Itens desenhados com `ViewportFrame`: AK, fusível e cartão. A munição usa o ícone da bala.
  - Itens-chave do grupo vêm dos atributos do workspace `BastiaoItemFusiveis` (Cenario03) e `BastiaoItemCartao` (Cenario04).
  - I (ou TAB, se a lista de jogadores estiver desligada) e ↓ abrem. O botão X é `Modal` (solta o mouse). Atributo local `BastiaoMaletaAberta` trava o tiro e esconde a mira.
- `CriaturaCore`/`Criatura`: o 731-A aprende.
  - Ouvido: correndo até 45 studs, andando até 12, devagar nada. Tiro até 150.
  - Memória de "calor" em células de 12 studs (`lembrar`/`pontoQuente`/`visitar`, meia-vida de 240 s): onde viu, perdeu, achou ou ouviu gente.
  - Na ronda e na busca ele volta para revistar esses lugares.
  - `fugiu` sobe o nível (0..3) a cada fuga: cone de visão maior, ouvido +15% por nível e memória +3 s por nível. Atributo `BastiaoAprendizado`.
- Roupas:
  - Jogadores: SSh-68 preto (14041464143), balaclava e Tactical GasMask (7135056846) no rosto, colete.
  - Pavel: SSh-68 verde (14041249070).
  - Infectados sorteiam:
    - camisa e calça: farda soviética ou roupa rasgada com sangue (5473281165/5473285145);
    - cabeça: Korpse Gasmask (8526476888), SSh-68 verde com Toxic Green Gasmask (7170073375), ushanka, ou Dust Mask.
- `InfectadosCliente.pose` (pura, testável): dormindo ficam ajoelhados comendo; correndo se debatem; tropeçam; a cabeça vira para a câmera.
- Testes novos: `tests/client_arma_maleta_test.luau` (11 casos no harness) e casos novos em `server_creature_core_test` e `server_arma_test`.
- Próximo: capítulo 3, parte 2 (o que o arsenal guarda); vitrine no instalador; sons da arma que faltam.
