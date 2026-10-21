package dev.edith.spotifast.ui;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.*;
import android.view.*;
import android.widget.*;

public final class Design {
    public static final int BG=0xff0d1013,PANEL=0xff1c2226,GREEN=0xff51e0a3,WHITE=0xfff2f5f4,MUTED=0xffa8b5b2;
    public static int dp(Context c,float n){return (int)(n*c.getResources().getDisplayMetrics().density+.5f);}
    public static GradientDrawable shape(Context c,int color,int radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(c,radius));return d;}
    public static LinearLayout column(Context c){LinearLayout v=new LinearLayout(c);v.setOrientation(1);return v;}
    public static LinearLayout row(Context c){LinearLayout v=new LinearLayout(c);v.setGravity(Gravity.CENTER_VERTICAL);return v;}
    public static TextView text(Context c,String value,int size,boolean bold){TextView t=new TextView(c);t.setText(value);t.setTextSize(size);t.setTextColor(WHITE);if(bold)t.setTypeface(Typeface.DEFAULT,Typeface.BOLD);return t;}
    public static Button button(Context c,String label,boolean primary){Button b=new Button(c);b.setText(label);b.setAllCaps(false);b.setTextSize(13);b.setTextColor(primary?BG:WHITE);b.setMinHeight(dp(c,48));b.setMinimumWidth(0);b.setMinWidth(0);b.setPadding(dp(c,10),dp(c,4),dp(c,10),dp(c,4));b.setBackground(new RippleDrawable(ColorStateList.valueOf(0x4451e0a3),shape(c,primary?GREEN:PANEL,16),null));return b;}
    public static EditText input(Context c,String hint){EditText e=new EditText(c);e.setTextColor(WHITE);e.setHintTextColor(MUTED);e.setHint(hint);e.setTextSize(16);e.setSingleLine(true);e.setPadding(dp(c,14),dp(c,8),dp(c,14),dp(c,8));e.setBackground(shape(c,PANEL,16));e.setMinimumHeight(dp(c,48));return e;}
    public static void gap(Context c,LinearLayout v,int h){v.addView(new View(c),new LinearLayout.LayoutParams(1,dp(c,h)));}
    public static String time(long ms){long s=Math.max(0,ms)/1000;return String.format(java.util.Locale.ROOT,"%d:%02d",s/60,s%60);}
}
