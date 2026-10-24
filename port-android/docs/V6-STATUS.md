# SpotiFast Android V6 — experimental 1

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
