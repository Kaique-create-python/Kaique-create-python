package dev.edith.spotifast.providers;

import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

public final class YouTubeIds {
    public static String parse(String input){
        input=input.trim();if(input.matches("[A-Za-z0-9_-]{11}"))return input;
        try{URI uri=new URI(input);if(!"https".equalsIgnoreCase(uri.getScheme())||uri.getHost()==null)return null;
            String host=uri.getHost().toLowerCase(Locale.ROOT),id=null,path=uri.getPath();
            if(host.equals("youtu.be")&&path.length()==12)id=path.substring(1);
            else if(host.equals("youtube.com")||host.equals("www.youtube.com")||host.equals("m.youtube.com")){
                String query=uri.getRawQuery();if(query!=null)for(String part:query.split("&")){String[] pair=part.split("=",2);if(pair.length==2&&pair[0].equals("v"))id=URLDecoder.decode(pair[1],"UTF-8");}
                if(id==null&&(path.startsWith("/embed/")||path.startsWith("/shorts/")))id=path.substring(path.lastIndexOf('/')+1);
            }return id!=null&&id.matches("[A-Za-z0-9_-]{11}")?id:null;
        }catch(Exception e){return null;}
    }
}
