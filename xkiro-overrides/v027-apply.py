from pathlib import Path
root=Path('xkiro-ai-studio')
def rep(path,a,b):
 p=root/path; s=p.read_text()
 if a not in s: raise SystemExit(f'missing marker {path}: {a[:90]}')
 p.write_text(s.replace(a,b,1))

p='app/src/main/java/ai/xkiro/studio/device/DeviceAgentController.kt'
f=root/p; s=f.read_text()
# Cursor exists from the beginning of a running task, not only after the first tap.
s=s.replace('''            if (service == null) service = awaitAccessibility(context, 120L)\n            val snapshot''','''            if (service == null) service = awaitAccessibility(context, 120L)\n            if (round == 1) service?.showAgentCursor(resourcesCenterX(context), resourcesCenterY(context))\n            val snapshot''')
# Give vision a strict computer-use contract.
s=s.replace('''            val visualCommand = command + cursorContext''','''            val visualCommand = command + cursorContext + """\nMODO COMPUTER USE ESTRITO: controle a tela como uma pessoa. Você NÃO possui open_url/open_app/click_text/click_id/set_text nem atalhos semânticos. Só pode usar tap, double_tap, long_press, swipe, drag, type_text, paste, enter, press_key, back, home, recents, wait, finish e need_confirmation. Para abrir site/app, navegue visualmente e digite/toque na interface. Escolha UMA ação física por frame e observe o frame seguinte antes de continuar.\n"""''')
# Strict allowlist at executor boundary: even a hallucinated semantic shortcut cannot run.
s=s.replace('''                val type = a.optString("action", "finish")\n                if (type == "finish")''','''                val type = a.optString("action", "finish")\n                val physical = setOf("tap","double_tap","long_press","swipe","swipe_direction","drag","type_text","paste","enter","press_key","back","home","recents","wait","finish","need_confirmation")\n                if (type !in physical) {\n                    lastMessage = "Atalho '$type' rejeitado pelo Computer Use; reobservando para usar toque/gesto."\n                    status("Atalho bloqueado • replanejando visualmente…")\n                    break\n                }\n                if (type == "finish")''')
# One physical action per fresh visual frame.
s=s.replace('''            for (i in 0 until minOf(actions.length(), 6)) {''','''            for (i in 0 until minOf(actions.length(), if (frame != null) 1 else 1)) {''')
# No accessibility-only semantic planner: require screen sharing for computer use.
s=s.replace('''            } else {\n                planBatch(context, settings, command, snapshot, round - 1)\n            }''','''            } else {\n                return finish("Ative o Screen Vision para eu controlar por toque e gestos olhando a tela.", acted)\n            }''')
# Helper for initial persistent cursor.
insert='''\n    private fun resourcesCenterX(context: Context): Int = context.resources.displayMetrics.widthPixels / 2\n    private fun resourcesCenterY(context: Context): Int = context.resources.displayMetrics.heightPixels / 2\n\n'''
pos=s.find('    private suspend fun describeAccessibilityFallback')
if pos < 0: raise SystemExit('helper insertion marker missing')
s=s[:pos]+insert+s[pos:]
f.write_text(s)

# Cursor: bigger/high-contrast and persistent.
p='app/src/main/java/ai/xkiro/studio/device/StudioAccessibilityService.kt'
f=root/p; s=f.read_text()
s=s.replace('val size = (26 * resources.displayMetrics.density).toInt()','val size = (34 * resources.displayMetrics.density).toInt()')
s=s.replace('val ring = (3 * resources.displayMetrics.density).toInt()','val ring = (4 * resources.displayMetrics.density).toInt()')
s=s.replace('setColor(Color.argb(70, 255, 255, 255))','setColor(Color.argb(120, 255, 255, 255))')
f.write_text(s)

p='app/build.gradle.kts'
rep(p,'versionCode = 17','versionCode = 18')
rep(p,'versionName = "0.2.6"','versionName = "0.2.7"')
