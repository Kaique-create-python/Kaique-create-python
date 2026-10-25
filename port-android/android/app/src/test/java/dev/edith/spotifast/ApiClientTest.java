package dev.edith.spotifast;
import dev.edith.spotifast.providers.ApiClient;
import okhttp3.mockwebserver.*;
import org.junit.Test;
import static org.junit.Assert.*;
public class ApiClientTest {
    @Test public void streamingHasNoSongLengthDeadlineAndSharesConnections(){
        assertEquals(0,ApiClient.STREAM.callTimeoutMillis());
        assertEquals(25000,ApiClient.HTTP.callTimeoutMillis());
        assertTrue(ApiClient.STREAM.readTimeoutMillis()>0);
        assertSame(ApiClient.HTTP.connectionPool(),ApiClient.STREAM.connectionPool());
    }
    @Test(timeout=45000) public void streamStaysOpenBeyondMetadataDeadline() throws Exception {
        try(MockWebServer server=new MockWebServer()){
            String body="abcdefghijklmnopqrst";
            server.enqueue(new MockResponse().setBody(body).throttleBody(1,1500,java.util.concurrent.TimeUnit.MILLISECONDS));
            server.start();
            try(okhttp3.Response response=ApiClient.STREAM.newCall(new okhttp3.Request.Builder().url(server.url("/audio")).build()).execute()){
                assertNotNull(response.body());assertEquals(body,response.body().string());
            }
        }
    }
    @Test public void retriesTemporaryFailureAndCachesOnlyMetadata() throws Exception {
        try(MockWebServer server=new MockWebServer()) {server.enqueue(new MockResponse().setResponseCode(503));server.enqueue(new MockResponse().setBody("{\"data\":[]}"));server.start();String url=server.url("/search").toString();assertTrue(ApiClient.get(url,this,true).has("data"));ApiClient.get(url,this,true);assertEquals(2,server.getRequestCount());}
    }
    @Test public void permanentDenialIsNotRetried() throws Exception {
        try(MockWebServer server=new MockWebServer()){server.enqueue(new MockResponse().setResponseCode(403));server.start();try{ApiClient.get(server.url("/stream").toString(),this,false);fail();}catch(java.io.IOException expected){}assertEquals(1,server.getRequestCount());}
    }
}

