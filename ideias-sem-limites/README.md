# Ideias Sem Limites — V3

## Novidades (V3.4)

* **Cenas de cinema:** quando algo grande aparece (demônio, titã, kaiju, Jesus, buraco negro,
  meteoro, nuke, terremoto), a câmera voa até lá com faixas pretas e o nome gigante na tela
  (toque para pular; dá para desligar em Ajustes).
* **Mapa que quebra:** meteoro e explosões grandes cavam crateras de verdade no terreno com lava
  no fundo; o terremoto abre rachaduras com lava e levanta placas de pedra. Tudo volta ao normal
  sozinho depois de ~45 s.
* **Desastres caprichados:** buraco negro com disco de acreção em 3 camadas, anel de luz
  (estilo filme), destroços espiralando e a tela escurecendo perto; meteoro com rocha irregular,
  rastro de fogo e luz; bomba nuclear com clarão, bola de fogo, cogumelo subindo e onda de
  choque; explosões soltam destroços de verdade.
* **Monstros grandes chegam com portal, raios e clarão.**
* **Modelos melhores:** todos os humanoides ganharam pescoço, ombros e mãos redondos e bico no
  sapato; demônio com chifres curvos e rachaduras de lava brilhando.
* **Interface:** borda arco-íris animada, botão CRIAR pulsando, sugestões rápidas para tocar,
  abertura com o logo (feito no Canva; `bash ideias.sh imagens` envia o logo).
* **Sons garantidos:** o jogo testa se o áudio do ElevenLabs carregou de verdade; se não, usa os
  sons do Roblox. Em Ajustes: status dos sons, botão "Testar som" e escolha ElevenLabs/Roblox.

## Novidades (V3.3)

* **Mais anime:** "luffy" (Pirata Elástico, soco que estica), "tanjiro" (Caçador de Demônios, corte de
  água), "gojo" (Feiticeiro Amaldiçoado, teleporte), "ataque dos titãs" (Titã Colossal), "deku",
  "ichigo", "sailor moon", "doraemon", "chainsaw man", "ash" (chama monstrinhos), "kurama".
* **Desenhos:** "ben 10" (chama alienígenas), "bob esponja", "patrick", "pica pau", "monica",
  "pernalonga", "frajola", "piu piu", "papa léguas".
* **Terror:** "enderman"/"slenderman" (Sombra Alta, teleporta), "granny".
* **Vida real:** boxeador, cantor, DJ, skatista, surfista, mágico, gamer, pedreiro, bailarina,
  jogador de basquete, vovó (dá comida e cura), bebê gigante.
* **Animais novos:** zebra, hipopótamo, coala, camelo, lhama, hiena, guepardo, tamanduá, tatu.
* **Combinações prontas:** circo, copa do mundo, batalha de anime, festa de aniversário,
  apocalipse dos memes, equipe de heróis ("vingadores", "liga da justiça").
* **Som novo:** trovão do ElevenLabs (13 efeitos no total).

## Novidades (V3.1)

* **Personagens pelo nome:** "goku", "naruto", "saitama", "homem aranha", "batman", "hulk",
  "mario", "sonic", "pikachu", "thor", "freeza", "medusa"... O jogo reconhece o nome e cria uma
  **versão original** com poderes parecidos (raio de energia, clones, soco supremo, teia, olhos de
  laser, raio do céu). Visual e nome oficiais não são usados porque o Roblox pode remover o jogo
  por direitos autorais.
* **Memes:** "tung tung tung sahur" (Tronco Tum-Tum), "tralalero tralala" (Tubarão Patinador),
  "bombardiro crocodilo", "ballerina cappuccina", "chimpanzini bananini", "lirili larila",
  "skibidi toilet", "creeper", "huggy wuggy", "freddy", "noob".
* **Jesus** aparece como personagem (túnica, luz suave): cura e acalma monstros. Ninguém consegue
  atacá-lo, explodi-lo ou misturá-lo com outras coisas. "deus" gera a Luz Celestial.
* **"gigante"** cria um gigante. Para você crescer, use "ficar gigante" ou "crescer".
* **Qualquer nome** ("verity", "ana beatriz") vira um personagem com esse nome. A aparência vem do
  nome, e o texto passa pelo filtro do Roblox antes de aparecer.
