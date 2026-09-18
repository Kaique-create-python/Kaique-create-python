package com.kaique.atomstudio;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.text.InputType;
import android.util.Base64;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.atomic.AtomicBoolean;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import okio.ByteString;

public class MainActivity extends Activity {

    private EditText hostInput;
    private EditText passwordInput;
    private EditText fileInput;
    private EditText editor;
    private TextView status;
    private TextView terminal;
    private Button connectButton;

    private final StringBuilder terminalBuffer = new StringBuilder();
    private final StringBuilder parserBuffer = new StringBuilder();

    private WebReplClient client;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        client = new WebReplClient(new WebReplClient.Listener() {
            @Override
            public void onTerminal(String text) {
                runOnUiThread(() -> {
                    appendTerminal(text);
                    parseSpecialOutput(text);
                });
            }

            @Override
            public void onState(String text, boolean ok) {
                runOnUiThread(() -> setStatus(text, ok));
            }

            @Override
            public void onAuthenticated() {
                runOnUiThread(() -> {
                    setStatus("Conectado ao ATOM e autenticado.", true);
                    connectButton.setText("DESCONECTAR");
                });
            }
        });

        setContentView(buildUi());
    }

    private View buildUi() {
        int pad = dp(16);

        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(Color.rgb(11, 15, 20));

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(pad, pad, pad, dp(30));
        scroll.addView(root);

        TextView title = text("ATOM Studio", 30, Color.WHITE);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        root.addView(title);

        TextView subtitle = text(
                "Programa o M5Stack ATOM Echo/Voice pelo Wi-Fi usando MicroPython WebREPL.",
                14, Color.rgb(170, 182, 195));
        subtitle.setPadding(0, dp(4), 0, dp(14));
        root.addView(subtitle);

        status = text("Desconectado.", 14, Color.rgb(255, 205, 90));
        status.setPadding(dp(12), dp(10), dp(12), dp(10));
        status.setBackgroundColor(Color.rgb(30, 37, 47));
        root.addView(status);

        root.addView(section("Conexão"));

        hostInput = input("IP ou URL do ATOM. Ex.: 192.168.1.120", false);
        hostInput.setText(getPreferences(MODE_PRIVATE).getString("host", ""));
        root.addView(hostInput);

        passwordInput = input("Senha WebREPL", true);
        root.addView(passwordInput);

        connectButton = button("CONECTAR");
        connectButton.setOnClickListener(v -> {
            if (client.isOpen()) {
                client.disconnect();
                connectButton.setText("CONECTAR");
                setStatus("Desconectado.", false);
                return;
            }

            String host = hostInput.getText().toString().trim();
            String pass = passwordInput.getText().toString();

            if (host.isEmpty() || pass.isEmpty()) {
                toast("Preencha o endereço e a senha WebREPL.");
                return;
            }

            getPreferences(MODE_PRIVATE).edit().putString("host", host).apply();
            setStatus("Conectando...", false);
            client.connect(host, pass);
        });
        root.addView(connectButton);

        Button findButton = button("ENCONTRAR ATOM NA REDE LOCAL");
        findButton.setOnClickListener(v -> discoverAtom());
        root.addView(findButton);

        TextView remoteHelp = text(
                "Fora da sua rede: use um endereço alcançável por VPN/túnel. Não exponha a porta 8266 diretamente na internet.",
                12, Color.rgb(150, 165, 180));
        remoteHelp.setPadding(0, dp(8), 0, dp(8));
        root.addView(remoteHelp);

        root.addView(section("Arquivos e editor"));

        fileInput = input("Arquivo", false);
        fileInput.setText("main.py");
        root.addView(fileInput);

        LinearLayout fileRow = horizontal();
        Button list = button("LISTAR");
        Button load = button("CARREGAR");
        Button save = button("SALVAR");
        fileRow.addView(list, weight());
        fileRow.addView(load, weight());
        fileRow.addView(save, weight());
        root.addView(fileRow);

        editor = new EditText(this);
        editor.setTextColor(Color.rgb(225, 235, 245));
        editor.setHintTextColor(Color.rgb(100, 112, 124));
        editor.setHint("# escreva Python aqui");
        editor.setTextSize(14);
        editor.setTypeface(Typeface.MONOSPACE);
        editor.setGravity(android.view.Gravity.TOP);
        editor.setMinLines(14);
        editor.setPadding(dp(12), dp(12), dp(12), dp(12));
        editor.setBackgroundColor(Color.rgb(8, 12, 16));
        editor.setInputType(InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_FLAG_MULTI_LINE
                | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        root.addView(editor);

        Button run = button("EXECUTAR EDITOR");
        run.setOnClickListener(v -> {
            if (!requireConnection()) return;
            client.executeRaw(editor.getText().toString());
        });
        root.addView(run);

        list.setOnClickListener(v -> {
            if (!requireConnection()) return;
            client.executeRaw("import os;print('__ATOM_FILES__',os.listdir())");
        });

        load.setOnClickListener(v -> {
            if (!requireConnection()) return;
            String name = checkedFilename();
            if (name == null) return;

            String code =
                    "import ubinascii;" +
                    "d=open(" + py(name) + ",'rb').read();" +
                    "print('__ATOM_FILE_BEGIN__'+ubinascii.b2a_base64(d).decode().strip()+'__ATOM_FILE_END__')";
            client.executeRaw(code);
        });

        save.setOnClickListener(v -> {
            if (!requireConnection()) return;
            String name = checkedFilename();
            if (name == null) return;

            byte[] raw = editor.getText().toString().getBytes(StandardCharsets.UTF_8);
            if (raw.length > 48 * 1024) {
                toast("Por enquanto limite o arquivo a 48 KB.");
                return;
            }

            String b64 = Base64.encodeToString(raw, Base64.NO_WRAP);
            String code =
                    "import ubinascii;" +
                    "f=open(" + py(name) + ",'wb');" +
                    "f.write(ubinascii.a2b_base64(" + py(b64) + "));" +
                    "f.close();" +
                    "print('__ATOM_SAVED__')";
            client.executeRaw(code);
        });

        root.addView(section("Controles rápidos"));

        LinearLayout quick1 = horizontal();
        Button sound = button("TESTAR SOM");
        Button led = button("TESTAR LED");
        quick1.addView(sound, weight());
        quick1.addView(led, weight());
        root.addView(quick1);

        LinearLayout quick2 = horizontal();
        Button stop = button("PARAR");
        Button reboot = button("REINICIAR");
        quick2.addView(stop, weight());
        quick2.addView(reboot, weight());
        root.addView(quick2);

        sound.setOnClickListener(v -> {
            if (!requireConnection()) return;
            // Short low-amplitude sine tone. Official ATOM Echo I2S pins:
            // BCLK=19, LRCK=33, DATA OUT=22.
            String beep =
                    "from machine import Pin,I2S;" +
                    "import math,struct;" +
                    "r=16000;n=3200;" +
                    "b=bytearray(n*4);" +
                    "[(struct.pack_into('<hh',b,i*4," +
                    "int(2500*math.sin(2*math.pi*660*i/r))," +
                    "int(2500*math.sin(2*math.pi*660*i/r)))) for i in range(n)];" +
                    "a=I2S(0,sck=Pin(19),ws=Pin(33),sd=Pin(22),mode=I2S.TX,bits=16,format=I2S.STEREO,rate=r,ibuf=8192);" +
                    "a.write(b);a.deinit();print('__ATOM_BEEP_OK__')";
            client.executeRaw(beep);
        });

        led.setOnClickListener(v -> {
            if (!requireConnection()) return;
            client.executeRaw(
                    "from machine import Pin;import neopixel,time;" +
                    "p=neopixel.NeoPixel(Pin(27),1);" +
                    "p[0]=(0,0,30);p.write();time.sleep_ms(500);" +
                    "p[0]=(0,0,0);p.write();print('__ATOM_LED_OK__')"
            );
        });

        stop.setOnClickListener(v -> {
            if (!requireConnection()) return;
            client.interrupt();
        });

        reboot.setOnClickListener(v -> {
            if (!requireConnection()) return;
            client.executeRaw("import machine;print('Reiniciando...');machine.reset()");
        });

        root.addView(section("Terminal"));

        terminal = text("", 12, Color.rgb(190, 255, 210));
        terminal.setTypeface(Typeface.MONOSPACE);
        terminal.setTextIsSelectable(true);
        terminal.setMinHeight(dp(260));
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

    private boolean requireConnection() {
        if (!client.isAuthenticated()) {
            toast("Conecte e autentique no ATOM primeiro.");
            return false;
        }
        return true;
    }

    private String checkedFilename() {
        String name = fileInput.getText().toString().trim();
        if (name.isEmpty() || name.contains("\n") || name.contains("\r")
                || name.contains("'") || name.contains("\\")) {
            toast("Nome de arquivo inválido.");
            return null;
        }
        return name;
    }

    private String py(String s) {
        return "'" + s.replace("'", "\\'") + "'";
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
            String b64 = all.substring(a + begin.length(), b).replace("\r", "").replace("\n", "").trim();
            try {
                byte[] raw = Base64.decode(b64, Base64.DEFAULT);
                editor.setText(new String(raw, StandardCharsets.UTF_8));
                toast("Arquivo carregado do ATOM.");
            } catch (Exception e) {
                toast("Não consegui decodificar o arquivo.");
            }
            parserBuffer.delete(0, b + end.length());
        }
    }

    private void discoverAtom() {
        setStatus("Procurando porta 8266 na rede local...", false);

        WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(WIFI_SERVICE);
        int ip = wifi.getConnectionInfo().getIpAddress();

        if (ip == 0) {
            setStatus("Não consegui descobrir o IP local do celular.", false);
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
                try (Socket socket = new Socket()) {
                    socket.connect(new InetSocketAddress(candidate, 8266), 180);
                    if (found.compareAndSet(false, true)) {
                        runOnUiThread(() -> {
                            hostInput.setText(candidate);
                            setStatus("Possível ATOM encontrado em " + candidate + ":8266", true);
                        });
                        pool.shutdownNow();
                    }
                } catch (Exception ignored) {
                }
            });
        }

        Executors.newSingleThreadExecutor().execute(() -> {
            try {
                Thread.sleep(7000);
            } catch (InterruptedException ignored) {
            }
            if (!found.get()) {
                runOnUiThread(() -> setStatus(
                        "Nenhum WebREPL encontrado. Confira se o ATOM está ligado e no mesmo Wi-Fi.",
                        false));
                pool.shutdownNow();
            }
        });
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
        status.setTextColor(ok ? Color.rgb(110, 235, 165) : Color.rgb(255, 205, 90));
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

    private LinearLayout horizontal() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.HORIZONTAL);
        return l;
    }

    private LinearLayout.LayoutParams weight() {
        return new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
    }

    private int dp(int n) {
        return Math.round(n * getResources().getDisplayMetrics().density);
    }

    private void toast(String s) {
        Toast.makeText(this, s, Toast.LENGTH_SHORT).show();
    }

    @Override
    protected void onDestroy() {
        client.disconnect();
        super.onDestroy();
    }

    static class WebReplClient {

        interface Listener {
            void onTerminal(String text);
            void onState(String text, boolean ok);
            void onAuthenticated();
        }

        private final Listener listener;
        private final OkHttpClient http = new OkHttpClient.Builder().build();
        private final ScheduledExecutorService io = Executors.newSingleThreadScheduledExecutor();

        private volatile WebSocket socket;
        private volatile boolean open;
        private volatile boolean authenticated;
        private volatile boolean passwordSent;
        private String password = "";
        private final StringBuilder loginBuffer = new StringBuilder();

        WebReplClient(Listener listener) {
            this.listener = listener;
        }

        boolean isOpen() {
            return open;
        }

        boolean isAuthenticated() {
            return authenticated;
        }

        void connect(String host, String password) {
            disconnect();

            this.password = password;
            this.passwordSent = false;
            this.authenticated = false;
            this.loginBuffer.setLength(0);

            String url = normalize(host);
            listener.onState("Abrindo " + url, false);

            Request request = new Request.Builder().url(url).build();
            socket = http.newWebSocket(request, new WebSocketListener() {
                @Override
                public void onOpen(WebSocket webSocket, Response response) {
                    open = true;
                    listener.onState("WebSocket aberto. Aguardando senha...", false);
                }

                @Override
                public void onMessage(WebSocket webSocket, String text) {
                    handleIncoming(text);
                }

                @Override
                public void onMessage(WebSocket webSocket, ByteString bytes) {
                    handleIncoming(bytes.utf8());
                }

                @Override
                public void onFailure(WebSocket webSocket, Throwable t, Response response) {
                    open = false;
                    authenticated = false;
                    listener.onState("Falha: " + t.getMessage(), false);
                }

                @Override
                public void onClosed(WebSocket webSocket, int code, String reason) {
                    open = false;
                    authenticated = false;
                    listener.onState("Conexão fechada.", false);
                }
            });
        }

        private void handleIncoming(String text) {
            listener.onTerminal(text);
            loginBuffer.append(text);

            String seen = loginBuffer.toString();

            if (!passwordSent && seen.contains("Password:")) {
                passwordSent = true;
                sendText(password + "\r\n");
                return;
            }

            if (!authenticated && passwordSent &&
                    (seen.contains("WebREPL connected") || seen.contains(">>>"))) {
                authenticated = true;
                listener.onAuthenticated();
            }

            if (loginBuffer.length() > 5000) {
                loginBuffer.delete(0, loginBuffer.length() - 2500);
            }
        }

        void interrupt() {
            if (!authenticated) return;
            sendText("\u0003\u0003");
        }

        void executeRaw(String code) {
            if (!authenticated) {
                listener.onState("WebREPL ainda não autenticado.", false);
                return;
            }

            io.execute(() -> {
                try {
                    sendText("\u0003\u0003");
                    sleep(120);
                    sendText("\u0001");
                    sleep(140);
                    sendText(code);
                    sleep(120);
                    sendText("\u0004");
                    sleep(450);
                    sendText("\u0002");
                } catch (Exception e) {
                    listener.onState("Erro executando código: " + e.getMessage(), false);
                }
            });
        }

        private void sendText(String s) {
            WebSocket ws = socket;
            if (ws != null) ws.send(s);
        }

        void disconnect() {
            WebSocket ws = socket;
            socket = null;
            open = false;
            authenticated = false;
            passwordSent = false;
            loginBuffer.setLength(0);
            if (ws != null) {
                try {
                    ws.close(1000, "bye");
                } catch (Exception ignored) {
                }
            }
        }

        private static String normalize(String host) {
            String h = host.trim();
            if (!h.startsWith("ws://") && !h.startsWith("wss://")) {
                h = "ws://" + h;
            }

            String afterScheme = h.substring(h.indexOf("://") + 3);
            if (!afterScheme.contains(":")) {
                h += ":8266";
            }

            if (!h.endsWith("/")) {
                h += "/";
            }

            return h;
        }

        private static void sleep(long ms) {
            try {
                Thread.sleep(ms);
            } catch (InterruptedException ignored) {
            }
        }
    }
}
