# Validação — 13/11/2026

## Evidências observadas

- Plugin oficial conectado ao Studio Place1. Mapa gerado com sucesso, `Ready=true`, inicialmente 1.524 Parts e **1.515 Parts depois da remoção de todas as placas**. Contagem posterior: **zero SurfaceGui e zero TextLabel dentro de Sector7World**.
- Suite `tests/Core.spec.luau`: **22 verificações aprovadas, zero falhas**, executada com ModuleScripts reais no Studio. Cobre consumo, exaustão, recuperação, teto da estamina, bloqueio por morte, pré-requisitos, duplicação dos fusíveis e saída idempotente. Os testes foram executados antes e depois das implementações/correções.
- Playtest real: personagem `Humanoid.RigType=R6`; Shift+W por 2,5 segundos levou `WalkSpeed=18`, `Sprinting=true` e estamina de 100 para aproximadamente 61. Soltar interrompeu a solicitação de corrida.
- Fluxo de missão exercitado com os **prompts reais pelo teclado E**: Fuse1 → Fuse2 → Fuse3 → Generator → Keycard → Exit. Estado final observado: `S7Fuses=3`, `S7Power=true`, `S7Keycard=true`, `S7Escaped=true`, `Player.Escaped=true`. Para isolar cada interação, o teste reposicionou o personagem perto dos objetos e apontou a câmera; isso não representa um percurso completo caminhado.
- Modal de evacuação em português apareceu e foi capturado no simulador de celular.
- Respawn via `LoadCharacterAsync()` confirmou novamente R6, estamina 100 e `Escaped=false`, preservando o progresso cooperativo da sessão.
- Capturas do túnel e HUD de celular feitas pelo plugin. A primeira captura branca veio do Studio minimizado; após restaurar a janela, a geometria e a iluminação renderizaram corretamente. O problema não exigiu alteração dos efeitos do jogo.
- Simulador iPhone 17 Pro em paisagem; efeitos e interface preencheram a tela. A configuração da experiência é `LandscapeSensor`; retrato não é uma orientação de jogo suportada nesta base. O simulador foi restaurado para o viewport padrão ao terminar.
- Cliente mantém botões touch em aparelhos que tenham `TouchEnabled`, inclusive híbridos com teclado; isso foi corrigido depois da primeira captura.
- Captura final no iPhone 17 Pro confirmou CORRER e LUZ visíveis, HUD completo e menu de conforto acessível. Teste de soltar/reapertar Shift rapidamente manteve `Sprinting=true` após a correção do filtro de eventos.
- Travessia física da oficina com tecla A por três segundos: personagem saiu de x=0 para x=-29,08, y=3, com vida 100. Blockcasts de volume 4×5×4 não encontraram bloqueios nos acessos das três salas.
- PathfindingService retornou Success para o corredor e NoPath para rotas até as salas, apesar dos acessos fisicamente livres. Esta base usa patrulha simples, sem depender de PathfindingService; uma IA futura deverá revisar a malha de navegação antes de usar caminhos automáticos.
- Animações customizadas 16817753747 e 16817762547 retornaram comprimento zero e mensagens de falta de permissão. Não foram ativadas em Config. A fábrica R6 forneceu `Animate`, preservado como fallback. O modelo de inspeção foi removido do projeto.
- Output do teste final de missão/respawn não apresentou erros do código Sector7. Houve aviso do plugin Roblox sobre atualização interna durante a sessão; as ferramentas continuaram funcionando.

## Limites e próximas verificações

O arquivo `build/Sector7.rbxlx` foi gerado da snapshot do Studio e das fontes finais. `python tools/verify_artifact.py` aprovou sua estrutura: 1.815 instâncias totais, 1.515 peças de mapa, nenhum letreiro, rig R6, dez interações, referências internas válidas e fontes atualizadas. O salvamento pela interface nativa do Studio não completou; o artefato entregue é a exportação XML reproduzível.

- Fazer um percurso completo caminhando, avaliar perseguição, dano, ritmo e dificuldade com jogadores humanos. A ameaça é uma base simples de patrulha/linha de visão, sem inteligência de navegação avançada.
- Testar dois jogadores reais: sessão cooperativa, consumo individual, lanterna e evacuação individual.
- Conferir touch em um celular físico e gamepad físico. O simulador verifica layout, não substitui todos os gestos e limitações de hardware.
- Abrir o artefato exportado em uma segunda sessão do Studio para conferir roundtrip completo de arquivo. Fontes, rig e mapa originais foram testados na sessão conectada.
- Publicar uma experiência de teste e conferir permissões de assets antes de trocar o fallback por animações customizadas.
- Não há persistência de progresso; uma nova sessão reinicia a missão.

## Regra obrigatória de direção

Não adicionar placas, letreiros, inscrições em parede ou marcação textual na porta. O objetivo fica no HUD; os registros narrativos são pequenos documentos interativos. Painéis metálicos da estrutura permanecem como geometria industrial.
