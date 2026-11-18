# AJUSTE-14 — piloto Star Platinum / The World

Spec: plano aprovado no chat em 2026-11-11, “BIZARRE — primeira etapa: Star Platinum e The World”.
Base remota b60be0a8f49a5c0a0dc3fbd77cdbec6fa4ab1fc0, árvore05f4d850e96fd7b4a861217127474cf3aa81e595.
O snapshot Git local0c5d93e é apenas a cópia parcial verificada; não é o commit remoto.

## Restrições

- Universe10774214555,Place108061345551908,dono1357078972. Nenhuma publicação/API Roblox aqui.
- Kaique usa Android/Termux sem Studio. Chave somente getpass no celular, nunca chat/log/arquivo.
- AJ13 está instalada e animação/câmera funcionam segundo Kaique. Manter R6, clipes do dono,
  mira manualMIRA/ShiftLock, distância11, seis Stands, Morioh/colisões, áudios/IDs/DataStore.
- Novo combate/VFX é para ataquesSP/TW. Os outros4 permanecem AJ13; iluminação é global.
- Qualidade alta; nenhuma redução automática porFPS. Somente assets reais do ZIP, não VFXNeon
  inventados. Limpeza de vida útil/cancelamento é correção, não corte de qualidade.
- ORA/MUDA completos4.6s, contato final4.35; tempo para em1.7s, SP3s/TW5s. Cinema<=.9s.
- Original ZIP preservado; SHA fd7569c0dec63ab43a99ec27e55bd64f2a9e857a7bb274a65287ada115b73c8c.

## Tarefas e ownership

1. Combate: servidor Combate/Hitbox, Regras, cliente Jogador/Controles, novos módulos de política
   e testes próprios. Novo protocolo additive seq/actionId/hitId/phase/t. Pai possui Config,
   Golpes, Acoes, Efeitos, Main.client, Main.server e integração.
2. Assets/VFX: ferramentas de curadoria, assets/vfx14, novos módulos BB/VFXReceitas e
   Cliente/VFXPiloto, testes próprios. Sem editar VFX/Efeitos/Acoes/Config existentes.
3. Gráficos: novo Cliente/AmbienteVisual14, Camera/Cinematica e testes próprios. Não editar
   Efeitos/Animador/Main/Config; comunicar hooks ao pai. Preservar APIs existentes.
4. Installer: pasta installer14, gerador novo tools/gerar_ajuste14.py, testes Python próprios.
   Patcher Sources reconhecidas+inserção catálogo real, preservando chunks opacos/referências.
   Não tocar dist até integração final nem usar gerador antigo que reconstrói cidade.
5. Pai: integração Efeitos/Acoes/Main/Config/Golpes, preflight real, pacote/preview, docs,
   verificações, review independente e entrega GitHub por lease, sem publicação Roblox.

Todos implementam com RED→GREEN nos módulos reais, fronteira Roblox simulada só quando
necessária. Não testar regex de implementação como prova do comportamento. Sem commits/push
pelos workers; pai integra/commita. Cada worker mantém relatório ../audit/<domínio>.md.

## Combate fixado

- Perfil novo sóSP/TW, separável em módulo puro; não adicionar flags arbitrárias ao pacote
  que o cliente possa usar para criar dano/cancelamento. IDs gerados/validados pelo servidor.
- BufferTOTAL1, TTL.12s, último comando válido substitui; apenas recuperação própria normal
  ou cooldown que termina em<=.12s. Não guardar ataques emstun/ragdoll/congelamento/menu/morte/
  rajada/ULT/agarrão. Release deguarda/toque/foco é imediato, nunca fila. Defesa segurada
  pode ativar ao recuperar enquanto dedo continua; parry usa horário original de apertar.
- M1: n1..3 contato.10/janela.08/recovery.30; n4 contato.16/janela.08/recovery.45, cooldown1.1
  preservado. Varredura servidor com dedupe1hit/alvo/swing, apenas corposR6 e parede real.
- M1n1..3 pode cancelar recovery para slot1..4 após acerto real+60ms; bloqueio/parry/erro não
  autorizam. Habilidade não zera contador/cooldown M1. Sem cancelvoluntário de n4/rajada/ULT/
  agarrão. Airlink é a exceção planejada do uppercut, não um cancel genérico.
- Uppercut confirmado cria link único atacante/vítima (mira se foi atingida, senão mais perto),
  abre hitTime+.18 até+.65. Novo m1_aereo consome tentativa ao iniciar mesmo errando; bypass
  somente cooldownM1 e recovery do MESMO uppercut, e veto ragdoll para vítima vinculada.
  Continua bloqueado por morte/stun/congelamento/ação diferente e valida alcance/corpo.
- Seguimento: impacto.10,janela.08,recovery.30, dano Regras.danoM1(1,standFora), impulsofrente8/
  cima-24/dur.12; sem elevar/renovar ragdoll. Preserva combo4, próximoM1 no máximo entre
  cooldown original e startSeguimento+.45. Link reservado continua válido só para resolver
  aquele ataque iniciado no prazo; invalida por uso/morte/trocaStand/cancelamento/remoção.
- Sem redução global progressiva dehitstun nesta etapa. Proteções são finalizador/recovery/
  cooldown, evasiva22s/proteção pósqueda.9 originais e única extensão aérea sem novo launcher.
