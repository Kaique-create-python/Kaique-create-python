package dev.edith.spotifast;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.recyclerview.widget.RecyclerView;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import dev.edith.spotifast.data.Track;
import dev.edith.spotifast.ui.TrackAdapter;
import java.util.Arrays;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Regression for the zero-width text column visible in the user's screenshots. */
@RunWith(AndroidJUnit4.class)
public class UiLayoutTest {
    @Test public void trackRowsHaveReadableTitleAndFillParentWidth() {
        Instrumentation instrumentation=InstrumentationRegistry.getInstrumentation();
        Intent intent=new Intent(instrumentation.getTargetContext(),FreeMusicActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        Activity activity=instrumentation.startActivitySync(intent);
        instrumentation.waitForIdleSync();
        instrumentation.runOnMainSync(()->{
            RecyclerView parent=new RecyclerView(activity);
            TrackAdapter adapter=new TrackAdapter(activity,new TrackAdapter.Actions(){
                public void play(int i){}
                public void menu(int i){}
            });
            adapter.submit(Arrays.asList(new Track("audius","abc123","Uma música com nome visível","Artista de teste")));
            TrackAdapter.Holder holder=adapter.onCreateViewHolder(parent,0);
            adapter.onBindViewHolder(holder,0);
            View row=holder.itemView;
            int width=(int)(360*activity.getResources().getDisplayMetrics().density);
            row.measure(View.MeasureSpec.makeMeasureSpec(width,View.MeasureSpec.EXACTLY),
                        View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED));
            assertEquals(ViewGroup.LayoutParams.MATCH_PARENT,row.getLayoutParams().width);
            LinearLayout info=(LinearLayout)((LinearLayout)row).getChildAt(1);
            assertTrue("Title column should have room for readable text",info.getMeasuredWidth()>width/3);
            TextView title=(TextView)info.getChildAt(0);
            assertTrue(title.getText().toString().contains("nome visível"));
            assertTrue(title.getMeasuredWidth()>0);
        });
        instrumentation.runOnMainSync(activity::finish);
    }
}
