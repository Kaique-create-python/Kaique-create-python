package com.veilbreakers.prototype;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.view.MotionEvent;
import android.view.View;

import java.io.IOException;
import java.io.InputStream;

public class GameView extends View {
    private static final int DOWN = 0;
    private static final int UP = 1;
    private static final int LEFT = 2;
    private static final int RIGHT = 3;

    private final Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint uiPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pixelPaint = new Paint();
    private final Paint shadowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private final Bitmap[][] idle = new Bitmap[4][];
    private final Bitmap[][] run = new Bitmap[4][];
    private final Bitmap[][] attack = new Bitmap[4][];

    private float px = -1f;
    private float py = -1f;
    private float vx = 0f;
    private float vy = 0f;

    private float joyX = 0f;
    private float joyY = 0f;
    private int joyPointer = -1;
    private int attackPointer = -1;

    private int facing = DOWN;
    private int attackFacing = DOWN;
    private float idleClock = 0f;
    private float runClock = 0f;
    private boolean attacking = false;
    private float attackClock = 0f;
    private long lastNs = System.nanoTime();

    private final float[] attackDurations = {0.075f, 0.060f, 0.055f, 0.060f, 0.075f, 0.100f};

    public GameView(Context context) {
        super(context);
        setFocusable(true);
        setKeepScreenOn(true);

        pixelPaint.setAntiAlias(false);
        pixelPaint.setFilterBitmap(false);
        pixelPaint.setDither(false);

        uiPaint.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        shadowPaint.setColor(Color.argb(105, 0, 0, 0));

        loadFrames(context);
    }

    private Bitmap load(Context c, String path) {
        try (InputStream in = c.getAssets().open(path)) {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inScaled = false;
            Bitmap b = BitmapFactory.decodeStream(in, null, options);
            if (b == null) throw new IOException("Could not decode " + path);
            return b;
        } catch (IOException e) {
            throw new RuntimeException("Missing sprite asset: " + path, e);
        }
    }

    private Bitmap[] loadSequence(Context c, String prefix, int count) {
        Bitmap[] frames = new Bitmap[count];
        for (int i = 0; i < count; i++) frames[i] = load(c, prefix + i + ".png");
        return frames;
    }

    private void loadFrames(Context c) {
        // The new sprites are already separated into individual PNG frames.
        // No runtime sheet slicing = no neighboring-frame red pixel bleed.
        idle[DOWN] = loadSequence(c, "kael/move/move_r0_f", 4);
        idle[UP] = loadSequence(c, "kael/move/move_r1_f", 4);
        idle[LEFT] = loadSequence(c, "kael/move/move_r2_f", 4);
        idle[RIGHT] = loadSequence(c, "kael/move/move_r3_f", 4);

        run[DOWN] = loadSequence(c, "kael/move/move_r4_f", 6);
        run[UP] = loadSequence(c, "kael/move/move_r5_f", 6);
        run[LEFT] = loadSequence(c, "kael/move/move_r6_f", 6);
        run[RIGHT] = loadSequence(c, "kael/move/move_r7_f", 6);

        attack[DOWN] = loadSequence(c, "kael/attack/attack_down_", 6);
        attack[UP] = loadSequence(c, "kael/attack/attack_up_", 6);
        attack[LEFT] = loadSequence(c, "kael/attack/attack_left_", 6);
        attack[RIGHT] = loadSequence(c, "kael/attack/attack_right_", 6);
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        if (px < 0f) {
            px = w * 0.50f;
            py = h * 0.52f;
        }
    }

    @Override
    protected void onDraw(Canvas c) {
        super.onDraw(c);

        long now = System.nanoTime();
        float dt = Math.min(0.032f, (now - lastNs) / 1_000_000_000f);
        lastNs = now;

        update(dt);
        drawArena(c);
        drawPlayer(c);
        drawControls(c);

        postInvalidateOnAnimation();
    }

