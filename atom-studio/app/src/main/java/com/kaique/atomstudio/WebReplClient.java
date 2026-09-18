package com.kaique.atomstudio;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import okio.ByteString;

public class WebReplClient {
    public interface Listener {
        void onTerminal(String text);
        void onState(String text, boolean ok);
        void onAuthenticated();
    }

    private final Listener listener;
    private final OkHttpClient http = new OkHttpClient();
    private final ExecutorService io = Executors.newSingleThreadExecutor();

    private volatile WebSocket socket;
    private volatile boolean open;
    private volatile boolean authenticated;
    private volatile boolean passwordSent;
    private String password;
    private final StringBuilder login = new StringBuilder();

    public WebReplClient(Listener listener) {
        this.listener = listener;
    }

    public boolean isOpen() { return open; }
    public boolean isAuthenticated() { return authenticated; }

    public void connect(String host, String password) {
        disconnect();
        this.password = password;
        this.passwordSent = false;
        this.authenticated = false;
        login.setLength(0);

        String url = normalize(host);
        listener.onState("Abrindo " + url, false);

        socket = http.newWebSocket(new Request.Builder().url(url).build(), new WebSocketListener() {
            @Override public void onOpen(WebSocket ws, Response response) {
                open = true;
                listener.onState("WebSocket aberto. Aguardando senha...", false);
            }

            @Override public void onMessage(WebSocket ws, String text) {
                incoming(text);
            }

            @Override public void onMessage(WebSocket ws, ByteString bytes) {
                incoming(bytes.utf8());
            }

            @Override public void onFailure(WebSocket ws, Throwable t, Response response) {
                open = false;
                authenticated = false;
                listener.onState("Falha: " + t.getMessage(), false);
            }

            @Override public void onClosed(WebSocket ws, int code, String reason) {
                open = false;
                authenticated = false;
                listener.onState("Conexão fechada.", false);
            }
        });
    }

    private void incoming(String text) {
        listener.onTerminal(text);
        login.append(text);
        String s = login.toString();

        if (!passwordSent && s.contains("Password:")) {
            passwordSent = true;
            send(password + "\r\n");
            return;
        }

        if (!authenticated && passwordSent &&
                (s.contains("WebREPL connected") || s.contains(">>>"))) {
            authenticated = true;
            listener.onAuthenticated();
        }

        if (login.length() > 5000) {
            login.delete(0, login.length() - 2500);
        }
    }

    public void executeRaw(String code) {
        if (!authenticated) return;
        io.execute(() -> {
            try {
                send("\u0003\u0003");
                sleep(120);
                send("\u0001");
                sleep(140);
                send(code);
                sleep(120);
                send("\u0004");
                sleep(550);
                send("\u0002");
            } catch (Exception e) {
                listener.onState("Erro executando Python: " + e.getMessage(), false);
            }
        });
    }

    public void startBlockingRaw(String code) {
        if (!authenticated) return;
        io.execute(() -> {
            try {
                send("\u0003\u0003");
                sleep(120);
                send("\u0001");
                sleep(140);
                send(code);
                sleep(120);
                send("\u0004");
            } catch (Exception e) {
                listener.onState("Erro iniciando stream Python: " + e.getMessage(), false);
            }
        });
    }

    public void finishBlockingRaw() {
        if (!authenticated) return;
        io.execute(() -> {
            sleep(250);
            send("\u0002");
        });
    }

    public void interrupt() {
        if (authenticated) send("\u0003\u0003");
    }

    private void send(String s) {
        WebSocket ws = socket;
        if (ws != null) ws.send(s);
    }

    public void disconnect() {
        WebSocket ws = socket;
        socket = null;
        open = false;
        authenticated = false;
        passwordSent = false;
        login.setLength(0);
        if (ws != null) {
            try { ws.close(1000, "bye"); } catch (Exception ignored) {}
        }
    }

    private static String normalize(String host) {
        String h = host.trim();
        if (!h.startsWith("ws://") && !h.startsWith("wss://")) h = "ws://" + h;
        String x = h.substring(h.indexOf("://") + 3);
        if (!x.contains(":")) h += ":8266";
        if (!h.endsWith("/")) h += "/";
        return h;
    }

    private static void sleep(long ms) {
        try { Thread.sleep(ms); } catch (InterruptedException ignored) {}
    }
}
