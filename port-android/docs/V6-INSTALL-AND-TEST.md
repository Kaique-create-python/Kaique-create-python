# Instalação e validação — SpotiFast V6 experimental

## Atualização com preservação de dados

1. Na V5, exporte as playlists antes de qualquer troca de instalação. Na V6,
   Configurações → Backup local exporta playlists, curtidas, histórico e metadados.
2. Baixe o APK ARM64 e o arquivo SHA-256 no mesmo Release. Compare o hash antes de
   instalar. O relatório `signature-verification.txt` informa o certificado usado.
3. Tente atualizar abrindo o APK ou com `adb install -r arquivo.apk`. A migração de
   SQLite v1 para v2 é automática e foi coberta por teste instrumentado.
4. APKs debug de runners diferentes usam certificados diferentes. Se o Android
   recusar a atualização por assinatura, mantenha a V5 instalada até concluir o
   backup. Desinstalar apaga o banco e autorizações locais. Uma assinatura estável
   é necessária para garantir atualizações futuras no mesmo aplicativo.
5. Em instalação nova, importe o JSON pela seção de playlists (exportação V5) ou
   por Backup local (exportação V6). Reautorize áudio e capas locais quando preciso.

Jamendo precisa de Client ID legítimo nas configurações. Sem ele, Audius e arquivos
locais continuam disponíveis. O acesso geral ao dispositivo solicita somente áudio;
o seletor individual permite abrir arquivos sem conceder acesso a toda a biblioteca.

## Evidência automatizada

O workflow `spotifast-v6.yml` exige testes unitários, Android Lint, testes Android 15,
compilação original Rust ARM64, inspeção do Manifest/ELF e apksigner. A publicação
depende do sucesso dos jobs de testes e empacotamento. Arquivos XML, screenshot,
memória e inicialização ficam no artifact `SpotiFast-V6-test-reports`.

- Primeira entrega: Actions 40088572048, 6 testes instrumentados aprovados.
- Biblioteca V6: Actions 40207070391, 10 testes instrumentados aprovados.
- Novos testes cobrem backup/rollback, seleção de rádio e consulta real ao MediaStore
  com áudio PCM gerado pelo próprio teste. O resultado definitivo é o do workflow
  associado ao commit do Release, acompanhado de `validation-report.json`.

As verificações de API fazem pesquisa e leitura de uma amostra autorizada, sem
armazenar áudio remoto. Elas não equivalem à reprodução integral pelo decodificador.
Falha ou ausência de credencial aparece separadamente no relatório.

## Métricas e limites

`am start -W` após force-stop mede uma abertura de processo depois dos testes.
`dumpsys meminfo` captura PSS imediatamente após abrir. `gfxinfo` captura os quadros
da abertura, sem percurso automatizado de rolagem. São observações únicas em
emulador, sem comparação controlada com a V5 ou outro aplicativo.

O teste de checkpoint instala um gatilho SQL que falha se uma fila idêntica for
apagada: a V6 preserva a fila e atualiza posição/modos. Isso verifica a redução de
escritas; não demonstra um ganho percentual de bateria ou velocidade.

## Validação física pendente

POCO C65/Android 15: partida fria repetida, rolagem, memória sob pressão, consumo em
30 minutos com tela apagada, fones Bluetooth, chamadas, remoção de fones, mudança
Wi-Fi/dados e Doze. Também verificar a interface Rust ARM64, arquivos MP3/FLAC/AAC/OGG
reais, painel de equalização do fabricante e widget no launcher utilizado.

Não há acesso a dispositivo físico nesta sessão. Crossfade, normalização de volume,
letras licenciadas, Android Auto, temas customizados e migração Compose ainda estão
pendentes, conforme V6-STATUS.md.

Ensaio auxiliar no workspace (Python SQLite em memória): catálogo sintético com
20.000 faixas, 1.000 curtidas e 5.000 registros de histórico; 10 execuções da consulta
limitada de recomendações retornaram 50 itens, mediana de 29,38 ms e máximo de
32,57 ms. Este ensaio mede somente SQL no servidor, não tempo ou memória Android,
e os dados sintéticos nunca são incluídos no catálogo do aplicativo.
