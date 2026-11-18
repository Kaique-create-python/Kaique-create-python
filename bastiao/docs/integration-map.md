# Mapa de integração (Tarefa 0 do plano) — Projeto Bastião sobre a base Sector7

Medido no `place_original.rbxl` enviado (SHA-256 começa com `8d3e6b78`), 9.004 instâncias.

## O que já existia (e continua intocado)

| Parte | Onde | Papel |
|---|---|---|
| Mapa | `Workspace.Sector7World` (Structure, Details, Lamps, RoomAnchors, BunkerSpawn, SpawnPoint) | 8.572 peças. Chão em y = 0. Túnel central x = 0 (z 24 → −510, largura 14,8), cruzamentos em z −80/−260/−440, anéis de serviço em x = ±58, salas 48×44 (oeste x = −88: Barracks −140, Armory −220, Infirmary −320, Storage −400; leste x = +88: Command −140, Communications −220, Workshop −320, Utilities −400), GeneratorHall (0, −535). Vãos das salas em x = ±65,36, z ±6 do centro (12,0 de largura, 8 de altura). |
| Servidor | `ServerScriptService.Sector7.Server` (+ Environment, MilitaryProps, WorldBuilder) | Coloca cada personagem em (0, 4, 12) depois de pedir streaming; fôlego (WalkSpeed 10, corrida 18); lanterna de peito. Usa o mapa salvo (não reconstrói). |
| Cliente | `StarterPlayerScripts.Sector7Client` (BodycamCamera, BodycamLook, BodycamHUD, Spring) | Primeira pessoa de bodycam, HUD OSD (RobotoMono, tela de desenho 1280×720), teclas Shift/F/M/Esc. **E** fica livre para os prompts. |
| Personagem | `StarterPlayer.StarterCharacter` (R6) | Jogadores com túnica oliva; o Pavel usa um clone com uniforme cáqui. |
| Iluminação | `Sector7.Environment` | Quase escuro (ambiente 12,14,14), neblina 55–200; luz vem das 48 lâmpadas e da lanterna. |
| Streaming | `Workspace.StreamingEnabled = true`, sinais `Deferred` | O cliente só tem o que está perto: giroflex e prompts tratam peças que entram e saem. |

## O que a Etapa 1 acrescenta (18 scripts, só nomes `Bastiao...`)

| Script | Classe | Função |
|---|---|---|
| `ServerScriptService/BastiaoServidor` | Script | Boot: remotos → espera o mapa → cenário → valida o capítulo → missão. Se algo faltar, não começa (o jogo base segue igual). |
| `…/StoryRunner` | ModuleScript | Núcleo determinístico: `Step(def, estado, evento)`; evento repetido não avança; efeito com chave única. |
| `…/StoryValidator` | ModuleScript | Confere o capítulo (referências, entidades, flags, alcance de todos os nós, final). |
| `…/Capitulo01` | ModuleScript | Conteúdo declarativo: nós, saídas, sequências com tempo. |
| `…/Mundo` | ModuleScript | Estado desejado de cada entidade; idempotente; retrato para checkpoint. |
| `…/Missao` | ModuleScript | Fila serial de eventos; aplica efeitos (entidade, objetivo, sequência, checkpoint). |
| `…/Sequencias` | ModuleScript | Deixas com tempo → legendas/sons para os clientes e mudanças no mundo; avisa `<seq>_fim`. |
| `…/Interacoes` | ModuleScript | Valida no servidor: vivo, alcance (≤ 10 studs; prompt aparece a 7), anti-repetição 0,4 s, estado, etapa esperada, regra própria. |
| `…/Zonas` | ModuleScript | Chegadas medidas no servidor (sem Touched), com condição (ex.: Pavel já na porta). |
| `…/Checkpoint` | ModuleScript | Último ponto seguro do servidor + lugar de renascer. |
| `…/Cenario` | ModuleScript | Cria as peças em `workspace.BastiaoHistoria` e registra as entidades. |
| `…/Pavel` | ModuleScript | NPC R6 (clone do StarterCharacter), rotas medidas, animações R6 padrão, vira para quem está perto. |
| `ReplicatedStorage/BastiaoCompartilhado` (+ `Textos`) | ModuleScript | Nomes de remotos/atributos e todos os textos em pt-BR. |
| `StarterPlayerScripts/BastiaoCliente` (+ Interface, Prompts, Giroflex) | LocalScript | Objetivo, legendas, avisos, alerta, corte, cartão final, prompts no estilo bodycam, giro dos giroflex. |

