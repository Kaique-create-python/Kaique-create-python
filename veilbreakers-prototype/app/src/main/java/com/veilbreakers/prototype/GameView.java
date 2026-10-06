package com.veilbreakers.prototype;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.view.HapticFeedbackConstants;
import android.view.MotionEvent;
import android.view.View;

import java.io.IOException;
import java.io.InputStream;
import java.util.Locale;

public class GameView extends View {
    private static final int DOWN = 0;
    private static final int UP = 1;
    private static final int LEFT = 2;
    private static final int RIGHT = 3;

    private final Paint bgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint uiPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint pixelPaint = new Paint();
    private final Paint imagePaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Paint shadowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint overlayPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private final Bitmap[][] idle = new Bitmap[4][];
    private final Bitmap[][] run = new Bitmap[4][];
    private final Bitmap[][] attack = new Bitmap[4][];

    // HUD / status assets
    private Bitmap hudHpFrame, hudHpFill, hudManaFrame, hudManaFill, hudXpFrame, hudXpFill;
    private Bitmap hudLevel, hudMoney, hudStats, hudMenuToggle;
    private Bitmap statusFrame, statusHeader, statusPortraitFrame, statusDescFrame;
    private Bitmap statusHpRow, statusManaRow, statusLevelRow, statusXpRow, statusAttrBlock;
    private Bitmap statusAttrPoints, statusMoney, statusUpgrade, statusPlus, statusMinus;
    private Bitmap levelHeader, levelReward;

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
    private final SharedPreferences prefs;
    private final boolean loadExisting;
    private final PlayerStats stats = new PlayerStats();

    // Status menu state
    private boolean statusOpen = false;
    private float statusAnim = 0f;
    private final int[] pending = {0, 0, 0, 0}; // ATK DEF CRIT SPD
    private int pendingPoints = 0;
    private final RectF[] minusHits = {new RectF(), new RectF(), new RectF(), new RectF()};
    private final RectF[] plusHits = {new RectF(), new RectF(), new RectF(), new RectF()};
    private final RectF upgradeHit = new RectF();
    private final RectF closeStatusHit = new RectF();
    private final RectF menuHit = new RectF();

    // Future level-up popup support.
    private float levelUpFlash = 0f;

    public GameView(Context context) {
        this(context, false);
    }

    public GameView(Context context, boolean loadExisting) {
        super(context);
        this.loadExisting = loadExisting;
        this.prefs = context.getSharedPreferences("veilbreakers_save", Context.MODE_PRIVATE);
        setFocusable(true);
        setKeepScreenOn(true);

        pixelPaint.setAntiAlias(false);
        pixelPaint.setFilterBitmap(false);
        pixelPaint.setDither(false);
        uiPaint.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        shadowPaint.setColor(Color.argb(105, 0, 0, 0));

        loadFrames(context);
        loadUiAssets(context);
        if (loadExisting && prefs.getBoolean("has_save", false)) stats.load(prefs);
        else stats.resetDefaults();
        pendingPoints = stats.attributePoints;
    }

    private Bitmap load(Context c, String path) {
        try (InputStream in = c.getAssets().open(path)) {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inScaled = false;
            Bitmap b = BitmapFactory.decodeStream(in, null, options);
            if (b == null) throw new IOException("Could not decode " + path);
            return b;
        } catch (IOException e) {
            throw new RuntimeException("Missing asset: " + path, e);
        }
    }

    private Bitmap[] loadSequence(Context c, String prefix, int count) {
        Bitmap[] frames = new Bitmap[count];
        for (int i = 0; i < count; i++) frames[i] = load(c, prefix + i + ".png");
        return frames;
    }

