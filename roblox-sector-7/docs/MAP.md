# Mapa procedural — SETOR 7

**Regra do usuário: não adicionar placas, letreiros ou texto no ambiente.** A entrega final removeu placas, `SurfaceGui`, `TextLabel`, fundos de placas e letras da porta. O mapa tem **1515 Parts** e nenhuma inscrição ambiental. Painéis metálicos que fazem parte da construção das paredes permanecem; eles não são placas. Objetivos, prompts e leitura das notas ficam na interface.

`src/server/WorldBuilder.luau` exporta `Build(): Model`. A função cria e retorna `Workspace.Sector7World`, publica o modelo cedo e cede execução a cada 180 Parts. O atributo `Ready` só vira `true` ao terminar. `PartCount` registra a contagem final. A semente local é `7131989`; nenhuma chamada altera o gerador aleatório global.

Uma reconstrução destrói somente um `Model` chamado `Sector7World` que possua `Sector7Owned=true`. Se outra instância usar esse nome, o builder gera erro e preserva essa instância. Não limpa Workspace, terreno, iluminação ou objetos de terceiros.

O corredor ocupa x=-8..8 e z=24..-202, com piso contínuo em y=0. O teto é uma abóbada facetada de concreto, com laterais a aproximadamente y=7 e ápice y=15. As salas possuem teto plano a y=8,2. As entradas laterais têm 11 studs de largura ao longo de Z, com altura livre de 7 studs. As paredes principais são segmentos reais entre as entradas: não existe parede invisível atravessando os acessos.

| Local | Centro / acesso | Limites aproximados |
| --- | --- | --- |
| Spawn | `(0, 3, 12)` | Corredor de entrada |
| Oficina | entrada `(-8, 0, -38)` | x=-32..-8; z=-50..-26 |
| Geradores | entrada `(8, 0, -92)` | x=8..32; z=-104..-80 |
| Arquivo | entrada `(-8, 0, -142)` | x=-32..-8; z=-154..-130 |
| Porta de evacuação | `(0, 5, -180)` | Largura 15,4; altura 10; espessura 1 |
| Zona após a porta | `(0, 4, -191)` | `ExitZone`: 14 × 8 × 14 |

Cada interação tem `InteractionId` no próprio BasePart e um filho `ProximityPrompt` chamado `Interact`. Os prompts usam E, botão X e o controle de toque padrão, alcance de 9 studs e visibilidade direta. O servidor deve validar distância, estado e progressão; o builder não processa interações.

| InteractionId | Posição exata do BasePart | Suporte |
| --- | --- | --- |
| `Fuse1` | `(-27.8, 3.08, -31)` | Bancada da oficina |
| `Fuse2` | `(28.8, 3.08, -83)` | Mesa de peças do gerador |
| `Fuse3` | `(-24.8, 3.08, -150.8)` | Bancada no fundo do arquivo |
| `Generator` | `(18.4, 2.7, -89)` | Console separado da máquina |
| `Keycard` | `(-20.8, 2.82, -143.4)` | Mesa central do arquivo |
| `Exit` | `(0, 5, -180)` | O próprio `ExitDoor` |
| `Note1` | `(7.76, 3.5, 7)` | Papel interativo na entrada, sem texto no ambiente |
| `Note2` | `(-27, 2.8, -44)` | Mesa da oficina |
| `Note3` | `(31.78, 3.25, -100)` | Parede dos geradores |
| `Note4` | `(-23.5, 2.81, -143)` | Mesa central do arquivo |

As notas só possuem papel e linhas decorativas, sem letras. Os textos narrativos continuam no servidor e aparecem na interface ao interagir. Não criar placas ou fundos de placas para apresentá-los. Fusíveis e cartão são os únicos Parts com seus respectivos IDs; pequenas tampas e a listra do cartão são decoração sem colisão, filha do Part interativo. Ao coletar, o servidor pode destruir o Part interativo (com seus filhos) sem afetar a navegação; se optar por transparência, deve ocultar também os BaseParts descendentes.

`ExitDoor` é um único Part ancorado, filho direto do modelo, tamanho `(15.4, 10, 1)`. Tem `ClosedCFrame` igual ao CFrame inicial e `OpenOffset=(0, 11, 0)`. O servidor pode desativar `CanCollide` para passagem imediata, ou mover esse único Part 11 studs para cima. A porta não tem letras, marcação ou `SurfaceGui`. Os batentes laterais deixam abertura livre de 15,4 studs. Não existem reforços ou outros sólidos sobre a folha que continuem bloqueando a passagem depois de abri-la. A área evacuada começa depois de z=-180; `ExitZone` cobre z=-184..-198 e delimita a zona usada pelo servidor para reconhecer a evacuação.

`BunkerSpawn` é um SpawnLocation transparente no piso em `(0, 0.075, 12)`. `SpawnPoint` é um marcador transparente em `(0, 3, 12)` para reposicionar personagens R6 explicitamente. Ambos pertencem ao modelo.

`CreatureNodes` contém `Node01` até `Node20`, Parts transparentes, ancorados, sem colisão/query/touch, com atributo numérico `Order`. A ordem segue o corredor e faz desvios acessíveis nas três salas, retornando pela mesma entrada. O último ponto é `(0, 3, -164)`, antes da porta. O servidor deve ordenar pelo atributo `Order` para patrulhar; pode também usar PathfindingService entre pontos.

A iluminação local usa luminárias com gaiola e PointLights em `Lamps`. O nome de cada luz é `BunkerLight`, com atributo `PowerLight=true`; o Part emissivo possui `BackupLight=true`. `Details.PowerIndicator` possui `PowerIndicator=true`, começa vermelho e pode mudar para verde quando o gerador ligar. O builder preserva Lighting global para que o servidor escolha ambientação, fog e efeitos de câmera. Canos, cabos, trilhos, grades de drenagem e poças decorativas ficam sem colisão; piso, paredes, teto, mesas e grandes máquinas possuem colisão.

Verificações estáticas: os três cortes de parede e os pisos de sala usam os mesmos centros; os encontros de piso sobrepõem 0,4 stud para evitar frestas; as portas ficam livres até y=7. Os pequenos desníveis decorativos não têm colisão. Nenhum recurso externo, textura, áudio ou MeshId é necessário para gerar o mapa.