* **Cadeias de ação:** "arma que atira cachorro e o cachorro caga elefante que o elefante explode",
  "vaca que vira dragão", "dragão que cospe gelo", "zumbis que se multiplicam", "robô dança".
* **Híbridos:** "gato tubarão", "homem tubarão", "macaco pizza", "crocodilo avião".
* **Efeitos e sons:** carga de energia, raio, soco com onda de choque, teia, coluna de luz com
  pombas, pum, lançamento em arco, pavio piscando, tambor. 9 sons do ElevenLabs estão num único
  áudio (`assets/sons`). Para ativá-los: `bash ideias.sh sons` (permissão `asset` Read+Write; pede
  seu User ID uma vez). A frase pode ter até 120 caracteres.

Jogo Roblox em que **qualquer palavra digitada vira um acontecimento no mundo**.
Universe `10774214423` · Place `122033314086516`.

> Estado: código completo e testado **fora do Roblox** (Lune + Rojo) e com testes prontos
> para rodar **dentro do motor do Roblox** pela Luau Execution API. Ainda **não foi
> executado no Roblox real** — isso depende da sua chave, no Termux (passo 5 abaixo).

---

## 1. Comandos no Termux (na ordem)

```bash
pkg update -y
pkg install curl python coreutils -y
termux-setup-storage            # permita o acesso aos arquivos
cd ~/storage/downloads

curl -fLO https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/claude/ideias-sem-limites-roblox-t44sea/ideias-sem-limites/termux/ideias.sh

bash ideias.sh configurar        # IDs + chave (digitada sem aparecer na tela)
bash ideias.sh baixar            # baixa a V3 e confere o SHA-256
bash ideias.sh backup            # copia V1/V2 para uma pasta de backup (não apaga nada)
bash ideias.sh diagnosticar      # analisa Ideias_Sem_Limites_V2.rbxlx (causa do erro 400)
bash ideias.sh enviar            # envia a V3 como SALVA (Saved) — não publica
bash ideias.sh testar            # roda os testes no motor do Roblox (até 5 min)
bash ideias.sh auditar 4         # (opcional) lista o conteúdo da versão 4 (V1)
bash ideias.sh publicar ~/storage/downloads/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxl   # só quando você decidir
```

**Sem o GitHub (pelo `IdeiasSemLimites_V3.zip`):** com o .zip na pasta Download, troque o
`curl` e o `baixar` acima por:

```bash
pkg install unzip -y
cd ~/storage/downloads
unzip -o IdeiasSemLimites_V3.zip                 # cria a pasta ideias-sem-limites/
cp ideias-sem-limites/termux/ideias.sh .
bash ideias.sh configurar
IDEIAS_RAW="file://$HOME/storage/downloads/ideias-sem-limites" bash ideias.sh baixar   # copia do .zip e confere o SHA-256
```

Depois siga com `backup`, `diagnosticar`, `enviar`, `testar` normalmente.

Permissões da chave (Creator Dashboard → Credenciais → editar a chave, só para este universo):

| Uso | Permissão |
|---|---|
| `enviar` / `publicar` | `universe-places` → Write (a mesma usada na V1) |
| `testar` / `auditar` | `universe.place.luau-execution-session` → Read + Write |
| `enviar-assets` (opcional) | `asset` → Read + Write |

A chave fica em `~/.ideias/chave` (permissão 600), vai para o `curl` por um arquivo de
cabeçalho temporário apagado ao sair e nunca é impressa. Nada de cookie, senha ou chave no
código, no repositório ou nos arquivos baixados.

## 2. Backup e reversão

* `bash ideias.sh backup` copia V1, V2 e scripts antigos para
  `~/storage/downloads/IdeiasSemLimites/backup-AAAAMMDD-HHMMSS/` com SHA-256.
* **Última versão conhecida aceita na nuvem: 4 (V1).** Enviar a V3 como *Saved* cria uma versão
  nova sem mexer no que os jogadores veem.
* Para voltar: Creator Dashboard → a experiência → Lugares → Histórico de versões → escolha a
  versão → Restaurar (funciona no navegador do celular). Ou reenvie o arquivo do backup com
  `bash ideias.sh enviar ARQUIVO`.
