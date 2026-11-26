# CyberOutlaw · terraço de Maré Baixa

## Bairros e luz nas ruas

A revisão visual da cidade mantém as 80 quadras, o canal, a Linha 07 e os acessos da versão integrada. Nove perfis diferenciam os volumes, a idade aparente dos materiais e a cor das luzes. A Praça do Dique, o Mercado do Sódio, o Colmeia, o Alto Vértice e as Docas da Maré são referências de orientação. Os Altos do Dique, a Costa da Maré, o Cercado e a Faixa de Serviço aparecem também no painel de destino do dono. [Pesquisa do mapa de Night City e aplicação em Maré Baixa](docs/REFERENCIAS_NIGHT_CITY.md)

O brilho no asfalto vem das luminárias próximas e das 26 poças com aberturas na pista. A colisão continua sob a água. O cliente mantém até 12, 22 ou 34 luminárias locais e até uma, duas ou três poças espelhadas ao mesmo tempo. No modo automático, ele ajusta esse orçamento à cadência de quadros. A qualidade manual do Roblox de 8 a 10 usa o orçamento mais alto da cidade. O canal combina reflexo do ambiente com brilhos nos pontos iluminados. [Modos de iluminação do Roblox](https://create.roblox.com/docs/environment/lighting) · [Efeitos de pós-processamento](https://create.roblox.com/docs/environment/post-processing-effects)

Os comparativos usam a geometria exportada da cidade, as mesmas posições de câmera e a mesma configuração do renderizador 3D. A aparência final depende da qualidade selecionada e do aparelho no Roblox. [Mercado do Sódio](dist/previews/mare-baixa-visual/mercado-comparativo.jpg) · [Térreo da Torre Vértice](dist/previews/mare-baixa-visual/vertice-comparativo.jpg) · [Avenida molhada](dist/previews/mare-baixa-visual/avenida.jpg) · [Canal](dist/previews/mare-baixa-visual/canal.jpg) · [Quatro bairros](dist/previews/mare-baixa-visual/bairros.jpg)

## Maré Baixa integrada

A integração parte da v12.1 da branch `ccr-b4068ef4-7ky9v8` e conserva o universo `10774214423` e o Place `122033314086516`. A cidade jogável tem 80 quadras em uma malha de 2.400 × 1.920 studs. O servidor constrói a geometria de `src/mare-baixa/` por Luau. O instalador inclui os módulos no script gerenciado da cidade.

As prévias usam a geometria exportada da versão integrada, com iluminação e reflexos do renderizador 3D. [Canal](dist/CyberOutlaw-Mare-Integrada-Canal.jpg) · [Estação](dist/CyberOutlaw-Mare-Integrada-Estacao.jpg) · [Colmeia](dist/CyberOutlaw-Mare-Integrada-Colmeia.jpg) · [Panorama](dist/CyberOutlaw-Mare-Integrada-Panorama.jpg)

- O Edifício Colmeia mantém as 12 unidades, as chegadas e os painéis do elevador. A Praça do Dique concentra o nascimento e a zona segura.
- O novo `Layout` informa os eixos X e Z, o canal e os tipos de ponte. O minimapa usa esses dados. As rotas do tanque cruzam o canal pelas pontes rodoviárias. O monotrilho faz ida e volta na Linha 07 com embarque na Estação do Dique.
- As texturas PBR da cidade e as artes vetoriais do menu foram feitas por código. Os PNGs desta versão têm até 512 × 512 nos materiais do mapa. `midia` aproveita os recibos existentes e envia as imagens novas para aprovação. O instalador grava as variantes aprovadas em `MaterialService` antes da publicação. A geometria usa materiais nativos e as digitalizações já aprovadas quando faltam IDs.
- A Praça do Dique recebe um piso de chegada persistente antes da montagem das quadras. O chão do modelo original é ocultado depois da construção da cidade.
- O instalador grava o streaming do Roblox no Place, com mínimo de 180 e alvo de 640 studs. O desempenho depende do aparelho e deve ser conferido no cliente. [Streaming de instâncias](https://create.roblox.com/docs/workspace/streaming)

No Termux, rode `python -u CYBEROUTLAW_HUD.py verificar` para validar o pacote. O comando `chave` faz a leitura de teste usando entrada oculta. `instalar` segue o fluxo de backup e pede confirmação de publicação.

Instalador para o universo `10774214423` e o Place inicial `122033314086516`. A câmera do menu percorre um terraço industrial da cidade 3D **Maré Baixa**, com fachadas de vidro, residenciais e uma estação ligada ao monotrilho. As poças deixam ver geometria espelhada abaixo do piso. A luz, a câmera e o palco são locais ao cliente. **Jogar** desmonta o palco e libera os controles para os sistemas do Place.

## No Termux

O pacote usa Python e `libzstd`. Se precisar instalar as dependências, use `pkg install python curl zstd`.

O arquivo `CYBEROUTLAW_TERMUX.pyz` é um pacote executável pelo Python. Ele abre em blocos e informa no terminal a etapa em andamento.

1. Rode `python CYBEROUTLAW_TERMUX.pyz verificar` para conferir os arquivos locais.
2. Se houver mídia pendente, rode `python CYBEROUTLAW_TERMUX.pyz midia`. A chave da Open Cloud é pedida em um campo oculto. Os envios têm preço esperado zero. Os recibos das versões anteriores permitem aproveitar os assets já aprovados.
3. Rode `python CYBEROUTLAW_TERMUX.pyz instalar` quando quiser publicar. O instalador guarda o backup em `~/.cyberoutlaw-installer`, atualiza os scripts gerenciados deste Place e grava as configurações de avatar e streaming. Confirme com `PUBLICAR CYBEROUTLAW`. Se a resposta da publicação for incerta, use `python CYBEROUTLAW_TERMUX.pyz resume` para consultar o resultado.

Se você já tem todos os arquivos de mídia aprovados, o comando `instalar` recupera os IDs pelos recibos salvos no Termux.

Na chave, habilite `asset:read`, `asset:write` e `asset-permissions:write` para a mídia do projeto. A leitura das versões e a publicação usam `legacy-asset:manage` e `universe-places:write` no Place. [Documentação da Open Cloud](https://create.roblox.com/docs/cloud)

## Abertura

`CyberOutlaw-Intro-6s.mp4` tem seis segundos, 1280 × 720, 180 quadros e nenhuma faixa de áudio. O Roblox cobra 2.000 Robux por importação de vídeo. Para usar um Video ID aprovado e acessível à experiência, rode `python CYBEROUTLAW_TERMUX.pyz video SEU_ID` antes de `instalar`. A abertura usa o panorama e a barra de progresso enquanto o ID estiver ausente, se o vídeo demorar a carregar ou se o jogador tiver ativado movimento reduzido. [Documentação de vídeo](https://create.roblox.com/docs/ui/video-frames)

## Cidade jogável e R6

Depois de **Jogar**, o jogador chega à Praça do Dique. O canal separa os bairros. As pontes conectam a praça à Estação do Dique, à Torre Vértice e às vias que levam ao Mercado Sódio e à Doca do Sal. O servidor publica o layout quando termina de construir a cidade.

O script `CyberOutlawR6` refaz em R6 personagens que nasçam em R15. O resultado fica no atributo `CyberOutlawRig` do jogador. O instalador reconhece os scripts gerenciados pelos cabeçalhos e usa a versão atual do Place como base.

## HUD

Ao clicar em **Jogar**, a vida mostra o retrato do avatar e os valores do `Humanoid`, com rastro do dano recente e borda pulsando abaixo de 30%. O minimapa gira com a câmera, mostra os distritos, o monotrilho e a praça, e traz o nome do distrito e o relógio da cidade. Ao entrar em outro distrito, o nome aparece no topo da tela. No PC o minimapa fica no canto inferior esquerdo, abaixo da vida; no celular fica no canto superior direito, longe do joystick e do botão de pulo. O desenho está em `design/hud_v2.py`, em vetores feitos à mão. O painel fica abaixo da barra do Roblox em telas touch e no canto inferior esquerdo em PC. A mira usa as dimensões do visor inteiro. As prévias usam 78 de vida e uma imagem de referência da cidade.

## Autoria e testes

A Capri usa 32 animações e três falas do projeto Capri Desktop. Ela adapta o tamanho aos controles da tela. O pacote inclui os créditos e a licença de uso não comercial. Os cliques do menu vieram do ElevenLabs. O concreto e o asfalto usam digitalizações Poly Haven com mapas de cor, relevo e rugosidade. [Créditos da Capri](media/capri/PROVENANCE.md) · [Créditos de áudio](media/audio/CREDITOS.json) · [Créditos de arte](media/art/CREDITOS.md)

Os testes locais conferem a câmera, os controles do menu, a atualização sobre a primeira versão e a composição do Place em formato binário e XML. A prévia usa a geometria e a trajetória do menu, com iluminação aproximada fora do cliente Roblox. O cliente aplica a qualidade gráfica disponível no aparelho.

O terraço usa texturas PBR por face e uma fonte de luz em cada região principal de brilho. Um efeito de câmera suaviza as bordas do neon. [Texturas, Decals e mapas PBR](https://create.roblox.com/docs/parts/textures-decals) · [Efeitos de iluminação](https://create.roblox.com/docs/environment/post-processing-effects)
