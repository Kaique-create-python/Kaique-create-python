# Correção 12 — parte da ARMA pronta (`bastiao/dist/CORRIGIR_ETAPA3_12.py`); a vitrine ainda falta
Pedido do dono: arma muito mais detalhada (cápsulas caindo no chão, tiro melhor, tremedeira, recuo,
recarga animada mais bonita) e vitrine do jogo pelo instalador (ícone, banner, nome e descrição,
profissional e sem emoji). Base: pacote depois da correção 11 (`CORRECAO11_MENU3D_CAPITULO2_ARMA.patch`).

## Sons já prontos (`bastiao/assets/audio/etapa3/`)
- `eleven_capsula.mp3` (1 tinido, para cada quique) e `eleven_capsula_b.mp3` (3 tinidos, variação).
- `eleven_ak_vazio.mp3` (clique seco da arma vazia).
- Cortes do `eleven_ak_recarga.mp3`: `eleven_ak_pente_sai.mp3` (0,00–0,32 s), `eleven_ak_pente_entra.mp3`
  (1,58–1,88 s) e `eleven_ak_ferrolho.mp3` (1,88–2,30 s). Conferir de ouvido se cada corte é a parte certa.
- Faltam (o ElevenLabs respondeu "free generations busy"): pôr no `AUDIO_PLAN.json` com estes prompts para
  o `preparar-audio` gerar: `bala_concreto` ("Bullet impact on a concrete wall: sharp crack, small concrete
  chips and dust", 0,8 s), `bala_metal` ("Bullet hitting a steel plate: sharp metallic ping with a short
  ricochet", 0,8 s), `pente_chao` ("Empty steel rifle magazine dropped on a concrete floor: heavy metallic
  clatter and one bounce", 0,9 s).

## Arma: como fazer
- Módulo novo compartilhado `ArmaAnim` (funções puras, testáveis no Lune e usáveis numa prévia em vídeo):
  - mola amortecida (passos de 1/120 s);
  - padrão de recuo do AK-74: sobe 1,0° no 1º tiro e ~0,62° depois; lateral 0,22·sin(0,85n+0,6) e, após 5 tiros, +0,14·sin(2,1n);
  - tremor com `math.noise`: mais forte com o monstro a menos de 35 studs e em rajada; respiração lenta;
  - poses das recargas por quadros-chave;
  - física própria de cápsula, pente e estilhaço, por raycast: gravidade 80, quique 0,35, atrito; deitam no chão, rolam um pouco e somem em 30 s, no máximo 60.
- `ArmaModelo`: grupos animáveis, movidos com `workspace:BulkMoveTo` (raiz * grupo * repouso). Medidas em cm.
  - Pente: gira na trava dianteira (0, -4.5, -11.9).
  - Mão esquerda: pivô (-0.6, -4.6, -25).
  - Ferrolho e Manejo: deslizam 12,5 cm para +Z.
  - Seletor: pivô (1.62, -0.6, 2); semi = -9°.
  - Gatilho: pivô (0, -4.8, -0.6); puxa -12°.
- Recargas:
  - **Tática (2,1 s):** o pente vai para o colete, entra um novo e fica 30+1. Eventos: 0,42 solta, 1,30 trava.
  - **Vazia (2,6 s):** o pente cai no chão com física, entra um novo e a mão puxa o ferrolho com a arma girada para a direita. Eventos: 0,42 solta, 0,70 cai, 1,48 trava, 1,98 ferrolho atrás, 2,09 ferrolho solta.
  - **Servidor:** `RECARGA_TATICA` 2.1, `RECARGA_VAZIA` 2.6, +1 na câmara; o efeito manda `vazia`, `duracao` e `material`.
- Tiro:
  - **Controle e mira:**
    - modo AUTO/SEMI (V, DPadUp ou botão MODO);
    - clique seco e depois recarga automática;
    - dispersão que abre com rajada, andar e correr, com mira dinâmica.
  - **Recuo e tremedeira:**
    - a câmera sobe com o recuo e volta: o alvo cai 1,2/s atirando e 5,5/s parado, com limite de 9°;
    - tremor de tela por trauma;
    - coice da arma em molas;
    - o ferrolho cicla a cada tiro e o dedo puxa o gatilho.
  - **Boca da arma:** clarões laterais do freio de boca, faíscas na boca e fumaça no cano depois de uma rajada (calor).
  - **Impacto:**
    - muda pelo material (concreto, metal, madeira, terra), com estilhaços com física;
    - a marca na parede tem duas camadas (queimado e furo).
  - **Cápsula:**
    - sai com uma fumacinha;
    - velocidade de ejeção: direita 5,5–7,5, cima 3–4,5 e trás 0,5–1,5 studs/s, mais a velocidade do jogador;
    - giro de 25–40 rad/s em torno do "cima" da arma;
    - tamanho 1,6x o real (0,19 x 0,05).
  - **Outros jogadores:** os tiros deles também soltam cápsulas, o pente deles cai e a arma deles dá um coice leve (Weld C0 local).

## Vitrine: APIs conferidas na documentação oficial (aceitam chave Open Cloud)
1. **Nome e descrição** vêm do place raiz.
   - `PATCH https://apis.roblox.com/cloud/v2/universes/10776462844/places/89520940302906?updateMask=displayName,description` com JSON `{displayName, description}`.
   - Escopo `universe.place:write`. Dá 409 se o place estiver aberto no Team Create.
2. **Enviar a imagem.**
   - `POST https://apis.roblox.com/assets/v1/assets`, multipart com dois campos:
     - `request`: `{assetType:"Image", displayName, description, creationContext:{creator:{userId:"10735737143"}, assetPrivacy:"OpenUse"}}`;
     - `fileContent`: o arquivo.
   - Depois, esperar a operação até sair o `assetId`. Escopos `asset:read` e `asset:write`.
3. **Ícone** (quadrado, 512x512):
   - `PATCH https://apis.roblox.com/assets/v1/assets/89520940302906?updateMask=icon`;
   - multipart só com `request` `{assetId:89520940302906, icon:"assets/<id>"}`.
4. **Banner** (16:9, 1920x1080):
   - ler a lista atual com `GET .../assets/v1/assets/89520940302906?readMask=previews`;
   - gravar com `PATCH ...?updateMask=previews`, com `previews:[{asset:"assets/<id>", altText}]`;
   - a lista substitui tudo: pôr o nosso na frente e manter os antigos.
5. **Opcional:** thumbnails da página inicial (`thumbnail-personalization-api`, escopos `universe.thumbnail:read/write`).

Comando novo: `python ~/storage/downloads/BASTIAO_ETAPA3.py vitrine`.
- Pede `ATUALIZAR VITRINE` e a chave oculta.
- Guarda recibo, para não enviar duas vezes.
- Se faltar permissão, só avisa qual escopo pôr na chave; nada mais trava.

As imagens devem usar o modelo real do monstro e o AK-74 (three.js), com visual de bodycam, sem nada enganoso.

Nome: **Projeto Bastião**.

Descrição (rascunho, sem emoji, menos de 1000 caracteres):

> Projeto Bastião é um terror cooperativo em primeira pessoa, visto pela câmera corporal de uma equipe
> enviada ao Setor 7, uma instalação soviética esquecida no subsolo.
> Algo continua vivo lá embaixo. A criatura 731-A escuta cada passo e não pode ser morta, apenas detida.
> - História em capítulos, guiada pelo Pavel
> - Jogue sozinho ou com amigos
> - Lanterna, estamina e som posicional
> - Fuzil AK-74 com munição contada
> - Português, English, Русский
> Capítulo 2 (parte 1) disponível. Novos capítulos em breve.
> EN: Project Bastion is a co-op first-person horror game seen through a bodycam inside Sector 7, a
> forgotten Soviet facility. Creature 731-A cannot be killed, only stopped for a few seconds.
