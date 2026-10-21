package dev.edith.spotifast.providers;

import okhttp3.*;
import org.json.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

/** Shared connection pool; cancellation tags and bounded metadata-only cache. Never logs URLs/credentials. */
public final class ApiClient {
    public static final OkHttpClient HTTP=new OkHttpClient.Builder().connectTimeout(10,TimeUnit.SECONDS)
            .readTimeout(15,TimeUnit.SECONDS).callTimeout(25,TimeUnit.SECONDS).build();
    private static final LinkedHashMap<String,Entry> CACHE=new LinkedHashMap<>(32,.75f,true);
    private static int cacheChars;
    private static final class Entry { long time=System.currentTimeMillis();String body;Entry(String b){body=b;} }
    public static void cancel(Object tag) {
        for(Call c:HTTP.dispatcher().queuedCalls()) if(tag.equals(c.request().tag())) c.cancel();
        for(Call c:HTTP.dispatcher().runningCalls()) if(tag.equals(c.request().tag())) c.cancel();
    }
    public static void clear() { synchronized(CACHE){CACHE.clear();cacheChars=0;} }
    public static JSONObject get(String url,Object tag,boolean cache) throws Exception {
        if(cache) synchronized(CACHE) { Entry e=CACHE.get(url);if(e!=null&&System.currentTimeMillis()-e.time<120000) return new JSONObject(e.body); }
        for(int attempt=0;attempt<3;attempt++) {
            if(Thread.currentThread().isInterrupted()) throw new InterruptedIOException();
            Request request=new Request.Builder().url(url).tag(tag).header("Accept","application/json").header("User-Agent","SpotiFastAndroid/4").build();
            try(Response response=HTTP.newCall(request).execute()) {
                int code=response.code();
                if((code==429||code>=500)&&attempt<2) {
                    long delay=500L*(1L<<attempt);
                    try {delay=Math.max(delay,Long.parseLong(response.header("Retry-After","0"))*1000);}catch(NumberFormatException ignored){}
                    if(delay>5000) throw new IOException("Limite da fonte atingido. Tente novamente mais tarde.");
                    Thread.sleep(delay);continue;
                }
                if(!response.isSuccessful()) throw new IOException(code==429?"Limite da fonte atingido. Aguarde.":code==401||code==403?"A fonte recusou o acesso. Verifique as credenciais e permissões.":code==404?"Conteúdo indisponível na fonte.":"A fonte respondeu HTTP "+code);
                if(response.body()==null) throw new IOException("Resposta vazia");
                if(response.body().contentLength()>2_000_000) throw new IOException("Resposta excede o limite");
                StringBuilder text=new StringBuilder();char[] buffer=new char[8192];
                try(Reader reader=response.body().charStream()) {int n;while((n=reader.read(buffer))!=-1) {text.append(buffer,0,n);if(text.length()>2_000_000) throw new IOException("Resposta excede o limite");}}
                String body=text.toString();JSONObject json=new JSONObject(body);
                if(cache) synchronized(CACHE) {Entry previous=CACHE.put(url,new Entry(body));cacheChars+=body.length()-(previous==null?0:previous.body.length());while(CACHE.size()>24||cacheChars>2_000_000){Entry removed=CACHE.remove(CACHE.keySet().iterator().next());cacheChars-=removed.body.length();}}
                return json;
            }
        }
        throw new IOException("Fonte temporariamente indisponível");
    }
    public static String url(String base,String... params) {
        HttpUrl.Builder b=Objects.requireNonNull(HttpUrl.parse(base)).newBuilder();
        for(int i=0;i<params.length;i+=2) b.addQueryParameter(params[i],params[i+1]);return b.build().toString();
    }
}
