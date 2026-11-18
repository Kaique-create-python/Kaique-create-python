# Verificação AJUSTE-17

48/48 comandos locais aprovados: 43 runners Luau focados; geral34/34 casos; Python69/69; lint0; git diff --check; instalador autocontido testar sem rede. Resultados em RESULTADOS_AJUSTE17.json.

- Cronologia: módulo Acoes real com relógio/agenda controlados; observador atrasado entra no tempo atual de animação/voz, término4,6s/final4,35s, ACK sem reinício, ação vencida descartada.
- Contatos: somente participantes, dedup por hit/phase, evento antigo/tempo parado pendente não produz falso feedback; renderer aplica identidade de defesa e menor opacidade nos núcleos contínuos.
- Preferências: política finita/whitelist, bloqueio de escrita antes de ler, preservação de campos desconhecidos, agrupamento/retry, isolamento por jogador; cliente conserva edição feita durante carga e ignora confirmação antiga. Nada escreveu DataStore Roblox.
- Layout: retângulos reais em568x260/320,667x375,844x390,1280x720,390x844; posição/limites/áreas reservadas/sobreposição. Editor real com instâncias R/serviços controlados: arrastar, salvar normalizado, cancelar sem gravar, rejeitar zona reservada, foco e limpeza. Ajustes gerados pelas funções reais: botões de editar/fechar distintos.
- Laboratório: servidor/política reais com fronteiras externas controladas; elegibilidade, propriedade, defesa após recuperar, cooldown de evasiva inclusive vencendo durante stun, contra após ragdoll, reset limitado sem alterar HP/CD do jogador, limpeza ao sair e geração assíncrona após troca de Stand. Hitbox e TempoSessao excluem alvo de outro dono; registro cliente não o oferece à câmera.
- Regressões: seis Stands, servidor/cliente, mira/Shift Lock, VFX/poses, projéteis, agarrões/tempo/rigs, interrupção/soltura, mídia, instalador e recuperação de POST incerto.
- Migração completa14/15/16→17: três fixtures do Place completo, idempotência e preservação de objetos/pais/valores/opacos;323/545/547 chunks preservados. Não são um backup atual ao vivo. Mapa, Golpes, Regras, Camera, AnimacoesDono e Dados comparados byte a byte à16; catálogos e mídias iguais. Build repetido produz bytes idênticos; tamanho/hash em ENTREGA_AJUSTE17.json.

Revisão independente única: quatro achados importantes corrigidos com RED→GREEN; veja REVISAO_AJUSTE17.md. Native preflight17 inclui verificações anteriores e novas políticas com store falso. Deve passar no comando testar-nuvem antes de publicar.

Limites: não houve execução autenticada Roblox, renderização/física real, seek de áudio ao vivo nem medição de FPS Android. Mock HTML é esquema exportado do Luau, sem screenshot validada: Chromium bloqueado por sandbox e a tentativa de permissão foi cancelada. Controles padrão de pulo/joystick precisam de conferência no celular. Nenhum resultado local é confirmação de publicação.

Skills aplicadas: Roblox VFX/UI Maker/Combat Tools/Game Pipeline e módulos pertinentes de Roblox Brain; quando ficaram disponíveis na sessão, colaboração/input/data/networking/GUI/NPC/lighting foram lidos diretamente. Fontes públicas: github.com/zriptic/roclicks-skills; github.com/JoCoding-Inc/roblox-skills; github.com/TabooHarmony/roblox-brain. Fluxos Studio adaptados à restrição Termux já autorizada. Nenhum asset ou código de modelo externo foi executado/adicionado.
