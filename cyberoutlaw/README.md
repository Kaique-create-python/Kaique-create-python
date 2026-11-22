# CyberOutlaw · menu 3D

Instalador para o universo `10774214423` e o Place inicial `122033314086516`. **Maré Baixa** é a cidade original do menu, com 2.270 peças, oito torres principais, canal, pontes e monotrilho. A câmera do `ViewportFrame` percorre a cena em um ciclo de 68 segundos. **Jogar** fecha o menu e devolve o controle aos sistemas do Place.

## No Termux

O pacote usa Python e `libzstd`. Se precisar instalar as dependências, use `pkg install python curl zstd`.

1. Rode `python CYBEROUTLAW_MENU.py verificar` para conferir os arquivos locais.
2. Rode `python CYBEROUTLAW_MENU.py midia` para importar as oito texturas da Capri e os sete sons. A chave da Open Cloud é pedida em um campo oculto. Os envios têm preço esperado zero. Se houver mídia em revisão, rode `midia` novamente. Os recibos preservam os envios já feitos.
3. Rode `python CYBEROUTLAW_MENU.py instalar`. O instalador guarda o backup em `~/.cyberoutlaw-installer` e prepara o único `LocalScript` do menu. Confirme com `PUBLICAR CYBEROUTLAW`. Se a resposta da publicação for incerta, use `python CYBEROUTLAW_MENU.py resume` para consultar o resultado.

Na chave, habilite `asset:read`, `asset:write` e `asset-permissions:write` para a mídia do projeto. A leitura das versões e a publicação usam `legacy-asset:manage` e `universe-places:write` no Place. [Documentação da Open Cloud](https://create.roblox.com/docs/cloud)

## Abertura

`CyberOutlaw-Intro-6s.mp4` tem seis segundos, 1280 × 720, 180 quadros e nenhuma faixa de áudio. O Roblox cobra 2.000 Robux por importação de vídeo. Para usar um Video ID aprovado e acessível à experiência, rode `python CYBEROUTLAW_MENU.py video SEU_ID` antes de `instalar`. A abertura usa o panorama e a barra de progresso enquanto o ID estiver ausente, se o vídeo demorar a carregar ou se o jogador tiver ativado movimento reduzido. [Documentação de vídeo](https://create.roblox.com/docs/ui/video-frames)

## Autoria e testes

A Capri usa 20 animações e três falas do projeto Capri Desktop. O pacote inclui os créditos e a licença de uso não comercial. Os sons de clique e confirmação vieram do ElevenLabs. Os dois efeitos de teleporte e reação são eletrônicos originais. [Créditos da Capri](media/capri/PROVENANCE.md) · [Créditos de áudio](media/audio/CREDITOS.json)

Os testes locais conferem o ciclo da câmera, o comportamento do menu e a preservação dos outros objetos do Place em formato binário e XML. A prévia do panorama foi renderizada fora do Roblox a partir da geometria e da trajetória do menu. O desempenho no cliente Roblox ainda precisa de medição.