- Mensagens antigas/duplicadas não interrompem ações novas. Previsão sóanimação/antecipação;
  impacto/dano só confirmação. Bots sem seq continuam aceitos pelo fluxo do servidor.

## Contrato VFX e assets

Catálogo: RBXM com ÚNICA raiz Folder BB_VFXCatalogo14 em ReplicatedStorage. Templates filhos
com nomes estáveis de manifesto. Nada de scripts, remotos, áudio, Humanoid/rigs, GUI, câmera ou
galerias. Preservar links Attachment0/1 dentro dos templates. Assets antes/depois conferidos.
EmitCount/EmitDelay/EmitDuration/EmissionDirection/FlipbookLayout/texturas preservados.

API VFXPiloto:
- suporta(standId:string?):boolean
- iniciar():() — idempotente
- tocar(standId:string,moveId:string,phase:string,ctx:any):any? — handle opcional
- cancelar(owner:Model?,actionId:string?):() — desliga contínuos, partículas já emitidas morrem
- congelar(sessionId:any,owner:Model?,fim:number):() / descongelar(sessionId:any):()

phase = inicio/contato/final/fim. moveId = id Golpes ou m1/m1_aereo/dash/bloqueio/parry/
quebra_guarda/tempo/tempoVolta/rolo. ctx = {owner:Model?,target:Model?,pos:Vector3?,dir:Vector3?,
actionId:string?,hitId:string?,t:number?,dur:number?,variant:string?,n:number?}.
t é GetServerTimeNow; ausência usaagora. Ordinais no manifesto resolvem nomes duplicados.
Dedup dehit usa(hitId,phase), pois fila do tempo e resolução podem mostrar fases diferentes.
Roteamento dos4legados permanece VFXAJ13.

Seleções iniciais E=112672322113504,S=107474757639811:
- E Anime/Punch-01/02/03,Stars-01,Shiny-01,Wind-01/02,Charge-01,ForceField-Break-01,Crack-01,
  Shoot-01,Portal-01,Portal-Enter-01; E Beams/Wind-01 paraStarFinger; Big/Explosion-01 paraRolo.
- S vfxpack/premade/direction_one,direction_all,speedlines; separated/impacts,stars,ring,lines,
  smoke. SPvioleta/branco/azul; TWouro/âmbar/escuro; núcleo branco mantido.
- Rajadas inicio.25SP/.20TW,ticks.12 até3.7,carga3.7..4.35,final4.35,saída4.6.
- Reservar scripts-modelos deespada parafuturoSC; MegaPack7218decals é biblioteca e não
  cenário para colocar nojogo. Imagens novas/atlasáudio não são necessárias neste piloto.
- Renderizador sem cap48 que corte receitaspiloto, com lifetimes/escopos corretos e limpeza.

## Gráficos

AmbienteVisual14.iniciar():idempotente; não requer Config14 para ser testável isolado.
Perfil alto,ClockTime15.8,LightingStyle.Realistic,PrioritizeLightingQuality=true,sombras,
solquente/sombrasmédiasfrias,Atmosphere/Bloom/ColorCorrection controlados. Materiais existentes
paraasfalto/concreto/metal/vidro, preservandoPartes/CFrames/colisões/texturas especiais.
DOF somente cinema. Impacto visual escopado atacante/vítima .04 básico/.08 forte, sem pausar
animação de terceiros. Pai usa Animador.hitstop(modelo,dur), remove uso global nesses acertos.
Camera/Cinema devem preservar manualMIRA/ShiftLock e APIs existentes; leases/tokens fazem
FOV/cor/DOF voltarem ao perfil correto após fim/interrupção/morte/trocaCurrentCamera.

## Verificação e entrega

- Suite34Lune existente, compilação todos, lint (falso positivo antigo aoSoltar pode ser
  corrigido com teste do parser). Novos testes módulos reais e integração.
- Casos: seqold/dup, janela.12, releaseBLOQ/stun, whiff/block/parry, parede/acessório, sweeps,
  airlinkduplo/errado/fora/expirado, duas sessões tempo, fimdevozes/efeitos,6stands compat.
- Catálogo sanitizado e referências(texturas/Beam/Trail) íntegros, patch idempotente e opacos
  mapa/mídias intactos. Testes de POSTincerto/resume/recibo/backupconflitante/destino rígido.
- Installer Python único BIZARRE_AJUSTE14.py, comandos testar/testar-nuvem/publicar/resume.
  Chave sógetpass, Saved e teste antes dePublished explícito; POSTúnico+intent persistente,
  resume somenteGET/verificação. Não usarSavePlaceAsync; fonte desconhecida bloqueia/exporta.
- Nativepreflight executado noTermux pelo Kaique; aqui semkey, não alegar physics/client/FPS
  ou publicação. Assets opcionais falhos dão relatório/fallback, não bloqueiam gameplay.
- Prévia deve usar osassets reais (cena Roblox/visualizador com fonte identificada); nenhuma
  conceptart representada como captura do jogo. Registrar limitações reais de render.

## Review focus

1. Corpos/colisões e alvo errado: nunca dano emacessório/VFX/atravésdeparede.
2. Interrupção e seqatrasada: não sobra voz/luz/câmera nem reseta ação maisnova.
3. Airlink: sóum poruppercut, sembypassgenérico/múltiploslaunchers.
4. Inserção catálogo: referências e chunksdesconhecidos preservados, sem código dospacotes.
5. Envio incerto: nuncaPOSTduplo, destinofixo, proof/bytes ePublished conferidos.
