package com.neonterminal.app;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
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

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;

/**
 * Neon Terminal 1.2. Isolated Android shell with foreground session ownership.
 * A true PTY emulator and independent Linux bootstrap are future components.
 */
public final class MainActivity extends Activity implements TerminalRuntime.Observer {
    private static final int BACKGROUND = Color.rgb(8, 8, 12);
    private static final int SURFACE = Color.rgb(20, 15, 22);
    private static final int ACCENT = Color.rgb(255, 43, 85);
    private static final int FOREGROUND = Color.rgb(240, 224, 228);
    private static final int MUTED = Color.rgb(150, 132, 144);
    private static final int MAX_EDIT = 128 * 1024;
    private static final int MAX_FILES = 250;

    private TextView header, terminal, hint;
    private ScrollView terminalScroll;
    private EditText command;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private TerminalRuntime.Session activeSession;
    private File home;
    private int historyIndex = -1;
    private boolean pendingRefresh;

    private final Runnable counter = new Runnable() {
        @Override public void run() {
            updateHeader();
            handler.postDelayed(this, 2000);
        }
    };

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(BACKGROUND);
        getWindow().setNavigationBarColor(BACKGROUND);
        home = new File(getFilesDir(), "home");
        if (!home.isDirectory()) home.mkdirs();
        TerminalRuntime.init(home);
        buildUi();
        if (TerminalRuntime.sessions().isEmpty()) newSession();
        else switchSession(TerminalRuntime.sessions().get(0));
        startBackgroundService();
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 4001);
        }
        handler.post(counter);
    }

    @Override protected void onResume() {
        super.onResume();
        TerminalRuntime.attach(this);
        showOutput();
    }

    @Override protected void onPause() {
        TerminalRuntime.detach(this);
        super.onPause();
    }

    @Override protected void onDestroy() {
        handler.removeCallbacks(counter);
        handler.removeCallbacksAndMessages(null);
        TerminalRuntime.detach(this);
        // Do not destroy sessions: foreground service owns their lifetime.
        super.onDestroy();
    }

    @Override public void onSessionUpdated(TerminalRuntime.Session s) {
        if (s == activeSession && !pendingRefresh) {
            pendingRefresh = true;
            handler.postDelayed(() -> {
                pendingRefresh = false;
                showOutput();
            }, 70);
        }
    }

    private void startBackgroundService() {
        try {
            Intent intent = new Intent(this, TerminalService.class);
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent);
            else startService(intent);
        } catch (Exception e) {
            Toast.makeText(this,
                "Serviço indisponível: sessões podem parar em segundo plano",
                Toast.LENGTH_LONG).show();
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private GradientDrawable bg(int color, int border) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(8));
        if (border != 0) d.setStroke(dp(1), border);
        return d;
    }

    private TextView label(String text, float size, int color) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(color);
        view.setTextSize(size);
        view.setTypeface(Typeface.MONOSPACE);
        return view;
    }

    private Button button(String text, Runnable listener) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextColor(FOREGROUND);
        b.setTextSize(12f);
        b.setBackground(bg(SURFACE, ACCENT));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
            -2, dp(43));
        params.setMargins(dp(4), dp(5), dp(4), dp(5));
        b.setLayoutParams(params);
        b.setOnClickListener(v -> listener.run());
        return b;
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BACKGROUND);
        setContentView(root);

        header = label("● NEON TERMINAL X", 13, ACCENT);
        header.setPadding(dp(15), dp(10), dp(10), dp(10));
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setBackgroundColor(SURFACE);
        header.setOnClickListener(v -> showMonitor());
        root.addView(header, new LinearLayout.LayoutParams(-1, dp(47)));

        hint = label("SESSÕES PERSISTENTES  /  SHELL ANDROID", 10, MUTED);
        hint.setPadding(dp(15), dp(9), dp(12), dp(4));
        root.addView(hint);

        HorizontalScrollView actions = new HorizontalScrollView(this);
        actions.setHorizontalScrollBarEnabled(false);
        LinearLayout actionsRow = new LinearLayout(this);
        actionsRow.setPadding(dp(6), 0, dp(6), 0);
        actionsRow.addView(button("+ Sessão", this::newSession));
        actionsRow.addView(button("Sessões", this::showMonitor));
        actionsRow.addView(button("Histórico", this::showHistory));
        actionsRow.addView(button("Arquivos", () -> showExplorer(home)));
        actionsRow.addView(button("Atalhos", this::showShortcuts));
        actionsRow.addView(button("Copiar", this::copyOutput));
        actionsRow.addView(button("Limpar", this::clearOutput));
        actionsRow.addView(button("Encerrar", this::confirmStopSession));
        actions.addView(actionsRow);
        root.addView(actions);

        View line = new View(this);
        line.setBackgroundColor(ACCENT);
        root.addView(line, new LinearLayout.LayoutParams(-1, dp(1)));

        terminalScroll = new ScrollView(this);
        terminalScroll.setFillViewport(true);
        terminal = label("", 13, FOREGROUND);
        terminal.setTextIsSelectable(true);
        terminal.setPadding(dp(14), dp(14), dp(14), dp(20));
        terminal.setLineSpacing(dp(2), 1.0f);
        terminalScroll.addView(terminal);
        root.addView(terminalScroll, new LinearLayout.LayoutParams(-1, 0, 1));

        LinearLayout bottom = new LinearLayout(this);
        bottom.setBackgroundColor(SURFACE);
        bottom.setPadding(dp(6), dp(5), dp(6), dp(7));
        bottom.setGravity(Gravity.CENTER_VERTICAL);
        TextView prefix = label(" ❯ ", 20, ACCENT);
        bottom.addView(prefix);

        command = new EditText(this);
        command.setSingleLine(true);
        command.setTextColor(FOREGROUND);
        command.setHintTextColor(MUTED);
        command.setHint("Digite um comando...");
        command.setTextSize(14);
        command.setTypeface(Typeface.MONOSPACE);
        command.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        command.setImeOptions(EditorInfo.IME_ACTION_SEND);
        command.setPadding(dp(8), dp(9), dp(8), dp(9));
        command.setBackgroundColor(BACKGROUND);
        command.setOnEditorActionListener((text, action, event) -> {
            if (action == EditorInfo.IME_ACTION_SEND) { submit(); return true; }
            return false;
        });
        bottom.addView(command, new LinearLayout.LayoutParams(0, dp(44), 1));
        bottom.addView(button("↑", this::previousCommand));
        bottom.addView(button("▶", this::submit));
        root.addView(bottom);
    }

    private void updateHeader() {
        int running = 0;
        for (TerminalRuntime.Session s : TerminalRuntime.sessions())
            if (s.isRunning()) running++;
        if (header != null) header.setText("● NEON TERMINAL X  /  " + running + " shell(s)");
        if (hint != null && activeSession != null)
            hint.setText("SESSÃO " + activeSession.id
                + "  /  " + (activeSession.isRunning() ? "EXECUTANDO" : "ENCERRADA")
                + "  /  SHELL ANDROID");
    }

    private void newSession() {
        try {
            switchSession(TerminalRuntime.create());
            startBackgroundService();
        } catch (IOException error) {
            new AlertDialog.Builder(this).setTitle("Falha ao iniciar shell")
                .setMessage(error.toString()).setPositiveButton("Fechar", null).show();
        }
    }

    private void switchSession(TerminalRuntime.Session session) {
        activeSession = session;
        showOutput();
        updateHeader();
    }

    private void showOutput() {
        if (terminal == null || activeSession == null) return;
        String text = activeSession.output();
        if (text.contentEquals(terminal.getText())) return;
        terminal.setText(text);
        terminalScroll.post(() -> terminalScroll.fullScroll(View.FOCUS_DOWN));
    }

    private void submit() {
        if (activeSession == null) return;
        String raw = command.getText().toString();
        command.setText("");
        if (raw.trim().isEmpty()) return;
        historyIndex = -1;
        TerminalRuntime.remember(raw);
        try { activeSession.run(raw); }
        catch (IOException error) {
            activeSession.addText("Falha: " + error.getMessage() + "\n");
        }
    }

    private void previousCommand() {
        List<String> list = TerminalRuntime.history();
        if (list.isEmpty()) return;
        if (historyIndex < 0) historyIndex = list.size() - 1;
        else historyIndex = Math.max(0, historyIndex - 1);
        command.setText(list.get(historyIndex));
        command.setSelection(command.length());
    }

    private void showHistory() {
        List<String> list = TerminalRuntime.history();
        if (list.isEmpty()) {
            toast("Histórico vazio");
            return;
        }
        int count = Math.min(100, list.size());
        String[] names = new String[count];
        for (int i = 0; i < count; i++) names[i] = list.get(list.size() - 1 - i);
        new AlertDialog.Builder(this).setTitle("NEON / HISTÓRICO PRIVADO")
            .setItems(names, (d, n) -> {
                command.setText(names[n]);
                command.setSelection(command.length());
            })
            .setNeutralButton("Apagar", (d, n) -> confirmClearHistory())
            .setNegativeButton("Fechar", null)
            .show();
    }

    private void confirmClearHistory() {
        new AlertDialog.Builder(this)
            .setTitle("Apagar histórico?")
            .setMessage("Os comandos salvos neste aplicativo serão apagados.")
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Apagar", (d, n) -> {
                TerminalRuntime.clearHistory();
                toast("Histórico apagado");
            }).show();
    }

    private void showMonitor() {
        List<TerminalRuntime.Session> sessions = TerminalRuntime.sessions();
        if (sessions.isEmpty()) {
            toast("Nenhuma sessão");
            return;
        }
        String[] items = new String[sessions.size()];
        for (int i = 0; i < sessions.size(); i++) {
            TerminalRuntime.Session s = sessions.get(i);
            long elapsed = (System.currentTimeMillis() - s.startedAt) / 60000;
            String cmd = s.lastCommand();
            if (cmd.length() > 25) cmd = cmd.substring(0, 25) + "…";
            items[i] = "#" + s.id
                + "  " + (s.isRunning() ? "● ATIVA" : "○ PARADA")
                + "  • " + elapsed + " min"
                + (s == activeSession ? "  [ATUAL]" : "")
                + (cmd.isEmpty() ? "" : "\nÚltimo: " + cmd);
        }
        new AlertDialog.Builder(this)
            .setTitle("NEON / SESSÕES")
            .setItems(items, (d, index) -> switchSession(sessions.get(index)))
            .setNeutralButton("+ Sessão", (d, index) -> newSession())
            .setNegativeButton("Fechar", null)
            .show();
    }

    private void confirmStopSession() {
        if (activeSession == null) return;
        TerminalRuntime.Session session = activeSession;
        new AlertDialog.Builder(this).setTitle("Encerrar sessão " + session.id + "?")
            .setMessage("O shell será encerrado. Comandos derivados podem precisar ser terminados separadamente.")
            .setNegativeButton("Cancelar", null)
            .setPositiveButton("Encerrar", (d, n) -> {
                TerminalRuntime.remove(session);
                List<TerminalRuntime.Session> all = TerminalRuntime.sessions();
                if (!all.isEmpty()) switchSession(all.get(all.size() - 1));
                else newSession();
            }).show();
    }

    private void showShortcuts() {
        final String[] names = {
            "Listar arquivos", "Pasta atual", "Processos visíveis",
            "Memória disponível", "Armazenamento", "Versão do Android", "Quem sou eu"
        };
        final String[] commands = {
            "ls -la", "pwd", "ps -A", "cat /proc/meminfo",
            "df -h", "getprop ro.build.version.release", "id"
        };
        new AlertDialog.Builder(this).setTitle("NEON / COMANDOS")
            .setItems(names, (d, which) -> {
                command.setText(commands[which]);
                command.setSelection(command.length());
                toast("Comando preparado. Toque ▶ para executar.");
            })
            .setNegativeButton("Fechar", null).show();
    }

    private void showExplorer(File path) {
        try {
            File root = home.getCanonicalFile();
            File dir = path.getCanonicalFile();
            if (!isInsideHome(root, dir) || !dir.isDirectory()) {
                toast("Pasta inválida ou fora do Home");
                return;
            }
            File[] files = dir.listFiles();
            if (files == null) { toast("Não foi possível listar esta pasta"); return; }
            Arrays.sort(files, (a, b) -> {
                if (a.isDirectory() != b.isDirectory()) return a.isDirectory() ? -1 : 1;
                return a.getName().compareToIgnoreCase(b.getName());
            });
            int count = Math.min(MAX_FILES, files.length);
            int up = dir.equals(root) ? 0 : 1;
            String[] labels = new String[count + up];
            if (up == 1) labels[0] = "← Voltar";
            for (int i = 0; i < count; i++) {
                labels[i + up] = (files[i].isDirectory() ? "[DIR] " : "[FILE] ") + files[i].getName();
            }
            new AlertDialog.Builder(this)
                .setTitle("ARQUIVOS / " + dir.getName()
                    + (files.length > MAX_FILES ? " (250 primeiros)" : ""))
                .setItems(labels, (dialog, index) -> {
                    if (up == 1 && index == 0) showExplorer(dir.getParentFile());
                    else {
                        File file = files[index - up];
                        if (file.isDirectory()) showExplorer(file);
                        else showFile(file);
                    }
                })
                .setNeutralButton("+ Novo", (d, n) -> createFileDialog(dir))
                .setNegativeButton("Fechar", null).show();
        } catch (IOException error) {
            toast("Erro: " + error.getMessage());
        }
    }

    private boolean isInsideHome(File root, File file) {
        return file.getPath().equals(root.getPath())
            || file.getPath().startsWith(root.getPath() + File.separator);
    }

    private void createFileDialog(File dir) {
        EditText name = new EditText(this);
        name.setSingleLine(true);
        name.setHint("nome.txt ou pasta");
        new AlertDialog.Builder(this)
            .setTitle("Criar no Neon Home")
            .setView(name)
            .setNegativeButton("Cancelar", null)
            .setNeutralButton("Nova pasta", (d, n) -> createPath(dir, name.getText().toString(), true))
            .setPositiveButton("Novo arquivo", (d, n) -> createPath(dir, name.getText().toString(), false))
            .show();
    }

    private void createPath(File dir, String name, boolean folder) {
        name = name.trim();
        if (!name.matches("[\\p{L}\\p{N}._ -]{1,80}") || name.equals(".") || name.equals("..")) {
            toast("Nome inválido");
            showExplorer(dir);
            return;
        }
        File newFile = new File(dir, name);
        try {
            if (!isInsideHome(home.getCanonicalFile(), newFile.getCanonicalFile())) {
                toast("Fora do Home"); return;
            }
            boolean created = folder ? newFile.mkdir() : newFile.createNewFile();
            if (!created) toast("Já existe ou não foi possível criar");
            else if (!folder) { showFile(newFile); return; }
            showExplorer(dir);
        } catch (IOException e) {
            toast("Erro: " + e.getMessage());
        }
    }

    private void showFile(File file) {
        try {
            File root = home.getCanonicalFile();
            File target = file.getCanonicalFile();
            if (!isInsideHome(root, target) || !target.isFile()) {
                toast("Arquivo inacessível"); return;
            }
            new AlertDialog.Builder(this).setTitle(file.getName())
                .setMessage(target.getPath() + "\n" + target.length() + " bytes"
                    + (target.length() > MAX_EDIT
                        ? "\nArquivo grande demais para o editor integrado." : ""))
                .setNegativeButton("Voltar", (d, n) -> showExplorer(target.getParentFile()))
                .setPositiveButton("Editar texto", (d, n) -> editFile(target))
                .show();
        } catch (IOException e) { toast(e.toString()); }
    }

    private void editFile(File file) {
        if (!file.isFile() || file.length() > MAX_EDIT) {
            toast("Arquivo maior que o limite do editor (128 KiB)");
            return;
        }
        try {
            byte[] bytes = new byte[(int) file.length()];
            try (FileInputStream in = new FileInputStream(file)) {
                int offset = 0, count;
                while (offset < bytes.length
                    && (count = in.read(bytes, offset, bytes.length - offset)) > 0)
                    offset += count;
            }
            String contents = new String(bytes, StandardCharsets.UTF_8);
            if (contents.indexOf('\0') >= 0) {
                toast("Arquivo binário: edição bloqueada");
                return;
            }
            EditText editor = new EditText(this);
            editor.setSingleLine(false);
            editor.setTypeface(Typeface.MONOSPACE);
            editor.setTextSize(13);
            editor.setText(contents);
            editor.setMinLines(8);
            editor.setGravity(Gravity.TOP | Gravity.LEFT);
            ScrollView scroll = new ScrollView(this);
            scroll.setPadding(dp(12), dp(12), dp(12), dp(12));
            scroll.addView(editor);
            new AlertDialog.Builder(this)
                .setTitle("EDITAR / " + file.getName())
                .setView(scroll)
                .setNegativeButton("Cancelar", (d, n) -> showExplorer(file.getParentFile()))
                .setPositiveButton("Salvar", (d, n) -> saveFile(file, editor.getText().toString()))
                .show();
        } catch (IOException e) { toast("Erro de leitura: " + e.getMessage()); }
    }

    private void saveFile(File file, String text) {
        try {
            if (!isInsideHome(home.getCanonicalFile(), file.getCanonicalFile())) {
                toast("Fora do Home"); return;
            }
            byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
            if (bytes.length > MAX_EDIT) { toast("Arquivo acima de 128 KiB"); return; }
            // In-app file editor; no broad storage permission or access to Termux's files.
            try (FileOutputStream out = new FileOutputStream(file)) {
                out.write(bytes);
                out.getFD().sync();
            }
            toast("Arquivo salvo");
            showExplorer(file.getParentFile());
        } catch (IOException e) {
            toast("Falha ao salvar: " + e.getMessage());
        }
    }

    private void copyOutput() {
        if (activeSession == null) return;
        ClipboardManager manager = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        manager.setPrimaryClip(ClipData.newPlainText("Neon Terminal", activeSession.output()));
        toast("Saída copiada");
    }

    private void clearOutput() {
        if (activeSession != null) {
            activeSession.clearOutput();
            showOutput();
        }
    }

    private void toast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }
}