    private void loadFrames(Context c) {
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

    private void loadUiAssets(Context c) {
        hudHpFrame = load(c, "ui/hud_hp_frame.png");
        hudHpFill = load(c, "ui/hud_hp_fill.png");
        hudManaFrame = load(c, "ui/hud_mana_frame.png");
        hudManaFill = load(c, "ui/hud_mana_fill.png");
        hudXpFrame = load(c, "ui/hud_xp_frame.png");
        hudXpFill = load(c, "ui/hud_xp_fill.png");
        hudLevel = load(c, "ui/hud_level.png");
        hudMoney = load(c, "ui/hud_money.png");
        hudStats = load(c, "ui/hud_stats.png");
        hudMenuToggle = load(c, "ui/hud_menu_toggle.png");

        statusFrame = load(c, "ui/status_frame.png");
        statusHeader = load(c, "ui/status_header.png");
        statusPortraitFrame = load(c, "ui/status_portrait_frame.png");
        statusDescFrame = load(c, "ui/status_desc_frame.png");
        statusHpRow = load(c, "ui/status_hp_row.png");
        statusManaRow = load(c, "ui/status_mana_row.png");
        statusLevelRow = load(c, "ui/status_level_row.png");
        statusXpRow = load(c, "ui/status_xp_row.png");
        statusAttrBlock = load(c, "ui/status_attr_block.png");
        statusAttrPoints = load(c, "ui/status_attr_points.png");
        statusMoney = load(c, "ui/status_money.png");
        statusUpgrade = load(c, "ui/status_upgrade.png");
        statusPlus = load(c, "ui/status_plus.png");
        statusMinus = load(c, "ui/status_minus.png");
        levelHeader = load(c, "ui/level_header.png");
        levelReward = load(c, "ui/level_reward.png");
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        if (px < 0f) {
            if (loadExisting && prefs.contains("player_x_norm") && prefs.contains("player_y_norm")) {
                px = w * prefs.getFloat("player_x_norm", 0.50f);
                py = h * prefs.getFloat("player_y_norm", 0.52f);
                facing = prefs.getInt("player_facing", DOWN);
            } else {
                px = w * 0.50f;
                py = h * 0.52f;
            }
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
        drawHud(c);
        if (!statusOpen && statusAnim < 0.02f) drawControls(c);
        drawStatusOverlay(c);
        drawLevelUpFlash(c);

        postInvalidateOnAnimation();
    }

    private void update(float dt) {
        float targetStatus = statusOpen ? 1f : 0f;
        statusAnim += (targetStatus - statusAnim) * (1f - (float) Math.exp(-12f * dt));
        if (levelUpFlash > 0f) levelUpFlash = Math.max(0f, levelUpFlash - dt);

        if (statusOpen) {
            vx *= Math.max(0f, 1f - dt * 10f);
            vy *= Math.max(0f, 1f - dt * 10f);
            return;
        }

        float inputLen = (float) Math.hypot(joyX, joyY);
        float ix = 0f;
        float iy = 0f;
        if (inputLen > 0.14f) {
            ix = joyX / Math.max(1f, inputLen);
            iy = joyY / Math.max(1f, inputLen);
        }

        float maxSpeed = getHeight() * 0.39f * stats.moveMultiplier();
        float targetVx = ix * maxSpeed;
        float targetVy = iy * maxSpeed;

        if (attacking) {
            attackClock += dt;
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
            float response = inputLen > 0.14f ? 13.5f : 9.5f;
            float blend = 1f - (float) Math.exp(-response * dt);
            vx += (targetVx - vx) * blend;
            vy += (targetVy - vy) * blend;
            px += vx * dt;
            py += vy * dt;

            float speedRatio = Math.min(1f, (float) Math.hypot(vx, vy) / Math.max(1f, maxSpeed));
            if (speedRatio > 0.08f) {
                updateFacingWithHysteresis(vx, vy);
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
        float ax = Math.abs(dx), ay = Math.abs(dy);
        if (ax + ay < 0.001f) return;
        if (facing == LEFT || facing == RIGHT) {
            if (ay > ax * 1.28f) facing = dy < 0f ? UP : DOWN;
            else if (ax > ay * 0.82f) facing = dx < 0f ? LEFT : RIGHT;
        } else {
            if (ax > ay * 1.28f) facing = dx < 0f ? LEFT : RIGHT;
            else if (ay > ax * 0.82f) facing = dy < 0f ? UP : DOWN;
        }
    }

    private void startAttack() {
        if (attacking || statusOpen) return;
        attacking = true;
        attackClock = 0f;
        attackFacing = facing;
        if (prefs.getBoolean("vibration", true)) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
    }

    private int currentAttackFrame() {
        float t = attackClock, acc = 0f;
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
        c.drawRect(getWidth() * 0.18f, getHeight() * 0.12f, getWidth() * 0.82f, getHeight() * 0.86f, bgPaint);
        bgPaint.setStyle(Paint.Style.FILL);
    }

    private void drawPlayer(Canvas c) {
        Bitmap frame;
        int bottomPad;
        if (attacking) {
            frame = attack[attackFacing][currentAttackFrame()];
            bottomPad = 12;
        } else {
            float maxSpeed = getHeight() * 0.39f * stats.moveMultiplier();
            float speedRatio = Math.min(1f, (float) Math.hypot(vx, vy) / Math.max(1f, maxSpeed));
            if (speedRatio > 0.10f) frame = run[facing][((int) Math.floor(runClock)) % run[facing].length];
            else frame = idle[facing][((int) Math.floor(idleClock)) % idle[facing].length];
            bottomPad = 8;
        }

        float scale = (getHeight() / 720f) * 0.92f;
        float w = frame.getWidth() * scale;
        float h = frame.getHeight() * scale;
        RectF dst = new RectF(px - w * 0.5f, py - (frame.getHeight() - bottomPad) * scale,
                px - w * 0.5f + w, py - (frame.getHeight() - bottomPad) * scale + h);
        float shadowW = getHeight() * 0.085f;
        float shadowH = getHeight() * 0.020f;
        c.drawOval(new RectF(px - shadowW, py - shadowH * 0.3f, px + shadowW, py + shadowH), shadowPaint);
        c.drawBitmap(frame, null, dst, pixelPaint);
    }

    // ---------------- HUD ----------------
    private void drawHud(Canvas c) {
        float h = getHeight();
        float w = getWidth();

        // Keep the left stack compact and away from the screen edges.
        float left = w * 0.018f;
        float top = h * 0.018f;

        float hpW = w * 0.315f;
        float hpH = hpW * hudHpFrame.getHeight() / (float) hudHpFrame.getWidth();
        RectF hpRect = new RectF(left, top, left + hpW, top + hpH);
        drawHudMeter(c, hudHpFrame, hudHpFill, hpRect, stats.hpRatio(),
                0.298f, 0.465f, 0.895f, 0.735f);
        drawSmallValue(c, stats.hp + "/" + stats.maxHp,
                hpRect.left + hpRect.width() * 0.865f,
                hpRect.top + hpRect.height() * 0.57f,
                h * 0.020f, Paint.Align.RIGHT);

        float manaW = w * 0.292f;
        float manaH = manaW * hudManaFrame.getHeight() / (float) hudManaFrame.getWidth();
        float manaTop = hpRect.bottom - h * 0.014f;
        RectF manaRect = new RectF(left, manaTop, left + manaW, manaTop + manaH);
        drawHudMeter(c, hudManaFrame, hudManaFill, manaRect, stats.manaRatio(),
                0.302f, 0.445f, 0.900f, 0.735f);
        drawSmallValue(c, stats.mana + "/" + stats.maxMana,
                manaRect.left + manaRect.width() * 0.858f,
                manaRect.top + manaRect.height() * 0.58f,
                h * 0.019f, Paint.Align.RIGHT);

        float xpW = w * 0.255f;
        float xpH = xpW * hudXpFrame.getHeight() / (float) hudXpFrame.getWidth();
        float xpTop = manaRect.bottom - h * 0.006f;
        RectF xpRect = new RectF(left + w * 0.004f, xpTop,
                left + w * 0.004f + xpW, xpTop + xpH);
        drawHudMeter(c, hudXpFrame, hudXpFill, xpRect, stats.xpRatio(),
                0.238f, 0.365f, 0.895f, 0.685f);
        drawSmallValue(c, stats.xp + "/" + stats.xpToNext,
                xpRect.left + xpRect.width() * 0.86f,
                xpRect.top + xpRect.height() * 0.60f,
                h * 0.017f, Paint.Align.RIGHT);

        // Level badge is aligned to the XP row instead of floating between the bars.
        float lvSize = h * 0.112f;
        RectF lvRect = new RectF(
                xpRect.right + w * 0.004f,
                xpRect.centerY() - lvSize * 0.50f,
                xpRect.right + w * 0.004f + lvSize,
                xpRect.centerY() + lvSize * 0.50f);
        c.drawBitmap(hudLevel, null, lvRect, imagePaint);
        drawSmallValue(c, String.format(Locale.US, "%02d", stats.level),
                lvRect.centerX(), lvRect.centerY() + h * 0.017f,
                h * 0.032f, Paint.Align.CENTER);

        // Right cluster uses one vertical rhythm and does not touch the screen edge.
        float right = w - w * 0.018f;
        float moneyW = w * 0.145f;
        float moneyH = moneyW * hudMoney.getHeight() / (float) hudMoney.getWidth();
        RectF moneyRect = new RectF(right - moneyW, top, right, top + moneyH);
        c.drawBitmap(hudMoney, null, moneyRect, imagePaint);
        drawSmallValue(c, String.valueOf(stats.money),
                moneyRect.left + moneyRect.width() * 0.62f,
                moneyRect.centerY() + h * 0.004f,
                h * 0.026f, Paint.Align.CENTER);

        float statW = w * 0.225f;
        float statH = statW * hudStats.getHeight() / (float) hudStats.getWidth();
        RectF statRect = new RectF(right - statW,
                moneyRect.bottom + h * 0.008f,
                right,
                moneyRect.bottom + h * 0.008f + statH);
        c.drawBitmap(hudStats, null, statRect, imagePaint);

        float y = statRect.centerY() + h * 0.006f;
        float[] xs = {0.20f, 0.445f, 0.695f, 0.915f};
        String[] vals = {
                String.valueOf(stats.attack),
                String.valueOf(stats.defense),
                stats.crit + "%",
                String.valueOf(stats.speed)
        };
        for (int i = 0; i < 4; i++) {
            drawSmallValue(c, vals[i],
                    statRect.left + statRect.width() * xs[i],
                    y, h * 0.019f, Paint.Align.CENTER);
        }

        float menuSize = h * 0.082f;
        menuHit.set(right - menuSize,
                statRect.bottom + h * 0.012f,
                right,
                statRect.bottom + h * 0.012f + menuSize);
        c.drawBitmap(hudMenuToggle, null, menuHit, imagePaint);
    }

    private void drawHudMeter(Canvas c, Bitmap frame, Bitmap fill, RectF frameRect, float ratio,
                              float trackLeft, float trackTop, float trackRight, float trackBottom) {
        // The generated frame has an opaque dark track. Draw the frame FIRST,
        // then place the colored fill on top of the track so it cannot be hidden.
        c.drawBitmap(frame, null, frameRect, imagePaint);

        RectF track = new RectF(
                frameRect.left + frameRect.width() * trackLeft,
                frameRect.top + frameRect.height() * trackTop,
                frameRect.left + frameRect.width() * trackRight,
                frameRect.top + frameRect.height() * trackBottom);

        float ratioClamped = PlayerStats.clamp01(ratio);
        if (ratioClamped <= 0.001f) return;

        float visibleRight = track.left + track.width() * ratioClamped;
        int save = c.save();
        c.clipRect(track.left, track.top, visibleRight, track.bottom);
        c.drawBitmap(fill, null, track, imagePaint);
        c.restoreToCount(save);

        // Tiny highlight line makes the meter remain readable on dark screens.
        overlayPaint.setColor(Color.argb(105, 255, 255, 255));
        float lineY = track.top + track.height() * 0.18f;
        c.drawRect(track.left + track.height() * 0.25f, lineY,
                Math.max(track.left + track.height() * 0.25f, visibleRight - track.height() * 0.25f),
                lineY + Math.max(1f, getHeight() * 0.0015f), overlayPaint);
    }

    private void drawSmallValue(Canvas c, String text, float x, float y, float size, Paint.Align align) {
        uiPaint.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        uiPaint.setTextSize(size);
        uiPaint.setTextAlign(align);
        uiPaint.setColor(Color.argb(180, 0, 0, 0));
        c.drawText(text, x + 2f, y + 2f, uiPaint);
        uiPaint.setColor(Color.rgb(239, 229, 210));
        c.drawText(text, x, y, uiPaint);
        uiPaint.setTextAlign(Paint.Align.LEFT);
    }

    // ---------------- Status menu ----------------
    private void openStatus() {
        statusOpen = true;
        statusAnim = 0f;
        for (int i = 0; i < pending.length; i++) pending[i] = 0;
        pendingPoints = stats.attributePoints;
        joyPointer = attackPointer = -1;
        joyX = joyY = 0f;
        haptic();
    }

    private void closeStatus(boolean discard) {
        statusOpen = false;
        if (discard) {
            for (int i = 0; i < pending.length; i++) pending[i] = 0;
            pendingPoints = stats.attributePoints;
        }
    }

    public boolean handleBack() {
        if (statusOpen) {
            closeStatus(true);
            return true;
        }
        return false;
    }

    private void drawStatusOverlay(Canvas c) {
        if (statusAnim < 0.008f) return;

        float a = smooth(statusAnim);
        float pop = 0.90f + 0.10f * easeOutBack(clamp(a / 0.92f, 0f, 1f));
        float slideY = (1f - a) * getHeight() * 0.055f;

        // Dim the game gradually instead of instantly covering it.
        overlayPaint.setColor(Color.argb((int) (205 * a), 2, 3, 6));
        c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);

        float finalW = getWidth() * 0.84f;
        float finalH = getHeight() * 0.91f;
        float cx = getWidth() * 0.50f;
        float cy = getHeight() * 0.500f + slideY;
        float panelW = finalW * pop;
        float panelH = finalH * pop;
        RectF panel = new RectF(cx - panelW * 0.5f, cy - panelH * 0.5f,
                cx + panelW * 0.5f, cy + panelH * 0.5f);

        // Panel body.
        overlayPaint.setColor(Color.argb((int) (240 * a), 7, 8, 12));
        c.drawRoundRect(panel, getHeight() * 0.024f, getHeight() * 0.024f, overlayPaint);

        float pulse = 0.5f + 0.5f * (float) Math.sin(System.nanoTime() / 1_000_000_000.0 * 3.0);
        overlayPaint.setStyle(Paint.Style.STROKE);
        overlayPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.0045f));
        overlayPaint.setColor(Color.argb((int) ((155 + 45 * pulse) * a), 132, 28, 39));
        c.drawRoundRect(panel, getHeight() * 0.024f, getHeight() * 0.024f, overlayPaint);
        overlayPaint.setStrokeWidth(Math.max(1f, getHeight() * 0.0018f));
        overlayPaint.setColor(Color.argb((int) ((70 + 35 * pulse) * a), 245, 62, 74));
        RectF innerGlow = new RectF(panel.left + getHeight() * 0.008f, panel.top + getHeight() * 0.008f,
                panel.right - getHeight() * 0.008f, panel.bottom - getHeight() * 0.008f);
        c.drawRoundRect(innerGlow, getHeight() * 0.020f, getHeight() * 0.020f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.FILL);

        float headerReveal = revealWindow(a, 0.04f, 0.42f);
        float leftReveal = revealWindow(a, 0.12f, 0.62f);
        float rowsReveal = revealWindow(a, 0.17f, 0.72f);
        float attrReveal = revealWindow(a, 0.30f, 0.82f);
        float bottomReveal = revealWindow(a, 0.46f, 0.96f);

        float headerW = panel.width() * 0.30f;
        float headerH = headerW * statusHeader.getHeight() / (float) statusHeader.getWidth();
        float headerOffsetY = (1f - headerReveal) * getHeight() * 0.035f;
        RectF header = new RectF(panel.centerX() - headerW * 0.5f,
                panel.top - headerH * 0.12f - headerOffsetY,
                panel.centerX() + headerW * 0.5f,
                panel.top + headerH * 0.88f - headerOffsetY);
        drawBitmapAlpha(c, statusHeader, header, headerReveal);

        closeStatusHit.set(panel.right - getHeight() * 0.070f, panel.top + getHeight() * 0.030f,
                panel.right - getHeight() * 0.018f, panel.top + getHeight() * 0.082f);
        overlayPaint.setColor(Color.argb((int) (190 * rowsReveal), 110, 18, 28));
        c.drawRoundRect(closeStatusHit, getHeight() * 0.010f, getHeight() * 0.010f, overlayPaint);
        drawSmallValueAlpha(c, "×", closeStatusHit.centerX(),
                closeStatusHit.centerY() + getHeight() * 0.017f,
                getHeight() * 0.041f, Paint.Align.CENTER, rowsReveal, Color.rgb(245, 226, 218));

        float innerTop = panel.top + panel.height() * 0.145f;
        float leftX = panel.left + panel.width() * 0.050f;
        float leftW = panel.width() * 0.235f;
        float rightX = panel.left + panel.width() * 0.325f;
        float rightW = panel.width() * 0.625f;

        // Portrait column enters from the left.
        float portraitH = panel.height() * 0.30f;
        float leftOffset = (1f - leftReveal) * panel.width() * 0.045f;
        RectF portrait = new RectF(leftX - leftOffset, innerTop,
                leftX - leftOffset + leftW, innerTop + portraitH);
        drawBitmapAlpha(c, statusPortraitFrame, portrait, leftReveal);

        Bitmap kael = idle[DOWN][1];
        float spriteH = portrait.height() * 0.70f;
        float spriteW = spriteH * kael.getWidth() / (float) kael.getHeight();
        RectF kaelDst = new RectF(portrait.centerX() - spriteW * 0.5f,
                portrait.bottom - spriteH * 0.91f,
                portrait.centerX() + spriteW * 0.5f,
                portrait.bottom + spriteH * 0.09f);
        pixelPaint.setAlpha((int) (255 * leftReveal));
        c.drawBitmap(kael, null, kaelDst, pixelPaint);
        pixelPaint.setAlpha(255);

        RectF desc = new RectF(leftX - leftOffset,
                portrait.bottom + panel.height() * 0.026f,
                leftX - leftOffset + leftW,
                portrait.bottom + panel.height() * 0.165f);
        drawBitmapAlpha(c, statusDescFrame, desc, leftReveal);
        uiPaint.setTextAlign(Paint.Align.CENTER);
        uiPaint.setTextSize(getHeight() * 0.018f);
        uiPaint.setColor(Color.rgb(203, 196, 185));
        uiPaint.setAlpha((int) (255 * leftReveal));
        c.drawText("Kael Varyn", desc.centerX(), desc.top + desc.height() * 0.42f, uiPaint);
        c.drawText("Portador da Marca VIII", desc.centerX(), desc.top + desc.height() * 0.70f, uiPaint);
        uiPaint.setAlpha(255);
        uiPaint.setTextAlign(Paint.Align.LEFT);

        // Vital rows slide from the right in a short stagger.
        float rowH = panel.height() * 0.066f;
        float rowGap = panel.height() * 0.014f;
        RectF[] rows = new RectF[4];
        Bitmap[] rowBmps = {statusHpRow, statusManaRow, statusLevelRow, statusXpRow};
        for (int i = 0; i < 4; i++) {
            float rr = revealWindow(a, 0.16f + i * 0.045f, 0.58f + i * 0.045f);
            float y0 = innerTop + i * (rowH + rowGap);
            float xOff = (1f - rr) * panel.width() * 0.045f;
            rows[i] = new RectF(rightX + xOff, y0, rightX + rightW + xOff, y0 + rowH);
            drawBitmapAlpha(c, rowBmps[i], rows[i], rr);
        }

        drawStatusMeterAlpha(c, rows[0], stats.hpRatio(), Color.rgb(205, 28, 45), rowsReveal);
        drawStatusMeterAlpha(c, rows[1], stats.manaRatio(), Color.rgb(35, 118, 232), rowsReveal);
        drawStatusMeterAlpha(c, rows[3], stats.xpRatio(), Color.rgb(151, 50, 220), rowsReveal);
        // Redraw row frames after the fills so borders stay crisp.
        for (int i = 0; i < 4; i++) drawBitmapAlpha(c, rowBmps[i], rows[i], rowsReveal);

        drawSmallValueAlpha(c, stats.hp + " / " + stats.maxHp,
                rows[0].left + rows[0].width() * 0.61f, rows[0].centerY() + getHeight() * 0.009f,
                getHeight() * 0.020f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));
        drawSmallValueAlpha(c, stats.mana + " / " + stats.maxMana,
                rows[1].left + rows[1].width() * 0.61f, rows[1].centerY() + getHeight() * 0.009f,
                getHeight() * 0.020f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));
        drawSmallValueAlpha(c, String.valueOf(stats.level),
                rows[2].left + rows[2].width() * 0.64f, rows[2].centerY() + getHeight() * 0.009f,
                getHeight() * 0.022f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));
        drawSmallValueAlpha(c, stats.xp + " / " + stats.xpToNext,
                rows[3].left + rows[3].width() * 0.61f, rows[3].centerY() + getHeight() * 0.009f,
                getHeight() * 0.019f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));

        // Attribute block sits fully above the resources row.
        float blockTop = rows[3].bottom + panel.height() * 0.028f;
        float blockH = panel.height() * 0.245f;
        float attrOffset = (1f - attrReveal) * getHeight() * 0.020f;
        RectF block = new RectF(rightX, blockTop + attrOffset, rightX + rightW, blockTop + blockH + attrOffset);
        drawBitmapAlpha(c, statusAttrBlock, block, attrReveal);

        int[] base = {stats.attack, stats.defense, stats.crit, stats.speed};
        int[] delta = {pending[0] * 2, pending[1] * 2, pending[2], pending[3] * 5};
        String[] suffix = {"", "", "%", ""};

        for (int i = 0; i < 4; i++) {
            float y0 = block.top + block.height() * (0.045f + i * 0.247f);
            float y1 = y0 + block.height() * 0.195f;
            RectF valueRect = new RectF(block.left + block.width() * 0.405f, y0,
                    block.left + block.width() * 0.655f, y1);
            String preview = delta[i] > 0
                    ? base[i] + " → " + (base[i] + delta[i]) + suffix[i]
                    : base[i] + suffix[i];
            int color = delta[i] > 0 ? Color.rgb(255, 207, 118) : Color.rgb(239, 229, 210);
            drawSmallValueAlpha(c, preview, valueRect.centerX(),
                    valueRect.centerY() + getHeight() * 0.009f,
                    getHeight() * (delta[i] > 0 ? 0.020f : 0.022f),
                    Paint.Align.CENTER, attrReveal, color);

            minusHits[i].set(block.left + block.width() * 0.685f, y0,
                    block.left + block.width() * 0.825f, y1);
            plusHits[i].set(block.left + block.width() * 0.835f, y0,
                    block.right, y1);
        }

        // Resources are on their own row, with the upgrade button below them.
        float upW = panel.width() * 0.255f;
        float upH = upW * statusUpgrade.getHeight() / (float) statusUpgrade.getWidth();
        float upBottom = panel.bottom - panel.height() * 0.035f;
        upgradeHit.set(panel.centerX() - upW * 0.5f, upBottom - upH,
                panel.centerX() + upW * 0.5f, upBottom);

        float resH = panel.height() * 0.062f;
        float resBottom = upgradeHit.top - panel.height() * 0.024f;
        float resTop = resBottom - resH;
        RectF ap = new RectF(panel.left + panel.width() * 0.070f, resTop,
                panel.left + panel.width() * 0.470f, resBottom);
        RectF money = new RectF(panel.left + panel.width() * 0.530f, resTop,
                panel.right - panel.width() * 0.070f, resBottom);

        drawBitmapAlpha(c, statusAttrPoints, ap, bottomReveal);
        drawBitmapAlpha(c, statusMoney, money, bottomReveal);
        drawSmallValueAlpha(c, String.valueOf(pendingPoints),
                ap.right - ap.width() * 0.105f, ap.centerY() + getHeight() * 0.009f,
                getHeight() * 0.023f, Paint.Align.RIGHT, bottomReveal, Color.rgb(255, 215, 133));
        drawSmallValueAlpha(c, String.valueOf(stats.money),
                money.right - money.width() * 0.105f, money.centerY() + getHeight() * 0.009f,
                getHeight() * 0.023f, Paint.Align.RIGHT, bottomReveal, Color.rgb(255, 215, 133));

        float buttonScale = hasPending() ? 1f + 0.018f * pulse : 1f;
        RectF buttonDraw = scaleRect(upgradeHit, buttonScale);
        imagePaint.setAlpha((int) ((hasPending() ? 255 : 135) * bottomReveal));
        c.drawBitmap(statusUpgrade, null, buttonDraw, imagePaint);
        imagePaint.setAlpha(255);

        if (hasPending()) {
            overlayPaint.setStyle(Paint.Style.STROKE);
            overlayPaint.setStrokeWidth(Math.max(1f, getHeight() * 0.0025f));
            overlayPaint.setColor(Color.argb((int) ((65 + 70 * pulse) * bottomReveal), 255, 72, 82));
            c.drawRoundRect(buttonDraw, getHeight() * 0.014f, getHeight() * 0.014f, overlayPaint);
            overlayPaint.setStyle(Paint.Style.FILL);
        }
    }


    private void drawStatusMeterAlpha(Canvas c, RectF row, float ratio, int color, float alpha) {
        RectF track = new RectF(
                row.left + row.width() * 0.705f,
                row.top + row.height() * 0.31f,
                row.left + row.width() * 0.935f,
                row.bottom - row.height() * 0.29f);
        overlayPaint.setColor((color & 0x00FFFFFF) | ((int) (235 * alpha) << 24));
        RectF fill = new RectF(track.left, track.top,
                track.left + track.width() * PlayerStats.clamp01(ratio), track.bottom);
        c.drawRoundRect(fill, track.height() * 0.45f, track.height() * 0.45f, overlayPaint);
    }

    

    

    private float revealWindow(float value, float start, float end) {
        if (end <= start) return value >= end ? 1f : 0f;
        return smooth(clamp((value - start) / (end - start), 0f, 1f));
    }

    private float easeOutBack(float t) {
        t = clamp(t, 0f, 1f);
        float c1 = 1.70158f;
        float c3 = c1 + 1f;
        float x = t - 1f;
        return 1f + c3 * x * x * x + c1 * x * x;
    }

    private RectF scaleRect(RectF r, float scale) {
        float cx = r.centerX();
        float cy = r.centerY();
        float hw = r.width() * 0.5f * scale;
        float hh = r.height() * 0.5f * scale;
        return new RectF(cx - hw, cy - hh, cx + hw, cy + hh);
    }

    private void drawBitmapAlpha(Canvas c, Bitmap bitmap, RectF dst, float alpha) {
        imagePaint.setAlpha((int) (255 * clamp(alpha, 0f, 1f)));
        c.drawBitmap(bitmap, null, dst, imagePaint);
        imagePaint.setAlpha(255);
    }

    private void drawSmallValueAlpha(Canvas c, String text, float x, float y, float size,
                                     Paint.Align align, float alpha, int color) {
        uiPaint.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        uiPaint.setTextSize(size);
        uiPaint.setTextAlign(align);
        uiPaint.setAlpha((int) (255 * clamp(alpha, 0f, 1f)));
        uiPaint.setColor(Color.argb((int) (150 * clamp(alpha, 0f, 1f)), 0, 0, 0));
        c.drawText(text, x + 2f, y + 2f, uiPaint);
        uiPaint.setColor(color);
        c.drawText(text, x, y, uiPaint);
        uiPaint.setAlpha(255);
        uiPaint.setTextAlign(Paint.Align.LEFT);
    }

    private boolean hasPending() {
        for (int p : pending) if (p > 0) return true;
        return false;
    }

    private void addPending(int index) {
        if (pendingPoints <= 0) return;
        pending[index]++;
        pendingPoints--;
        haptic();
    }

    private void removePending(int index) {
        if (pending[index] <= 0) return;
        pending[index]--;
        pendingPoints++;
        haptic();
    }

    private void commitPending() {
        if (!hasPending()) return;
        stats.attack += pending[0] * 2;
        stats.defense += pending[1] * 2;
        stats.crit += pending[2];
        stats.speed += pending[3] * 5;
        stats.attributePoints = pendingPoints;
        for (int i = 0; i < pending.length; i++) pending[i] = 0;
        saveState();
        haptic();
    }

    private void haptic() {
        if (prefs.getBoolean("vibration", true)) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
    }

    public void grantXp(int amount) {
        int levels = stats.addXp(amount);
        if (levels > 0) {
            pendingPoints = stats.attributePoints;
            levelUpFlash = 2.0f;
        }
        saveState();
    }

    private void drawLevelUpFlash(Canvas c) {
        if (levelUpFlash <= 0f) return;
        float a = Math.min(1f, levelUpFlash * 2f);
        float w = getWidth() * 0.34f;
        float hh = w * levelHeader.getHeight() / (float) levelHeader.getWidth();
        RectF header = new RectF(getWidth() * 0.5f - w * 0.5f, getHeight() * 0.20f,
                getWidth() * 0.5f + w * 0.5f, getHeight() * 0.20f + hh);
        float rw = getWidth() * 0.28f;
        float rh = rw * levelReward.getHeight() / (float) levelReward.getWidth();
        RectF reward = new RectF(getWidth() * 0.5f - rw * 0.5f, header.bottom - getHeight() * 0.02f,
                getWidth() * 0.5f + rw * 0.5f, header.bottom - getHeight() * 0.02f + rh);
        imagePaint.setAlpha((int) (255 * a));
        c.drawBitmap(levelHeader, null, header, imagePaint);
        c.drawBitmap(levelReward, null, reward, imagePaint);
        imagePaint.setAlpha(255);
    }

    // ---------------- Controls ----------------
    private float joyCx() { return getWidth() * 0.13f; }
    private float joyCy() { return getHeight() * 0.79f; }
    private float joyR() { return getHeight() * 0.14f; }
    private float atkCx() { return getWidth() * 0.865f; }
    private float atkCy() { return getHeight() * 0.78f; }
    private float atkR() { return getHeight() * 0.105f; }

    private void drawControls(Canvas c) {
        float jx = joyCx(), jy = joyCy(), jr = joyR();
        uiPaint.setColor(Color.argb(72, 255, 255, 255));
        c.drawCircle(jx, jy, jr, uiPaint);
        uiPaint.setStyle(Paint.Style.STROKE);
        uiPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.003f));
        uiPaint.setColor(Color.argb(95, 255, 255, 255));
        c.drawCircle(jx, jy, jr, uiPaint);
        uiPaint.setStyle(Paint.Style.FILL);
        uiPaint.setColor(Color.argb(150, 176, 52, 67));
        c.drawCircle(jx + joyX * jr * 0.55f, jy + joyY * jr * 0.55f, jr * 0.42f, uiPaint);

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
        float x = e.getX(actionIndex), y = e.getY(actionIndex);

        if (statusOpen) {
            if (action == MotionEvent.ACTION_DOWN) {
                if (closeStatusHit.contains(x, y)) { closeStatus(true); return true; }
                for (int i = 0; i < 4; i++) {
                    if (plusHits[i].contains(x, y)) { addPending(i); return true; }
                    if (minusHits[i].contains(x, y)) { removePending(i); return true; }
                }
                if (upgradeHit.contains(x, y)) { commitPending(); return true; }
            }
            return true;
        }

        if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
            if (menuHit.contains(x, y)) { openStatus(); return true; }
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
                joyPointer = -1; joyX = 0f; joyY = 0f;
            }
            if (pointerId == attackPointer || action == MotionEvent.ACTION_CANCEL) attackPointer = -1;
            return true;
        }
        return true;
    }

    private void updateJoystick(float x, float y) {
        float dx = (x - joyCx()) / joyR();
        float dy = (y - joyCy()) / joyR();
        float len = (float) Math.hypot(dx, dy);
        if (len > 1f) { dx /= len; dy /= len; }
        joyX = dx; joyY = dy;
    }

    public void saveState() {
        if (getWidth() <= 0 || getHeight() <= 0 || px < 0f || py < 0f) return;
        SharedPreferences.Editor editor = prefs.edit()
                .putBoolean("has_save", true)
                .putFloat("player_x_norm", clamp(px / getWidth(), 0f, 1f))
                .putFloat("player_y_norm", clamp(py / getHeight(), 0f, 1f))
                .putInt("player_facing", facing);
        stats.save(editor);
        editor.apply();
    }

    @Override
    protected void onDetachedFromWindow() {
        saveState();
        super.onDetachedFromWindow();
    }

    private RectF offset(RectF r, float dx, float dy) {
        return new RectF(r.left + dx, r.top + dy, r.right + dx, r.bottom + dy);
    }

    private float smooth(float t) {
        t = clamp(t, 0f, 1f);
        return t * t * (3f - 2f * t);
    }

    private float distance(float x1, float y1, float x2, float y2) {
        return (float) Math.hypot(x1 - x2, y1 - y2);
    }

    private float clamp(float v, float min, float max) {
        return Math.max(min, Math.min(max, v));
    }
}