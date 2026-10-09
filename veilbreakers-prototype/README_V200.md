# VEILBREAKERS v1.10.0 — Ecos sob as Cinzas

Varyn agora tem nove áreas. Depois do Santuário, Kael atravessa a Estrada das Cinzas, investiga a Cripta dos Ecos e reencontra Ivo na Torre do Vigia. A segunda missão oferece pistas sobre os desaparecimentos e a reação da Marca VIII, preservando os mistérios da história original.

## Chão e profundidade

O personagem e os inimigos ficam dentro do chão de cada área. Céu, arquitetura distante, canais e paredes do primeiro plano bloqueiam a movimentação. Baú, altar e sobreviventes têm colisões próprias; as rotas continuam acessíveis. Os objetos altos entram na mesma ordem de profundidade dos personagens e usam a base visível da imagem para evitar flutuação.

## Combate em ondas

Sempre há no máximo um inimigo ativo. Um aviso de 1,5 segundo indica onde o próximo vai aparecer. Os encontros têm três ondas na Praça, três no Aqueduto, três na Estrada, quatro na Cripta e duas na Torre. Vida, dano e pressão aumentam ao longo da campanha; os últimos adversários são elites. Criaturas contornam obstáculos e golpes não atravessam objetos sólidos.

Cada onda paga sua recompensa uma vez. Progresso e HP do adversário persistem no Continue. A morte do jogador restaura apenas a criatura ainda não vencida; ondas já recompensadas continuam concluídas. Saves v1.9 mantêm as salas já limpas. Há provisões garantidas a cada segunda onda.

## Runas e poder

Abra **STATUS → RUNAS**, selecione uma runa aprendida e prepare a magia.

| Habilidade | Custo | Recarga | Efeito |
| --- | --- | --- | --- |
| Arcana VIII | 18 Mana | 1,1 s | Projétil da Marca VIII |
| Brasas | 22 Mana | 1,6 s | Impacto forte e três pulsos de queimadura |
| Geada | 25 Mana | 2,0 s | Impacto e velocidade do inimigo reduzida por três segundos |
| Marca VIII | 30 Mana | 12 s | Ataque aumentado em 25% por quatro segundos |

Brasas é aprendida no Santuário; Geada exige investigar os ecos na Cripta. Essa descoberta também desperta a Marca VIII, disponível para as lutas da Cripta e da Torre pelo botão próprio nos controles. O poder não altera permanentemente atributos salvos. Pausa, diálogo e inventário congelam os efeitos e recargas.

## Arte e recuperação

São 212 quadros de combate e 35 imagens de cenário, interface, itens, NPCs e runas. As fontes selecionadas e os prompts de image_gen builtin ficam no `project_archive/source_sheets/v20`, junto dos recortes e metadados. Os conjuntos v17, v18 e v19 continuam preservados; o overlay v20 entra por último.

O APK é compilado pelo GitHub Actions; o Termux compila Java contra SDK 35, mas seu AAPT2 ARM não lê a tabela de recursos desse SDK. Contexto, história e metadados atuais são inseridos depois dos overlays.

A entrega usa `tools/sign_local_apk.py` depois da revisão para manter uma assinatura de desenvolvimento fixa neste Termux. O script verifica a assinatura e confirma que todo o conteúdo do jogo continua idêntico ao APK revisado. A chave privada permanece no armazenamento privado; não faz parte da entrega. Builds antigas assinadas pelo GitHub possuem outra identidade e não atualizam diretamente com esta assinatura.

## Verificação

Testes de lógica cobrem rotas, colisões, missões, save, runas, equipamentos e recompensas. As capturas Android precisam confirmar o quadro desenhado por um identificador único e pelos pixels do próprio quadro; tempos fixos sozinhos não aprovam uma cena. A revisão inclui as nove áreas, runas, três magias, poder, inventário, retratos, limites do chão e profundidade do baú.

Consulte a conclusão do workflow e `qa/v20` para a execução Android final. O capítulo continua sendo uma parte da campanha; o restante da história, outras escolas e áudio ficam para incrementos seguintes.
