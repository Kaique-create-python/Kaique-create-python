package ai.xkiro.studio.device

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import ai.xkiro.studio.core.AgentOrchestrator
import ai.xkiro.studio.core.XKiroClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.Base64
import java.util.Locale

object DeviceAgentController {
    data class Result(val message: String, val actedOnDevice: Boolean)

    fun looksLikeDeviceCommand(text: String): Boolean {
        val t = text.lowercase(Locale.ROOT)
        val deviceWords = listOf(
            "abra ", "abre ", "abrir ", "entre no", "entra no", "vá para", "vai para",
            "no meu celular", "no meu cll", "meu celular", "mexer no celular", "mexa no",
            "termux", "whatsapp", "youtube", "configurações", "configuracoes", "chrome",
            "digite ", "toque em", "clique em"
        )
        return deviceWords.any { it in t }
    }

    suspend fun execute(context: Context, apiKey: String, command: String, status: (String) -> Unit): Result {
        status("Device Agent: interpretando comando escrito…")
        val lower = command.lowercase(Locale.ROOT)
        if ("termux" in lower) return executeTermux(context, apiKey, command, status)

        if (StudioAccessibilityService.instance == null) {
            return Result("Ative o Device Agent em Acessibilidade para eu poder executar comandos escritos no celular.", false)
        }

        val explicitApp = extractRequestedApp(lower)
        if (explicitApp != null && containsOpenVerb(lower)) {
            val packageName = findLaunchablePackage(context, explicitApp)
            if (packageName != null) {
                status("Device Agent: abrindo $explicitApp…")
                openPackage(context, packageName)
                delay(700)
                val remainderSignals = listOf(" e ", " depois ", "pesquise", "digite", "toque", "clique", "faça", "faca")
                if (remainderSignals.none { it in lower }) return Result("$explicitApp aberto pelo Device Agent.", true)
            }
        }

        return runScreenDrivenLoop(context, apiKey, command, status)
    }

    private suspend fun runScreenDrivenLoop(
        context: Context,
        apiKey: String,
        command: String,
        status: (String) -> Unit
    ): Result {
        val service = StudioAccessibilityService.instance ?: return Result("Device Agent de Acessibilidade não está ativo.", false)
        var acted = false
        var lastNote = ""

        repeat(8) { step ->
            val snapshot = service.snapshot(180)
            status("Device Agent: analisando tela • passo ${step + 1}/8…")
            val plan = planDeviceStep(apiKey, command, snapshot, step)
            val action = plan.optString("action", "finish")
            val target = plan.optString("target")
            val text = plan.optString("text")
            lastNote = plan.optString("reason")

            when (action) {
                "open_app" -> {
                    val appName = plan.optString("app", target)
                    val pkg = findLaunchablePackage(context, appName)
                        ?: return Result("Não encontrei o app '$appName' instalado/visível para abrir.", acted)
                    openPackage(context, pkg)
                    acted = true
                    delay(700)
                }
                "click_text" -> {
                    if (target.isBlank() || !service.clickText(target)) return Result("Não consegui localizar/tocar no texto '$target' nesta tela.", acted)
                    acted = true
                    delay(550)
                }
                "set_text" -> {
                    if (!service.setFocusedText(text)) return Result("Não encontrei um campo de texto editável nesta tela.", acted)
                    acted = true
                    delay(350)
                }
                "enter" -> {
                    if (!ShizukuBridge.binderAlive || !ShizukuBridge.hasPermission()) {
                        return Result("Para confirmar Enter em outros apps, autorize o Shizuku para o xKiro AI Studio.", acted)
                    }
                    ShizukuBridge.keyEvent(66).getOrElse { return Result("Falha ao enviar Enter: ${it.message}", acted) }
                    acted = true
                    delay(500)
                }
                "back" -> { service.back(); acted = true; delay(400) }
                "home" -> { service.home(); acted = true; delay(400) }
                "scroll" -> {
                    if (!service.scrollForward()) return Result("Não encontrei uma área rolável nesta tela.", acted)
                    acted = true
                    delay(450)
                }
                "wait" -> delay(plan.optLong("ms", 700L).coerceIn(200L, 2500L))
                "finish" -> return Result(plan.optString("message").ifBlank { lastNote.ifBlank { "Comando concluído pelo Device Agent." } }, acted)
                "need_confirmation" -> return Result(plan.optString("message").ifBlank { "A próxima ação é externa ou sensível e precisa da sua confirmação." }, acted)
                else -> return Result("O planejador pediu uma ação ainda não suportada: $action", acted)
            }
        }
        return Result(lastNote.ifBlank { "Cheguei ao limite de passos do Device Agent; revise a tela e mande continuar se necessário." }, acted)
    }

    private suspend fun executeTermux(context: Context, apiKey: String, request: String, status: (String) -> Unit): Result {
        if (!ShizukuBridge.binderAlive) return Result("Shizuku não está conectado. Abra o Shizuku e deixe o serviço ativo, depois tente novamente.", false)
        if (!ShizukuBridge.hasPermission()) {
            ShizukuBridge.requestPermission()
            return Result("Autorize o xKiro AI Studio na janela do Shizuku e envie o comando novamente.", false)
        }
        if (StudioAccessibilityService.instance == null) {
            return Result("Ative o Device Agent em Acessibilidade no app antes de mandar ações escritas para o Termux.", false)
        }

        status("Device Agent: pedindo à equipe um script pequeno e executável…")
        val python = buildPythonForRequest(apiKey, request)
        val encoded = Base64.getEncoder().encodeToString(python.toByteArray(Charsets.UTF_8))
        val fileName = "xkiro_simple_ai.py"
        val terminalCommand = "echo $encoded | base64 -d > ~/$fileName && python ~/$fileName"

        status("Device Agent: abrindo Termux…")
        openPackage(context, "com.termux")
        delay(850)

        val clipboard = context.getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newPlainText("xKiro command", terminalCommand))

