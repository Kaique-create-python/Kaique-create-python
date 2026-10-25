package dev.edith.spotifast.playback;

import dev.edith.spotifast.data.Track;
import java.util.*;

/** Selects real available tracks; never invents similarity scores across providers. */
public final class RadioPlanner {
    private RadioPlanner() {}
    public static List<Track> select(List<Track> candidates,Set<String> queued,int limit){
        if(limit<=0)return Collections.emptyList();
        Set<String> seen=new HashSet<>(queued);List<Track> result=new ArrayList<>();
        for(Track t:candidates){if(t.playable()&&seen.add(t.key()))result.add(t);if(result.size()>=limit)break;}
        return result;
    }
}
