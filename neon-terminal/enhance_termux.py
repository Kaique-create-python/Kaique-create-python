#!/usr/bin/env python3
"""Neon Terminal V1: native dashboard, session and task monitor, explorer and quick commands."""
from pathlib import Path
import sys
import re

root = Path(sys.argv[1]).resolve()

def change(path, before, after):
    file = root / path
    text = file.read_text(encoding="utf-8")
    count = text.count(before)
    if count != 1:
        raise RuntimeError("Expected 1 match, found %d in %s: %s" % (count,path,before[:100]))
    file.write_text(text.replace(before,after,1), encoding="utf-8")
    print("ENHANCE",path)

activity="app/src/main/java/com/termux/app/TermuxActivity.java"
layout="app/src/main/res/layout/activity_termux.xml"
service="app/src/main/java/com/termux/app/TermuxService.java"

change(layout,
        '        <androidx.drawerlayout.widget.DrawerLayout\n',
        '''        <TextView
            android:id="@+id/neon_header"
            android:layout_width="match_parent"
            android:layout_height="42dp"
            android:layout_alignParentTop="true"
            android:background="@color/neon_surface"
            android:paddingHorizontal="14dp"
            android:gravity="center_vertical"
            android:clickable="true"
            android:focusable="true"
            android:text="● NEON TERMINAL  |  conectando…"
            android:textColor="@color/neon_red"
            android:textSize="12sp"
            android:letterSpacing="0.09"
            android:contentDescription="Abrir monitor de sessões" />

        <androidx.drawerlayout.widget.DrawerLayout
            android:layout_below="@id/neon_header"
''')
change(layout,
        '                <ListView\n                    android:id="@+id/terminal_sessions_list"',
        '''                <TextView
                    android:layout_width="match_parent"
                    android:layout_height="36dp"
                    android:gravity="center_vertical"
                    android:paddingHorizontal="14dp"
                    android:text="NEON  /  CONTROLE"
                    android:textStyle="bold"
                    android:textSize="12sp"
                    android:textColor="@color/neon_red" />

                <LinearLayout
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:orientation="horizontal"
                    android:paddingHorizontal="8dp">
                    <Button
                        android:id="@+id/neon_monitor_button"
                        android:layout_width="0dp"
                        android:layout_height="wrap_content"
                        android:layout_weight="1"
                        android:text="Monitor"
                        android:textAllCaps="false" />
                    <Button
                        android:id="@+id/neon_files_button"
                        android:layout_width="0dp"
                        android:layout_height="wrap_content"
                        android:layout_weight="1"
                        android:text="Arquivos"
                        android:textAllCaps="false" />
                </LinearLayout>
                <Button
                    android:id="@+id/neon_shortcuts_button"
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:layout_marginHorizontal="8dp"
                    android:text="Atalhos de comandos"
                    android:textAllCaps="false" />

                <TextView
                    android:layout_width="match_parent"
                    android:layout_height="wrap_content"
                    android:paddingHorizontal="14dp"
                    android:paddingTop="8dp"
                    android:paddingBottom="4dp"
                    android:text="SESSÕES ABERTAS"
                    android:textColor="@color/neon_red"
                    android:textSize="11sp"/>

                <ListView
                    android:id="@+id/terminal_sessions_list"''')
change(layout,
        'android:background="@color/black"\n            android:layout_alignParentBottom="true"',
        'android:background="@color/neon_surface"\n            android:layout_alignParentBottom="true"')

# Existing v0.1 patched manifest is still com.termux, intentionally preserving apt/pkg prefix.
change(service,
        'TermuxConstants.TERMUX_APP_NAME, notificationText, null,',
        '"Neon Terminal", notificationText, null,')
change(service,
        'builder.setColor(0xFF607D8B);',
        'builder.setColor(0xFFFF315A);')
change(service,
        '    public synchronized int getTermuxSessionsSize() {\n',
        '''    /** Number of tracked app-level background tasks, excluding foreground terminal sessions. */
    public synchronized int getNeonBackgroundTasksCount() {
        return mShellManager.mTermuxTasks.size();
    }

    public synchronized int getTermuxSessionsSize() {
''')

change(activity,
        'import android.widget.TextView;\n',
        '''import android.widget.TextView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.graphics.Typeface;
import android.graphics.Color;
import android.content.DialogInterface;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Comparator;
''')
change(activity,
        '    private static final int CONTEXT_MENU_NEON_MONITOR_ID = 12;',
        '''    private static final int CONTEXT_MENU_NEON_MONITOR_ID = 12;
    private static final int CONTEXT_MENU_NEON_FILES_ID = 13;
    private static final int CONTEXT_MENU_NEON_SHORTCUTS_ID = 14;

    private final Handler mNeonHeaderHandler = new Handler(Looper.getMainLooper());
    private TextView mNeonHeader;
    private final Runnable mNeonHeaderTicker = new Runnable() {
        @Override public void run() {
            if (mNeonHeader == null || !mIsVisible) return;
            int sessions = mTermuxService == null ? 0 : mTermuxService.getTermuxSessionsSize();
            int tasks = mTermuxService == null ? 0 : mTermuxService.getNeonBackgroundTasksCount();
            mNeonHeader.setText("● NEON TERMINAL  |  " + sessions +
                " sessão(ões)  •  " + tasks + " tarefa(s)");
            mNeonHeaderHandler.postDelayed(this, 2000);
        }
    };
''')
change(activity,
        '        setToggleKeyboardView();\n\n        registerForContextMenu(mTerminalView);',
        '''        setToggleKeyboardView();

        setNeonDashboard();
        registerForContextMenu(mTerminalView);''')
