# Maré Baixa · cidade 3D de CyberOutlaw

Maré Baixa é uma cidade noturna original para Roblox. A malha principal mede **2.400 × 1.920 studs**, tem **80 quadras** de passo 240 e chega a **575 studs** no mastro da Torre Vértice. As vias têm 34, 44 ou 50 studs de largura. As calçadas principais têm 11 studs e as entradas e bancadas foram dimensionadas para avatares R6.

Há seis pontes viárias e três passarelas sobre o canal. A Linha 07 passa acima da avenida central. As escadas da estação chegam às plataformas, e o trem estacionado pode ser visitado. O Mercado Sódio tem bancas, balcões, iluminação e entradas nos quatro lados. Na Doca do Sal há galpão atravessável, guindaste, paletes, caixas, dutos e pátios de serviço. Entre as fachadas ficam floreiras, bancos, grelhas de drenagem, hidrantes, semáforos, armários, passagens cobertas e vitrines. Sete letreiros identificam os pontos de interesse.

## Arquivos e pontos de referência

| Arquivo | Uso |
| --- | --- |
| `entrega/Mare-Baixa.rbxl` | Place autônomo para abrir, explorar e editar |
| `entrega/Mare-Baixa.rbxm` | Modelo para importar na experiência existente |
| `entrega/Mare-Baixa-Planta.png` | Planta com as 80 quadras e o caminho da Linha 07 |
| `entrega/estatisticas.json` | Limites, partes, luzes e centros das quadras medidos no build |
| `materials/` | Oito materiais contínuos, 26 mapas PNG e amostras |
| `world/` | Fontes Luau da cidade. Gere o Place de novo a partir daqui |
| `preview/` | Renderizador de prévias e imagens da cidade |

O centro do mapa fica em `(0, 0, 0)`. O canal acompanha `X=0` e a ferrovia acompanha `Z=0`. Valores negativos de Z apontam para o norte.

| Local | Quadra | Posição em studs |
| --- | --- | --- |
| Nascimento na Praça do Dique | E4 | `(-115, 0.132, -83)` |
| Mercado Sódio | D4 | `(-360, 0, -120)` |
| Estação do Dique | F4 | Plataforma norte em `(125, 27.8, -17.8)` |
| Entrada da Torre Vértice | G3 | `(360, 0.5, -423)` |
| Doca do Sal | B7 | `(-840, 0, 600)` |

Os térreos das torres têm saguões e acessos de serviço. Os andares altos são volumes de fachada. O observatório físico da Vértice está na cota 468 e pode ser visitado com uma câmera no editor. A ligação por elevador e o movimento do monotrilho são pontos de extensão.

## Para o Claude continuar

### Abrir e integrar

