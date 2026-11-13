# Validação AJUSTE-15

Base: AJUSTE-14, publicação v36 confirmada pelo usuário. A15 preparada offline; não publicada aqui.

- Combate: perfil responsivo para Silver Chariot e Magician’s Red. Crazy Diamond e Killer Queen continuam legados. Golpes, Regras, andar/correr, Camera, Dados e Mapa preservados byte a byte.
- Catálogo adicional: 14 templates do ZIP original, 24 ParticleEmitters e 10 meshes visíveis. Sem scripts, sons, humanoids, juntas ou remotos importados. Catálogo14 preservado byte a byte.
- Renderer: instâncias reais no Lune para mesh, fade, captura na vítima confirmada, formação/queda do fogo, cancelamento, TTL e limpeza por troca de Stand.
- Projéteis: pausas independentes confirmadas pelo servidor; retomada sem salto de posição, reflexão e limpeza. Registro de todos os escopos derivados da prévia.
- Animações: poses próprias SC/MR com valores finitos; cenas de até 0,9s. Cópias residuais do Stand real, sem colisão, com fade e duração de 0,25s.
- ADM: seleção entre quatro Stands, reproduzir e parar. Prévia local sem dano, remoto de combate, câmera ou voz de ataque.
- Instalador: fontes AJ14 reconhecidas, estado15 independente, proteção de envio14 pendente, confirmação explícita, intenção durável antes do POST e recuperação somente por consulta. Publicação no mesmo número de versão exige flag Published e hash completo iguais.
- Patch: Place14 completo reconstruído offline, atualização idempotente e preservação dos objetos, pais e 323 pacotes originais de propriedades/opacos. O fixture não é um backup ao vivo.
- Uma revisão independente encontrou três problemas; corrigidos com regressões que falharam antes da correção. As fronteiras HTTP, relógio e sinais são controladas nos testes.

Evidência local: teste geral com 34 casos, 63 testes Python e runners específicos em tools/tests_*15.luau. Contagens e hashes finais: ENTREGA_AJUSTE15.json e dist/SHA256_AJUSTE15.txt.

Nenhum resultado offline representa execução autenticada no Roblox, física real, avaliação visual, FPS ou teste Android. Kaique ainda deve executar testar-nuvem e conferir lâmina, fogo, câmera e controles no celular. A autorização e renderização das texturas dependem do Roblox. Não há novos uploads de mídia.

Módulos internos conservam nomes14 por compatibilidade. O catálogo15 é separado; as silhuetas existentes dos projéteis são reutilizadas junto dos efeitos curados.
