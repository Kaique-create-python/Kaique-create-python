# Compilação no Termux

O dispositivo usa ARM64 (`aarch64`). Foram instalados e executados os pacotes
nativos `openjdk-21`, `aapt2`, `aidl`, `d8`, `apksigner` e `aapt` (inclui
`zipalign`). Os testes de campanha, inventário, colisão e movimento já podem
rodar localmente:

```sh
python veilbreakers-prototype/tools/test_gameplay_logic.py
```

O Android SDK Platform 35 oficial foi baixado sem ferramentas x86. Seu ZIP
`platform-35_r02.zip` tem 64.273.788 bytes e SHA-1
`0bb560a90a7a2cbd0dd8348224d518b638fe7949`, conferido com os metadados do Google.
O `android.jar` tem 27.092.450 bytes e está em:

```text
~/.cache/veilbreakers-build/android-sdk/platforms/android-35/android.jar
```

A compilação do APK está bloqueada pela versão do empacotador disponível no
Termux: AAPT2 2.19, baseado no Android 13, não interpreta a tabela de recursos
desse SDK 35. O teste `aapt2 dump resources android.jar` retorna:

```text
error: illegal map type 'string' (22).
failed to parse value for resource android:string/ (0x010407c1) with configuration 'am'.
```

O teste `aapt2 link` também falha ao carregar esse include. Baixar o SDK Linux
x86 não resolve a incompatibilidade de arquitetura. O Gradle 9.6 do repositório
Termux também não corresponde ao projeto, que usa AGP 8.5.2 e Gradle 8.7.

O fluxo validado para o APK continua no workflow `build-veilbreakers.yml` com
JDK 17, Gradle 8.7 e ferramentas oficiais do Android em Windows; o emulador
Linux verifica as telas, controles e animações. O código Java pode ser compilado
localmente contra as classes de `android.jar`, e os testes de lógica não dependem
do empacotador AAPT2. A investigação executou ferramentas do Termux, sem acionar
interfaces ou configurações de outros aplicativos Android.

Referências: [compatibilidade do Gradle](https://docs.gradle.org/current/userguide/compatibility.html)
e [AGP 8.5](https://developer.android.com/build/releases/agp-8-5-0-release-notes).
