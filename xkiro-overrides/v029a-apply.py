from pathlib import Path
r=Path('xkiro-ai-studio')

def rw(p,a,b):
 f=r/p;s=f.read_text()
 if a not in s: raise SystemExit('missing '+p)
 f.write_text(s.replace(a,b,1))

p='app/src/main/java/ai/xkiro/studio/device/StudioAccessibilityService.kt'
rw(p,'    private var cursorView: View? = null\n','    private var cursorView: View? = null\n    private var cursorParams: WindowManager.LayoutParams? = null\n\n    fun foregroundPackage(): String = rootInActiveWindow?.packageName?.toString().orEmpty()\n')
f=r/p;s=f.read_text();a=s.index('    fun showAgentCursor(x: Int, y: Int) {');b=s.index('\n    override fun onServiceConnected()',a)
repl='''    fun showAgentCursor(x: Int, y: Int) {\n        mainHandler.post {\n            val wm = getSystemService(WINDOW_SERVICE) as WindowManager\n            val size = (34 * resources.displayMetrics.density).toInt()\n            val old = cursorView; val lpOld = cursorParams\n            if (old != null && lpOld != null) {\n                lpOld.x = x - size / 2; lpOld.y = y - size / 2\n                runCatching { wm.updateViewLayout(old, lpOld) }; return@post\n            }\n            val v = View(this).apply { background = GradientDrawable().apply {\n                shape = GradientDrawable.OVAL; setColor(Color.argb(120,255,255,255))\n                setStroke((4 * resources.displayMetrics.density).toInt(), Color.rgb(255,70,70))\n            }}\n            val lp = WindowManager.LayoutParams(size,size,WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,\n                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, PixelFormat.TRANSLUCENT).apply {\n                gravity = Gravity.TOP or Gravity.START; this.x=x-size/2; this.y=y-size/2\n            }\n            runCatching { wm.addView(v,lp); cursorView=v; cursorParams=lp }\n        }\n    }\n\n    fun hideAgentCursor() {\n        mainHandler.post {\n            val wm=getSystemService(WINDOW_SERVICE) as WindowManager\n            cursorView?.let { runCatching { wm.removeView(it) } }\n            cursorView=null; cursorParams=null\n        }\n    }\n'''
f.write_text(s[:a]+repl+s[b:])
rw(p,'        cursorView = null\n        if (instance === this) instance = null\n','        cursorView = null\n        cursorParams = null\n        if (instance === this) instance = null\n')

p='app/src/main/java/ai/xkiro/studio/device/ScreenCaptureService.kt'
rw(p,'        fun healthText(): String {\n            if (!active) return "captura inativa"\n','        fun healthText(): String {\n            if (!active) return lastError?.let { "captura inativa: ${it.take(120)}" } ?: "captura inativa"\n')
rw(p,'            override fun onStop() {\n                active = false\n                stopSelf()\n            }\n','            override fun onStop() {\n                active = false\n                contentVisible = false\n                if (lastError == null) lastError = "MediaProjection encerrada; é necessária nova autorização"\n                stopSelf()\n            }\n')
