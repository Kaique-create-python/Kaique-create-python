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

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public class AstraController {
    public interface Listener {
        void onStatus(String status);
        void onFinished(String message);
        void onError(String error);
    }

    private static final String ENDPOINT = "https://api.openai.com/v1/responses";
    private static final String MODEL = "gpt-6-astra";
    private static final int MAX_STEPS = 30;

    private final Activity activity;
    private final XServer xServer;
    private final XServerView xServerView;
    private final Listener listener;
    private volatile boolean stopRequested;
    private Thread worker;

    public AstraController(Activity activity, XServer xServer, XServerView xServerView, Listener listener) {
        this.activity = activity;
        this.xServer = xServer;
        this.xServerView = xServerView;
        this.listener = listener;
    }

    public synchronized void start(String apiKey, String task) {
        stop();
        stopRequested = false;
        worker = new Thread(() -> runLoop(apiKey.trim(), task.trim()), "DianaAstra");
        worker.start();
    }

    public synchronized void stop() {
        stopRequested = true;
        if (worker != null) {
            worker.interrupt();
            worker = null;
        }
        status("Astra parado");
    }

    public boolean isRunning() {
        return worker != null && worker.isAlive() && !stopRequested;
    }

    private void runLoop(String apiKey, String task) {
        try {
            if (apiKey.isEmpty()) throw new IllegalArgumentException("Digite sua chave da API.");
            if (task.isEmpty()) throw new IllegalArgumentException("Digite o que o Astra deve fazer.");

            status("Astra iniciando...");
            JSONObject request = new JSONObject();
            request.put("model", MODEL);
            request.put("instructions",
                "Você controla apenas o desktop Wine/Diana PC mostrado pelas capturas. " +
                "Não tente sair para o Android, não abra apps Android, não faça compras, pagamentos, " +
                "envio de mensagens/arquivos, exclusões destrutivas, mudanças de conta ou entrada de senhas. " +
                "Se uma tarefa exigir uma dessas ações, pare e explique que precisa da confirmação do usuário. " +
                "Use a ferramenta computer para interagir com a interface e confira o resultado por screenshots.");
            request.put("input", task);
            request.put("tools", new JSONArray().put(new JSONObject().put("type", "computer")));
            request.put("reasoning", new JSONObject().put("effort", "medium"));

            JSONObject response = post(apiKey, request);
            int steps = 0;

            while (!stopRequested && steps++ < MAX_STEPS) {
                String responseId = response.optString("id", "");
                JSONArray output = response.optJSONArray("output");
                JSONObject computerCall = findComputerCall(output);

                if (computerCall == null) {
                    String text = extractText(output);
                    if (text.isEmpty()) text = "Tarefa encerrada.";
                    finish(text);
                    return;
                }

                String callId = computerCall.optString("call_id", "");
                JSONArray actions = computerCall.optJSONArray("actions");
                if (actions != null) {
                    for (int i = 0; i < actions.length() && !stopRequested; i++) {
                        JSONObject action = actions.optJSONObject(i);
                        if (action != null) executeAction(action);
                    }
                }

                if (stopRequested) return;

                status("Astra verificando a tela...");
                String screenshot = captureScreenshotBase64();
                if (screenshot == null) throw new Exception("Não consegui capturar a tela do Diana PC.");

                JSONObject screenshotOutput = new JSONObject()
                    .put("type", "computer_screenshot")
                    .put("image_url", "data:image/png;base64," + screenshot)
                    .put("detail", "original");

                JSONObject callOutput = new JSONObject()
                    .put("type", "computer_call_output")
                    .put("call_id", callId)
                    .put("output", screenshotOutput);

                JSONObject next = new JSONObject();
                next.put("model", MODEL);
                next.put("tools", new JSONArray().put(new JSONObject().put("type", "computer")));
                next.put("previous_response_id", responseId);
                next.put("input", new JSONArray().put(callOutput));

                response = post(apiKey, next);
            }

            if (!stopRequested) finish("O Astra atingiu o limite de passos desta execução.");
        }
        catch (InterruptedException ignored) {}
        catch (Exception e) {
            if (!stopRequested) error(e.getMessage() != null ? e.getMessage() : e.toString());
        }
        finally {
            worker = null;
        }
    }

    private JSONObject post(String apiKey, JSONObject body) throws Exception {
        HttpURLConnection conn = (HttpURLConnection)new URL(ENDPOINT).openConnection();
        conn.setConnectTimeout(30000);
        conn.setReadTimeout(120000);
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Authorization", "Bearer " + apiKey);
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setRequestProperty("Accept", "application/json");

        try (OutputStream out = conn.getOutputStream()) {
            out.write(body.toString().getBytes(StandardCharsets.UTF_8));
        }

        int code = conn.getResponseCode();
        InputStream stream = code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream();
        String payload = readAll(stream);

        if (code < 200 || code >= 300) {
            try {
                JSONObject obj = new JSONObject(payload);
                JSONObject err = obj.optJSONObject("error");
                if (err != null) throw new Exception("API: " + err.optString("message", "erro " + code));
            }
            catch (org.json.JSONException ignored) {}
            throw new Exception("API retornou HTTP " + code);
        }

        return new JSONObject(payload);
    }

    private String readAll(InputStream in) throws Exception {
        if (in == null) return "";
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
        }
        return sb.toString();
    }

    private JSONObject findComputerCall(JSONArray output) {
        if (output == null) return null;
        for (int i = 0; i < output.length(); i++) {
            JSONObject item = output.optJSONObject(i);
            if (item != null && "computer_call".equals(item.optString("type"))) return item;
        }
        return null;
    }

    private String extractText(JSONArray output) {
        if (output == null) return "";
        StringBuilder result = new StringBuilder();

        for (int i = 0; i < output.length(); i++) {
            JSONObject item = output.optJSONObject(i);
            if (item == null) continue;
            JSONArray content = item.optJSONArray("content");
            if (content == null) continue;

            for (int j = 0; j < content.length(); j++) {
                JSONObject part = content.optJSONObject(j);
                if (part == null) continue;
                if ("output_text".equals(part.optString("type"))) {
                    if (result.length() > 0) result.append("\n");
                    result.append(part.optString("text", ""));
                }
            }
        }
        return result.toString().trim();
    }

    private void executeAction(JSONObject action) throws Exception {
        String type = action.optString("type", "");
        status("Astra: " + readableAction(type));

        switch (type) {
            case "screenshot":
                break;

            case "move": {
                int[] p = toXServer(action.optInt("x"), action.optInt("y"));
                xServer.injectPointerMove(p[0], p[1]);
                sleep(80);
                break;
            }

            case "click":
                click(action.optInt("x"), action.optInt("y"), action.optString("button", "left"), 1);
                break;

            case "double_click":
                click(action.optInt("x"), action.optInt("y"), action.optString("button", "left"), 2);
                break;

            case "drag":
                drag(action);
                break;

            case "scroll":
                scroll(action);
                break;

            case "type":
                typeText(action.optString("text", ""));
                break;

            case "keypress":
                keypress(action.optJSONArray("keys"));
                break;

            case "wait":
                sleep(Math.max(250, Math.min(5000, action.optInt("ms", 1000))));
                break;

            default:
                break;
        }
    }

    private String readableAction(String type) {
        switch (type) {
            case "click": return "clicando";
            case "double_click": return "duplo clique";
            case "drag": return "arrastando";
            case "scroll": return "rolando";
            case "type": return "digitando";
            case "keypress": return "tecla";
            case "move": return "movendo o mouse";
            case "screenshot": return "olhando a tela";
            case "wait": return "aguardando";
            default: return type;
        }
    }

    private void click(int sx, int sy, String buttonName, int count) throws Exception {
        int[] p = toXServer(sx, sy);
        Pointer.Button button = pointerButton(buttonName);
        xServer.injectPointerMove(p[0], p[1]);

        for (int i = 0; i < count; i++) {
            xServer.injectPointerButtonPress(button);
            sleep(55);
            xServer.injectPointerButtonRelease(button);
            if (i + 1 < count) sleep(100);
        }
        sleep(120);
    }

    private void drag(JSONObject action) throws Exception {
        JSONArray path = action.optJSONArray("path");
        if (path != null && path.length() > 0) {
            JSONObject first = path.optJSONObject(0);
            if (first == null) return;
            int[] start = toXServer(first.optInt("x"), first.optInt("y"));
            xServer.injectPointerMove(start[0], start[1]);
            xServer.injectPointerButtonPress(Pointer.Button.BUTTON_LEFT);

            for (int i = 1; i < path.length() && !stopRequested; i++) {
                JSONObject point = path.optJSONObject(i);
                if (point == null) continue;
                int[] p = toXServer(point.optInt("x"), point.optInt("y"));
                xServer.injectPointerMove(p[0], p[1]);
                sleep(35);
            }

            xServer.injectPointerButtonRelease(Pointer.Button.BUTTON_LEFT);
            sleep(150);
            return;
        }

        int[] start = toXServer(action.optInt("x"), action.optInt("y"));
        int[] end = toXServer(action.optInt("end_x", action.optInt("x")), action.optInt("end_y", action.optInt("y")));
        xServer.injectPointerMove(start[0], start[1]);
        xServer.injectPointerButtonPress(Pointer.Button.BUTTON_LEFT);

        for (int i = 1; i <= 12; i++) {
            int x = start[0] + (end[0] - start[0]) * i / 12;
            int y = start[1] + (end[1] - start[1]) * i / 12;
            xServer.injectPointerMove(x, y);
            sleep(30);
        }

        xServer.injectPointerButtonRelease(Pointer.Button.BUTTON_LEFT);
        sleep(150);
    }

    private void scroll(JSONObject action) throws Exception {
        int[] p = toXServer(action.optInt("x"), action.optInt("y"));
        xServer.injectPointerMove(p[0], p[1]);

        int sy = action.optInt("scroll_y", 0);
        int sx = action.optInt("scroll_x", 0);
        int amount = Math.max(Math.abs(sy), Math.abs(sx));
        int ticks = Math.max(1, Math.min(12, amount / 100 + 1));

        Pointer.Button button = sy >= 0 ? Pointer.Button.BUTTON_SCROLL_DOWN : Pointer.Button.BUTTON_SCROLL_UP;
        for (int i = 0; i < ticks; i++) {
            xServer.injectPointerButtonPress(button);
            xServer.injectPointerButtonRelease(button);
            sleep(40);
        }
    }

    private void typeText(String text) throws Exception {
        for (int i = 0; i < text.length() && !stopRequested; i++) {
            String ch = String.valueOf(text.charAt(i));
            KeyEvent event = new KeyEvent(SystemClock.uptimeMillis(), ch, -1, 0);
            xServer.keyboard.onKeyEvent(event);
            sleep(12);
        }
    }

    private void keypress(JSONArray keys) throws Exception {
        if (keys == null || keys.length() == 0) return;

        int[] codes = new int[keys.length()];
        for (int i = 0; i < keys.length(); i++) codes[i] = keyCode(keys.optString(i));

        long now = SystemClock.uptimeMillis();
        for (int code : codes) {
            if (code == KeyEvent.KEYCODE_UNKNOWN) continue;
            xServer.keyboard.onKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_DOWN, code, 0));
        }

        sleep(60);
        for (int i = codes.length - 1; i >= 0; i--) {
            if (codes[i] == KeyEvent.KEYCODE_UNKNOWN) continue;
            xServer.keyboard.onKeyEvent(new KeyEvent(now, SystemClock.uptimeMillis(), KeyEvent.ACTION_UP, codes[i], 0));
        }
        sleep(80);
    }

    private int keyCode(String key) {
        String k = key.toUpperCase(Locale.ENGLISH).replace("ARROW", "");
        switch (k) {
            case "ENTER": case "RETURN": return KeyEvent.KEYCODE_ENTER;
            case "ESC": case "ESCAPE": return KeyEvent.KEYCODE_ESCAPE;
            case "TAB": return KeyEvent.KEYCODE_TAB;
            case "SPACE": return KeyEvent.KEYCODE_SPACE;
            case "BACKSPACE": return KeyEvent.KEYCODE_DEL;
            case "DELETE": return KeyEvent.KEYCODE_FORWARD_DEL;
            case "LEFT": return KeyEvent.KEYCODE_DPAD_LEFT;
            case "RIGHT": return KeyEvent.KEYCODE_DPAD_RIGHT;
            case "UP": return KeyEvent.KEYCODE_DPAD_UP;
            case "DOWN": return KeyEvent.KEYCODE_DPAD_DOWN;
            case "CTRL": case "CONTROL": return KeyEvent.KEYCODE_CTRL_LEFT;
            case "SHIFT": return KeyEvent.KEYCODE_SHIFT_LEFT;
            case "ALT": return KeyEvent.KEYCODE_ALT_LEFT;
            case "HOME": return KeyEvent.KEYCODE_MOVE_HOME;
            case "END": return KeyEvent.KEYCODE_MOVE_END;
            case "PAGEUP": return KeyEvent.KEYCODE_PAGE_UP;
            case "PAGEDOWN": return KeyEvent.KEYCODE_PAGE_DOWN;
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

    private Pointer.Button pointerButton(String name) {
        if ("right".equalsIgnoreCase(name)) return Pointer.Button.BUTTON_RIGHT;
        if ("middle".equalsIgnoreCase(name)) return Pointer.Button.BUTTON_MIDDLE;
        return Pointer.Button.BUTTON_LEFT;
    }

    private int[] toXServer(int screenshotX, int screenshotY) {
        GLRenderer renderer = xServerView.getRenderer();
        int width = Math.max(1, xServerView.getWidth());
        int height = Math.max(1, xServerView.getHeight());

        float x;
        float y;

        if (renderer.isFullscreen()) {
            x = screenshotX * (xServer.screenInfo.width / (float)width);
            y = screenshotY * (xServer.screenInfo.height / (float)height);
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

    private String captureScreenshotBase64() throws Exception {
        CountDownLatch latch = new CountDownLatch(1);
        final String[] result = new String[1];

        xServerView.queueEvent(() -> {
            try {
                int width = Math.max(1, xServerView.getWidth());
                int height = Math.max(1, xServerView.getHeight());
                int[] pixels = xServerView.getRenderer().getPixelsARGB(0, 0, width, height, true);
                Bitmap bitmap = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888);

                ByteArrayOutputStream out = new ByteArrayOutputStream();
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
                bitmap.recycle();
                result[0] = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP);
            }
            catch (Exception ignored) {}
            finally {
                latch.countDown();
            }
        });
        xServerView.requestRender();

        if (!latch.await(5, TimeUnit.SECONDS)) return null;
        return result[0];
    }

    private void sleep(long ms) throws InterruptedException {
        if (stopRequested) throw new InterruptedException();
        Thread.sleep(ms);
    }

    private void status(String message) {
        if (listener != null) activity.runOnUiThread(() -> listener.onStatus(message));
    }

    private void finish(String message) {
        if (listener != null) activity.runOnUiThread(() -> listener.onFinished(message));
    }

    private void error(String message) {
        if (listener != null) activity.runOnUiThread(() -> listener.onError(message));
    }
}
