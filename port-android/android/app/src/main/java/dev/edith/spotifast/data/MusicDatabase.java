package dev.edith.spotifast.data;

import android.content.*;
import android.database.Cursor;
import android.database.sqlite.*;
import java.util.*;
import java.util.concurrent.*;

/** Versioned SQLite, foreign keys and transactions. All callers use IO, never the main thread. */
public final class MusicDatabase extends SQLiteOpenHelper {
    public static final ExecutorService IO = Executors.newSingleThreadExecutor();
    private static volatile MusicDatabase instance;
    public static MusicDatabase get(Context c) {
        if (instance == null) synchronized (MusicDatabase.class) {
            if (instance == null) instance = new MusicDatabase(c.getApplicationContext());
        }
        return instance;
    }
    public MusicDatabase(Context c) { this(c, "spotifast-library.db"); }
    public MusicDatabase(Context c, String name) { super(c, name, null, 1); setWriteAheadLoggingEnabled(true); }
    @Override public void onConfigure(SQLiteDatabase db) { db.setForeignKeyConstraintsEnabled(true); }
    @Override public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE tracks (key TEXT PRIMARY KEY, provider TEXT NOT NULL, track_id TEXT NOT NULL, title TEXT NOT NULL, artist TEXT NOT NULL, artwork TEXT NOT NULL, artist_id TEXT NOT NULL, album_id TEXT NOT NULL, album TEXT NOT NULL, genre TEXT NOT NULL, license TEXT NOT NULL, share_url TEXT NOT NULL, duration INTEGER NOT NULL, unavailable TEXT NOT NULL, discovered INTEGER NOT NULL, UNIQUE(provider,track_id))");
        db.execSQL("CREATE TABLE playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', artwork TEXT NOT NULL DEFAULT '')");
        db.execSQL("CREATE TABLE entries (id INTEGER PRIMARY KEY AUTOINCREMENT, playlist INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE, track TEXT NOT NULL REFERENCES tracks(key), position INTEGER NOT NULL, added INTEGER NOT NULL)");
        db.execSQL("CREATE INDEX entries_order ON entries(playlist,position)");
        db.execSQL("CREATE TABLE favorites (track TEXT PRIMARY KEY REFERENCES tracks(key), added INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE history (track TEXT PRIMARY KEY REFERENCES tracks(key), played INTEGER NOT NULL, count INTEGER NOT NULL)");
        db.execSQL("CREATE TABLE queue (position INTEGER PRIMARY KEY, track TEXT NOT NULL REFERENCES tracks(key))");
        db.execSQL("CREATE TABLE session (id INTEGER PRIMARY KEY CHECK(id=1), current_index INTEGER NOT NULL, position INTEGER NOT NULL, repeat_mode INTEGER NOT NULL, shuffle INTEGER NOT NULL)");
    }
    @Override public void onUpgrade(SQLiteDatabase db, int old, int next) {
        throw new IllegalStateException("Missing non-destructive database migration " + old + " to " + next);
    }
    public void save(Track t) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues v = new ContentValues();
        v.put("key", t.key()); v.put("provider", t.provider); v.put("track_id", t.id);
        v.put("title", t.title); v.put("artist", t.artist); v.put("artwork", t.artwork);
        v.put("artist_id", t.artistId); v.put("album_id", t.albumId); v.put("album", t.album);
        v.put("genre", t.genre); v.put("license", t.license); v.put("share_url", t.shareUrl);
        v.put("duration", t.duration); v.put("unavailable", t.unavailable);
        // UPDATE instead of REPLACE: retain discovery time and all foreign-key references.
        if (db.update("tracks", v, "key=?", new String[]{t.key()}) == 0) {
            v.put("discovered", System.currentTimeMillis()); db.insertOrThrow("tracks", null, v);
        }
    }
    private Track read(Cursor c) {
        Track t = new Track(s(c,"provider"),s(c,"track_id"),s(c,"title"),s(c,"artist"));
        t.artwork=s(c,"artwork"); t.artistId=s(c,"artist_id"); t.albumId=s(c,"album_id");
        t.album=s(c,"album"); t.genre=s(c,"genre"); t.license=s(c,"license");
        t.shareUrl=s(c,"share_url"); t.unavailable=s(c,"unavailable");
        t.duration=c.getLong(c.getColumnIndexOrThrow("duration")); return t;
    }
    private static String s(Cursor c,String name) { return c.getString(c.getColumnIndexOrThrow(name)); }
    private List<Track> query(String sql,String... args) {
        List<Track> out=new ArrayList<>();
        try(Cursor c=getReadableDatabase().rawQuery(sql,args)) { while(c.moveToNext()) out.add(read(c)); }
        return out;
    }
    public List<Track> library(String kind) {
        switch(kind) {
            case "favorites": return query("SELECT t.* FROM tracks t JOIN favorites f ON t.key=f.track ORDER BY f.added DESC LIMIT 500");
            case "most": return query("SELECT t.* FROM tracks t JOIN history h ON t.key=h.track ORDER BY h.count DESC LIMIT 100");
            case "discoveries": return query("SELECT * FROM tracks ORDER BY discovered DESC LIMIT 100");
            default: return query("SELECT t.* FROM tracks t JOIN history h ON t.key=h.track ORDER BY h.played DESC LIMIT 100");
        }
    }
    public boolean favorite(Track t) {
        save(t); SQLiteDatabase db=getWritableDatabase();
        if(db.delete("favorites","track=?",new String[]{t.key()})>0) return false;
        ContentValues v=new ContentValues();v.put("track",t.key());v.put("added",System.currentTimeMillis());db.insertOrThrow("favorites",null,v);return true;
    }
    public void played(Track t) {
        save(t); SQLiteDatabase db=getWritableDatabase();
        db.execSQL("INSERT OR IGNORE INTO history(track,played,count) VALUES(?,0,0)",new Object[]{t.key()});
        db.execSQL("UPDATE history SET played=?,count=count+1 WHERE track=?",new Object[]{System.currentTimeMillis(),t.key()});
    }
    public long createPlaylist(String name) {
        ContentValues v=new ContentValues();v.put("name",validName(name)); return getWritableDatabase().insertOrThrow("playlists",null,v);
    }
    private String validName(String name) { if(name.trim().isEmpty()) throw new IllegalArgumentException("Informe um nome");return name.trim(); }
    public void editPlaylist(long id,String name,String description,String art) {
        ContentValues v=new ContentValues();v.put("name",validName(name));v.put("description",description);v.put("artwork",art);
        getWritableDatabase().update("playlists",v,"id=?",new String[]{""+id});
    }
    public void deletePlaylist(long id) { getWritableDatabase().delete("playlists","id=?",new String[]{""+id}); }
    public List<Playlist> playlists() {
        List<Playlist> out=new ArrayList<>();
        try(Cursor c=getReadableDatabase().rawQuery("SELECT p.*,COUNT(e.id) AS count,COALESCE(SUM(t.duration),0) AS duration FROM playlists p LEFT JOIN entries e ON p.id=e.playlist LEFT JOIN tracks t ON t.key=e.track GROUP BY p.id ORDER BY p.name COLLATE NOCASE",null)) {
            while(c.moveToNext()) { Playlist p=new Playlist();p.id=c.getLong(0);p.name=s(c,"name");p.description=s(c,"description");p.artwork=s(c,"artwork");p.count=c.getInt(c.getColumnIndexOrThrow("count"));p.duration=c.getLong(c.getColumnIndexOrThrow("duration"));out.add(p); }
        } return out;
    }
    public List<Track> playlist(long id) { return query("SELECT t.* FROM entries e JOIN tracks t ON t.key=e.track WHERE e.playlist=? ORDER BY e.position,e.id",""+id); }
    public void add(long id,Track t) {
        SQLiteDatabase db=getWritableDatabase();db.beginTransaction();try {
            save(t);db.execSQL("INSERT INTO entries(playlist,track,position,added) SELECT ?,?,COALESCE(MAX(position),-1)+1,? FROM entries WHERE playlist=?",new Object[]{id,t.key(),System.currentTimeMillis(),id});db.setTransactionSuccessful();
        } finally { db.endTransaction(); }
    }
    public void replace(long id,List<Track> tracks) {
        SQLiteDatabase db=getWritableDatabase(); db.beginTransaction();try {
            db.delete("entries","playlist=?",new String[]{""+id});for(Track t:tracks) add(id,t);db.setTransactionSuccessful();
        } finally { db.endTransaction(); }
    }
    public long importPlaylist(String name, String description, List<Track> tracks) {
        SQLiteDatabase db=getWritableDatabase();db.beginTransaction();try {
            long id=createPlaylist(name);editPlaylist(id,name,description,"");replace(id,tracks);
            db.setTransactionSuccessful();return id;
        } finally {db.endTransaction();}
    }
    public long duplicate(Playlist p) {
        SQLiteDatabase db=getWritableDatabase();db.beginTransaction();try {
            long id=createPlaylist(p.name+" (cópia)");editPlaylist(id,p.name+" (cópia)",p.description,p.artwork);
            replace(id,playlist(p.id));db.setTransactionSuccessful();return id;
        } finally {db.endTransaction();}
    }
    public void saveSession(List<Track> tracks,int index,long position,int repeat,boolean shuffle) {
        SQLiteDatabase db=getWritableDatabase();db.beginTransaction();try {
            db.delete("queue",null,null);
            for(int i=0;i<tracks.size();i++) { save(tracks.get(i)); db.execSQL("INSERT INTO queue VALUES(?,?)",new Object[]{i,tracks.get(i).key()}); }
            db.execSQL("INSERT OR REPLACE INTO session VALUES(1,?,?,?,?)",new Object[]{index,position,repeat,shuffle?1:0});db.setTransactionSuccessful();
        } finally {db.endTransaction();}
    }
    public Snapshot restore() {
        Snapshot s=new Snapshot();s.tracks=query("SELECT t.* FROM queue q JOIN tracks t ON t.key=q.track ORDER BY q.position");
        try(Cursor c=getReadableDatabase().rawQuery("SELECT * FROM session WHERE id=1",null)) {
            if(c.moveToFirst()) {s.index=c.getInt(1);s.position=c.getLong(2);s.repeat=c.getInt(3);s.shuffle=c.getInt(4)!=0;}
        } return s;
    }
    public static final class Snapshot { public List<Track> tracks=new ArrayList<>();public int index,repeat;public long position;public boolean shuffle; }
    public static final class Playlist {public long id,duration;public String name,description,artwork;public int count;}
}