        status("Device Agent: colando o programa no terminal…")
        ShizukuBridge.keyEvent(279).getOrElse {
            return Result("Consegui abrir o Termux, mas não consegui colar pelo Shizuku: ${it.message}", true)
        }
        delay(250)
        ShizukuBridge.keyEvent(66).getOrElse {
            return Result("O código foi colado no Termux, mas não consegui confirmar Enter: ${it.message}", true)
        }

        delay(1200)
        val snapshot = StudioAccessibilityService.instance?.snapshot(100).orEmpty()
        status("Device Agent: comando enviado ao Termux e tela verificada.")
        return Result(
            buildString {
                append("Termux aberto e ~/xkiro_simple_ai.py foi criado/executado. ")
                if (snapshot.isNotBlank() && snapshot != "(sem árvore de acessibilidade)") {
                    append("O Device Agent também conseguiu ler o estado atual da interface.")
                } else {
                    append("O terminal recebeu o comando; esta versão do Termux não expôs texto suficiente pela árvore de acessibilidade para validar a saída linha por linha.")
                }
            },
            true
        )
    }

    private suspend fun buildPythonForRequest(apiKey: String, request: String): String {
        val results = AgentOrchestrator.runSwarm(
            apiKey,
            "Crie SOMENTE o conteúdo de um único arquivo Python pequeno para este pedido: $request. Regras: sem markdown, sem crases, sem dependências externas, deve rodar em terminal Android/Termux com Python padrão. Se o pedido disser IA simples, faça um chatbot simples por regras/entrada de texto e explique pelo próprio programa como sair.",
            3
        )
        val synthesis = AgentOrchestrator.synthesize(apiKey, "Retorne SOMENTE código Python válido, sem markdown, para: $request", results)
        return cleanCode(synthesis).ifBlank {
            "print('xKiro AI simples pronta. Digite sair para encerrar.')\n" +
            "while True:\n" +
            "    msg = input('Você: ').strip().lower()\n" +
            "    if msg in {'sair','exit','quit'}: break\n" +
            "    print('IA:', 'Olá! Como posso ajudar?' if 'oi' in msg else 'Você disse: ' + msg)\n"
        }
    }

    private fun cleanCode(raw: String): String {
        var s = raw.trim()
        if (s.startsWith("```")) s = s.substringAfter('\n').substringBeforeLast("```").trim()
        return s
    }

    private suspend fun planDeviceStep(apiKey: String, request: String, snapshot: String, step: Int): JSONObject = withContext(Dispatchers.IO) {
        val model = AgentOrchestrator.accessReport(apiKey, 1).verifiedUsable.firstOrNull()
            ?: error("Nenhum modelo xKiro utilizável para interpretar o comando.")
        val raw = XKiroClient.chat(
            apiKey,
            model.id,
            """
                Você é o planejador do Device Agent Android. Retorne SOMENTE um objeto JSON, sem markdown.
                Execute apenas UMA ação por resposta.
                Ações permitidas: open_app, click_text, set_text, enter, back, home, scroll, wait, finish, need_confirmation.
                Campos possíveis: action, app, target, text, ms, message, reason.
                Use a árvore real da tela; nunca diga que clicou ou digitou se não houver ação correspondente.
                Antes de compras, envio de mensagens, exclusão de dados, instalação de software, mudança de conta/senha/permissões ou outra ação externa irreversível, use need_confirmation.
                Se a tarefa já estiver concluída, use finish.
            """.trimIndent(),
            "PEDIDO ORIGINAL: $request\nPASSO: $step\nTELA ATUAL:\n${snapshot.take(12000)}",
            260,
            0.0
        )
        parseJsonObject(raw)
    }

    private fun parseJsonObject(raw: String): JSONObject {
        val start = raw.indexOf('{')
        val end = raw.lastIndexOf('}')
        if (start < 0 || end <= start) return JSONObject().put("action", "finish").put("message", raw.take(300))
        return runCatching { JSONObject(raw.substring(start, end + 1)) }
            .getOrElse { JSONObject().put("action", "finish").put("message", "Não consegui interpretar o plano da IA.") }
    }

    private fun containsOpenVerb(text: String): Boolean =
        listOf("abra ", "abre ", "abrir ", "entre no", "entra no", "vá para", "vai para").any { it in text }

    private fun extractRequestedApp(text: String): String? {
        val aliases = listOf("termux", "whatsapp", "youtube", "chrome", "configurações", "configuracoes")
        return aliases.firstOrNull { it in text }
    }

    private fun findLaunchablePackage(context: Context, appName: String): String? {
        val normalized = appName.lowercase(Locale.ROOT).trim()
        val known = when {
            "termux" in normalized -> "com.termux"
            "whatsapp" in normalized -> "com.whatsapp"
            "youtube" in normalized -> "com.google.android.youtube"
            "chrome" in normalized -> "com.android.chrome"
            "configura" in normalized -> "com.android.settings"
            else -> null
        }
        if (known != null && context.packageManager.getLaunchIntentForPackage(known) != null) return known

        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val candidates = context.packageManager.queryIntentActivities(launcher, 0)
        return candidates.firstOrNull { info ->
            val label = info.loadLabel(context.packageManager)?.toString()?.lowercase(Locale.ROOT).orEmpty()
            label == normalized || label.contains(normalized) || normalized.contains(label)
        }?.activityInfo?.packageName
    }

    private fun openPackage(context: Context, packageName: String) {
        val pm = context.packageManager
        val launch = pm.getLaunchIntentForPackage(packageName)
            ?: Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                setPackage(packageName)
            }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(launch)
    }
}
