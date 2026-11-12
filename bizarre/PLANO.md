# BIZARRE BATTLEGROUNDS — plano para deixar tudo cabuloso

Referência: Jujutsu Shenanigans (combate rápido, câmera de ombro, ragdoll, ULT com cena).
Cada AJUSTE é um instalador (`BIZARRE_AJUSTE<N>.py`) que só publica se o teste na nuvem passar
e o dono confirmar. O fluxo AJ14 usa primeiro uma versão **Saved**, preservando a publicada.

## AJUSTE-14 — piloto atual

Plano aprovado: [docs/PLANO_AJUSTE14.md](docs/PLANO_AJUSTE14.md).
Instalação e limites: [docs/README_AJUSTE14.md](docs/README_AJUSTE14.md).
Validação: [docs/VALIDACAO_AJUSTE14.md](docs/VALIDACAO_AJUSTE14.md).

- Star Platinum e The World recebem receitas feitas com 23 templates reais dos pacotes enviados,
  previsão/ACK sem repetir impacto e escopos de efeitos por ação/sessão.
- Combate: buffer de 120 ms, sequência idempotente, cancelamento após acerto válido e uma única
  extensão aérea do uppercut; hitbox/cooldown/dano continuam validados no servidor.
- ORA/MUDA completos 4,6 s e golpe final em 4,35 s. Cena ULT curta, câmera preservada e retorno
  correto após interrupção. Sons/IDs anteriores permanecem.
- Iluminação alta, materiais selecionados, sem reconstruir a cidade ou mudar colisões.
- Prévia local dos VFX em ADM; instalador altera o Place atual, com backup e POST único.

Próximo passo real: Kaique executar `testar-nuvem`, conferir a prévia/combate SP/TW e só então
autorizar a publicação. Depois do teste no celular, estender a curadoria aos outros quatro Stands.
As listas abaixo são **histórico e ideias futuras**, não uma autorização para mudar o escopo.

## Feito até o AJUSTE-7
AJUSTE-7: câmera de mira a 11 studs com proteção de parede, botões que não travam, menu que só
fecha com o servidor confirmando, ajustes (câmera, tremor, volume, qualidade), carregamento com
etapas reais, ORA x MUDA, seta TO BE CONTINUED, Morioh mais leve, salvamento sem duplicar e
instalador que confere a versão no ar. Detalhes em RELATORIO_AJUSTE7.md.

## Feito no AJUSTE-12 (combate: mira, dash, impacto)
- **Mira**: a trava agora tem câmera própria (Scriptable): atrás do ombro direito, olhando um ponto
  entre você e o alvo, suave (não briga com o dedo), sobe quando o alvo é lançado, para antes da parede,
  volta para a câmera normal sem pulo. Trava sozinha só em quem VOCÊ acerta (apanhar não gira a câmera).
- **Impacto**: congelamento no acerto maior (0,075/0,14/0,17 s), tremor maior, camada grave em todo soco,
  sons de soco/whoosh/dash mais altos, quadro de impacto nos golpes fortes, VFX maiores e com mais
  camadas (anéis inteiros, arcos, estilhaços, estrelas, linhas).
- **Dash**: anel no chão, linhas de velocidade, 3 fantasmas, fumaça do pacote, FOV puxando.
- **VFX da loja em todo lugar**: punho de todo soco, impacto (impacto → outros), dash, guarda, parry,
  rajada, ULT, tempo parado. DIAG mostra o nome de cada efeito por tipo e o pico do andar (5 s).
- **Vozes**: ORA/MUDA/ZA WARUDO/Star Platinum The World 2,6x mais altos e ouvidos de mais longe
  (mesmo áudio: nada para reenviar).
- **Prévia 3D dos VFX** (`tools/previa_vfx.luau`): cada efeito congelado no meio, com os bonecos.

## Feito no AJUSTE-11
- **Animação do dono no personagem de verdade**: causa provável — quando a experiência está em R15, o
  corpo é refeito em R6 (AJUSTE-9) e o Roblox põe o "Animate" PADRÃO nele; o jogo via as animações do
  Roblox tocando e saía da frente. Agora o servidor tira esse Animate, o celular tira e para qualquer
  trilha do Roblox, e os nossos scripts do personagem vão marcados (BB_Nosso).
- **Botão DIAG (ADM)**: mostra na tela o estado da animação (R6, juntas, trilhas do Roblox, Animate,
  quanto do andar do dono está entrando, erro) e o resumo dos VFX da loja.
- **VFX da loja (os pacotes que o dono pegou)**: o servidor carrega pelo caminho oficial
  (AssetService:LoadAssetAsync / InsertService:LoadAsset), tira todo script/som/boneco, separa por tipo
  (impacto, choque, explosão, corte, faísca, fumaça, fogo, laser, chão, aura, flash) e o celular usa nos
  golpes por cima dos VFX próprios. O instalador (passo 4c) baixa cada pacote com a chave (Open Cloud
  Asset Delivery, permissão legacy-asset:manage) e mostra o que tem dentro; o teste na nuvem mostra o
  que carregou no jogo.

