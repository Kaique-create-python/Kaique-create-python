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
    @Before public void before(){context=InstrumentationRegistry.getInstrumentation().getTargetContext();context.deleteDatabase("spotifast-library-test.db");db=new MusicDatabase(context,"spotifast-library-test.db");}
    @After public void after(){db.close();}
    @Test public void playlistAndSessionSurviveReopen(){Track a=new Track("audius","1","A","Art"),b=new Track("jamendo","1","B","Art");long id=db.createPlaylist("Viagem");db.add(id,a);db.add(id,b);db.saveSession(Arrays.asList(b,a),1,12000,2,true);db.close();db=new MusicDatabase(context,"spotifast-library-test.db");assertEquals(2,db.playlist(id).size());MusicDatabase.Snapshot s=db.restore();assertEquals("jamendo:1",s.tracks.get(0).key());assertEquals(12000,s.position);assertEquals(1,s.index);assertTrue(s.shuffle);}
    @Test public void updatingTrackPreservesPlaylistAndFavorite(){Track a=new Track("audius","1","A","Art");long id=db.createPlaylist("Mix");db.add(id,a);db.favorite(a);a.title="Changed";db.save(a);assertEquals("Changed",db.playlist(id).get(0).title);assertEquals(1,db.library("favorites").size());db.deletePlaylist(id);assertEquals(1,db.library("favorites").size());}
    @Test public void reorderAndDuplicatePersist(){Track a=new Track("audius","1","A","Art"),b=new Track("audius","2","B","Art");long id=db.createPlaylist("Mix");db.replace(id,Arrays.asList(b,a));MusicDatabase.Playlist p=db.playlists().get(0);long copy=db.duplicate(p);db.replace(id,Collections.singletonList(a));assertEquals("audius:2",db.playlist(copy).get(0).key());assertEquals(1,db.playlist(id).size());}
    @Test public void migrationFromV5PreservesLibraryAndCollapsesDuplicates(){
        Track a=new Track("audius","1","A","Artist");long id=db.createPlaylist("V5");db.add(id,a);db.favorite(a);
        android.database.sqlite.SQLiteDatabase sql=db.getWritableDatabase();
        sql.execSQL("DROP INDEX entries_unique");sql.execSQL("DROP INDEX history_recent");sql.execSQL("DROP INDEX tracks_artist_genre");sql.execSQL("DROP TABLE search_history");
        sql.execSQL("INSERT INTO entries(playlist,track,position,added) SELECT playlist,track,position+1,added FROM entries");
        sql.setVersion(1);db.close();db=new MusicDatabase(context,"spotifast-library-test.db");
        assertEquals(2,db.getReadableDatabase().getVersion());assertEquals(1,db.playlist(id).size());assertTrue(db.isFavorite(a));
        db.add(id,a);assertEquals(1,db.playlist(id).size());
        assertEquals("ok",android.database.DatabaseUtils.stringForQuery(db.getReadableDatabase(),"PRAGMA integrity_check",null));
    }
    @Test public void checkpointsDoNotRewriteUnchangedQueue(){
        Track a=new Track("audius","1","A","Artist");db.saveSession(Collections.singletonList(a),0,0,0,false);
        db.getWritableDatabase().execSQL("CREATE TRIGGER guard_queue BEFORE DELETE ON queue BEGIN SELECT RAISE(ABORT,'queue rewritten'); END");
        db.saveSession(Collections.singletonList(a),0,15000,1,true);
        assertEquals(15000,db.restore().position);assertTrue(db.restore().shuffle);
    }
    @Test public void historyIsBoundedAndCanBeClearedWithoutLosingFavorites(){
        Track a=new Track("audius","1","A","Artist");db.favorite(a);db.played(a);
        for(int i=0;i<40;i++)db.rememberSearch("query "+i);
        assertEquals(12,db.searchHistory().size());db.clearPersonalization();
        assertTrue(db.searchHistory().isEmpty());assertTrue(db.library("recent").isEmpty());assertTrue(db.isFavorite(a));
    }
    @Test public void recommendationsUseRealSavedMetadata(){
        Track seed=new Track("audius","1","Seed","A"),match=new Track("audius","2","Match","A"),other=new Track("audius","3","Other","B");
        seed.artistId=match.artistId="artist-a";db.favorite(seed);db.played(seed);db.save(match);db.save(other);
        assertEquals(match.key(),db.recommendations().get(0).key());
    }
    @Test public void backupRestoresPlaylistsFavoritesAndHistory() throws Exception {
        Track a=new Track("audius","1","Backup song","Artist");long id=db.createPlaylist("Saved");db.add(id,a);db.favorite(a);db.played(a);
        String json=db.exportBackup();db.close();context.deleteDatabase("spotifast-library-test.db");db=new MusicDatabase(context,"spotifast-library-test.db");db.importBackup(json);
        assertEquals(a.key(),db.playlist(db.playlists().get(0).id).get(0).key());assertTrue(db.isFavorite(a));assertEquals(1,db.library("most").size());
    }
    @Test public void invalidBackupRollsBackPartialWrites() throws Exception {
        Track a=new Track("audius","1","Keep","Artist");long id=db.createPlaylist("Keep");db.add(id,a);
        org.json.JSONObject data=new org.json.JSONObject(db.exportBackup());data.getJSONArray("playlists").getJSONObject(0).getJSONArray("entries").put("audius:missing");
        try{db.importBackup(data.toString());fail("Expected invalid reference");}catch(NullPointerException expected){}
        assertEquals(1,db.playlists().size());assertEquals(1,db.playlist(id).size());
    }
}

