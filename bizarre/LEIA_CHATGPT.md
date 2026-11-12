# BIZARRE BATTLEGROUNDS — leia antes de continuar

Jogo JoJo de Kaique. **Universe 10774214555; Place 108061345551908.**
Ele usa Android/Termux, sem Roblox Studio. Responda em português com comandos curtos.
Repositório: `Kaique-create-python/Kaique-create-python`, ramo
`claude/context-capture-w0uo2t`, pasta `bizarre/`.

## AJUSTE-16 — entrega atual

Leia [README_AJUSTE16.md](docs/README_AJUSTE16.md) e [VALIDACAO_AJUSTE16.md](docs/VALIDACAO_AJUSTE16.md).
CD/KQ e ORA/MUDA do vídeo revisados; preservam kits, dano/CD, mapa, mídia e câmera.
A IA só testou offline. Última publicação confirmada pelo usuário: AJ14 v36.
Última saída AJ15: Saved com conferência interrompida por rede; envio pendente. Não
assumir instalação15/16; resolver com o resume do instalador que iniciou o envio.
A16 aceita fontes14/15 reconhecidas, estado16 próprio e confirmação PUBLICAR AJUSTE16.
Build: tools/gerar_ajuste16.py. Não regenerar14/15 com as fontes16.

## AJUSTE-15 — continuação atual

Leia [README_AJUSTE15.md](docs/README_AJUSTE15.md) e [PLANO_AJUSTE15.md](docs/PLANO_AJUSTE15.md).
AJ14 teve teste nativo aprovado e publicação v36 confirmada pelo usuário. AJ15 atualiza SC/MR,
preparada/testada offline; não assumir instalação/publicação15 sem resultado do usuário.
Use BIZARRE_AJUSTE15.py testar/testar-nuvem/publicar/resume; confirmação PUBLICAR AJUSTE15.
Preservar inteiro ~/.bizarre_instalador e14; não repetirsetup/assetsupload. Gerar com tools/gerar_ajuste15.py.
As instruções14 abaixo são histórico/base, não substituir a15 por14 ao continuar.

## Estado atual

- Kaique confirmou que a **AJUSTE-13 instalada** tem animação e câmera funcionando.
- A **AJUSTE-14** é o piloto de combate/VFX de **Star Platinum e The World**.
  Os outros quatro kits mantêm seu comportamento; o perfil de iluminação é global.
- Leia [README_AJUSTE14.md](docs/README_AJUSTE14.md), o plano aprovado
  [PLANO_AJUSTE14.md](docs/PLANO_AJUSTE14.md) e [VALIDACAO_AJUSTE14.md](docs/VALIDACAO_AJUSTE14.md).
- Testes locais e inspeção do Place são verificações offline. Não representam uma partida,
  renderização, física, autorização online de texturas, FPS ou publicação no Roblox.
  O último resultado real da instalação sempre vem de Kaique.

## Instalar a AJUSTE-14

O instalador novo baixa o **Place completo atual** e altera somente Sources reconhecidas,
acrescentando módulos e o catálogo visual sanitizado. Não reconstrói Morioh.
Não usar o antigo `install --substituir` para esta entrega.

```sh
python ~/BIZARRE_AJUSTE14.py testar
python ~/BIZARRE_AJUSTE14.py testar-nuvem
```

`testar` confere a integridade offline, sem chave/rede. `testar-nuvem` pede a chave oculta,
preserva backup, cria **Saved** se necessário e testa essa versão no motor. A versão
Published continua a mesma. Somente após **TESTE APROVADO**, com autorização do dono:

```sh
python ~/BIZARRE_AJUSTE14.py publicar
```

Ele exige `PUBLICAR AJUSTE14`. Se a resposta de um envio ficar incerta, use `resume`;
nunca repetir POST ou apagar `~/.bizarre_instalador/active-write.json`.
Preserve toda a pasta `~/.bizarre_instalador`, inclusive recibos anteriores.

## Regras

- Nunca pedir senha, cookie ou chave no chat; nunca colocar segredo em código, arquivo ou log.
  Chave somente `getpass` no Termux, mantida em memória durante o comando.
- Nunca publicar sem confirmação, resetar Place/DataStore ou trocar de universo.
- Fonte desconhecida bloqueia e exporta ZIP para revisão; não forçar ou reconstruir uma base.
- Manter Morioh/colisões, seis Stands, R6, andar/correr do dono, mira manual/Shift Lock,
  distância de câmera aprovada, IDs de mídia, áudios e progresso.
- VFX são dos pacotes reais enviados pelo dono. Código de modelos externos nunca é executado.
  Texturas/sons opcionais indisponíveis recebem aviso/fallback; não inventar IDs nem reenviar mídias.
- ORA/MUDA completos 4,6 s, sem cancelamento voluntário. Qualidade alta, sem redução automática
  por FPS nesta etapa. Não ampliar o piloto aos quatro outros kits sem validar com Kaique.

## Fontes e ferramentas

- `src/ReplicatedStorage/BB/PerfilCombate14.luau`: política de sequência, buffer e extensão aérea.
- `src/ServerScriptService/BB_Servidor/`: validação de golpes, hitbox, projéteis e sessões de tempo.
- `src/ReplicatedStorage/BB/VFXReceitas.luau`, `Cliente/VFXPiloto.luau`, `Cliente/Apresentacao14.luau`:
  receitas, renderer e integração de previsão/confirmação.
- `assets/vfx14/`: catálogo RBXM/XML, manifesto de origem e propriedades.
- `Cliente/Camera.luau`, `Cinematica.luau`, `AmbienteVisual14.luau`: câmera, ULT e iluminação.
- `Cliente/PreviaVFX14.luau`: **ADM → PRÉVIA VFX**, cena local de 6,2 s sem dano/remotos/áudio de ataque.
- `installer14/`, `tools/gerar_ajuste14.py`: patcher e protocolo de envio. Baseline AJ13 registrada
  em `installer14/baseline13.json`; `tools/teste_nuvem14.luau` é o teste nativo desta entrega.
- `tools/instalador_modelo.py` e o montador antigo são históricos, não o caminho AJ14.

Build, da raiz do repositório:

```sh
python3 bizarre/tools/gerar_instalador.py AJUSTE-14
/caminho/do/lune run bizarre/tools/teste_geral.luau
python3 bizarre/tools/lint.py
cd bizarre
python3 -m unittest discover -s tests
```

Rode também os testes `tools/tests_*14*.luau` descritos no relatório de validação. Ao mudar
uma Source, gere novamente o instalador e seus hashes; não entregar só um fragmento.