    private void update(float dt) {
        float inputLen = (float) Math.hypot(joyX, joyY);
        float ix = 0f;
        float iy = 0f;
        if (inputLen > 0.14f) {
            ix = joyX / Math.max(1f, inputLen);
            iy = joyY / Math.max(1f, inputLen);
        }

        float maxSpeed = getHeight() * 0.39f;
        float targetVx = ix * maxSpeed;
        float targetVy = iy * maxSpeed;

        if (attacking) {
            attackClock += dt;

            // Keep a little inertia during the slash, but quickly settle so the attack feels planted.
            float attackDrag = 1f - (float) Math.exp(-9.5f * dt);
            vx += (0f - vx) * attackDrag;
            vy += (0f - vy) * attackDrag;
            px += vx * dt * 0.45f;
            py += vy * dt * 0.45f;

            float total = 0f;
            for (float d : attackDurations) total += d;
            if (attackClock >= total) {
                attacking = false;
                attackClock = 0f;
            }
        } else {
            // Exponential smoothing gives responsive acceleration without robotic instant starts/stops.
            float response = inputLen > 0.14f ? 13.5f : 9.5f;
            float blend = 1f - (float) Math.exp(-response * dt);
            vx += (targetVx - vx) * blend;
            vy += (targetVy - vy) * blend;

            px += vx * dt;
            py += vy * dt;

            float speedRatio = Math.min(1f, (float) Math.hypot(vx, vy) / Math.max(1f, maxSpeed));
            if (speedRatio > 0.08f) {
                updateFacingWithHysteresis(vx, vy);
                // Animation speed follows actual character speed instead of joystick position.
                runClock += dt * (5.6f + 5.0f * speedRatio);
            } else {
                idleClock += dt * 3.1f;
            }
        }

        float xMargin = getHeight() * 0.10f;
        float yTop = getHeight() * 0.14f;
        float yBottom = getHeight() * 0.88f;
        px = clamp(px, xMargin, getWidth() - xMargin);
        py = clamp(py, yTop, yBottom);
    }

    private void updateFacingWithHysteresis(float dx, float dy) {
        float ax = Math.abs(dx);
        float ay = Math.abs(dy);
        if (ax + ay < 0.001f) return;

        // Prevent direction flicker around diagonal input.
        if (facing == LEFT || facing == RIGHT) {
            if (ay > ax * 1.28f) facing = dy < 0f ? UP : DOWN;
            else if (ax > ay * 0.82f) facing = dx < 0f ? LEFT : RIGHT;
        } else {
            if (ax > ay * 1.28f) facing = dx < 0f ? LEFT : RIGHT;
            else if (ay > ax * 0.82f) facing = dy < 0f ? UP : DOWN;
        }
    }

    private void startAttack() {
        if (attacking) return;
        attacking = true;
        attackClock = 0f;
        attackFacing = facing;
    }

    private int currentAttackFrame() {
        float t = attackClock;
        float acc = 0f;
        for (int i = 0; i < attackDurations.length; i++) {
            acc += attackDurations[i];
            if (t < acc) return i;
        }
        return attackDurations.length - 1;
    }

