package dev.edith.spotifast;

import android.app.Activity;
import android.content.*;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.*;
import android.widget.*;
import androidx.media3.session.*;
import androidx.media3.common.Player;
import com.google.common.util.concurrent.ListenableFuture;
import dev.edith.spotifast.playback.PlaybackService;
import dev.edith.spotifast.providers.YouTubeIds;
import static dev.edith.spotifast.ui.Design.*;

/** Visible official video only. No audio extraction, hidden playback, or PiP. */
@androidx.annotation.OptIn(markerClass=androidx.media3.common.util.UnstableApi.class)
public final class YouTubeActivity extends Activity {
    private WebView video;private TextView status;private String id="";private MediaController audio;
    private ListenableFuture<MediaController> connection;
    private final Player.Listener listener=new Player.Listener(){@Override public void onIsPlayingChanged(boolean playing){if(playing&&audio!=null)audio.pause();}};
    @Override public void onCreate(Bundle saved){super.onCreate(saved);
        ScrollView scroll=new ScrollView(this);LinearLayout root=column(this);root.setPadding(dp(this,16),dp(this,24),dp(this,16),dp(this,24));root.setBackgroundColor(BG);scroll.addView(root);setContentView(scroll);
        root.setOnApplyWindowInsetsListener((v,insets)->{v.setPadding(dp(this,16),insets.getSystemWindowInsetTop()+dp(this,12),dp(this,16),insets.getSystemWindowInsetBottom()+dp(this,16));return insets;});
        Button back=button(this,"‹ Voltar",false);root.addView(back);back.setOnClickListener(v->finish());root.addView(text(this,"YouTube",27,true));
        EditText input=input(this,"Pesquisar ou colar link do YouTube");input.setText(getIntent().getStringExtra("query"));root.addView(input);
        Button search=button(this,"Pesquisar no YouTube ↗",false);root.addView(search);search.setOnClickListener(v->external("https://www.youtube.com/results?search_query="+Uri.encode(input.getText().toString())));
        Button embed=button(this,"Abrir vídeo pelo link",true);root.addView(embed);embed.setOnClickListener(v->{String parsed=YouTubeIds.parse(input.getText().toString());if(parsed==null){status.setText("Cole um link válido do YouTube.");return;}id=parsed;load();});
        status=text(this,"Use os controles oficiais do vídeo para reproduzir.",13,false);root.addView(status);
        video=new WebView(this);video.setBackgroundColor(0xff000000);video.getSettings().setJavaScriptEnabled(true);video.getSettings().setDomStorageEnabled(true);video.getSettings().setAllowFileAccess(false);video.getSettings().setAllowContentAccess(false);video.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);video.getSettings().setMediaPlaybackRequiresUserGesture(true);video.setWebChromeClient(new WebChromeClient());
        video.setWebViewClient(new WebViewClient(){@Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request){if(request.isForMainFrame()){external(request.getUrl().toString());return true;}return false;}});
        root.addView(video,new LinearLayout.LayoutParams(-1,dp(this,270)));
        Button external=button(this,"Abrir no aplicativo YouTube ↗",false);root.addView(external);external.setOnClickListener(v->{if(!id.isEmpty())external("https://www.youtube.com/watch?v="+id);});
        root.addView(text(this,"Ao sair desta tela, o vídeo será interrompido. Se a incorporação for bloqueada, abra no YouTube.",13,false));
    }
    private void load(){if(audio!=null)audio.pause();
        String html="<!doctype html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'><style>html,body{margin:0;background:black;width:100%;height:100%}#player{width:100%;height:100%}#error{color:white;font:14px sans-serif}</style></head><body><div id='player'></div><p id='error'></p><script src='https://www.youtube.com/iframe_api'></script><script>function onYouTubeIframeAPIReady(){new YT.Player('player',{videoId:'"+id+"',playerVars:{playsinline:1,controls:1,origin:'https://dev.edith.spotifast'},events:{onError:function(e){document.getElementById('error').textContent='Vídeo indisponível para incorporação ('+e.data+'). Abra no YouTube.';}}});}</script></body></html>";
        video.loadDataWithBaseURL("https://dev.edith.spotifast",html,"text/html","UTF-8",null);status.setText("Player oficial · toque no vídeo para assistir");
    }
    private void external(String url){if(!url.startsWith("https://"))return;try{startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse(url)));}catch(ActivityNotFoundException e){status.setText("Nenhum aplicativo disponível para abrir este link.");}}
    @Override protected void onStart(){super.onStart();connection=new MediaController.Builder(this,new SessionToken(this,new ComponentName(this,PlaybackService.class))).buildAsync();connection.addListener(()->{try{audio=connection.get();audio.pause();audio.addListener(listener);}catch(Exception ignored){}},command->runOnUiThread(command));}
    @Override protected void onResume(){super.onResume();if(video!=null)video.onResume();}
    @Override protected void onPause(){if(video!=null){video.loadUrl("about:blank");video.onPause();status.setText("Vídeo interrompido. Toque em Abrir vídeo pelo link para continuar.");}super.onPause();}
    @Override protected void onStop(){if(audio!=null)audio.removeListener(listener);if(connection!=null)MediaController.releaseFuture(connection);audio=null;super.onStop();}
    @Override protected void onDestroy(){if(video!=null){((android.view.ViewGroup)video.getParent()).removeView(video);video.destroy();video=null;}super.onDestroy();}
}
