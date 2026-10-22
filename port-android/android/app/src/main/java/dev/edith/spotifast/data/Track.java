package dev.edith.spotifast.data;

import org.json.JSONObject;

/** Stable provider identity. Stream URLs are deliberately resolved only at playback time. */
public final class Track {
    public String provider, id, title, artist, artwork = "", artistId = "", albumId = "",
            album = "", genre = "", license = "", shareUrl = "", unavailable = "";
    public long duration;
    public Track(String provider, String id, String title, String artist) {
        this.provider = provider; this.id = id; this.title = title; this.artist = artist;
    }
    public String key() { return provider + ":" + id; }
    public boolean playable() { return unavailable.isEmpty(); }
    public JSONObject json() throws org.json.JSONException {
        return new JSONObject().put("provider", provider).put("trackId", id).put("title", title)
            .put("artist", artist).put("artwork", artwork).put("artistId", artistId)
            .put("albumId", albumId).put("album", album).put("genre", genre)
            .put("license", license).put("shareUrl", shareUrl).put("duration", duration)
            .put("unavailable", unavailable);
    }
    public static Track fromJson(JSONObject o) {
        String provider = o.optString("provider"), id = o.optString("trackId");
        if (!(provider.equals("audius") || provider.equals("jamendo") || provider.equals("local")))
            throw new IllegalArgumentException("Fonte desconhecida");
        if (provider.equals("local") ? !id.startsWith("content://") : !id.matches("[A-Za-z0-9_-]{1,100}"))
            throw new IllegalArgumentException("Identificador inválido");
        Track t = new Track(provider, id, o.optString("title", "Sem título"), o.optString("artist", "Artista"));
        t.artwork = safeImage(o.optString("artwork")); t.artistId = o.optString("artistId");
        t.albumId = o.optString("albumId"); t.album = o.optString("album"); t.genre = o.optString("genre");
        t.license = o.optString("license"); t.shareUrl = o.optString("shareUrl");
        t.duration = Math.max(0, o.optLong("duration")); t.unavailable = o.optString("unavailable");
        return t;
    }
    public static String safeImage(String url) { return url.startsWith("https://") || url.startsWith("content://") ? url : ""; }
}
