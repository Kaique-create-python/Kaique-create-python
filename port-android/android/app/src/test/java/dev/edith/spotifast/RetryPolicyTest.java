package dev.edith.spotifast;
import dev.edith.spotifast.playback.RetryPolicy;
import org.junit.Test;
import static org.junit.Assert.*;
public class RetryPolicyTest {
    @Test public void networkRecoveryIsBounded(){
        assertEquals(1000,RetryPolicy.delay(2001,0));
        assertEquals(2000,RetryPolicy.delay(2002,1));
        assertEquals(4000,RetryPolicy.delay(2001,2));
        assertEquals(-1,RetryPolicy.delay(2001,3));
    }
    @Test public void neverRetriesDenialMissingFileOrDecoderFailure(){
        for(int code:new int[]{2004,2005,2006,3001,4001})assertEquals(-1,RetryPolicy.delay(code,0));
    }
}
