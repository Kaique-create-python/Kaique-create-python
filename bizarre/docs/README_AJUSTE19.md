# BIZARRE AJUSTE-19 — HUD novo

**Instalador corrigido em13/11/2026:** veja [CORRECAO_AJUSTE19.md](CORRECAO_AJUSTE19.md). O validador Luau agora reconhece18/19; preserva o HUD/VFX e reconhece a AJ19 já salva. Baixe novamente; não apague estado.

Pedido do Kaique: HUD bem mais bonito, no estilo battlegrounds (referência de gênero: Jujutsu
Shenanigans), usando as skills de design. Identidade própria, sem copiar a arte de outro jogo.
Testado só offline (50/50 comandos); nada foi testado ou publicado no Roblox.

## Crítica do HUD antigo (design-critique)
- Botões cobriam 41% do meio da tela no Galaxy A06 (30% no iPhone) e ficavam em cima do personagem.
- Número da recarga em cima do nome do golpe ("STAR 5NGER"); "7 HITS" em cima do DASH.
- Texto Bangers pequeno (8-10 px no celular), roxo + dourado + vermelho sem hierarquia, "3" e "64%" sem explicação.

## O que mudou
- Vida em cima à esquerda: aba inclinada na cor da aura com o nome do Stand (Bangers), barra de vida
  inclinada vermelha com rastro de dano, número grande; despertar em 10 gomos dourados; chip ESQUIVA.
- Golpes 1-4 viraram cartões inclinados numa fileira embaixo no meio (selo com o número na cor do
  Stand; na recarga só o número grande e a faixa diminuindo). PC: mesma barra com o G.
- ATACAR grande com aro na cor do Stand; DEFESA e DASH em volta do pulo; DESPERTAR é um "tanque" que
  enche de dourado e pisca quando pronto; STAND/MIRA/SHIFT LOCK/POSE quietos no canto de cima.
- Abates logo abaixo da vida; combo ao lado do meio; avisos numa fita acima dos golpes.
- Duas fontes só: Bangers (momentos grandes) + Roboto Condensed Bold (rótulos e números).
- Tablet: reserva maior para o joystick/pulo grandes do Roblox. Escala 1 no celular, até 1,35 no PC.
- Meio da tela coberto: A06 41% -> 2%; iPhone 30% -> 1%; SE 26% -> 2%.

Mantido: toda a lógica (recargas, despertar, guarda, esquiva, editor de botões, preferências salvas,
TO BE CONTINUED). Layouts salvos pelos jogadores continuam valendo.

## Termux
```sh
python ~/storage/downloads/BIZARRE_AJUSTE19.py testar
python ~/storage/downloads/BIZARRE_AJUSTE19.py instalar
```
Digite `PUBLICAR AJUSTE19` quando pedir. Reconhece o jogo nas versões 14 a 19.

## Ferramentas
- `tools/previa_hud19.luau` + `tools/previa_hud19.py`: roda o HUD real no Lune e desenha no tamanho
  do celular (Chromium) com medida de cobertura. Imagem: `docs/previa_hud19.jpg` (antes/depois).
- `tools/tests_hud19.luau`: layout em 12 telas, geometria, recargas, despertar, fontes, sobreposição.
- Teste na nuvem 19 monta as peças do HUD no motor antes de publicar.

Limites: a prévia não é o renderizador do Roblox (fontes da web, sem bloom). Conferir no celular.
Migração 14-18 coberta pelos hashes reconhecidos; a cadeia completa (migracao18.py) não foi rodada de novo.
