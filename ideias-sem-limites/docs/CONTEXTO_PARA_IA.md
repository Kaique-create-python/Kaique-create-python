# Contexto completo para outra IA continuar o projeto

Leia este arquivo inteiro antes de mexer em qualquer coisa. Ele resume tudo o que foi feito
até a versão **V3.6** do jogo **Ideias Sem Limites** (Roblox).

Repositório: `Kaique-create-python/Kaique-create-python`, ramo
`claude/ideias-sem-limites-roblox-t44sea`, pasta `ideias-sem-limites/`.

---

## 1. Quem é o dono e como ajudar

* Fala **português do Brasil**. Responda sempre em português, de forma curta e direta.
* Usa **só o celular** (Android + **Termux**). Não tem PC nem Roblox Studio.
* Orçamento de IA: **R$ 0**. Nada de serviços pagos.
* Quando pedir "o comando", entregue comandos prontos para copiar e colar no Termux.
* O dono gosta de visual caprichado (estilo dos jogos populares do Roblox), efeitos exagerados,
  cenas de cinema e sons. Detesta coisa "com cara de IA" (ícones gerados por IA foram recusados).

## 2. Regras de segurança do dono (obrigatórias, texto original)

* "O proprietário possui uma chave Open Cloud, mas ela deve ser inserida somente no ambiente
  seguro do Termux. Nunca solicite senha da conta, cookie ".ROBLOSECURITY" ou chave completa
  dentro da conversa."
* "Nunca inclua uma chave verdadeira em código-fonte, ZIP público, repositório ou arquivo hospedado."
* "As credenciais devem ser lidas localmente, sem exibição em logs."
* "Não execute nenhuma atualização diretamente em "Published" sem minha confirmação explícita."
* "Não publique para todos antes de minha autorização."
* "Não altere outros jogos nem outros universos da minha conta."
* "Não permita que jogadores enviem código Luau arbitrário para execução."
* "Os escopos de execução devem ser configurados apenas quando necessários."
* "Antes de executar alterações, confirme se o método funciona para este lugar e suas permissões.
  Não invente chamadas nem suponha que um recurso documentado esteja automaticamente habilitado na conta."

Universo **10774214423**, lugar **122033314086516** (os únicos que podem ser alterados).

## 3. O jogo

