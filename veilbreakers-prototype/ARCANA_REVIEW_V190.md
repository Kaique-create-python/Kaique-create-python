# Arcana VIII — revisão v1.9.0

A revisão das capturas Android v18 confirmou quatro falhas: a conjuração
movia principalmente o braço e terminava direto em idle; a esfera/faísca já
estava pintada no sprite enquanto o runtime desenhava outra esfera; o núcleo
escuro do projétil quase desaparecia no mapa; o trail autorado para direita
não girava com sua direção real de movimento.

## Mudança visual e comportamento

Kael agora passa por seis fases: preparação, câmara, carga, arremesso,
continuação do gesto e repouso. As 16 poses centrais novas mostram joelhos,
cintura, ombros e braço transferindo peso. Os oito endpoints de preparação e
repouso conservam os arquivos v17 bons. As mãos novas ficam vazias: uma única
esfera de runtime nasce e cresce no socket da luva. Há 24 PNGs de conjuração
com pivô `(128,232)`, célula 256×256 e escala corporal de referência 174px.

O lançamento ocorre na pose 3 aos **0,34s**; a recuperação termina aos
**0,72s**. O projétil nasce no socket autorado de liberação e só se desloca
pelo tempo transcorrido depois dessa fronteira. Dano, colisão e consumo de
Mana mantêm suas regras. O impacto visual começa no mesmo HIT que aplica o
dano uma vez, e o status/diálogo continuam pausando seus relógios.

Os 12 efeitos novos usam núcleo branco/magenta, energia violeta/carmesim,
trail autorado, choque e quatro fases de impacto distintas. A origem é o
núcleo, não o centro dos bounds do trail. A rotação acompanha direita,
esquerda, cima e baixo. O choque da luva dura somente 55ms e desvanece antes
de parecer uma segunda esfera parada. O impacto progride por flash, ruptura,
anel e dissipação durante 335ms.

## Origem e preservação

As imagens foram geradas e editadas com `image_gen.imagegen` integrado,
sempre solicitando alpha transparente e usando o model sheet existente de
Kael. Uma correção focal manteve a recuperação DOWN olhando para frente;
outra separou os efeitos de seus vizinhos. A folha gerou as duas direções
laterais em linhas trocadas: o recorte as mapeia pela direção efetivamente
desenhada, sem espelhamento. Os prompts completos e a seleção estão em
`project_archive/source_sheets/v19/ARCANA_PROMPTS.txt`.

`tools/prepare_arcana_v19.py` somente isola os pixels da fonte, recorta,
reamostra com fatores compartilhados, alinha pivôs e registra sockets. Não
desenha personagens ou efeitos procedurais e não inventa frames. Fontes,
origens manuais, master sheets, contact sheets e GIF ficam arquivados em
`source_sheets/v19` e `previews/v19`.

Os 24 frames de corrida v18 foram novamente examinados nas capturas Android
e nos PNGs: não há células vazias, bordas cortadas ou falta de frames. Existe
a limitação conhecida de oclusão da perna próxima/distante e pequena
diferença de perspectiva na segunda fonte lateral. Esses frames bons foram
preservados; a revisão não declara que essa limitação anatômica desapareceu.
Os demais idle, walk, combos e inimigos também permanecem com os bytes
anteriores. O contrato final contém 188 frames: 24 cast novos/selecionados,
12 efeitos, e 152 registros v18 preservados.

## Evidência e verificações

As contact sheets `kael_cast_socket_contact.png` e `arcana_fx_contact.png`
foram abertas e examinadas: identidade, direção, número de membros/espada,
apoio dos pés, fases distintas, mãos vazias, pivôs, padding e sockets. A
marca azul indica a luva, a amarela a origem da esfera. Esses são previews de
assets, não capturas Android.

`V19_ARCANA_ASSET_QA.json` confirma 36 PNGs RGBA 256×256 com alpha e margens,
SHA256 atual e sockets ativos tocando pixels da luva em até quatro pixels.
`KAEL_AUDIT_V190.json` registra a inspeção dos 24 runs e os defeitos antigos.
O selftest isolado Android cobre liberação nas quatro direções, socket sem
adiantar o projétil, impacto ligado ao HIT e ausência de dano duplicado.
A execução Android e a inspeção do novo APK devem ser consultadas no run
correspondente; a validação técnica não mede anatomia ou suavidade.
