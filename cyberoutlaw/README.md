# CyberOutlaw · terraço de Maré Baixa

Instalador para o universo `10774214423` e o Place inicial `122033314086516`. A câmera do menu percorre um terraço industrial da cidade 3D **Maré Baixa**, com fachadas de vidro, residenciais e uma estação ligada ao monotrilho. As poças deixam ver geometria espelhada abaixo do piso. A luz, a câmera e o palco são locais ao cliente. **Jogar** desmonta o palco e libera os controles para os sistemas do Place.

## No Termux

O pacote usa Python e `libzstd`. Se precisar instalar as dependências, use `pkg install python curl zstd`.

1. Rode `python CYBEROUTLAW_MENU.py verificar` para conferir os arquivos locais.
2. Rode `python CYBEROUTLAW_MENU.py midia` para importar as fachadas, a chuva e qualquer mídia ainda pendente. A chave da Open Cloud é pedida em um campo oculto. Os envios têm preço esperado zero. Se houver mídia em revisão, rode `midia` novamente. Os recibos das versões anteriores permitem aproveitar os assets já aprovados.
3. Rode `python CYBEROUTLAW_MENU.py instalar`. O instalador guarda o backup em `~/.cyberoutlaw-installer` e prepara o único `LocalScript` do menu. Confirme com `PUBLICAR CYBEROUTLAW`. Se a resposta da publicação for incerta, use `python CYBEROUTLAW_MENU.py resume` para consultar o resultado.

Na chave, habilite `asset:read`, `asset:write` e `asset-permissions:write` para a mídia do projeto. A leitura das versões e a publicação usam `legacy-asset:manage` e `universe-places:write` no Place. [Documentação da Open Cloud](https://create.roblox.com/docs/cloud)

## Abertura

`CyberOutlaw-Intro-6s.mp4` tem seis segundos, 1280 × 720, 180 quadros e nenhuma faixa de áudio. O Roblox cobra 2.000 Robux por importação de vídeo. Para usar um Video ID aprovado e acessível à experiência, rode `python CYBEROUTLAW_MENU.py video SEU_ID` antes de `instalar`. A abertura usa o panorama e a barra de progresso enquanto o ID estiver ausente, se o vídeo demorar a carregar ou se o jogador tiver ativado movimento reduzido. [Documentação de vídeo](https://create.roblox.com/docs/ui/video-frames)

## Autoria e testes

A Capri usa 20 animações e três falas do projeto Capri Desktop. Ela ocupa mais espaço no menu e adapta o tamanho aos controles da tela. O pacote inclui os créditos e a licença de uso não comercial. Os dois cliques e a chuva vieram do ElevenLabs. A chuva começa quando a abertura termina, se repete em um loop de 14 segundos e segue a opção **Som do menu**. O concreto e o asfalto usam digitalizações Poly Haven com mapas de cor, relevo e rugosidade. [Créditos da Capri](media/capri/PROVENANCE.md) · [Créditos de áudio](media/audio/CREDITOS.json) · [Créditos de arte](media/art/CREDITOS.md)

Os testes locais conferem a câmera, os controles do menu, a atualização sobre a primeira versão e a composição do Place em formato binário e XML. A prévia usa a geometria e a trajetória do menu, com iluminação aproximada fora do cliente Roblox. O cliente aplica a qualidade gráfica disponível no aparelho.

O terraço usa texturas PBR por face e uma fonte de luz em cada região principal de brilho. Um efeito de câmera suaviza as bordas do neon. [Texturas, Decals e mapas PBR](https://create.roblox.com/docs/parts/textures-decals) · [Efeitos de iluminação](https://create.roblox.com/docs/environment/post-processing-effects)
