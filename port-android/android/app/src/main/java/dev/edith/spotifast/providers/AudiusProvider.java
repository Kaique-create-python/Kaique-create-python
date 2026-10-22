package dev.edith.spotifast.providers;

import dev.edith.spotifast.data.Track;
import org.json.*;
import java.util.*;
import java.io.IOException;

public final class AudiusProvider {
    public static final String BASE="https://api.audius.co/v1";
    public List<Track> search(String query,String genre,int offset,Object tag) throws Exception {
        String url=ApiClient.url(BASE+(query.isEmpty()?"/tracks/trending":"/tracks/search"),"app_name","SpotiFastAndroid","limit","25","offset",""+offset);
        if(!query.isEmpty()) url=ApiClient.url(url,"query",query);
        if(!genre.isEmpty()) url=ApiClient.url(url,"genre",genre);
        return tracks(ApiClient.get(url,tag,true).optJSONArray("data"));
    }
    public List<Track> artist(String id,int offset,Object tag) throws Exception {
        if(!id.matches("[A-Za-z0-9_-]{1,100}")) throw new IOException("Artista inválido");
        return tracks(ApiClient.get(ApiClient.url(BASE+"/users/"+id+"/tracks","limit","25","offset",""+offset,"app_name","SpotiFastAndroid"),tag,true).optJSONArray("data"));
    }
    public static List<Track> tracks(JSONArray a) throws Exception {
        if(a==null) throw new IOException("Resposta Audius inválida");List<Track> out=new ArrayList<>();
        for(int i=0;i<a.length();i++) {Track t=parse(a.getJSONObject(i));if(t.id.matches("[A-Za-z0-9_-]{1,100}"))out.add(t);}return out;
    }
    public static Track parse(JSONObject o) {
        JSONObject user=o.optJSONObject("user");if(user==null) user=new JSONObject();
        Track t=new Track("audius",o.optString("id"),o.optString("title","Sem título"),user.optString("name","Audius"));
        t.artistId=user.optString("id");t.duration=o.optLong("duration")*1000;t.genre=o.optString("genre");
        JSONObject art=o.optJSONObject("artwork");if(art!=null)t.artwork=Track.safeImage(art.optString("480x480",art.optString("150x150")));
        String link=o.optString("permalink");if(link.startsWith("/"))t.shareUrl="https://audius.co"+link;else if(link.startsWith("https://audius.co/"))t.shareUrl=link;
        if(o.optBoolean("is_stream_gated")||o.optBoolean("is_delete")||o.optBoolean("is_private")||o.optBoolean("is_unlisted")||!o.optBoolean("is_streamable",true)||!o.optBoolean("streamable",true))t.unavailable="Faixa restrita ou indisponível no Audius";
        JSONObject access=o.optJSONObject("access"),conditions=o.optJSONObject("stream_conditions");
        if((access!=null&&!access.optBoolean("stream",true))||(conditions!=null&&conditions.length()>0))t.unavailable="Esta faixa exige autorização na fonte";
        return t;
    }
    /**
     * GET /tracks/{id} returns {"data": {...}}, unlike track search where
     * data is an array. Treat the detail shape correctly before streaming.
     */
    public static Track parseTrackDetail(JSONObject response) throws Exception {
        Object data=response.opt("data");
        JSONObject detail;
        if(data instanceof JSONObject) detail=(JSONObject)data;
        else if(data instanceof JSONArray && ((JSONArray)data).length()>0)
            detail=((JSONArray)data).getJSONObject(0);
        else throw new IOException("Detalhes da faixa indisponíveis no Audius");
        Track track=parse(detail);
        if(!track.id.matches("[A-Za-z0-9_-]{1,100}"))
            throw new IOException("Identificador de faixa inválido");
        if(!track.playable()) throw new IOException(track.unavailable);
        return track;
    }
    public String resolve(String id) throws Exception {
        if(!id.matches("[A-Za-z0-9_-]{1,100}"))throw new IOException("Identificador inválido");
        JSONObject response=ApiClient.get(ApiClient.url(BASE+"/tracks/"+id,"app_name","SpotiFastAndroid"),this,false);
        Track track=parseTrackDetail(response);
        if(!id.equals(track.id)) throw new IOException("A faixa retornada não corresponde à selecionada");
        return ApiClient.url(BASE+"/tracks/"+id+"/stream","app_name","SpotiFastAndroid");
    }
}
