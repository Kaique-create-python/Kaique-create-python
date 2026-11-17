# Ferramentas de verificação da Etapa 3 (pacote do ChatGPT)

Rodam no Lune, sem Roblox e sem chave nenhuma.

- `fluxo_mapa_real.luau`: roda o trecho "abertura inteira" do `teste_nuvem.luau` de verdade, com o
  mapa Sector7World do place, raycast contra as peças e jogadores falsos (como na nuvem, que não deixa
  criar Player). `pavel` coloca o corpo do Pavel no cenário (foi assim que achamos o braço dele
  bloqueando o rádio). `duracoes.json` usa as durações reais das vozes.
- `teste_contrato.luau` + `glb_ossos.luau`: monta os 46 ossos a partir do próprio GLB e testa o
  `MonsterImportContract` em 15 situações (igual ao arquivo, giro do importador, rotações zeradas,
  troca de eixo, escala, deitado, raiz deslocada...).

O arquivo `dist/CORRIGIR_ETAPA3_3.py` aplica as mudanças de `docs/CORRECAO3_ETAPA3_CHATGPT.patch` na
pasta já extraída no celular (mantém os recibos de assets; não reenvia nada).
