package dev.edith.spotifast.providers;

import dev.edith.spotifast.data.Track;
import java.util.*;
import java.util.concurrent.*;
import android.os.*;

/** Both providers run concurrently. A generation owns its callbacks and in-flight HTTP calls. */
public final class TrackRepository {
    public interface Callback { void done(List<Track> tracks,String message); }
    private final ExecutorService io=Executors.newFixedThreadPool(3);
    private final Handler main=new Handler(Looper.getMainLooper());
    private final List<Future<?>> pending=new ArrayList<>();
    private Object tag=new Object();private int generation;private CancellationSignal localSignal=new CancellationSignal();
    public void cancel(){localSignal.cancel();localSignal=new CancellationSignal();generation++;ApiClient.cancel(tag);for(Future<?> f:pending)f.cancel(true);pending.clear();tag=new Object();}
    public void close(){cancel();io.shutdownNow();main.removeCallbacksAndMessages(null);}
    public void search(android.content.Context context,String query,String genre,String source,String client,int offset,Callback cb){
        cancel();final int stamp=generation;final Object requestTag=tag;final CancellationSignal signal=localSignal;
        List<String> sources=new ArrayList<>();if(source.equals("all")||source.equals("audius"))sources.add("audius");if((source.equals("all")||source.equals("jamendo"))&&!client.isEmpty())sources.add("jamendo");if(((source.equals("all")&&!query.trim().isEmpty())||source.equals("local"))&&LocalProvider.permitted(context))sources.add("local");
        if(sources.isEmpty()){cb.done(Collections.emptyList(),source.equals("local")?"Autorize o acesso a músicas na Biblioteca.":"Configure seu Client ID do Jamendo em Configurações.");return;}
        Map<String,List<Track>> results=new HashMap<>();List<String> errors=new ArrayList<>();int[] remaining={sources.size()};
        for(String provider:sources)pending.add(io.submit(()->{
            List<Track> tracks=Collections.emptyList();String error="";
            try{tracks=provider.equals("local")?LocalProvider.search(context,query,offset,signal):provider.equals("audius")?new AudiusProvider().search(query,genre,offset,requestTag):new JamendoProvider(client).search(query,genre,offset,requestTag);}
            catch(Exception e){if(Thread.currentThread().isInterrupted())return;error=provider+": "+(e instanceof java.io.IOException?e.getMessage():"Não foi possível ler a resposta");}
            List<Track> found=tracks;String message=error;
            main.post(()->{if(stamp!=generation)return;results.put(provider,found);if(!message.isEmpty())errors.add(message);
                if(--remaining[0]==0){List<Track> merged=new ArrayList<>();Set<String> seen=new HashSet<>();
                    // Round-robin preserves each provider's relevance without fabricating comparable scores.
                    for(int i=0;i<25;i++)for(String s:sources){List<Track> list=results.get(s);if(i<list.size()&&seen.add(list.get(i).key()))merged.add(list.get(i));}
                    cb.done(merged,String.join("\n",errors));}
            });
        }));
    }
}

