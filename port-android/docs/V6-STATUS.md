# SpotiFast Android V6 — experimental 3

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
Não se afirma equivalência de desempenho ao Spotify. Crossfade, normalização de volume, letras licenciadas,
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

## Recursos adicionais — terceira entrega
- Rádio opcional acrescenta até 5 faixas públicas da fonte/gênero, exclui restrições
  e itens da fila; o catálogo pode esgotar. Não existe promessa de rádio infinita.
- Fila do rádio é podada após 200 itens, preservando as 50 faixas anteriores.
- Qualidade econômica (MP3 96 kb/s) ou padrão (MP3 192 kb/s) para Jamendo.
- Backup JSON de biblioteca com importação transacional e testes de rollback.
  Limites da importação: 16 MB, 20 mil faixas e 2 mil playlists. Importar acrescenta
  playlists; não apaga as existentes. Autorizações de arquivos não são portáveis.
- Widget com título/artista e anterior/play-pause/próxima; atualiza por eventos do
  Media3 e não usa polling. Validação de posicionamento depende do launcher.
- Ícones vetoriais originais em grade consistente, independentes de fontes emoji.
- Recomendações limitadas a 500 candidatas e 100 sementes para limitar o trabalho.

## Recursos pendentes
Compose/Material 3 e temas customizáveis permanecem como migração futura. A UI
continua em Views para preservar os fluxos testados. Álbuns/perfis usam os dados
que cada fonte fornece; pesquisa dedicada de entidades e playlists públicas de
provedores, letras autorizadas e fotos de artistas ainda precisam de implementação.
Não há benchmark físico nem afirmação de menor consumo que outros aplicativos.
