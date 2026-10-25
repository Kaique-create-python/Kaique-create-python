package dev.edith.spotifast;

import android.app.*;
import android.content.*;
import androidx.media3.session.*;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import dev.edith.spotifast.data.Track;
import dev.edith.spotifast.playback.*;
import dev.edith.spotifast.providers.AudiusProvider;
import com.google.common.util.concurrent.ListenableFuture;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.*;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Actual authorized remote decoding, reported separately from deterministic PCM tests. */
@RunWith(AndroidJUnit4.class)
public class LivePlaybackTest {
    @Test(timeout=90000) public void publicAudiusTrackReachesPlayingAndAdvances() throws Exception {
        List<Track> tracks;
        try{tracks=new AudiusProvider().search("ambient","",0,this);}
        catch(Exception unavailable){Assume.assumeNoException("Audius discovery unavailable in this environment",unavailable);return;}
        Track selected=null;for(Track t:tracks)if(t.playable()){selected=t;break;}
        Assume.assumeNotNull(selected);
        Instrumentation inst=InstrumentationRegistry.getInstrumentation();Context c=inst.getTargetContext();
        Activity activity=inst.startActivitySync(new Intent(c,FreeMusicActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        AtomicReference<ListenableFuture<MediaController>> future=new AtomicReference<>();MediaController control=null;
        try{
            inst.runOnMainSync(()->future.set(new MediaController.Builder(c,new SessionToken(c,new ComponentName(c,PlaybackService.class))).buildAsync()));
            control=future.get().get(15,TimeUnit.SECONDS);MediaController player=control;Track permitted=selected;
            inst.runOnMainSync(()->{player.setMediaItems(MediaItems.of(Collections.singletonList(permitted)));player.prepare();player.play();});
            long deadline=System.currentTimeMillis()+30000;AtomicBoolean success=new AtomicBoolean();AtomicReference<String> error=new AtomicReference<>();
            while(System.currentTimeMillis()<deadline){
                inst.runOnMainSync(()->{
                    if(player.getPlayerError()!=null)error.set("Media3 remote error code="+player.getPlayerError().errorCode);
                    success.set(player.isPlaying()&&player.getCurrentPosition()>500);
                });
                if(success.get()||error.get()!=null)break;Thread.sleep(100);
            }
            assertNull(error.get(),error.get());assertTrue("Public Audius stream did not reach advancing playback",success.get());
        }finally{
            if(control!=null){MediaController p=control;inst.runOnMainSync(()->{p.stop();p.clearMediaItems();p.release();});}
            else if(future.get()!=null)MediaController.releaseFuture(future.get());
            inst.runOnMainSync(activity::finish);
        }
    }
}