    private void drawArena(Canvas c) {
        c.drawColor(Color.rgb(8, 10, 14));

        float tile = Math.max(48f, getHeight() / 10f);
        for (float y = 0; y < getHeight(); y += tile) {
            for (float x = 0; x < getWidth(); x += tile) {
                boolean alt = (((int) (x / tile)) + ((int) (y / tile))) % 2 == 0;
                bgPaint.setColor(alt ? Color.rgb(18, 21, 28) : Color.rgb(11, 14, 19));
                c.drawRect(x, y, x + tile, y + tile, bgPaint);
            }
        }

        bgPaint.setStyle(Paint.Style.STROKE);
        bgPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.0035f));
        bgPaint.setColor(Color.rgb(72, 26, 34));
        c.drawRect(getWidth() * 0.18f, getHeight() * 0.12f,
                getWidth() * 0.82f, getHeight() * 0.86f, bgPaint);
        bgPaint.setStyle(Paint.Style.FILL);

        uiPaint.setColor(Color.argb(180, 220, 220, 225));
        uiPaint.setTextSize(getHeight() * 0.032f);
        c.drawText("VEILBREAKERS  •  Prototype v0.3", getWidth() * 0.025f, getHeight() * 0.060f, uiPaint);
    }

    private void drawPlayer(Canvas c) {
        Bitmap frame;
        int bottomPad;

        if (attacking) {
            frame = attack[attackFacing][currentAttackFrame()];
            bottomPad = 12;
        } else {
            float maxSpeed = getHeight() * 0.39f;
            float speedRatio = Math.min(1f, (float) Math.hypot(vx, vy) / Math.max(1f, maxSpeed));
            if (speedRatio > 0.10f) {
                int idx = ((int) Math.floor(runClock)) % run[facing].length;
                frame = run[facing][idx];
            } else {
                int idx = ((int) Math.floor(idleClock)) % idle[facing].length;
                frame = idle[facing][idx];
            }
            bottomPad = 8;
        }

        float scale = (getHeight() / 720f) * 0.92f;
        float w = frame.getWidth() * scale;
        float h = frame.getHeight() * scale;

        float left = px - w * 0.5f;
        float top = py - (frame.getHeight() - bottomPad) * scale;
        RectF dst = new RectF(left, top, left + w, top + h);

        float shadowW = getHeight() * 0.085f;
        float shadowH = getHeight() * 0.020f;
        c.drawOval(new RectF(px - shadowW, py - shadowH * 0.3f,
                px + shadowW, py + shadowH), shadowPaint);

        c.drawBitmap(frame, null, dst, pixelPaint);
    }

    private float joyCx() { return getWidth() * 0.13f; }
    private float joyCy() { return getHeight() * 0.79f; }
    private float joyR() { return getHeight() * 0.14f; }
    private float atkCx() { return getWidth() * 0.865f; }
    private float atkCy() { return getHeight() * 0.78f; }
    private float atkR() { return getHeight() * 0.105f; }

    private void drawControls(Canvas c) {
        float jx = joyCx();
        float jy = joyCy();
        float jr = joyR();

        uiPaint.setColor(Color.argb(72, 255, 255, 255));
        c.drawCircle(jx, jy, jr, uiPaint);
        uiPaint.setStyle(Paint.Style.STROKE);
        uiPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.003f));
        uiPaint.setColor(Color.argb(95, 255, 255, 255));
        c.drawCircle(jx, jy, jr, uiPaint);
        uiPaint.setStyle(Paint.Style.FILL);

        uiPaint.setColor(Color.argb(150, 176, 52, 67));
        c.drawCircle(jx + joyX * jr * 0.55f,
                jy + joyY * jr * 0.55f,
                jr * 0.42f, uiPaint);

        uiPaint.setColor(Color.argb(attacking ? 205 : 145, 190, 42, 58));
        c.drawCircle(atkCx(), atkCy(), atkR(), uiPaint);
        uiPaint.setStyle(Paint.Style.STROKE);
        uiPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.003f));
        uiPaint.setColor(Color.argb(155, 255, 190, 195));
        c.drawCircle(atkCx(), atkCy(), atkR(), uiPaint);
        uiPaint.setStyle(Paint.Style.FILL);

        uiPaint.setTextAlign(Paint.Align.CENTER);
        uiPaint.setColor(Color.WHITE);
        uiPaint.setTextSize(getHeight() * 0.030f);
        c.drawText("ATTACK", atkCx(), atkCy() + getHeight() * 0.010f, uiPaint);
        uiPaint.setTextAlign(Paint.Align.LEFT);
    }

    @Override
    public boolean onTouchEvent(MotionEvent e) {
        int action = e.getActionMasked();
        int actionIndex = e.getActionIndex();
        int pointerId = e.getPointerId(actionIndex);

        if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
            float x = e.getX(actionIndex);
            float y = e.getY(actionIndex);

            if (joyPointer < 0 && distance(x, y, joyCx(), joyCy()) <= joyR() * 1.40f) {
                joyPointer = pointerId;
                updateJoystick(x, y);
                return true;
            }

            if (attackPointer < 0 && distance(x, y, atkCx(), atkCy()) <= atkR() * 1.50f) {
                attackPointer = pointerId;
                startAttack();
                return true;
            }
        }

        if (action == MotionEvent.ACTION_MOVE) {
            for (int i = 0; i < e.getPointerCount(); i++) {
                if (e.getPointerId(i) == joyPointer) updateJoystick(e.getX(i), e.getY(i));
            }
            return true;
        }

        if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_POINTER_UP || action == MotionEvent.ACTION_CANCEL) {
            if (pointerId == joyPointer || action == MotionEvent.ACTION_CANCEL) {
                joyPointer = -1;
                joyX = 0f;
                joyY = 0f;
            }
            if (pointerId == attackPointer || action == MotionEvent.ACTION_CANCEL) {
                attackPointer = -1;
            }
            return true;
        }

        return true;
    }

    private void updateJoystick(float x, float y) {
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

    private float distance(float x1, float y1, float x2, float y2) {
        return (float) Math.hypot(x1 - x2, y1 - y2);
    }

    private float clamp(float v, float min, float max) {
        return Math.max(min, Math.min(max, v));
    }
}