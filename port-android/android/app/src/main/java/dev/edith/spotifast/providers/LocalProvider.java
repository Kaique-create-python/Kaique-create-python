package dev.edith.spotifast.providers;

import android.Manifest;
import android.content.*;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.os.*;
import android.provider.MediaStore;
import dev.edith.spotifast.data.Track;
import java.util.*;

/** Audio-only MediaStore access. The permission is requested only by an explicit UI action. */
public final class LocalProvider {
    public static String permission(){return Build.VERSION.SDK_INT>=33?Manifest.permission.READ_MEDIA_AUDIO:Manifest.permission.READ_EXTERNAL_STORAGE;}
    public static boolean permitted(Context c){return c.checkSelfPermission(permission())==PackageManager.PERMISSION_GRANTED;}
    public static List<Track> search(Context c,String query,int offset,CancellationSignal signal){
        List<Track> out=new ArrayList<>();if(!permitted(c))return out;
        String[] fields={"_id","title","artist","album","album_id","duration","_display_name"};
        String selection="is_music!=0";String[] args=null;
        if(!query.trim().isEmpty()){
            selection+=" AND (title LIKE ? OR artist LIKE ? OR album LIKE ?)";
            String pattern="%"+query.trim()+"%";args=new String[]{pattern,pattern,pattern};
        }
        try(Cursor cursor=c.getContentResolver().query(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,fields,selection,args,"title COLLATE NOCASE,_id",signal)){
            if(cursor==null)return out;
            if(offset>0&&!cursor.moveToPosition(offset-1))return out;
            while(out.size()<25&&cursor.moveToNext()){
                signal.throwIfCanceled();long id=cursor.getLong(0),album=cursor.getLong(4);
                String title=cursor.getString(1),artist=cursor.getString(2);
                if(title==null||title.trim().isEmpty())title=cursor.getString(6);
                if(title==null||title.trim().isEmpty())title="Arquivo de áudio";
                if(artist==null||artist.trim().isEmpty()||artist.equals("<unknown>"))artist="Artista desconhecido";
                Track t=new Track("local",ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,id).toString(),title,artist);
                t.album=cursor.getString(3)==null?"":cursor.getString(3);t.duration=cursor.getLong(5);
                if(album>0)t.artwork=ContentUris.withAppendedId(android.net.Uri.parse("content://media/external/audio/albumart"),album).toString();
                out.add(t);
            }
        }
        return out;
    }
}
