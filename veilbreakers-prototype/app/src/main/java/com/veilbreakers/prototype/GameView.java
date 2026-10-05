package com.veilbreakers.prototype;

import android.content.Context;
import android.graphics.*;
import android.view.MotionEvent;
import android.view.View;

import java.io.IOException;
import java.io.InputStream;

public class GameView extends View {
    private final Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pixelPaint = new Paint();
    private final Paint uiPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private Bitmap moveSheet;
    private Bitmap attackSheet;
    @SuppressWarnings("unused") private Bitmap magicSheet;

    private float px = -1f, py = -1f;
    private float joyX = 0f, joyY = 0f;
    private float vx = 0f, vy = 0f;
    private int joyPointer = -1;
    private int attackPointer = -1;

    // 0 down, 1 up, 2 left, 3 right
    private int lastDir = 3;
    private int attackDir = 3;

    private long lastNs = System.nanoTime();
    private float animClock = 0f;
    private boolean wasMoving = false;

    private boolean attacking = false;
    private float attackTime = 0f;

    private static final float JOY_DEADZONE = 0.16f;
    private static final float DIR_HYSTERESIS = 1.18f;
    private static final float ATTACK_TOTAL = 0.38f;

    // Prepared-frame canvases. Content is normalized inside these canvases.
    private static final int MOVE_CANVAS_W = 150;
    private static final int MOVE_CANVAS_H = 150;
    private static final int MOVE_FOOT_PAD = 8;
    private static final int ATTACK_CANVAS_W = 220;
    private static final int ATTACK_CANVAS_H = 160;
    private static final int ATTACK_FOOT_PAD = 7;

    private final Rect[][] idleRects = new Rect[4][];
    private final Rect[][] runRects = new Rect[4][];
    private final Rect[][] attackRects = new Rect[4][];

    private final Bitmap[][] idleFrames = new Bitmap[4][];
    private final Bitmap[][] runFrames = new Bitmap[4][];
    private final Bitmap[][] attackFrames = new Bitmap[4][];

    // Do not ping-pong run frames; generated frames already represent one forward cycle.
    private final int[] idleSeq = {0, 1, 2, 3, 2, 1};
    private final int[] runSeq = {0, 1, 2, 3, 4, 5};

