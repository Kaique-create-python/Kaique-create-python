package dev.edith.spotifast;
import dev.edith.spotifast.data.Track;
import dev.edith.spotifast.playback.RadioPlanner;
import java.util.*;
import org.junit.Test;
import static org.junit.Assert.*;
public class RadioPlannerTest {
    @Test public void excludesQueuedRestrictedAndDuplicateTracks(){
        Track queued=new Track("audius","1","A","Artist"),restricted=new Track("audius","2","B","Artist"),next=new Track("jamendo","1","C","Artist");restricted.unavailable="Restricted";
        List<Track> result=RadioPlanner.select(Arrays.asList(queued,restricted,next,next),Collections.singleton(queued.key()),5);
        assertEquals(1,result.size());assertSame(next,result.get(0));
    }
    @Test public void capsPrefetchAndAllowsSameTitleOnDifferentSources(){
        List<Track> tracks=new ArrayList<>();for(int i=0;i<20;i++)tracks.add(new Track("audius",""+i,"Same title","Artist"));
        assertEquals(5,RadioPlanner.select(tracks,Collections.emptySet(),5).size());
    }
}
