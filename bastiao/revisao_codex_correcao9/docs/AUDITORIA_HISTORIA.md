# Auditoria da história e do servidor — correção 10

## A história continua depois da primeira parte?

**Não.** O pacote recebido e a base pública consultada continuam ligados ao
`Capitulo01`, `bastiao_cap01`, versão 1. A correção 9 acrescenta comportamento,
animações e apresentação ao encontro e ao Pavel; não implementa uma etapa
narrativa posterior ao final já existente.

Evidências verificadas no código:

- `src/server/BastiaoServidor.luau` carrega apenas `Capitulo01` e o fornece a
  `StoryValidator`, `Missao` e `Sequencias`. O callback final atualiza `ATR_FIM`;
  não carrega outro capítulo.
- Na base pública, `bastiao/src/ServerScriptService/BastiaoServidor/Capitulo01.luau`
  encerra `s8_lista_fim` em `fim_etapa`, com `final = true` e checkpoint
  `fim_etapa1`. Não existe módulo `Capitulo02` na árvore `bastiao` consultada.
- O último trecho jogável chega à oficina, fecha a trava, lê a lista no terminal,
  ouve Elena/Pavel e os três toques na parede. `pavel_sinal` encerra a sequência.
- O builder da correção 9 mantém `Capitulo01` entre as fontes reconhecidas da
  base e não fornece um capítulo adicional. Os arquivos novos de servidor são
  o núcleo da criatura, a criatura e seu contrato de importação.
- O comentário antigo de `Capitulo01` ainda anuncia perseguição para uma etapa
  futura; a criatura já foi integrada pelas correções. Esse comentário não prova
  continuação narrativa e não foi usado como fonte de conclusão.

Isso descreve os arquivos entregues e a base pública consultada, sem presumir
o conteúdo de qualquer place privado não inspecionado.

## Defeitos confirmados e corrigidos

1. Remover/desativar a criatura durante o jumpscare deixava o jogador vivo
   ancorado, com velocidade e saltos zerados. A captura agora guarda os valores
   anteriores e os restaura na limpeza, inclusive se o encontro falhar. A raiz
   mantém seu estado de ancoragem original. A saída do jogador ou troca de
   personagem cancela a captura antes do golpe fatal e não afeta o respawn.
2. O boot e o Pavel chamavam métodos de grupos de colisão em `workspace`, mas
   esses métodos pertencem a `PhysicsService`. O erro era escondido por `pcall`
   e a atribuição posterior de um grupo não registrado podia interromper o
   cenário. Registro e configuração agora usam o serviço correto.
3. Um `StarterCharacter` sem `Humanoid` ou sem uma raiz física válida gerava
   erro ao construir Pavel. Agora a cópia inválida é descartada, o problema é
   registrado e a missão segue com a mesma estratégia de NPC indisponível já
   usada quando a criação falha.

As capturas fatais de frente e de costas, as pancadas na porta, a busca com
farejar/olhar, o uniforme soviético e os eventos de áudio por marcadores foram
preservados. `PORTA` e `PORTA_FORA` estão ambos declarados: não havia defeito
nessa referência. Nenhuma alteração de mapa ou HUD foi feita nesta auditoria.

## Verificação e limites

- Testes de regressão falharam antes das correções: vítima permaneceu ancorada;
  grupo do Pavel não foi registrado no `PhysicsService`; rig incompleto quebrou
  a construção. Depois das correções, os três casos passam.
- `server_capture_test.luau` executa as closures reais de captura e limpeza com
  fronteiras do motor simuladas: preservação dos valores, saída, respawn,
  variantes de frente/costas, morte no `Impact` e liberação final.
- `server_pavel_test.luau` verifica roupa, chapéu, rosto, caminhada, gesto ao
  chegar, aceno único, variação do parado, registro de grupo e rig incompleto.
- `server_compile.luau` compila as quatro fontes de servidor com Lune 0.11.1.
- `server_creature_core_test.luau` reaproveita 18 casos comportamentais do núcleo:
  visão/LOS, audição, limite da oficina, memória, marcador de golpe e cooldown.
- A suíte declarativa `bastiao/ferramentas/teste_historia.luau` da base pública
  verifica o percurso do capítulo já existente.

Esses testes não executam física, replicação, carregamento de assets, animação
nativa ou câmera no motor Roblox. Um playtest real continua necessário para
validar esses comportamentos no place; não foi realizado nesta sessão.
