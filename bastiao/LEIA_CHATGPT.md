# LEIA ANTES DE MEXER — Projeto Bastião (para ChatGPT, Claude ou qualquer IA)

O dono joga e testa só pelo celular (Android + Termux, sem Studio). Respostas em português,
simples e passo a passo.

## Regras que não mudam

1. **Nunca peça a chave Open Cloud no chat.** O instalador pede a chave escondida (getpass) e
   nunca imprime chave ou segredo.
2. **Nunca resete o Place nem o DataStore.** O progresso dos jogadores fica preservado.
3. **Não apague nem altere o mapa `Sector7World`, o HUD da bodycam ou os scripts Sector7**, nem
   em tempo de execução. A história só acrescenta: scripts com nome `Bastiao...` e coisas novas
   em `workspace.BastiaoHistoria`.
4. **Se o teste isolado falhar, nada é publicado.** Publicar só com `PUBLICAR ETAPA<N>` digitado
   pelo dono.
5. Recursos opcionais (imagens, sons, modelos) **nunca** travam a instalação.
6. Efeitos visuais só de pacotes da loja; não desenhe efeito por código/IA. (Luz, neon,
   material e a fumaça padrão do Roblox são permitidos.)

## Como a história funciona

- Conteúdo é dado: `src/ServerScriptService/BastiaoServidor/Capitulo01.luau` (nós, saídas,
  sequências com tempo) e `src/ReplicatedStorage/BastiaoCompartilhado/Textos.luau` (todo texto).
- O `StoryValidator` confere o capítulo com as entidades que o `Cenario` registra. Se não
  validar, o servidor não começa a história (e o teste na nuvem reprova).
- Para uma etapa nova: crie `Capitulo02.luau` (ou novos nós no 01), registre novas entidades
  no `Cenario` e textos em `Textos`, e rode os testes. Nada de lógica espalhada em script solto.
- Interação nova: entra em `cena.interacoes` com `posicao`, `alcance` (10), `evento`, `requer`
  e, se precisar, `validar`. O servidor valida tudo; o cliente só desenha.

## Antes de entregar qualquer mudança

```
bash bastiao/ferramentas/testar_tudo.sh /caminho/place_original.rbxl
python3 bastiao/ferramentas/audio_etapa2.py   # sons: brutos do ElevenLabs -> arquivos do jogo
python3 bastiao/ferramentas/gerar_etapa2.py   # instalador (aprende as fontes já entregues em dist/)
```

O teste de cenário monta tudo dentro do place real e reprova peça atravessando parede, porta
fora do vão, interação sem lugar para ficar em pé e rota do Pavel batendo em algo.

## Onde está cada coisa

- Mapa do projeto e coordenadas: `docs/integration-map.md`
- Resultados e prévias: `docs/VALIDACAO_ETAPA1.md` e `docs/VALIDACAO_ETAPA2.md`
- Instalador (patch só de scripts `Bastiao...`, backup, Saved, teste nativo, recibo e resume):
  `instalador/` + `ferramentas/gerar_etapa2.py`

## Línguas e som (Etapa 2)

- **Texto nunca vai fixo no servidor**: o servidor manda chaves (`fala`, `som`, `ruido`, `aviso`
  com argumentos) e cada cliente mostra/toca na língua do atributo `BastiaoIdioma` do jogador.
  Toda chave nova precisa existir em `Textos.L.pt`, `.en` e `.ru` (o `teste_idiomas` reprova).
- Telas de terminal: o servidor só põe atributos na peça (`BastiaoTela`, `BastiaoTelaEstado`,
  `BastiaoTelaNomes`); o cliente desenha (`BastiaoCliente/Telas.luau`).
- Som: `BastiaoCliente/Som.luau` toca trechos de 4 arquivos (`voz_pt`, `voz_en`, `voz_ru`,
  `efeitos`) descritos no módulo gerado `BastiaoCompartilhado/Audio` (não editar à mão: o
  instalador escreve os IDs depois de enviar os sons).
- Vozes novas: gere no ElevenLabs seguindo `assets/audio/roteiro.json`, salve em
  `assets/audio/brutos/<nome>.mp3`, rode `audio_etapa2.py` e `gerar_etapa2.py`.
