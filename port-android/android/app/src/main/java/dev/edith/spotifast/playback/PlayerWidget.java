package dev.edith.spotifast.playback;

import android.app.PendingIntent;
import android.appwidget.*;
import android.content.*;
import android.os.*;
import android.widget.RemoteViews;
import androidx.media3.common.Player;
import androidx.media3.session.*;
import com.google.common.util.concurrent.ListenableFuture;
import dev.edith.spotifast.FreeMusicActivity;
import dev.edith.spotifast.R;

/** Event-driven widget: no polling, timer, network request or extra playback service. */
@androidx.annotation.OptIn(markerClass=androidx.media3.common.util.UnstableApi.class)
public final class PlayerWidget extends AppWidgetProvider {
    private static final String PREFIX="dev.edith.spotifast.widget.";
    @Override public void onUpdate(Context context,AppWidgetManager manager,int[] ids){render(context,"SpotiFast","Abra sua biblioteca",false);}
    public static void render(Context context,String title,String artist,boolean playing){
        AppWidgetManager manager=AppWidgetManager.getInstance(context);
        int[] ids=manager.getAppWidgetIds(new ComponentName(context,PlayerWidget.class));if(ids.length==0)return;
        RemoteViews views=new RemoteViews(context.getPackageName(),R.layout.player_widget);
        views.setTextViewText(R.id.widget_title,title);views.setTextViewText(R.id.widget_artist,artist);
        views.setTextViewText(R.id.widget_toggle,playing?"Ⅱ":"▶");
        views.setContentDescription(R.id.widget_toggle,playing?"Pausar":"Reproduzir");
        views.setOnClickPendingIntent(R.id.widget_info,PendingIntent.getActivity(context,0,new Intent(context,FreeMusicActivity.class),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT));
        int[] controls={R.id.widget_previous,R.id.widget_toggle,R.id.widget_next};String[] actions={"previous","toggle","next"};
        for(int i=0;i<actions.length;i++)views.setOnClickPendingIntent(controls[i],PendingIntent.getBroadcast(context,i,new Intent(context,PlayerWidget.class).setAction(PREFIX+actions[i]),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT));
        manager.updateAppWidget(ids,views);
    }
    @Override public void onReceive(Context context,Intent intent){
        super.onReceive(context,intent);String action=intent.getAction();if(action==null||!action.startsWith(PREFIX))return;
        PendingResult result=goAsync();Handler main=new Handler(Looper.getMainLooper());
        java.util.concurrent.atomic.AtomicBoolean finished=new java.util.concurrent.atomic.AtomicBoolean();
        ListenableFuture<MediaController> future=new MediaController.Builder(context,new SessionToken(context,new ComponentName(context,PlaybackService.class))).buildAsync();
        Runnable timeout=()->{if(finished.compareAndSet(false,true)){MediaController.releaseFuture(future);result.finish();}};main.postDelayed(timeout,8000);
        future.addListener(()->{
            main.removeCallbacks(timeout);
            if(!finished.compareAndSet(false,true))return;
            try{
                MediaController p=future.get();
                if(action.endsWith("previous"))p.seekToPrevious();
                else if(action.endsWith("next"))p.seekToNextMediaItem();
                else if(p.isPlaying())p.pause();
                else{if(p.getPlaybackState()==Player.STATE_ENDED)p.seekTo(0);if(p.getPlaybackState()==Player.STATE_IDLE)p.prepare();p.play();}
            }catch(Exception e){android.util.Log.w("SpotiFastWidget","Player connection unavailable");}
            finally{MediaController.releaseFuture(future);result.finish();}
        },main::post);
    }
}