O jogador digita qualquer ideia ("dragão de gelo gigante", "chuva de pizzas", "arma que atira
cachorro e o cachorro caga elefante que o elefante explode") e ela vira algo no mundo: criaturas,
personagens (versões originais de personagens famosos), veículos, construções, comidas, poderes,
desastres (meteoro, buraco negro, nuke, terremoto, tornado...), clima e mudanças no mundo.
Nada de código do jogador é executado: o texto só é interpretado por um vocabulário fixo.

Fluxo: `TextBox` (cliente) → RemoteEvent → **Parser** (texto → tokens/grupos) → **Planner**
(conceitos + modificadores + ações) → **EventManager** (orçamento, limites, segurança) →
**Handler** (`npc`, `prop`, `vehicle`, `building`, `disaster`, `world`, `power`, `tool`,
`composite`, `blessing`) → **Builders** (modelos procedurais feitos de peças) → **Fx** (efeitos
enviados aos clientes) → cliente desenha partículas, sons, cenas de cinema.

## 4. Estrutura de pastas (`ideias-sem-limites/`)

| Pasta | O que tem |
|---|---|
| `default.project.json` | projeto Rojo (gera o `.rbxl`/`.rbxlx`) |
| `src/shared/` | `Parser`, `Planner`, `Lexicon`, `Config` (limites, sons, imagens), `Catalog/` (todos os conceitos: `Creatures`, `Characters`, `Objects`, `Vehicles`, `Buildings`, `Phenomena`, `Powers`, `Modifiers`, `Interactions`, `Grammar`, `Secrets`, `Progression`) |
| `src/server/Core/` | `EventManager`, `Budget`, `Actors`, `Combat`, `Fx`, `Chains` (cadeias de ação), `TerrainScars` (crateras/rachaduras que se consertam), `Ambience` (luz/céu), `Destruction` |
| `src/server/Handlers/` | um executor por tipo; `Disasters/` (Cosmic = buraco negro, Impact = meteoro/explosão, Ground = vulcão/terremoto, Storms...) |
| `src/server/Builders/` | modelos procedurais (`Kit`, `Beasts`, `Figures`, `Memes`, `Fusion`, `Monsters`, `Props`...) |
| `src/server/Brains/` | IA dos NPCs | 
| `src/server/Map/` | mapa procedural (hub, praia, cidade, floresta, deserto, geleira, vulcão, céu, arena) |
| `src/client/` | `Main.client`, `UI/` (`Hud`, `Drawer`, `Theme`), `FX/` (`Effects`, `Disasters`), `Settings` |
| `tests/lune/` | testes offline (parser, builders, mapa, servidor completo) |
| `tests/termux/` | teste do script do Termux com servidor Open Cloud falso |
| `termux/ideias.sh` | tudo que o dono roda no celular |
| `tools/build.sh` | build + todos os testes; gera `dist/` |
| `tools/sons/montar_sprite.py` | junta os efeitos do ElevenLabs num único `.ogg` + `regioes.json` |
| `tools/ui/desenhar_icones.py` | desenho vetorial (à mão, sem IA) da folha de ícones → `assets/ui/IdeiasIcones.svg/png` |
| `assets/` | `sons/IdeiasSons.ogg` + `regioes.json`, `ui/IdeiasLogo.png` (Canva), `ui/IdeiasIcones.png` |
| `dist/` | arquivos prontos que o Termux baixa do GitHub |

### Como adicionar um conceito

Edite o arquivo do `Catalog` certo. Exemplo de criatura:

```lua
npc("dragon", "Dragão", "m", { "dragao", "dragon", "drake" }, {
	model = "dragon", variant = "dragon", faction = H, hp = 900, speed = 26, dmg = 18, fly = true,
	element = "fire", attacks = { "breath", "melee" }, size = 1.4,
}, { "beast", "monster", "flying", "evil" }, { maxCount = 3, lifetime = 80 })
```

Cuidado com **apelidos repetidos** entre conceitos (o teste acusa colisões). Personagens famosos
viram **versões originais** (nome e visual próprios, sem copiar marca). Jesus é personagem sagrado
protegido (invulnerável, sem modificadores/fusões/cadeias); "deus" vira a Luz Celestial.

## 5. Build e testes (num computador/servidor, não no celular)

```bash
# ferramentas: Rojo 7.7.1 e Lune 0.11.1 no PATH
bash tools/build.sh                     # build + parser + 318 modelos + mapa + servidor completo
bash tests/termux/testar_ideias_sh.sh   # testa o ideias.sh com Open Cloud falso
```

O build valida as propriedades das peças contra `tools/roblox_reflexao.json.gz`.
Antes de cada commit rode os dois. O mapa do hub tem limite de 1000 peças (`tests/lune/map_spec.luau`).

## 6. Fluxo no celular (Termux)

```bash
bash ideias.sh configurar      # guarda a chave Open Cloud em ~/.ideias/chave (permissão 600)
bash ideias.sh baixar          # baixa dist/ deste ramo do GitHub e confere SHA256
bash ideias.sh backup
bash ideias.sh enviar          # envia como SALVA (Saved) — não publica
bash ideias.sh testar          # roda os testes dentro do Roblox (Luau Execution)
bash ideias.sh sons            # envia o áudio (só se mudou) e salva a versão com o ID
bash ideias.sh verificar-sons  # pergunta ao Roblox se o áudio já foi aprovado
bash ideias.sh imagens         # envia logo + folha de ícones (Decal) e salva a versão
bash ideias.sh publicar ARQUIVO  # só com confirmação digitando PUBLICAR
```

Os IDs de áudio/imagem são gravados em marcadores dentro do `.rbxlx`:
`Id = 0, --@@SPRITE_ID@@`, `Logo = 0, --@@LOGO_ID@@`, `Icons = 0, --@@ICONS_ID@@`.
Correção de 11/11/2026: o auxiliar `tools/preparar_midias.py` sempre parte do XML do
build recém-baixado, validado pelo SHA256SUMS, e reaplica recibos cujos arquivos continuam
iguais. `enviar` sem argumento usa o arquivo `_final.rbxlx`. `sons` e `imagens` preservam
os outros IDs; imagens confirmadas também têm cache por hash. O áudio antigo usa o mesmo
`audio_id`/`audio_sha`, sem novo upload quando não mudou. Cópias preparadas substituídas
ficam em `V3/historico-midias`. O download inclui o auxiliar e valida seu checksum antes
de executá-lo. `baixar` tenta migrar os IDs legados das imagens somente com Config compatível
e PNGs anteriores ao arquivo final. Sem essa comprovação, é necessário rodar `imagens` uma vez.

Ordem recomendada: `baixar` → `sons` → `imagens` → `testar`. Esses comandos salvam como
**Saved**, e os testes são isolados. Entrar normalmente pelo aplicativo Roblox continua
abrindo a versão publicada; isso não é uma prévia da versão Saved. `publicar` continua
dependendo da confirmação do dono. Não afirmar que uma mudança apareceu ao vivo só por
salvar ou passar nos testes isolados. Veja `docs/CORRECAO_MIDIAS.md`.

## 7. Sons (ElevenLabs)

* 16 efeitos num único áudio (`assets/sons/IdeiasSons.ogg`), tocados por trecho
  (`Sound.PlaybackRegion`). Trechos em `Config.SoundSprite.Regions` — **precisam bater com
  `assets/sons/regioes.json`** sempre que o `.ogg` for refeito.
* Efeitos → trechos em `Config.SoundCues` (cada um tem `fallback` = som embutido do Roblox).
* O cliente (`Effects.checkSprite`) testa se o áudio carregou de verdade (`IsLoaded` e
  `TimeLength > 1`). Se não carregou (moderação, permissão ou conexão), toca os sons
  embutidos e mostra um aviso na tela. Em Ajustes há "Testar som" e a escolha ElevenLabs/Roblox.
* Confira a moderação com
  `bash ideias.sh verificar-sons`. Cada envio novo gasta a cota de uploads de áudio do Roblox;
  o script só reenvia se o arquivo mudou (`sons --novo` força).
  Approved confirma somente a moderação; não confirma o ID da versão publicada nem a
  reprodução no cliente. A mensagem do instalador distingue esses estados.
* Gerar sons novos: ElevenLabs "text to sound" (plano grátis; às vezes responde "busy" — não
  insistir na hora). Depois: `python3 tools/sons/montar_sprite.py PASTA_MP3 assets/sons/IdeiasSons.ogg assets/sons/regioes.json nome:duração ...`
  e atualizar `Config.SoundSprite.Regions`.

## 8. Interface (V3.6, no estilo que o dono pediu)

* Coluna à esquerda com **azulejos quadrados** (contorno escuro grosso, aro claro, desenho com
  contorno e brilho) e o **nome ao lado em branco com borda preta**: Ideias, Histórico,
  Favoritos, Progresso, Loja, Ajustes. Embaixo, contador dourado de **Faíscas**.
* Barra de ideias escura no topo, botão **CRIAR** estilo azulejo.
* Folha de ícones: `assets/ui/IdeiasIcones.png` (1024×768, grade 4×3, células de 256):
  ideias, favoritos, historico, progresso / loja, ajustes, creature, disaster / vehicle,
  building, food, power (`Config.IconSheet`). Sem a folha enviada (ID 0) a interface monta
  azulejos parecidos com emoji.
  Agora a alternativa também permanece enquanto a imagem está pendente ou falhou, mesmo
  com ID não zero. A arte só aparece quando `ImageLabel.IsLoaded` é verdadeiro. O logo
  original é RGB e contém fundo espacial opaco; não confundir esses pixels com falha de envio.
* Para mudar os ícones: edite `tools/ui/desenhar_icones.py` (formas vetoriais) e rode
  `python3 tools/ui/desenhar_icones.py assets/ui/IdeiasIcones.svg /tmp/camadas.json` e
  `node tools/ui/render_svg.js $PWD/assets/ui/IdeiasIcones.svg $PWD/assets/ui/IdeiasIcones.png`
  (precisa de Playwright/Chromium). O SVG também pode ser importado no Canva.
* Canva grátis: não exporta PNG com fundo transparente e não desenha contorno em formas
  compostas — por isso a folha final é renderizada a partir do SVG.

## 9. Estado atual (V3.6)

Feito e testado offline: 402 conceitos, 3490 palavras, cadeias de ação, fusões, personagens por
nome, cenas de cinema, crateras/rachaduras no terreno, buraco negro/meteoro gigante/nuke
catastróficos, sons do ElevenLabs com reserva, nova interface com azulejos.

Versões já enviadas pelo dono: V3.0 publicada (versão 5); V3.1 + sons publicada (versão 6).
O `dist/` foi preparado e testado offline. A informação antiga era que V3.6 ainda não havia
sido enviada. Em 11/11/2026 o dono confirmou aprovação do áudio; não confirmou nesta rodada
qual versão do Place está publicada. Não assumir instalação/publicação sem conferir o resultado.

## 10. Próximos passos sugeridos

1. Atualizar o script do Termux, depois `baixar` → `sons` → `imagens` → `testar`.
   Conferir o relatório da versão Saved e pedir confirmação antes de `publicar`.
   O aplicativo Roblox normal usa a versão publicada; não prometer uma prévia Saved nele.
2. Se o som ainda não sair: `verificar-sons`; em Ajustes, "Testar som"; volume do celular.
3. Botões no topo em pílula escura (como "Updates/Codes/Settings" dos jogos populares) para
   Loja/Ajustes, e mais ícones na folha (célula 12 em diante → aumentar a grade).
4. Mais conceitos pedidos pelo dono (animes, desenhos, memes, vida real, combinações).
5. Mais detalhes no mapa do hub (respeitar o limite de peças) e efeitos de clima.

## 11. Cuidados

* Nunca coloque chave, cookie ou senha em arquivo, commit, log ou conversa.
* Nunca envie nada como `Published` sem o dono digitar a confirmação.
* Não suponha que uma API do Roblox está liberada: o script testa e mostra o erro (401/403).
* Mudou o `.ogg`? Atualize as regiões no `Config`, senão os sons tocam o trecho errado.
* Rode `bash tools/build.sh` antes de cada commit e mantenha "RESULTADO: TUDO OK".
