# Diagnóstico técnico: V1, V2 e o erro "Invalid Content stream"

## O que foi possível verificar

| Item | Situação |
|---|---|
| Arquivos V1/V2 | Não acessíveis nesta sessão (ficam em `~/storage/downloads` do celular). |
| Endpoint usado | `POST /universes/v1/{universe}/places/{place}/versions?versionType=Saved` — confirmado na documentação atual (BETA, `universe-places:write`, 30 req/min). Resposta 400 = "Invalid request / Invalid file content". |
| Content-Type | `application/xml` para `.rbxlx`, `application/octet-stream` para `.rbxl` (documentação atual). |
| Assets API | `PATCH /assets/v1/assets/{placeId}` multipart (`request` + `fileContent`), assíncrona: devolve `operations/{id}` e precisa de consulta até `done`. `published: true` publica; sem isso salva sem publicar. |
| `xmlns:xmime` | Irrelevante: arquivos do Rojo não têm namespace algum e são aceitos. |
| Notação científica | Não é aceita como causa sem prova; a bissecção gera a variante sem ela. |

## Como encontrar a causa exata no seu arquivo

```bash
bash ideias.sh diagnosticar ~/storage/downloads/Ideias_Sem_Limites_V2.rbxlx
```

A ferramenta (`tools/diagnosticar_rbxlx.py`, só biblioteca padrão do Python) usa a base de
reflexão do Roblox 0.741 (931 classes, 641 enums) e verifica:

* **Bytes:** vazio, ZIP, gzip, binário com extensão errada, BOM, UTF-16, UTF-8 inválido,
  caracteres de controle proibidos em XML.
* **Estrutura:** raiz `<roblox version="4">`, `referent` único, serviços duplicados ou
  aninhados, classes inexistentes ou não criáveis.
* **Propriedades:** tipo da tag × tipo real (ex.: enum gravado como `<string>`), token não
  numérico ou fora do enum, `bool` diferente de `true/false`, `nan/inf` no estilo Python,
  CFrame sem os 12 números, Color3 em 0–255, `Content` sem `<url>`, base64 inválido,
  `AttributesSerialize` malformado, `SharedString` sem entrada, NumberSequence/ColorSequence.
* **Comparação com a V1** (aceita): classes, tipos e combinações classe.propriedade<tipo> que
  só existem na V2 — os primeiros suspeitos.
* **Correção segura:** cópia nova (nunca sobrescreve) com bool, NaN, enums por nome→número,
  Content→`<url>` e referents duplicados corrigidos.
* **Bissecção:** variantes reduzidas para enviar como *Saved* e ver qual é aceita.

Testada contra arquivos válidos do Rojo (0 alertas) e contra um "V2" com 10 defeitos
plantados (todos detectados, 6 corrigidos automaticamente).

## Inconsistência "lightning" × "thunder" do WordResolver da V2

Não foi possível abrir o `WordResolver.lua` original. Na V3 o problema não existe por
construção: o fallback sorteia **conceitos do catálogo** (ids validados por
`Catalog.validate()`), e o teste "ida e volta" garante que cada rótulo e cada alias levam ao
próprio conceito. O raio é o conceito `lightning`, com aliases `raio`, `relâmpago`, `trovão`,
`thunder`, `lightning`, e também funciona como modificador elétrico (`tornado de raio`).

## Luau Execution (estudo)

* Endpoints: `POST /cloud/v2/universes/{u}/places/{p}/versions/{v}/luau-execution-session-tasks`,
  `GET .../tasks/{t}` e `.../logs`. Escopo `universe.place.luau-execution-session` (read/write).
  Até 5 min por tarefa, 10 tarefas simultâneas por lugar, script de até 4 MB, retorno em JSON.
* Mudanças no DataModel **não persistem**, exceto com `AssetService:SavePlaceAsync`, que só
  funciona em lugares criados por `CreatePlaceAsync` ou com a API habilitada nas configurações
  do lugar (a documentação não nomeia a opção).
* Uso adotado: **testes no motor real** (`tests/cloud/run_cloud_tests.luau`) e **auditoria**
  de versões antigas (`tests/cloud/auditar_lugar.luau`). O mapa não precisa ser salvo porque é
  gerado ao iniciar o servidor.
