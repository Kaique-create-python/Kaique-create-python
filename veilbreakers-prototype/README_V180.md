# VEILBREAKERS v1.8.0

Continuação da v1.7 no branch `veilbreakers-apk-build`: primeira missão Cinzas do Oitavo,
seis áreas das Ruínas de Varyn, dois sobreviventes, diálogos de texto gradual, encontros
persistentes e status com atributos/diário de missão. Só o conjunto RUN ganhou arte nova;
os demais 156 sprites v1.7 continuam em uso. A fase da corrida segue a distância após colisão.

Use o joystick para mover; toque INTERAGIR perto de objetos/NPCs/saídas. Na conversa,
um toque revela a fala e outro avança. STATUS pausa o combate, distribui pontos e exibe a missão.
O Portão Norte encerra a missão; o santuário permite descanso.

## Reproduzir

JDK17, Android SDK35/build-tools35, Gradle8.7, Python com Pillow11.3.0:

```
python tools/recover_workflow_assets.py
python tools/validate_v17_assets.py --version 1.8.0
python tools/test_gameplay_logic.py
gradle --no-daemon assembleDebug
python tools/verify_apk_v17.py app/build/outputs/apk/debug/app-debug.apk
```

O workflow produz `VEILBREAKERS_v1.8.0_Codex.apk` e `VEILBREAKERS_CONTEXTO.txt`.
O APK contém o arquivo de recuperação `project_archive` com história, manifestos,
fontes históricas, nova corrida e contexto atual. Capturas da nova revisão em `qa/v18`;
`qa/v17` permanece histórico e contém imagens encobertas pelo aviso imersivo do Android.

Uma atualização sobre o APK anterior depende da mesma assinatura. Não desinstale
uma instalação com save para resolver erro de assinatura.
