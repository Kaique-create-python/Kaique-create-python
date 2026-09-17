from pathlib import Path
root=Path('xkiro-ai-studio')

def rep(path,a,b,count=1):
    p=root/path
    s=p.read_text()
    if a not in s:
        raise SystemExit(f'missing marker {path}: {a[:120]!r}')
    p.write_text(s.replace(a,b,count))

def edit(path, fn):
    p=root/path
    s=p.read_text()
    n=fn(s)
    if n==s:
        raise SystemExit(f'no change {path}')
    p.write_text(n)

# --- ScreenCaptureService: Android 14/15-safe resize and real streaming health ---
p='app/src/main/java/ai/xkiro/studio/device/ScreenCaptureService.kt'
def cap(s):
    s=s.replace('''        private const val MIN_CAPTURE_INTERVAL_MS = 900L\n''','''        private const val MIN_CAPTURE_INTERVAL_MS = 900L\n        private const val STREAM_FRESH_MS = 3_500L\n''',1)
    s=s.replace('''        @Volatile var lastFrameAt: Long = 0L\n            private set\n''','''        @Volatile var lastFrameAt: Long = 0L\n            private set\n        @Volatile var frameCount: Long = 0L\n            private set\n        @Volatile var sessionStartedAt: Long = 0L\n            private set\n''',1)
    old='''        fun healthText(): String {\n            if (!active) return "captura inativa"\n            val age = if (lastFrameAt == 0L) Long.MAX_VALUE else System.currentTimeMillis() - lastFrameAt\n            return when {\n                lastError != null -> "captura com erro: ${lastError!!.take(100)}"\n                !contentVisible -> "conteúdo compartilhado não está visível"\n                age == Long.MAX_VALUE -> "captura ativa, aguardando primeiro quadro"\n                age > 5_000 -> "captura ativa, mas o último quadro tem ${age / 1000}s"\n                else -> "captura ativa • ${captureWidth}x${captureHeight} • quadro há ${age}ms"\n            }\n        }\n'''
    new='''        fun isStreaming(maxAgeMs: Long = STREAM_FRESH_MS): Boolean {\n            if (!active || lastFrameAt <= 0L || lastError != null) return false\n            return System.currentTimeMillis() - lastFrameAt <= maxAgeMs\n        }\n\n        fun healthText(): String {\n            if (!active) return "captura inativa"\n            val age = if (lastFrameAt == 0L) Long.MAX_VALUE else System.currentTimeMillis() - lastFrameAt\n            return when {\n                lastError != null -> "captura com erro: ${lastError!!.take(100)}"\n                age == Long.MAX_VALUE -> "captura autorizada, aguardando primeiro quadro"\n                age > 5_000 -> "captura autorizada, mas sem vídeo recente • último quadro há ${age / 1000}s"\n                else -> "transmitindo • ${captureWidth}x${captureHeight} • quadro há ${age}ms • #$frameCount"\n            }\n        }\n'''
    if old not in s: raise SystemExit('healthText marker missing')
    s=s.replace(old,new,1)
    s=s.replace('''            lastFrameAt = frame.capturedAt\n            captureWidth = frame.width\n''','''            lastFrameAt = frame.capturedAt\n            frameCount += 1L\n            captureWidth = frame.width\n''',1)
    s=s.replace('''        lastFrameAt = 0L\n        lastError = null\n''','''        lastFrameAt = 0L\n        frameCount = 0L\n        sessionStartedAt = 0L\n        lastError = null\n''',1)
    s=s.replace('''        recreateCapture(width, height)\n        active = true\n        return START_STICKY\n''','''        val started = recreateCapture(width, height)\n        active = started\n        sessionStartedAt = if (started) System.currentTimeMillis() else 0L\n        if (!started) {\n            stopSelf()\n            return START_NOT_STICKY\n        }\n        return START_STICKY\n''',1)
    start=s.find('    private fun recreateCapture(width: Int, height: Int) {')
    end=s.find('\n    private fun imageToCompressedFrame', start)
    if start<0 or end<0: raise SystemExit('recreateCapture block missing')
    replacement='''    /**\n     * Android 14+ allows one createVirtualDisplay() per MediaProjection session.\n     * Resize callbacks must reuse that VirtualDisplay and only swap the ImageReader surface.\n     */\n    private fun recreateCapture(width: Int, height: Int): Boolean {\n        val mp = projection ?: return false\n        var newReader: ImageReader? = null\n        return runCatching {\n            val w = width.coerceAtLeast(1)\n            val h = height.coerceAtLeast(1)\n            newReader = ImageReader.newInstance(w, h, PixelFormat.RGBA_8888, 3)\n            newReader!!.setOnImageAvailableListener({ ir ->\n                val image = runCatching { ir.acquireLatestImage() }.getOrNull() ?: return@setOnImageAvailableListener\n                try {\n                    val now = System.currentTimeMillis()\n                    if (now - lastStoredAt < MIN_CAPTURE_INTERVAL_MS) return@setOnImageAvailableListener\n                    imageToCompressedFrame(image, now)?.let {\n                        lastStoredAt = now\n                        pushFrame(it)\n                    }\n                } catch (t: Throwable) {\n                    lastError = t.message ?: t.javaClass.simpleName\n                } finally {\n                    image.close()\n                }\n            }, imageHandler)\n\n            val oldReader = reader\n            val vd = virtualDisplay\n            if (vd == null) {\n                virtualDisplay = mp.createVirtualDisplay(\n                    "xkiro-screen", w, h, density,\n                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,\n                    newReader!!.surface, null, imageHandler\n                ) ?: error("VirtualDisplay não foi criado")\n            } else {\n                vd.setSurface(newReader!!.surface)\n                vd.resize(w, h, density)\n            }\n            reader = newReader\n            newReader = null\n            oldReader?.setOnImageAvailableListener(null, null)\n            oldReader?.close()\n            captureWidth = w\n            captureHeight = h\n            lastError = null\n            true\n        }.getOrElse { t ->\n            newReader?.setOnImageAvailableListener(null, null)\n            newReader?.close()\n            lastError = t.message ?: "falha ao configurar captura"\n            false\n        }\n    }\n'''
    s=s[:start]+replacement+s[end:]
    return s
