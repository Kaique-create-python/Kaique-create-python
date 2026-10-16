# Argila 3D — protótipo Android (v0.1)

Editor 3D feito para toque, com geometria editável.

## Funcionalidades do protótipo
- Escultura com pincéis **Puxar, Cavar, Inflar e Suavizar**
- **Vértices, arestas e faces**: toque para selecionar e arraste para editar
- **Orbitar** a câmera com um dedo no modo Orbitar, ou com dois dedos em outros modos
- **Zoom** de pinça, e ajustes de força e tamanho do pincel
- Começar com **esfera** ou **cubo**, desfazer movimentos
- **Salvar/carregar** projeto localmente; **exportar OBJ** (malha de triângulos) pela interface de documentos do Android

## Limitações conhecidas
A prévia 3D usa o Canvas nativo, com sombreamento por face e sem suporte a texturas; é voltada a modelos leves. Esculpir não subdivide a malha automaticamente: o nível de detalhe inicial limita os pormenores. Edição por vértice, aresta e face movimenta os elementos selecionados no plano da câmera. Ainda não há UV, importação, pintura de textura, rigging, timeline nem animação. É um protótipo não testado em dispositivo real.

## Compilar
Requer Android SDK 35, JDK 17 e Gradle 8.11.1.
Em um ambiente configurado, na pasta argila3d:
\`\`\`bash
gradle :app:assembleDebug
\`\`\`
Saída: app/build/outputs/apk/debug/app-debug.apk

O GitHub Actions publica o artefato \`Argila3D-APK\` (ZIP contendo o APK) a cada push na branch \`argila3d-android\`.

## Etapas seguintes
1. Teste de toque, desempenho e correções em Android real
2. Texturas, materiais, UV e importação
3. Ossos, rigging e animação por quadros-chave
