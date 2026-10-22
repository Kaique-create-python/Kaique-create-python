# SpotiFast Android V5 — Interface móvel renovada (preview)

## Mudanças implementadas

- Corrigido bug do RecyclerView que media cada linha como `wrap_content` e deixava a coluna de música/artista com largura zero.
- Tela inicial inspirada no mockup aprovado pelo usuário, com identidade original SpotiFast: fundo preto-esverdeado, gradiente discreto, tipografia hierarquizada, capas reais, mini-player e navegação inferior compacta.
- Seções reais e dinâmicas: músicas recentes do banco local, descoberta através de Audius/Jamendo, destaque da primeira faixa pública e playlists locais existentes.
- Todas as capas/títulos desta tela vêm exclusivamente das APIs autorizadas ou do histórico local. Nenhuma música, artista, podcast ou anúncio fictício é exibido como real.
- Cards de descoberta abrem reprodução real através do Media3 / MediaSessionService, e atalhos de biblioteca/playlist abrem páginas existentes.
- Mini-player compacto com capa, artista, play/pause, próxima e barra de progresso.
- Adicionado teste instrumental para largura do título em tela de celular.

## Permanecem

- Audius e Jamendo (Jamendo exige Client ID do usuário e faixas licenciadas).
- YouTube através de player oficial visível, sem extrair áudio.
- Media3/ExoPlayer, áudio em segundo plano conforme permissões Android, playlists, biblioteca e motor original Rust/librespot preservado no APK.
- Conta Spotify Free não habilita reprodução local de catálogo Spotify Premium.

## Validação

- Compilar pelo workflow `spotifast-real-port.yml` com Gradle, Android Lint, testes instrumentados Android 15, Rust ARM64 e apksigner.
- Testes de layout são executados no emulador; a reprodução real via provedores, callbacks, diferentes modelos de celular e comportamento de uso de bateria ainda requerem testes físicos.

## Limitações

- Reprodução depende de faixas de streaming disponíveis, autenticação e conectividade dos provedores.
- Histórico e playlists dependem dos dados reais locais; quando vazios as seções não aparecem, sem conteúdo inventado.
- Releases sem keystore configurado recebem assinatura de debug efêmera, portanto atualizações in-place podem falhar.
