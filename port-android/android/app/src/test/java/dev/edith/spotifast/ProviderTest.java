package dev.edith.spotifast;

import dev.edith.spotifast.providers.*;
import dev.edith.spotifast.data.Track;
import org.json.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class ProviderTest {
    @Test public void rejectsAudiusGatesAndExplicitStreamDenial() throws Exception {
        assertFalse(AudiusProvider.parse(new JSONObject("{\"id\":\"abc\",\"is_stream_gated\":true}")).playable());
        assertFalse(AudiusProvider.parse(new JSONObject("{\"id\":\"abc\",\"is_streamable\":false}")).playable());
        assertFalse(AudiusProvider.parse(new JSONObject("{\"id\":\"abc\",\"access\":{\"stream\":false}}")).playable());
        assertFalse(AudiusProvider.parse(new JSONObject("{\"id\":\"abc\",\"stream_conditions\":{\"follow_user_id\":1}}")).playable());
    }
    @Test public void keepsPublicTrackMetadata() throws Exception {
        Track t=AudiusProvider.parse(new JSONObject("{\"id\":\"abc\",\"title\":\"Music\",\"duration\":15,\"user\":{\"id\":\"artist\",\"name\":\"Art\"},\"artwork\":{\"480x480\":\"https://example.com/cover.jpg\"}}"));
        assertTrue(t.playable());assertEquals(15000,t.duration);assertEquals("artist",t.artistId);assertTrue(t.artwork.endsWith("cover.jpg"));
    }
    @Test public void audiusDetailIsObjectNotArray() throws Exception {
        JSONObject response=new JSONObject("{\"data\":{\"id\":\"D7KyD\",\"title\":\"Song\",\"user\":{\"name\":\"Artist\"},\"is_streamable\":true}}");
        Track t=AudiusProvider.parseTrackDetail(response);
        assertEquals("D7KyD",t.id);
        assertTrue(t.playable());
    }
    @Test public void audiusDetailStillAcceptsLegacyArray() throws Exception {
        Track t=AudiusProvider.parseTrackDetail(new JSONObject("{\"data\":[{\"id\":\"abc123\",\"title\":\"Song\"}]}"));
        assertEquals("abc123",t.id);
    }
    @Test(expected=java.io.IOException.class) public void audiusRejectsAbsentTrackDetails() throws Exception {
        AudiusProvider.parseTrackDetail(new JSONObject("{\"data\":null}"));
    }
    @Test(expected=java.io.IOException.class) public void audiusRejectsGatedDetail() throws Exception {
        AudiusProvider.parseTrackDetail(new JSONObject("{\"data\":{\"id\":\"abc123\",\"is_stream_gated\":true}}"));
    }
    @Test(expected=java.io.IOException.class) public void jamendoApiErrorIsNotAnEmptyResult() throws Exception {JamendoProvider.parseResponse(new JSONObject("{\"headers\":{\"code\":5},\"results\":[]}"));}
    @Test public void jamendoKeepsSingleAndLicenseWithoutDownload() throws Exception {
        Track t=JamendoProvider.parseResponse(new JSONObject("{\"headers\":{\"code\":0},\"results\":[{\"id\":\"42\",\"name\":\"Single\",\"image\":\"https://example.com/cover\",\"audio\":\"https://example.com/audio\",\"audiodownload_allowed\":false,\"license_ccurl\":\"https://creativecommons.org/licenses/by/4.0/\"}]}")).get(0);
        assertTrue(t.playable());assertFalse(t.license.isEmpty());assertEquals("",t.albumId);
    }
    @Test public void mixedProviderIdentitySurvivesExport() throws Exception {Track a=new Track("audius","1","One","Artist"),j=new Track("jamendo","1","One","Artist");assertNotEquals(a.key(),j.key());assertEquals(a.key(),Track.fromJson(a.json()).key());}
    @Test(expected=IllegalArgumentException.class) public void youtubeCannotBecomeAnAudioTrack() throws Exception {Track.fromJson(new JSONObject("{\"provider\":\"youtube\",\"trackId\":\"dQw4w9WgXcQ\"}"));}
    @Test public void validatesYouTubeOriginAndId(){assertEquals("dQw4w9WgXcQ",YouTubeIds.parse("https://youtu.be/dQw4w9WgXcQ"));assertEquals("dQw4w9WgXcQ",YouTubeIds.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3"));assertNull(YouTubeIds.parse("https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ"));assertNull(YouTubeIds.parse("http://youtu.be/dQw4w9WgXcQ"));assertNull(YouTubeIds.parse("javascript:alert(1)"));}
}
