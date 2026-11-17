# Reação a impacto — correção 10 sobre a correção 9

`Efeitos.luau` conserva o módulo completo recebido na correção 9: menu 3D, abertura/fechamento, lanterna, perseguição, pancadas de porta e jumpscare. Nenhum elemento do mapa, layout, legenda ou Pavel foi alterado por esta implementação.

A reação escuta `Humanoid.HealthChanged` do personagem local atual. Só a perda real de vida com o personagem vivo inicia o efeito. Cura, valor inicial ao nascer e golpe letal não iniciam a reação. A morte, remoção do personagem, captura/jumpscare, câmera diferente de `Custom` e `destroy()` limpam o efeito e suas conexões. Um Humanoid adicionado após o personagem também é reconhecido.

## Intensidade e recuperação

- Severidade = `clamp(perda / MaxHealth * 2.5, 0.1, 1)`.
- Ataque visual de 45 ms; recuperação suave, monotônica, até zero.
- Duração total = `2 + 3.5 * severidade` segundos: 2,35 s no mínimo; 20 de dano em 100 de vida = severidade 0,5 e 3,75 s; 40 ou mais = 5,5 s.
- Golpe angular amortecido termina em 0,65 s; limites de 2,8° em pitch e 1,8° em roll, multiplicados pela severidade, amortecimento e preferência de movimento. Não altera posição, FOV, CameraSubject nem CameraType.
- Blur separado até 18 px; saturação até −0,30, contraste até −0,08, brilho até −0,035. Sem flashes ou oscilação de brilho.
- Golpes menores durante os 45 ms iniciais preservam o pico pendente. Durante a recuperação, um golpe menor que a intensidade atual não reinicia nem enfraquece o efeito. Um golpe maior parte da intensidade atual, sem cair a zero ou acumular instâncias.

## Integração com Sector7

Os efeitos próprios chamam-se `S7BastiaoImpactoBlur` e `S7BastiaoImpactoCor`: o `BodycamLook` recebido desabilita efeitos sem o prefixo S7. Eles não substituem nem modificam `S7MotionBlur`, o grade ou a lente.

A aplicação angular roda em `Last + 2`, depois da apresentação e do jumpscare existente. A ordem completa de aplicação é Sector7 (`Camera + 1`), tremor de porta existente (`Last`) e impacto (`Last + 2`). A ordem inversa de unwind é impacto (`Input - 3`), tremor (`Input - 2`) e `BodycamCamera` (`Input - 1`). Cada camada restaura a base capturada somente se a câmera ainda contém seu próprio CFrame aplicado (tolerância 1e-4); assim não acumula rotação e respeita outra câmera/cutscene que assumiu a visão. O teste reproduz porta, impacto e o contrato de unwind condicional do Sector7 juntos por 700 quadros; também destrói as duas camadas ativas entre quadros. Isso é evidência do contrato em harness, não uma gravação do motor Roblox.

O tremor de porta mantém os gatilhos, a força e a duração anteriores. Agora também respeita movimento reduzido, escala por `S7CameraMotion` e limpa seu próprio offset na morte, captura, remoção do personagem ou destruição. Um tremor já expirado não deixa força residual para a próxima pancada.

`GuiService.ReducedMotionEnabled` elimina o movimento angular e o blur; a mudança discreta de cor e o áudio permanecem. `S7CameraMotion` escala a rotação de 0 a 1; `S7MotionBlur = false` elimina o blur de impacto. Preferências são consultadas a cada quadro.

## Áudio

O efeito solicita `op.efeito("impacto_zumbido")`. `Som.luau` dá a essa chave volume 0,20 e o grupo próprio `BastiaoOuvido`, fora do abafamento dos SFX. É necessário um segmento real no AudioCatalog; sem ID/segmento válido, fica silencioso. O arquivo/segmento deve durar pelo menos 5,5 s; o volume recupera com o mesmo envelope. Nenhum ID de áudio foi inventado no código de produção.

O abafamento é um `EqualizerSoundEffect` temporário `S7BastiaoImpactoEQ` criado somente no `BastiaoEfeitos` do módulo Som. Ganhos máximos: agudos −24 dB, médios −9 dB, graves −2 dB. As vozes, rádio, PA, outros grupos, volumes e equalizadores existentes permanecem sob seus próprios donos. Nenhuma propriedade preexistente de mixer é sobrescrita, portanto não há valor global a restaurar nem disputa de volume. A recuperação remove exclusivamente a instância criada pelo impacto. O som de zumbido devolvido por Som é parado/destruído ao limpar; Som já tolera sons encerrados externamente em sua limpeza de heartbeat.

## Interface opcional

`api.impacto(forca, posicaoOpcional)` usa severidade entre 0 e 1. A posição só decide o lado do golpe; não cria explosões, dano, eventos de rede ou autoridade no cliente. Só funciona com o Humanoid atual vivo e câmera `Custom`. O fluxo de dano atual já funciona sem essa API.

Nenhum novo módulo precisa ser incluído no release: basta atualizar os dois módulos já existentes e adicionar o segmento real `impacto_zumbido` ao catálogo de áudio.

## Verificação

Executar em `saida` com Lune 0.11.1:

```
lune run tests/camera_envelope_test.luau
lune run tests/camera_runtime_test.luau
lune run tests/camera_audio_test.luau
```

Cobertura: limites/entradas finitas, recuperação monotônica, kick curto, dano/cura/spawn, golpes repetidos antes e depois do pico, blur/zumbido/abafamento, composição e unwind, outro dono da câmera, movimento reduzido, preferências S7, Scriptable, morte, respawn, captura/jumpscare, destruição idempotente e catálogo sem ID.

Os testes de regressão de cliente usam um harness que deve expor os sinais reais `Humanoid.HealthChanged` e `Player.CharacterRemoving`. Os testes `camera_*` complementam localmente o harness original de entrada, sem alterar esse arquivo.

Não houve playtest em Studio, avaliação subjetiva de conforto/áudio em dispositivo nem publicação nesta etapa. No motor, conferir uma pancada não letal com o bodycam ligado, troca de preferências durante recuperação e captura durante efeito ativo.
