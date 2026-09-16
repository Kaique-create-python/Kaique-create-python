package ai.xkiro.studio

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.provider.Settings
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import ai.xkiro.studio.core.*
import ai.xkiro.studio.device.ScreenCaptureService
import ai.xkiro.studio.device.ShizukuBridge
import ai.xkiro.studio.device.DeviceAgentController
import ai.xkiro.studio.voice.VoiceAssistantService
import kotlinx.coroutines.*

class MainActivity : AppCompatActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var store: SettingsStore
    private lateinit var out: TextView
    private lateinit var modelsText: TextView
    private lateinit var xKey: EditText
    private lateinit var vKey: EditText
    private lateinit var vId: EditText
    private lateinit var wake: EditText
    private lateinit var prompt: EditText

    private val micPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) startVoiceService() else toast("Microfone não autorizado.")
    }

    private val capturePermission = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) {
            val i = Intent(this, ScreenCaptureService::class.java)
                .putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, result.resultCode)
                .putExtra(ScreenCaptureService.EXTRA_DATA, result.data)
            ContextCompat.startForegroundService(this, i)
            toast("Screen Agent ativo.")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        store = SettingsStore(this)
        bind()
        loadSettings()

        findViewById<Button>(R.id.saveSettings).setOnClickListener { saveSettings() }
        findViewById<Button>(R.id.refreshModels).setOnClickListener { refreshModels() }
        findViewById<Button>(R.id.swarmDemo).setOnClickListener { runPrompt("Faça uma revisão rápida da arquitetura deste AI Studio e proponha 3 melhorias.", 7) }
        findViewById<Button>(R.id.sendPrompt).setOnClickListener { runTypedPrompt(prompt.text.toString()) }
        findViewById<Button>(R.id.openAccessibility).setOnClickListener {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
        findViewById<Button>(R.id.startVoice).setOnClickListener {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) startVoiceService()
            else micPermission.launch(Manifest.permission.RECORD_AUDIO)
        }
        findViewById<Button>(R.id.shareScreen).setOnClickListener {
            val mgr = getSystemService(MediaProjectionManager::class.java)
            capturePermission.launch(mgr.createScreenCaptureIntent())
        }
    }

    private fun bind() {
        out = findViewById(R.id.output)
        modelsText = findViewById(R.id.modelsText)
        xKey = findViewById(R.id.xkiroKey)
        vKey = findViewById(R.id.voiceKey)
        vId = findViewById(R.id.voiceId)
        wake = findViewById(R.id.wakeWord)
        prompt = findViewById(R.id.prompt)
    }

    private fun loadSettings() {
        val s = store.load()
        xKey.setText(s.xkiroKey)
        vKey.setText(s.voiceKey)
        vId.setText(s.voiceId)
        wake.setText(s.wakeWord)
    }

    private fun saveSettings() {
        store.save(StudioSettings(xKey.text.toString(), vKey.text.toString(), vId.text.toString(), wake.text.toString()))
        if (ShizukuBridge.binderAlive && !ShizukuBridge.hasPermission()) ShizukuBridge.requestPermission()
        toast("Configurações salvas localmente.")
    }

    private fun refreshModels() {
        val key = xKey.text.toString().trim()
        if (key.isBlank()) return toast("Coloque sua chave xKiro.")
        modelsText.text = "Consultando catálogo e verificando acesso real..."
        scope.launch {
            val report = runCatching { AgentOrchestrator.accessReport(key, 7) }
            modelsText.text = report.fold(
                onSuccess = {
                    val names = it.verifiedUsable.take(5).joinToString { m -> m.id }
                    "${it.totalCatalog} no catálogo • ${it.verifiedUsable.size} verificados agora • ${it.blockedInProbe} recusados nesta varredura\n$names"
                },
                onFailure = { "Erro: ${it.message}" }
            )
        }
    }

    private fun runTypedPrompt(text: String) {
        if (text.isBlank()) return toast("Digite uma tarefa.")
        val key = xKey.text.toString().trim()
        if (key.isBlank()) return toast("Coloque sua chave xKiro.")

        if (DeviceAgentController.looksLikeDeviceCommand(text)) {
            out.text = "Device Agent: preparando ação escrita…"
            scope.launch {
                runCatching {
                    DeviceAgentController.execute(this@MainActivity, key, text) { status ->
                        runOnUiThread { out.text = status }
                    }
                }.onSuccess { result ->
                    out.text = result.message
                }.onFailure {
                    out.text = "Falha do Device Agent: ${it.message}"
                }
            }
        } else {
            runPrompt(text, 7)
        }
    }

    private fun runPrompt(text: String, agents: Int) {
        if (text.isBlank()) return toast("Digite uma tarefa.")
        val key = xKey.text.toString().trim()
        if (key.isBlank()) return toast("Coloque sua chave xKiro.")
        out.text = "Orchestrator: distribuindo tarefa...\n"
        scope.launch {
            runCatching {
                val results = AgentOrchestrator.runSwarm(key, text, agents)
                out.text = results.joinToString("\n") { "✓ ${it.role} • ${it.model}" } + "\n\nIntegrator trabalhando..."
                AgentOrchestrator.synthesize(key, text, results)
            }.onSuccess { out.text = it }
             .onFailure { out.text = "Falha: ${it.message}" }
        }
    }

    private fun startVoiceService() {
        saveSettings()
        ContextCompat.startForegroundService(this, Intent(this, VoiceAssistantService::class.java))
        toast("Modo de voz ativo.")
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
