# CyberOutlaw · terraço de Maré Baixa

Instalador para o universo `10774214423` e o Place inicial `122033314086516`. A câmera do menu percorre um terraço industrial da cidade 3D **Maré Baixa**, com fachadas de vidro, residenciais e uma estação ligada ao monotrilho. As poças deixam ver geometria espelhada abaixo do piso. A luz, a câmera e o palco são locais ao cliente. **Jogar** desmonta o palco e libera os controles para os sistemas do Place.

## No Termux

O pacote usa Python e `libzstd`. Se precisar instalar as dependências, use `pkg install python curl zstd`.

O arquivo `CYBEROUTLAW_TERMUX.pyz` é um pacote executável pelo Python. Ele abre em blocos e informa no terminal a etapa em andamento.

1. Rode `python CYBEROUTLAW_TERMUX.pyz verificar` para conferir os arquivos locais.
2. Se houver mídia pendente, rode `python CYBEROUTLAW_TERMUX.pyz midia`. A chave da Open Cloud é pedida em um campo oculto. Os envios têm preço esperado zero. Os recibos das versões anteriores permitem aproveitar os assets já aprovados.
3. Rode `python CYBEROUTLAW_TERMUX.pyz instalar`. O instalador guarda o backup em `~/.cyberoutlaw-installer`, atualiza o `LocalScript` do menu e grava R6 na configuração de avatar do Place. Confirme com `PUBLICAR CYBEROUTLAW`. Se a resposta da publicação for incerta, use `python CYBEROUTLAW_TERMUX.pyz resume` para consultar o resultado.

Se você já tem todos os arquivos de mídia aprovados, o comando `instalar` recupera os IDs pelos recibos salvos no Termux.

Na chave, habilite `asset:read`, `asset:write` e `asset-permissions:write` para a mídia do projeto. A leitura das versões e a publicação usam `legacy-asset:manage` e `universe-places:write` no Place. [Documentação da Open Cloud](https://create.roblox.com/docs/cloud)

## Abertura

`CyberOutlaw-Intro-6s.mp4` tem seis segundos, 1280 × 720, 180 quadros e nenhuma faixa de áudio. O Roblox cobra 2.000 Robux por importação de vídeo. Para usar um Video ID aprovado e acessível à experiência, rode `python CYBEROUTLAW_TERMUX.pyz video SEU_ID` antes de `instalar`. A abertura usa o panorama e a barra de progresso enquanto o ID estiver ausente, se o vídeo demorar a carregar ou se o jogador tiver ativado movimento reduzido. [Documentação de vídeo](https://create.roblox.com/docs/ui/video-frames)

## Cidade jogável e R6

Depois de **Jogar**, o jogador chega à Praça da Maré, no centro de uma cidade aberta de 2.000 × 2.000 studs. O script de servidor `CyberOutlawCity` monta a cidade ao iniciar o servidor, sempre igual, com cinco distritos: Distrito Prisma (torres de até 1.148 studs), Alto Vértice (torres corporativas), Colmeia (residencial), Mercado Fosso (becos com letreiros) e Docas da Maré (galpões, contêineres, guindastes e cargueiro). Avenidas de quatro faixas com canteiro, ruas de duas faixas, faixas de pedestre, semáforos, postes, poças, monotrilho elevado com a Estação Prisma, baía e horizonte. As pistas ficam livres de obstáculos para os veículos de uma etapa futura.

As janelas acesas usam três texturas desenhadas por código. Rode `midia` para enviá-las; enquanto aguardam aprovação, a instalação continua e os prédios usam faixas de luz em geometria. A cidade fica idêntica nos dois casos.

O script `CyberOutlawR6` refaz em R6 qualquer personagem que nasça em R15, porque o universo ainda responde `MorphToR15` na API pública. O resultado fica no atributo `CyberOutlawRig` do jogador.

O instalador grava os dois scripts em `ServerScriptService` e só substitui scripts que começam com o cabeçalho do CyberOutlaw.

## HUD

Ao clicar em **Jogar**, a vida mostra o retrato do avatar e os valores do `Humanoid`, com rastro do dano recente e borda pulsando abaixo de 30%. O minimapa gira com a câmera, mostra os distritos, o monotrilho e a praça, e traz o nome do distrito e o relógio da cidade. Ao entrar em outro distrito, o nome aparece no topo da tela. No PC o minimapa fica no canto inferior esquerdo, abaixo da vida; no celular fica no canto superior direito, longe do joystick e do botão de pulo. O desenho está em `design/hud_v2.py`, em vetores feitos à mão. O painel fica abaixo da barra do Roblox em telas touch e no canto inferior esquerdo em PC. A mira usa as dimensões do visor inteiro. As prévias usam 78 de vida e uma imagem de referência da cidade.

## Autoria e testes

A Capri usa 20 animações e três falas do projeto Capri Desktop. Ela ocupa mais espaço no menu e adapta o tamanho aos controles da tela. O pacote inclui os créditos e a licença de uso não comercial. Os dois cliques vieram do ElevenLabs. O concreto e o asfalto usam digitalizações Poly Haven com mapas de cor, relevo e rugosidade. [Créditos da Capri](media/capri/PROVENANCE.md) · [Créditos de áudio](media/audio/CREDITOS.json) · [Créditos de arte](media/art/CREDITOS.md)

Os testes locais conferem a câmera, os controles do menu, a atualização sobre a primeira versão e a composição do Place em formato binário e XML. A prévia usa a geometria e a trajetória do menu, com iluminação aproximada fora do cliente Roblox. O cliente aplica a qualidade gráfica disponível no aparelho.

O terraço usa texturas PBR por face e uma fonte de luz em cada região principal de brilho. Um efeito de câmera suaviza as bordas do neon. [Texturas, Decals e mapas PBR](https://create.roblox.com/docs/parts/textures-decals) · [Efeitos de iluminação](https://create.roblox.com/docs/environment/post-processing-effects)
