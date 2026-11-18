# Atualização Codex sobre a correção 9

Atualiza o pacote Etapa3 já existente no Termux; não substitui o instalador base. Preserva mapa, layout, interface, vozes e recursos da C9.

- Corrige captura interrompida e grupos de colisão do Pavel.
- Adiciona reação a ferimentos não letais: câmera, visão, abafamento e zumbido.
- Corrige a composição do tremor antigo com a bodycam.
- Dá +15,8% de duração à corrida, sem mudar velocidade.
- Mantém a animação 36 opcional no builder, sem apagar as anteriores.
- Atualiza com pré-verificação, backup e rollback em falhas tratáveis.

**A história ainda termina no Capitulo01. Não foi implementado Capitulo02.**

O novo zumbido é DSP original. Os sons ElevenLabs fornecidos foram mantidos. O áudio novo só toca após preparação/envio/autorização do asset pelo instalador.

`CORRIGIR_ETAPA3_10_CODEX.py` aplica arquivos localmente. Use `--verificar` para conferir sem gravar. Depois execute o instalador existente `BASTIAO_ETAPA3.py instalar`: ele prepara áudio/assets e testa na nuvem antes da publicação. As chaves ficam só no Termux. Nenhum Place foi publicado nesta revisão.

Fontes não reconhecidas são recusadas. Não apague seus arquivos para passar por essa proteção: envie o erro/relatório para revisão.

O detalhe técnico, as pendências reais e o próximo passo da história estão em `PROMPT_PARA_CLAUDE_CORRECAO10.md`. As verificações locais estão em `VALIDACAO_CORRECAO10.json`. Testes locais não equivalem a playtest no Roblox.
