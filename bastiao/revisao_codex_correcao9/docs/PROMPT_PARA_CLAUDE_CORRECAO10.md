# Prompt para Claude — revisão Codex sobre CORRIGIR_ETAPA3_9.py

Você está continuando o jogo Roblox **Projeto Bastião**, terror militar em uma base russa. O jogador é um soldado R6. O 731-A é um humano deformado por um experimento de supersoldado. O dono trabalha pelo Android/Termux, sem computador/Studio. Fale português e entregue comandos curtos, arquivos reais e provas; não apenas planos.

## Pedido atual e limites

O dono pediu: revisar a correção 9, corrigir erros sem remover recursos, deixar câmera/impactos mais realistas e aumentar ligeiramente a duração da stamina. **Ele aprovou o mapa e a interface: não redesenhar, reconstruir, redimensionar, substituir ou apagar nenhum deles.** A exceção Sector7 autorizada é exclusivamente a redução do consumo da stamina descrita abaixo. Não troque os scripts existentes de câmera/HUD.

Destino: universe `10776462844`, place `89520940302906`. A chave Open Cloud fica oculta somente no Termux. Nunca peça que seja enviada ao chat/GitHub. Não apague recibos, caches de geração/upload, saves, backups ou envios pendentes para contornar erro.

## Qual entrega usar

A revisão parte do arquivo **CORRIGIR_ETAPA3_9.py** anexado pelo dono, com seus 36 payloads decodificados por AST e conferidos por SHA-256. Não executamos o Python recebido para inspecioná-lo.

Repositório: `Kaique-create-python/Kaique-create-python`.
Branch da revisão: `codex/revisao-correcao9`.
Instalador local cumulativo: `bastiao/dist/CORRIGIR_ETAPA3_10_CODEX.py`.
Fontes/testes/documentação: `bastiao/revisao_codex_correcao9/`.

**Não confundir o nome desta correção com a sua própria "correção 10 parte 1".** Na base consultada, commit `6aee1bf2c330d4c39633c7654717791633e3596b`, já havia o asset `36_CORRER_MEDONHO.rbxm`, prévias e candidatos a sons da sua próxima correção. Eles não foram apagados, substituídos nem considerados automaticamente instalados no celular. Integre futuras alterações por diff; não reaplique versões antigas por cima desta revisão.

## O que foi feito

1. **Captura do monstro:** interromper/remover a criatura durante um jumpscare deixava a vítima viva ancorada, sem andar/pular. A captura agora guarda e restaura ancoragem, WalkSpeed, JumpPower/JumpHeight, UseJumpPower e AutoRotate. A saída do jogador ou troca de personagem cancela a captura antes do golpe e não afeta o respawn. Capturas fatais frontal/traseira continuam fatais no marcador Impact. Não removemos porta esmurrada, farejar, olhar, perseguição, menu 3D, uniforme do Pavel ou sons da C9.
2. **PhysicsService/Pavel:** métodos de grupos de colisão estavam sendo chamados em workspace. Foram movidos ao PhysicsService. Um StarterCharacter sem Humanoid/raiz válida agora falha com aviso e descarte da cópia, sem derrubar a história.
3. **Impactos na câmera:** Efeitos escuta perda real de vida no Humanoid local vivo. Dano não letal causa um tranco angular amortecido de até 0,65 s, blur até 18, discreta dessaturação e recuperação suave entre 2,35 e 5,5 s, conforme a severidade. Cura/spawn não acionam. Há também `api.impacto(forca, posicaoOpcional)` para uma futura integração explícita; não criamos sistema de granadas, dano no cliente ou novo remoto de dano.
4. **Som de impacto:** zumbido real `impacto_zumbido`, com 5,6 s, ganho de reprodução 0,20, fade e canal próprio `BastiaoOuvido`. Um EqualizerSoundEffect temporário abafa somente BastiaoEfeitos; vozes/rádio/PA não são sobrescritos. **O novo zumbido é síntese DSP original, não ElevenLabs.** Os arquivos ElevenLabs recebidos na C9 foram preservados. O som novo precisa ser preparado/enviado/autorizado pelo fluxo de assets antes de tocar no Roblox; nenhum AssetId foi inventado.
5. **Composição da câmera:** o tremor antigo das pancadas alterava CFrame sem desfazer o offset e ignorava preferências. Agora aplicação: S7 Camera+1 → tremor Last → impacto Last+2; desfazimento: impacto Input−3 → tremor Input−2 → S7 Input−1. Há guard para outro dono da câmera. Respeita movimento reduzido, S7CameraMotion, S7MotionBlur, Scriptable, captura, morte, respawn e destroy. As instâncias próprias usam prefixo S7 para coexistir com BodycamLook.
6. **Stamina, modesta:** `ReplicatedStorage/Sector7/Config`, só `DrainRate = 22` para `19`. Reserva 100, velocidades 10/18, regeneração 16, pausa 1,5 e reinício 30 continuam iguais. Corrida contínua ideal: 4,55 → 5,26 s, +15,8%. Config é table.freeze: não tentamos mutar require nem criar uma segunda simulação ou escritor de WalkSpeed. `instalador/stamina.py` contém as duas fontes exatas. Patcher só permite essa classe/caminho/fonte, recusa Config ausente/desconhecido e ignora hashes extras de `known` para ampliar essa exceção. SHA original confirmado no RBXL: `144382edfc65a9e96a53c2a7cfcc51b2eb56fd0d1eaeff2300ff53eedc97df50`.
7. **Animação opcional 36:** builder e teste nativo aceitam as 35 existentes e também a 36_CORRER_MEDONHO opcional, quando presente no plano e com recibo real aprovado/autorizado. Não adicionamos um ID fictício nem alteramos/apagamos o plano de assets do dono. Aceitar o catálogo não equivale a integrar a animação no seletor de corrida: verifique esse ponto na sua continuação.
8. **Atualizador:** valida todos os payloads antes de escrever; recusa fontes desconhecidas, incluindo modo criar; rejeita symlinks ancestrais; backups completos antes da troca; gravação atômica por arquivo, rollback em falhas tratáveis e relatório por aplicação. Idempotente. O plano de áudio é mesclado apenas nas chaves aprovadas, preservando vozes, configurações e clipes alheios. --verificar é leitura. A atualização local não publica Roblox.