edit(p,cap)

# --- DeviceAgent: no direct URL/app shortcuts; require a real video frame ---
p='app/src/main/java/ai/xkiro/studio/device/DeviceAgentController.kt'
def dev(s):
    start=s.find('        // Open explicit normal web URLs deterministically')
    end=s.find('\n        if (isScreenLookCommand(lower))', start)
    if start<0 or end<0: raise SystemExit('direct URL block missing')
    s=s[:start]+'''        // Visual Computer Use owns navigation. Do not launch URLs/apps semantically here.\n'''+s[end:]
    start=s.find('        val explicitApp = extractRequestedApp(lower)')
    end=s.find('\n        return runScreenDrivenLoop', start)
    if start<0 or end<0: raise SystemExit('explicit app block missing')
    s=s[:start]+'''        // App launching is also performed visually (Home -> tap icon/search -> observe again).\n'''+s[end:]
    old='''        if (service == null && !ShizukuBridge.hasPermission())\n            return Result("Consigo ver a tela, mas preciso da Acessibilidade conectada ou do Shizuku autorizado para executar gestos.", false)\n        var acted = false\n'''
    new='''        if (service == null && !ShizukuBridge.hasPermission())\n            return Result("Consigo ver a tela, mas preciso da Acessibilidade conectada ou do Shizuku autorizado para executar gestos.", false)\n        if (!ScreenCaptureService.active)\n            return Result("Screen Vision não está autorizado. Toque em 'Compartilhar tela inteira' e confirme a captura.", false)\n        status("Validando transmissão do Screen Vision…")\n        val firstFrame = awaitFreshFrame(timeoutMs = 2_800L)\n        if (firstFrame == null)\n            return Result("Screen Vision foi autorizado, mas não está entregando vídeo. ${ScreenCaptureService.healthText()}. Reabra 'Compartilhar tela inteira' e autorize novamente.", false)\n        var acted = false\n'''
    if old not in s: raise SystemExit('run loop preflight marker missing')
    s=s.replace(old,new,1)
    old='''            if (frame != null) lastObservedFrameAt = frame.capturedAt\n            val cursorContext'''
    new='''            if (frame == null) {\n                return finish("Screen Vision perdeu o fluxo de vídeo durante a tarefa. ${ScreenCaptureService.healthText()}. Reautorize o compartilhamento da tela inteira.", acted)\n            }\n            lastObservedFrameAt = frame.capturedAt\n            val cursorContext'''
    if old not in s: raise SystemExit('frame null marker missing')
    s=s.replace(old,new,1)
    s=s.replace('''            } else {\n                return finish("Ative o Screen Vision para eu controlar por toque e gestos olhando a tela.", acted)\n            }''','''            } else {\n                return finish("Screen Vision sem quadro utilizável: ${ScreenCaptureService.healthText()}.", acted)\n            }''',1)
    old='''            val cursorContext = lastCursor?.let { "\\nCURSOR_XKIRO: último toque/gesto terminou aproximadamente em x=${it.first}, y=${it.second}. Use isso só como referência espacial; confirme pela tela atual." }.orEmpty()\n            val visualCommand = command + cursorContext + """'''
    new='''            val cursorContext = lastCursor?.let { "\\nCURSOR_XKIRO: último toque/gesto terminou aproximadamente em x=${it.first}, y=${it.second}. Use isso só como referência espacial; confirme pela tela atual." }.orEmpty()\n            val outcomeContext = lastMessage.takeIf { it.isNotBlank() }?.let { "\\nULTIMO_RESULTADO: ${it.take(280)}" }.orEmpty()\n            val visualCommand = command + cursorContext + outcomeContext + """'''
    if old not in s: raise SystemExit('visualCommand marker missing')
    s=s.replace(old,new,1)
    return s