Em tempo de execução: pasta `workspace.BastiaoHistoria` (atributo `BastiaoDono`), remotos
`ReplicatedStorage.BastiaoRemotos.Apresentacao`, atributos no módulo compartilhado
(`BastiaoObjetivo`, `BastiaoAlarme`, `BastiaoFimEtapa`, `BastiaoEtapa`, `BastiaoErro`), tag
`BastiaoGiroflex`, grupos de colisão `BastiaoNPC` × `BastiaoJogador` (Pavel não empurra ninguém).

## Onde fica cada coisa (medido; o teste de cenário confere tudo)

| Peça | Posição | Observação |
|---|---|---|
| Pavel (cena 1) | (3,4; 0; 2,2) | 10,4 studs do spawn: um passo dispara a cena. |
| Caixa, rádio, caneca, lista | caixa em (6,0; 0; 1,6) | encostada na parede leste do túnel; lista virada para quem chega. |
| Relógio 02:49 | parede oeste do túnel, z 1,5, y 4 | abaixo da bandeja de cabos. |
| Painel ACESSO EXTERNO | antepara atrás do spawn (2,6; 6; 23,98) | entre os reforços. |
| Carregador e módulo | parede norte do arsenal (−88; 0; −198,15) | entre as juntas da parede. |
| Terminal externo da enfermaria | corredor oeste (−65,0; y 2,15–4,85; −306) | abaixo da abóbada. |
| Porta de contenção | vão da enfermaria (x −65,36; z −326…−314) | duas folhas de 6,0, fechadas; vapor pela vedação. |
| Porta da oficina | vão da oficina (x 65,36) | folhas deslizantes que somem dentro da parede quando abertas. |
| Trava (alavanca) | lado de dentro (65,8; 3,8; −305) | ao lado de onde o Pavel espera. |
| Terminal da oficina | parede norte da oficina (88; 0; −298,15) | entre as estantes. |
| Giroflex | 7 pontos: túnel (z −5, −70), anel oeste (z −290), cruzamento z −260 (x ±22/30), anel leste (z −290, −334) | entre as juntas que se repetem a cada 22 studs. |

## Entidades e estados

`pavel` (tunel, arsenal, enfermaria, porta_oficina, oficina) · `relogio` (0249) ·
`radio` (guardado, oferecido, entregue) · `bateria` (no_carregador, disponivel, carregada,
encaixada) · `terminal_enfermaria` (sem_energia, ligado, autorizado) · `porta_contencao`
(trancada, vazando, destravada) · `alarme` (desligado, ligado) · `acesso_externo` (aberto,
bloqueado) · `porta_oficina` (aberta, trancada, travada) · `terminal_oficina` (apagado,
aguardando, lista) · `fim` (oculto, visivel).

Flags do plano usadas: `radio_checked`, `battery_collected`, `medical_terminal_powered`,
`exercise_started`, `maintenance_reached`, `partial_roster_found`. (`equipment_checked` entra
com o rifle.)

## Próximos encaixes

- Cena 2 (rifle no estande) entra como novo nó entre `radio_ordem` e `ordem`.
- Cena 6 (perseguição) entre `ir_oficina` e `fechar_trava`, com o monstro (CreatureController,
  EncounterDirector) e checkpoint antes do encontro.
- Sons: cada `som`/`fala` já tem chave estável; basta ligar um id de áudio por chave.
