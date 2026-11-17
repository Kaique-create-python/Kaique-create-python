# Instalador da correção 10

O arquivo independente `CORRIGIR_ETAPA3_10_CODEX.py` aplica a lista explícita `ARQUIVOS` ao pacote já instalado. Funciona offline com a biblioteca padrão do Python; não pede chave, gera áudio, envia dados ou publica o jogo. Importar `tooling/patch_install.py` não executa a instalação.

## No celular

Primeiro confira o pacote, sem escrever nada:

```sh
python ~/storage/downloads/CORRIGIR_ETAPA3_10_CODEX.py --verify
```

Depois aplique:

```sh
python ~/storage/downloads/CORRIGIR_ETAPA3_10_CODEX.py
```

Sem uma pasta explícita, a busca usa somente `~/.bastiao_etapa3/pacote_*` com `instalar.py`. A pasta de trabalho atual não vira destino automaticamente. Para selecionar uma pasta:

```sh
python ~/storage/downloads/CORRIGIR_ETAPA3_10_CODEX.py --verify /caminho/do/pacote
python ~/storage/downloads/CORRIGIR_ETAPA3_10_CODEX.py /caminho/do/pacote
```

`--verificar` é equivalente a `--verify`. Essa opção verifica o manifesto, todos os payloads e os arquivos existentes; não cria arquivos, diretórios, backups ou relatórios.

## Preservação dos arquivos existentes

Antes da primeira escrita, o instalador verifica todos os caminhos, os conteúdos compactados e seus SHA-256. Isso também vale para arquivos já atualizados e testes opcionais que serão pulados.

Um arquivo existente só é substituído quando seu hash consta em `antes`, ou é reconhecido como já atualizado pelo hash `novo`. A lista cumulativa inclui os hashes antigos aprovados e os da correção 9. O modo `criar` cria um arquivo ausente; não permite sobrescrever uma versão existente desconhecida. Uma alteração de outra origem interrompe a aplicação naquela pasta com o caminho e seu hash, antes de qualquer escrita. É preciso revisar essa alteração e produzir uma mesclagem aprovada; apagar o arquivo ou acrescentar seu hash sem revisar anularia a proteção.

Testes opcionais existentes com alterações desconhecidas são preservados e registrados como pulados. O modo `teste` também permite pular testes ausentes. `criar_teste` permite criar um teste ausente. Arquivos fora de `ARQUIVOS` não são varridos nem substituídos; chaves, saves, estado, mapa e interface ficam fora da lista, exceto os caminhos de código expressamente aprovados na correção cumulativa.

Caminhos absolutos, `..`, componentes vazios, barras invertidas e o diretório interno `.correcao10` são recusados no manifesto. Atalhos/symlinks são recusados no arquivo, em seus diretórios e nos ancestrais da pasta do pacote. Os modos de permissão de arquivos substituídos são preservados.

## Plano de áudio

O modo `plano` mescla somente os efeitos cujas chaves aparecem em `clipes` no manifesto. `clip_keys` é um alias. Sem essa lista, a biblioteca limita a mesclagem aos dez efeitos da correção 9; o manifesto cumulativo deve incluir expressamente `impacto_zumbido` para atualizá-lo.

As configurações do plano existente, os clipes de voz e os demais clipes são preservados. Campos adicionais de um efeito existente também são mantidos; os campos fornecidos pelo efeito aprovado são atualizados. Planos com JSON inválido, schema diferente de 1 ou chaves duplicadas são recusados. A mesclagem repetida mantém os mesmos bytes se já estiver correta.

## Backup, relatório e falhas

Uma aplicação que modifica arquivos cria uma pasta exclusiva:

```text
<pacote>/.correcao10/aplicacao_<identificador>/
  originais/<caminho original>
  relatorio.json
```

Todos os backups terminam antes da primeira substituição. Cada escrita usa um temporário exclusivo no mesmo diretório, sincronização do conteúdo e substituição atômica do arquivo. O relatório é gravado somente após as substituições e informa, por arquivo:

- ação (`write`, `unchanged` ou `skip`), caminho e permissões;
- SHA-256 anterior, do payload e do conteúdo final;
- caminho do backup quando houve substituição.

O relatório também contém a pasta do pacote, horário UTC, versão do formato, arquivos alterados, preservados e pulados. O comando imprime seu caminho. O backup guarda apenas os arquivos substituídos, sem coletar chaves ou estado que estejam fora da lista. Backups de aplicações anteriores nunca são reutilizados ou apagados.

Se uma escrita, verificação posterior ou gravação do relatório falhar, ou houver Ctrl+C durante a aplicação, o instalador tenta restaurar os originais e remover os arquivos e diretórios que acabou de criar. Se o rollback terminar, a tentativa não deixa novos backups. Se a restauração também falhar, o erro diz `rollback incompleto` e informa o diretório cujos originais foram preservados. Uma interrupção forçada do processo ou perda de energia não permite executar esse tratamento; as cópias já concluídas ficam em `originais` para recuperação manual.

Aplicar novamente um pacote já corrigido não cria outro backup nem relatório.

## API para montagem e auditoria

```python
from tooling.patch_install import PatchError, PatchReport, apply, main

report: PatchReport = apply(pasta, rows, verify=True)
report = apply(pasta, rows)
# Wrapper independente: raise SystemExit(main(ARQUIVOS))
```

`rows` é um dicionário `{caminho: {modo, antes, novo, dados}}`. `dados` contém zlib codificado em Base85; `antes` é uma lista de hashes SHA-256 completos. `apply` retorna um `PatchReport` (dicionário tipado) ou lança `PatchError`. `report_path` é `None` para verificação ou aplicação sem alterações. Os caminhos de `backups` são locais e absolutos. `main(rows, argv=None)` retorna 0 se ao menos uma pasta for verificada/aplicada ou já estiver corrigida, e 1 se nenhuma puder ser atendida. Cada pasta é tratada separadamente e as recusas são impressas.

O payload do arquivo de correção anterior deve ser extraído com AST/`ast.literal_eval`, sem executar seu código principal. O manifesto cumulativo é responsável por limitar os caminhos aos arquivos aprovados; esta biblioteca não escolhe quais funcionalidades serão instaladas.

## Testes locais

```sh
python -m unittest discover -s tests -p 'test_patch_install.py' -v
```

Os testes usam exclusivamente pastas temporárias. Cobrem hashes antigos e da C9, arquivo estrangeiro no modo `criar`, corrupção de payload mesmo já aplicado, mesclagem preservando vozes/configuração, repetição, permissões, travessia de caminho, symlinks, verificação sem escrita, colisão de backup, falhas tardias e restauração completa ou incompleta. Não usam a pasta real do celular, rede ou APIs de mídia/publicação.
