package com.neonterminal.app;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.inputmethod.EditorInfo;
import android.widget.Button;
import android.widget.EditText;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Independent Android shell application, NOT a custom Termux bootstrap.
 * The shell is Android's /system/bin/sh, never com.termux's files/usr/bin.
 * No sharedUserId or cross-application filesystem access.
 */
public class MainActivity extends Activity {
    private static final int BACKGROUND = Color.rgb(8, 8, 12);
    private static final int SURFACE = Color.rgb(20, 15, 22);
    private static final int ACCENT = Color.rgb(255, 43, 85);
    private static final int FOREGROUND = Color.rgb(240, 224, 228);
    private static final int MUTED = Color.rgb(150, 132, 144);
    private static final int MAX_BUFFER = 50000;

    private LinearLayout main;
    private TextView header;
    private TextView terminal;
    private ScrollView terminalScroll;
    private EditText command;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ArrayList<Session> sessions = new ArrayList<>();
    private Session activeSession;
    private File home;
    private int nextSessionId = 1;
    private final Runnable counter = new Runnable() {
        @Override public void run() {
            if (header != null) {
                int alive = 0;
                for (Session s : sessions) if (s.alive()) alive++;
                header.setText("● NEON TERMINAL   /   " + alive + " sessão(ões) ativa(s)");
            }
            handler.postDelayed(this, 2000);
        }
    };

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(BACKGROUND);
        getWindow().setNavigationBarColor(BACKGROUND);
        home = new File(getFilesDir(), "home");
        if (!home.exists()) home.mkdirs();
        createUi();
        startSession();
        handler.post(counter);
    }

    private GradientDrawable background(int color, int stroke) {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(16);
        if (stroke != 0) bg.setStroke(1, stroke);
        return bg;
    }

    private TextView label(String text, float size, int color) {
        TextView t = new TextView(this);
        t.setText(text);
        t.setTextColor(color);
        t.setTextSize(size);
        t.setTypeface(Typeface.MONOSPACE);
        return t;
    }

    private Button button(String title, Runnable fn) {
        Button b = new Button(this);
        b.setText(title);
        b.setAllCaps(false);
        b.setTextColor(FOREGROUND);
        b.setTextSize(12);
        b.setBackground(background(SURFACE, ACCENT));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, dp(43));
        params.setMargins(dp(4), dp(5), dp(4), dp(5));
        b.setLayoutParams(params);
        b.setOnClickListener(v -> fn.run());
        return b;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void createUi() {
        main = new LinearLayout(this);
        main.setOrientation(LinearLayout.VERTICAL);
        main.setBackgroundColor(BACKGROUND);
        setContentView(main);

        header = label("● NEON TERMINAL", 13, ACCENT);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(17), dp(12), dp(14), dp(12));
        header.setBackgroundColor(SURFACE);
        header.setOnClickListener(v -> showMonitor());
        main.addView(header, new LinearLayout.LayoutParams(-1, dp(49)));

        TextView hint = label("ANDROID SHELL  /  AMBIENTE INDEPENDENTE", 10, MUTED);
        hint.setPadding(dp(15), dp(10), dp(10), dp(3));
        main.addView(hint);

        HorizontalScrollView actions = new HorizontalScrollView(this);
        actions.setHorizontalScrollBarEnabled(false);
        LinearLayout actionRow = new LinearLayout(this);
        actionRow.setOrientation(LinearLayout.HORIZONTAL);
        actionRow.setPadding(dp(7), 0, dp(7), 0);
        actionRow.addView(button("+ Sessão", this::startSession));
        actionRow.addView(button("Monitor", this::showMonitor));
        actionRow.addView(button("Arquivos", () -> showExplorer(home)));
        actionRow.addView(button("Atalhos", this::showShortcuts));
        actionRow.addView(button("Copiar", this::copyOutput));
        actionRow.addView(button("Limpar", this::clearOutput));
        actions.addView(actionRow);
        main.addView(actions);

        View separator = new View(this);
        separator.setBackgroundColor(ACCENT);
        main.addView(separator, new LinearLayout.LayoutParams(-1, dp(1)));

        terminalScroll = new ScrollView(this);
        terminalScroll.setFillViewport(true);
        terminalScroll.setBackgroundColor(BACKGROUND);
        terminal = label("", 13, FOREGROUND);
        terminal.setTextIsSelectable(true);
        terminal.setPadding(dp(15), dp(16), dp(15), dp(20));
        terminal.setLineSpacing(dp(3), 1.0f);
        terminalScroll.addView(terminal, new ScrollView.LayoutParams(-1, -2));
        main.addView(terminalScroll, new LinearLayout.LayoutParams(-1, 0, 1));

        LinearLayout bottom = new LinearLayout(this);
        bottom.setPadding(dp(7), dp(7), dp(7), dp(9));
        bottom.setGravity(Gravity.CENTER_VERTICAL);
        bottom.setBackgroundColor(SURFACE);

        TextView dollar = label(" ❯ ", 20, ACCENT);
        bottom.addView(dollar);

        command = new EditText(this);
        command.setSingleLine(true);
        command.setTextColor(FOREGROUND);
        command.setHintTextColor(MUTED);
        command.setHint("Digite um comando...");
        command.setHint("ls -la, pwd, cd...");
        command.setTextSize(14);
        command.setTypeface(Typeface.MONOSPACE);
        command.setBackgroundColor(BACKGROUND);
        command.setPadding(dp(8), dp(10), dp(6), dp(10));
        command.setImeOptions(EditorInfo.IME_ACTION_SEND);
        command.setInputType(InputType.TYPE_CLASS_TEXT
            | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        command.setOnEditorActionListener((view, action, event) -> {
            if (action == EditorInfo.IME_ACTION_SEND) {
                submit();
                return true;
            }
            return false;
        });
        bottom.addView(command, new LinearLayout.LayoutParams(0, dp(48), 1));
        bottom.addView(button("Executar", this::submit));
        main.addView(bottom, new LinearLayout.LayoutParams(-1, -2));
    }

    private void addText(Session session, String text) {
        if (session == null) return;
        String clean = text.replaceAll("\u001b\\[[0-?]*[ -/]*[@-~]", "");
        session.output.append(clean);
        if (session.output.length() > MAX_BUFFER) {
            session.output.delete(0, session.output.length() - MAX_BUFFER);
        }
        if (activeSession == session) showOutput();
    }

    private void showOutput() {
        if (activeSession == null) return;
        terminal.setText(activeSession.output.toString());
        terminalScroll.post(() -> terminalScroll.fullScroll(View.FOCUS_DOWN));
    }

    private void startSession() {
        try {
            Session session = new Session(nextSessionId++);
            sessions.add(session);
            activeSession = session;
            session.output.append("NEON TERMINAL / sessão " + session.id + "\n")
                .append("Shell Android: /system/bin/sh\n")
                .append("Home privado: ").append(home.getAbsolutePath()).append("\n\n")
                .append("Este app é separado do Termux.\n")
                .append("Não inclui pkg, Python ou Node.js do Termux.\n")
                .append("Use 'help' para ver comandos básicos.\n\n");
            showOutput();
        } catch (IOException error) {
            new AlertDialog.Builder(this)
                .setTitle("Erro ao iniciar o terminal")
                .setMessage(error.toString())
                .setPositiveButton("OK", null)
                .show();
        }
    }

    private void submit() {
        if (activeSession == null) return;
        String cmd = command.getText().toString().trim();
        command.setText("");
        if (cmd.isEmpty()) return;
        Session session = activeSession;
        addText(session, "❯ " + cmd + "\n");
        if ("help".equals(cmd)) {
            addText(session, "Comandos: ls, cd, pwd, echo, cat, mkdir, rm, ps, df, id, getprop\n");
            addText(session, "Sessões, arquivos e atalhos ficam nos botões superiores.\n\n");
            return;
        }
        try {
            if (!session.alive()) {
                addText(session, "Sessão encerrada. Abra + Sessão.\n");
                return;
            }
            session.stdin.write(cmd);
            session.stdin.newLine();
            session.stdin.flush();
        } catch (IOException error) {
            addText(session, "\nErro ao executar: " + error.getMessage() + "\n");
        }
    }

    private void showMonitor() {
        if (sessions.isEmpty()) {
            new AlertDialog.Builder(this).setMessage("Nenhuma sessão aberta")
                .setPositiveButton("Fechar", null).show();
            return;
        }
        String[] items = new String[sessions.size()];
        for (int i = 0; i < sessions.size(); i++) {
            Session s = sessions.get(i);
            items[i] = "Sessão " + s.id + " | PID " + s.process.pid()
                + " | " + (s.alive() ? "Executando" : "Encerrada")
                + (s == activeSession ? " | ATUAL" : "");
        }
        new AlertDialog.Builder(this)
            .setTitle("NEON / SESSÕES E PROCESSOS")
            .setItems(items, (d, which) -> {
                activeSession = sessions.get(which);
                showOutput();
            })
            .setNeutralButton("+ Nova sessão", (d, w) -> startSession())
            .setNegativeButton("Fechar", null)
            .show();
    }

    private void showShortcuts() {
        final String[] labels = {
            "Pasta atual", "Arquivos", "Processos do sistema",
            "Uso do armazenamento", "Usuário atual", "Versão do Android",
            "Listar conexões de rede"
        };
        final String[] cmds = {
            "pwd", "ls -la", "ps -A", "df -h", "id",
            "getprop ro.build.version.release", "cat /proc/net/tcp"
        };
        new AlertDialog.Builder(this)
            .setTitle("NEON / COMANDOS RÁPIDOS")
            .setItems(labels, (d, which) -> {
                command.setText(cmds[which]);
                command.setSelection(command.length());
                Toast.makeText(this, "Comando preenchido. Execute quando quiser.", Toast.LENGTH_SHORT).show();
            })
            .setNegativeButton("Fechar", null)
            .show();
    }

    private void showExplorer(File directory) {
        try {
            File root = home.getCanonicalFile();
            File dir = directory.getCanonicalFile();
            String rootPath = root.getPath();
            if (!dir.getPath().equals(rootPath)
                && !dir.getPath().startsWith(rootPath + File.separator)) {
                Toast.makeText(this, "Acesso limitado à pasta Home", Toast.LENGTH_SHORT).show();
                return;
            }
            File[] candidates = dir.listFiles();
            if (candidates == null) {
                Toast.makeText(this, "Não foi possível ler a pasta.", Toast.LENGTH_SHORT).show();
                return;
            }
            Arrays.sort(candidates, (a, b) -> {
                if (a.isDirectory() != b.isDirectory()) return a.isDirectory() ? -1 : 1;
                return a.getName().compareToIgnoreCase(b.getName());
            });
            final int n = Math.min(200, candidates.length);
            boolean parent = !dir.equals(root);
            String[] labels = new String[n + (parent ? 1 : 0)];
            int offset = parent ? 1 : 0;
            if (parent) labels[0] = "← Voltar";
            for (int i = 0; i < n; i++)
                labels[i + offset] = (candidates[i].isDirectory() ? "[DIR] " : "[FILE] ")
                    + candidates[i].getName();
            new AlertDialog.Builder(this)
                .setTitle("HOME / " + dir.getName())
                .setItems(labels, (d, index) -> {
                    if (parent && index == 0) showExplorer(dir.getParentFile());
                    else {
                        File chosen = candidates[index - offset];
                        if (chosen.isDirectory()) showExplorer(chosen);
                        else showFile(chosen);
                    }
                })
                .setNegativeButton("Fechar", null)
                .show();
        } catch (IOException error) {
            Toast.makeText(this, "Erro: " + error.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void showFile(File file) {
        StringBuilder content = new StringBuilder();
        content.append(file.getAbsolutePath()).append("\n")
            .append("Tamanho: ").append(file.length()).append(" bytes\n\n");
        if (file.length() < 16384 && file.length() > 0) {
            try (FileInputStream input = new FileInputStream(file)) {
                byte[] bytes = new byte[(int) file.length()];
                int size = input.read(bytes);
                if (size > 0) {
                    String preview = new String(bytes, 0, size, StandardCharsets.UTF_8);
                    if (preview.indexOf('\0') < 0)
                        content.append(preview.substring(0, Math.min(4000, preview.length())));
                    else content.append("Arquivo binário.");
                }
            } catch (IOException e) { content.append("Prévia indisponível."); }
        } else content.append("Prévia indisponível para este tamanho de arquivo.");
        new AlertDialog.Builder(this).setTitle(file.getName())
            .setMessage(content.toString())
            .setPositiveButton("Fechar", null)
            .setNeutralButton("Voltar", (d, w) -> showExplorer(file.getParentFile()))
            .show();
    }

    private void clearOutput() {
        if (activeSession != null) {
            activeSession.output.setLength(0);
            showOutput();
        }
    }

    private void copyOutput() {
        if (activeSession == null) return;
        ClipboardManager clipboard =
            (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        clipboard.setPrimaryClip(ClipData.newPlainText("Neon Terminal", activeSession.output));
        Toast.makeText(this, "Saída copiada", Toast.LENGTH_SHORT).show();
    }

    @Override protected void onDestroy() {
        handler.removeCallbacks(counter);
        for (Session session : sessions) session.process.destroy();
        super.onDestroy();
    }

    private final class Session {
        final int id;
        final Process process;
        final BufferedWriter stdin;
        final StringBuilder output = new StringBuilder();

        Session(int id) throws IOException {
            this.id = id;
            ProcessBuilder pb = new ProcessBuilder("/system/bin/sh");
            pb.directory(home);
            pb.redirectErrorStream(true);
            pb.environment().put("HOME", home.getAbsolutePath());
            pb.environment().put("TMPDIR", getCacheDir().getAbsolutePath());
            pb.environment().put("PATH", "/system/bin:/system/xbin:/vendor/bin");
            process = pb.start();
            stdin = new BufferedWriter(
                new OutputStreamWriter(process.getOutputStream(), StandardCharsets.UTF_8));
            Thread reader = new Thread(() -> {
                try (InputStreamReader stdout = new InputStreamReader(
                    process.getInputStream(), StandardCharsets.UTF_8)) {
                    char[] bytes = new char[2048];
                    int count;
                    while ((count = stdout.read(bytes)) != -1) {
                        final String chunk = new String(bytes, 0, count);
                        runOnUiThread(() -> addText(this, chunk));
                    }
                } catch (IOException error) {
                    runOnUiThread(() -> addText(this, "\n[Leitura encerrada]\n"));
                } finally {
                    runOnUiThread(() -> addText(this, "\n[Sessão encerrada]\n"));
                }
            }, "Neon-shell-output-" + id);
            reader.setDaemon(true);
            reader.start();
        }

        boolean alive() { return process.isAlive(); }
    }
}
