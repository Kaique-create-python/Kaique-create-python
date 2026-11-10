# BIZARRE BATTLEGROUNDS — plano para deixar tudo cabuloso

Referência: Jujutsu Shenanigans (combate rápido, câmera de ombro, ragdoll, ULT com cena).
Cada AJUSTE é um instalador (`BIZARRE_AJUSTE<N>.py`) que só publica se o teste na nuvem passar.

## Feito até o AJUSTE-7
AJUSTE-7: câmera de mira a 11 studs com proteção de parede, botões que não travam, menu que só
fecha com o servidor confirmando, ajustes (câmera, tremor, volume, qualidade), carregamento com
etapas reais, ORA x MUDA, seta TO BE CONTINUED, Morioh mais leve, salvamento sem duplicar e
instalador que confere a versão no ar. Detalhes em RELATORIO_AJUSTE7.md.

## Feito no AJUSTE-8
- **Sons do dono**: ORA ORA (Star Platinum), MUDA MUDA (DIO), ZA WARUDO e Star Platinum The World com o som
  de parar o tempo. Ficam num áudio SEPARADO (se o Roblox recusar, as vozes geradas continuam). As rajadas
  duram o som inteiro (~4,5 s, mesmo dano total) e o tempo para junto com o som (1,7 s).
- **Câmera que gruda**: trava sozinha em quem você bate ou em quem te bate, segue mais firme, aguenta 3 s
  atrás de parede, passa para o inimigo mais perto quando o alvo cai; AJUSTES > MIRA NA LUTA desliga.
- **Andar JoJo de verdade**: tronco gira, quadril rola, braços em arco, passo largo, corrida inclinada.
- **Interface (Canva)**: tela de abertura com a arte e o logo grande, arte atrás do menu e na tela de
  carregamento, logo novo (dourado). Imagens opcionais: sem elas o menu de texto continua.

| Área | O que já tem |
|---|---|
| Stands | 6 Stands da JoJo em R6, roupa e acessórios do catálogo, sólidos, sem colisão com ninguém |
| Combate | M1 com combo, bloqueio/parry, dash, evasiva, 4 golpes + ULT por Stand, despertar |
| Mira | trava no alvo (MIRA/T), losango no alvo, personagem de frente, ímã do M1, servidor corrige a direção |
| Ragdoll | juntas soltas de verdade, empurrão curto, levanta em pé, 0,9 s sem cair de novo |
| ULTs (AJUSTE-4) | cena de anime: barras de cinema, câmera de close → giro → ombro, nome do golpe 『』, ゴゴゴ, linhas de mangá |
| Andar (AJUSTE-4) | andar/parado/correr estilo JoJo de cada usuário (Jotaro com as mãos no bolso, DIO de peito estufado...) |
| Golpes (AJUSTE-4) | rajada com braços fantasmas do próprio Stand, partículas, coluna de fogo, rolo compressor |
| Mapa | Morioh (ChatGPT) quebrável, máximo 40 peças por golpe, volta sozinho, chão nunca quebra |
| Vozes | ORA, ORAAA, Star Platinum The World, ZA WARUDO, DORARARA, Bites the Dust |
| Interface | menu com cartões, status do Stand em letras A–E (AJUSTE-4), HUD com recargas e combo |

## Próximos passos (ordem sugerida)
1. **Vozes que faltam** — HORA, Crossfire, DORA final e "Killer Queen" (MUDA veio do som do dono).
2. **Ajustes salvos** entre partidas (campo novo no DataStore, sem apagar nada).
2b. **Mais arte** — retrato de cada Stand nos cartões do menu e HUD com moldura desenhada (o Canva
   ficou sem créditos no AJUSTE-8; o logo foi desenhado por código).
3. **ULTs ainda mais cinematográficas** — câmera própria para cada ULT (ex.: ZA WARUDO mostra o
   relógio parando; Bites the Dust mostra a mão apertando o botão), câmera lenta de 0,3 s no impacto.
4. **Animações de golpe por Stand** — poses de mangá no fim de cada golpe (pose de vitória ao matar).
5. **Combate** — combo aéreo (M1 para cima segue no ar), "perfect block" com brilho, contador de
   combo grande na tela, kill feed com o rosto do Stand.
6. **Mapa** — pontos famosos de Morioh marcados (casa do Josuke, Kame Yu), música por bairro.
7. **Progresso** — nível e títulos por Stand (já salva vitórias), skins de cor do Stand.
8. **Desempenho no celular** — qualidade automática (menos partículas em celular fraco).

## Regras que nunca mudam
- A chave da Open Cloud é pedida escondida no Termux e nunca aparece.
- Nunca resetar o Place nem o DataStore.
- Se o teste isolado falhar, nada é publicado.
- Sons, imagens e vozes são opcionais: nunca travam a instalação.
