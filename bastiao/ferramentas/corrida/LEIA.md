# Corrida medonha do monstro (correção 10, em andamento)

- `medonho.py`: a pose nova (corcunda, cabeça erguida e torta, braços batendo, tiques e tremor na cabeça,
  espasmo nos dedos). 3 ciclos da corrida original (2,8 s) para os tiques não repetirem. Pernas intactas:
  marcadores Foot_R/Foot_L continuam nos mesmos tempos (0.233/0.700 + 0.933 por ciclo).
- `offsets.py medonho.py off.json`: gera um quaternion por osso por quadro (30 fps, 85 quadros).
- Prévia: servir esta pasta (`python3 -m http.server 8765`), com `three` (symlink para node_modules/three
  0.160) e `monstro.glb` (= modelo/Monstro_Fonte_47ossos_35clipes_Studs.glb) ao lado; `node render.js cena.json saida 30 2.8`.
  O three.js tira o ponto dos nomes dos ossos (upper_arm.L vira upper_armL): o index.html já trata isso.
- `lune run aplicar_rbxm.luau 08_CORRER.rbxm off.json 36_CORRER_MEDONHO.rbxm 36_CORRER_MEDONHO`:
  gera a animação do Roblox (`assets/monstro/36_CORRER_MEDONHO.rbxm`, 85 keyframes, 2,8 s, loop, Movement).
- Conferido: os 46 ossos do Roblox têm o mesmo repouso do GLB e Pose.CFrame = Transform (rest*T = GLB),
  então Pose * offset no Roblox = GLB * offset na prévia (mesmo resultado do vídeo `docs/PREVIA_CORRIDA_MEDONHA.mp4`).

## Falta para entregar (CORRIGIR_ETAPA3_10.py)
1. `modelo/MONSTER_ASSET_PLAN.json`: entrada id 36 "36_CORRER_MEDONHO" (duration 2.8, loop, Movement,
   6 marcadores Foot, file animations/36_CORRER_MEDONHO.rbxm, sha256, assetType Animation, contentType model/x-rbxm).
2. `tooling/release_builder.py` `monster_catalog`: hoje exige `len(animations) == 35`; aceitar as 35 originais
   + extras OPCIONAIS (extra sem recibo pronto fica fora do catálogo, sem erro).
3. `instalar.py` comando `assets`: hoje falha se QUALQUER asset não estiver pronto; extra opcional
   recusado/pendente só avisa (regra: recurso opcional nunca trava a instalação).
4. `src/teste_nuvem.luau`: `quantidade == 35` vira "35 originais + extras conhecidos".
5. `src/server/Criatura.luau`: pôr "36_CORRER_MEDONHO" em EXTRAS (Movement, Looped=true!) e, na escolha da
   corrida (`name = ... "08_CORRER"`), usar a medonha se `c.tracks["36_CORRER_MEDONHO"]` existir (mesma
   velocidade autoral 3.2). Hoje o carregador de extras força `Looped=false`: a corrida precisa de loop.
6. Sons novos (ElevenLabs) em `assets/audio/etapa3/candidatos_correcao10/`: escolher 1 de cada
   (passos_longe, tres_toques_parede, alarme, portas), virar `reuse` no AUDIO_PLAN com sha256, como na correção 9.
7. `gerar_correcao10.py` + verificação completa (cadeia v17 -> 8 -> 9 -> 10 com recibos emulados, `--proprias`).
