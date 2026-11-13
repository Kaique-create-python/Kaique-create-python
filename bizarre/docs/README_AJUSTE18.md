# BIZARRE AJUSTE-18

Base: Kaique confirmou a AJUSTE-16 publicada e funcionando. A AJ17 (ChatGPT) foi preparada e testada
offline; não há confirmação de instalação dela. A AJ18 vem por cima da AJ17 e reconhece um Place em
AJ14, AJ15, AJ16 ou AJ17. A IA não fez teste autenticado nem publicou no Roblox.
Universe 10774214555 · Place 108061345551908. Android/Termux, sem Studio.

## O que mudou

Revisão do combate contra as skills (roblox-vfx, roblox-feel-audio-vfx, roblox-animation-vfx,
roblox-camera, roblox-lighting, roblox-combat-tools, roblox-engine-2026). Só efeitos dos pacotes da
loja: nada desenhado por código.

- **Acerto em degraus (6 kits):** o impacto/clarão sai no contato e as outras camadas entram em
  degraus de 0,025–0,05 s. A intensidade só cai depois do contato (Star Platinum/The World começam
  pelo impacto de direção, Silver Chariot pelo corte, Magician's Red pelo fogo, Diamond/Queen pelo
  impacto).
- **Sem bola branca atrasada:** nos acertos, brilhos de pacote que cresciam por ~1 s sobre o alvo
  (emissores `Light`/`Core*`) ficam de fora, e as outras camadas longas duram no máximo 0,45 s.
  EmitDelay/EmitCount continuam literais. Tempo parado, rolo compressor e explosão não mudam.
- **Soco realçado:** a camada `Punch_0x` ganha Brightness ×2,4 (só emissores aditivos fracos), para
  ler em cena clara com bloom alto (limiar 1,5).
- **Luz do impacto:** PointLight sem sombra, 0,35 s (0,45 s no forte), que apaga enquanto o alcance
  cresce. No máximo 8 ao mesmo tempo e 1 por lutador a cada 0,12 s. Bloqueio não acende.
- **Pico segurado:** o efeito para junto com a pausa dos corpos (0,04 s leve, 0,08 s forte). Rajada
  e defesa não seguram.
- **Soco de FOV:** golpe forte do próprio jogador fecha o FOV ~6° em 0,05 s e volta com rebote leve
  em 0,25 s. Desligado quando o tremor está desligado nos AJUSTES.
- **Animação:** o Animador aceita `AnimationConstraint` além de `Motor6D` (Avatar Joint Upgrade do
  Roblox), para as animações do dono continuarem quando o Roblox trocar as juntas.
- **Instalador:** comando novo `instalar` = `testar-nuvem` + `publicar` num comando só (a chave é
  pedida uma vez). As travas são as mesmas: Saved testada antes, `PUBLICAR AJUSTE18` digitado,
  recibo e `resume`. Se o teste reprovar, nada é publicado.

Preservados: mapa Morioh, seis Stands, R6, andar/correr do dono, câmera aprovada/Shift Lock, mídias
e IDs, Golpes/Regras, DataStores e progresso. Nenhum som ou imagem é reenviado.

## Termux

Preserve `~/.bizarre_instalador` inteira. Sem setup nem assets-upload.

```sh
gh api 'repos/Kaique-create-python/Kaique-create-python/contents/bizarre/dist/BIZARRE_AJUSTE18.py?ref=claude/context-capture-w0uo2t' -H 'Accept: application/vnd.github.raw+json' > ~/BIZARRE_AJUSTE18.py
python ~/BIZARRE_AJUSTE18.py testar
python ~/BIZARRE_AJUSTE18.py instalar
```

`testar` não usa chave nem rede. `instalar` pede a chave oculta, guarda backup do Place completo,
cria uma Saved, testa no motor e, só se passar, pede `PUBLICAR AJUSTE18`. Quem preferir em dois
passos: `testar-nuvem` e depois `publicar`. Resposta incerta: `python ~/BIZARRE_AJUSTE18.py resume`.
Recibo de outro instalador: use o `resume` dele; nunca repetir POST ou apagar `active-write.json`.

## Conferir no celular

1. M1 1–4 em cada Stand, num boneco de treino: o clarão sai no contato, sem bola branca crescendo
   sobre o alvo depois; a luz pisca e some.
2. 4º soco e golpes fortes: pausa curta com o efeito parado junto; a câmera dá um "soco" de zoom e
   volta. Com o tremor desligado nos AJUSTES, o zoom some.
3. ORA/MUDA e defesa: sem pausa nem luz extra; duração 4,6 s igual.
4. Andar/correr do dono e poses dos Stands iguais à AJ16/17.
5. Luta com várias pessoas: sem queda visível de FPS.

## Limites

Os testes offline simulam serviços e relógio com módulos e instâncias reais de Lune; não provam
renderização, física, replicação, áudio nem FPS no Android. A prévia `previa_vfx18.py`
(imagem `docs/previa_hit18.jpg`: AJ17 em cima, AJ18 embaixo, de 0,03 s a 0,5 s) é uma simulação
de partículas com as texturas reais dos pacotes, não uma captura do Roblox.

Fontes em `src/`, build `python3 bizarre/tools/gerar_ajuste18.py`. Reconhece hashes 14/15/16/17,
acrescenta só ModuleScripts e bloqueia Source desconhecida. Relatórios: VALIDACAO_AJUSTE18.md,
ENTREGA_AJUSTE18.json, RESULTADOS_AJUSTE18.json. Migração: `python3 bizarre/tools/migracao18.py`.
