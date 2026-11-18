# BIZARRE BATTLEGROUNDS (Roblox)

Jogo de luta no estilo "battlegrounds" (referência: Jujutsu Shenanigans), com sistema de **Stands**: um espírito lutador que aparece atrás de você e bate junto. Os 6 Stands são **originais** e têm nomes de estilos de música brasileira, do mesmo jeito que, na história de onde vem a ideia, cada Stand tem nome de música.

Tudo é feito por código, sem Roblox Studio, e publicado por um instalador Python.

- Universe 10774214555
- Place 108061345551908
- Dono (UserId) 1357078972

## Como instalar (celular, Termux)

```
cp ~/storage/downloads/BIZARRE_AJUSTE1.py ~ && cd ~ && python BIZARRE_AJUSTE1.py install
```

A chave da Open Cloud é pedida escondida. Ela precisa destas permissões, com a experiência marcada:

- **Place Publishing** (`universe-places`): `write`.
- **Luau Execution Sessions**: `read` e `write`. É o teste isolado: monta a cidade e os 6 Stands e faz uma luta com todos os golpes antes de publicar.
- **Universes** `universe:write`: opcional, só para reiniciar os servidores.

Não precisa de Assets API: os sons são da biblioteca liberada do Roblox e os corpos dos Stands vêm do catálogo.

## O jogo

- **Combate.** M1 de 4 golpes; o 4º arremessa e quebra paredes. Pulando, ele vira para cima; no ar, crava no chão.
  - Bloqueio de frente. Apertar na hora do golpe dá **PARRY**.
  - Dash para frente, para o lado e para trás.
  - **Evasiva**: dash quando estiver atordoado.
  - **DESPERTAR**: a barra enche batendo e apanhando. Desperto, você bate mais forte, as recargas ficam mais curtas e libera a **ULT**.
- **Stands**: MARACATU (força), BOSSA NOVA (tempo, pode parar o tempo), FREVO (velocidade, sombrinha), AXÉ (fogo), CHORINHO (conserta o mapa em cima dos inimigos) e FUNK (som e grave). Cada um tem 4 golpes, uma ULT e uma passiva.
- **Mapa quebrável**: a "Vila Bizarra" tem 14 prédios feitos de painéis, carros, árvores, postes, uma feira, um chafariz e uma estátua. Tudo quebra e volta sozinho depois de uns 30 segundos.
- **Treino**: área cercada com bonecos (um deles bloqueia) e bots que lutam (fácil, médio e difícil).
- **ADM** (dono): botão vermelho com bots, cura, despertar, sem recarga, imortal, restaurar ou quebrar o mapa e troca de Stand.
- **Estatísticas**: abates, mortes e melhor sequência ficam salvos em `BB_Jogadores_v1`. Cada salvamento só soma ao que já existe; nada é apagado.

## Pastas

- `src/`: código Luau na mesma estrutura do Roblox.
  - `ReplicatedStorage/BB`: dados e regras (`Config`, `Regras`, `Stands`, `Golpes`, `Poses`, `Sons`, `Rig`, `Mapa/Plano`) e `Cliente/`, que é tudo o que roda no celular.
  - `ServerScriptService/BB_Servidor`: o servidor (`Combate`, `Executores`, `Mapa`, `Projeteis`, `Fisica`, `Hitbox`, `StandModelos`, `Bots`, `Dados`, `Admin`).
  - `ReplicatedFirst/Carregando`: a tela de carregamento, para não ficar tela preta.
- `tools/`: testes, prévias e o instalador.
- `previas/`: imagens de prévia.

## Como gerar uma nova versão (AJUSTE-N)

1. Mude `Config.REVISAO` para `AJUSTE-N`.
2. Rode os testes: `lune run bizarre/tools/teste_geral.luau`.
3. Gere o instalador: `python3 bizarre/tools/gerar_instalador.py AJUSTE-N`. Ele fica em `bizarre/dist/BIZARRE_AJUSTEN.py`.
4. Teste o instalador sem internet: `python3 bizarre/dist/BIZARRE_AJUSTEN.py testar`. Para testar contra a Open Cloud falsa, use `tools/mock_roblox.py` com a chave `CHAVE-DE-TESTE`.
5. Prévias:
   - `lune run bizarre/tools/previa.luau && node bizarre/tools/preview/shot.js bizarre/tools/out/lote.json`
   - `python3 bizarre/tools/previa_stands.py`
