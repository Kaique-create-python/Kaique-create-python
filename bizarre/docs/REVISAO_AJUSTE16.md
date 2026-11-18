# Revisão final AJUSTE-16

Uma revisão estática independente examinou a mudança a partir da AJ15 (base720a733,
fontes revisadas atéf7d5963). Sem alterações pelo revisor ou execução nativa Roblox.

Três problemas importantes foram encontrados e corrigidos pelo implementador:

1. O final da ULT CD ainda estava ancorado ao aplicar o empurrão. A liberação do vínculo
   agora é processada antes do acerto, respeitando outras prisões e sessões de tempo.
   Regressão com a mesma recusa de empurrão em raiz ancorada da física real: RED→GREEN.
2. Explosões/projéteis CD/KQ podiam usar o contexto de uma ação posterior ou sobreviver
   a morte/troca/remoção do dono. Capturam identidade no lançamento e mantêm atribuição;
   reflexão transfere somente o vínculo do projétil refletido, com definição independente.
   Regressões de tanque após M1 e cancelamento/reflexão: RED→GREEN. Crossfire existente
   também conserva seu dano/contexto após uma ação seguinte, coberto por regressão.
3. A sobreposição por acessório e a visão lateral de projéteis ainda eram filtradas
   somente para SP/TW. O predicado agora é o perfil compartilhado dos seis Stands.
   Projétil+Hitbox+registro reais, com fronteiras de colisão controladas:
   corpo acerta, acessório isolado e vítima atrás de parede falham — RED→GREEN.

Nenhum problema crítico ou menor foi listado. Houve uma única rodada de correções,
verificada por testes, sem nova revisão independente.

A avaliação visual, física e FPS nativos, legibilidade no celular e coreografia completa
sob tempo parado exigem cliente Roblox. O revisor não os avaliou; o instalador mantém
Saved/teste e confirmação explícita antes de publicar. O hash/preservação do pacote
final foram deixados ao implementador; evidência em ENTREGA_AJUSTE16.json e
RESULTADOS_AJUSTE16.json. Nenhuma desses resultados locais representa publicação.