* `bash ideias.sh status` mostra o histórico local: arquivo, SHA-256, versão e resultado.
* Publicar exige digitar `PUBLICAR` e avisa se o arquivo não foi salvo/testado antes.

## 3. Diagnóstico da V1 e da V2

Os arquivos V1/V2 estão só no seu celular: não estavam no repositório nem no Google Drive
conectado (lá existem outros projetos Roblox, de outros universos, que não foram tocados).
Por isso o diagnóstico é uma **ferramenta que roda no seu Termux** e aponta a causa no seu
arquivo — veja `docs/DIAGNOSTICO.md`. Resumo:

* **Descartado com evidência:** `xmlns:xmime` — o Rojo gera `<roblox version="4">` sem
  namespace nenhum e esses arquivos são aceitos pelo Open Cloud.
* **Pouco provável:** notação científica (`1e-05`) — a ferramenta gera uma variante sem ela
  para comprovar (`E_sem_notacao_cientifica.rbxlx`).
* **Causas prováveis em geradores Python escritos à mão** (a ferramenta detecta cada uma):
  enum gravado como texto (`<token name="Material">Neon</token>`), `bool` como `True`,
  `nan`/`inf` no estilo Python, `<Content>` sem `<url>`, `BinaryString`/`AttributesSerialize`
  com JSON em vez do formato binário, `referent` duplicado, classe inexistente, propriedade
  com tipo trocado, BOM, arquivo vazio/ZIP — e, do lado da requisição, enviar o arquivo
  errado/vazio (o `curl --data-binary @arquivo-que-não-existe` envia corpo vazio).
* A ferramenta gera uma **cópia corrigida** e uma **bissecção** (metades do arquivo, sem
  scripts, sem cada tipo suspeito) para isolar a parte exata recusada enviando só como *Saved*.

**Solução adotada na V3:** o arquivo de lugar é gerado pelo **Rojo** (serializador rbx-dom,
o padrão da comunidade) e o mapa é **construído por código ao iniciar o servidor** — o
arquivo enviado tem só scripts e poucas peças (≈300 KB), sem XML escrito à mão.

## 4. O que foi implementado

**Interpretador modular** (`src/shared`): normalização (acentos, maiúsculas, letras repetidas,
números colados), plurais PT/EN, diminutivos/aumentativos (`gatão`, `cachorrinho`), prefixos
(`superdragão`, `minirobô`), correção de digitação (Damerau-Levenshtein), frases de várias
palavras, quantidades (`100 zumbis`, `horda de`), `chuva de X`, regiões (`no vulcão`), relações
(`e`, `contra`, `protegendo`, `montando`, `no/na`, `de`), fallback surpresa determinístico.
Catálogo de dados com **323 conceitos**, 55 modificadores (tamanho, elemento, material, traço,
velocidade, facção, voo, cor), 2.743 entradas de vocabulário, regras de interação e
**28 combinações secretas**. Novos acontecimentos = uma entrada em `Catalog/*.luau`.

**Combinações reais:** modificadores alteram parâmetros e visual (dragão de gelo = azul,
sopro congelante); `contra` cria rivais que lutam; `protegendo` cria guarda vinculado à
construção; `montando`/`no carro` coloca o NPC pilotando; predador × presa gera caçada;
`tornado de tubarões` carrega tubarões no funil; reações entre acontecimentos no mundo
(fogo + gelo = vapor, água apaga fogo, eletricidade na água, lava + água = obsidiana).

**Modelos procedurais:** 33 trajes de personagens (inclui Saci, Curupira, Cuca), ~30
quadrúpedes, dinossauros, aves, peixes, polvo/kraken, serpentes, insetos, slime, dragão/hidra,
robôs, OVNI, 18 veículos, 28 construções (labirinto gerado), 75 objetos e comidas
(brigadeiro, coxinha, pão de queijo, açaí...). Rigs com Motor6D animados no cliente.

**NPCs:** IA com alvo por facção, perseguição, fuga, guarda, seguir o dono, voo
(AlignPosition), pathfinding sob demanda, detecção de travamento; ataques corpo a corpo,
sopro elemental, projéteis, pisão, investida, raio trator, cura, presentes.

