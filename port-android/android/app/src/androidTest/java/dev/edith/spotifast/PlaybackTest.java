package dev.edith.spotifast;

import android.app.*;
import android.content.*;
import android.media.*;
import android.net.Uri;
import android.provider.MediaStore;
import androidx.media3.common.Player;
import androidx.media3.session.*;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import dev.edith.spotifast.playback.*;
import dev.edith.spotifast.data.Track;
import com.google.common.util.concurrent.ListenableFuture;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class PlaybackTest {
    private final Instrumentation inst=InstrumentationRegistry.getInstrumentation();
    private void ui(Runnable r){inst.runOnMainSync(r);}
    private void await(java.util.function.BooleanSupplier predicate) throws Exception {long end=System.currentTimeMillis()+15000;while(System.currentTimeMillis()<end){AtomicBoolean ok=new AtomicBoolean();ui(()->ok.set(predicate.getAsBoolean()));if(ok.get())return;Thread.sleep(100);}fail("Timed out waiting for player state");}
    @Test public void localAudioQueueFocusAndBackground() throws Exception {
        Context c=inst.getTargetContext();Activity activity=inst.startActivitySync(new Intent(c,FreeMusicActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        ContentValues values=new ContentValues();values.put(MediaStore.Audio.Media.DISPLAY_NAME,"spotifast-test.wav");values.put(MediaStore.Audio.Media.MIME_TYPE,"audio/wav");values.put(MediaStore.Audio.Media.IS_PENDING,1);
        Uri uri=c.getContentResolver().insert(MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),values);assertNotNull(uri);
        AtomicReference<ListenableFuture<MediaController>> future=new AtomicReference<>();MediaController control=null;
        try {
            // Generated PCM tone, no third-party content or network dependency.
            try(OutputStream raw=c.getContentResolver().openOutputStream(uri);DataOutputStream out=new DataOutputStream(raw)){
                int bytes=8000*2*30;out.writeBytes("RIFF");little(out,36+bytes,4);out.writeBytes("WAVEfmt ");little(out,16,4);little(out,1,2);little(out,1,2);little(out,8000,4);little(out,16000,4);little(out,2,2);little(out,16,2);out.writeBytes("data");little(out,bytes,4);for(int n=0;n<bytes/2;n++)little(out,(short)(Math.sin(n*2*Math.PI*220/8000)*1000),2);
            }
            values.clear();values.put(MediaStore.Audio.Media.IS_PENDING,0);c.getContentResolver().update(uri,values,null,null);
            ui(()->future.set(new MediaController.Builder(c,new SessionToken(c,new ComponentName(c,PlaybackService.class))).buildAsync()));control=future.get().get(15,TimeUnit.SECONDS);final MediaController p=control;
            Track a=new Track("local",uri.toString(),"Fixture A","Test"),b=new Track("local",uri.toString(),"Fixture B","Test");
            ui(()->{p.setMediaItems(MediaItems.of(Arrays.asList(a,b)));p.prepare();p.play();});await(p::isPlaying);
            ui(p::pause);await(()->!p.isPlaying());ui(()->{p.seekTo(1000);p.play();});await(()->p.isPlaying()&&p.getCurrentPosition()>=1000);
            ui(p::seekToNextMediaItem);await(()->p.getCurrentMediaItemIndex()==1&&p.isPlaying());ui(p::seekToPreviousMediaItem);await(()->p.getCurrentMediaItemIndex()==0);
            AudioManager manager=(AudioManager)c.getSystemService(Context.AUDIO_SERVICE);
            AudioFocusRequest focus=new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT).setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build()).setOnAudioFocusChangeListener(x->{}).build();
            assertEquals(AudioManager.AUDIOFOCUS_REQUEST_GRANTED,manager.requestAudioFocus(focus));await(()->!p.isPlaying());manager.abandonAudioFocusRequest(focus);await(p::isPlaying);
            ui(activity::finish);await(p::isPlaying);Thread.sleep(1500);await(()->p.isPlaying()&&p.getCurrentPosition()>1000);
            NotificationManager notifications=(NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);assertTrue(notifications.getActiveNotifications().length>0);
            ui(p::pause);
        } finally {if(control!=null){MediaController finalControl=control;ui(()->{finalControl.stop();finalControl.clearMediaItems();finalControl.release();});}c.getContentResolver().delete(uri,null,null);ui(activity::finish);}
    }
    private static void little(DataOutputStream out,int value,int n)throws IOException{for(int i=0;i<n;i++)out.write((value>>>(8*i))&255);}
}
