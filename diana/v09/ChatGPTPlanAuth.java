package com.winlator.core;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Base64;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.math.BigInteger;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URL;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.Signature;
import java.security.spec.RSAPublicKeySpec;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

public class ChatGPTPlanAuth {
    public interface Listener {
        void onStatus(String message);
        void onSignedIn(String email);
        void onError(String error);
    }

    private static final String AUTH_ENDPOINT = "https://auth.openai.com/api/accounts/authorize";
    private static final String TOKEN_ENDPOINT = "https://auth.openai.com/api/accounts/oauth/token";
    private static final String JWKS_ENDPOINT = "https://auth.openai.com/.well-known/jwks.json";
    private static final String RESOURCE = "https://api.openai.com/v1";
    private static final String SCOPE = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct";
    private static final String PREFS = "diana_chatgpt_plan";
    private static final String DYNAMIC_CLIENT = "dynamic_agent_client";

    private final Activity activity;
    private final SharedPreferences prefs;
    private final AtomicBoolean signingIn = new AtomicBoolean(false);

    public ChatGPTPlanAuth(Activity activity) {
        this.activity = activity;
        this.prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (!prefs.contains("host_id")) {
            prefs.edit().putString("host_id", "urn:uuid:" + UUID.randomUUID().toString()).apply();
        }
    }

    public boolean isSignedIn() {
        String access = prefs.getString("access_token", "");
        String refresh = prefs.getString("refresh_token", "");
        String scope = prefs.getString("scope", "");
        return (!access.isEmpty() || !refresh.isEmpty()) && scope.contains("chatgpt.tokens.use.direct");
    }

    public String getEmail() {
        return prefs.getString("email", "");
    }

