# SETOR 7: O Último Sinal

## Premissa

Novembro de 1989. Sob uma estação ferroviária desativada, numa região fictícia da União Soviética, o SETOR 7 intercepta sinais de rádio que não aparecem em nenhuma frequência oficial. Após uma queda de energia, a equipe de manutenção desce para restaurar o circuito. Os relatórios falam de uma voz que atravessa canos, fios e alto-falantes desligados. Ela conhece o nome de quem ainda está lá embaixo.

A instalação, os personagens e os acontecimentos são ficcionais. A ambientação usa concreto úmido, túneis abobadados, trilhos de serviço, tubulações antigas e máquinas analógicas. A ameaça deve ser sugerida por presença, distância e ruído; as notas revelam o ocorrido sem interromper a exploração por longos períodos.

## Objetivo do jogador

Encontrar **três fusíveis**, **ligar o gerador**, **recuperar o cartão de acesso** e **abrir a saída de evacuação**. A progressão é cooperativa por servidor: cada fusível recolhido ajuda todo o grupo. Correr consome estamina; guardar fôlego permite escapar da ameaça nos corredores. O jogador pode ler as quatro notas para entender os acontecimentos, mas a leitura não deve bloquear a missão.

Mensagens curtas sugeridas para o HUD, conforme o estado:

1. `ENCONTRE OS FUSÍVEIS — 0/3` (atualizar a contagem).
2. `RESTABELEÇA A ENERGIA — Ligue o gerador`.
3. `RECUPERE O CARTÃO — Procure no arquivo`.
4. `EVACUE — Use o cartão na saída`.
5. `VOCÊ SAIU DO SETOR 7`.

## Notas de ambiente

Os IDs abaixo correspondem ao atributo `InteractionId` das peças interativas. Os locais são orientações narrativas, ajustáveis ao layout do mapa.

### Note1 — Ordem de manutenção

Local sugerido: papel interativo junto ao depósito inicial, com leitura pela interface.

> 17 de novembro de 1989. Três fusíveis foram retirados: um no depósito, outro na sala de máquinas e o último no arquivo. Reponha os três no circuito antes de tentar ligar o gerador. A porta de evacuação continua sem energia.

### Note2 — Registro de escuta

Local sugerido: mesa de rádio num túnel lateral.

> O sinal voltou às 02h17. Não veio da antena. Veio dos canos. A voz repetiu nossos nomes na ordem do livro de presença. Se ouvir alguém chamando no túnel vazio, mantenha a lanterna acesa e continue andando.

### Note3 — Protocolo do arquivo

Local sugerido: parede ou bancada do arquivo.

> Depois de restabelecer a energia, retire o cartão de acesso do arquivo. O leitor da saída só libera a porta com o gerador ligado e o cartão recuperado. Não abra a sala de escuta.

### Note4 — Última transmissão

Local sugerido: antecâmara da saída.

> Apagamos a frequência e a voz continuou. Morozov correu até ficar sem ar; ela o alcançou no escuro. Caminhe quando puder. Guarde fôlego para a saída. Se a porta abrir, não espere pelo último sinal.

## Direção para o acabamento

Os textos narrativos e as instruções aparecem em português na interface. Por decisão expressa do usuário, o ambiente não recebe placas, letreiros, letras, `SurfaceGui`, `TextLabel` nem fundos de placas. Detalhes soviéticos podem aparecer nas formas dos equipamentos e nos documentos lidos pela interface. Painéis metálicos estruturais das paredes permanecem. Evitar símbolos históricos usados como celebração política. O foco da história é uma instalação de escuta fictícia e o medo de responder a um sinal desconhecido.

As fotografias do usuário são referência de atmosfera e formas arquitetônicas; não estabelecem a localização real da história. Para a primeira versão, conservar o percurso legível e a sequência fusíveis → gerador → cartão → saída.
