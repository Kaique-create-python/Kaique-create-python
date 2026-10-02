package com.winlator;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import com.winlator.core.FileUtils;
import com.winlator.xenvironment.RootFS;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.util.Map;

public class LinuxTerminalActivity extends Activity {
    private TextView output;
    private EditText input;
    private ScrollView scroll;
    private Process shell;
    private BufferedWriter stdin;
    private final Handler main = new Handler(Looper.getMainLooper());
    private volatile boolean closing;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = (int)(12 * getResources().getDisplayMetrics().density);
        root.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("Diana Linux Terminal");
        title.setTextSize(18f);
        root.addView(title, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        scroll = new ScrollView(this);
        output = new TextView(this);
        output.setTextSize(13f);
        output.setTextIsSelectable(true);
        output.setGravity(Gravity.START | Gravity.TOP);
        output.setText("Iniciando Linux...\n");
        scroll.addView(output, new ScrollView.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        root.addView(scroll, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f
        ));

        LinearLayout commandRow = new LinearLayout(this);
        commandRow.setOrientation(LinearLayout.HORIZONTAL);

        input = new EditText(this);
        input.setSingleLine(true);
        input.setHint("comando Linux");
        commandRow.addView(input, new LinearLayout.LayoutParams(
            0,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            1f
        ));

        Button run = new Button(this);
        run.setText("Executar");
        commandRow.addView(run);
        root.addView(commandRow);

        setContentView(root);

        run.setOnClickListener(v -> sendCommand());
        input.setOnEditorActionListener((v, actionId, event) -> {
            sendCommand();
            return true;
        });
        input.setOnKeyListener((v, keyCode, event) -> {
            if (keyCode == KeyEvent.KEYCODE_ENTER && event.getAction() == KeyEvent.ACTION_UP) {
                sendCommand();
                return true;
            }
            return false;
        });

        startShell();
    }

    private void startShell() {
        new Thread(() -> {
            try {
                RootFS rootFS = RootFS.find(this);
                File rootDir = rootFS.getRootDir();
                File box64 = new File(rootDir, "usr/local/bin/box64");
                File bash = new File(rootDir, "usr/bin/bash");
                if (!bash.isFile()) bash = new File(rootDir, "bin/bash");
                if (!bash.isFile()) bash = new File(rootDir, "bin/sh");

                if (!box64.isFile() || !bash.isFile()) {
                    throw new Exception("O Bash do sistema Linux não foi encontrado.");
                }

                File home = new File(rootDir, "home/xuser");
                if (!home.isDirectory()) home.mkdirs();

                ProcessBuilder pb = new ProcessBuilder(
                    box64.getAbsolutePath(),
                    bash.getAbsolutePath(),
                    "--noprofile",
                    "--norc",
                    "-i"
                );
                pb.directory(home);
                pb.redirectErrorStream(true);

                Map<String, String> env = pb.environment();
                env.put("HOME", home.getAbsolutePath());
                env.put("USER", "xuser");
                env.put("LOGNAME", "xuser");
                env.put("TMPDIR", new File(rootDir, "tmp").getAbsolutePath());
                env.put("TERM", "xterm-256color");
                env.put(
                    "PATH",
                    new File(rootDir, "usr/local/bin").getAbsolutePath() + ":" +
                    new File(rootDir, "usr/bin").getAbsolutePath() + ":" +
                    new File(rootDir, "bin").getAbsolutePath()
                );
                env.put("LD_LIBRARY_PATH", new File(rootDir, "usr/lib").getAbsolutePath());
                env.put("BOX64_LD_LIBRARY_PATH", new File(rootDir, "lib/x86_64-linux-gnu").getAbsolutePath());
                env.put("BOX64_BASH", bash.getAbsolutePath());
                env.put("BOX64_NOBANNER", "1");
                env.put("BOX64_DYNAREC", "1");

                shell = pb.start();
                stdin = new BufferedWriter(new OutputStreamWriter(shell.getOutputStream()));

                postOutput(
                    "Diana Linux pronto.\n" +
                    "HOME: " + home.getAbsolutePath() + "\n" +
                    "Downloads: /storage/emulated/0/Download\n\n"
                );

                BufferedReader reader = new BufferedReader(new InputStreamReader(shell.getInputStream()));
                String line;
                while (!closing && (line = reader.readLine()) != null) {
                    postOutput(line + "\n");
                }
            }
            catch (Exception e) {
                postOutput("\nErro: " + (e.getMessage() != null ? e.getMessage() : e.toString()) + "\n");
            }
        }, "DianaLinuxTerminal").start();
    }

    private void sendCommand() {
        String command = input.getText().toString();
        if (command.trim().isEmpty()) return;
        input.setText("");
        postOutput("$ " + command + "\n");

        new Thread(() -> {
            try {
                if (stdin == null) throw new Exception("Terminal ainda está iniciando.");
                stdin.write(command);
                stdin.newLine();
                stdin.flush();
            }
            catch (Exception e) {
                postOutput("Erro: " + (e.getMessage() != null ? e.getMessage() : e.toString()) + "\n");
            }
        }, "DianaLinuxInput").start();
    }

    private void postOutput(String text) {
        main.post(() -> {
            output.append(text);
            scroll.post(() -> scroll.fullScroll(ScrollView.FOCUS_DOWN));
        });
    }

    @Override
    protected void onDestroy() {
        closing = true;
        try {
            if (stdin != null) {
                stdin.write("exit");
                stdin.newLine();
                stdin.flush();
                stdin.close();
            }
        }
        catch (Exception ignored) {}

        if (shell != null) shell.destroy();
        super.onDestroy();
    }
}
