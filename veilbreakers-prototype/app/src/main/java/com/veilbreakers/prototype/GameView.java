package com.veilbreakers.prototype;

import android.content.Context;
import android.graphics.*;
import android.view.MotionEvent;
import android.view.View;

import java.io.IOException;
import java.io.InputStream;

public class GameView extends View {
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Paint pixelPaint = new Paint();
    private final Paint uiPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private Bitmap moveSheet;
    private Bitmap attackSheet;
    @SuppressWarnings("unused") private Bitmap magicSheet;

    private float px = -1, py = -1;
    private float joyX, joyY;
    private int joyPointer = -1;
    private int attackPointer = -1;
    private int lastDir = 3; // 0 down, 1 up, 2 left, 3 right
    private long lastNs = System.nanoTime();
    private float animTime = 0f;
    private boolean attacking = false;
    private float attackTime = 0f;

    private final Rect[][] idle = new Rect[4][];
    private final Rect[][] run = new Rect[4][];
    private final Rect[][] attack = new Rect[4][];

    public GameView(Context context) {
        super(context);
        setFocusable(true);
        pixelPaint.setAntiAlias(false);
        pixelPaint.setFilterBitmap(false);
        uiPaint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        loadAssets(context);
        setupFrames();
    }

    private Bitmap load(Context c, String name) throws IOException {
        try (InputStream in = c.getAssets().open(name)) {
            return BitmapFactory.decodeStream(in);
        }
    }

