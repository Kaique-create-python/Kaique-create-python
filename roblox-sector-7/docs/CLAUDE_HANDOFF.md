# Handoff para Claude — SETOR 7

**REGRA EXPRESSA DO USUÁRIO: NÃO ADICIONAR PLACAS, LETREIROS OU TEXTO NO AMBIENTE.** Foram removidos do código e do Studio todos os letreiros, `SurfaceGui`, `TextLabel`, fundos de placas e letras da porta. Não os recriar no acabamento. Os painéis metálicos estruturais das paredes permanecem. Instruções e textos narrativos pertencem ao HUD, aos prompts e aos painéis de leitura da interface.

## Escopo e estado deste documento

Base Roblox de terror em instalação soviética subterrânea fictícia, em 1989. A prioridade é uma missão curta jogável com R6, corrida/estamina, lanterna, câmera suave e HUD que funcione no celular. As cinco fotos fornecidas pelo usuário orientam os túneis e a atmosfera. Claude continuará o acabamento visual e a expansão.

Este documento registra o contrato de integração de `PROJECT.md`. Os resultados observados, testes realizados e limites da entrega estão em [VALIDATION.md](VALIDATION.md), mantido pelo integrador. Consultar também [MAP.md](MAP.md), [STORY.md](STORY.md) e [ANIMATIONS.md](ANIMATIONS.md). O mapa final possui 1515 Parts e nenhuma inscrição ambiental.

## Estrutura contratada

| Fonte local | Destino / função no Studio |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Sector7`; inclui `Config` como ModuleScript e lógica compartilhada. |
| `src/server` | `ServerScriptService.Sector7`; `Server` é Script, demais módulos são irmãos. |
| `src/server/WorldBuilder.luau` | ModuleScript `WorldBuilder`; `Build()` cria e retorna `Workspace.Sector7World`. |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Sector7Client`, LocalScript. |

Dependências externas não fazem parte do contrato. O mapa é procedural determinístico, feito com Parts, e a progressão é cooperativa por servidor, sem persistência.

## Contratos que o acabamento deve preservar

Remotes em `ReplicatedStorage.Sector7.Remotes`:

| Nome | Tipo / payload |
| --- | --- |
| `Sprint` | `RemoteEvent`, cliente envia boolean. |
| `Flashlight` | `RemoteEvent`, cliente envia boolean. |
| `Feedback` | `RemoteEvent`, servidor envia tabela `{kind, title, text}`. |

Estado replicado por atributos:

| Alvo | Atributos |
| --- | --- |
| `Player` | `Stamina` (0..100), `Sprinting`, `Exhausted`, `FlashlightOn`, `Escaped` (booleanos). |
| `Workspace` | `S7Fuses` (0..3), `S7Power`, `S7Keycard`, `S7Escaped` (booleanos). |
| Acessibilidade local | `ReducedMotion`, `CameraBlurEnabled`. |

O servidor deve decidir velocidade, estamina e progressão, além de validar payload, frequência, vida, distância e pré-requisitos das interações. O cliente apresenta estado, envia intenção e controla os efeitos locais. Notas podem ser lidas sem alterar a ordem da missão.

Peças interativas usam atributo `InteractionId`: `Fuse1`, `Fuse2`, `Fuse3`, `Generator`, `Keycard`, `Exit`, `Note1`..`Note4`. Cada peça tem `ProximityPrompt` com `ActionText` em português e controles de teclado, gamepad e touch. Preservar os IDs ao substituir os placeholders visuais.

## Percurso e missão

Spawn previsto em `(0, 3, 12)`. O corredor principal segue o eixo `-Z` até aproximadamente `-190`, com salas laterais: depósito, máquinas, arquivo e saída. O builder deve incluir `CreatureNodes` (Folder de Parts invisíveis para rotas) e `ExitDoor` (BasePart). A zona final fica além da porta, perto de `z=-180`.

Sequência: recolher três fusíveis → acionar o gerador → pegar o cartão → liberar a saída → atravessar a zona de evacuação. Os prompts devem explicar o requisito ausente. O estado global é compartilhado; `Player.Escaped` identifica quem terminou. Conferir na implementação como o estado global `S7Escaped` é usado antes de criar regras de vitória de todo o grupo.

## Movimento, câmera e interface

Valores iniciais previstos: `WalkSpeed=10`, `SprintSpeed=18`, `MaxStamina=100`, `DrainRate=22`, `RegenRate=16`, `RegenDelay=1.5`, `RestartThreshold=30`.

Câmera prevista: `BaseFov=74`, `SprintFov=80`, `BobStrength=0.045`, `MaxBlur=4`. Respeitar movimento reduzido e permitir desativar blur. Aplicar efeitos sem acumular rotação/deslocamento entre frames ou após respawn.

Preservar suporte a PC, touch e gamepad. No celular, os botões de corrida e lanterna devem ficar livres do joystick, salto, recortes e safe areas; estados de esgotamento precisam ser visíveis. O efeito de tela deve cobrir proporções diferentes sem bordas vazias. Acabamento visual não deve esconder objetivo, notas ou feedback.

## Personagem e animações

R6 é requisito. Conferir o primeiro spawn e o respawn com `Humanoid.RigType`. `ANIMATIONS.md` traz os resultados reais da pesquisa e as referências oficiais da API R6.

IDs de modelos do Creator Store são candidatos para inspeção, não IDs de clipes. O modelo gratuito `16823872202` foi inspecionado em `ServerStorage`; seus clipes `Walk=16817753747` e `Run=16817762547` falharam por permissão e não foram integrados. O modelo foi removido e nenhum script de terceiros acompanha a entrega. `Config.Animations` permanece com `Walk`, `Run` e `Idle` vazios. O fallback padrão R6 foi verificado no Studio. Os demais candidatos tiveram apenas metadados consultados; detalhes em [ANIMATIONS.md](ANIMATIONS.md).

## Próximos passos de acabamento

1. Ler o código final e os registros de validação antes de alterar o contrato.
2. Substituir ou detalhar Parts mantendo colisão, conexão entre salas, espaço R6 e identificadores interativos.
3. Refinar concreto úmido, tubulações e iluminação de emergência seguindo as fotos; manter o caminho principal compreensível pela geometria e pela luz, preservando a ausência de placas e letras.
4. Refinar a ameaça e o áudio a partir de assets autorizados. A história está em `STORY.md`; o jogador precisa entender a missão sem ler todas as notas.
5. Escolher animações somente após inspeção e teste. Manter esta base sem compras automáticas.
6. Repetir o percurso inteiro em PC e celular e testar morte/respawn após as alterações.

## Evidências de validação

Consultar [VALIDATION.md](VALIDATION.md) para o registro final do integrador, incluindo missão, primeiro spawn/respawn R6, animações, interface e limitações de testes. Não transformar uma verificação visual ou local em alegação de teste cooperativo ou de servidor publicado sem a evidência correspondente.