**19 desastres** (meteoros, buraco negro, tornado, raios, tsunami, explosão/nuke, terremoto,
vulcão, incêndio, gelo, nevasca, chuva ácida, areia, lava, chuva de pedras, vento, gravidade,
lasers, fim do mundo), clima e magia temporários, poderes (voar, crescer, invisível, escudo,
clones, parar o tempo...) e 10 ferramentas com mira automática.

**Mapa:** ilha com oceano e 9 regiões — Centro de Criação, Floresta Encantada, Cidade Neon,
Região Glacial, Região Vulcânica, Deserto das Ruínas, Praia, Ilhas Flutuantes e Arena
Subterrânea —, estradas, viagem rápida, ~4,6 mil peças + terreno, destrutíveis que voltam
sozinhos, lava que queima. StreamingEnabled ligado.

**Interface mobile:** barra no topo (não cobre analógico nem pulo) com prévia ao vivo,
CRIAR com recarga, capacidade do mundo, avisos, destaques, painel lateral com sugestões por
categoria, histórico, favoritos, progresso, loja de cosméticos (Faíscas, sem Robux) e ajustes
(gráficos, câmera, tremor, sons, tamanho da interface).

**Segurança e desempenho:** servidor autoritativo; texto tratado como dado; validação de
tipo/tamanho/UTF-8; recarga de 3 s; bloqueio de spam; limite global; orçamento de
acontecimentos (12), NPCs (28), partes físicas, efeitos e partes estáticas; 3 ideias ativas
por jogador com reciclagem da mais antiga; cada acontecimento numa pasta própria com tempo de
vida; para os outros jogadores só vão rótulos do catálogo e o DisplayName (nenhum texto livre).

## 5. Testes

```bash
tools/build.sh      # gera dist/*.rbxl(x) e roda tudo (precisa de rojo e lune)
```

Resultado atual (offline, Lune 0.11.1 + Rojo 7.7.1):

| Suíte | Resultado |
|---|---|
| Sintaxe dos 92 scripts | 0 erros |
| Interpretador (casos, rótulo↔conceito de todos, todos os aliases, determinismo, entradas maliciosas) | 3143/3143 |
| Construtores: 318 modelos × 9 combinações de modificadores, validados na reflexão do Roblox | 2862/2862 |
| Mapa completo (orçamento por região, luzes, teleportes) | ok |
| Servidor: **cada conceito executado e limpo**, cadeias, híbridos, nomes, estresse com 5 jogadores, porteiro | 466/466 |
| `ideias.sh` contra Open Cloud simulado (inclui `sons`) | 21/21 |

Na nuvem, `bash ideias.sh testar` roda o interpretador e a suíte do servidor no motor real.

## 6. Pendências e limites honestos

* Nada foi executado no Roblox real ainda; física (veículos, voo, empurrões), animações e o
  visual dos desastres no cliente só serão confirmados jogando.
* Sons usam arquivos embutidos do cliente (`rbxasset://sounds/...`); se algum não tocar,
  troque por IDs da Loja em `Config.Sounds`.
* Persistência (DataStore) só funciona em lugar publicado com acesso a API habilitado; sem
  isso o progresso vale só na sessão (o jogo continua funcionando).
* `SavePlaceAsync` via Luau Execution foi estudado mas não é necessário: o mapa é gerado ao
  iniciar. A documentação exige uma opção de API nas configurações do lugar que não foi possível
  confirmar daqui.
* Instâncias que o Open Cloud não atualiza (MeshPart/Union) não são usadas.
* Ainda faltam: animações com assets próprios, música, balanceamento após teste real,
  mais variedade de trajes por região.

## 7. Estrutura

```
default.project.json   projeto Rojo (serviços, remotes, plataforma inicial)
src/shared             interpretador, catálogo, trajetórias, testes compartilhados
src/server             núcleo, construtores, IA, executores, mapa, progressão, testes
src/client             interface, efeitos, clima/animação, movimento e veículos
tests/lune             harness que roda os módulos fora do Roblox
tests/cloud            scripts enviados pela Luau Execution API
tests/termux           Open Cloud simulado + teste do ideias.sh
tools/                 build, diagnóstico de .rbxlx, base de reflexão, prévia 3D
termux/ideias.sh       instalador e publicador
dist/                  arquivos prontos (rbxl, rbxlx, SHA256SUMS)
```