    public void signIn(Listener listener) {
        if (!signingIn.compareAndSet(false, true)) {
            listener.onError("Já existe um login em andamento.");
            return;
        }

        new Thread(() -> {
            ServerSocket server = null;
            try {
                status(listener, "Preparando login com ChatGPT...");

                String state = randomValue(32);
                String nonce = randomValue(32);
                String verifier = randomValue(64);
                String challenge = base64Url(MessageDigest.getInstance("SHA-256")
                    .digest(verifier.getBytes(StandardCharsets.US_ASCII)));

                server = new ServerSocket(0, 1, InetAddress.getByName("127.0.0.1"));
                server.setSoTimeout(180000);
                int port = server.getLocalPort();
                String redirectUri = "http://127.0.0.1:" + port + "/auth/callback";

                String savedClientId = prefs.getString("client_id", "");
                String clientId = savedClientId.isEmpty() ? DYNAMIC_CLIENT : savedClientId;
                String hostId = prefs.getString("host_id", "");

                Uri.Builder auth = Uri.parse(AUTH_ENDPOINT).buildUpon()
                    .appendQueryParameter("client_id", clientId)
                    .appendQueryParameter("response_type", "code")
                    .appendQueryParameter("redirect_uri", redirectUri)
                    .appendQueryParameter("scope", SCOPE)
                    .appendQueryParameter("resource", RESOURCE)
                    .appendQueryParameter("state", state)
                    .appendQueryParameter("nonce", nonce)
                    .appendQueryParameter("code_challenge_method", "S256")
                    .appendQueryParameter("code_challenge", challenge)
                    .appendQueryParameter("ext_agent_host_id", hostId);

                if (savedClientId.isEmpty()) {
                    auth.appendQueryParameter("agent_name_hint", "Diana PC");
                }
                else {
                    String idToken = prefs.getString("id_token", "");
                    String email = prefs.getString("email", "");
                    if (!idToken.isEmpty()) auth.appendQueryParameter("id_token_hint", idToken);
                    if (!email.isEmpty()) auth.appendQueryParameter("login_hint", email);
                }

                Intent browser = new Intent(Intent.ACTION_VIEW, auth.build());
                browser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.runOnUiThread(() -> {
                    try {
                        activity.startActivity(browser);
                        listener.onStatus("Faça login no ChatGPT e autorize o Diana PC.");
                    }
                    catch (Exception e) {
                        listener.onError("Não consegui abrir o navegador.");
                    }
                });

                Socket socket = server.accept();
                BufferedReader reader = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8));
                String requestLine = reader.readLine();
                if (requestLine == null || !requestLine.startsWith("GET ")) throw new Exception("Callback inválido.");

                String target = requestLine.split(" ")[1];
                while (true) {
                    String line = reader.readLine();
                    if (line == null || line.isEmpty()) break;
                }

                String html = "<html><body style='font-family:sans-serif;background:#111;color:#fff;padding:32px'>" +
                    "<h2>Diana PC</h2><p>Login recebido. Você já pode voltar para o Diana PC.</p></body></html>";
                byte[] bytes = html.getBytes(StandardCharsets.UTF_8);
                OutputStream out = socket.getOutputStream();
                out.write(("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: " +
                    bytes.length + "\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.UTF_8));
                out.write(bytes);
                out.flush();
                socket.close();

                Map<String, String> params = parseQuery(target);
                if (!state.equals(params.get("state"))) throw new Exception("O login não pôde ser verificado.");
                if (params.containsKey("error")) throw new Exception("Login cancelado ou permissão não autorizada.");

                String code = params.get("code");
                if (code == null || code.isEmpty()) throw new Exception("O login não retornou um código.");

                String issuedClientId = params.get("client_id");
                if (savedClientId.isEmpty()) {
                    if (issuedClientId == null || issuedClientId.isEmpty()) {
                        throw new Exception("O ChatGPT não retornou o client ID do Diana PC.");
                    }
                }
                else {
                    issuedClientId = savedClientId;
                    String returnedClient = params.get("client_id");
                    if (returnedClient != null && !returnedClient.isEmpty() && !savedClientId.equals(returnedClient)) {
                        throw new Exception("O client ID retornado não corresponde à conta salva.");
                    }
                }

                status(listener, "Validando sua conta ChatGPT...");
                JSONObject token = exchangeCode(issuedClientId, code, verifier, redirectUri);
                String accessToken = token.optString("access_token", "");
                String refreshToken = token.optString("refresh_token", "");
                String idToken = token.optString("id_token", "");
                String scope = token.optString("scope", "");

                if (accessToken.isEmpty() || idToken.isEmpty()) throw new Exception("Tokens de login incompletos.");
                if (!scope.contains("chatgpt.tokens.use.direct")) {
                    throw new Exception("Sua conta não autorizou o uso do plano ChatGPT neste app.");
                }

                JSONObject identity = verifyIdToken(idToken, issuedClientId, nonce);
                String email = identity.optString("email", "");
                long expiresIn = token.optLong("expires_in", 3600L);
                long expiresAt = System.currentTimeMillis() + expiresIn * 1000L;

                SharedPreferences.Editor editor = prefs.edit()
                    .putString("client_id", issuedClientId)
                    .putString("access_token", accessToken)
                    .putString("refresh_token", refreshToken)
                    .putString("id_token", idToken)
                    .putString("scope", scope)
                    .putString("email", email)
                    .putString("subject", identity.optString("sub", ""))
                    .putLong("expires_at", expiresAt);
                editor.apply();

                activity.runOnUiThread(() -> listener.onSignedIn(email));
            }
            catch (Exception e) {
                activity.runOnUiThread(() -> listener.onError(e.getMessage() != null ? e.getMessage() : e.toString()));
            }
            finally {
                signingIn.set(false);
                if (server != null) {
                    try { server.close(); } catch (Exception ignored) {}
                }
            }
        }, "DianaChatGPTLogin").start();
    }

    public synchronized String getValidAccessToken() throws Exception {
        String access = prefs.getString("access_token", "");
        long expiresAt = prefs.getLong("expires_at", 0L);
        if (!access.isEmpty() && System.currentTimeMillis() < expiresAt - 60000L) return access;

        String refresh = prefs.getString("refresh_token", "");
        String clientId = prefs.getString("client_id", "");
        if (refresh.isEmpty() || clientId.isEmpty()) throw new Exception("Entre com ChatGPT novamente.");

        JSONObject token = postForm(TOKEN_ENDPOINT, mapOf(
            "grant_type", "refresh_token",
            "client_id", clientId,
            "refresh_token", refresh,
            "resource", RESOURCE
        ));

        String newAccess = token.optString("access_token", "");
        String newRefresh = token.optString("refresh_token", "");
        if (newAccess.isEmpty() || newRefresh.isEmpty()) throw new Exception("Não consegui renovar o login ChatGPT.");

        long expiresIn = token.optLong("expires_in", 3600L);
        SharedPreferences.Editor editor = prefs.edit()
            .putString("access_token", newAccess)
            .putString("refresh_token", newRefresh)
            .putLong("expires_at", System.currentTimeMillis() + expiresIn * 1000L);

        if (token.has("id_token")) editor.putString("id_token", token.optString("id_token", ""));
        if (token.has("scope")) editor.putString("scope", token.optString("scope", ""));
        editor.apply();
        return newAccess;
    }