## Feito no AJUSTE-10 (pedido + plano do ChatGPT)
- **Andar e correr do dono** (Rig animation walk/run do Drive): importados por
  `tools/importar_animacoes.luau` para `AnimacoesDono.luau` e tocados direto nas juntas do R6, misturando
  andar → correr pela velocidade. Parado continua a pose JoJo. Prévia em vídeo gerada.
- **Stand**: fica do lado esquerdo, atrás e flutuando (segue o dono com um atraso suave); aparece saindo
  do dono com clarão e anel; **na guarda vai para a frente e cruza os braços em X**, tranca quando apanha,
  dá contra-golpe no parry e é jogado para trás quando a guarda quebra.
- **Socos do Stand**: investida a cada soco, rastro no braço que bate e estouro de ar na frente do punho.
- **VFX novos** (`Cliente/VFX.luau`): clarão, anel de choque, arco branco em meia-lua, brilho em estrela,
  estilhaços branco/preto/cor do Stand, linhas de velocidade, fumaça — em 3 níveis (leve, forte, enorme);
  ondas de pressão nas rajadas; clash mais forte; tempo parado com anéis nas cores de cada Stand e anel
  que fecha quando o tempo volta. Teto de peças vivas para o celular.
- **Mapa Morioh intacto** (regra do plano): a simplificação do AJUSTE7 ficou desligada
  (`Config.SIMPLIFICAR_MAPA = false`; dá para ligar de novo se o celular ficar lento).
- Pacotes de VFX da Creator Store: o Roblox exige login para baixar o conteúdo (resposta 401
  "Authentication required"), então não deu para inspecionar nem copiar; os efeitos foram feitos em código.

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

## AJUSTE-13 (feito)
- **VFX só dos pacotes da loja** (o dono não quer efeito desenhado por código/IA): `Cliente/VFX.luau`
  monta cada golpe em camadas com os efeitos que o servidor (`VFXLoja`) carrega dos 6 pacotes.
  `BB/VFXMedida.luau` mede cada efeito (raio, vida, cor), põe na escala do golpe e pinta com a cor
  do Stand (o branco do miolo fica branco). Escolha FIXA por Stand+golpe (mesma cara sempre).
  Aparição de cada Stand com camadas próprias (`VFX.APARICAO`); aura de cor errada (ex.: verde no
  Star Platinum) não é escolhida. Sem pacote: reserva com as texturas do próprio Roblox.
- Saíram: bolas/anéis/estilhaços/linhas Neon, textos na tela (ORA ORA!, PARRY!, GUARDA QUEBRADA!...),
  o grito de reserva e a música de fundo (`Config.MUSICA = false`).
- **Mira**: não gruda sozinha (só no botão MIRA; nos ajustes dá para ligar). **SHIFT LOCK** no celular:
  câmera reta por cima do ombro (`Humanoid.CameraOffset`) e o corpo olhando para a câmera.
- **Socos do dono** (2 mp3): `tools/sons_sfx.py` corta o começo, sobe o grave (harmônicos que o
  alto-falante do celular toca) e satura um pouco → `assets/sfx.ogg` (SOCO_A, SOCO_B, SOCO_MEGA,
  WHOOSH_SOCO). Instalador envia como áudio opcional (marcador `BBSFX`, `BB_SFX` no place).
- Instalador salva `BIZARRE_VFX_PACOTES.zip` (pacotes baixados + `no_jogo.json` com a descrição de cada
  efeito vinda do teste na nuvem) para o dono mandar no chat.

## Pendências do AJUSTE-13
1. **Sons de espada** (Silver Chariot) pelo ElevenLabs: o ElevenLabs estava ocupado; gerar corte,
   estocada, choque de metal e golpe pesado e acrescentar NO FIM do `sfx.ogg` (`tools/sons_sfx.py`,
   ordem fixa) e usar em `VFX.corte`/Efeitos para `corte_prata`.
2. Com o `BIZARRE_VFX_PACOTES.zip` do dono: ver cada efeito (Lune `roblox.deserializeModel` lê os
   .rbxm; as texturas saem pela API pública de thumbnails) e escolher à mão o melhor efeito de cada
   golpe (hoje é automático pela medida + nome).
3. Sons de impacto e explosão que o dono vai mandar (entram no fim do `sfx.ogg`).

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
8. **Desempenho no celular** — adiado pelo dono. AJ14 prioriza qualidade, sem redução automática.

## Regras que nunca mudam
- A chave da Open Cloud é pedida escondida no Termux e nunca aparece.
- Nunca resetar o Place nem o DataStore.
- Se o teste isolado falhar, nada é publicado.
- Sons, imagens e vozes são opcionais: nunca travam a instalação.
