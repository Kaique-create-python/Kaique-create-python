package com.kaique.atomstudio;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.text.InputType;
import android.util.Base64;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

public class MainActivityV2 extends Activity {
    private static final int REQ_AUDIO = 4041;
    private static final int REQ_MIC = 4042;

    private EditText hostInput;
    private EditText passwordInput;
    private EditText fileInput;
    private EditText editor;
    private TextView status;
    private TextView terminal;
    private TextView audioFileLabel;
    private TextView volumeLabel;
    private Button connectButton;

    private Uri selectedAudioUri;
    private int volumePercent = 35;

    private final StringBuilder terminalBuffer = new StringBuilder();
    private final StringBuilder parserBuffer = new StringBuilder();

    private WebReplClient client;
    private final AudioStreamer audioStreamer = new AudioStreamer();
    private final LiveMicStreamer liveMicStreamer = new LiveMicStreamer();

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        client = new WebReplClient(new WebReplClient.Listener() {
            @Override public void onTerminal(String text) {
                runOnUiThread(() -> {
                    appendTerminal(text);
                    parseSpecialOutput(text);
                });
            }

            @Override public void onState(String text, boolean ok) {
                runOnUiThread(() -> setStatus(text, ok));
            }

            @Override public void onAuthenticated() {
                runOnUiThread(() -> {
                    setStatus("Conectado ao ATOM e autenticado.", true);
                    connectButton.setText("DESCONECTAR");
                });
            }
        });

