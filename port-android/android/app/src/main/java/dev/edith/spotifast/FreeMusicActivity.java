package dev.edith.spotifast;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Supplementary legal streaming sources in the ORIGINAL SpotiFast Android app.
 * Audius: official public search + MP3 stream endpoint.
 * Jamendo: official read-only tracks API, requires user's developer Client ID.
 * YouTube: VISIBLE official iframe player only; NEVER extract/hide its audio,
 * download videos, remove ads or continue YouTube playback in background.
 */
public class FreeMusicActivity extends Activity {
    private static final int BG = Color.rgb(15, 18, 23);
    private static final int PANEL = Color.rgb(26, 30, 37);
    private static final int ACCENT = Color.rgb(25, 211, 101);
    private static final int WHITE = Color.rgb(240, 243, 245);
    private static final int MUTED = Color.rgb(155, 165, 175);

    private final ExecutorService network = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ArrayList<Track> results = new ArrayList<>();
    private LinearLayout root, list, playerBar;
    private TextView status, playing;
    private EditText searchBox, jamendoId, youtubeLink;
    private Button playPause;
    private MediaPlayer player;
    private WebView youtube;
    private int selected = -1;
    private int source = 0; // 0 Audius, 1 Jamendo, 2 YouTube
    private boolean loading = false;
    private int requestId = 0;