    public String findAstraModel(String accessToken) throws Exception {
        HttpURLConnection conn = (HttpURLConnection)new URL("https://api.openai.com/v1/models").openConnection();
        conn.setConnectTimeout(30000);
        conn.setReadTimeout(60000);
        conn.setRequestMethod("GET");
        conn.setRequestProperty("Authorization", "Bearer " + accessToken);
        conn.setRequestProperty("Accept", "application/json");

        int code = conn.getResponseCode();
        String payload = readAll(code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream());
        if (code < 200 || code >= 300) throw new Exception("Não consegui consultar os modelos da sua conta.");

        JSONObject obj = new JSONObject(payload);
        JSONArray models = obj.optJSONArray("models");
        if (models == null) models = obj.optJSONArray("data");
        if (models == null) throw new Exception("Catálogo de modelos inválido.");

        for (int i = 0; i < models.length(); i++) {
            JSONObject model = models.optJSONObject(i);
            if (model == null) continue;
            String visibility = model.optString("visibility", "list");
            if (!"list".equals(visibility)) continue;

            String slug = model.optString("slug", model.optString("id", ""));
            String display = model.optString("display_name", "");
            String joined = (slug + " " + display).toLowerCase(Locale.ENGLISH);
            if (joined.contains("astra")) return slug;
        }

        throw new Exception("O Astra não apareceu no catálogo desta conta.");
    }

    public void signOut() {
        prefs.edit()
            .remove("access_token")
            .remove("refresh_token")
            .remove("id_token")
            .remove("scope")
            .remove("email")
            .remove("subject")
            .remove("expires_at")
            .apply();
    }

    private JSONObject exchangeCode(String clientId, String code, String verifier, String redirectUri) throws Exception {
        return postForm(TOKEN_ENDPOINT, mapOf(
            "grant_type", "authorization_code",
            "client_id", clientId,
            "code", code,
            "code_verifier", verifier,
            "redirect_uri", redirectUri,
            "resource", RESOURCE
        ));
    }

    private JSONObject postForm(String endpoint, Map<String, String> fields) throws Exception {
        StringBuilder form = new StringBuilder();
        for (Map.Entry<String, String> entry : fields.entrySet()) {
            if (form.length() > 0) form.append('&');
            form.append(URLEncoder.encode(entry.getKey(), "UTF-8"))
                .append('=')
                .append(URLEncoder.encode(entry.getValue(), "UTF-8"));
        }

        HttpURLConnection conn = (HttpURLConnection)new URL(endpoint).openConnection();
        conn.setConnectTimeout(30000);
        conn.setReadTimeout(60000);
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Accept", "application/json");
        conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");

        try (OutputStream out = conn.getOutputStream()) {
            out.write(form.toString().getBytes(StandardCharsets.UTF_8));
        }

        int code = conn.getResponseCode();
        String payload = readAll(code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream());
        if (code < 200 || code >= 300) {
            try {
                JSONObject obj = new JSONObject(payload);
                JSONObject err = obj.optJSONObject("error");
                if (err != null) throw new Exception(err.optString("message", "Falha no login ChatGPT."));
            }
            catch (org.json.JSONException ignored) {}
            throw new Exception("Falha no login ChatGPT (HTTP " + code + ").");
        }
        return new JSONObject(payload);
    }