1. Abra `Mare-Baixa.rbxl` em Roblox Studio para explorar. O ponto de partida é a Praça do Dique. O arquivo já traz iluminação, spawn e o tipo de avatar R6.
2. Para incorporar ao **CyberOutlaw** atual, parta de uma cópia da versão mais recente do Place `122033314086516`, universo `10774214423`. Importe `Mare-Baixa.rbxm` em uma cópia do Place. O modelo principal chama-se `Maré Baixa` e fica sob `Workspace`. Separe os filhos da pasta irmã `Maré Baixa · iluminação e materiais`. `Atmosphere`, `BloomEffect` e `ColorCorrectionEffect` vão para `Lighting`, e as variantes vinculadas vão para `MaterialService`.
3. Confira os spawns da cópia e deixe ativo o da Praça do Dique para o teste da cidade. O menu do CyberOutlaw guarda a própria cidade de apresentação localmente. O fluxo de **Jogar** restaura a câmera e os controles para o mapa em `Workspace`. Preserve `StarterPlayerScripts`, o HUD e os dados do Place ao integrar. [Código existente do menu e do HUD](https://github.com/Kaique-create-python/Kaique-create-python/tree/codex/cyberoutlaw-menu-3d/cyberoutlaw/src)
4. Compare a versão integrada com a cópia original, teste no cliente Roblox e publique por meio do fluxo de backup do projeto. O arquivo autônomo serve para explorar a cidade. A integração com o menu é feita sobre a cópia da experiência já existente. [Referência de publicação de Place pela Open Cloud](https://create.roblox.com/docs/cloud/reference/Place)

No celular, baixe e extraia o ZIP pelo Termux. O Claude pode reconstruir o mapa numa máquina com Lune e devolver a cópia revisada em formato Roblox. As ferramentas de textura também funcionam no Termux.

### Texturas PBR já prontas

Cada pasta em `materials/` contém cor, normal tangent-space no padrão OpenGL e rugosidade. Metal e vidro também têm metalicidade. Os PNGs são de 512 ou 1024 pixels. `manifest.json` guarda a escala de repetição em studs.

| Material | Repetição |
| --- | --- |
| Asfalto e vidro de fachada | 16 studs |
| Concreto, chapas de aço e cobertura | 12 studs |
| Tijolo escuro | 10 studs |
| Pavers e cerâmica | 8 studs |

O Place entregue já abre com materiais nativos, iluminação, poças e frisos refletidos no canal. As imagens personalizadas precisam de IDs de imagem com permissão para o universo. A prévia usa os 26 PNGs locais e a geometria exportada do mesmo build. O método de iluminação e reflexão do cliente Roblox depende do nível gráfico e do tipo de superfície.

O fluxo de mídia usa o mesmo mecanismo de recibos do CyberOutlaw. O envio pede a chave localmente no Termux. Execute `enviar` quando quiser subir as imagens para o universo. Se algumas ficarem em moderação, rode o comando depois para consultar os recibos. A aprovação de todas gera `material_ids.json`.

```bash
python -B tools/material_assets.py verificar
python -B tools/material_assets.py enviar
```

Com `material_ids.json` pronto, monte uma cópia com as variantes atribuídas nas peças. O argumento final também aceita um JSON montado com IDs aprovados manualmente. Cada entrada usa o nome do material e os campos `color`, `normal`, `roughness` e, quando houver, `metalness`.

```bash
lune run world/build.luau entrega-pbr material_ids.json
```

No Studio, as mesmas variantes podem ser montadas em `MaterialService` com os PNGs importados e uma correspondência entre o atributo `MareMaterial` e a propriedade `MaterialVariant`. Use o mesmo `BaseMaterial` da peça e a escala do manifesto. [Materiais do Roblox](https://create.roblox.com/docs/parts/materials) · [Aparência de superfície PBR](https://create.roblox.com/docs/art/modeling/surface-appearance)

### Como ampliar o mapa e manter o visual

1. **Trabalhe por quadra.** A matriz em `world/layout.luau` referencia os nomes `A1` a `J8`. Os centros têm passo de 240 studs. Coloque novas fachadas e anexos até cerca de 92 studs do centro, reservando as bordas para a rua. Use `world/buildings.luau` para torres, `world/commerce.luau` para comércio e indústria, e `world/public_space.luau` para a orla e mobiliário.
2. **Dê profundidade aos prédios.** Use saguões e entradas no térreo, montantes à frente do vidro, peitoris, pilares recuados, varandas com guarda-corpo e volumes técnicos no topo. Mantenha o ritmo de andares de aproximadamente 12 a 16 studs. Uma porta de 5 × 8,5 studs e uma passagem livre de pelo menos 6 studs são referências para novos interiores R6.
3. **Mostre o desgaste nos lugares certos.** A água se acumula junto ao meio-fio, às juntas e aos bueiros. Aplique pavers nos passeios, concreto no embasamento e aço nas peças de manutenção. Nos mapas de rugosidade, use áreas mais suaves nas poças e deixe o restante do asfalto mais rugoso para o brilho variar.
4. **Ilumine os caminhos.** Preserve a oposição entre neons frios e entradas âmbar. Letreiros servem para identificar pontos que o jogador procura. Nas demais fachadas, use vidro, frisos, marquises e janelas iluminadas. O build limita cada região de 72 × 72 studs por faixa de altura a três luzes locais. Frisos emissivos continuam visíveis entre as luzes da região.
5. **Revise em escala.** O build usa streaming com raio mínimo de 180 e alvo de 640 studs. Reabra o Place, ande pelo mercado, atravesse o canal e embarque no trem. Use o simulador de aparelho e compare com um telefone antes de aumentar o alcance das luzes, as sombras ou a quantidade de objetos. [Streaming de instâncias](https://create.roblox.com/docs/workspace/streaming) · [Otimização no Roblox](https://create.roblox.com/docs/performance-optimization)

### Reconstruir e conferir

Na pasta do projeto, com Lune 0.11.1 e Python 3, execute:

```bash
lune run world/build.luau entrega
lune run world/verify.luau entrega
python -B tools/check_routes.py entrega/visualizacao.json
```

O build gera o Place, o modelo e o JSON com as posições reais das peças. O verificador confere os dois arquivos Roblox. O teste geométrico cobre 11 rotas, incluindo os acessos do mercado e do galpão, a entrada da Vértice, os dois lados da estação e o embarque. Ele mede piso e espaço livre. A movimentação no cliente e os FPS no celular continuam a ser testados em Roblox.

Para produzir novas prévias, use o guia em `preview/README.md`. Para refazer a planta, use `python -B tools/draw_plan.py entrega/estatisticas.json entrega/Mare-Baixa-Planta.png` com Pillow e DejaVu Sans. O gerador das texturas é `tools/generate_materials.py`. [Lune 0.11.1](https://github.com/lune-org/lune/releases/tag/v0.11.1)
