# Revisão Codex da correção 9 — Projeto Bastião

Instalação móvel: use **../dist/CORRIGIR_ETAPA3_10_CODEX.py**, sobre o pacote Etapa3 já existente. Este diretório guarda fontes e testes para revisão; não é um instalador base e não inclui GLBs/texturas/animações completos nem recibos de assets do dono.

Mapa e layout/HUD preservados. Correções de captura/Pavel, impactos na câmera e +15,8% na duração da stamina. O Capitulo02 ainda não foi implementado.

- [Resumo da atualização](docs/CORRECAO10_CODEX.md)
- [Prompt completo para Claude](docs/PROMPT_PARA_CLAUDE_CORRECAO10.md)
- [Câmera e áudio de impacto](docs/CAMERA.md)
- [Auditoria da história](docs/AUDITORIA_HISTORIA.md)
- [Instalador e backups](docs/INSTALADOR.md)
- [Resultados locais](VALIDACAO_CORRECAO10.json)

Os testes usam Python, ffmpeg e Lune 0.11.1. Execute `python -m unittest discover -s tests -p 'test_*.py'`. Rode cada `tests/*_test.luau` e `tests/*_compile.luau` com Lune. Para conferir preservação sobre um backup binário: `python tests/check_place_preservation.py /caminho/place_original.rbxl`.

O gerador `tooling/build_correction10.py` lê apenas literais da correção 9. Não execute scripts baixados para extrair payloads. Os testes não enviam dados ao Roblox/ElevenLabs. O instalador de correção é offline; a publicação real continua com o instalador existente após teste Saved aprovado.