    private void loadAssets(Context c) {
        try {
            moveSheet = load(c, "move_sheet.png");
            attackSheet = load(c, "attack_sheet.png");
            magicSheet = load(c, "magic_sheet.png");
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private Rect r(int l, int t, int rr, int b) { return new Rect(l, t, rr, b); }

    private void setupFrames() {
        // Coordinates are for the optimized 724x543 copies (50% of the generated sheets).
        idle[0] = new Rect[]{r(16,7,88,107), r(94,7,158,107), r(165,7,228,107), r(238,7,308,107)};
        idle[1] = new Rect[]{r(413,7,483,107), r(492,7,557,107), r(565,7,626,107), r(640,7,704,107)};
        idle[2] = new Rect[]{r(30,115,94,212), r(109,115,170,212), r(184,115,251,212), r(259,115,321,212)};
        idle[3] = new Rect[]{r(396,115,462,212), r(472,115,541,212), r(551,115,616,212), r(630,115,693,212)};

        run[0] = new Rect[]{r(5,219,63,307), r(64,219,118,307), r(122,219,180,307), r(181,219,235,307), r(238,219,294,307), r(297,219,356,307)};
        run[1] = new Rect[]{r(369,219,428,307), r(429,219,484,307), r(491,219,544,307), r(549,219,603,307), r(608,219,661,307), r(664,219,720,307)};
        run[2] = new Rect[]{r(0,311,66,395), r(66,311,126,395), r(126,311,186,395), r(186,311,246,395), r(246,311,302,395), r(302,311,362,395)};
        run[3] = new Rect[]{r(362,311,442,395), r(442,311,494,395), r(494,311,549,395), r(549,311,607,395), r(607,311,668,395), r(668,311,724,395)};

        // One fast five-frame slash sequence for each facing direction.
        attack[0] = new Rect[]{r(7,5,62,63), r(83,5,141,63), r(149,5,228,63), r(229,5,317,63), r(318,5,414,63)};
        attack[1] = new Rect[]{r(11,66,61,127), r(74,66,150,127), r(153,66,219,127), r(226,66,316,127), r(321,66,410,127)};
        attack[2] = new Rect[]{r(5,131,62,191), r(76,131,151,191), r(151,131,224,191), r(225,131,317,191), r(319,131,418,191)};
        attack[3] = new Rect[]{r(8,193,66,256), r(68,193,151,256), r(153,193,228,256), r(230,193,318,256), r(320,193,414,256)};
    }

    @Override protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        if (px < 0) { px = w * 0.5f; py = h * 0.47f; }
    }

    @Override protected void onDraw(Canvas c) {
        super.onDraw(c);
        long now = System.nanoTime();
        float dt = Math.min(0.033f, (now - lastNs) / 1_000_000_000f);
        lastNs = now;
        update(dt);
        drawArena(c);
        drawPlayer(c);
        drawControls(c);
        postInvalidateOnAnimation();
    }

    private void update(float dt) {
        animTime += dt;
        if (attacking) {
            attackTime += dt;
            if (attackTime >= 0.42f) { attacking = false; attackTime = 0f; }
            return;
        }
        float len = (float)Math.hypot(joyX, joyY);
        if (len > 0.12f) {
            float nx = joyX / Math.max(1f, len);
            float ny = joyY / Math.max(1f, len);
            float speed = getHeight() * 0.44f;
            px += nx * speed * dt;
            py += ny * speed * dt;
            float margin = getHeight() * 0.12f;
            px = Math.max(margin, Math.min(getWidth() - margin, px));
            py = Math.max(margin, Math.min(getHeight() - margin, py));
            if (Math.abs(nx) > Math.abs(ny)) lastDir = nx < 0 ? 2 : 3;
            else lastDir = ny < 0 ? 1 : 0;
        }
    }

    private void drawArena(Canvas c) {
        c.drawColor(Color.rgb(9, 11, 15));
        paint.setColor(Color.rgb(19, 22, 29));
        float tile = Math.max(48f, getHeight() / 10f);
        for (float y = 0; y < getHeight(); y += tile) {
            for (float x = 0; x < getWidth(); x += tile) {
                if ((((int)(x/tile)) + ((int)(y/tile))) % 2 == 0) c.drawRect(x, y, x+tile, y+tile, paint);
            }
        }
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        paint.setColor(Color.rgb(77, 27, 35));
        c.drawRect(getWidth()*0.18f, getHeight()*0.12f, getWidth()*0.82f, getHeight()*0.84f, paint);
        paint.setStyle(Paint.Style.FILL);

        uiPaint.setTextSize(getHeight()*0.035f);
        uiPaint.setColor(Color.argb(180, 220,220,225));
        c.drawText("VEILBREAKERS  •  Prototype v0.1", getWidth()*0.03f, getHeight()*0.07f, uiPaint);
    }

    private void drawPlayer(Canvas c) {
        Rect src;
        Bitmap sheet;
        if (attacking) {
            sheet = attackSheet;
            int f = Math.min(attack[lastDir].length - 1, (int)(attackTime / 0.42f * attack[lastDir].length));
            src = attack[lastDir][f];
        } else {
            float moving = (float)Math.hypot(joyX, joyY);
            if (moving > 0.12f) {
                int f = ((int)(animTime * 11f)) % run[lastDir].length;
                src = run[lastDir][f];
            } else {
                int f = ((int)(animTime * 5f)) % idle[lastDir].length;
                src = idle[lastDir][f];
            }
            sheet = moveSheet;
        }
        float baseH = getHeight() * (attacking ? 0.30f : 0.27f);
        float ratio = src.width() / (float)Math.max(1, src.height());
        float baseW = baseH * ratio;
        RectF dst = new RectF(px - baseW/2f, py - baseH*0.70f, px + baseW/2f, py + baseH*0.30f);
        c.drawBitmap(sheet, src, dst, pixelPaint);
    }

    private float joyCx() { return getWidth()*0.13f; }
    private float joyCy() { return getHeight()*0.78f; }
    private float joyR() { return getHeight()*0.14f; }
    private float atkCx() { return getWidth()*0.86f; }
    private float atkCy() { return getHeight()*0.77f; }
    private float atkR() { return getHeight()*0.105f; }

    private void drawControls(Canvas c) {
        float jcX=joyCx(), jcY=joyCy(), jr=joyR();
        uiPaint.setColor(Color.argb(75, 255,255,255));
        c.drawCircle(jcX,jcY,jr,uiPaint);
        uiPaint.setColor(Color.argb(120, 180,55,68));
        c.drawCircle(jcX + joyX*jr*0.55f, jcY + joyY*jr*0.55f, jr*0.43f, uiPaint);

        uiPaint.setColor(Color.argb(attacking ? 190 : 130, 188,45,60));
        c.drawCircle(atkCx(),atkCy(),atkR(),uiPaint);
        uiPaint.setColor(Color.WHITE);
        uiPaint.setTextAlign(Paint.Align.CENTER);
        uiPaint.setTextSize(getHeight()*0.033f);
        c.drawText("ATTACK", atkCx(), atkCy()+getHeight()*0.012f, uiPaint);
        uiPaint.setTextAlign(Paint.Align.LEFT);
    }

    @Override public boolean onTouchEvent(MotionEvent e) {
        final int action = e.getActionMasked();
        final int idx = e.getActionIndex();
        final int pid = e.getPointerId(idx);

        if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
            float x=e.getX(idx), y=e.getY(idx);
            if (dist(x,y,joyCx(),joyCy()) <= joyR()*1.35f && joyPointer < 0) {
                joyPointer = pid; updateJoy(x,y); return true;
            }
            if (dist(x,y,atkCx(),atkCy()) <= atkR()*1.4f && attackPointer < 0) {
                attackPointer = pid;
                if (!attacking) { attacking = true; attackTime = 0f; animTime = 0f; }
                return true;
            }
        }
        if (action == MotionEvent.ACTION_MOVE) {
            for (int i=0;i<e.getPointerCount();i++) {
                int id=e.getPointerId(i);
                if (id==joyPointer) updateJoy(e.getX(i),e.getY(i));
            }
            return true;
        }
        if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_POINTER_UP || action == MotionEvent.ACTION_CANCEL) {
            if (pid==joyPointer || action==MotionEvent.ACTION_CANCEL) { joyPointer=-1; joyX=joyY=0f; }
            if (pid==attackPointer || action==MotionEvent.ACTION_CANCEL) attackPointer=-1;
            return true;
        }
        return true;
    }

    private void updateJoy(float x, float y) {
        float dx=(x-joyCx())/joyR(), dy=(y-joyCy())/joyR();
        float len=(float)Math.hypot(dx,dy);
        if (len>1f) { dx/=len; dy/=len; }
        joyX=dx; joyY=dy;
    }

    private float dist(float x1,float y1,float x2,float y2) {
        return (float)Math.hypot(x1-x2,y1-y2);
    }
}