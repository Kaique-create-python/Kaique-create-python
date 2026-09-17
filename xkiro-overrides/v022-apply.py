from pathlib import Path

root=Path('xkiro-ai-studio')

p=root/'app/src/main/java/ai/xkiro/studio/openrouter/OpenRouterOrchestrator.kt'
s=p.read_text()
old='''    private fun textModels(all: List<OpenRouterModel>) = all
        .filter { it.textOutput && "text" in it.inputModalities }
        .filter(::pricedOrFree)'''
new='''    private fun isInteractive(m: OpenRouterModel): Boolean {
        val s = (m.id + " " + m.name).lowercase()
        return !listOf(":batch", "batch-only", "batch only").any { it in s }
    }

    private fun textModels(all: List<OpenRouterModel>) = all
        .filter { it.textOutput && "text" in it.inputModalities }
        .filter(::pricedOrFree)
        .filter(::isInteractive)'''
if old not in s: raise SystemExit('textModels patch target missing')
s=s.replace(old,new)
old='''        return all.filter { it.vision && it.textOutput }
            .filter(::pricedOrFree)'''
new='''        return all.filter { it.vision && it.textOutput }
            .filter(::pricedOrFree)
            .filter(::isInteractive)'''
if old not in s: raise SystemExit('vision patch target missing')
s=s.replace(old,new)
p.write_text(s)

p=root/'app/src/main/java/ai/xkiro/studio/device/DeviceAgentController.kt'
s=p.read_text()
needle='''        val lower = command.lowercase(Locale.ROOT)
        DoctorEngine.diagnoseAndRecover(context, settings, deep = false)
        val service = awaitAccessibility(context, 900L)
'''
repl='''        val lower = command.lowercase(Locale.ROOT)
        DoctorEngine.diagnoseAndRecover(context, settings, deep = false)
        val service = awaitAccessibility(context, 900L)

        // Open explicit normal web URLs deterministically instead of letting a chat model refuse browsing.
        val url = Regex("""https?://[^\\s\\]\\)\\}>,]+""", RegexOption.IGNORE_CASE).find(command)?.value
        if (url != null && listOf("abre", "abra", "entra", "entre", "acessa", "acesse", "site", "link").any { it in lower }) {
            val uri = runCatching { Uri.parse(url) }.getOrNull()
            if (uri != null && uri.scheme in setOf("http", "https")) {
                status("Abrindo link no celular…")
                context.startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                delay(650)
                val onlyOpen = command.replace(url, "").trim().length < 35
                if (onlyOpen) return Result("Link aberto.", true)
            }
        }
'''
if needle not in s: raise SystemExit('device execute patch target missing')
s=s.replace(needle,repl)
s=s.replace('''            "click_id" -> service?.clickId(a.optString("target")) ?: false''','''            "click_id" -> {
                val target = a.optString("target")
                (service?.clickId(target) == true) || (service?.clickText(target.substringAfterLast('/').replace('_', ' ')) == true)
            }''')
p.write_text(s)

p=root/'app/build.gradle.kts'
s=p.read_text().replace('versionCode = 12','versionCode = 13').replace('versionName = "0.2.1"','versionName = "0.2.2"')
p.write_text(s)
print('Applied v0.2.2: interactive model filter, direct URL routing, click fallback, version bump')
