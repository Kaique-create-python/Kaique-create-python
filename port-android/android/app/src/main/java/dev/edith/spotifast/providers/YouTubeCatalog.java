package dev.edith.spotifast.providers;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * YouTube Data API metadata search ONLY. Playback always remains within the
 * visible, official YouTube iframe in YouTubeActivity. No audio extraction,
 * stream URL resolution, advertisements bypass, or Android Media3 injection.
 *
 * A YouTube Data API key can be configured by the user. We never bundle a
 * private Google API key in a published APK or source repository.
 */
public final class YouTubeCatalog {
    private YouTubeCatalog() {}
    public static final String KEY = "youtube_data_api_key";
    public static String apiKey(Context context) {
        return context.getSharedPreferences("FreeMusicActivity", Context.MODE_PRIVATE)
                .getString(KEY, "").trim();
    }

    public static final class Video {
        public final String id;
        public final String title;
        public final String channel;
        public final String artwork;
        Video(String id, String title, String channel, String artwork) {
            this.id = id;
            this.title = title;
            this.channel = channel;
            this.artwork = artwork;
        }
        public String url() { return "https://www.youtube.com/watch?v=" + id; }
    }

    public static List<Video> parse(JSONObject data) throws Exception {
        if (data.optJSONObject("error") != null) {
            throw new IOException("A API do YouTube recusou a busca. Confira a chave e a cota.");
        }
        JSONArray values = data.optJSONArray("items");
        if (values == null) throw new IOException("Resposta inválida da API do YouTube");
        List<Video> videos = new ArrayList<>();
        for (int i = 0; i < values.length(); ++i) {
            JSONObject item = values.optJSONObject(i);
            if (item == null) continue;
            JSONObject ids = item.optJSONObject("id");
            JSONObject snippet = item.optJSONObject("snippet");
            if (ids == null || snippet == null) continue;
            String id = ids.optString("videoId");
            if (!id.matches("[A-Za-z0-9_-]{11}")) continue;
            JSONObject art = snippet.optJSONObject("thumbnails");
            JSONObject large = art == null ? null : art.optJSONObject("medium");
            if (large == null && art != null) large = art.optJSONObject("default");
            String image = large == null ? "" : large.optString("url");
            videos.add(new Video(id, snippet.optString("title", "Vídeo"),
                    snippet.optString("channelTitle", "Canal"), image.startsWith("https://") ? image : ""));
        }
        return videos;
    }

    public static List<Video> search(String term, String apiKey, Object requestTag) throws Exception {
        String name = term == null ? "" : term.trim();
        if (name.isEmpty()) throw new IOException("Digite o nome da música ou artista");
        if (apiKey == null || apiKey.trim().isEmpty())
            throw new IOException("Configure sua chave da YouTube Data API");
        // Only metadata is fetched. The official embedded player controls
        // actual playback and enforces the platform's restrictions.
        String url = ApiClient.url("https://www.googleapis.com/youtube/v3/search",
                "part", "snippet", "type", "video", "videoEmbeddable", "true",
                "videoSyndicated", "true", "safeSearch", "moderate",
                "q", name + " música", "maxResults", "25",
                "relevanceLanguage", "pt", "regionCode", "BR",
                "key", apiKey.trim());
        return parse(ApiClient.get(url, requestTag, true));
    }
}
