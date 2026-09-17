from pathlib import Path
root=Path('xkiro-ai-studio')
def rep(path,a,b):
 p=root/path; s=p.read_text()
 if a not in s: raise SystemExit(f'missing marker in {path}: {a[:100]}')
 p.write_text(s.replace(a,b,1))

# Device loop: URL is bootstrap only. Once a real screen exists, force visual primitives.
p='app/src/main/java/ai/xkiro/studio/device/DeviceAgentController.kt'
f=root/p; s=f.read_text()
s=s.replace('''            val visualCommand = buildString {\n                append(command)''','''            val visualCommand = buildString {\n                if (acted > 0) append("OBJETIVO ORIGINAL (não repita abertura de URL/app; continue a partir da tela atual): ")\n                append(command)''')
s=s.replace('''            val maxActionsThisRound = if (frame != null) 2 else 5''','''            val maxActionsThisRound = if (frame != null) 1 else 2''')
# Avoid repeatedly executing semantic launch actions after progress has started.
s=s.replace('''            for (a in plan.actions.take(maxActionsThisRound)) {''','''            for (a in plan.actions.take(maxActionsThisRound)) {\n                if (acted > 0 && a.type in setOf("open_url", "open_app", "launch_app")) {\n                    status("Atalho repetido bloqueado • observando tela novamente…")\n                    continue\n                }''')
f.write_text(s)

# Vision planner: computer-use primitives only after bootstrap.
p='app/src/main/java/ai/xkiro/studio/openrouter/OpenRouterOrchestrator.kt'
f=root/p; s=f.read_text()
s=s.replace('''Você é o cérebro operacional do xKiro Device Agent. Você possui ferramentas reais para controlar este Android autorizado pelo usuário. Analise screenshot + árvore de acessibilidade e converta pedidos de navegação em ações; não responda como um chatbot alegando que não consegue abrir sites ou operar a interface.''','''Você é o cérebro visual do xKiro Device Agent. Controle este Android como um humano olhando a tela. Depois que a tela/alvo já estiver aberto, NÃO use atalhos semânticos como open_url/open_app para continuar a tarefa. Prefira exclusivamente ações físicas: tap por coordenadas, swipe, type/set_text/paste quando um campo estiver focado e teclas Android. Execute somente a próxima ação necessária e depois observe um frame novo. Nunca repita abertura de URL/app quando a tela atual já permite continuar.''')
f.write_text(s)

p='app/src/main/java/ai/xkiro/studio/core/AgentOrchestrator.kt'
f=root/p; s=f.read_text()
s=s.replace('''Você é o cérebro operacional de visão do xKiro Device Agent e possui ferramentas reais para controlar este Android autorizado pelo usuário. Converta pedidos de navegação em ações; não alegue que não consegue abrir sites ou operar a interface.''','''Você é o cérebro visual do xKiro Device Agent. Controle o Android olhando o frame atual como um humano. Após o bootstrap, use tap por coordenadas, swipe, digitação/colagem e teclas Android; não fique reabrindo URL ou aplicativo. Planeje uma ação, observe um frame novo e só então decida a seguinte.''')
f.write_text(s)

# Cursor becomes persistent instead of disappearing after 1.2s.
p='app/src/main/java/ai/xkiro/studio/device/StudioAccessibilityService.kt'
f=root/p; s=f.read_text()
s=s.replace('''            mainHandler.postDelayed({ if (cursorView === v) { runCatching { wm.removeView(v) }; cursorView = null } }, 1200)''','''            // Cursor intentionally stays visible for the whole agent session and moves on each gesture.''')
f.write_text(s)

p='app/build.gradle.kts'
rep(p,'versionCode = 16','versionCode = 17')
rep(p,'versionName = "0.2.5"','versionName = "0.2.6"')
