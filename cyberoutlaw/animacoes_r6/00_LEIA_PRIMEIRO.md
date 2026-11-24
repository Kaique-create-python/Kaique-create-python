# Pacote de animações R6 — entrega para Claude

Seleção final de 10 ciclos: idle Okarun V3, oito caminhadas direcionais e sprint frontal Okarun V5. Versões anteriores excluídas. Os arquivos foram renomeados externamente e reorganizados, sem alterar os movimentos ou os nomes internos das KeyframeSequences. O manifesto relaciona nomes internos e caminhos.

| Arquivo base | Entrada | Função | Ciclo | Keyframes | Vel. referência (studs/s) |
|---|---|---|---:|---:|---:|
| `Idle_Okarun_R6` | Parado | Repouso / respiracao pesada | 5 s | 151 | — |
| `Walk_Forward_R6` | W | Caminhar para frente | 1.2 s | 73 | 3.5 |
| `Walk_Backward_R6` | S | Caminhar para tras | 1.2 s | 73 | 2.5 |
| `Walk_Left_R6` | A | Caminhar para esquerda | 1.2 s | 73 | 1.5 |
| `Walk_Right_R6` | D | Caminhar para direita | 1.2 s | 73 | 1.5 |
| `Walk_ForwardLeft_R6` | W+A | Caminhar na diagonal frente-esquerda | 1.2 s | 73 | 2.7 |
| `Walk_ForwardRight_R6` | W+D | Caminhar na diagonal frente-direita | 1.2 s | 73 | 2.7 |
| `Walk_BackwardLeft_R6` | S+A | Caminhar na diagonal tras-esquerda | 1.2 s | 73 | 2.0 |
| `Walk_BackwardRight_R6` | S+D | Caminhar na diagonal tras-direita | 1.2 s | 73 | 2.0 |
| `Sprint_Forward_Okarun_R6` | Sprint frontal | Corrida frontal anime explosiva e fluida | 0.5 s | 31 | 13.2 |

## Formatos
- `.rbxmx`: KeyframeSequence nativa para importar/editar no Roblox Studio; publicar como animação e obter AnimationId real.
- `*_CreateRig.lua`: script auxiliar de Command Bar para modo edição; cria rig de teste e sequência. Não é controlador de runtime. Não executar diretamente no jogo publicado.
- `.glb`: modelo 3D animado para visualização; não substitui o rig Motor6D.
- `.mp4` e `.png`: referência visual. O vídeo de cadência 2x é a mesma corrida, não um novo asset.
- `00_Manifesto.json`: identificação inequívoca, velocidades de referência, caminhos e hashes.

## Integração
Use `00_INSTRUCOES_PARA_CLAUDE.txt`. As animações são in-place, sem root motion acumulado. Frente do avatar em -Z; direita em +X. R6 não tem joelhos nem cotovelos articulados. As caminhadas usam pequenas compensações de translação; não reutilize indiscriminadamente os transforms em rigs diferentes. As velocidades de referência estão no manifesto (algumas notas originais de caminhada repetem a velocidade da versão frontal).

## Validação e limites
ZIP e arquivos XML/GLB verificados estruturalmente. Os tempos são crescentes e primeira/última pose de cada sequência coincidem dentro da tolerância de 1e-5. Importação, publicação, replicação, blending e gameplay no Roblox Studio não foram testados nesta entrega. Não há AnimationIds publicados nem controlador pronto. O sprint fornecido é somente frontal.
