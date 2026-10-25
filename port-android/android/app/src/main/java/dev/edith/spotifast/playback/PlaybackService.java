package dev.edith.spotifast.playback;

import android.app.PendingIntent;
import android.content.Intent;
import android.net.Uri;
import android.net.ConnectivityManager;
import android.net.Network;
import android.os.*;
import androidx.media3.common.*;
import androidx.media3.datasource.*;
import androidx.media3.datasource.okhttp.OkHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import androidx.media3.session.*;
import com.google.common.util.concurrent.*;
import dev.edith.spotifast.FreeMusicActivity;
import dev.edith.spotifast.data.*;
import dev.edith.spotifast.providers.*;
import java.io.IOException;
import java.util.*;

/** Sole owner of authorized audio. Activity lifetime never owns playback. */
@androidx.annotation.OptIn(markerClass=androidx.media3.common.util.UnstableApi.class)
public final class PlaybackService extends MediaSessionService {
    public static final String SLEEP="dev.edith.spotifast.SLEEP";
    public static final String AUDIO_SESSION="dev.edith.spotifast.AUDIO_SESSION";
    private ExoPlayer player;
    private MediaSession session;
    private final Handler main=new Handler(Looper.getMainLooper());
    private boolean restoring=true,changed=false,destroyed=false;
    private String counted="";
    private int retries;
    private String retryItem="";
    private ConnectivityManager connectivity;
    private ConnectivityManager.NetworkCallback networkCallback;
    private final Runnable retry=()->{
        if(destroyed||player==null||!player.getPlayWhenReady())return;
        MediaItem item=player.getCurrentMediaItem();
        if(item!=null&&retryItem.equals(item.mediaId)&&player.getPlayerError()!=null)player.prepare();
    };
    private final Runnable sleep=()->{if(player!=null)player.pause();};
    private final Runnable checkpoint=new Runnable(){public void run(){save();if(player!=null&&player.isPlaying())main.postDelayed(this,15000);}};
    @Override public void onCreate(){
        super.onCreate();
        DefaultDataSource.Factory sources=new DefaultDataSource.Factory(this,new OkHttpDataSource.Factory(ApiClient.STREAM));
        ResolvingDataSource.Factory resolving=new ResolvingDataSource.Factory(sources,spec->{
            Uri uri=spec.uri;
            if(!"spotifast".equals(uri.getScheme()))return spec;
            String id=uri.getLastPathSegment();if(id==null||!id.matches("[A-Za-z0-9_-]{1,100}"))throw new IOException("Faixa inválida");
            try {
                String url;
                if("audius".equals(uri.getHost()))url=new AudiusProvider().resolve(id);
                else if("jamendo".equals(uri.getHost()))url=new JamendoProvider(getSharedPreferences("FreeMusicActivity",MODE_PRIVATE).getString("jamendo_client_id","")).resolve(id);
                else throw new IOException("Fonte não autorizada");
                return spec.withUri(Uri.parse(url));
            }catch(IOException e){throw HttpDataSource.HttpDataSourceException.createForIOException(e,spec,HttpDataSource.HttpDataSourceException.TYPE_OPEN);}catch(Exception e){throw new IOException("A fonte não autorizou ou não disponibilizou esta faixa");}
        });
        player=new ExoPlayer.Builder(this).setMediaSourceFactory(new DefaultMediaSourceFactory(resolving))
            .setAudioAttributes(new AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(),true)
            .setHandleAudioBecomingNoisy(true).setWakeMode(C.WAKE_MODE_LOCAL).build();
        player.addListener(new Player.Listener(){
            @Override public void onTimelineChanged(Timeline timeline,int reason){changed=true;save();}
            @Override public void onMediaItemTransition(MediaItem item,int reason){counted="";retries=0;main.removeCallbacks(retry);save();countPlay();}
            @Override public void onIsPlayingChanged(boolean playing){main.removeCallbacks(checkpoint);save();if(playing){countPlay();main.postDelayed(checkpoint,15000);}}
            @Override public void onRepeatModeChanged(int repeat){save();}
            @Override public void onShuffleModeEnabledChanged(boolean shuffle){save();}
            @Override public void onPositionDiscontinuity(Player.PositionInfo old,Player.PositionInfo now,int reason){save();}
            @Override public void onPlaybackStateChanged(int state){if(state==Player.STATE_READY){retries=0;main.removeCallbacks(retry);}}
            @Override public void onPlayWhenReadyChanged(boolean ready,int reason){if(!ready)main.removeCallbacks(retry);}
            @Override public void onPlayerError(PlaybackException error){
                android.util.Log.w("SpotiFastPlayback","Playback failure code="+error.errorCode);save();
                long delay=RetryPolicy.delay(error.errorCode,retries);
                MediaItem item=player.getCurrentMediaItem();
                if(delay>=0&&item!=null&&player.getPlayWhenReady()){
                    retryItem=item.mediaId;retries++;main.removeCallbacks(retry);main.postDelayed(retry,delay);
                }
            }
        });
        connectivity=(ConnectivityManager)getSystemService(CONNECTIVITY_SERVICE);
        networkCallback=new ConnectivityManager.NetworkCallback(){
            @Override public void onAvailable(Network network){main.post(()->{
                if(destroyed||player==null||player.getPlayerError()==null)return;
                if(RetryPolicy.delay(player.getPlayerError().errorCode,0)>=0&&player.getPlayWhenReady()){
                    // One fresh bounded recovery window when a network becomes available.
                    retries=0;main.removeCallbacks(retry);main.postDelayed(retry,500);
                }
            });}
        };
        try{connectivity.registerDefaultNetworkCallback(networkCallback);}catch(SecurityException e){networkCallback=null;}
        session=new MediaSession.Builder(this,player).setSessionActivity(PendingIntent.getActivity(this,0,new Intent(this,FreeMusicActivity.class),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT))
            .setCallback(new MediaSession.Callback(){
                @Override public MediaSession.ConnectionResult onConnect(MediaSession s,MediaSession.ControllerInfo c){
                    if(c.getUid()!=android.os.Process.myUid()&&!c.isTrusted())return MediaSession.ConnectionResult.reject();
                    MediaSession.ConnectionResult base=MediaSession.Callback.super.onConnect(s,c);
                    return new MediaSession.ConnectionResult.AcceptedResultBuilder(s).setAvailableSessionCommands(base.availableSessionCommands.buildUpon().add(new SessionCommand(SLEEP,Bundle.EMPTY)).add(new SessionCommand(AUDIO_SESSION,Bundle.EMPTY)).build()).build();
                }
                @Override public ListenableFuture<List<MediaItem>> onAddMediaItems(MediaSession s,MediaSession.ControllerInfo c,List<MediaItem> items){
                    if(c.getUid()!=android.os.Process.myUid())return Futures.immediateFailedFuture(new SecurityException("Only app library can add audio"));
                    try{List<MediaItem> validated=new ArrayList<>();for(MediaItem item:items)validated.add(MediaItems.of(MediaItems.track(item)));return Futures.immediateFuture(validated);}
                    catch(Exception e){return Futures.immediateFailedFuture(e);}
                }
                @Override public ListenableFuture<MediaSession.MediaItemsWithStartPosition> onPlaybackResumption(MediaSession s,MediaSession.ControllerInfo c) {
                    SettableFuture<MediaSession.MediaItemsWithStartPosition> result=SettableFuture.create();
                    MusicDatabase.IO.execute(()->{
                        try {
                            MusicDatabase.Snapshot saved=MusicDatabase.get(PlaybackService.this).restore();
                            if(saved.tracks.isEmpty())throw new IOException("Nenhuma sessão anterior");
                            result.set(new MediaSession.MediaItemsWithStartPosition(MediaItems.of(saved.tracks),Math.max(0,Math.min(saved.index,saved.tracks.size()-1)),Math.max(0,saved.position)));
                        } catch(Exception e) {result.setException(e);}
                    });
                    return result;
                }
                @Override public ListenableFuture<SessionResult> onCustomCommand(MediaSession s,MediaSession.ControllerInfo c,SessionCommand command,Bundle args){
                    if(AUDIO_SESSION.equals(command.customAction)&&c.getUid()==android.os.Process.myUid()){
                        Bundle data=new Bundle();data.putInt("audio_session_id",player.getAudioSessionId());
                        return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS,data));
                    }
                    if(SLEEP.equals(command.customAction)&&c.getUid()==android.os.Process.myUid()){
                        main.removeCallbacks(sleep);int minutes=args.getInt("minutes",0);
                        if(minutes>0&&minutes<=120)main.postDelayed(sleep,minutes*60000L);
                        return Futures.immediateFuture(new SessionResult(SessionResult.RESULT_SUCCESS));
                    }return Futures.immediateFuture(new SessionResult(androidx.media3.session.SessionError.ERROR_NOT_SUPPORTED));
                }
            }).build();
        MusicDatabase.IO.execute(()->{
            MusicDatabase.Snapshot snapshot;
            try{snapshot=MusicDatabase.get(this).restore();}catch(Exception e){snapshot=new MusicDatabase.Snapshot();android.util.Log.w("SpotiFastPlayback","Session restore unavailable");}
            MusicDatabase.Snapshot saved=snapshot;
            main.post(()->{if(destroyed)return;
                if(!changed&&player.getMediaItemCount()==0&&!saved.tracks.isEmpty()){
                    player.setMediaItems(MediaItems.of(saved.tracks),Math.max(0,Math.min(saved.index,saved.tracks.size()-1)),Math.max(0,saved.position));
                    player.setRepeatMode(Math.max(0,Math.min(2,saved.repeat)));player.setShuffleModeEnabled(saved.shuffle);
                    // Restored paused: no unsolicited playback or network requests at startup.
                }restoring=false;save();
            });
        });
    }
    private void countPlay(){
        MediaItem item=player.getCurrentMediaItem();if(!player.isPlaying()||item==null||item.mediaId.equals(counted))return;
        counted=item.mediaId;
        if(!getSharedPreferences("FreeMusicActivity",MODE_PRIVATE).getBoolean("history_enabled",true))return;
        Track t=MediaItems.track(item);MusicDatabase.IO.execute(()->MusicDatabase.get(this).played(t));
    }
    private void save(){
        if(player==null||restoring)return;
        List<Track> tracks=new ArrayList<>();for(int i=0;i<player.getMediaItemCount();i++)tracks.add(MediaItems.track(player.getMediaItemAt(i)));
        int index=player.getCurrentMediaItemIndex(),repeat=player.getRepeatMode();long position=player.getCurrentPosition();boolean shuffle=player.getShuffleModeEnabled();
        MusicDatabase.IO.execute(()->{try{MusicDatabase.get(this).saveSession(tracks,index,position,repeat,shuffle);}catch(Exception e){android.util.Log.w("SpotiFastPlayback","Could not save session");}});
    }
    @Override public MediaSession onGetSession(MediaSession.ControllerInfo info){return session;}
    @Override public void onDestroy(){destroyed=true;save();main.removeCallbacksAndMessages(null);if(networkCallback!=null)connectivity.unregisterNetworkCallback(networkCallback);if(session!=null)session.release();if(player!=null)player.release();player=null;super.onDestroy();}
}