    public GameView(Context context) {
        super(context);
        setFocusable(true);
        pixelPaint.setAntiAlias(false);
        pixelPaint.setFilterBitmap(false);
        uiPaint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        loadAssets(context);
        setupRects();
        buildPreparedFrames();
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

    private Rect r(int l, int t, int rr, int b) {
        return new Rect(l, t, rr, b);
    }

    private void setupRects() {
        idleRects[0] = new Rect[]{r(16,7,88,107), r(94,7,158,107), r(165,7,228,107), r(238,7,308,107)};
        idleRects[1] = new Rect[]{r(413,7,483,107), r(492,7,557,107), r(565,7,626,107), r(640,7,704,107)};
        idleRects[2] = new Rect[]{r(30,115,94,212), r(109,115,170,212), r(184,115,251,212), r(259,115,321,212)};
        idleRects[3] = new Rect[]{r(396,115,462,212), r(472,115,541,212), r(551,115,616,212), r(630,115,693,212)};

        runRects[0] = new Rect[]{r(5,219,63,307), r(64,219,118,307), r(122,219,180,307), r(181,219,235,307), r(238,219,294,307), r(297,219,356,307)};
        runRects[1] = new Rect[]{r(369,219,428,307), r(429,219,484,307), r(491,219,544,307), r(549,219,603,307), r(608,219,661,307), r(664,219,720,307)};
        runRects[2] = new Rect[]{r(0,311,66,395), r(66,311,126,395), r(126,311,186,395), r(186,311,246,395), r(246,311,302,395), r(302,311,362,395)};
        runRects[3] = new Rect[]{r(362,311,442,395), r(442,311,494,395), r(494,311,549,395), r(549,311,607,395), r(607,311,668,395), r(668,311,724,395)};

        attackRects[0] = new Rect[]{r(7,5,62,63), r(83,5,141,63), r(149,5,228,63), r(229,5,317,63), r(318,5,414,63)};
        attackRects[1] = new Rect[]{r(11,66,61,127), r(74,66,150,127), r(153,66,219,127), r(226,66,316,127), r(321,66,410,127)};
        attackRects[2] = new Rect[]{r(5,131,62,191), r(76,131,151,191), r(151,131,224,191), r(225,131,317,191), r(319,131,418,191)};
        attackRects[3] = new Rect[]{r(8,193,66,256), r(68,193,151,256), r(153,193,228,256), r(230,193,318,256), r(320,193,414,256)};
    }

    private void buildPreparedFrames() {
        // Front/back are good enough independently. For side views, mirror LEFT to RIGHT:
        // it eliminates the inconsistent generated right-facing run/attack poses seen in the video.
        idleFrames[0] = prepareFrames(moveSheet, idleRects[0], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 98, false);
        idleFrames[1] = prepareFrames(moveSheet, idleRects[1], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 98, false);
        idleFrames[2] = prepareFrames(moveSheet, idleRects[2], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 96, false);
        idleFrames[3] = prepareFrames(moveSheet, idleRects[2], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 96, true);

        runFrames[0] = prepareFrames(moveSheet, runRects[0], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 93, false);
        runFrames[1] = prepareFrames(moveSheet, runRects[1], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 93, false);
        runFrames[2] = prepareFrames(moveSheet, runRects[2], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 92, false);
        runFrames[3] = prepareFrames(moveSheet, runRects[2], MOVE_CANVAS_W, MOVE_CANVAS_H, MOVE_FOOT_PAD, 92, true);

        // Attack sprites were generated much smaller than movement sprites. Normalize them up
        // before drawing, so pressing ATTACK no longer makes Kael suddenly shrink.
        attackFrames[0] = prepareFrames(attackSheet, attackRects[0], ATTACK_CANVAS_W, ATTACK_CANVAS_H, ATTACK_FOOT_PAD, 96, false);
        attackFrames[1] = prepareFrames(attackSheet, attackRects[1], ATTACK_CANVAS_W, ATTACK_CANVAS_H, ATTACK_FOOT_PAD, 96, false);
        attackFrames[2] = prepareFrames(attackSheet, attackRects[2], ATTACK_CANVAS_W, ATTACK_CANVAS_H, ATTACK_FOOT_PAD, 96, false);
        attackFrames[3] = prepareFrames(attackSheet, attackRects[2], ATTACK_CANVAS_W, ATTACK_CANVAS_H, ATTACK_FOOT_PAD, 96, true);
    }

    private Bitmap[] prepareFrames(Bitmap sheet, Rect[] rects, int canvasW, int canvasH,
                                   int bottomPad, int targetContentHeight, boolean mirror) {
        Bitmap[] out = new Bitmap[rects.length];
        for (int i = 0; i < rects.length; i++) {
            out[i] = prepareFrame(sheet, rects[i], canvasW, canvasH, bottomPad, targetContentHeight, mirror);
        }
        return out;
    }

    private Bitmap prepareFrame(Bitmap sheet, Rect src, int canvasW, int canvasH,
                                int bottomPad, int targetContentHeight, boolean mirror) {
        Bitmap crop = Bitmap.createBitmap(sheet, src.left, src.top, src.width(), src.height());
        crop = trimAlpha(crop);

        float scale = targetContentHeight / (float) Math.max(1, crop.getHeight());
        int targetW = Math.max(1, Math.round(crop.getWidth() * scale));
        int targetH = Math.max(1, Math.round(crop.getHeight() * scale));
        crop = Bitmap.createScaledBitmap(crop, targetW, targetH, false);

        if (mirror) crop = mirrorBitmap(crop);

        // Safety: keep extreme attack VFX inside the fixed canvas without changing body scale too much.
        if (crop.getWidth() > canvasW - 4) {
            float fit = (canvasW - 4) / (float) crop.getWidth();
            int w = Math.max(1, Math.round(crop.getWidth() * fit));
            int h = Math.max(1, Math.round(crop.getHeight() * fit));
            crop = Bitmap.createScaledBitmap(crop, w, h, false);
        }

        Bitmap out = Bitmap.createBitmap(canvasW, canvasH, Bitmap.Config.ARGB_8888);
        Canvas cc = new Canvas(out);
        Paint p = new Paint();
        p.setAntiAlias(false);
        p.setFilterBitmap(false);

        int x = (canvasW - crop.getWidth()) / 2;
        int y = canvasH - crop.getHeight() - bottomPad;
        cc.drawBitmap(crop, x, y, p);
        return out;
    }

    private Bitmap trimAlpha(Bitmap src) {
        int w = src.getWidth();
        int h = src.getHeight();
        int[] pixels = new int[w * h];
        src.getPixels(pixels, 0, w, 0, 0, w, h);

        int minX = w, minY = h, maxX = -1, maxY = -1;
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int a = (pixels[y * w + x] >>> 24) & 0xFF;
                if (a > 8) {
                    minX = Math.min(minX, x);
                    minY = Math.min(minY, y);
                    maxX = Math.max(maxX, x);
                    maxY = Math.max(maxY, y);
                }
            }
        }