## A continuação da história existe? NÃO

Verificamos o código, não só nomes/comentários. BastiaoServidor requer apenas Capitulo01 e, ao finalizar, atualiza ATR_FIM. O capítulo liga `s8_lista_fim` a `fim_etapa`, `final=true`, checkpoint `fim_etapa1`. Não existe Capitulo02 implementado nem carregamento de capítulo posterior.

Último trecho jogável: fuga até a oficina, trava da porta, leitura da lista do terminal, Elena/Pavel e três toques na parede; `pavel_sinal` encerra. Os novos comportamentos da criatura não são uma continuação narrativa.

Sua próxima prioridade narrativa é implementar **uma sequência posterior completa e pequena**, partindo desse estado, com início, objetivo, consequência e checkpoint recuperável. Proponha/escreva a partir da história/PDF que você já recebeu. Não invente que leu um PDF se ele não estiver disponível: peça o arquivo ou encontre-o no Drive autorizado. Integre por dados Capitulo02/StoryRunner/Missao/Sequencias/StoryValidator, sem espalhar missões em scripts soltos e sem recriar o mapa aprovado. Não tente completar todos os capítulos de uma vez.

## O que ainda revisar e resolver

- **Playtest no motor é obrigatório antes de afirmar que está funcionando no jogo.** Esta entrega teve compilação, harness e testes de patch local; não teve Studio, simulação real de física/assets nem publicação por nós. O dono executa o teste Saved na nuvem pelo instalador; uma falha deve bloquear a publicação.
- A reação a ferimento só ocorre com dano real não letal. O jumpscare fatal mantém a apresentação própria e prioridade de câmera; não foi convertido em tapa não letal. Se você adicionar ataque que empurra sem matar, mantenha a decisão de dano no servidor e conecte-o ao mesmo fluxo, sem duplicar impactos no cliente.
- Na próxima integração, conferir a 36_CORRER_MEDONHO contra o mesmo rig/escala, adicionar ao plano/recibos se faltar e escolher explicitamente na corrida, com fallback 08_CORRER. Não remover as 35 anteriores. Ajustar taxa de animação à velocidade e validar marcadores dos passos/impactos no motor.
- Validar conforto da câmera no celular real: pancada e bodycam simultâneas, preferências alteradas durante recuperação, captura durante o blur, morte/respawn e câmera Scriptable. Não fazer o tranco mudar direção de movimento/tiro. Não mudar a aparência do HUD/menu para obter os efeitos.
- Conferir áudio aprovado e permissionado para este universo, regiões dos sprites e volumes em fones/alto-falante. Não substituir falas por rótulos como "som de...". Legendas de diálogo/localização existentes devem continuar.
- O plano C9 contém 20 falas; 17 estão como reuse com fontes conferidas. `elena_nome`, `pavel_registro`, `pavel_sinal` ainda aparecem como TTS planejado no pacote recebido. Isso não prova ausência no cache do celular, nem prova que foram geradas. Conferir recibos/cache antes de solicitar ElevenLabs. Não diga "todas as vozes prontas" sem conferir os arquivos. Preservar clips gerados pelo dono e não repetir POST após timeout sem resolver o recibo.
- Dois jogadores: captura só afeta a vítima, saída durante captura não prende outro personagem, áudio espacial não toca globalmente, Pavel não bloqueia portas e safe zone não pode ser usada para rastreamento através da parede. Não mudar geometria para esconder bug de navegação.
- História: retomada de checkpoint não deve repetir apresentação/objetivo anterior, falas não devem se atropelar, ações são validadas pelo servidor e o próximo capítulo não deve apagar progresso existente.

## Testes e entrega

Leia `VALIDACAO_CORRECAO10.json`, `docs/CAMERA.md`, `docs/AUDITORIA_HISTORIA.md`, `docs/INSTALADOR.md` e o diff da revisão. Para testes locais, instale Python e Lune 0.11.1. A pasta de revisão contém testes e fontes; os assets completos continuam no pacote original extraído no Termux. Não use recibos/IDs de fixtures para uma release real.

```
python -m unittest discover -s tests -p 'test_*.py'
lune run tests/camera_runtime_test.luau
lune run tests/server_capture_test.luau
python tests/check_place_preservation.py /caminho/place_original.rbxl
```

Integração binária foi testada sobre o original de 9004 instâncias: todos os objetos originais, hierarquia e 1747 chunks de propriedades não Source preservados; 12 fontes originais protegidas intactas; única mudança em fonte original foi DrainRate. Não confundir essa evidência com teste do motor ou estado do Place privado mais recente.

No Termux, depois da correção local: `python ~/storage/downloads/BASTIAO_ETAPA3.py instalar`. O fluxo existente prepara áudio, envia/acompanha assets, testa Saved e pede a confirmação final de publicação. Se houver envio incerto, preserve active-write.json e use resume com o mesmo payload congelado. Não remova travas nem publique sem teste aprovado.

Entregue a próxima alteração pequena, com testes, instalador baixável pelo GitHub e comando curl funcionando. Explique exatamente o que foi feito e o que ainda depende de teste/moderação. Não prometa que a história avançou antes de existir uma missão posterior jogável.