    private JSONObject verifyIdToken(String idToken, String clientId, String nonce) throws Exception {
        String[] parts = idToken.split("\\.");
        if (parts.length != 3) throw new Exception("ID token inválido.");

        JSONObject header = new JSONObject(new String(Base64.decode(parts[0], Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP), StandardCharsets.UTF_8));
        JSONObject payload = new JSONObject(new String(Base64.decode(parts[1], Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP), StandardCharsets.UTF_8));

        if (!"RS256".equals(header.optString("alg"))) throw new Exception("Algoritmo de token não suportado.");
        String kid = header.optString("kid", "");
        if (kid.isEmpty()) throw new Exception("ID token sem kid.");

        JSONObject jwks = new JSONObject(httpGet(JWKS_ENDPOINT));
        JSONArray keys = jwks.optJSONArray("keys");
        JSONObject jwk = null;
        if (keys != null) {
            for (int i = 0; i < keys.length(); i++) {
                JSONObject k = keys.optJSONObject(i);
                if (k != null && kid.equals(k.optString("kid"))) {
                    jwk = k;
                    break;
                }
            }
        }
        if (jwk == null) throw new Exception("Chave de assinatura OpenAI não encontrada.");

        byte[] n = Base64.decode(jwk.getString("n"), Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
        byte[] e = Base64.decode(jwk.getString("e"), Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
        RSAPublicKeySpec spec = new RSAPublicKeySpec(new BigInteger(1, n), new BigInteger(1, e));
        java.security.PublicKey key = KeyFactory.getInstance("RSA").generatePublic(spec);

        Signature sig = Signature.getInstance("SHA256withRSA");
        sig.initVerify(key);
        sig.update((parts[0] + "." + parts[1]).getBytes(StandardCharsets.US_ASCII));
        byte[] signature = Base64.decode(parts[2], Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
        if (!sig.verify(signature)) throw new Exception("Assinatura do login ChatGPT inválida.");

        if (!"https://auth.openai.com".equals(payload.optString("iss"))) throw new Exception("Emissor do login inválido.");
        if (!audienceMatches(payload.opt("aud"), clientId)) throw new Exception("Audiência do login inválida.");
        if (payload.optLong("exp", 0L) < (System.currentTimeMillis() / 1000L) - 5L) throw new Exception("Login expirado.");
        if (!nonce.equals(payload.optString("nonce"))) throw new Exception("Nonce do login inválido.");
        if (payload.optString("sub", "").isEmpty()) throw new Exception("Identidade ChatGPT inválida.");
        return payload;
    }

    private boolean audienceMatches(Object aud, String clientId) {
        if (aud instanceof String) return clientId.equals(aud);
        if (aud instanceof JSONArray) {
            JSONArray arr = (JSONArray)aud;
            for (int i = 0; i < arr.length(); i++) if (clientId.equals(arr.optString(i))) return true;
        }
        return false;
    }

    private String httpGet(String endpoint) throws Exception {
        HttpURLConnection conn = (HttpURLConnection)new URL(endpoint).openConnection();
        conn.setConnectTimeout(30000);
        conn.setReadTimeout(60000);
        conn.setRequestMethod("GET");
        int code = conn.getResponseCode();
        String payload = readAll(code >= 200 && code < 300 ? conn.getInputStream() : conn.getErrorStream());
        if (code < 200 || code >= 300) throw new Exception("Falha ao validar o login ChatGPT.");
        return payload;
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

    private Map<String, String> parseQuery(String target) throws Exception {
        Map<String, String> result = new HashMap<>();
        int q = target.indexOf('?');
        if (q < 0) return result;
        String query = target.substring(q + 1);
        for (String part : query.split("&")) {
            int eq = part.indexOf('=');
            String key = eq >= 0 ? part.substring(0, eq) : part;
            String val = eq >= 0 ? part.substring(eq + 1) : "";
            result.put(URLDecoder.decode(key, "UTF-8"), URLDecoder.decode(val, "UTF-8"));
        }
        return result;
    }

    private Map<String, String> mapOf(String... values) {
        Map<String, String> map = new HashMap<>();
        for (int i = 0; i + 1 < values.length; i += 2) map.put(values[i], values[i + 1]);
        return map;
    }

    private String randomValue(int bytes) {
        byte[] data = new byte[bytes];
        new java.security.SecureRandom().nextBytes(data);
        return base64Url(data);
    }

    private String base64Url(byte[] data) {
        return Base64.encodeToString(data, Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
    }

    private void status(Listener listener, String message) {
        activity.runOnUiThread(() -> listener.onStatus(message));
    }
}