        setContentView(buildUi());
    }

    private ScrollView buildUi() {
        int pad = dp(16);

        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(Color.rgb(11, 15, 20));

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(pad, pad, pad, dp(30));
        scroll.addView(root);

        TextView title = text("ATOM Studio v0.6 HalfDuplexFix", 30, Color.WHITE);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        root.addView(title);

        TextView sub = text(
                "Programa o ATOM pelo Wi-Fi e transmite áudio do celular em tempo real.",
                14, Color.rgb(170, 182, 195));
        sub.setPadding(0, dp(4), 0, dp(14));
        root.addView(sub);

        status = text("Desconectado.", 14, Color.rgb(255, 205, 90));
        status.setPadding(dp(12), dp(10), dp(12), dp(10));
        status.setBackgroundColor(Color.rgb(30, 37, 47));
        root.addView(status);

        root.addView(section("Conexão"));

        hostInput = input("IP do ATOM. Ex.: 192.168.1.120", false);
        hostInput.setText(getPreferences(MODE_PRIVATE).getString("host", ""));
        root.addView(hostInput);

        passwordInput = input("Senha WebREPL", true);
        root.addView(passwordInput);

        connectButton = button("CONECTAR");
        connectButton.setOnClickListener(v -> connectOrDisconnect());
        root.addView(connectButton);

        Button find = button("ENCONTRAR ATOM NA REDE LOCAL");
        find.setOnClickListener(v -> discoverAtom());
        root.addView(find);

        root.addView(section("Áudio do celular → ATOM"));

        TextView info = text(
                "O som fica no celular. O app decodifica e transmite PCM ao vivo; nenhum arquivo de áudio é gravado na flash do ATOM.",
                13, Color.rgb(170, 182, 195));
        root.addView(info);

        audioFileLabel = text("Nenhum áudio selecionado.", 13, Color.rgb(220, 228, 238));
        audioFileLabel.setPadding(0, dp(8), 0, dp(4));
        root.addView(audioFileLabel);

        Button choose = button("CARREGAR ÁUDIO DO CELULAR");
        choose.setOnClickListener(v -> chooseAudio());
        root.addView(choose);

        volumeLabel = text("Volume: 35%", 13, Color.rgb(220, 228, 238));
        volumeLabel.setPadding(0, dp(10), 0, 0);
        root.addView(volumeLabel);

        SeekBar volume = new SeekBar(this);
        volume.setMax(70);
        volume.setProgress(35);
        volume.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar bar, int progress, boolean fromUser) {
                volumePercent = Math.max(5, progress);
                volumeLabel.setText("Volume: " + volumePercent + "%");
            }
            @Override public void onStartTrackingTouch(SeekBar bar) {}
            @Override public void onStopTrackingTouch(SeekBar bar) {}
        });
        root.addView(volume);

        LinearLayout audioRow = row();
        Button play = button("TRANSMITIR / TOCAR");
        Button stopAudio = button("PARAR ÁUDIO");
        audioRow.addView(play, weight());
        audioRow.addView(stopAudio, weight());
        root.addView(audioRow);

        play.setOnClickListener(v -> playSelectedAudio());
        stopAudio.setOnClickListener(v -> {
            audioStreamer.stop();
            setStatus("Parando áudio...", false);
        });

        root.addView(section("Microfone do celular → ATOM"));

        TextView mic = text(
                "Transmite sua voz ao vivo pela RAM. Nenhum arquivo de gravação é criado no celular nem gravado no ATOM.",
                13, Color.rgb(170, 182, 195));
        mic.setPadding(0, dp(4), 0, dp(6));
        root.addView(mic);

        LinearLayout micRow = row();
        Button startMic = button("INICIAR MIC AO VIVO");
        Button stopMic = button("PARAR MIC");
        micRow.addView(startMic, weight());
        micRow.addView(stopMic, weight());
        root.addView(micRow);

        startMic.setOnClickListener(v -> startLiveMic());
        stopMic.setOnClickListener(v -> {
            liveMicStreamer.stop();
            setStatus("Parando microfone ao vivo...", false);
        });

        TextView atomMic = text(
                "Obs.: este botão usa o microfone do CELULAR. O microfone físico PDM do próprio ATOM ainda precisa de firmware específico.",
                12, Color.rgb(255, 205, 90));
        atomMic.setPadding(0, dp(8), 0, 0);
        root.addView(atomMic);

        root.addView(section("Arquivos e editor"));

        fileInput = input("Nome do arquivo", false);
        fileInput.setText("main.py");
        root.addView(fileInput);

        LinearLayout files = row();
        Button list = button("LISTAR");
        Button load = button("CARREGAR");
        Button save = button("SALVAR");
        files.addView(list, weight());
        files.addView(load, weight());
        files.addView(save, weight());
        root.addView(files);

        editor = new EditText(this);
        editor.setTextColor(Color.rgb(225, 235, 245));
        editor.setHintTextColor(Color.rgb(100, 112, 124));
        editor.setHint("# escreva Python aqui");
        editor.setTextSize(14);
        editor.setTypeface(Typeface.MONOSPACE);
        editor.setGravity(android.view.Gravity.TOP);
        editor.setMinLines(12);
        editor.setPadding(dp(12), dp(12), dp(12), dp(12));
        editor.setBackgroundColor(Color.rgb(8, 12, 16));
        editor.setInputType(InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_FLAG_MULTI_LINE
                | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        root.addView(editor);

        list.setOnClickListener(v -> {
            if (!requireConnection()) return;
            client.executeRaw("import os;print('__ATOM_FILES__',os.listdir())");
        });

        load.setOnClickListener(v -> loadFile());
        save.setOnClickListener(v -> saveFile());

        Button run = button("EXECUTAR EDITOR");
        run.setOnClickListener(v -> {
            if (!requireConnection()) return;
            client.executeRaw(editor.getText().toString());
        });
        root.addView(run);

        root.addView(section("Controles rápidos"));

        LinearLayout quick = row();
        Button beep = button("TESTAR SOM");
        Button led = button("TESTAR LED");
        quick.addView(beep, weight());
        quick.addView(led, weight());
        root.addView(quick);

        LinearLayout quick2 = row();
        Button interrupt = button("PARAR PYTHON");
        Button reboot = button("REINICIAR");
        quick2.addView(interrupt, weight());
        quick2.addView(reboot, weight());
        root.addView(quick2);

        beep.setOnClickListener(v -> testBeep());
        led.setOnClickListener(v -> testLed());
        interrupt.setOnClickListener(v -> {
            if (requireConnection()) client.interrupt();
        });
        reboot.setOnClickListener(v -> {
            if (!requireConnection()) return;
            audioStreamer.stop();
            liveMicStreamer.stop();
            client.executeRaw("import machine;print('Reiniciando...');machine.reset()");
        });

        root.addView(section("Terminal"));

        terminal = text("", 12, Color.rgb(190, 255, 210));
        terminal.setTypeface(Typeface.MONOSPACE);
        terminal.setTextIsSelectable(true);
        terminal.setMinHeight(dp(250));
        terminal.setPadding(dp(10), dp(10), dp(10), dp(10));
        terminal.setBackgroundColor(Color.rgb(5, 8, 11));
        root.addView(terminal);

        Button clear = button("LIMPAR TERMINAL");
        clear.setOnClickListener(v -> {
            terminalBuffer.setLength(0);
            parserBuffer.setLength(0);
            terminal.setText("");
        });
        root.addView(clear);

        return scroll;
    }

    private void connectOrDisconnect() {
        if (client.isOpen()) {
            audioStreamer.stop();
            liveMicStreamer.stop();
            client.disconnect();
            connectButton.setText("CONECTAR");
            setStatus("Desconectado.", false);
            return;
        }

        String host = hostInput.getText().toString().trim();
        String pass = passwordInput.getText().toString();

        if (host.isEmpty() || pass.isEmpty()) {
            toast("Preencha IP e senha WebREPL.");
            return;
        }

        getPreferences(MODE_PRIVATE).edit().putString("host", host).apply();
        setStatus("Conectando...", false);
        client.connect(host, pass);
    }

    private void chooseAudio() {
        Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("audio/*");
        startActivityForResult(i, REQ_AUDIO);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode == REQ_AUDIO && resultCode == RESULT_OK
                && data != null && data.getData() != null) {
            selectedAudioUri = data.getData();

            try {
                getContentResolver().takePersistableUriPermission(
                        selectedAudioUri,
                        data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } catch (Exception ignored) {}

            audioFileLabel.setText("Selecionado: " + displayName(selectedAudioUri));
        }
    }

    private String displayName(Uri uri) {
        Cursor c = null;
        try {
            c = getContentResolver().query(uri, null, null, null, null);
            if (c != null && c.moveToFirst()) {
                int index = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (index >= 0) return c.getString(index);
            }
        } catch (Exception ignored) {
        } finally {
            if (c != null) c.close();
        }
        return "áudio";
    }

    private void playSelectedAudio() {
        if (!requireConnection()) return;
        if (selectedAudioUri == null) {
            toast("Escolha um áudio primeiro.");
            return;
        }

        liveMicStreamer.stop();
        audioStreamer.start(this, selectedAudioUri, volumePercent, new AudioStreamer.Control() {
            @Override public void startBlockingPython(String code) {
                client.startBlockingRaw(code);
            }

            @Override public void finishBlockingPython() {
                client.finishBlockingRaw();
            }

            @Override public String host() {
                return cleanHost(hostInput.getText().toString());
            }

            @Override public void status(String text, boolean ok) {
                runOnUiThread(() -> setStatus(text, ok));
            }

            @Override public void log(String text) {
                runOnUiThread(() -> appendTerminal(text));
            }
        });
    }

    private void startLiveMic() {
        if (!requireConnection()) return;

        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, REQ_MIC);
            return;
        }

        audioStreamer.stop();

        liveMicStreamer.start(volumePercent, new LiveMicStreamer.Control() {
            @Override public void startBlockingPython(String code) {
                client.startBlockingRaw(code);
            }

            @Override public void finishBlockingPython() {
                client.finishBlockingRaw();
            }

            @Override public String host() {
                return cleanHost(hostInput.getText().toString());
            }

            @Override public void status(String text, boolean ok) {
                runOnUiThread(() -> setStatus(text, ok));
            }

            @Override public void log(String text) {
                runOnUiThread(() -> appendTerminal(text));
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode == REQ_MIC) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startLiveMic();
            } else {
                toast("Permissão do microfone negada.");
            }
        }
    }

    private String cleanHost(String raw) {
        String h = raw.trim();
        h = h.replace("ws://", "").replace("wss://", "")
                .replace("http://", "").replace("https://", "");

        int slash = h.indexOf('/');
        if (slash >= 0) h = h.substring(0, slash);

        int colon = h.indexOf(':');
        if (colon >= 0) h = h.substring(0, colon);

        return h.trim();
    }

    private void loadFile() {
        if (!requireConnection()) return;
        String name = filename();
        if (name == null) return;

        String code =
                "import ubinascii;" +
                "d=open(" + py(name) + ",'rb').read();" +
                "print('__ATOM_FILE_BEGIN__'+ubinascii.b2a_base64(d).decode().strip()+'__ATOM_FILE_END__')";
        client.executeRaw(code);
    }

    private void saveFile() {
        if (!requireConnection()) return;
        String name = filename();
        if (name == null) return;

        byte[] raw = editor.getText().toString().getBytes(StandardCharsets.UTF_8);
        if (raw.length > 48 * 1024) {
            toast("Limite atual: 48 KB por arquivo.");
            return;
        }

        String b64 = Base64.encodeToString(raw, Base64.NO_WRAP);
        String code =
                "import ubinascii;" +
                "f=open(" + py(name) + ",'wb');" +
                "f.write(ubinascii.a2b_base64(" + py(b64) + "));" +
                "f.close();print('__ATOM_SAVED__')";
        client.executeRaw(code);
    }

    private void testBeep() {
        if (!requireConnection()) return;

        String code =
                "from machine import Pin,I2S;" +
                "import math,struct;" +
                "r=16000;n=2400;" +
                "b=bytearray(n*4);" +
                "[(struct.pack_into('<hh',b,i*4," +
                "int(1800*math.sin(2*math.pi*660*i/r))," +
                "int(1800*math.sin(2*math.pi*660*i/r)))) for i in range(n)];" +
                "a=I2S(0,sck=Pin(19),ws=Pin(33),sd=Pin(22),mode=I2S.TX,bits=16,format=I2S.STEREO,rate=r,ibuf=8192);" +
                "a.write(b);a.deinit();print('__ATOM_BEEP_OK__')";
        client.executeRaw(code);
    }

    private void testLed() {
        if (!requireConnection()) return;
        client.executeRaw(
                "from machine import Pin;import neopixel,time;" +
                "p=neopixel.NeoPixel(Pin(27),1);" +
                "p[0]=(0,0,30);p.write();time.sleep_ms(500);" +
                "p[0]=(0,0,0);p.write();print('__ATOM_LED_OK__')"
        );
    }

    private void parseSpecialOutput(String chunk) {
        parserBuffer.append(chunk);
        if (parserBuffer.length() > 180000) {
            parserBuffer.delete(0, parserBuffer.length() - 90000);
        }

        String all = parserBuffer.toString();
        String begin = "__ATOM_FILE_BEGIN__";
        String end = "__ATOM_FILE_END__";

        int a = all.indexOf(begin);
        int b = all.indexOf(end, a + begin.length());

        if (a >= 0 && b > a) {
            String b64 = all.substring(a + begin.length(), b)
                    .replace("\r", "").replace("\n", "").trim();

            try {
                byte[] raw = Base64.decode(b64, Base64.DEFAULT);
                editor.setText(new String(raw, StandardCharsets.UTF_8));
                toast("Arquivo carregado.");
            } catch (Exception e) {
                toast("Falha ao carregar arquivo.");
            }

            parserBuffer.delete(0, b + end.length());
        }
    }

    private void discoverAtom() {
        setStatus("Procurando WebREPL na rede...", false);

        WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        int ip = wifi.getConnectionInfo().getIpAddress();

        if (ip == 0) {
            setStatus("Não consegui obter o IP Wi-Fi do celular.", false);
            return;
        }

        String base = String.format(Locale.US, "%d.%d.%d.",
                ip & 0xff, (ip >> 8) & 0xff, (ip >> 16) & 0xff);

        ExecutorService pool = Executors.newFixedThreadPool(32);
        AtomicBoolean found = new AtomicBoolean(false);

        for (int i = 1; i <= 254; i++) {
            final String candidate = base + i;

            pool.submit(() -> {
                if (found.get()) return;

                try (Socket s = new Socket()) {
                    s.connect(new InetSocketAddress(candidate, 8266), 180);

                    if (found.compareAndSet(false, true)) {
                        runOnUiThread(() -> {
                            hostInput.setText(candidate);
                            setStatus("ATOM/WebREPL encontrado em " + candidate, true);
                        });
                        pool.shutdownNow();
                    }
                } catch (Exception ignored) {}
            });
        }

        Executors.newSingleThreadExecutor().execute(() -> {
            try { Thread.sleep(7000); } catch (InterruptedException ignored) {}

            if (!found.get()) {
                runOnUiThread(() -> setStatus(
                        "Nenhum WebREPL encontrado na rede local.", false));
                pool.shutdownNow();
            }
        });
    }

    private boolean requireConnection() {
        if (!client.isAuthenticated()) {
            toast("Conecte no ATOM primeiro.");
            return false;
        }
        return true;
    }

    private String filename() {
        String n = fileInput.getText().toString().trim();

        if (n.isEmpty() || n.contains("\n") || n.contains("\r")
                || n.contains("'") || n.contains("\\")) {
            toast("Nome de arquivo inválido.");
            return null;
        }

        return n;
    }

    private String py(String s) {
        return "'" + s.replace("'", "\\'") + "'";
    }

    private void appendTerminal(String s) {
        terminalBuffer.append(s);

        if (terminalBuffer.length() > 70000) {
            terminalBuffer.delete(0, terminalBuffer.length() - 50000);
        }

        terminal.setText(terminalBuffer.toString());
    }

    private void setStatus(String s, boolean ok) {
        status.setText(s);
        status.setTextColor(ok
                ? Color.rgb(110, 235, 165)
                : Color.rgb(255, 205, 90));
    }

    private TextView section(String s) {
        TextView t = text(s, 19, Color.WHITE);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setPadding(0, dp(18), 0, dp(8));
        return t;
    }

    private TextView text(String s, int sp, int color) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(color);
        return t;
    }

    private EditText input(String hint, boolean password) {
        EditText e = new EditText(this);
        e.setHint(hint);
        e.setHintTextColor(Color.rgb(110, 120, 132));
        e.setTextColor(Color.WHITE);
        e.setSingleLine(true);
        e.setPadding(dp(12), dp(8), dp(12), dp(8));
        e.setBackgroundColor(Color.rgb(20, 27, 35));

        if (password) {
            e.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        }

        return e;
    }

    private Button button(String s) {
        Button b = new Button(this);
        b.setText(s);
        b.setAllCaps(false);
        return b;
    }

    private LinearLayout row() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.HORIZONTAL);
        return l;
    }

    private LinearLayout.LayoutParams weight() {
        return new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
    }

    private int dp(int n) {
        return Math.round(n * getResources().getDisplayMetrics().density);
    }

    private void toast(String s) {
        Toast.makeText(this, s, Toast.LENGTH_SHORT).show();
    }

    @Override
    protected void onDestroy() {
        audioStreamer.shutdown();
        liveMicStreamer.shutdown();
        client.disconnect();
        super.onDestroy();
    }
}
