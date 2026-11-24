# CyberOutlaw · contexto para continuar o projeto

Claude, você está assumindo **CyberOutlaw**, meu projeto Roblox de mundo aberto cyberpunk. A ideia futura mistura cidade aberta, veículos e sistemas de crime. Já defini a história e os sistemas. Quando a próxima etapa precisar desses detalhes, peça meu material. Meu acesso é pelo celular, com **Termux e Roblox Open Cloud**.

## Identificação do projeto

| Dado | Valor |
| --- | --- |
| Nome do projeto | **CyberOutlaw** |
| Nome público na última consulta | **Ideias** |
| ID do universo | `10774214423` |
| ID do mapa e Place inicial | `122033314086516` |
| ID do criador Roblox | `1357078972` |
| Repositório | `Kaique-create-python/Kaique-create-python` |
| Branch atual | `ccr-b4068ef4-7ky9v8` (partiu de `codex/cyberoutlaw-menu-3d`) |
| Pasta de trabalho | `cyberoutlaw/` |

O repositório também contém trabalhos de outros jogos. Use os IDs acima durante toda a instalação do CyberOutlaw. [Abrir o Place](https://www.roblox.com/games/122033314086516) · [Abrir o código na branch](https://github.com/Kaique-create-python/Kaique-create-python/tree/codex/cyberoutlaw-menu-3d/cyberoutlaw)

## O que já está pronto no código

- **Menu.** A câmera passeia por um terraço de Maré Baixa, uma cidade em 3D com prédios de várias alturas, fachadas detalhadas, monotrilho, concreto e asfalto PBR, poças e neon rosa e ciano. O fundo do menu precisa ser geometria 3D em movimento. Use o letreiro original aprovado em `media/art/title.png`. O cenário do menu é local e é desmontado ao tocar em **Jogar**. O mundo aberto jogável ainda é uma etapa futura.
- **Abertura.** Dura seis segundos e fica muda. O pacote permite vincular o Video ID do clipe aprovado. Na ausência do ID, a abertura usa a cidade 3D e a barra de progresso.
- **Capri.** Assistente do menu, maior que nas versões iniciais. Pode ser arrastada, fica no canto, reage às interações e usa 20 clipes, incluindo teleportes e poses. Preserve os cliques do menu, as reações com áudio, as falas e os créditos. A licença da Capri é a PolyForm Noncommercial 1.0.0. [Créditos e origem da Capri](https://github.com/Kaique-create-python/Kaique-create-python/blob/codex/cyberoutlaw-menu-3d/cyberoutlaw/media/capri/PROVENANCE.md)
- **Som.** O pedido mais recente removeu o áudio de chuva. A chuva visual faz parte da cidade. A versão atual reaproveita as mídias aprovadas e tem 23 arquivos no manifesto, incluindo os atlas da Capri e sete sons.
- **HUD.** Entra depois de **Jogar**. A barra rosa mostra o rosto do avatar e a vida atual/máxima do `Humanoid`. Atualiza com dano, cura e renascimento. Fica abaixo da barra do Roblox no celular e no canto inferior esquerdo no PC.
- **Mira.** Círculo pequeno de 14 px com ponto de 2 px. A camada da mira usa `ScreenInsets.None` e âncora e posição `0.5, 0.5`, para que a barra do Roblox e os recortes de tela não desloquem o centro.
- **R6 obrigatório.** O instalador grava R6 nas propriedades nativas de avatar do Place. A alteração passou em arquivos `.rbxl` e `.rbxlx` de teste. Na consulta pública de 23 de novembro de 2026, o universo ainda respondeu `MorphToR15`. Veja qual versão está publicada e valide `Humanoid.RigType` em um servidor novo antes de dar o R6 como confirmado em jogo. [Metadados públicos do universo](https://games.roblox.com/v1/games?universeIds=10774214423)

## Etapa de 23 de novembro de 2026: cidade jogável, R6 forçado e HUD v2

- **Cidade jogável.** `src/world.server.luau` vira o Script `CyberOutlawCity` em `ServerScriptService`. Ele monta Maré Baixa ao iniciar o servidor: 2.000 × 2.000 studs, eixos de rua a cada 200 studs (avenidas de 56 studs nos múltiplos de 400, ruas de 28), cinco distritos (Distrito Prisma, Alto Vértice, Colmeia, Mercado Fosso, Docas da Maré), torres de 170 a 1.148 studs, monotrilho com a Estação Prisma, docas com guindastes e cargueiro, baía de terreno, horizonte e muros invisíveis. O spawn fica na Praça da Maré, em (107, 0.85, 139). A cidade publica o traçado do minimapa em `ReplicatedStorage.CyberOutlawCityInfo` (atributo `Layout`). As pistas ficam livres para veículos futuros, e o teste confere isso.
- **Arte da cidade sem IA.** Asfalto e concreto Poly Haven (CC0) e três texturas de janelas desenhadas por código (`tools/draw_city_textures.py`). As janelas são mídia opcional: sem aprovação, os prédios usam faixas de luz em geometria. A cidade é idêntica nos dois casos.
- **R6 forçado.** O usuário viu R15 em jogo. `src/r6_guard.server.luau` vira o Script `CyberOutlawR6`, que refaz qualquer R15 como R6 com `CreateHumanoidModelFromDescriptionAsync` no mesmo lugar. O atributo `CyberOutlawRig` do jogador mostra o resultado. A configuração de avatar do Place continua em R6.
- **Instalador.** O patcher grava o menu e os scripts de servidor, e só substitui scripts que começam com `-- CyberOutlaw · script de servidor gerenciado: <nome>`. Backup, confirmação e `resume` seguem iguais.
- **HUD v2.** Vida com rastro de dano e pulso abaixo de 30%, minimapa que gira com a câmera, aviso de distrito, relógio e a mira central de antes. PC: minimapa no canto inferior esquerdo, vida acima. Celular: vida no topo à esquerda e minimapa no topo à direita. O desenho vetorial está em `design/hud_v2.py`. O Figma do usuário atingiu o limite mensal de chamadas do plano Starter (arquivo vazio "CyberOutlaw HUD v2" criado). O Canva só cria designs pelo gerador de IA dele, então não foi usado.
- **Testes.** Python: 31 testes. Luau (Lune): menu e HUD, cena, terraço do menu, R6 e cidade (`tests/world_test.luau` também exporta a prévia).
- **Pendente em jogo.** Confirmar R6 e animações num servidor novo, o desempenho da cidade no celular, as janelas depois de `midia` e o minimapa. O título do menu pode continuar sendo arte gerada por IA, a pedido do usuário.

## Arquivos atuais

- O `.py` inicia a última versão verificada. Ele reaproveita o pacote local se estiver íntegro ou baixa a versão fixa do GitHub com verificação SHA-256. [Baixar CYBEROUTLAW_HUD.py](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/ccr-b4068ef4-7ky9v8/cyberoutlaw/dist/CYBEROUTLAW_HUD.py)
- O `.pyz` é o pacote completo da versão `141e572`. [Baixar CYBEROUTLAW_TERMUX.pyz](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/141e5721f29fc280fd127e79c91391db7f4ccabd/cyberoutlaw/dist/CYBEROUTLAW_TERMUX.pyz)
- O design tem duas pranchetas editáveis para importar no Figma. O limite do plano Starter impediu gravar na versão online. A imagem da cidade nas pranchetas serve de referência para o HUD. [Figma editável](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/141e5721f29fc280fd127e79c91391db7f4ccabd/cyberoutlaw/dist/CyberOutlaw-HUD.fig) · [Prévia no celular](https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/141e5721f29fc280fd127e79c91391db7f4ccabd/cyberoutlaw/dist/CyberOutlaw-HUD-Celular.png)

Leia `src/menu.client.luau` para o fluxo do menu, `src/city.luau` e `src/scene.luau` para a cidade e a câmera, e `src/hud.luau` para vida e mira. O código de montagem, migração e backup está em `install/cyber_installer.py` e `install/patcher.py`. A entrada do Termux é `launcher.py`. [Código do projeto](https://github.com/Kaique-create-python/Kaique-create-python/tree/codex/cyberoutlaw-menu-3d/cyberoutlaw)

## Fluxo no Termux

```bash
curl -fL --retry 3 -o "$HOME/CYBEROUTLAW_HUD.py" \
  'https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/ccr-b4068ef4-7ky9v8/cyberoutlaw/dist/CYBEROUTLAW_HUD.py' &&
python -u "$HOME/CYBEROUTLAW_HUD.py" verificar
```

O comando `verificar` confere o pacote sem publicar. Para aplicar no Roblox, rode `python -u "$HOME/CYBEROUTLAW_HUD.py" instalar` e confirme no Termux com `PUBLICAR CYBEROUTLAW`. A chave da Open Cloud é pedida com entrada oculta e fica no aparelho.

O instalador guarda backups em `~/.cyberoutlaw-installer`. Ele reaproveita recibos de mídia em `~/.cyberoutlaw-menu/recibos-midia` e lê IDs das versões anteriores conhecidas durante a migração. Use `midia` se faltarem aprovações. Quando o retorno da publicação ficar inconclusivo, use `resume` para conferir antes de tentar publicar de novo. [Manual do instalador](https://github.com/Kaique-create-python/Kaique-create-python/blob/codex/cyberoutlaw-menu-3d/cyberoutlaw/README.md)

## Como retomar

1. Confira o que a versão atual mostra no celular. Abra a entrada, veja se a câmera apresenta a cidade 3D e se o letreiro original carregou. O caso anterior de céu vazio e título provisório motivou a correção `0597ef5`, incluída no pacote atual. O erro Android de `os.link` no backup foi corrigido em `440a682`.
2. Toque em **Jogar** e valide o avatar R6 em um servidor novo. Confira o rosto, a vida ao receber dano e renascer, a posição da mira com as margens do celular e o fim do áudio do menu. A última entrega passou por 27 testes Python e pelos testes Luau de menu, HUD e cidade. A confirmação em partida continua pendente.
3. Depois dessa conferência, continue por uma etapa de gameplay por vez conforme eu pedir. A ideia do jogo é GTA com cyberpunk e mercenários (estilo Mercenaries 2): veículos, facções e contratos são os próximos candidatos. Preserve a direção de arte, o fluxo de **Jogar**, a Capri e os créditos. Trabalhe sobre o place existente e mantenha o fluxo para atualizar com backup pelo Termux.

## Versão 2 da cidade e do jogo (novembro de 2026)

- **Cidade:**
  - Ruas mais largas, com estacionamento, e pintura rente ao asfalto.
  - Lojas recuadas com o interior desenhado, letreiros legíveis e placas verticais com palavras curtas.
  - Objetos de rua, carros estacionados, fios aéreos, megaprédios de painéis e tambores de anúncio.
  - Poças com reflexo, montado como mundo espelhado no cliente.
  - Céu desenhado por código, sem chuva.
- **Arte e texturas:**
  - `tools/draw_city_art.py` e `tools/draw_sky.py` desenham a arte por código, sem IA.
  - `tools/prepare_city_textures.py` prepara as texturas Poly Haven (CC0).
  - O instalador agora entrega as janelas e toda a arte da cidade ao script da cidade.
- **HUD:**
  - Fica no CyberOutlawPlay (`src/play.client.luau`), com layout único para PC e celular.
  - Um teste confere que nada se sobrepõe em 6 tamanhos de tela.
  - `src/hud.luau` ficou vazio.
  - Prévia: `tools/hud_preview.luau`.
- **Animação:** locomoção procedural R6 (`gaitStep`), com prévia em `tools/gait_preview.luau`.
- **Sons:**
  - Tiros, recargas, cliques e passos são gravações CC0, recortadas por `tools/prepare_weapon_audio.py`.
  - Os sons de interface são sintetizados.
- **Iluminação:** o instalador grava no place Technology Unified, LightingStyle Realistic e PrioritizeLightingQuality.
- **Pendente:** animações da Capri que faltam no Capri Desktop (fala, música, glitches, entradas "peek" e "up-close", versões espelhadas) e viaduto com rampas.

## Versão 3 (armas reais, animação do catálogo, HUD v4, Capri completa)

- **Chave Open Cloud:**
  - O envio para no primeiro 401/403 e mostra a mensagem do Roblox, sem a chave.
  - Recusas antigas por chave voltam a ser tentadas sozinhas.
  - `python CYBEROUTLAW_HUD.py chave` testa a chave lendo um asset aprovado, sem enviar nada.
- **Armas reais** (`src/arsenal.server.luau`):
  - Punhos, faca, Glock 17, Desert Eagle, Uzi, AK-47, M4A1, escopeta pump e sniper .308, todas feitas de peças, sem neon.
  - Sons de gravações CC0 da Free Firearm Sound Library: PPQ, 1911, M45, AK-47, AR-15, Mossberg e Tikka.
  - Bomba e ferrolho tocam depois do tiro.
  - A sniper tem luneta (FOV 18 e anel preto feito de `UIStroke`).
- **Ícones:**
  - `design/icones.py` projeta as peças dos modelos 3D em SVG (`tools/export_weapons.luau`).
  - O atlas tem 9 armas e 8 glifos.
  - Sem o atlas aprovado, os botões usam glifos feitos de Frames (`frameGlyph`).
- **Animação:**
  - Pacotes do catálogo tocam num esqueleto R15 invisível no cliente e são convertidos para R6 (`retargetPose`).
  - Os IDs dos pacotes Rthro, Stylish, Ninja e Superhero vêm da documentação oficial.
  - adidas, Oldschool e o pack UGC "GTA 6" são resolvidos no servidor (`r6_guard.server.luau`).
  - Se o pacote não tocar, volta para a locomoção procedural.
- **Painel do dono:** botão TP na faixa do topo, só para o criador.
  - Teleporte para praça, poças, bairros, estação e viaduto.
  - Troca do pacote de animação.
  - O servidor valida cada pedido.
- **HUD v4:**
  - Paleta "pôr do sol" (rosa, laranja e dourado) nos destaques.
  - Disco de vidro na roleta e cartão selecionado em degradê.
  - Arte no Figma (arquivo do projeto, seção "CyberOutlaw v3").
- **Cidade e lobby:**
  - Noite mais clara e feixes de luz (`Beam`) nos postes.
  - Via Expressa da Maré (elevado com rampas, z = 800).
  - Vitrines com interiores gerados com IA no Figma, com autorização do dono.
  - Lobby sem chuva, mais claro e com reflexo forte nas poças.
- **Capri:**
  - 32 animações. As novas são fala sentada e deitada, música sentada, glitches por pose, saída deitada e piscadas com glitch.
  - Música do menu: `python CYBEROUTLAW_HUD.py musica <vídeo ou áudio>`. O `ffmpeg` do Termux tira a trilha e envia como Audio.
  - O menu toca a música em loop com o botão ♪, e a Capri dança ou ouve.
- **Pendente:**
  - As intros em tela cheia da Capri ("peek" e "up-close", 1920×1080) não entraram.
  - Conferir no Roblox real o esqueleto R15 e a luneta.

## Versão 4 (HUD neon com páginas, implantes, Sandevistan, trem e dia e noite)

- **HUD neon:**
  - A barra de armas embaixo (placa 3D na frente da câmera) mostra 4 armas por página, com setas `<` `>` (`buildWeaponBar`, `BAR_HITS`).
  - O cartão de arma antigo saiu; o minimapa (vida, fôlego e estabilidade) foi para a mesma placa neon 3D.
  - As placas giram em volta da borda de fora (`holoTilt`), então nunca saem do retângulo do layout.
  - Botões neon: arsenal (só no toque), implantes (I) e habilidade (X), todos dentro do layout testado em 6 telas.
- **Implantes** (`IMPLANTS` em `src/arsenal.server.luau`):
  - Nomes do Cyberpunk: Sandevistan Militar (coluna), Ópticos Kiroshi, Lâminas Louva-a-Deus, Braços de Gorila, Tendões Reforçados e Armadura Subdérmica.
  - Só o Sandevistan funciona; os outros aparecem como "em breve".
  - Terminal holográfico 3D (`buildImplantPanel`): lista, boneco R6 de holograma que gira arrastando, marcas dos lugares do corpo e o botão ENCAIXAR. O toque usa uma camada 2D com as mesmas áreas (`panel.hits`).
- **Sandevistan** (regras em `SANDEVISTAN`, testadas em `tests/arsenal_test.luau`):
  - 4 s: quem ativou anda 2,2x e atira 2x mais rápido; quem está a até 90 studs anda a 30%.
  - Rastros coloridos (verde, ciano, azul, violeta, rosa, amarelo); partículas quase param.
  - Cada uso gasta 25 de estabilidade. A zero, 2 s de ciberpsicose: o servidor atira sozinho no jogador mais perto à vista, fora da zona segura. Depois volta a 40 e regenera 2,5/s após 8 s sem usar.
  - Sons sintetizados: `habilidade_lenta`, `surto` e `implante_encaixe` (`tools/synth_weapon_fx.py`).
- **Trem** (`trainSchedule`, `carCFrame`, `buildTrainCar` em `src/play.client.luau`):
  - Três carros andam no viaduto pela hora do servidor, sem rede. Param 14 s na Estação Prisma com as portas abertas.
  - Quem está em pé no carro anda junto (corpo, rumo e câmera).
  - Elevadores de vidro ligam a esquina (446, -47) à plataforma.
- **Dia e noite** (`dayLight`, `DAY_KEYS`): 24 minutos por dia, no cliente, pela hora do servidor.
  - Luz, névoa, nuvens, raios de sol e postes mudam aos poucos. O céu desenhado fica para a noite; de dia é o céu padrão do Roblox.
- **Correções:**
  - As pernas não abrem mais ao atirar andando de costas.
  - A Baseplate do modelo fica escondida abaixo do asfalto e os SpawnLocations do modelo são desligados (era o "cubo invisível" do spawn).
- **Símbolos:** o atlas tem agora 16 glifos (8 novos dos implantes). No Figma, seção "CyberOutlaw v5", com componentes `Ícone/Implante/*`.
- **Pendente:** conferir no Roblox real a entrada pela camada 2D do terminal, a carona no trem, o céu de dia (IDs do céu padrão) e o efeito de câmera lenta.
