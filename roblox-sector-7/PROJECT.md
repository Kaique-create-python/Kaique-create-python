# SETOR 7 — base jogável

Pedido: jogo de terror Roblox em base russa subterrânea, túneis baseados nas cinco fotografias do usuário, R6 obrigatório, estamina, câmera com balanço e desfoque suave, HUD responsivo cobrindo telas de celular. Priorizar programação funcional e arquitetura clara; Claude continuará o acabamento.

Correção explícita do usuário: remover TODAS as placas e letreiros do cenário e não adicionar novas placas. Não usar sinalização, textos em paredes ou marcações na porta. Os painéis metálicos de construção não são placas de sinalização; os documentos coletáveis continuam como objetos pequenos da história.

Decisões de implementação: Luau sem dependências; mapa procedural determinístico com Parts, arquitetura modular, progresso cooperativo por servidor sem persistência. Uma missão curta: três fusíveis, gerador, cartão e evacuação, com ameaça simples e notas narrativas. Nome provisório SETOR 7: O Último Sinal, 1989, instalação soviética fictícia.

## Plano
- [x] Configuração compartilhada e lógica pura de estamina/progresso com testes em Studio.
- [x] Túneis abobadados, canos, trilhos, sala de máquinas, arquivo, saída; mapa regenerável sem placas.
- [x] Servidor autoritativo para estamina, interação, missão, ameaça e respawn R6.
- [x] Cliente: corrida PC/touch/gamepad, lanterna, câmera ajustável, animação, HUD responsivo com safe areas.
- [x] Integração no Studio via plugin, playtest e verificações PC/celular no simulador, correções. Limites em docs/VALIDATION.md.
- [x] README, história, arquitetura, roteiro de testes e handoff Claude; artefatos prontos para o repositório indicado.

## Contrato de integração
ReplicatedStorage.Sector7.Config (ModuleScript); Remotes.Sprint (RemoteEvent, boolean), Remotes.Flashlight (RemoteEvent, boolean), Remotes.Feedback (RemoteEvent, table {kind,title,text}). Estado em atributos Player: Stamina (0..100), Sprinting (bool), Exhausted (bool), FlashlightOn (bool), Escaped (bool). Estado em atributos Workspace: S7Fuses (0..3), S7Power (bool), S7Keycard (bool), S7Escaped (bool). Atributos de acessibilidade locais: ReducedMotion, CameraBlurEnabled.

WorldBuilder.Build() cria Workspace.Sector7World e retorna Model. Mapa: spawn (0,3,12), corredor principal ao longo de -Z até -190, salas laterais. Interações por BasePart com atributo InteractionId: Fuse1, Fuse2, Fuse3, Generator, Keycard, Exit, Note1..Note4. ProximityPrompt filho: ActionText português, E/buttonX/touch. Ameaça gerada por servidor; zona final além da porta z=-180. Builder deve incluir CreatureNodes Folder com Parts invisíveis de rotas e ExitDoor (BasePart).

Cliente em StarterPlayer.StarterPlayerScripts.Sector7Client (LocalScript). Servidor em ServerScriptService.Sector7.Server (Script), demais módulos irmãos. Fontes em src/shared, src/server, src/client; builder como src/server/WorldBuilder.luau. Config: WalkSpeed=10, SprintSpeed=18, MaxStamina=100, DrainRate=22, RegenRate=16, RegenDelay=1.5, RestartThreshold=30; Camera={BaseFov=74,SprintFov=80,BobStrength=0.045,MaxBlur=4}; Animations={Walk='',Run='',Idle=''} (IDs opcionais; fallback R6 original ou animação procedural).

## Revisão
Verificar: respawn limpa estado; sprint rejeita tipo/rate e esgota sem spam; interações validam distância/vida/progresso; touch não bloqueia joystick/jump; barras e efeitos cobrem proporções diferentes; ruído visual discreto e movimento reduzido; mapa conexo e altura livre R6.
