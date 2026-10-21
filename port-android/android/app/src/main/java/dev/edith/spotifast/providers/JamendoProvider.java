package dev.edith.spotifast.providers;

import org.json.*;
import java.util.*;
import java.io.IOException;
import dev.edith.spotifast.data.Track;

public final class JamendoProvider {
    private final String client;
    public JamendoProvider(String client) {this.client=client;}
    private String base(int offset) throws IOException {
        if(client.trim().isEmpty())throw new IOException("Configure seu Client ID do Jamendo");
        return ApiClient.url("https://api.jamendo.com/v3.0/tracks/","client_id",client,"format","json","limit","25","offset",""+offset,"audioformat","mp32","imagesize","500","include","musicinfo","type","single albumtrack");
    }
    public List<Track> search(String query,String genre,int offset,Object tag) throws Exception {
        String url=ApiClient.url(base(offset),"order",query.isEmpty()?"popularity_week":"relevance");
        if(!query.isEmpty())url=ApiClient.url(url,"search",query);
        if(!genre.isEmpty())url=ApiClient.url(url,"tags",genre);
        return parseResponse(ApiClient.get(url,tag,true));
    }
    public List<Track> artist(String id,int offset,Object tag) throws Exception {return parseResponse(ApiClient.get(ApiClient.url(base(offset),"artist_id",id),tag,true));}
    public List<Track> album(String id,Object tag) throws Exception {return parseResponse(ApiClient.get(ApiClient.url(base(0),"album_id",id),tag,true));}
    public static List<Track> parseResponse(JSONObject data) throws Exception {
        JSONObject headers=data.optJSONObject("headers");
        if(headers==null||headers.optInt("code",-1)!=0)throw new IOException("Jamendo recusou a consulta. Verifique seu Client ID.");
        JSONArray a=data.optJSONArray("results");if(a==null)throw new IOException("Resposta Jamendo inválida");
        List<Track> out=new ArrayList<>();for(int i=0;i<a.length();i++){JSONObject o=a.getJSONObject(i);Track t=new Track("jamendo",o.optString("id"),o.optString("name","Sem título"),o.optString("artist_name","Jamendo"));
            t.artistId=o.optString("artist_id");t.albumId=o.optString("album_id");t.album=o.optString("album_name");
            t.artwork=Track.safeImage(o.optString("image",o.optString("album_image")));t.duration=o.optLong("duration")*1000;
            t.license=o.optString("license_ccurl");t.shareUrl=o.optString("shareurl");
            if(!o.optString("audio").startsWith("https://"))t.unavailable="Streaming indisponível no Jamendo";
            JSONObject info=o.optJSONObject("musicinfo");if(info!=null){JSONObject tags=info.optJSONObject("tags");if(tags!=null){JSONArray genres=tags.optJSONArray("genres");if(genres!=null)t.genre=genres.optString(0);}}
            if(t.id.matches("[0-9]+"))out.add(t);
        }return out;
    }
    public String resolve(String id) throws Exception {
        JSONObject data=ApiClient.get(ApiClient.url(base(0),"id",id),this,false);List<Track> tracks=parseResponse(data);
        if(tracks.isEmpty()||!tracks.get(0).playable())throw new IOException("Faixa indisponível no Jamendo");
        return data.getJSONArray("results").getJSONObject(0).getString("audio");
    }
}
