package dev.edith.spotifast;
import android.content.Context;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import dev.edith.spotifast.data.*;
import java.util.*;
import org.junit.*;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;
@RunWith(AndroidJUnit4.class)
public class LibraryTest {
    private Context context;private MusicDatabase db;
    @Before public void before(){context=InstrumentationRegistry.getInstrumentation().getTargetContext();context.deleteDatabase("spotifast-library.db");db=new MusicDatabase(context);}
    @After public void after(){db.close();}
    @Test public void playlistAndSessionSurviveReopen(){Track a=new Track("audius","1","A","Art"),b=new Track("jamendo","1","B","Art");long id=db.createPlaylist("Viagem");db.add(id,a);db.add(id,b);db.saveSession(Arrays.asList(b,a),1,12000,2,true);db.close();db=new MusicDatabase(context);assertEquals(2,db.playlist(id).size());MusicDatabase.Snapshot s=db.restore();assertEquals("jamendo:1",s.tracks.get(0).key());assertEquals(12000,s.position);assertEquals(1,s.index);assertTrue(s.shuffle);}
    @Test public void updatingTrackPreservesPlaylistAndFavorite(){Track a=new Track("audius","1","A","Art");long id=db.createPlaylist("Mix");db.add(id,a);db.favorite(a);a.title="Changed";db.save(a);assertEquals("Changed",db.playlist(id).get(0).title);assertEquals(1,db.library("favorites").size());db.deletePlaylist(id);assertEquals(1,db.library("favorites").size());}
    @Test public void reorderAndDuplicatePersist(){Track a=new Track("audius","1","A","Art"),b=new Track("audius","2","B","Art");long id=db.createPlaylist("Mix");db.replace(id,Arrays.asList(b,a));MusicDatabase.Playlist p=db.playlists().get(0);long copy=db.duplicate(p);db.replace(id,Collections.singletonList(a));assertEquals("audius:2",db.playlist(copy).get(0).key());assertEquals(1,db.playlist(id).size());}
}
