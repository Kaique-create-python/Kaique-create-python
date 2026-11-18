# OI3: jogo de terror no Roblox

Esta pasta tem o jogo inteiro em código. Tudo é montado por código, sem Roblox Studio, e o jogo é publicado por um instalador Python.

## Como instalar (celular, Termux)

```
cd ~/storage/downloads
python OI3_AJUSTE1.py install
```

O arquivo fica em `dist/OI3_AJUSTE1.py`. Ele pede a chave da Open Cloud escondida e nunca a mostra nem salva.

A chave precisa destas permissões, com a experiência OI3 marcada:

- **Assets API**: `asset:read` e `asset:write` (para os áudios).
- **Place Publishing** (`universe-places`): `write`.
- **Luau Execution Sessions**: `read` e `write` (para o teste isolado na nuvem).
- **Universes** `universe:write`: opcional, serve só para reiniciar os servidores.

Para conferir o pacote sem internet, rode `python OI3_AJUSTE1.py testar`.

## Pastas

- `src/`: código Luau, com a mesma estrutura do Roblox: ReplicatedStorage, ServerScriptService, StarterPlayerScripts e ReplicatedFirst.
  - `Mapa.luau`: o orfanato, feito com peças por código. O quarto do espelho também é montado refletido para o efeito de espelho.
  - `Personagens.luau`: rigs R6 com rostos desenhados por código. As roupas oficiais vão entrar depois, pelos IDs do catálogo.
  - `Cliente/MenuCena.luau` e `Cliente/Botoes3D.luau`: o menu 3D e os botões 3D.
  - `Cliente/Cutscene.luau`: a abertura em 8 cenas.
  - `ServerScriptService/OI3_Servidor`: o servidor (mapa, DataStore das configurações e sala multiplayer).
- `assets/`: áudios do jogo.
  - Os efeitos foram sintetizados por código (`tools/audio.py`).
  - As vozes provisórias vieram do ElevenLabs (`assets/vozes_elevenlabs`).
- `tools/`: testes e geradores.
  - `teste_geral.luau`: testes offline com Lune.
  - `montar_place.luau`: gera o `.rbxlx`.
  - `teste_nuvem.luau`: teste que roda na nuvem do Roblox.
  - `gerar_instalador.py`: junta tudo num instalador de um arquivo só.
  - `mock_roblox.py`: Open Cloud falsa, para testar o instalador.
  - `previa_*.luau` e `preview/`: imagens de prévia (aproximadas, feitas com three.js).
- `previas/`: imagens de prévia.

## Como gerar uma nova versão (AJUSTE-N)

1. Mude `Config.REVISAO` para `AJUSTE-N`.
2. Se mudou áudio, rode `python3 oi3/tools/audio.py oi3/assets/vozes_elevenlabs`.
3. Rode os testes com `lune run oi3/tools/teste_geral.luau`.
4. Gere o instalador com `python3 oi3/tools/gerar_instalador.py AJUSTE-N`.

As ferramentas usadas são o Lune 0.11 (`cargo install lune`), Python 3 com numpy e scipy, e ffmpeg. As prévias precisam do `three.min.js` em `tools/preview/`, que vem de `npm i three@0.160.0`.
