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
