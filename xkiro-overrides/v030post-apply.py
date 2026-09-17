from pathlib import Path

p = Path('xkiro-ai-studio/app/src/main/java/ai/xkiro/studio/MainActivity.kt')
s = p.read_text()

def one(old, new):
    global s
    if old not in s:
        raise SystemExit('missing marker: ' + old[:100])
    s = s.replace(old, new, 1)

# Diana branding without replacing the working v0.2.9 runtime.
s = s.replace('xKiro-Work-${System.currentTimeMillis()}.zip', 'Diana-Work-${System.currentTimeMillis()}.zip')
s = s.replace('Configure OpenRouter ou xKiro primeiro.', 'Configure OpenRouter ou Diana primeiro.')
s = s.replace('Ative o Shizuku e volte para autorizar o xKiro.', 'Ative o Shizuku e volte para autorizar a Diana.')
s = s.replace('Depois disso o xKiro poderá usar a integração oficial RUN_COMMAND sem depender de colar comandos grandes.', 'Depois disso a Diana poderá usar a integração oficial RUN_COMMAND sem depender de colar comandos grandes.')
s = s.replace('Configure OpenRouter ou xKiro.', 'Configure OpenRouter ou Diana.')
s = s.replace('Configure sua OpenRouter API key ou xKiro.', 'Configure sua OpenRouter API key ou Diana.')
s = s.replace('A voz do ElevenLabs está funcionando no xKiro.', 'A voz do ElevenLabs está funcionando na Diana.')
s = s.replace('Configure OpenRouter ou xKiro antes da voz.', 'Configure OpenRouter ou Diana antes da voz.')
s = s.replace('Você é o assistente principal xKiro.', 'Você é a assistente principal Diana.')
s = s.replace('"xKiro: ${r.totalCatalog} no catálogo', '"Diana: ${r.totalCatalog} no catálogo')

one('wake.setText(s.wakeWord)', 'wake.setText(if (s.wakeWord == "Orizon") "Diana" else s.wakeWord)')
one('wakeWord = wake.text.toString().trim().ifBlank { "Orizon" }', 'wakeWord = wake.text.toString().trim().ifBlank { "Diana" }')

# New visual controls from the Diana mockup.
one(
'''        findViewById<Button>(R.id.stopEverything).setOnClickListener { interruptCurrentTask(true) }
''',
'''        findViewById<Button>(R.id.stopEverything).setOnClickListener { interruptCurrentTask(true) }
        findViewById<Button>(R.id.settingsButton).setOnClickListener {
            val panel = findViewById<View>(R.id.settingsPanel)
            panel.visibility = if (panel.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        }
        findViewById<Button>(R.id.historyButton).setOnClickListener { toast("Histórico da Diana entra na próxima etapa.") }
        findViewById<Button>(R.id.viewExecution).setOnClickListener {
            if (ScreenCaptureService.isStreaming()) testScreenVision() else startFullScreenVision()
        }
        findViewById<Button>(R.id.modeChat).setOnClickListener { toast("Modo Chat") }
        findViewById<Button>(R.id.modeWork).setOnClickListener {
            val text = prompt.text.toString().trim()
            if (text.isBlank()) toast("Escreva o que o Work deve criar.") else runWork(text)
        }
        findViewById<Button>(R.id.modeDevice).setOnClickListener {
            if (ScreenCaptureService.isStreaming()) toast("Aparelho pronto para controle visual.") else startFullScreenVision()
        }
''')

one(
'''    private fun updateShizukuStatus() {
        if (ShizukuBridge.hasPermission()) ShizukuBridge.connectUserService()
        shizukuStatus.text = "Shizuku: ${ShizukuBridge.statusText()}"
    }
''',
'''    private fun updateShizukuStatus() {
        val connected = ShizukuBridge.hasPermission()
        if (connected) ShizukuBridge.connectUserService()
        shizukuStatus.text = if (connected) "conectado" else ShizukuBridge.statusText().take(18)
        shizukuStatus.setTextColor(ContextCompat.getColor(this, if (connected) R.color.success else R.color.muted))
    }
''')

one(
'''    private fun updateAccessibilityStatus() {
        val enabled = StudioAccessibilityService.isEnabled(this)
        val connected = StudioAccessibilityService.instance != null
        accessibilityStatus.text = "Acessibilidade: " + when {
            connected -> "ativa e conectada"
            enabled -> "ativa • aguardando/reconectando serviço"
            else -> "desativada"
        }
        findViewById<Button>(R.id.openAccessibility).text = if (enabled)
            "Acessibilidade ativa • abrir configurações"
        else "Ativar Device Agent (Acessibilidade)"
    }
''',
'''    private fun updateAccessibilityStatus() {
        val enabled = StudioAccessibilityService.isEnabled(this)
        val connected = StudioAccessibilityService.instance != null
        accessibilityStatus.text = when {
            connected -> "conectado"
            enabled -> "reconectando"
            else -> "desligado"
        }
        accessibilityStatus.setTextColor(ContextCompat.getColor(this, if (connected) R.color.success else R.color.muted))
        findViewById<Button>(R.id.openAccessibility).text = "›"
    }
''')

one(
'''    private fun updateScreenVisionButton(){
        if(!::runtimeStatus.isInitialized) return
        findViewById<Button>(R.id.shareScreen).text=when{
            ScreenCaptureService.isStreaming()->"Screen Vision ativo • quadro #${ScreenCaptureService.frameCount}"
            ScreenCaptureService.active->"Screen Vision autorizado • aguardando vídeo"
            else->"Compartilhar tela inteira com os agentes"
        }
    }
''',
'''    private fun updateScreenVisionButton(){
        if(!::runtimeStatus.isInitialized) return
        val streaming = ScreenCaptureService.isStreaming()
        findViewById<Button>(R.id.shareScreen).text = "›"
        findViewById<TextView>(R.id.screenVisionStatus).text = when {
            streaming -> "Screen Vision • frame #${ScreenCaptureService.frameCount} • ao vivo"
            ScreenCaptureService.active -> "Screen Vision • autorizado • aguardando vídeo"
            else -> "Screen Vision • desligado"
        }
        findViewById<TextView>(R.id.screenVisionRowStatus).apply {
            text = when {
                streaming -> "ao vivo"
                ScreenCaptureService.active -> "aguardando"
                else -> "desligado"
            }
            setTextColor(ContextCompat.getColor(this@MainActivity, if (streaming) R.color.success else R.color.muted))
        }
        val access = StudioAccessibilityService.instance != null
        val shizuku = ShizukuBridge.hasPermission()
        findViewById<TextView>(R.id.deviceCount).text = "${listOf(access, shizuku, streaming).count { it }}/3 ativos"
    }
''')

p.write_text(s)
print('Applied safe Diana UI bindings on top of v0.2.9 runtime')
