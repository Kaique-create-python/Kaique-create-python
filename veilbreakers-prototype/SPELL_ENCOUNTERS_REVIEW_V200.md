# Ondas e magias — v1.10

O combate agora mantém um único inimigo ativo, com ondas sequenciais salvas:
3 na praça, 3 no aqueduto, 3 na floresta, 4 na cripta e 2 na torre. O primeiro
Wretch tem 70HP/18ATK; o Vigia final tem 160HP/28ATK. O contador de ondas
também é o ledger de recompensas: cada morte paga XP e moedas inteiros uma
vez; a sala só é liberada após a última onda. Quartos já concluídos em v1.9
permanecem concluídos na migração. Cada segunda onda concede uma atadura e
um tônico, respeitando a capacidade do inventário.

Há uma pausa/advertência de 1,5s entre oponente e seguinte. A aparição escolhe
um ponto caminhável a pelo menos .24H do jogador e avisa antes de ativar o
inimigo. Se o jogador entrar no círculo, ele muda de posição com novo aviso.
O caminho usa a mesma malha de colisões de props/NPC/chão que o jogador;
uma grade leve permite contornar obstáculos. Ataques verificam linha livre.
Elites resistem a interromper um golpe que já passou do início do aviso,
evitando que cada toque mantenha o chefe permanentemente atordoado.

Arcana usa 18Mana/cd1,1s. Brasas usa 22Mana/cd1,6s, dano1,6x e três ticks de
queimadura. Geada usa 25Mana/cd2s, dano1,0x e movimento reduzido em50% por3s.
Marca VIII usa 30Mana/cd12s e dura4s, elevando ataque em25% sem escrever no
atributo permanente ou permitir empilhar a ativação. As runas/poder só podem
ser selecionados após seus desbloqueios de história.

Fogo/gelo ganharam 12 sprites próprios cada, gerados com `image_gen` integrado
a partir de uma referência de estilo. Cristais/neve/mist de gelo têm formas
distintas das chamas/brasas. As fontes, prompts literais, origens autoradas,
master sheets, contact sheets e GIFs ficam em `source_sheets/v20` e
`previews/v20`. `prepare_spell_fx_v20.py` somente isola e alinha os pixels
originais; não inventa partículas ou desenha efeitos procedurais.

São 24 novos PNGs RGBA256, pivô128,128, alpha transparente e margens. Os188
frames anteriores, incluindo conjuração24, corrida24 e Arcana12, permanecem
preservados. O manifesto combinado contém212 frames. A esfera mantém seu
socket/altura visual; colisão usa o plano dos pés capturado no lançamento,
em vez de um offset fixo que divergia entre direções.

Os contact sheets normalizados de fogo/gelo foram abertos e verificados,
assim como os PNGs de corrida existentes. Não houve regeneração ampla dos
personagens; a pequena diferença de perspectiva da segunda fonte lateral
da corrida permanece documentada. O harness de estado e os selftests Android
devem validar ondas/recompensas/migração, custo/dano, queimadura, lentidão,
pausa e bônus temporário antes de declarar a execução completa. Capturas de
assets são previews; evidência Android vem das capturas com token/ACK no run.
