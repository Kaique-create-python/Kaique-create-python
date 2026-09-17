from pathlib import Path
root=Path('xkiro-ai-studio')

def edit(path, fn):
 p=root/path; s=p.read_text(); n=fn(s)
 if n==s: raise SystemExit('no change '+path)
 p.write_text(n)

# Screen capture: expose health/freshness and explicit fresh-frame waiting.
p='app/src/main/java/ai/xkiro/studio/device/ScreenCaptureService.kt'
def cap(s):
 marker='companion object {'
 if marker not in s: raise SystemExit('ScreenCapture companion missing')
 s=s.replace(marker, marker+'''\n        @Volatile var lastFrameAt: Long = 0L\n            private set\n        fun frameAgeMs(): Long = if (lastFrameAt <= 0L) Long.MAX_VALUE else System.currentTimeMillis() - lastFrameAt\n        fun isStreaming(): Boolean = frameAgeMs() < 3000L\n''',1)
 # Update timestamp whenever a captured frame is published. Handle common assignments.
 for old in ['latestFrame = frame','latestFrame = jpeg','latestFrame = bytes']:
  if old in s:
   s=s.replace(old, old+'\n                lastFrameAt = System.currentTimeMillis()',1)
   break
 else:
  # fallback: timestamp at successful history append if implementation names differ
  if 'frames.add' in s: s=s.replace('frames.add', 'lastFrameAt = System.currentTimeMillis()\n                frames.add',1)
  else: raise SystemExit('frame publish marker missing')
 return s
edit(p,cap)

# Device executor: don't trust merely non-null old frame. Wait for a genuinely fresh capture.
p='app/src/main/java/ai/xkiro/studio/device/DeviceAgentController.kt'
def dev(s):
 old='val frame = ScreenCaptureService.latestFrame()'
 if old not in s: raise SystemExit('latestFrame call missing')
 new='''val frame = awaitFreshVisionFrame(2500L)\n            if (frame == null) {\n                return finish("Screen Vision sem frames recentes. Toque em Screen Vision e autorize o compartilhamento da tela novamente.", acted)\n            }'''
 s=s.replace(old,new,1)
 # If this call occurs each loop, fresh wait is enough; add helper before existing helper.
 marker='    private fun resourcesCenterX(context: Context): Int'
 helper='''    private suspend fun awaitFreshVisionFrame(timeoutMs: Long): ByteArray? {\n        val start = System.currentTimeMillis()\n        var frame = ScreenCaptureService.latestFrame()\n        while ((frame == null || !ScreenCaptureService.isStreaming()) && System.currentTimeMillis() - start < timeoutMs) {\n            kotlinx.coroutines.delay(100L)\n            frame = ScreenCaptureService.latestFrame()\n        }\n        return if (frame != null && ScreenCaptureService.isStreaming()) frame else null\n    }\n\n'''
 if marker not in s: raise SystemExit('cursor helper missing')
 s=s.replace(marker,helper+marker,1)
 return s
edit(p,dev)

# Version bump.
p='app/build.gradle.kts'
def ver(s):
 if 'versionCode = 18' not in s or 'versionName = "0.2.7"' not in s: raise SystemExit('version markers missing')
 return s.replace('versionCode = 18','versionCode = 19',1).replace('versionName = "0.2.7"','versionName = "0.2.8"',1)
edit(p,ver)