        if (maxX < minX || maxY < minY) return src;
        return Bitmap.createBitmap(src, minX, minY, maxX - minX + 1, maxY - minY + 1);
    }

    private Bitmap mirrorBitmap(Bitmap src) {
        Matrix m = new Matrix();
        m.preScale(-1f, 1f);
        return Bitmap.createBitmap(src, 0, 0, src.getWidth(), src.getHeight(), m, false);
    }

    @Override protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        if (px < 0f) {
            px = w * 0.5f;
            py = h * 0.47f;
        }
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
        float joyLen = (float) Math.hypot(joyX, joyY);
        float maxSpeed = getHeight() * 0.40f;

        float targetVx = 0f;
        float targetVy = 0f;
        if (!attacking && joyLen > JOY_DEADZONE) {
            float inputStrength = Math.min(1f, (joyLen - JOY_DEADZONE) / (1f - JOY_DEADZONE));
            float nx = joyX / joyLen;
            float ny = joyY / joyLen;
            targetVx = nx * maxSpeed * inputStrength;
            targetVy = ny * maxSpeed * inputStrength;
            updateFacing(nx, ny);
        }

        // Smooth acceleration/deceleration instead of instant start/stop.
        float accel = attacking ? getHeight() * 5.0f : getHeight() * 3.5f;
        vx = approach(vx, targetVx, accel * dt);
        vy = approach(vy, targetVy, accel * dt);

        float speed = (float) Math.hypot(vx, vy);
        boolean moving = speed > maxSpeed * 0.06f && !attacking;

        if (moving != wasMoving) {
            animClock = 0f;
            wasMoving = moving;
        }

        if (moving) {
            // Animation speed follows actual movement speed, not just joystick touch.
            float speed01 = Math.min(1f, speed / maxSpeed);
            animClock += dt * (0.72f + 0.55f * speed01);
        } else if (!attacking) {
            animClock += dt;
        }

        // Even during attack, leftover velocity decays naturally for a tiny bit of momentum.
        px += vx * dt;
        py += vy * dt;

        float margin = getHeight() * 0.12f;
        px = Math.max(margin, Math.min(getWidth() - margin, px));
        py = Math.max(margin, Math.min(getHeight() - margin, py));

        if (attacking) {
            attackTime += dt;
            if (attackTime >= ATTACK_TOTAL) {
                attacking = false;
                attackTime = 0f;
                animClock = 0f;
            }
        }
    }

    private void updateFacing(float nx, float ny) {
        float ax = Math.abs(nx);
        float ay = Math.abs(ny);

        // Hysteresis prevents rapid left/up/right/down flicker near diagonals.
        if (ax > ay * DIR_HYSTERESIS) {
            lastDir = nx < 0f ? 2 : 3;
        } else if (ay > ax * DIR_HYSTERESIS) {
            lastDir = ny < 0f ? 1 : 0;
        }
        // If neither axis clearly dominates, keep the previous facing.
    }

    private float approach(float current, float target, float delta) {
        if (current < target) return Math.min(current + delta, target);
        if (current > target) return Math.max(current - delta, target);
        return target;
    }

    private void drawArena(Canvas c) {
        c.drawColor(Color.rgb(9, 11, 15));
        bgPaint.setColor(Color.rgb(19, 22, 29));
        float tile = Math.max(48f, getHeight() / 10f);

        for (float y = 0; y < getHeight(); y += tile) {
            for (float x = 0; x < getWidth(); x += tile) {
                if ((((int) (x / tile)) + ((int) (y / tile))) % 2 == 0) {
                    c.drawRect(x, y, x + tile, y + tile, bgPaint);
                }
            }
        }

        bgPaint.setStyle(Paint.Style.STROKE);
        bgPaint.setStrokeWidth(3f);
        bgPaint.setColor(Color.rgb(77, 27, 35));
        c.drawRect(getWidth() * 0.18f, getHeight() * 0.12f,
                getWidth() * 0.82f, getHeight() * 0.84f, bgPaint);
        bgPaint.setStyle(Paint.Style.FILL);

        uiPaint.setTextSize(getHeight() * 0.035f);
        uiPaint.setColor(Color.argb(180, 220, 220, 225));
        c.drawText("VEILBREAKERS  •  Prototype v0.2", getWidth() * 0.03f, getHeight() * 0.07f, uiPaint);
    }

    private void drawPlayer(Canvas c) {
        Bitmap frame;
        int footPad;

        if (attacking) {
            frame = attackFrames[attackDir][attackFrameForTime(attackTime)];
            footPad = ATTACK_FOOT_PAD;
        } else {
            float maxSpeed = getHeight() * 0.40f;
            float speed = (float) Math.hypot(vx, vy);
            boolean moving = speed > maxSpeed * 0.06f;

            if (moving) {
                int frameIndex = ((int) (animClock * 8.2f)) % runSeq.length;
                frame = runFrames[lastDir][runSeq[frameIndex]];
            } else {
                int frameIndex = ((int) (animClock * 3.0f)) % idleSeq.length;
                frame = idleFrames[lastDir][idleSeq[frameIndex]];
            }
            footPad = MOVE_FOOT_PAD;
        }

        // One common world scale. Preserve bitmap aspect ratio; never stretch it into a square.
        float worldScale = (getHeight() * 0.285f) / MOVE_CANVAS_H;
        float drawW = frame.getWidth() * worldScale;
        float drawH = frame.getHeight() * worldScale;

        float left = px - drawW * 0.5f;
        float top = py - (frame.getHeight() - footPad) * worldScale;
        RectF dst = new RectF(left, top, left + drawW, top + drawH);
        c.drawBitmap(frame, null, dst, pixelPaint);
    }

    private int attackFrameForTime(float t) {
        // Non-uniform timing: readable startup -> fast slash -> brief follow-through.
        float n = t / ATTACK_TOTAL;
        if (n < 0.18f) return 0;
        if (n < 0.34f) return 1;
        if (n < 0.52f) return 2;
        if (n < 0.76f) return 3;
        return 4;
    }

    private void startAttack() {
        if (attacking) return;
        attacking = true;
        attackTime = 0f;
        attackDir = lastDir; // lock facing for the whole swing
    }

    private float joyCx() { return getWidth() * 0.13f; }
    private float joyCy() { return getHeight() * 0.78f; }
    private float joyR() { return getHeight() * 0.14f; }
    private float atkCx() { return getWidth() * 0.86f; }
    private float atkCy() { return getHeight() * 0.77f; }
    private float atkR() { return getHeight() * 0.105f; }

    private void drawControls(Canvas c) {
        float jcX = joyCx(), jcY = joyCy(), jr = joyR();
        uiPaint.setColor(Color.argb(75, 255, 255, 255));
        c.drawCircle(jcX, jcY, jr, uiPaint);
        uiPaint.setColor(Color.argb(120, 180, 55, 68));
        c.drawCircle(jcX + joyX * jr * 0.55f, jcY + joyY * jr * 0.55f,
                jr * 0.43f, uiPaint);

        uiPaint.setColor(Color.argb(attacking ? 190 : 130, 188, 45, 60));
        c.drawCircle(atkCx(), atkCy(), atkR(), uiPaint);
        uiPaint.setColor(Color.WHITE);
        uiPaint.setTextAlign(Paint.Align.CENTER);
        uiPaint.setTextSize(getHeight() * 0.033f);
        c.drawText("ATTACK", atkCx(), atkCy() + getHeight() * 0.012f, uiPaint);
        uiPaint.setTextAlign(Paint.Align.LEFT);
    }

    @Override public boolean onTouchEvent(MotionEvent e) {
        final int action = e.getActionMasked();
        final int idx = e.getActionIndex();
        final int pid = e.getPointerId(idx);

        if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
            float x = e.getX(idx), y = e.getY(idx);

            if (dist(x, y, joyCx(), joyCy()) <= joyR() * 1.35f && joyPointer < 0) {
                joyPointer = pid;
                updateJoy(x, y);
                return true;
            }

            if (dist(x, y, atkCx(), atkCy()) <= atkR() * 1.4f && attackPointer < 0) {
                attackPointer = pid;
                startAttack();
                return true;
            }
        }

        if (action == MotionEvent.ACTION_MOVE) {
            for (int i = 0; i < e.getPointerCount(); i++) {
                int id = e.getPointerId(i);
                if (id == joyPointer) updateJoy(e.getX(i), e.getY(i));
            }
            return true;
        }

        if (action == MotionEvent.ACTION_UP ||
                action == MotionEvent.ACTION_POINTER_UP ||
                action == MotionEvent.ACTION_CANCEL) {

            if (pid == joyPointer || action == MotionEvent.ACTION_CANCEL) {
                joyPointer = -1;
                joyX = 0f;
                joyY = 0f;
            }
            if (pid == attackPointer || action == MotionEvent.ACTION_CANCEL) {
                attackPointer = -1;
            }
            return true;
        }

        return true;
    }

    private void updateJoy(float x, float y) {
        float dx = (x - joyCx()) / joyR();
        float dy = (y - joyCy()) / joyR();
        float len = (float) Math.hypot(dx, dy);
        if (len > 1f) {
            dx /= len;
            dy /= len;
        }
        joyX = dx;
        joyY = dy;
    }

    private float dist(float x1, float y1, float x2, float y2) {
        return (float) Math.hypot(x1 - x2, y1 - y2);
    }
}