# SpotiFast Android V6 — experimental 2

Continuação direta da V5. Rust original e todas as fontes autorizadas preservados.

## Estabilidade
- Cliente de streaming sem limite total de 25 segundos, mantendo timeouts de rede.
- Recuperação limitada de conexão e monitoramento de retorno da rede no serviço.
- MediaSessionService, audio focus, notificação e restauração pausada preservados.

## Validação e limites
A publicação depende dos testes unitários, Android Lint, testes instrumentados
Android 15 e compilação do Rust original ARM64. A assinatura é verificada com
apksigner e o SHA-256 acompanha o APK. O relatório do Actions é a fonte dos resultados.

Bluetooth real, chamadas, troca Wi-Fi/dados, consumo de bateria e desempenho no
POCO C65 exigem dispositivo físico. Sem credencial legítima, Jamendo não é testado.
Não se afirma equivalência de desempenho ao Spotify. Crossfade, letras licenciadas,
Android Auto e visualizador ainda não estão implementados.

Se não houver keystore estável nos secrets, o APK terá assinatura debug temporária:
a atualização sobre V5 pode ser recusada. Exporte playlists antes de qualquer remoção;
desinstalar apaga os dados locais. Não remova a V5 sem backup.

## Biblioteca, busca e player — segunda entrega
- Migração SQLite v1→v2 preserva playlists/curtidas/histórico/sessão e mantém a primeira
  ocorrência de faixas duplicadas; índice único impede novas duplicatas.
- Checkpoints atualizam posição/modos sem regravar uma fila idêntica.
- Busca unificada inclui MediaStore com permissão somente de áudio e cancelamento;
  seletor de arquivos individuais continua disponível sem acesso à biblioteca completa.
- Histórico de busca limitado, sugestões salvas e opção de desativar/limpar histórico.
- Mix local baseado em artistas da mesma fonte e gêneros explícitos do catálogo salvo.
- Biblioteca: recentes, curtidas, mais ouvidas, descobertas, mix e músicas locais salvas.
- Prévia de faixas na home limitada a 12; paginação completa na busca virtualizada.
- Player adaptado à altura, controle central circular, estado de curtida, perfil do
  artista e opção de desligar cores/transições. Painel de equalização do Android
  quando oferecido pelo dispositivo; não é um equalizador embutido.

## Resultados confirmados da primeira entrega
Actions 40088572048: lint, unitários e 6 testes Android 15 passaram; Rust ARM64 e
apksigner passaram. Audius retornou pesquisa, capa e amostra de 4096 bytes de áudio.
Jamendo não executado por falta de Client ID legítimo. Isso não valida cada faixa,
decodificação remota no aparelho ou uso de Bluetooth físico.
