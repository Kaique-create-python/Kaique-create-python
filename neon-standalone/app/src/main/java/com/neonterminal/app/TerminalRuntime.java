package com.neonterminal.app;

import android.os.Handler;
import android.os.Looper;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.lang.ref.WeakReference;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Process/session owner independent of Activity instances. This is NOT a Linux distribution
 * or a PTY; commands execute through the device's built-in /system/bin/sh.
 */
public final class TerminalRuntime {
    private TerminalRuntime() {}
    private static final int MAX_OUTPUT = 100_000;
    private static final int MAX_HISTORY = 300;
    private static final Handler UI = new Handler(Looper.getMainLooper());
    private static final ArrayList<Session> sessions = new ArrayList<>();
    private static final ArrayList<String> history = new ArrayList<>();
    private static WeakReference<Observer> observer = new WeakReference<>(null);
    private static File home;
    private static int nextId = 1;
    private static boolean initialized = false;

    public interface Observer { void onSessionUpdated(Session session); }

    public static synchronized void init(File appHome) {
        if (initialized) return;
        home = appHome;
        if (!home.isDirectory()) home.mkdirs();
        File file = historyFile();
        if (file.isFile()) {
            try (BufferedReader r = new BufferedReader(new InputStreamReader(
                    new FileInputStream(file), StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    if (!line.trim().isEmpty()) history.add(line);
                    if (history.size() > MAX_HISTORY) history.remove(0);
                }
            } catch (IOException ignored) {}
        }
        initialized = true;
    }

    private static File historyFile() { return new File(home, ".neon_history"); }

    public static synchronized void attach(Observer o) {
        observer = new WeakReference<>(o);
    }

    public static synchronized void detach(Observer o) {
        if (observer.get() == o) observer.clear();
    }

    private static void broadcast(Session s) {
        UI.post(() -> {
            Observer o;
            synchronized (TerminalRuntime.class) { o = observer.get(); }
            if (o != null) o.onSessionUpdated(s);
        });
    }

    public static synchronized List<Session> sessions() {
        return new ArrayList<>(sessions);
    }

    public static synchronized Session create() throws IOException {
        if (!initialized) throw new IOException("Runtime não inicializado");
        Session session = new Session(nextId++);
        sessions.add(session);
        broadcast(session);
        return session;
    }

    public static synchronized List<String> history() {
        return new ArrayList<>(history);
    }

    /** Commands prefixed with a space are excluded from persisted history. */
    public static synchronized void remember(String rawCommand) {
        if (rawCommand.isEmpty() || rawCommand.startsWith(" ")) return;
        String cmd = rawCommand.trim();
        if (cmd.isEmpty() || cmd.equals(history.isEmpty() ? null : history.get(history.size() - 1))) return;
        history.add(cmd);
        if (history.size() > MAX_HISTORY) history.remove(0);
        persistHistory();
    }

    private static void persistHistory() {
        try (FileOutputStream out = new FileOutputStream(historyFile())) {
            for (String cmd : history) {
                out.write((cmd + "\n").getBytes(StandardCharsets.UTF_8));
            }
        } catch (IOException ignored) {}
    }

    public static synchronized void clearHistory() {
        history.clear();
        if (initialized) persistHistory();
    }

    public static synchronized void remove(Session session) {
        if (sessions.remove(session)) {
            session.stop();
            broadcast(session);
        }
    }

    public static synchronized void stopAll() {
        for (Session s : sessions) s.stop();
        sessions.clear();
    }

    public static final class Session {
        public final int id;
        public final Process process;
        private final BufferedWriter stdin;
        private final StringBuilder output = new StringBuilder();
        public final long startedAt = System.currentTimeMillis();
        private String lastCommand = "";
        private volatile boolean closed = false;

        private Session(int id) throws IOException {
            this.id = id;
            ProcessBuilder pb = new ProcessBuilder("/system/bin/sh");
            pb.directory(home);
            pb.redirectErrorStream(true);
            pb.environment().put("HOME", home.getAbsolutePath());
            pb.environment().put("TMPDIR", home.getParentFile().getAbsolutePath());
            pb.environment().put("PATH", "/system/bin:/system/xbin:/vendor/bin");
            pb.environment().put("PS1", "neon$ ");
            process = pb.start();
            stdin = new BufferedWriter(
                new OutputStreamWriter(process.getOutputStream(), StandardCharsets.UTF_8));

            addText("NEON TERMINAL / sessão " + id + "\n"
                + "Shell Android: /system/bin/sh\n"
                + "Home isolada: " + home.getAbsolutePath() + "\n"
                + "Sessões mantidas por serviço em primeiro plano.\n"
                + "Não inclui pacotes Linux / pkg / Python / Node.\n"
                + "Digite 'help' para conhecer os comandos.\n\n");

            Thread reader = new Thread(() -> {
                try (InputStreamReader stream = new InputStreamReader(
                        process.getInputStream(), StandardCharsets.UTF_8)) {
                    char[] buffer = new char[2048];
                    int count;
                    while ((count = stream.read(buffer)) >= 0) {
                        if (count > 0) addText(new String(buffer, 0, count));
                    }
                } catch (IOException e) {
                    addText("\n[Saída encerrada]\n");
                } finally {
                    closed = true;
                    addText("\n[Shell encerrado]\n");
                }
            }, "Neon-shell-" + id);
            reader.setDaemon(true);
            reader.start();
        }

        public synchronized String output() { return output.toString(); }
        public synchronized String lastCommand() { return lastCommand; }
        public boolean isRunning() { return !closed && process.isAlive(); }

        public synchronized void clearOutput() {
            output.setLength(0);
            broadcast(this);
        }

        public synchronized void addText(String str) {
            // Remove common ANSI SGR codes only; this TextView is not a full terminal emulator.
            String plain = str.replaceAll("\u001b\\[[0-?]*[ -/]*[@-~]", "");
            output.append(plain);
            int excess = output.length() - MAX_OUTPUT;
            if (excess > 0) output.delete(0, excess);
            broadcast(this);
        }

        public synchronized void run(String command) throws IOException {
            if (!isRunning()) throw new IOException("Shell encerrado");
            lastCommand = command;
            addText("❯ " + command + "\n");
            if ("help".equals(command.trim())) {
                addText("Comandos Android: ls, pwd, cd, cat, echo, ps, df, id, getprop.\n"
                    + "Use os botões para sessões, histórico, arquivos e editor.\n"
                    + "Prefixe um comando com espaço para não salvar no histórico.\n\n");
                return;
            }
            stdin.write(command);
            stdin.newLine();
            stdin.flush();
        }

        public synchronized void stop() {
            if (closed) return;
            closed = true;
            try { stdin.write("exit\n"); stdin.flush(); } catch (IOException ignored) {}
            process.destroy();
            addText("\n[Sessão finalizada pelo usuário]\n");
        }
    }
}
