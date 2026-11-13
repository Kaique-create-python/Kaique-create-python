# Revisão AJUSTE-17

Revisão independente única por gpt-6-astra, leitura da mudança contra AJ16/ec5f2a1, sem mutações nem chamadas Roblox.
Quatro achados importantes, corrigidos com regressões que falharam antes e passaram depois:

1. EDITAR BOTÕES sobrepunha FECHAR: painel de ajustes ampliado/recentralizado, geometria das funções reais validada (tests_settings_layout17).
2. Cooldown de evasiva terminando durante stun não entrava na janela de fuga: política avalia a primeira oportunidade real no intervalo anterior (tests_training17).
3. Alvo privado ainda atraía seleção/tempo parado: predicado antes das consultas Hitbox, TempoSessao e registro visual; Camera fica byte a byte igual (tests_private_targets17/private_registry17).
4. Rig criado de forma assíncrona sobrevivia à troca de Stand: limpeza invalida pedido mesmo sem alvo pronto e conclusão verifica geração (tests_training_server17).

Nenhum achado crítico ou menor listado; nenhuma segunda revisão. Resultados do revisor foram conferidos pelo implementador com testes; roteiro e decisões em specs/plans e VALIDACAO_AJUSTE17.

Não avaliado pelo revisor: renderização, seek/áudio nativo, controles padrão do Roblox, replicação/física ao vivo, FPS Android e fidelidade visual. Decisão do implementador: manter esses itens como conferência no cliente após Saved; não alegar validação nativa. A revisão não autoriza publicação e não contorna os bloqueios do instalador.
