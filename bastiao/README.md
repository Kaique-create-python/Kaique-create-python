# PROJETO BASTIÃO — Etapa 1: "A chamada"

Place **89520940302906** · Universe **10776462844** · instalador: `bastiao/dist/BASTIAO_ETAPA1.py`

A Etapa 1 transforma a base Sever-9 (o mapa Sector7 que já existe) no começo da história do
plano mestre: as cenas **1, 3, 4, 5, 7 e 8** da abertura, do fim de um turno comum até a lista
do turno no terminal da oficina. O monstro 731-A, o rifle (cena 2) e a perseguição (cena 6)
ficam para as próximas etapas, como combinado: uma parte por vez, com qualidade.

## O que entra no jogo

| Cena | O que acontece |
|---|---|
| 1 · fim de um turno comum | Pavel espera no túnel de entrada, ao lado de uma caixa com rádio, caneca e a lista de turno. Relógio da base marca 02:49. Ao chegar perto, ele fala; o objetivo aparece só depois: **Confira o rádio com Pavel**. |
| 3 · o nome na lista | Orlov pede o módulo de reserva pelo rádio; Pavel lê a lista ("Antonov. KEDR. Sokolov...") e muda de assunto; três toques ao longe. Pavel vai na frente para o arsenal. |
| 4 · uma porta grande demais | O módulo está no carregador do arsenal. Quem pega carrega na mão. No terminal externo da enfermaria, só quem carrega encaixa. Gravação "Sokolov, Mikhail", inspiração atrás da porta, vapor na fresta, **EXERCÍCIO AUTORIZADO** (ordem remota, separada da bateria). |
| 5 · o isolamento | Alarme: giroflex vermelhos girando nos corredores, alerta **● ALERTA · ISOLAMENTO** na tela, painel da entrada **ACESSO EXTERNO BLOQUEADO**. Orlov chama de falha de protocolo e manda pela oficina. |
| 7 · o lugar em que ele procura | Pavel espera na porta da oficina, abre quando o grupo chega e entra. Um jogador fecha a trava (alavanca ao lado dele). Passos pesados em outro setor. Ponto seguro salvo no servidor. |
| 8 · alguém ainda responde | O terminal mostra o arquivo do exercício com o turno **e os nomes de quem está no servidor (KEDR-1, KEDR-2...)**, registrado às 02:31, antes da abertura. Elena pelo rádio, "731", três toques do outro lado da parede. Cartão **PROJETO BASTIÃO · CAPÍTULO 1 — A CHAMADA**. |

Cooperativo: a história é do servidor inteiro. Se quem carrega o módulo sair ou morrer, o
módulo volta ao carregador (com aviso). Quem ficar do lado de fora quando a trava fecha é levado
para dentro (corte preto). Quem renasce depois do ponto seguro aparece dentro da oficina.

Visual igual ao da bodycam que já existe: objetivo no topo, legendas embaixo (sem cobrir os
botões de toque), prompts com a tecla e a ação presos ao objeto (no celular é só tocar na
etiqueta). Prévias: [docs/VALIDACAO_ETAPA1.md](docs/VALIDACAO_ETAPA1.md).

## O que NÃO muda

- **Mapa Sector7World**: nenhuma peça movida, apagada ou recolorida (teste confere as 8.572 peças).
- **HUD da bodycam**, câmera, lanterna, fôlego e menu: intocados.
- **Scripts Sector7**, personagem R6, iluminação: intocados.
- **DataStore / progresso**: não é usado nem resetado. O Place não é resetado.

O instalador só acrescenta 18 scripts com nome `Bastiao...` (servidor, compartilhado e
cliente). Tudo o que a história cria aparece em tempo de execução em `workspace.BastiaoHistoria`.

## Como instalar (Termux, no celular)

1. Baixe `BASTIAO_ETAPA1.py` para a pasta **Downloads**.
2. Conferir o arquivo (sem internet e sem chave):
   `python ~/storage/downloads/BASTIAO_ETAPA1.py testar`
3. Instalar:
   `python ~/storage/downloads/BASTIAO_ETAPA1.py instalar`
   - ele pede a **chave Open Cloud escondida** (não aparece na tela e não é salva);
   - baixa o jogo atual, guarda um **backup completo**, cria uma versão **Saved** (a publicada
     continua igual) e roda o **teste dentro do Roblox**;
   - se o teste passar, pede para você digitar **`PUBLICAR ETAPA1`**. Sem isso, nada é publicado.
4. Se a internet cair no meio do envio: `python ~/storage/downloads/BASTIAO_ETAPA1.py resume`
   (ele confere o que chegou e nunca reenvia às cegas).

## O que testar no celular depois de publicar

1. Entre num servidor novo. Pavel está à frente no túnel; o relógio 02:49 na parede esquerda.
2. Ande até ele: legendas embaixo; depois o objetivo do rádio. Toque em **PEGAR RÁDIO**.
3. Depois da ordem do Orlov, vá ao **arsenal** (corredor de serviço oeste) e pegue o módulo.
4. Leve ao **terminal externo da enfermaria** (mesmo corredor, mais ao sul) e segure **ENCAIXAR MÓDULO**.
5. Veja o vapor na porta de contenção, o alarme e os giroflex girando.
6. Vá à **oficina** (lado leste, pelo cruzamento do meio). A porta abre quando você chega; entre e feche a **TRAVA**.
7. Leia o **terminal da oficina**: seu nome aparece na lista. No fim aparece o cartão do capítulo.
8. Com 2 pessoas: quem não carrega o módulo não consegue encaixar (aparece um aviso).

## Limites desta etapa (honesto)

- **Sem vozes e sem efeitos sonoros ainda**: cada fala vira legenda e cada som importante vira
  legenda de áudio (ex.: `[TRÊS TOQUES CURTOS NO METAL, AO LONGE]`). Vozes e os sons do monstro
  entram junto com o monstro.
- Ponto seguro vale **dentro do servidor** (nada é salvo em DataStore nesta etapa).
- O relógio da base é de apresentação: começa em 02:49 e anda um minuto por minuto.
- O carimbo de data no canto da bodycam é do HUD original (mostra a data real) e não foi mexido.
- Testado **fora do Roblox** (lógica, cenário montado dentro do place real, patch conferido por
  um leitor independente) e com o teste que roda **dentro do Roblox** durante o `instalar`,
  antes de publicar. Ainda não foi visto rodando num celular.

## Próxima etapa (monstro 731-A)

No Drive estão o modelo leve com esqueleto (`Monstro_Rig_Leve_18k.glb`: 18 mil triângulos,
47 ossos, 2 texturas, 3 m) e vídeos de prévia com sons. As **35 animações** estão só em
`Monstro_Grotesco_V2_35_Animacoes_R6.zip` (48 MB), maior que o limite de 10 MB do conector
do Drive: é preciso enviar esse ZIP direto no chat.

## Para quem for mexer no código

- Regras e mapa do projeto: [LEIA_CHATGPT.md](LEIA_CHATGPT.md) e [docs/integration-map.md](docs/integration-map.md).
- Testes: `bash bastiao/ferramentas/testar_tudo.sh /caminho/place_original.rbxl`
- Gerar o instalador: `python3 bastiao/ferramentas/gerar_etapa1.py`
