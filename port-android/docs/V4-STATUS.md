# SpotiFast Android 0.14.1-android-v4-preview1

Migração incremental do módulo Android na branch `spotifast-real-android-port`, baseada no commit V3.1 `e958c66720d9a99826a04b4406d86f5c3826644b`. O código Rust, JNI, egui, librespot e armazenamento de credenciais original permanecem preservados. A tela Android agora abre diretamente; a interface Rust permanece em Perfil.

## Implementado
- Media3/ExoPlayer em MediaSessionService, MediaController, notificação automática, foco de áudio, pausa ao desconectar fones, fila independente da busca, anterior/próxima, seek, shuffle, repeat, restauração pausada e sleep timer.
- SQLite versionado com chaves estrangeiras e transações: playlists, descrição, capa por seletor do sistema, duplicação, remoção, ordenação, arrastar, filtro, favoritos, histórico, fila e posição. Exportação/importação de referências JSON via seletor do Android; sem download de músicas remotas.
- Navegação Início/Buscar/Biblioteca/Playlists, mini-player, player expandido, capas Glide com cache, gradiente Palette, listas recicláveis, insets e controles acessíveis. Progresso não reconstrói a interface e para de atualizar em segundo plano.
- Audius e Jamendo em paralelo, debounce, cancelamento, paginação de faixas, cache temporário limitado, conexões compartilhadas, tentativas limitadas em 429/5xx, identidade por fonte e erros legíveis. Trending/popularidade, gêneros e faixas de artistas; álbuns Jamendo quando fornecidos nos metadados. Revalidação de acesso antes do streaming.
- YouTube com IFrame visível e controles oficiais, validação de links, busca externa autorizada e parada ao sair. Vídeo não integra a fila de áudio.
- Áudio local via seletor de documentos com permissão persistente.

## Auditoria e correções
A V3.1 pausava MediaPlayer em onStop e o liberava em onDestroy, não tinha foreground service ou media session, recriava a UI ao trocar fonte, não persistia playlists nem carregava capas. O novo serviço elimina a dependência da Activity. A identidade da fila não muda quando uma busca termina. O launcher Android evita exigir login Spotify para fontes públicas; não altera nem promete consertar o fluxo OAuth original.

## Validação e limites
A publicação deste preview depende dos testes unitários, lint, testes instrumentados em Android 15 x86_64 e build ARM64 original. Consulte os relatórios do workflow para os resultados efetivos: este documento descreve os testes preparados, não afirma resultados antes da execução.

Os testes instrumentados verificam inicialização, persistência após reabrir o banco, atualização de metadados, duplicação/ordenação e reprodução de um WAV gerado localmente (pause, seek, próxima/anterior, foco, reprodução após fechar Activity e presença da notificação). Isso não substitui testar bloqueio de tela, Bluetooth, chamadas, doze e consumo de bateria no POCO C65. O emulador não executa o motor Rust ARM64.

Não foram medidos startup, memória, frames, consumo de rede ou bateria em dispositivo físico. Busca Jamendo real depende de Client ID legítimo. Disponibilidade de Audius e restrições do YouTube variam; nenhum resultado ao vivo é presumido. Não há reprodução do catálogo Spotify Free, extração YouTube ou contorno de acesso.

Pendentes: busca dedicada de entidades artista/álbum, fotos e perfis completos, playlists públicas Audius, paginação de perfis, recomendações por similaridade, artistas salvos, scanner MediaStore, edição da fila por arrastar, ordem por data original de inclusão, tema dinâmico selecionável, limites de cache ajustáveis/por fonte, equalizador, crossfade, normalização e letras autorizadas. Gapless depende do formato e do suporte padrão do ExoPlayer; não foi medido.

## Instalação e assinatura
Android 8+; engine nativo ARM64. Instale somente o APK acompanhado do SHA-256 desta release. A assinatura é verificada na CI e identificada nas notas da release. A assinatura estável exige secrets `SPOTIFAST_KEYSTORE_BASE64`, `SPOTIFAST_STORE_PASSWORD`, `SPOTIFAST_KEY_ALIAS` e `SPOTIFAST_KEY_PASSWORD`. A chave privada nunca é publicada.

Na ausência desses secrets, a distribuição é explicitamente um **preview com assinatura debug temporária**, que pode não atualizar a V3.1. Não desinstale uma versão com dados importantes sem exportá-los; a troca de certificado impede atualização no Android. Mesmo package ID e preservação de preferências/arquivos permitem manter dados quando a assinatura é compatível. O Client ID V3.1 continua no mesmo arquivo de preferências. Não foi comprovado upgrade entre certificados anteriores.
