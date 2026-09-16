package ai.xkiro.studio.device

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

object ShizukuBridge {
    private val received = Shizuku.OnBinderReceivedListener { /* pingBinder() is source of truth */ }
    private val dead = Shizuku.OnBinderDeadListener { /* status is read live */ }

    fun initialize() {
        runCatching {
            Shizuku.addBinderReceivedListenerSticky(received)
            Shizuku.addBinderDeadListener(dead)
        }
    }

    fun isRunning(): Boolean = runCatching { Shizuku.pingBinder() }.getOrDefault(false)

    val binderAlive: Boolean
        get() = isRunning()

    fun hasPermission(): Boolean = runCatching {
        isRunning() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    }.getOrDefault(false)

    fun requestPermission(code: Int = 4242): Boolean {
        if (!isRunning()) return false
        if (hasPermission()) return true
        return runCatching {
            if (!Shizuku.shouldShowRequestPermissionRationale()) {
                Shizuku.requestPermission(code)
                true
            } else {
                false
            }
        }.getOrDefault(false)
    }

    fun shell(command: String, timeoutMs: Long = 12_000): Result<String> = runCatching {
        check(isRunning()) { "Shizuku não está conectado." }
        check(hasPermission()) { "Permissão do Shizuku ainda não foi concedida ao xKiro AI Studio." }

        val method = Shizuku::class.java.methods.firstOrNull {
            it.name == "newProcess" && it.parameterTypes.size == 3
        } ?: error("Esta versão do Shizuku não expõe execução shell compatível.")

        val process = method.invoke(null, arrayOf("sh", "-c", command), null, null) as Process
        val started = System.currentTimeMillis()
        while (process.isAlive && System.currentTimeMillis() - started < timeoutMs) {
            Thread.sleep(20)
        }
        if (process.isAlive) {
            process.destroy()
            error("Comando Shizuku excedeu o tempo limite.")
        }
        val stdout = BufferedReader(InputStreamReader(process.inputStream)).use { it.readText() }
        val stderr = BufferedReader(InputStreamReader(process.errorStream)).use { it.readText() }
        if (process.exitValue() != 0) error(stderr.ifBlank { "shell exit=${process.exitValue()}" })
        (stdout + if (stderr.isNotBlank()) "\n$stderr" else "").trim()
    }

    fun keyEvent(keyCode: Int): Result<String> = shell("input keyevent $keyCode")
}