change(activity,
        '        mIsVisible = true;\n',
        '''        mIsVisible = true;
        mNeonHeaderHandler.removeCallbacks(mNeonHeaderTicker);
        mNeonHeaderHandler.post(mNeonHeaderTicker);
''')
change(activity,
        '        mIsVisible = false;\n',
        '''        mIsVisible = false;
        mNeonHeaderHandler.removeCallbacks(mNeonHeaderTicker);
''')
change(activity,
        '        menu.add(Menu.NONE, CONTEXT_MENU_NEON_MONITOR_ID, Menu.NONE, "Monitor de sessões");',
        '''        menu.add(Menu.NONE, CONTEXT_MENU_NEON_MONITOR_ID, Menu.NONE, "Monitor de sessões");
        menu.add(Menu.NONE, CONTEXT_MENU_NEON_FILES_ID, Menu.NONE, "Arquivos do projeto");
        menu.add(Menu.NONE, CONTEXT_MENU_NEON_SHORTCUTS_ID, Menu.NONE, "Atalhos de comandos");''')
change(activity,
        '            case CONTEXT_MENU_NEON_MONITOR_ID:\n                showNeonMonitor();',
        '''            case CONTEXT_MENU_NEON_FILES_ID:
                showNeonExplorer(new File(getFilesDir(), "home"));
                return true;
            case CONTEXT_MENU_NEON_SHORTCUTS_ID:
                showNeonShortcuts();
                return true;
            case CONTEXT_MENU_NEON_MONITOR_ID:
                showNeonMonitor();''')
