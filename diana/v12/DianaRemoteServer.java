package com.winlator.core;

import android.app.Activity;
import android.graphics.Bitmap;
import android.os.SystemClock;
import android.util.Base64;
import android.view.KeyEvent;

import com.winlator.renderer.GLRenderer;
import com.winlator.widget.XServerView;
import com.winlator.xserver.Pointer;
import com.winlator.xserver.XServer;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Enumeration;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class DianaRemoteServer {
    public interface Listener {
        void onStatus(String message);
        void onError(String message);
    }

    private static final int DEFAULT_PORT = 8765;
    private static final int JPEG_QUALITY = 68;

    private final Activity activity;
    private final XServer xServer;
    private final XServerView xServerView;
    private final Listener listener;
    private final ExecutorService clients = Executors.newFixedThreadPool(6);
    private final Object frameLock = new Object();

    private volatile boolean running;
    private ServerSocket serverSocket;
    private Thread acceptThread;
    private int port;
    private String pin;

    public DianaRemoteServer(Activity activity, XServer xServer, XServerView xServerView, Listener listener) {
        this.activity = activity;
        this.xServer = xServer;
        this.xServerView = xServerView;
        this.listener = listener;
    }

    public synchronized void start() {
        if (running) {
            status("Remote Web já está ligado.");
            return;
        }

        try {
            pin = String.format(Locale.ENGLISH, "%06d", new SecureRandom().nextInt(1000000));
            serverSocket = bindPort();
            port = serverSocket.getLocalPort();
            running = true;

            acceptThread = new Thread(this::acceptLoop, "DianaRemoteAccept");
            acceptThread.start();

            status("Remote Web ligado em " + getPrimaryUrl());
        }
        catch (Exception e) {
            running = false;
            error("Não consegui iniciar o Remote Web: " + safeMessage(e));
        }
    }

    public synchronized void stop() {
        running = false;
        try {
            if (serverSocket != null) serverSocket.close();
        }
        catch (Exception ignored) {}
        serverSocket = null;
        if (acceptThread != null) acceptThread.interrupt();
        acceptThread = null;
        status("Remote Web desligado.");
    }

    public boolean isRunning() {
        return running;
    }

    public int getPort() {
        return port;
    }

    public String getPin() {
        return pin != null ? pin : "";
    }

    public String getPrimaryUrl() {
        List<String> urls = getUrls();
        return urls.isEmpty() ? "http://127.0.0.1:" + port : urls.get(0);
    }

    public List<String> getUrls() {
        if (port <= 0) return Collections.emptyList();

        ArrayList<String> siteLocal = new ArrayList<>();
        ArrayList<String> other = new ArrayList<>();

        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces != null && interfaces.hasMoreElements()) {
                NetworkInterface network = interfaces.nextElement();
                if (!network.isUp() || network.isLoopback()) continue;

                Enumeration<InetAddress> addresses = network.getInetAddresses();
                while (addresses.hasMoreElements()) {
                    InetAddress address = addresses.nextElement();
                    if (!(address instanceof Inet4Address) || address.isLoopbackAddress()) continue;
                    String url = "http://" + address.getHostAddress() + ":" + port;
                    if (address.isSiteLocalAddress()) siteLocal.add(url);
                    else other.add(url);
                }
            }
        }
        catch (Exception ignored) {}

        siteLocal.addAll(other);
        return siteLocal;
    }

    private ServerSocket bindPort() throws Exception {
        Exception last = null;
        for (int p = DEFAULT_PORT; p <= DEFAULT_PORT + 10; p++) {
            try {
                ServerSocket socket = new ServerSocket(p);
                socket.setReuseAddress(true);
                return socket;
            }
            catch (Exception e) {
                last = e;
            }
        }
        if (last != null) throw last;
        throw new Exception("Nenhuma porta disponível.");
    }

    private void acceptLoop() {
        while (running) {
            try {
                Socket socket = serverSocket.accept();
                socket.setSoTimeout(15000);
                clients.execute(() -> handleClient(socket));
            }
            catch (Exception e) {
                if (running) error("Remote Web: " + safeMessage(e));
            }
        }
    }

    private void handleClient(Socket socket) {
        try (Socket client = socket) {
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(client.getInputStream(), StandardCharsets.UTF_8)
            );

            String requestLine = reader.readLine();
            if (requestLine == null || requestLine.isEmpty()) return;

            String[] requestParts = requestLine.split(" ");
            if (requestParts.length < 2) {
                sendText(client, 400, "text/plain; charset=utf-8", "Bad request");
                return;
            }

            String method = requestParts[0];
            String target = requestParts[1];
            int contentLength = 0;

            String line;
            while ((line = reader.readLine()) != null && !line.isEmpty()) {
                int colon = line.indexOf(':');
                if (colon < 0) continue;
                String name = line.substring(0, colon).trim();
                String value = line.substring(colon + 1).trim();
                if ("Content-Length".equalsIgnoreCase(name)) {
                    try { contentLength = Integer.parseInt(value); }
                    catch (Exception ignored) {}
                }
            }

            String body = "";
            if (contentLength > 0) {
                char[] chars = new char[Math.min(contentLength, 65536)];
                int total = 0;
                while (total < chars.length) {
                    int n = reader.read(chars, total, chars.length - total);
                    if (n < 0) break;
                    total += n;
                }
                body = new String(chars, 0, total);
            }

            String path = target;
            String query = "";
            int q = target.indexOf('?');
            if (q >= 0) {
                path = target.substring(0, q);
                query = target.substring(q + 1);
            }

            if ("GET".equals(method) && "/".equals(path)) {
                sendText(client, 200, "text/html; charset=utf-8", pageHtml());
                return;
            }

            String suppliedPin = queryValue(query, "pin");
            if (!getPin().equals(suppliedPin)) {
                sendText(client, 403, "text/plain; charset=utf-8", "PIN inválido");
                return;
            }

            if ("GET".equals(method) && "/frame.jpg".equals(path)) {
                byte[] frame = captureJpeg();
                if (frame == null) {
                    sendText(client, 503, "text/plain; charset=utf-8", "Sem frame");
                    return;
                }
                sendBytes(client, 200, "image/jpeg", frame, "Cache-Control: no-store\r\n");
                return;
            }

            if ("GET".equals(method) && "/ping".equals(path)) {
                sendText(client, 200, "application/json; charset=utf-8", "{\"ok\":true}");
                return;
            }

            if ("POST".equals(method) && "/event".equals(path)) {
                handleEvent(new JSONObject(body));
                sendText(client, 200, "application/json; charset=utf-8", "{\"ok\":true}");
                return;
            }

            sendText(client, 404, "text/plain; charset=utf-8", "Not found");
        }
        catch (Exception ignored) {}
    }

    private String queryValue(String query, String key) {
        try {
            for (String part : query.split("&")) {
                int eq = part.indexOf('=');
                String k = eq >= 0 ? part.substring(0, eq) : part;
                String v = eq >= 0 ? part.substring(eq + 1) : "";
                if (key.equals(URLDecoder.decode(k, "UTF-8"))) {
                    return URLDecoder.decode(v, "UTF-8");
                }
            }
        }
        catch (Exception ignored) {}
        return "";
    }

    private void handleEvent(JSONObject event) throws Exception {
        String type = event.optString("type", "");

        switch (type) {
            case "move": {
                int[] p = normalizedToXServer(
                    (float)event.optDouble("x", 0),
                    (float)event.optDouble("y", 0)
                );
                xServer.injectPointerMove(p[0], p[1]);
                break;
            }

            case "mouse_down": {
                int[] p = normalizedToXServer(
                    (float)event.optDouble("x", 0),
                    (float)event.optDouble("y", 0)
                );
                xServer.injectPointerMove(p[0], p[1]);
                xServer.injectPointerButtonPress(pointerButton(event.optInt("button", 0)));
                break;
            }

            case "mouse_up": {
                int[] p = normalizedToXServer(
                    (float)event.optDouble("x", 0),
                    (float)event.optDouble("y", 0)
                );
                xServer.injectPointerMove(p[0], p[1]);
                xServer.injectPointerButtonRelease(pointerButton(event.optInt("button", 0)));
                break;
            }

            case "wheel": {
                int dy = event.optInt("dy", 0);
                int ticks = Math.max(1, Math.min(10, Math.abs(dy) / 80 + 1));
                Pointer.Button button = dy >= 0
                    ? Pointer.Button.BUTTON_SCROLL_DOWN
                    : Pointer.Button.BUTTON_SCROLL_UP;

                for (int i = 0; i < ticks; i++) {
                    xServer.injectPointerButtonPress(button);
                    xServer.injectPointerButtonRelease(button);
                }
                break;
            }

            case "text":
                typeText(event.optString("text", ""));
                break;

            case "key_down":
                injectKey(event.optString("key", ""), true);
                break;

            case "key_up":
                injectKey(event.optString("key", ""), false);
                break;
        }
    }

    private int[] normalizedToXServer(float nx, float ny) {
        nx = Math.max(0f, Math.min(1f, nx));
        ny = Math.max(0f, Math.min(1f, ny));

        int viewWidth = Math.max(1, xServerView.getWidth());
        int viewHeight = Math.max(1, xServerView.getHeight());
        float screenshotX = nx * viewWidth;
        float screenshotY = ny * viewHeight;

        GLRenderer renderer = xServerView.getRenderer();
        float x;
        float y;

        if (renderer.isFullscreen()) {
            x = screenshotX * (xServer.screenInfo.width / (float)viewWidth);
            y = screenshotY * (xServer.screenInfo.height / (float)viewHeight);
        }
        else {
            float aspect = Math.max(0.0001f, renderer.viewTransformation.aspect);
            x = (screenshotX - renderer.viewTransformation.viewOffsetX) / aspect;
            y = (screenshotY - renderer.viewTransformation.viewOffsetY) / aspect;
        }

        int ix = Math.max(0, Math.min(xServer.screenInfo.width - 1, Math.round(x)));
        int iy = Math.max(0, Math.min(xServer.screenInfo.height - 1, Math.round(y)));
        return new int[]{ix, iy};
    }

    private Pointer.Button pointerButton(int browserButton) {
        if (browserButton == 2) return Pointer.Button.BUTTON_RIGHT;
        if (browserButton == 1) return Pointer.Button.BUTTON_MIDDLE;
        return Pointer.Button.BUTTON_LEFT;
    }

    private void typeText(String text) throws Exception {
        for (int i = 0; i < text.length(); i++) {
            String ch = String.valueOf(text.charAt(i));
            KeyEvent keyEvent = new KeyEvent(SystemClock.uptimeMillis(), ch, -1, 0);
            xServer.keyboard.onKeyEvent(keyEvent);
        }
    }

    private void injectKey(String key, boolean down) {
        int keyCode = keyCode(key);
        if (keyCode == KeyEvent.KEYCODE_UNKNOWN) return;

        long now = SystemClock.uptimeMillis();
        KeyEvent event = new KeyEvent(
            now,
            now,
            down ? KeyEvent.ACTION_DOWN : KeyEvent.ACTION_UP,
            keyCode,
            0
        );
        xServer.keyboard.onKeyEvent(event);
    }

    private int keyCode(String key) {
        String k = key != null ? key.toUpperCase(Locale.ENGLISH) : "";
        switch (k) {
            case "ENTER": case "RETURN": return KeyEvent.KEYCODE_ENTER;
            case "ESC": case "ESCAPE": return KeyEvent.KEYCODE_ESCAPE;
            case "TAB": return KeyEvent.KEYCODE_TAB;
            case " ": case "SPACE": return KeyEvent.KEYCODE_SPACE;
            case "BACKSPACE": return KeyEvent.KEYCODE_DEL;
            case "DELETE": return KeyEvent.KEYCODE_FORWARD_DEL;
            case "ARROWLEFT": case "LEFT": return KeyEvent.KEYCODE_DPAD_LEFT;
            case "ARROWRIGHT": case "RIGHT": return KeyEvent.KEYCODE_DPAD_RIGHT;
            case "ARROWUP": case "UP": return KeyEvent.KEYCODE_DPAD_UP;
            case "ARROWDOWN": case "DOWN": return KeyEvent.KEYCODE_DPAD_DOWN;
            case "CONTROL": case "CTRL": return KeyEvent.KEYCODE_CTRL_LEFT;
            case "SHIFT": return KeyEvent.KEYCODE_SHIFT_LEFT;
            case "ALT": return KeyEvent.KEYCODE_ALT_LEFT;
            case "META": case "OS": return KeyEvent.KEYCODE_META_LEFT;
            case "HOME": return KeyEvent.KEYCODE_MOVE_HOME;
            case "END": return KeyEvent.KEYCODE_MOVE_END;
            case "PAGEUP": return KeyEvent.KEYCODE_PAGE_UP;
            case "PAGEDOWN": return KeyEvent.KEYCODE_PAGE_DOWN;
            case "INSERT": return KeyEvent.KEYCODE_INSERT;
            case "F1": return KeyEvent.KEYCODE_F1;
            case "F2": return KeyEvent.KEYCODE_F2;
            case "F3": return KeyEvent.KEYCODE_F3;
            case "F4": return KeyEvent.KEYCODE_F4;
            case "F5": return KeyEvent.KEYCODE_F5;
            case "F6": return KeyEvent.KEYCODE_F6;
            case "F7": return KeyEvent.KEYCODE_F7;
            case "F8": return KeyEvent.KEYCODE_F8;
            case "F9": return KeyEvent.KEYCODE_F9;
            case "F10": return KeyEvent.KEYCODE_F10;
            case "F11": return KeyEvent.KEYCODE_F11;
            case "F12": return KeyEvent.KEYCODE_F12;
        }

        if (k.length() == 1) {
            char ch = k.charAt(0);
            if (ch >= 'A' && ch <= 'Z') return KeyEvent.KEYCODE_A + (ch - 'A');
            if (ch >= '0' && ch <= '9') return KeyEvent.KEYCODE_0 + (ch - '0');
        }
        return KeyEvent.KEYCODE_UNKNOWN;
    }

    private byte[] captureJpeg() throws Exception {
        synchronized (frameLock) {
            CountDownLatch latch = new CountDownLatch(1);
            final byte[][] result = new byte[1][];

            xServerView.queueEvent(() -> {
                try {
                    int width = Math.max(1, xServerView.getWidth());
                    int height = Math.max(1, xServerView.getHeight());
                    int[] pixels = xServerView.getRenderer().getPixelsARGB(0, 0, width, height, true);
                    Bitmap bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888);

                    ByteArrayOutputStream out = new ByteArrayOutputStream();
                    bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out);
                    bitmap.recycle();
                    result[0] = out.toByteArray();
                }
                catch (Exception ignored) {}
                finally {
                    latch.countDown();
                }
            });
            xServerView.requestRender();

            if (!latch.await(3, TimeUnit.SECONDS)) return null;
            return result[0];
        }
    }

    private void sendText(Socket socket, int code, String contentType, String text) throws Exception {
        sendBytes(
            socket,
            code,
            contentType,
            text.getBytes(StandardCharsets.UTF_8),
            "Cache-Control: no-store\r\n"
        );
    }

    private void sendBytes(Socket socket, int code, String contentType, byte[] bytes, String extraHeaders) throws Exception {
        String reason = code == 200 ? "OK" :
                        code == 400 ? "Bad Request" :
                        code == 403 ? "Forbidden" :
                        code == 404 ? "Not Found" :
                        code == 503 ? "Service Unavailable" : "OK";

        OutputStream out = socket.getOutputStream();
        String headers =
            "HTTP/1.1 " + code + " " + reason + "\r\n" +
            "Content-Type: " + contentType + "\r\n" +
            "Content-Length: " + bytes.length + "\r\n" +
            extraHeaders +
            "Connection: close\r\n\r\n";
        out.write(headers.getBytes(StandardCharsets.UTF_8));
        out.write(bytes);
        out.flush();
    }

    private String pageHtml() {
        return "<!doctype html>" +
            "<html><head><meta charset='utf-8'>" +
            "<meta name='viewport' content='width=device-width,initial-scale=1,user-scalable=no'>" +
            "<title>Diana PC Remote</title>" +
            "<style>" +
            "*{box-sizing:border-box}html,body{margin:0;background:#0d0f12;color:#eee;font-family:system-ui,sans-serif;height:100%;overflow:hidden}" +
            "#top{height:52px;display:flex;align-items:center;gap:10px;padding:8px 12px;background:#16191e;border-bottom:1px solid #2c3138}" +
            "#top b{white-space:nowrap}#status{font-size:13px;color:#aab3c0;flex:1}" +
            "button,input{font:inherit;border-radius:8px;border:1px solid #3a414b;background:#20252c;color:#fff;padding:8px 10px}" +
            "button{cursor:pointer}#pin{width:96px}" +
            "#stage{height:calc(100% - 52px);display:flex;align-items:center;justify-content:center;background:#090a0c;overflow:hidden}" +
            "#screen{max-width:100%;max-height:100%;width:auto;height:auto;display:block;outline:none;user-select:none;-webkit-user-drag:none;touch-action:none;cursor:default}" +
            "#gate{position:absolute;inset:52px 0 0 0;display:flex;align-items:center;justify-content:center;background:#090a0c}" +
            "#card{width:min(390px,90%);padding:24px;background:#171a20;border:1px solid #303640;border-radius:14px}" +
            "#card h2{margin:0 0 8px}#card p{color:#aab3c0;line-height:1.45}" +
            "#card input{width:100%;font-size:22px;text-align:center;letter-spacing:5px;margin:8px 0 10px}" +
            "#card button{width:100%;padding:11px}.hide{display:none!important}" +
            "#hint{position:absolute;left:12px;bottom:10px;background:#000a;padding:6px 9px;border-radius:7px;font-size:12px;color:#cbd3df;pointer-events:none}" +
            "</style></head><body>" +
            "<div id='top'><b>Diana PC</b><span id='status'>Digite o PIN</span><button id='reconnect' type='button'>Reconectar</button></div>" +
            "<div id='stage'><img id='screen' tabindex='0' draggable='false' alt='Tela do Diana PC'><div id='hint' class='hide'>Clique na tela para usar teclado e mouse</div></div>" +
            "<div id='gate'><div id='card'><h2>Remote Web</h2><p>Digite o PIN mostrado no celular. Use somente na sua rede Wi-Fi/hotspot.</p><input id='pin' inputmode='numeric' maxlength='6' placeholder='000000'><button id='connect' type='button'>Conectar</button><p id='error'></p></div></div>" +
            "<script>" +
            "(()=>{const gate=document.getElementById('gate'),pinEl=document.getElementById('pin'),connect=document.getElementById('connect'),screen=document.getElementById('screen'),status=document.getElementById('status'),err=document.getElementById('error'),hint=document.getElementById('hint'),reconnect=document.getElementById('reconnect');" +
            "let pin='',connected=false,frameBusy=false,lastMove=0,movePending=null,held=new Set(),frames=0,lastFps=performance.now(),eventQueue=Promise.resolve();" +
            "const enc=encodeURIComponent;" +
            "function post(ev){if(!connected)return Promise.resolve();eventQueue=eventQueue.then(()=>fetch('/event?pin='+enc(pin),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(ev),cache:'no-store'})).then(r=>{if(!r.ok)throw new Error('input');}).catch(()=>{status.textContent='Falha no controle • tentando reconectar';});return eventQueue;}" +
            "function pos(e){const r=screen.getBoundingClientRect();return{x:Math.max(0,Math.min(1,(e.clientX-r.left)/Math.max(1,r.width))),y:Math.max(0,Math.min(1,(e.clientY-r.top)/Math.max(1,r.height)))}}" +
            "function nextFrame(){if(!connected||frameBusy)return;frameBusy=true;const url='/frame.jpg?pin='+enc(pin)+'&t='+Date.now();screen.onload=()=>{frameBusy=false;frames++;const now=performance.now();if(now-lastFps>1000){status.textContent='Conectado • '+frames+' FPS';frames=0;lastFps=now;}setTimeout(nextFrame,35)};screen.onerror=()=>{frameBusy=false;status.textContent='Reconectando...';setTimeout(nextFrame,500)};screen.src=url}" +
            "async function doConnect(){pin=pinEl.value.trim();if(!/^\\d{6}$/.test(pin)){err.textContent='PIN precisa ter 6 números.';return;}err.textContent='Conectando...';try{const r=await fetch('/ping?pin='+enc(pin),{cache:'no-store'});if(!r.ok)throw 0;connected=true;gate.classList.add('hide');hint.classList.remove('hide');status.textContent='Conectado';screen.focus();nextFrame();}catch(e){err.textContent='PIN inválido ou conexão recusada.'}}" +
            "connect.addEventListener('click',doConnect);pinEl.addEventListener('keydown',e=>{if(e.key==='Enter')doConnect()});" +
            "reconnect.addEventListener('click',()=>{connected=false;gate.classList.remove('hide');err.textContent='';status.textContent='Digite o PIN';pinEl.focus()});" +
            "screen.addEventListener('pointerdown',e=>{e.preventDefault();screen.setPointerCapture?.(e.pointerId);screen.focus();hint.classList.add('hide');const p=pos(e);held.add(e.button);status.textContent='Mouse conectado';post({type:'mouse_down',button:e.button,x:p.x,y:p.y})});" +
            "screen.addEventListener('pointerup',e=>{e.preventDefault();const p=pos(e);held.delete(e.button);post({type:'mouse_up',button:e.button,x:p.x,y:p.y})});" +
            "screen.addEventListener('pointercancel',e=>{const p=pos(e);for(const b of held)post({type:'mouse_up',button:b,x:p.x,y:p.y});held.clear()});" +
            "screen.addEventListener('pointermove',e=>{const now=performance.now();movePending={...pos(e),type:'move'};if(now-lastMove<25)return;lastMove=now;const m=movePending;movePending=null;post(m)});" +
            "screen.addEventListener('wheel',e=>{e.preventDefault();post({type:'wheel',dy:e.deltaY})},{passive:false});" +
            "screen.addEventListener('contextmenu',e=>e.preventDefault());" +
            "function special(k){return ['Enter','Escape','Tab','Backspace','Delete','ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Control','Shift','Alt','Meta','Home','End','PageUp','PageDown','Insert','F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12'].includes(k)}" +
            "screen.addEventListener('keydown',e=>{if(!connected)return;const modified=e.ctrlKey||e.altKey||e.metaKey;if((e.key.length===1&&!modified)){e.preventDefault();post({type:'text',text:e.key});return;}if(special(e.key)||modified){e.preventDefault();if(!e.repeat)post({type:'key_down',key:e.key})}});" +
            "screen.addEventListener('keyup',e=>{if(!connected)return;const modified=e.ctrlKey||e.altKey||e.metaKey;if(special(e.key)||modified||e.key.length===1){e.preventDefault();post({type:'key_up',key:e.key})}});" +
            "window.addEventListener('blur',()=>{for(const b of held)post({type:'mouse_up',button:b,x:0,y:0});held.clear()});pinEl.focus();" +
            "})()" +
            "</script></body></html>";
    }

    private void status(String message) {
        if (listener != null) activity.runOnUiThread(() -> listener.onStatus(message));
    }

    private void error(String message) {
        if (listener != null) activity.runOnUiThread(() -> listener.onError(message));
    }

    private String safeMessage(Exception e) {
        return e.getMessage() != null ? e.getMessage() : e.toString();
    }
}
