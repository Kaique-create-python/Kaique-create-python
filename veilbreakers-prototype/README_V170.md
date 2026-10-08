# VEILBREAKERS v1.7.0

Android package `com.veilbreakers.prototype`, versionCode **21**. Fonte obrigatória: branch `veilbreakers-apk-build`; base anterior `bc70c03b0ee04e46b4b04abea6726ba9e06ffa9f`.

Esta revisão integra 180 sprites novos gerados e revisados: Kael em quatro direções (idle/walk/run, três combos e cast), Veilborn em quatro direções, hurt/death e oito fases da esfera de Arcana VIII. Walk e run têm poses diferentes. Pivô corporal, escala, hit e release são constantes/documentados.

Leia `VEILBREAKERS_CONTEXTO.txt`, `ART_REVIEW_V170.md` e `SPRITES_MANIFEST_V170.json`. Os scripts de recorte preservam fontes e coordenadas; as folhas e previews completas são reconstruídas em `app/src/main/assets/project_archive/` pelo workflow.

```sh
python -m pip install -r tools/requirements-art.txt
python tools/recover_workflow_assets.py
python tools/validate_v17_assets.py
gradle --no-daemon assembleDebug
```

Build: JDK17, Gradle8.7, Android SDK35/build-tools35. O workflow gera `VEILBREAKERS_v1.7.0_Codex.apk`, contexto e pacote de arte; outro job captura as 180 poses no Android e grava ciclos. O log `VEILBREAKERS_ASSETS` confirma o carregamento real dos 180 arquivos v17. Resultados do run e capturas compactas ficam em `qa/v17/`, fora dos paths que disparam builds.

Não é necessário obter APK ou assets por upload manual. Todos os pacotes de reconstrução estão no repositório; `v17_reviewed_art.zip.b64.part-*` é aplicado depois dos pacotes históricos. O APK contém história, contexto, fontes, previews e manifestos.
