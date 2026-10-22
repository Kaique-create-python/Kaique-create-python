package dev.edith.spotifast.ui;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.*;
import android.view.*;
import android.widget.*;

/** Original SpotiFast palette and adaptive touch dimensions. */
public final class Design {
    public static final int BG=0xff0b0f10;
    public static final int PANEL=0xff1c2225;
    public static final int RAISED=0xff272d30;
    public static final int GREEN=0xff43df9b;
    public static final int WHITE=0xfff4f6f5;
    public static final int MUTED=0xffa0acaf;

    public static int dp(Context c,float n){return (int)(n*c.getResources().getDisplayMetrics().density+.5f);}
    public static GradientDrawable shape(Context c,int color,int radius){
        GradientDrawable d=new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(c,radius));
        return d;
    }
    public static GradientDrawable gradient(Context c,int top,int bottom,int radius){
        GradientDrawable d=new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,new int[]{top,bottom});
        d.setCornerRadius(dp(c,radius));
        return d;
    }
    public static LinearLayout column(Context c){LinearLayout v=new LinearLayout(c);v.setOrientation(LinearLayout.VERTICAL);return v;}
    public static LinearLayout row(Context c){LinearLayout v=new LinearLayout(c);v.setOrientation(LinearLayout.HORIZONTAL);v.setGravity(Gravity.CENTER_VERTICAL);return v;}
    public static TextView text(Context c,String value,int size,boolean bold){
        TextView t=new TextView(c);t.setText(value);t.setTextSize(size);t.setTextColor(WHITE);
        if(bold)t.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));
        return t;
    }
    public static Button button(Context c,String label,boolean primary){
        Button b=new Button(c);b.setText(label);b.setAllCaps(false);b.setTextSize(14);
        b.setTextColor(primary?BG:WHITE);b.setMinHeight(dp(c,44));
        b.setMinimumWidth(0);b.setMinWidth(0);
        b.setPadding(dp(c,12),dp(c,6),dp(c,12),dp(c,6));
        b.setBackground(new RippleDrawable(ColorStateList.valueOf(0x335be5a9),
            shape(c,primary?GREEN:PANEL,22),null));
        return b;
    }
    public static EditText input(Context c,String hint){
        EditText e=new EditText(c);e.setTextColor(WHITE);e.setHintTextColor(MUTED);e.setHint(hint);
        e.setTextSize(16);e.setSingleLine(true);
        e.setPadding(dp(c,14),dp(c,8),dp(c,14),dp(c,8));
        e.setBackground(shape(c,PANEL,14));e.setMinimumHeight(dp(c,48));return e;
    }
    public static void gap(Context c,LinearLayout v,int h){v.addView(new View(c),new LinearLayout.LayoutParams(1,dp(c,h)));}
    public static String time(long ms){long s=Math.max(0,ms)/1000;return String.format(java.util.Locale.ROOT,"%d:%02d",s/60,s%60);}
}