edit(p,dev)

# --- MainActivity: restart MediaProjection cleanly and show actual frame health ---
p='app/src/main/java/ai/xkiro/studio/MainActivity.kt'
def main(s):
    old='''        if (result.resultCode == Activity.RESULT_OK && result.data != null) {\n            stopService(Intent(this, ScreenCaptureService::class.java))\n            val i = Intent(this, ScreenCaptureService::class.java)\n                .putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, result.resultCode)\n                .putExtra(ScreenCaptureService.EXTRA_DATA, result.data)\n            ContextCompat.startForegroundService(this, i)\n            runtimeStatus.text = "Iniciando visão da tela inteira…"\n            scope.launch {\n                delay(1200)\n                runtimeStatus.text = "Screen Vision: ${ScreenCaptureService.healthText()}"\n            }\n            toast("Screen Vision iniciado para a tela inteira.")\n        } else {\n'''
    new='''        if (result.resultCode == Activity.RESULT_OK && result.data != null) {\n            val permissionData = result.data!!\n            val resultCode = result.resultCode\n            runtimeStatus.text = "Reiniciando Screen Vision…"\n            scope.launch {\n                stopService(Intent(this@MainActivity, ScreenCaptureService::class.java))\n                val deadline = System.currentTimeMillis() + 1_500L\n                while (ScreenCaptureService.active && System.currentTimeMillis() < deadline) delay(80)\n                delay(120)\n                val i = Intent(this@MainActivity, ScreenCaptureService::class.java)\n                    .putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)\n                    .putExtra(ScreenCaptureService.EXTRA_DATA, permissionData)\n                ContextCompat.startForegroundService(this@MainActivity, i)\n                runtimeStatus.text = "Screen Vision: aguardando primeiro quadro…"\n                repeat(8) {\n                    delay(350)\n                    runtimeStatus.text = "Screen Vision: ${ScreenCaptureService.healthText()}"\n                    if (ScreenCaptureService.isStreaming()) return@repeat\n                }\n            }\n            toast("Permissão recebida. Validando os quadros do Screen Vision.")\n        } else {\n'''
    if old not in s: raise SystemExit('capturePermission marker missing')
    s=s.replace(old,new,1)
    return s
