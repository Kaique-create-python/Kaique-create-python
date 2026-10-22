package dev.edith.spotifast.playback;

import android.net.Uri;
import android.os.Bundle;
import androidx.media3.common.*;
import dev.edith.spotifast.data.Track;
import java.util.*;
import org.json.JSONObject;

@androidx.annotation.OptIn(markerClass=androidx.media3.common.util.UnstableApi.class)
public final class MediaItems {
    public static MediaItem of(Track t) {
        Bundle extras=new Bundle();try {extras.putString("track",t.json().toString());}catch(Exception e){throw new IllegalArgumentException(e);}
        MediaMetadata.Builder metadata=new MediaMetadata.Builder().setTitle(t.title).setArtist(t.artist)
                .setAlbumTitle(t.album).setExtras(extras).setIsPlayable(true).setMediaType(MediaMetadata.MEDIA_TYPE_MUSIC);
        if(!t.artwork.isEmpty())metadata.setArtworkUri(Uri.parse(t.artwork));
        return new MediaItem.Builder().setMediaId(t.key()).setUri(t.provider.equals("local")?t.id:"spotifast://"+t.provider+"/"+t.id)
                .setMediaMetadata(metadata.build()).build();
    }
    public static Track track(MediaItem item) {
        try {return Track.fromJson(new JSONObject(Objects.requireNonNull(item.mediaMetadata.extras).getString("track","")));}
        catch(Exception e){throw new IllegalArgumentException("Metadados de faixa inválidos",e);}
    }
    public static List<MediaItem> of(List<Track> tracks) {List<MediaItem> out=new ArrayList<>();for(Track t:tracks)out.add(of(t));return out;}
}
