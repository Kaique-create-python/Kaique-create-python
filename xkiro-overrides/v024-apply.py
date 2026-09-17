from pathlib import Path
root=Path('xkiro-ai-studio')

def rep(path,a,b):
 p=root/path; s=p.read_text();
 if a not in s: raise SystemExit(f'missing marker in {path}: {a[:80]}')
 p.write_text(s.replace(a,b,1))

p='app/src/main/java/ai/xkiro/studio/device/DeviceAgentController.kt'
rep(p,'"abra ", "abre ", "abrir ", "entre no", "entra no", "vá para", "vai para",','"abra ", "abre ", "abrir ", "entre no", "entra no", "entre nesse", "entra nesse", "acesse ", "acessa ", "acessar ", "vá para", "vai para",')
rep(p,'"digite ", "toque em", "clique em", "aperte enter", "dê enter", "de enter",','"digite ", "preencha ", "preencher ", "responda ", "responder ", "faça login", "faca login", "entre com a conta", "toque em", "clique em", "aperte enter", "dê enter", "de enter",')
rep(p,'Você controla um Android pelo xKiro Device Agent. Retorne SOMENTE JSON válido.','Você é o cérebro operacional do xKiro Device Agent e possui ferramentas reais para controlar este Android autorizado pelo usuário: abrir URLs/apps, observar a tela, tocar, arrastar, digitar, colar, pressionar teclas e navegar. Não responda como um chatbot dizendo que não consegue navegar; converta o pedido em ações das ferramentas. Retorne SOMENTE JSON válido.')

p='app/src/main/java/ai/xkiro/studio/openrouter/OpenRouterOrchestrator.kt'
rep(p,'Você controla um Android autorizado pelo próprio usuário. Analise screenshot + árvore de acessibilidade.','Você é o cérebro operacional do xKiro Device Agent. Você possui ferramentas reais para controlar este Android autorizado pelo usuário. Analise screenshot + árvore de acessibilidade e converta pedidos de navegação em ações; não responda como um chatbot alegando que não consegue abrir sites ou operar a interface.')
f=root/p; s=f.read_text(); s=s.replace('            Antes de compra/pagamento, envio/postagem, instalação/desinstalação, apagar dados/arquivos em massa, alterar conta/senha/permissões ou outra ação externa irreversível, use need_confirmation.\n',''); f.write_text(s)

p='app/src/main/java/ai/xkiro/studio/core/AgentOrchestrator.kt'
rep(p,'Você é um agente de visão que controla um Android autorizado pelo próprio usuário.','Você é o cérebro operacional de visão do xKiro Device Agent e possui ferramentas reais para controlar este Android autorizado pelo usuário. Converta pedidos de navegação em ações; não alegue que não consegue abrir sites ou operar a interface.')
f=root/p; s=f.read_text(); s=s.replace('            Não invente o que não estiver visível. Para compra/pagamento, envio/postagem, instalação/desinstalação,\n            apagar dados/arquivos em massa, alterar conta/senha/permissões ou outra ação externa irreversível, use need_confirmation antes.\n','            Não invente o que não estiver visível.\n'); f.write_text(s)

p='app/src/main/java/ai/xkiro/studio/MainActivity.kt'
rep(p,'''        when {\n            WorkEngine.looksLikeWorkCommand(text) -> runWork(text)\n            looksLikeResearchRequest(text) -> runResearch(text)\n            DeviceAgentController.looksLikeDeviceCommand(text) -> beginTask("Device Agent • visão + ações") {''','''        when {\n            DeviceAgentController.looksLikeDeviceCommand(text) -> beginTask("Device Agent • visão + ações") {''')
rep(p,'''                }.message\n            }\n            else -> runNormalPrompt(text)''','''                }.message\n            }\n            WorkEngine.looksLikeWorkCommand(text) -> runWork(text)\n            looksLikeResearchRequest(text) -> runResearch(text)\n            else -> runNormalPrompt(text)''')

p='app/build.gradle.kts'
rep(p,'versionCode = 14','versionCode = 15')
rep(p,'versionName = "0.2.3"','versionName = "0.2.4"')
