# Argila 3D — protótipo Android (v0.1)

Editor 3D feito para toque, com geometria editável.

## Funcionalidades do protótipo
- Escultura com pincéis **Puxar, Cavar, Inflar e Suavizar**
- **Vértices, arestas e faces**: toque para selecionar e arraste para editar
- **Orbitar** a câmera com um dedo no modo Orbitar, ou com dois dedos em outros modos
- **Zoom** de pinça, e ajustes de força e tamanho do pincel
- Começar com **esfera** ou **cubo**, desfazer movimentos
- **Salvar/carregar** projeto localmente; **exportar OBJ** (malha de triângulos) pela interface de documentos do Android

## Testar no Poco C65
O APK de depuração é gerado por um app escrito em Java puro, **sem bibliotecas nativas separadas por arquitetura**. Portanto, não depende de uma variante somente ARM64 e é compatível em princípio com Android 7.0 (API 24) ou superior, inclusive com o Poco C65. A instalação e o desempenho **ainda precisam ser verificados em um celular real**.

No primeiro teste: abra uma esfera, use os pincéis para esculpir, edite um vértice, uma aresta e uma face, teste desfazer, salvar/abrir e exporte um OBJ. Prefira modelos leves para preservar a resposta ao toque do Poco C65.

## Limitações conhecidas
A prévia 3D usa o Canvas nativo, com sombreamento por face e sem suporte a texturas; é voltada a modelos leves. Esculpir não subdivide a malha automaticamente: o nível de detalhe inicial limita os pormenores. Edição por vértice, aresta e face movimenta os elementos selecionados no plano da câmera. Ainda não há UV, importação, pintura de textura, rigging, timeline nem animação.

## Compilar
Requer Android SDK 35, JDK 17 e Gradle 8.11.1.
Em um ambiente configurado, na pasta `argila3d`:

```bash
gradle :app:assembleDebug
```

Saída: `app/build/outputs/apk/debug/app-debug.apk`.

## Baixar o APK pelo GitHub
1. Abra **Actions** no repositório `Kaique-create-python/Kaique-create-python`.
2. Encontre a execução **Argila3D Android APK** da branch `argila3d-android`.
3. **Aguarde o status verde (sucesso)**. Se a execução falhar, não haverá APK válido: verifique o log.
4. Abra a execução e baixe o artefato **Argila3D-APK** em **Artifacts**.
5. Extraia o ZIP e instale o `app-debug.apk` no Poco C65, permitindo a instalação desse arquivo se o Android solicitar.

O artefato fica disponível por até 14 dias após a execução bem-sucedida. **O APK ainda não foi validado em um dispositivo físico.**

## Etapas seguintes
1. Teste de toque, desempenho e correções em Android real
2. Texturas, materiais, UV e importação
3. Ossos, rigging e animação por quadros-chave