    private static class Track {
        String title, artist, url, provider;
        Track(String title, String artist, String url, String provider) {
            this.title = title;
            this.artist = artist;
            this.url = url;
            this.provider = provider;
        }
    }

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        getWindow().getDecorView().setSystemUiVisibility(0);
        build();
    }

    private int dp(float value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    private GradientDrawable bg(int color, int radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radius));
        return drawable;
    }

    private TextView text(String message, int sp, boolean bold, int color) {
        TextView view = new TextView(this);
        view.setText(message);
        view.setTextSize(sp);
        view.setTextColor(color);
        if (bold) view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return view;
    }

    private Button button(String label, boolean primary) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextSize(13);
        b.setAllCaps(false);
        b.setTextColor(primary ? Color.BLACK : WHITE);
        b.setBackground(bg(primary ? ACCENT : PANEL, 14));
        b.setPadding(dp(9), dp(5), dp(9), dp(5));
        b.setMinHeight(dp(44));
        return b;
    }

    private EditText input(String hint) {
        EditText edit = new EditText(this);
        edit.setSingleLine(true);
        edit.setTextSize(15);
        edit.setTextColor(WHITE);
        edit.setHintTextColor(MUTED);
        edit.setHint(hint);
        edit.setPadding(dp(14), dp(8), dp(14), dp(8));
        edit.setBackground(bg(PANEL, 14));
        return edit;
    }

    private LinearLayout column() {
        LinearLayout ll = new LinearLayout(this);
        ll.setOrientation(LinearLayout.VERTICAL);
        return ll;
    }

    private LinearLayout row() {
        LinearLayout ll = new LinearLayout(this);
        ll.setOrientation(LinearLayout.HORIZONTAL);
        ll.setGravity(Gravity.CENTER_VERTICAL);
        return ll;
    }

    private void spacer(LinearLayout parent, int height) {
        View v = new View(this);
        parent.addView(v, new LinearLayout.LayoutParams(1, dp(height)));
    }

    private void build() {
        root = column();
        root.setBackgroundColor(BG);
        root.setPadding(dp(14), dp(8), dp(14), dp(8));
        setContentView(root);

        LinearLayout heading = row();
        Button back = button("‹", false);
        heading.addView(back, new LinearLayout.LayoutParams(dp(48), dp(44)));
        back.setOnClickListener(v -> finish());
        TextView title = text("Músicas grátis", 22, true, WHITE);
        LinearLayout.LayoutParams titleP = new LinearLayout.LayoutParams(0, -2, 1);
        titleP.leftMargin = dp(12);
        heading.addView(title, titleP);
        root.addView(heading);
        spacer(root, 14);

        LinearLayout tabs = row();
        String[] names = {"Audius", "Jamendo", "YouTube"};
        for (int i=0; i<3; i++) {
            final int tab = i;
            Button b = button(names[i], i == source);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(46), 1);
            if (i > 0) lp.leftMargin = dp(6);
            tabs.addView(b, lp);
            b.setOnClickListener(v -> {
                stopYouTube();
                stopAudio();
                source = tab;
                selected = -1;
                build();
            });
        }
        root.addView(tabs);
        spacer(root, 12);

        TextView note = text(
            source == 0 ? "Audius • streaming gratuito de faixas públicas" :
            source == 1 ? "Jamendo • músicas independentes e suas licenças" :
            "YouTube • player de vídeo oficial e visível",
            12, false, MUTED);
        root.addView(note);
        spacer(root, 12);

        if (source == 2) {
            addYouTube();
        } else {
            addAudioSearch();
        }
    }

    private void addAudioSearch() {
        if (source == 1) {
            jamendoId = input("Seu Client ID do Jamendo Developer");
            jamendoId.setInputType(InputType.TYPE_CLASS_TEXT);
            jamendoId.setText(getPreferences(MODE_PRIVATE).getString("jamendo_client_id", ""));
            root.addView(jamendoId, new LinearLayout.LayoutParams(-1, dp(48)));
            spacer(root, 8);
        }

        LinearLayout query = row();
        searchBox = input("Buscar música ou artista");
        query.addView(searchBox, new LinearLayout.LayoutParams(0, dp(48), 1));
        Button go = button("Buscar", true);
        LinearLayout.LayoutParams gp = new LinearLayout.LayoutParams(dp(88), dp(48));
        gp.leftMargin = dp(8);
        query.addView(go, gp);
        root.addView(query);
        go.setOnClickListener(v -> search());
        searchBox.setOnEditorActionListener((v, actionId, event) -> {
            search();
            return true;
        });
        spacer(root, 12);

        status = text("Pesquise por músicas para começar.", 13, false, MUTED);
        root.addView(status);
        spacer(root, 8);
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        list = column();
        scroll.addView(list);
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));

        playerBar = column();
        playerBar.setBackground(bg(PANEL, 18));
        playerBar.setPadding(dp(12), dp(10), dp(12), dp(10));
        playing = text("Nenhuma faixa selecionada", 14, true, WHITE);
        playing.setSingleLine(true);
        playing.setEllipsize(android.text.TextUtils.TruncateAt.END);
        playerBar.addView(playing);
        LinearLayout controls = row();
        playPause = button("▶ / ❚❚", true);
        controls.addView(playPause, new LinearLayout.LayoutParams(0, dp(45), 1));
        Button next = button("Próxima ›", false);
        LinearLayout.LayoutParams np = new LinearLayout.LayoutParams(0, dp(45), 1);
        np.leftMargin = dp(8);
        controls.addView(next, np);
        spacer(playerBar, 8);
        playerBar.addView(controls);
        root.addView(playerBar);
        playPause.setOnClickListener(v -> toggle());
        next.setOnClickListener(v -> {
            if (results.isEmpty()) return;
            playAt((selected + 1) % results.size());
        });
    }

    private void search() {
        if (loading) return;
        String query = searchBox.getText().toString().trim();
        if (query.isEmpty()) {
            status.setText("Digite o nome de uma música.");
            return;
        }
        String client = "";
        if (source == 1) {
            client = jamendoId.getText().toString().trim();
            if (client.isEmpty()) {
                status.setText("Jamendo exige um Client ID gratuito do portal de desenvolvedores.");
                return;
            }
            getPreferences(MODE_PRIVATE).edit().putString("jamendo_client_id", client).apply();
        }
        final int kind = source, stamp = ++requestId;
        final String finalClient = client;
        status.setText("Pesquisando…");
        list.removeAllViews();
        loading = true;
        network.execute(() -> {
            try {
                String endpoint = kind == 0
                    ? "https://api.audius.co/v1/tracks/search?query=" + encode(query) + "&limit=25&app_name=SpotiFastAndroid"
                    : "https://api.jamendo.com/v3.0/tracks/?client_id=" + encode(finalClient)
                      + "&format=json&limit=25&search=" + encode(query) + "&audioformat=mp32";
                JSONObject data = fetch(endpoint);
                ArrayList<Track> found = new ArrayList<>();
                JSONArray songs = kind == 0 ? data.optJSONArray("data") : data.optJSONArray("results");
                if (songs == null) throw new Exception("Resposta da API inesperada");
                for (int i=0; i<songs.length(); i++) {
                    JSONObject song = songs.optJSONObject(i);
                    if (song == null) continue;
                    if (kind == 0) {
                        if (song.optBoolean("is_stream_gated", false)
                           || !song.optBoolean("streamable", true)) continue;
                        String id = song.optString("id");
                        if (!id.matches("[A-Za-z0-9_-]{1,100}")) continue;
                        String artist = song.optJSONObject("user") != null
                            ? song.optJSONObject("user").optString("name", "Audius") : "Audius";
                        found.add(new Track(song.optString("title", "Sem título"),
                            artist, "https://api.audius.co/v1/tracks/" + id
                              + "/stream?app_name=SpotiFastAndroid", "Audius"));
                    } else {
                        String url = song.optString("audio");
                        if (!url.startsWith("https://")) continue;
                        found.add(new Track(song.optString("name", "Sem título"),
                            song.optString("artist_name", "Jamendo"), url, "Jamendo"));
                    }
                }
                main.post(() -> {
                    loading = false;
                    if (kind != source || stamp != requestId) return;
                    results.clear();
                    results.addAll(found);
                    selected = -1;
                    status.setText(found.isEmpty() ? "Nenhum resultado reproduzível encontrado." :
                            found.size() + " faixas encontradas • toque para ouvir");
                    renderResults();
                });
            } catch (Exception e) {
                final String message = e.getMessage();
                main.post(() -> {
                    loading = false;
                    if (kind == source && stamp == requestId)
                        status.setText("Falha na busca: " + (message == null ? "sem conexão" : message));
                });
            }
        });
    }

    private static String encode(String s) throws Exception {
        return URLEncoder.encode(s, StandardCharsets.UTF_8.toString());
    }

    private static JSONObject fetch(String url) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(10000);
        c.setReadTimeout(15000);
        c.setRequestProperty("Accept", "application/json");
        c.setRequestProperty("User-Agent", "SpotiFastAndroid/0.14.1");
        try {
            int response = c.getResponseCode();
            if (response < 200 || response >= 300) throw new Exception("HTTP " + response);
            StringBuilder sb = new StringBuilder();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(
                    c.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                int size = 0;
                while ((line = r.readLine()) != null) {
                    size += line.length();
                    if (size > 1_000_000) throw new Exception("Resposta grande demais");
                    sb.append(line);
                }
            }
            return new JSONObject(sb.toString());
        } finally {
            c.disconnect();
        }
    }

    private void renderResults() {
        list.removeAllViews();
        for (int i=0; i<results.size(); i++) {
            final int index = i;
            Track t = results.get(i);
            LinearLayout item = row();
            item.setPadding(dp(12), dp(12), dp(12), dp(12));
            item.setBackground(bg(i == selected ? 0xff174c32 : PANEL, 12));
            LinearLayout info = column();
            TextView title = text(t.title, 15, true, WHITE);
            title.setMaxLines(2);
            info.addView(title);
            info.addView(text(t.artist + " • " + t.provider, 12, false, MUTED));
            item.addView(info, new LinearLayout.LayoutParams(0, -2, 1));
            TextView play = text("▶", 22, true, ACCENT);
            play.setGravity(Gravity.CENTER);
            item.addView(play, new LinearLayout.LayoutParams(dp(42), dp(48)));
            item.setOnClickListener(v -> playAt(index));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
            lp.bottomMargin = dp(7);
            list.addView(item, lp);
        }
    }

    private void playAt(int index) {
        if (index < 0 || index >= results.size()) return;
        stopAudio();
        selected = index;
        Track t = results.get(index);
        playing.setText(t.title + " — " + t.artist);
        status.setText("Carregando reprodução de " + t.provider + "…");
        renderResults();
        try {
            player = new MediaPlayer();
            player.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build());
            player.setOnPreparedListener(mp -> {
                if (mp != player) return;
                mp.start();
                status.setText("Tocando • " + t.provider);
                playPause.setText("❚❚ Pausar");
            });
            player.setOnCompletionListener(mp -> {
                if (mp == player && !results.isEmpty()) playAt((selected + 1) % results.size());
            });
            player.setOnErrorListener((mp, what, extra) -> {
                status.setText("Não foi possível tocar esta faixa. Pode exigir acesso/licença.");
                playPause.setText("▶ Reproduzir");
                return true;
            });
            player.setDataSource(t.url);
            player.prepareAsync();
        } catch (Exception error) {
            status.setText("Erro ao preparar áudio: " + error.getClass().getSimpleName());
        }
    }

    private void toggle() {
        if (player == null) {
            if (!results.isEmpty()) playAt(Math.max(0, selected));
            return;
        }
        try {
            if (player.isPlaying()) {
                player.pause();
                playPause.setText("▶ Continuar");
            } else {
                player.start();
                playPause.setText("❚❚ Pausar");
            }
        } catch (IllegalStateException ex) {
            status.setText("Reprodução ainda não está pronta.");
        }
    }

    private void stopAudio() {
        if (player != null) {
            try { player.reset(); player.release(); } catch (Exception ignored) {}
            player = null;
        }
    }

    private String videoId(String input) {
        input = input.trim();
        if (input.matches("[A-Za-z0-9_-]{11}")) return input;
        try {
            Uri uri = Uri.parse(input);
            if (!"https".equalsIgnoreCase(uri.getScheme())) return null;
            String host = uri.getHost();
            if (host == null) return null;
            host = host.toLowerCase(java.util.Locale.ROOT);
            if (host.equals("youtu.be")) {
                String path = uri.getPath();
                if (path != null && path.length() == 12) return path.substring(1);
            }
            if (host.equals("youtube.com") || host.equals("www.youtube.com") || host.equals("m.youtube.com")) {
                String id = uri.getQueryParameter("v");
                if (id == null && uri.getPathSegments().size() >= 2
                        && ("shorts".equals(uri.getPathSegments().get(0)) || "embed".equals(uri.getPathSegments().get(0)))) {
                    id = uri.getPathSegments().get(1);
                }
                if (id != null && id.matches("[A-Za-z0-9_-]{11}")) return id;
            }
        } catch (Exception ignored) {}
        return null;
    }

    private void addYouTube() {
        youtubeLink = input("Cole o link de um vídeo do YouTube");
        root.addView(youtubeLink, new LinearLayout.LayoutParams(-1, dp(50)));
        spacer(root, 10);
        LinearLayout controls = row();
        Button openSearch = button("Buscar no YouTube", false);
        Button embed = button("Reproduzir vídeo", true);
        controls.addView(openSearch, new LinearLayout.LayoutParams(0, dp(46), 1));
        LinearLayout.LayoutParams ep = new LinearLayout.LayoutParams(0, dp(46), 1);
        ep.leftMargin = dp(8);
        controls.addView(embed, ep);
        root.addView(controls);
        openSearch.setOnClickListener(v -> {
            try {
                String query = youtubeLink.getText().toString().trim();
                String url = "https://www.youtube.com/results?search_query="
                        + encode(query.isEmpty() ? "música" : query);
                startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
            } catch (Exception e) { showYouTubeStatus("Navegador indisponível"); }
        });
        embed.setOnClickListener(v -> {
            String id = videoId(youtubeLink.getText().toString());
            if (id == null) {
                showYouTubeStatus("Cole um link válido ou um ID de vídeo de 11 caracteres.");
                return;
            }
            startYouTube(id);
        });
        spacer(root, 12);
        status = text("O player oficial precisa permanecer visível, sem extrair o áudio.", 13, false, MUTED);
        root.addView(status);
        spacer(root, 12);
        FrameLayout container = new FrameLayout(this);
        container.setBackground(bg(PANEL, 14));
        root.addView(container, new LinearLayout.LayoutParams(-1, dp(256)));
        youtube = new WebView(this);
        youtube.setBackgroundColor(Color.BLACK);
        youtube.getSettings().setJavaScriptEnabled(true);
        youtube.getSettings().setDomStorageEnabled(true);
        youtube.getSettings().setMediaPlaybackRequiresUserGesture(true);
        youtube.setWebChromeClient(new WebChromeClient());
        container.addView(youtube, new FrameLayout.LayoutParams(-1, -1));
        spacer(root, 12);
        TextView explanation = text("Você pode procurar músicas no YouTube, copiar o link e assisti-las aqui. Não há reprodução oculta, extração de MP3 ou modo somente áudio do YouTube.", 12, false, MUTED);
        root.addView(explanation);
    }

    private void showYouTubeStatus(String msg) {
        if (status != null) status.setText(msg);
    }

    private void startYouTube(String id) {
        if (youtube == null) return;
        String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>"
            + "<style>html,body{margin:0;padding:0;height:100%;background:#000}iframe{width:100%;height:100%;border:0}</style></head>"
            + "<body><iframe src='https://www.youtube.com/embed/" + id + "?playsinline=1&enablejsapi=1'"
            + " title='YouTube video player' allow='accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture'"
            + " allowfullscreen></iframe></body></html>";
        youtube.loadDataWithBaseURL("https://www.youtube.com", html, "text/html", "UTF-8", null);
        showYouTubeStatus("Player oficial incorporado • use os controles do vídeo");
    }

    private void stopYouTube() {
        if (youtube != null) {
            youtube.loadUrl("about:blank"); // no YouTube playback in the background
            youtube.onPause();
            youtube.destroy();
            youtube = null;
        }
    }

    @Override protected void onStop() {
        super.onStop();
        // This Activity does not run as a background streaming service.
        if (player != null && player.isPlaying()) player.pause();
        if (youtube != null) youtube.loadUrl("about:blank");
    }

    @Override protected void onDestroy() {
        stopAudio();
        stopYouTube();
        network.shutdownNow();
        super.onDestroy();
    }
}
