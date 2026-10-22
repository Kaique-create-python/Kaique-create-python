package dev.edith.spotifast;
import android.content.Intent;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;
@RunWith(AndroidJUnit4.class)
public class LaunchTest {
    @Test public void androidShellLaunchesWithoutLoadingRustLogin(){android.app.Instrumentation i=InstrumentationRegistry.getInstrumentation();Intent intent=new Intent(i.getTargetContext(),FreeMusicActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);android.app.Activity activity=i.startActivitySync(intent);i.waitForIdleSync();assertFalse(activity.isFinishing());i.runOnMainSync(activity::finish);}
}
