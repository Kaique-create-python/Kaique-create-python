package dev.edith.spotifast.ui;

import android.graphics.*;
import android.graphics.drawable.Drawable;
import android.view.Gravity;
import android.widget.TextView;

/** Original vector controls drawn on a shared 24-unit grid; independent of emoji fonts. */
public final class MusicIcons extends Drawable {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final String kind;private final int size;
    private MusicIcons(String kind,int color,int size){this.kind=kind;this.size=size;paint.setColor(color);paint.setStrokeWidth(1.8f);paint.setStrokeCap(Paint.Cap.ROUND);paint.setStrokeJoin(Paint.Join.ROUND);}
    public static void bind(TextView view,String kind,int color){
        view.setText("");view.setGravity(Gravity.CENTER);
        view.setCompoundDrawablesWithIntrinsicBounds(new MusicIcons(kind,color,Design.dp(view.getContext(),24)),null,null,null);
    }
    public static String navigation(String tab){return tab.equals("Início")?"home":tab.equals("Buscar")?"search":tab.equals("Biblioteca")?"library":"playlist";}
    @Override public void draw(Canvas canvas){
        int saved=canvas.save();Rect b=getBounds();canvas.translate(b.left,b.top);canvas.scale(b.width()/24f,b.height()/24f);paint.setStyle(Paint.Style.STROKE);
        switch(kind){
            case "home":path(canvas,3,11,12,3,21,11);path(canvas,5,10,5,21,10,21,10,15,14,15,14,21,19,21,19,10);break;
            case "search":canvas.drawCircle(10.5f,10.5f,6.5f,paint);canvas.drawLine(15.3f,15.3f,21,21,paint);break;
            case "library":canvas.drawRoundRect(3,4,7,21,1,1,paint);canvas.drawRoundRect(10,4,14,21,1,1,paint);path(canvas,17,5,20,4,23,20,20,21,17,5);break;
            case "playlist":canvas.drawLine(4,5,18,5,paint);canvas.drawLine(4,10,18,10,paint);canvas.drawLine(4,15,11,15,paint);canvas.drawLine(17,14,17,22,paint);canvas.drawLine(13,18,21,18,paint);break;
            case "pause":paint.setStyle(Paint.Style.FILL);canvas.drawRoundRect(6,4,10,20,1,1,paint);canvas.drawRoundRect(14,4,18,20,1,1,paint);break;
            case "next":paint.setStyle(Paint.Style.FILL);path(canvas,5,4,17,12,5,20,5,4);canvas.drawRect(18,4,20,20,paint);break;
            case "previous":paint.setStyle(Paint.Style.FILL);path(canvas,19,4,7,12,19,20,19,4);canvas.drawRect(4,4,6,20,paint);break;
            default:paint.setStyle(Paint.Style.FILL);path(canvas,7,3,21,12,7,21,7,3);break;
        }
        canvas.restoreToCount(saved);
    }
    private void path(Canvas c,float... points){Path p=new Path();p.moveTo(points[0],points[1]);for(int i=2;i<points.length;i+=2)p.lineTo(points[i],points[i+1]);c.drawPath(p,paint);}
    @Override public int getIntrinsicWidth(){return size;}
    @Override public int getIntrinsicHeight(){return size;}
    @Override public void setAlpha(int alpha){paint.setAlpha(alpha);invalidateSelf();}
    @Override public void setColorFilter(ColorFilter filter){paint.setColorFilter(filter);invalidateSelf();}
    @Override public int getOpacity(){return PixelFormat.TRANSLUCENT;}
}
