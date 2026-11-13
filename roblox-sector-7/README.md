# SETOR 7 — O Último Sinal

Base jogável de terror Roblox em uma instalação soviética fictícia de 1989. Programação funcional, organizada para o Claude continuar a direção de arte e expandir o jogo.

## Abrir e jogar

Abra **[build/Sector7.rbxlx](build/Sector7.rbxlx)** no Roblox Studio e pressione **Play**. O arquivo contém o cenário editável, código e personagem R6. Não exige Rojo, plugins adicionais, compras nem chaves de API.

Alternativa para uma place vazia: cole o conteúdo de `build/InstallSector7.luau` na Command Bar do Studio **fora do Play**. Esse instalador substitui somente as pastas Sector7, o mapa Sector7World e StarterCharacter; use uma place dedicada.

## Jogabilidade

Encontre três fusíveis nas salas laterais, ligue o gerador, recupere o cartão no arquivo e abra a porta de evacuação no fim do túnel. A ameaça desperta quando o gerador liga. Quebre a linha de visão e guarde estamina para fugir. Leia quatro registros para entender o que aconteceu.

| Ação | PC | Celular | Controle |
| --- | --- | --- | --- |
| Correr | Segurar Shift | Botão CORRER alterna | L3 alterna |
| Lanterna | F | Botão LUZ | Y |
| Interagir / ler | Segurar E | Prompt de toque | X |
| Opções | M / MENU | MENU | Select |

As opções permitem reduzir movimento de câmera e desligar desfoque. A estamina fica na parte inferior; ações respeitam a área segura e os efeitos de tela cobrem as bordas. Orientação de celular: paisagem com rotação automática.

## Sistemas

- Personagem R6 próprio em `StarterPlayer.StarterCharacter`, incluindo Animate padrão Roblox.
- Corrida, estamina, atraso de regeneração e bloqueio de exaustão controlados pelo servidor.
- HUD adaptável, controles de teclado/touch/gamepad e notas com rolagem.
- Câmera em primeira pessoa com balanço discreto, inclinação, FOV de corrida e desfoque limitado.
- Lanterna visível para os outros jogadores; interações com validação de distância, vida, linha de visão e sequência da missão.
- Missão cooperativa por sessão, ameaça simples com patrulha, perseguição e dano, morte/respawn.
- Mapa de 1.515 Parts: abóbadas, concreto, painéis de metal enferrujado, tubulações, cabos, trilhos, poças e salas funcionais. Sem placas, letreiros ou textos nas paredes e portas, conforme pedido do criador.

O progresso pertence ao servidor atual e sobrevive à morte do jogador. Uma nova sessão reinicia a missão. Não há persistência, inventário complexo, monetização, lobby ou matchmaking nesta base.

## Continuar com Claude

Comece por [docs/CLAUDE_HANDOFF.md](docs/CLAUDE_HANDOFF.md), [PROJECT.md](PROJECT.md), [docs/MAP.md](docs/MAP.md) e [docs/STORY.md](docs/STORY.md). [docs/VALIDATION.md](docs/VALIDATION.md) distingue os testes realizados das pendências. [docs/ANIMATIONS.md](docs/ANIMATIONS.md) registra pesquisa e limitações do catálogo.

O mapa não depende de imagens externas. As cinco fotos enviadas na conversa orientaram a geometria e os materiais; as fotos não foram republicadas no repositório.

## Fontes e reconstrução

`src/shared`: configuração e estamina pura. `src/server`: missão, servidor, ameaça e gerador do mapa. `src/client`: interface, entradas e câmera. `tests/Core.spec.luau`: testes de estamina e progressão executados no Studio. `tools/ExportSnapshot.luau` exporta uma snapshot de Edit; `python tools/build_place.py` gera o `.rbxlx` e instalador a partir da snapshot em `build/studio-snapshot.json`.

Para reconstruir o cenário no Studio: `require(game.ServerScriptService.Sector7.WorldBuilder).Build()` na Command Bar fora do Play. Não execute uma reconstrução durante uma partida: as conexões dos prompts pertencem ao mapa inicial.

Os valores estão em `src/shared/Config.luau`; não há serviço externo de configuração nesta versão. Ao alterar fontes locais, atualize os Scripts no Studio via instalador, exporte nova snapshot e reconstrua os artefatos. O instalador é gerado das fontes; a place é gerada da snapshot do Studio.