start_marker='    /** Monitor current sessions; does not execute arbitrary commands. */'
end_marker='    private void showStylingDialog() {'
path=root/activity
s=path.read_text(encoding="utf-8")
if s.count(start_marker)!=1 or s.count(end_marker)!=1: raise RuntimeError("Monitor method anchor changed")
i=s.index(start_marker)
j=s.index(end_marker,i)
addon=r'''
    private void setNeonDashboard() {
        mNeonHeader = findViewById(R.id.neon_header);
        mNeonHeader.setOnClickListener(v -> showNeonMonitor());
        findViewById(R.id.neon_monitor_button).setOnClickListener(v -> {
            getDrawer().closeDrawers();
            showNeonMonitor();
        });
        findViewById(R.id.neon_files_button).setOnClickListener(v -> {
            getDrawer().closeDrawers();
            showNeonExplorer(new File(getFilesDir(), "home"));
        });
        findViewById(R.id.neon_shortcuts_button).setOnClickListener(v -> {
            getDrawer().closeDrawers();
            showNeonShortcuts();
        });
    }

    private void showNeonMonitor() {
        final TextView status = new TextView(this);
        status.setPadding(36, 28, 36, 32);
        status.setTextColor(0xFFFCE5EB);
        status.setTextSize(14f);
        status.setTypeface(Typeface.MONOSPACE);
        status.setBackgroundColor(0xFF151019);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(status);
        final Handler handler = new Handler(Looper.getMainLooper());
        final AlertDialog dialog = new AlertDialog.Builder(this)
            .setTitle("NEON  /  MONITOR AO VIVO")
            .setView(scroll)
            .setNeutralButton("Nova sessão", (d, which) -> {
                if (mTermuxTerminalSessionActivityClient != null)
                    mTermuxTerminalSessionActivityClient.addNewSession(false, null);
            })
            .setPositiveButton("Fechar", null)
            .create();
        final Runnable refresh = new Runnable() {
            @Override public void run() {
                if (!dialog.isShowing()) return;
                StringBuilder out = new StringBuilder();
                if (mTermuxService == null) {
                    out.append("Aguardando inicialização do serviço...");
                } else {
                    List<TermuxSession> sessions =
                        new java.util.ArrayList<>(mTermuxService.getTermuxSessions());
                    out.append("Sessões abertas: ").append(sessions.size()).append("\n");
                    out.append("Tarefas em segundo plano: ")
                        .append(mTermuxService.getNeonBackgroundTasksCount())
                        .append("\n\n────────────────────\n\n");
                    if (sessions.isEmpty()) out.append("Nenhuma sessão aberta.\n");
                    for (int i = 0; i < sessions.size(); i++) {
                        TerminalSession terminal = sessions.get(i).getTerminalSession();
                        out.append("SESSION ").append(i + 1);
                        if (terminal == getCurrentSession()) out.append("  [ATUAL]");
                        out.append("\nNome: ")
                            .append(terminal.mSessionName == null ? "Terminal" : terminal.mSessionName);
                        out.append("\nPID: ").append(terminal.getPid());
                        out.append("\nEstado: ")
                            .append(terminal.isRunning() ? "Executando" : "Encerrado");
                        String cwd = terminal.getCwd();
                        if (cwd != null) out.append("\nPasta: ").append(cwd);
                        out.append("\n\n");
                    }
                    out.append("Atualização: 1,5 s\n");
                    out.append("O monitor acompanha sessões e tarefas do app.");
                }
                status.setText(out.toString());
                handler.postDelayed(this, 1500);
            }
        };
        dialog.setOnDismissListener(ignored -> handler.removeCallbacks(refresh));
        dialog.show();
        handler.post(refresh);
    }

    /** Browse $HOME with Android's regular file APIs, read only. */
    private void showNeonExplorer(File directory) {
        try {
            File home = new File(getFilesDir(), "home").getCanonicalFile();
            File dir = directory.getCanonicalFile();
            String base = home.getPath();
            if (!dir.getPath().equals(base) &&
                !dir.getPath().startsWith(base + File.separator)) {
                showToast("Arquivo fora da pasta Home", true);
                return;
            }
            if (!dir.isDirectory()) {
                showToast("Pasta indisponível", true);
                return;
            }
            File[] files = dir.listFiles();
            if (files == null) {
                showToast("Sem acesso à pasta", true);
                return;
            }
            java.util.Arrays.sort(files, (a, b) -> {
                if (a.isDirectory() && !b.isDirectory()) return -1;
                if (!a.isDirectory() && b.isDirectory()) return 1;
                return a.getName().compareToIgnoreCase(b.getName());
            });
            final int count = Math.min(200, files.length);
            String[] labels = new String[count + (dir.equals(home) ? 0 : 1)];
            int start = dir.equals(home) ? 0 : 1;
            if (start == 1) labels[0] = "← Pasta anterior";
            for (int index=0; index<count; index++)
                labels[index + start] = (files[index].isDirectory() ? "📁  " : "📄  ") +
                    files[index].getName();
            new AlertDialog.Builder(this)
                .setTitle("NEON  /  " + dir.getName() +
                    (files.length > 200 ? "  (primeiros 200)" : ""))
                .setItems(labels, (dialog, index) -> {
                    if (start == 1 && index == 0) {
                        showNeonExplorer(dir.getParentFile());
                        return;
                    }
                    File selected = files[index - start];
                    if (selected.isDirectory()) showNeonExplorer(selected);
                    else showNeonFile(selected);
                })
                .setNegativeButton("Fechar", null)
                .show();
        } catch (IOException e) {
            showToast("Falha ao ler a pasta: " + e.getMessage(), true);
        }
    }

    private void showNeonFile(File file) {
        StringBuilder body = new StringBuilder("Local: " + file.getAbsolutePath());
        body.append("\nTamanho: ").append(file.length()).append(" bytes\n");
        if (file.length() > 0 && file.length() <= 32768) {
            try (FileInputStream input = new FileInputStream(file)) {
                byte[] bytes = new byte[(int) file.length()];
                int n = input.read(bytes);
                if (n > 0) {
                    String preview = new String(bytes, 0, n, StandardCharsets.UTF_8);
                    boolean appearsText = preview.indexOf('\u0000') < 0;
                    if (appearsText) {
                        body.append("\nPrévia:\n\n")
                            .append(preview.substring(0, Math.min(4000, preview.length())));
                    } else body.append("\nArquivo binário (sem prévia)");
                }
            } catch (IOException ex) {
                body.append("\nSem permissão de leitura.");
            }
        } else body.append("\nPrévia desativada para arquivo grande ou vazio.");
        new AlertDialog.Builder(this)
            .setTitle(file.getName())
            .setMessage(body.toString())
            .setPositiveButton("Fechar", null)
            .setNeutralButton("Voltar", (dialog, which) -> showNeonExplorer(file.getParentFile()))
            .show();
    }

    private void showNeonShortcuts() {
        final String[] labels = {
            "Mostrar pasta atual", "Listar arquivos", "Listar processos",
            "Portas e servidores", "Versão do Python", "Versão do Node.js", "Atualizar pacotes"
        };
        final String[] commands = {
            "pwd", "ls -la", "ps -ef", "ss -lnt", "python --version",
            "node --version", "pkg update"
        };
        new AlertDialog.Builder(this)
            .setTitle("NEON  /  ATALHOS")
            .setItems(labels, (dialog, index) -> {
                TerminalSession session = getCurrentSession();
                if (session == null || !session.isRunning()) {
                    showToast("Abra uma sessão antes de inserir comandos", true);
                } else {
                    // User must press Enter; a shortcut never auto-executes a command.
                    session.write(commands[index]);
                    showToast("Comando inserido. Pressione Enter para executar.", true);
                }
            })
            .setNegativeButton("Fechar", null)
            .show();
    }

'''
s=s[:i]+addon+s[j:]
path.write_text(s,encoding="utf-8")
print("REPLACE neon dialog and inject dashboard/explorer/shortcuts")
print("Neon V1 enhancement complete.")
