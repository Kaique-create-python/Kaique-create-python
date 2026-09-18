# ATOM Studio

Android app para programar um **M5Stack ATOM Echo / Atom Voice** rodando MicroPython por Wi-Fi.

## O que já faz

- conecta ao MicroPython WebREPL pela rede;
- aceita IP local ou URL WebSocket alcançável;
- procura automaticamente um WebREPL na porta 8266 da rede local;
- terminal WebREPL;
- editor Python;
- salva um arquivo no ESP32;
- carrega um arquivo do ESP32;
- lista arquivos;
- executa código sem salvar;
- interrompe código com Ctrl+C;
- reinicia o ESP32;
- testa o LED RGB do ATOM;
- botão **Testar som** no alto-falante interno.

## Requisito do ATOM

O ATOM deve estar com MicroPython e WebREPL já habilitados no `boot.py`.

Exemplo:

```python
import webrepl
webrepl.start(password="atom123")
```

O celular e o ATOM precisam estar na mesma rede para uso local.

## Acesso remoto

O campo de endereço também aceita um host alcançável fora da rede local.

Use uma **VPN ou túnel seguro**. Não exponha a porta WebREPL 8266 diretamente na internet, pois o WebREPL normal usa WebSocket sem TLS.

## Teste de som

O ATOM Echo usa o barramento I2S interno:

- BCLK: GPIO19
- LRCK/WS: GPIO33
- DATA OUT: GPIO22

O teste gera apenas um tom senoidal curto e de baixa amplitude.

## APK

O workflow `Build ATOM Studio APK` gera um APK debug e salva como artifact `ATOM-Studio-debug`.

## Estrutura

```
atom-studio/
  settings.gradle
  build.gradle
  app/
    build.gradle
    src/main/AndroidManifest.xml
    src/main/java/com/kaique/atomstudio/MainActivity.java
```

## Observação

Esta é a primeira versão funcional. O próximo passo pode incluir editor com abas, gerenciador de vários arquivos, upload em blocos maiores, console interativo e descoberta mais robusta do dispositivo.
