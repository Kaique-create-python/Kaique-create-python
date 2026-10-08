# Cinzas do Oitavo — primeira campanha jogável

Esta implementação continua a história de `HISTORIA_COMPLETA.txt`. Kael desperta depois de morrer no ataque do Domínio Áureo, encontra a Marca VIII e procura sobreviventes nas Ruínas de Varyn. O jogador recebe informações que Kael pode conhecer neste momento. A origem da marca e os conflitos entre as divindades permanecem mistérios.

Mara e Ivo são novos sobreviventes locais. Mara organiza socorro na praça e fala de modo prático. Ivo vigia um abrigo e usa humor nervoso para disfarçar o medo. Não têm parentesco estabelecido com Kael, poderes secretos ou conhecimento sobre The First.

| Sala | Ambiente e ação | Condição para seguir |
| --- | --- | --- |
| 0 — Distrito Destruído | Casas carbonizadas, estandarte rasgado; recuperar a espada de Kael | Espada recuperada |
| 1 — Praça Central | Fonte quebrada, monumento sem cabeça; provisões, Mara e Veilborn | Baú aberto, Mara ouvida, criatura derrotada |
| 2 — Casas Queimadas | Abrigo fechado; Ivo relata desaparecimento e Kael examina pegadas interrompidas | Ivo ouvido e vestígio examinado |
| 3 — Aqueduto | Arcos antigos e canais; Veilborn mais forte ocupa a passagem | Ameaça derrotada |
| 4 — Portão Norte | Kael alcança a saída e vê o céu escurecer | Cena do portão concluída |
| 5 — Santuário Abandonado | Nave aberta, pedra de descanso e velas | Descanso opcional; capítulo concluído |

O objetivo é global: ao voltar a uma sala anterior, o diário continua mostrando a próxima ação pendente. Cada sala possui passagem à direita e retorno à esquerda. O santuário fecha este incremento e deixa a continuação aberta.

No portão, a marca queima e Kael vê algo semelhante a um olho atrás do Hollow Sun. Ele atribui a visão à fumaça. A cena não identifica a entidade, não confirma a existência de um Oitavo Deus e não revela a verdade sobre Kael.

## Estado e integração

`StoryState` guarda somente a campanha. Os atributos do personagem continuam em `PlayerStats`. Os campos públicos são `introSeen`, `swordFound`, `chestOpened`, `metMara`, `metIvo`, `traceFound`, `bossDefeated`, `questComplete`, `altarUsed`, `zone` e `clearedMask`.

`load(SharedPreferences)` e `save(Editor)` usam `world_version=180`, `world_zone`, `world_cleared_mask` e chaves `story_*`. Um save anterior reconhecido por `has_save` ou `stat_level`, sem `world_version`, inicia no distrito com introdução vista e espada recuperada. O método não modifica HP, Mana, posição, nível, dinheiro ou atributos. O controlador do jogo realoca a posição antiga ao migrar para o novo mapa. Preferências vazias mantêm a introdução e a espada pendentes.

`progressStep()` devolve de 0 a 9 objetivos concluídos em ordem. A conclusão no portão corresponde a 8; o descanso corresponde a 9. `canEnterNext()` verifica os requisitos locais. O bit 1 de `clearedMask` registra a derrota do Veilborn da praça.

`dialogue(id)` devolve páginas `{personagem, fala}` para `intro`, `sword`, `chest`, `mara`, `ivo`, `trace`, `gate`, `altar` e `blocked`. Consultar ou desenhar diálogos não altera nenhum campo. O controlador aplica flags, recompensas e salvamento somente depois da última página, evitando recompensa duplicada ou evento concluído por uma conversa interrompida. As falas cabem em caixas curtas com revelação gradual e avanço por toque, inspiradas no ritmo de Undertale, mantendo personagens e texto próprios.

## Mapa e apresentação

`VarynMap` desenha arquitetura de pedra, chão com rachaduras, silhuetas distantes e Hollow Sun usando Canvas. Mantém um Bitmap do fundo da sala; o fundo só é recriado ao trocar de sala ou redimensionar a tela. Névoa, brasas, velas e pequenos marcadores usam Paint, Path e RectF reutilizados. Mara e Ivo possuem silhuetas originais; nenhum sprite de Kael ou Veilborn é substituído.

As colisões correspondem aos pés dos obstáculos, deixando livre o corredor central entre aproximadamente 45% e 72% da altura. As posições autoradas de entrada, inimigos e interações ficam acessíveis. A interação mais próxima é selecionada em um raio de 16% da altura, com uma única ação por vez. Saídas bloqueadas continuam selecionáveis para explicar o objetivo que falta.

`drawGround(Canvas, zone, story)` prepara o chão e a arquitetura; `drawObjects(Canvas, zone, story, clock)` acrescenta itens e ambientação. `drawNpcs(Canvas, zone, clock, minY, maxY)` desenha sobreviventes cujos pés estão no intervalo `[minY, maxY)`. O controlador intercala essas camadas entre Kael e o inimigo conforme a altura dos pés, permitindo passar à frente ou atrás dos NPCs sem inverter a profundidade. Também mantém HUD, botões, combate, pausa e transições. `release()` libera o fundo ao encerrar a tela.

## Continuidade do arquivo de recuperação

O resumo histórico em `project_archive/HISTORIA_COMPLETA.txt` nos pacotes antigos está em inglês e não contradiz a história canônica mais completa em português. A entrega v1.8 deve copiar a história canônica atual e este registro para o arquivo de recuperação do APK, conservando os pacotes históricos e a arte v1.7.
