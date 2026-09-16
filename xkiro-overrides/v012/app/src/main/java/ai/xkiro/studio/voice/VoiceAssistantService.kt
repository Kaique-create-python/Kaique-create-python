package ai.xkiro.studio.voice

import android.Manifest
import android.app.*
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.os.*
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import ai.xkiro.studio.core.AgentOrchestrator
import ai.xkiro.studio.core.SettingsStore
import ai.xkiro.studio.device.DeviceAgentController
import kotlinx.coroutines.*
import java.io.File
import java.util.Locale

class VoiceAssistantService : Service(), RecognitionListener {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var recognizer: SpeechRecognizer? = null
    private lateinit var settings: SettingsStore

    override fun onCreate() {
        super.onCreate()
        settings = SettingsStore(this)
        val ch = NotificationChannel("voice", "AI Voice Mode", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        startForeground(21, Notification.Builder(this, "voice")
            .setContentTitle("xKiro Voice Mode")
            .setContentText("Diga o nome configurado para falar com a IA")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .build())
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) startListening()
    }

    private fun startListening() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return
        if (recognizer == null) recognizer = SpeechRecognizer.createSpeechRecognizer(this).also { it.setRecognitionListener(this) }
        val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }
        recognizer?.startListening(i)
    }

    private fun process(text: String) {
        val cfg = settings.load()
        val wake = cfg.wakeWord.lowercase(Locale.ROOT)
        if (!text.lowercase(Locale.ROOT).contains(wake)) return
        val idx = text.indexOf(cfg.wakeWord, ignoreCase = true)
        val command = if (idx >= 0) text.substring(idx + cfg.wakeWord.length).trim() else text.trim()
        if (command.equals("para", true) || command.equals("parar", true)) {
            stopSelf()
            return
        }
        if (cfg.xkiroKey.isBlank()) return
        scope.launch {
            val reply = runCatching {
                if (DeviceAgentController.looksLikeDeviceCommand(command)) {
                    DeviceAgentController.execute(this@VoiceAssistantService, cfg.xkiroKey, command) { }.message
                } else {
                    val res = AgentOrchestrator.runSwarm(cfg.xkiroKey, "Comando por voz no celular: $command", 3)
                    AgentOrchestrator.synthesize(cfg.xkiroKey, command, res).take(2200)
                }
            }.getOrElse { "Ocorreu um erro: ${it.message}" }
            speak(reply)
        }
    }

    private fun speak(text: String) {
        val cfg = settings.load()
        if (cfg.voiceKey.isBlank() || cfg.voiceId.isBlank()) {
            restartSoon()
            return
        }
        scope.launch(Dispatchers.IO) {
            runCatching {
                val f = File(cacheDir, "voice_reply.mp3")
                ElevenVoiceClient.synthesize(cfg.voiceKey, cfg.voiceId, text, f)
                withContext(Dispatchers.Main) {
                    MediaPlayer().apply {
                        setDataSource(f.absolutePath)
                        setOnCompletionListener { it.release(); restartSoon() }
                        prepare()
                        start()
                    }
                }
            }.onFailure { withContext(Dispatchers.Main) { restartSoon() } }
        }
    }

    private fun restartSoon() {
        Handler(Looper.getMainLooper()).postDelayed({ if (!isDestroyed) startListening() }, 600)
    }

    private var isDestroyed = false
    override fun onDestroy() {
        isDestroyed = true
        recognizer?.destroy()
        scope.cancel()
        super.onDestroy()
    }

    override fun onResults(results: Bundle?) {
        results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let(::process)
        restartSoon()
    }
    override fun onError(error: Int) = restartSoon()
    override fun onReadyForSpeech(params: Bundle?) = Unit
    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() = Unit
    override fun onPartialResults(partialResults: Bundle?) = Unit
    override fun onEvent(eventType: Int, params: Bundle?) = Unit
    override fun onBind(intent: Intent?): IBinder? = null
}
