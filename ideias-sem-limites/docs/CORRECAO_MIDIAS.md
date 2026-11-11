# Correções de áudio e imagens — 11/11/2026

O áudio já aprovado no celular é reaproveitado pelo recibo local, desde que o OGG
continue igual. A chave real permanece exclusivamente na configuração local do Termux;
não está no pacote, nos fontes ou nos testes. Os testes usam uma credencial fictícia. Não é necessário repetir `configurar`.

## Atualizar no celular

Na mesma pasta em que você já usa `ideias.sh`:

```bash
cp -n ideias.sh ideias_backup.sh
curl -fL 'https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/claude/ideias-sem-limites-roblox-t44sea/ideias-sem-limites/termux/ideias.sh' -o ideias_novo.sh && mv ideias_novo.sh ideias.sh
bash ideias.sh baixar
bash ideias.sh sons
bash ideias.sh imagens
bash ideias.sh testar
```

Os envios são **Saved**; esses comandos não publicam para os jogadores. O aplicativo
Roblox abre a versão publicada, não uma prévia da Saved. A publicação continua
manual, somente depois do teste aprovado e da confirmação explícita do dono.

`baixar` preserva o download anterior quando há erro ou checksum inválido. Inclui
o auxiliar Python e verifica seu checksum antes de executá-lo. Depois cria o arquivo
final com fontes atuais e os IDs cujos recibos ainda correspondem aos arquivos.

`sons` mantém os IDs das imagens. O áudio igual ao recibo é reaproveitado; não usar
`--novo` para resolver um problema de carregamento de um áudio já aprovado.

`imagens` guarda recibos individuais por SHA256. IDs antigos são migrados antes do
download quando a Config e a ordem dos arquivos locais permitem identificar os mesmos
PNGs. Se os arquivos anteriores já foram trocados sem recibos, não é possível atribuir
um ID com segurança; nessa situação, a primeira execução precisa enviar as imagens.
As execuções seguintes reaproveitam os uploads confirmados. Falha de uma imagem bloqueia
o novo Saved e preserva os recibos das imagens que já terminaram.

`enviar` sem nome de arquivo sempre usa `IdeiasSemLimites_V3_final.rbxlx`, reconstruído
do build atual. Nunca escolhe uma cópia `_sons` antiga. Arquivos preparados substituídos
ficam em `IdeiasSemLimites/V3/historico-midias`, sem apagar os recibos/configuração.

## Aparência e som

Os ícones mantêm a alternativa original enquanto a imagem está pendente/indisponível;
trocam para a arte quando ela carrega e voltam à alternativa se necessário. O título da
abertura permanece até o logo carregar. O atlas mantém os 12 recortes de 256×256 e a arte
original. O logo tem fundo opaco nos próprios pixels; não houve remoção de fundo.

`verificar-sons` consulta **moderação**, sem dizer que isso prova reprodução. Se um áudio
aprovado não toca, conferir o arquivo/versionamento enviado, permissões da experiência,
carregamento no cliente, ajustes de som e volume do aparelho. O cliente conserva os sons
de reserva. Não há alteração do OGG nem dos seus 16 intervalos nesta correção.

O comando `testar` agora retorna erro quando a tarefa termina mas seu relatório contém
`ok=false` ou não confirma sucesso. Tarefa COMPLETE não é sinônimo de teste aprovado.

## Validação

As regressões foram observadas antes das correções: perda dos IDs, uso de fonte antiga,
envio padrão incorreto, reenvio de PNGs iguais, alternativa vazia e teste falso positivo.
Foram acrescentados testes de composição, recibos, migração conservadora, preservação
de arquivos, IDs sem perda de precisão, download incompleto e interface com carregamento
tardio/falha/destruição.

```bash
bash tools/build.sh
bash tests/termux/testar_ideias_sh.sh
```

O build usa Rojo 7.7.1 e Lune 0.11.1 e inclui os 14 casos de interface. O teste do Termux executa
o handler OpenCloud simulado sobre bytes HTTP em memória, sem abrir portas ou acessar
o Roblox. A fronteira curl HTTP é adaptada somente no teste; downloads `file://` usam curl.
Isso verifica os comandos, metadados e corpos enviados, e não mede conectividade libcurl,
moderação real, renderização Roblox, áudio nativo ou desempenho do celular. Essas conferências
continuam necessárias na experiência real após a publicação autorizada.

Só o destino 10774214423 / 122033314086516 é aceito. Jogadores continuam enviando texto para
o vocabulário fixo; nenhuma execução de Luau arbitrário foi introduzida.
