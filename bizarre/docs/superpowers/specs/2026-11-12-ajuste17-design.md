# AJUSTE-17 — combate legível, controles pessoais e laboratório de treino

Kaique confirmou a AJ16 publicada e funcionando e autorizou os cinco pontos propostos em 12/11/2026. Implementação Luau pelo instalador Termux, sem Studio nem publicação pela IA.

1. Contato: identificação visual discreta e exclusiva de acerto/bloqueio/parry/quebra, com som e reação existentes; feedback só de confirmação do servidor. Clarões menores, alvo legível.
2. Cronologia: observadores entram na posição atual da animação/rajada/voz pelo relógio do servidor; eventos vencidos não reiniciam. Previsão local imediata e ACK sem reinício. ORA/MUDA preservam 4,6s/final4,35s e áudio termina com a ação.
3. Mobile: editor arrastar/tamanho por botão, salvar/restaurar/cancelar, regiões seguras e manter multitouch/soltura. Preferências (volume/câmera/qualidade/tremor/mira/layout) validadas por whitelist no servidor, persistência separada sem alterar estatísticas. Indicar prontidão/recarga sem alterar cooldown real.
4. Laboratório: painel disponível somente no treino; boneco próprio com resposta parado/bloquear após primeiro acerto/esquivar/contra-atacar; reiniciar cenário com cooldown e validação do servidor. Relatório de dano, hits e janela escapável baseada no estado real; sem prometer combo verdadeiro além do que o servidor verifica.
5. Aparência: contraste equilibrado, atmosfera leve e partículas/Beams/Trails dos catálogos reais. Preservar Morioh, colisões, câmera/Shift Lock/R6, mídias/IDs, progresso e valores de Golpes.

Escolha técnica: alteração incremental na arquitetura AJ16, módulos pequenos para política/validação e GUI nativa. Alternativas: refazer rede/câmera ou mapa seria desnecessário e arriscaria partes aprovadas. Nada de migrar autoridade de rede nesta etapa.

Validação: testes de comportamento Luau, pacote Python, regressões anteriores, prévia HTML mobile/PC quando aplicável; teste nativo Saved pelo dono. Aparência/física final depende do cliente Roblox, não de mocks.
