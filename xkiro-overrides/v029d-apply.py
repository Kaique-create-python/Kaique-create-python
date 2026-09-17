from pathlib import Path
r=Path('xkiro-ai-studio')
def rw(p,a,b):
 f=r/p;s=f.read_text()
 if a not in s: raise SystemExit('missing '+a[:70])
 f.write_text(s.replace(a,b,1))
p='app/src/main/java/ai/xkiro/studio/openrouter/OpenRouterOrchestrator.kt'
rw(p,'        val visionTier = if (route.tier == Tier.DEEP) Tier.DEEP else Tier.BALANCED\n','        val visionTier = if (route.tier == Tier.DEEP || request.contains("ESTAGNAÇÃO", ignoreCase = true)) Tier.DEEP else Tier.BALANCED\n')
rw(p,'            Retorne SOMENTE JSON válido: {"actions":[...até 6...],"message":"resumo curto","confidence":0.0}.\n','            Retorne SOMENTE JSON válido: {"actions":[EXATAMENTE_UMA_ACAO],"message":"o que a ação fará, sem fingir resultado","confidence":0.0}.\n')
rw(p,'            Não invente sucesso. Se estiver incerto, faça poucos passos e olhe a tela de novo.\n','            Não invente sucesso. Se xKiro estiver em primeiro plano, use home e nunca toque nos controles do próprio xKiro. Só use wait com carregamento visível e não repita wait indefinidamente. finish só quando o frame ATUAL provar conclusão. Se a tela não mudou, mude de estratégia e não repita coordenadas.\n')
p='app/src/main/java/ai/xkiro/studio/core/AgentOrchestrator.kt'
rw(p,'            Formato: {"actions":[...até 5 ações...],"message":"resumo curto","confidence":0.0}.\n','            Formato: {"actions":[EXATAMENTE_UMA_ACAO],"message":"o que a ação fará, sem fingir resultado","confidence":0.0}.\n')
rw(p,'            Não invente o que não estiver visível.\n','            Não invente o que não estiver visível. Se xKiro estiver em primeiro plano, use home e nunca toque nos controles do próprio xKiro. Só use wait quando houver carregamento visível. Não repita a mesma ação sem mudança de tela. finish só quando o frame atual provar conclusão.\n')
