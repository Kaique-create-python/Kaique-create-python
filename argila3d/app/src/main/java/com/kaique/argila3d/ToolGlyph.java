package com.kaique.argila3d;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.drawable.Drawable;

/**
 * Lightweight vector icons, sized for touch controls and rendered at device density.
 * Each icon is an original geometric drawing, not an emoji or downloaded asset.
 */
public final class ToolGlyph extends Drawable {
    public static final int SCULPT=1, VERTEX=2, EDGE=3, FACE=4, ORBIT=5;
    public static final int RAISE=6, LOWER=7, INFLATE=8, SMOOTH=9;

    private final int type, color, size;
    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path path = new Path();

    public ToolGlyph(int type, int color, float density) {
        this.type = type;
        this.color = color;
        this.size = Math.round(24 * density);
        p.setStrokeWidth(1.65f);
        p.setStrokeJoin(Paint.Join.ROUND);
        p.setStrokeCap(Paint.Cap.ROUND);
        p.setStyle(Paint.Style.STROKE);
    }

    @Override public int getIntrinsicWidth() { return size; }
    @Override public int getIntrinsicHeight() { return size; }

    private void line(Canvas c, float x, float y, float a, float b) {
        c.drawLine(x, y, a, b, p);
    }
    private void dot(Canvas c, float x, float y, float radius) {
        p.setStyle(Paint.Style.FILL);
        c.drawCircle(x, y, radius, p);
        p.setStyle(Paint.Style.STROKE);
    }
    private void lines(Canvas c, float... xy) {
        path.reset();
        path.moveTo(xy[0], xy[1]);
        for (int i=2; i<xy.length; i+=2) path.lineTo(xy[i], xy[i+1]);
        c.drawPath(path, p);
    }

    @Override public void draw(Canvas canvas) {
        android.graphics.Rect b = getBounds();
        canvas.save();
        canvas.translate(b.left, b.top);
        canvas.scale(b.width()/24f, b.height()/24f);
        p.setColor(color);
        p.setAlpha(getAlpha());
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(1.65f);
        switch(type) {
            case SCULPT:
                lines(canvas, 5,19, 4,12, 6,10, 9,13, 9,4, 11,3, 13,4, 13,11, 15,9, 17,10, 17,12, 19,11, 21,13, 20,18, 17,21, 9,21, 5,19);
                line(canvas, 13,11,13,14);
                break;
            case VERTEX:
                lines(canvas,4,18, 12,4, 20,18, 4,18);
                line(canvas,12,4,12,12);
                dot(canvas,4,18,2.4f); dot(canvas,12,4,2.4f); dot(canvas,20,18,2.4f);
                break;
            case EDGE:
                lines(canvas,3,17,12,6,21,17);
                line(canvas,3,17,21,17);
                dot(canvas,3,17,2.1f); dot(canvas,12,6,2.1f); dot(canvas,21,17,2.1f);
                break;
            case FACE:
                lines(canvas,4,18, 11,3, 21,17, 4,18);
                line(canvas,11,3,12,15);
                line(canvas,12,15,4,18);
                line(canvas,12,15,21,17);
                dot(canvas,12,15,1.5f);
                break;
            case ORBIT:
                canvas.drawOval(3,7,21,17,p);
                line(canvas,18,4,21,7); line(canvas,21,7,18,9);
                line(canvas,6,20,3,17); line(canvas,3,17,6,15);
                canvas.drawCircle(12,12,4,p);
                break;
            case RAISE:
                lines(canvas,3,19,8,16,12,11,16,16,21,19);
                line(canvas,12,10,12,3);
                lines(canvas,8.5f,6.5f,12,3,15.5f,6.5f);
                line(canvas,4,21,20,21);
                break;
            case LOWER:
                lines(canvas,3,18,8,15,12,11,16,15,21,18);
                line(canvas,12,3,12,9);
                lines(canvas,8.5f,6,12,9.5f,15.5f,6);
                line(canvas,4,21,20,21);
                break;
            case INFLATE:
                canvas.drawCircle(12,12,6,p);
                dot(canvas,10,10,1);
                line(canvas,12,3,12,1); line(canvas,12,21,12,23);
                line(canvas,3,12,1,12); line(canvas,21,12,23,12);
                line(canvas,6,6,4,4); line(canvas,18,18,20,20);
                line(canvas,18,6,20,4); line(canvas,6,18,4,20);
                break;
            case SMOOTH:
                lines(canvas,2,9,6,6,10,9,14,6,18,9,22,6);
                lines(canvas,2,14,6,11,10,14,14,11,18,14,22,11);
                lines(canvas,2,19,6,16,10,19,14,16,18,19,22,16);
                break;
            default:
                canvas.drawCircle(12,12,5,p);
        }
        canvas.restore();
    }
    @Override public void setAlpha(int alpha) { p.setAlpha(alpha); invalidateSelf(); }
    @Override public void setColorFilter(ColorFilter filter) { p.setColorFilter(filter); invalidateSelf(); }
    @Override public int getOpacity() { return PixelFormat.TRANSLUCENT; }
}