edit(p,main)

# --- OpenRouter vision planner: remove contradictory semantic shortcuts from the system prompt ---
p='app/src/main/java/ai/xkiro/studio/openrouter/OpenRouterOrchestrator.kt'
def orouter(s):
    s=s.replace('''            Você é o cérebro visual do xKiro Device Agent. Controle este Android como um humano olhando a tela. Depois que a tela/alvo já estiver aberto, NÃO use atalhos semânticos como open_url/open_app para continuar a tarefa. Prefira exclusivamente ações físicas: tap por coordenadas, swipe, type/set_text/paste quando um campo estiver focado e teclas Android. Execute somente a próxima ação necessária e depois observe um frame novo. Nunca repita abertura de URL/app quando a tela atual já permite continuar.\n''','''            Você é o cérebro visual do xKiro Device Agent. Controle este Android como um humano olhando a tela. Não existem atalhos semânticos para abrir URL/app nem para clicar por texto/ID. Navegue fisicamente com Home/Back, taps, swipes, digitação e teclas Android. Execute exatamente UMA ação física e depois observe um frame novo antes de decidir a próxima.\n''',1)
    s=s.replace('''            Ações permitidas: open_app, open_url, click_text, click_id, set_text, type_text, append_text, clear_text, paste, enter, press_key, back, home, recents, notifications, quick_settings, scroll, tap, double_tap, multi_tap, long_press, swipe, swipe_direction, drag, pinch_in, pinch_out, select_all, copy, cut, wait_for_text, wait, finish, need_confirmation, screenshot.\n''','''            Ações permitidas: tap, double_tap, long_press, swipe, swipe_direction, drag, type_text, paste, enter, press_key, back, home, recents, wait, finish, need_confirmation.\n''',1)
    s=s.replace('''            Prefira click_text/click_id quando o alvo existir claramente na árvore; se ID/texto falhar ou a árvore não expuser o elemento, use tap por coordenadas da screenshot.\n''','''            Use a árvore de acessibilidade apenas como contexto para entender a tela; a interação deve acontecer pelas ações físicas permitidas acima.\n''',1)
    s=s.replace('''            Faça no máximo 2 ações que mudam a tela antes de pedir nova observação. Prefira type_text/set_text a digitação por tecla.\n''','''            Faça somente 1 ação por quadro. Para texto, primeiro toque visualmente no campo e depois use type_text ou paste.\n''',1)
    return s
edit(p,orouter)

# --- xKiro fallback planner: same physical-only contract ---
p='app/src/main/java/ai/xkiro/studio/core/AgentOrchestrator.kt'
def aorch(s):
    s=s.replace('''            Ações: open_app, click_text, click_id, set_text, append_text, clear_text, paste, enter, back, home, recents, notifications, quick_settings, scroll, tap, double_tap, long_press, swipe, swipe_direction, drag, pinch_in, pinch_out, select_all, copy, cut, wait, finish, need_confirmation, screenshot.\n''','''            Ações: tap, double_tap, long_press, swipe, swipe_direction, drag, type_text, paste, enter, press_key, back, home, recents, wait, finish, need_confirmation.\n''',1)
    s=s.replace('''            Prefira click_text/click_id à coordenada. Use screenshot quando precisar olhar novamente antes de decidir.\n''','''            Interaja como uma pessoa: toque por coordenadas, deslize, digite e use teclas Android. Nunca abra URL/app por atalho e nunca clique por texto/ID. Faça uma ação e reobserve a tela.\n''',1)
    return s
edit(p,aorch)

# version bump
p='app/build.gradle.kts'
def ver(s):
    if 'versionCode = 18' not in s or 'versionName = "0.2.7"' not in s:
        raise SystemExit('version markers missing')
    return s.replace('versionCode = 18','versionCode = 19',1).replace('versionName = "0.2.7"','versionName = "0.2.8"',1)
edit(p,ver)

print('Applied v0.2.8: Android 14/15 Screen Vision fix + strict physical Computer Use')
