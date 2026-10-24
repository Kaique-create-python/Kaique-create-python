# Auditoria V6 — 24/10/2026

Base: `spotifast-real-android-port`, commit `c57db0ffc96ead00690a4541dbca6924cf1347ed`.
Branch de trabalho: `spotifast-android-v6`. Outros projetos não são alterados.

## Arquitetura existente

Shell Java nativo, RecyclerView e Glide/Palette; Media3 1.5.1 com MediaSessionService;
OkHttp compartilhado; SQLiteOpenHelper v1 em executor serial, WAL e chaves estrangeiras.
Rust original é compilado separadamente para ARM64 e incluído como libspotifast.so.
YouTube permanece no IFrame visível. Não existe autorização para baixar áudio remoto.

## Evidências e prioridades

- Streaming herda callTimeout de 25 segundos do cliente de metadados: separar cliente
  de mídia sem prazo total, mantendo timeout de conexão/leitura e pool compartilhado.
- Serviço já implementa audio focus, becoming-noisy, notificação e restauração pausada.
  Falta recuperação limitada após falha transitória e retorno da rede.
- Cada evento/checkpoint regrava a fila inteira: separar posição de alteração da fila.
- entries permite duplicatas; criar migração não destrutiva e índice único.
- Pesquisa possui debounce/cancelamento, mas busca local apenas por seletor SAF;
  adicionar MediaStore com permissão somente de áudio, histórico e sugestões.
- Histórico não tem controle de privacidade. Recomendações devem usar metadados reais.
- Player expandido é rolável, mas usa controles de texto largos e insets incompletos.
- Home coloca RecyclerView wrap_content dentro de ScrollView, o que cresce com páginas;
  limitar prévia da home e manter paginação na busca virtualizada.
- Últimos commits corrigem medição de títulos e testes Android 15. Workflow V5 de
  testes `39700285516` e build `39700451401` terminaram com sucesso no GitHub.
- Workflow existente tem caminhos relativos frágeis após cd no script do emulador.

## Estratégia

Preservar Java/Views nesta entrega: trocar toda a UI por Compose sem validação de
paridade acrescentaria risco desnecessário ao player. Separar novos componentes e
manter migração futura incremental. Manter SQLite versionado (sem recriar banco).
Testes de regressão determinísticos, lint, emulador Android 15 e build Rust ARM64
precedem a publicação experimental. Testes físicos são documentados separadamente.

## Ambiente

O terminal não alcançou o proxy de rede e não contém Gradle, SDK Android, emulador
ou Rust no PATH. Fontes Android foram obtidas pelo conector GitHub no commit fixo.
Commits remotos devem usar a árvore original como base, preservando todo o Rust.
Não confundir a cópia parcial local de trabalho com uma substituição do repositório.
