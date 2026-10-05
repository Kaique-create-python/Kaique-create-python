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
        float left = w * 0.012f;
        float top = h * 0.010f;

        float hpW = w * 0.34f;
        float hpH = hpW * hudHpFrame.getHeight() / (float) hudHpFrame.getWidth();
        RectF hpRect = new RectF(left, top, left + hpW, top + hpH);
        drawHudMeter(c, hudHpFrame, hudHpFill, hpRect, stats.hpRatio(), 0.265f, 0.40f, 0.86f, 0.68f);
        drawSmallValue(c, stats.hp + "/" + stats.maxHp, hpRect.right - hpW * 0.08f, hpRect.centerY(), h * 0.022f, Paint.Align.RIGHT);

        float manaW = w * 0.31f;
        float manaH = manaW * hudManaFrame.getHeight() / (float) hudManaFrame.getWidth();
        RectF manaRect = new RectF(left, hpRect.bottom - h * 0.010f, left + manaW, hpRect.bottom - h * 0.010f + manaH);
        drawHudMeter(c, hudManaFrame, hudManaFill, manaRect, stats.manaRatio(), 0.28f, 0.39f, 0.86f, 0.70f);
        drawSmallValue(c, stats.mana + "/" + stats.maxMana, manaRect.right - manaW * 0.07f, manaRect.centerY(), h * 0.020f, Paint.Align.RIGHT);

        float xpW = w * 0.27f;
        float xpH = xpW * hudXpFrame.getHeight() / (float) hudXpFrame.getWidth();
        RectF xpRect = new RectF(left + w * 0.004f, manaRect.bottom - h * 0.005f, left + w * 0.004f + xpW, manaRect.bottom - h * 0.005f + xpH);
        drawHudMeter(c, hudXpFrame, hudXpFill, xpRect, stats.xpRatio(), 0.23f, 0.30f, 0.90f, 0.62f);
        drawSmallValue(c, stats.xp + "/" + stats.xpToNext, xpRect.right - xpW * 0.03f, xpRect.centerY(), h * 0.018f, Paint.Align.RIGHT);

        float lvSize = h * 0.135f;
        RectF lvRect = new RectF(xpRect.right + w * 0.006f, xpRect.top - h * 0.035f,
                xpRect.right + w * 0.006f + lvSize, xpRect.top - h * 0.035f + lvSize);
        c.drawBitmap(hudLevel, null, lvRect, imagePaint);
        drawSmallValue(c, String.format(Locale.US, "%02d", stats.level), lvRect.centerX(), lvRect.centerY() + h * 0.020f, h * 0.037f, Paint.Align.CENTER);

        float moneyW = w * 0.17f;
        float moneyH = moneyW * hudMoney.getHeight() / (float) hudMoney.getWidth();
        RectF moneyRect = new RectF(w - moneyW - w * 0.012f, h * 0.018f, w - w * 0.012f, h * 0.018f + moneyH);
        c.drawBitmap(hudMoney, null, moneyRect, imagePaint);
        drawSmallValue(c, String.valueOf(stats.money), moneyRect.left + moneyRect.width() * 0.58f, moneyRect.centerY() + h * 0.004f, h * 0.028f, Paint.Align.CENTER);

        float statW = w * 0.25f;
        float statH = statW * hudStats.getHeight() / (float) hudStats.getWidth();
        RectF statRect = new RectF(w - statW - w * 0.012f, moneyRect.bottom - h * 0.004f, w - w * 0.012f, moneyRect.bottom - h * 0.004f + statH);
        c.drawBitmap(hudStats, null, statRect, imagePaint);
        float y = statRect.centerY() + h * 0.006f;
        float[] xs = {0.19f, 0.43f, 0.68f, 0.91f};
        String[] vals = {String.valueOf(stats.attack), String.valueOf(stats.defense), stats.crit + "%", String.valueOf(stats.speed)};
        for (int i = 0; i < 4; i++) drawSmallValue(c, vals[i], statRect.left + statRect.width() * xs[i], y, h * 0.021f, Paint.Align.CENTER);

        float menuSize = h * 0.105f;
        menuHit.set(w - menuSize - w * 0.015f, statRect.bottom + h * 0.006f, w - w * 0.015f, statRect.bottom + h * 0.006f + menuSize);
        c.drawBitmap(hudMenuToggle, null, menuHit, imagePaint);
    }

    private void drawHudMeter(Canvas c, Bitmap frame, Bitmap fill, RectF frameRect, float ratio,
                              float trackLeft, float trackTop, float trackRight, float trackBottom) {
        RectF track = new RectF(frameRect.left + frameRect.width() * trackLeft,
                frameRect.top + frameRect.height() * trackTop,
                frameRect.left + frameRect.width() * trackRight,
                frameRect.top + frameRect.height() * trackBottom);
        int save = c.save();
        c.clipRect(track.left, track.top, track.left + track.width() * PlayerStats.clamp01(ratio), track.bottom);
        c.drawBitmap(fill, null, track, imagePaint);
        c.restoreToCount(save);
        c.drawBitmap(frame, null, frameRect, imagePaint);
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
        for (int i = 0; i < pending.length; i++) pending[i] = 0;
        pendingPoints = stats.attributePoints;
        joyPointer = attackPointer = -1;
        joyX = joyY = 0f;
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
        if (statusAnim < 0.01f) return;
        float a = smooth(statusAnim);
        overlayPaint.setColor(Color.argb((int) (215 * a), 2, 3, 6));
        c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);

        float panelH = getHeight() * 0.90f * a;
        float panelW = getWidth() * 0.70f * a;
        float cx = getWidth() * 0.50f;
        float cy = getHeight() * 0.50f;
        RectF panel = new RectF(cx - panelW * 0.5f, cy - panelH * 0.5f, cx + panelW * 0.5f, cy + panelH * 0.5f);
        overlayPaint.setColor(Color.argb((int) (238 * a), 8, 9, 13));
        c.drawRoundRect(panel, getHeight() * 0.025f, getHeight() * 0.025f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.STROKE);
        overlayPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.004f));
        overlayPaint.setColor(Color.argb((int) (210 * a), 126, 29, 39));
        c.drawRoundRect(panel, getHeight() * 0.025f, getHeight() * 0.025f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.FILL);

        float headerW = panel.width() * 0.42f;
        float headerH = headerW * statusHeader.getHeight() / (float) statusHeader.getWidth();
        RectF header = new RectF(panel.centerX() - headerW * 0.5f, panel.top - headerH * 0.10f,
                panel.centerX() + headerW * 0.5f, panel.top + headerH * 0.90f);
        c.drawBitmap(statusHeader, null, header, imagePaint);

        closeStatusHit.set(panel.right - getHeight() * 0.065f, panel.top + getHeight() * 0.035f,
                panel.right - getHeight() * 0.015f, panel.top + getHeight() * 0.085f);
        overlayPaint.setColor(Color.argb(190, 110, 18, 28));
        c.drawRoundRect(closeStatusHit, 8f, 8f, overlayPaint);
        drawSmallValue(c, "×", closeStatusHit.centerX(), closeStatusHit.centerY() + getHeight() * 0.018f, getHeight() * 0.045f, Paint.Align.CENTER);

        float innerTop = panel.top + panel.height() * 0.18f;
        float leftX = panel.left + panel.width() * 0.07f;
        float leftW = panel.width() * 0.28f;
        float rightX = panel.left + panel.width() * 0.38f;
        float rightW = panel.width() * 0.55f;

        // Portrait
        float portraitH = panel.height() * 0.30f;
        RectF portrait = new RectF(leftX, innerTop, leftX + leftW, innerTop + portraitH);
        c.drawBitmap(statusPortraitFrame, null, portrait, imagePaint);
        Bitmap kael = idle[DOWN][1];
        float spriteH = portrait.height() * 0.72f;
        float spriteW = spriteH * kael.getWidth() / (float) kael.getHeight();
        RectF kaelDst = new RectF(portrait.centerX() - spriteW * 0.5f, portrait.bottom - spriteH * 0.90f,
                portrait.centerX() + spriteW * 0.5f, portrait.bottom + spriteH * 0.10f);
        c.drawBitmap(kael, null, kaelDst, pixelPaint);

        RectF desc = new RectF(leftX, portrait.bottom + panel.height() * 0.025f,
                leftX + leftW, portrait.bottom + panel.height() * 0.18f);
        c.drawBitmap(statusDescFrame, null, desc, imagePaint);
        uiPaint.setTextAlign(Paint.Align.CENTER);
        uiPaint.setTextSize(getHeight() * 0.020f);
        uiPaint.setColor(Color.rgb(190, 184, 176));
        c.drawText("Kael Varyn", desc.centerX(), desc.top + desc.height() * 0.40f, uiPaint);
        c.drawText("Portador da Marca VIII", desc.centerX(), desc.top + desc.height() * 0.66f, uiPaint);
        uiPaint.setTextAlign(Paint.Align.LEFT);

        // Vital rows
        float rowH = panel.height() * 0.085f;
        RectF r1 = new RectF(rightX, innerTop, rightX + rightW, innerTop + rowH);
        RectF r2 = offset(r1, 0f, rowH * 0.95f);
        RectF r3 = offset(r1, 0f, rowH * 1.90f);
        RectF r4 = offset(r1, 0f, rowH * 2.85f);
        drawStatusMeter(c, r1, stats.hpRatio(), Color.rgb(195, 25, 42));
        drawStatusMeter(c, r2, stats.manaRatio(), Color.rgb(31, 112, 220));
        drawStatusMeter(c, r4, stats.xpRatio(), Color.rgb(147, 47, 212));
        c.drawBitmap(statusHpRow, null, r1, imagePaint);
        c.drawBitmap(statusManaRow, null, r2, imagePaint);
        c.drawBitmap(statusLevelRow, null, r3, imagePaint);
        c.drawBitmap(statusXpRow, null, r4, imagePaint);
        drawStatusRowValue(c, r1, stats.hp + " / " + stats.maxHp, stats.hpRatio());
        drawStatusRowValue(c, r2, stats.mana + " / " + stats.maxMana, stats.manaRatio());
        drawStatusRowText(c, r3, String.valueOf(stats.level));
        drawStatusRowValue(c, r4, stats.xp + " / " + stats.xpToNext, stats.xpRatio());

        // Attribute block
        float blockTop = r4.bottom + panel.height() * 0.018f;
        float blockH = panel.height() * 0.31f;
        RectF block = new RectF(rightX, blockTop, rightX + rightW, blockTop + blockH);
        c.drawBitmap(statusAttrBlock, null, block, imagePaint);
        String[] values = {
                String.valueOf(stats.attack + pending[0] * 2),
                String.valueOf(stats.defense + pending[1] * 2),
                (stats.crit + pending[2]) + "%",
                String.valueOf(stats.speed + pending[3] * 5)
        };
        for (int i = 0; i < 4; i++) {
            float y0 = block.top + block.height() * (0.055f + i * 0.245f);
            float y1 = y0 + block.height() * 0.19f;
            RectF valueRect = new RectF(block.left + block.width() * 0.43f, y0, block.left + block.width() * 0.63f, y1);
            drawSmallValue(c, values[i], valueRect.centerX(), valueRect.centerY() + getHeight() * 0.010f, getHeight() * 0.025f, Paint.Align.CENTER);
            minusHits[i].set(block.left + block.width() * 0.68f, y0, block.left + block.width() * 0.82f, y1);
            plusHits[i].set(block.left + block.width() * 0.84f, y0, block.right, y1);
        }

        // Bottom resources + upgrade
        float bottomY = panel.bottom - panel.height() * 0.14f;
        RectF ap = new RectF(panel.left + panel.width() * 0.09f, bottomY,
                panel.left + panel.width() * 0.48f, bottomY + panel.height() * 0.085f);
        RectF money = new RectF(panel.left + panel.width() * 0.52f, bottomY,
                panel.right - panel.width() * 0.09f, bottomY + panel.height() * 0.085f);
        c.drawBitmap(statusAttrPoints, null, ap, imagePaint);
        c.drawBitmap(statusMoney, null, money, imagePaint);
        drawSmallValue(c, String.valueOf(pendingPoints), ap.right - ap.width() * 0.10f, ap.centerY() + getHeight() * 0.010f, getHeight() * 0.026f, Paint.Align.RIGHT);
        drawSmallValue(c, String.valueOf(stats.money), money.right - money.width() * 0.10f, money.centerY() + getHeight() * 0.010f, getHeight() * 0.026f, Paint.Align.RIGHT);

        float upW = panel.width() * 0.34f;
        float upH = upW * statusUpgrade.getHeight() / (float) statusUpgrade.getWidth();
        upgradeHit.set(panel.centerX() - upW * 0.5f, panel.bottom - upH * 0.95f,
                panel.centerX() + upW * 0.5f, panel.bottom + upH * 0.05f);
        imagePaint.setAlpha(hasPending() ? 255 : 130);
        c.drawBitmap(statusUpgrade, null, upgradeHit, imagePaint);
        imagePaint.setAlpha(255);
    }


    private void drawStatusMeter(Canvas c, RectF row, float ratio, int color) {
        RectF track = new RectF(row.left + row.width() * 0.71f, row.top + row.height() * 0.32f,
                row.left + row.width() * 0.94f, row.bottom - row.height() * 0.30f);
        overlayPaint.setColor(color);
        RectF fill = new RectF(track.left, track.top, track.left + track.width() * PlayerStats.clamp01(ratio), track.bottom);
        c.drawRoundRect(fill, track.height() * 0.45f, track.height() * 0.45f, overlayPaint);
    }

    private void drawStatusRowValue(Canvas c, RectF row, String text, float ratio) {
        drawSmallValue(c, text, row.left + row.width() * 0.60f, row.centerY() + getHeight() * 0.010f, getHeight() * 0.022f, Paint.Align.CENTER);
    }

    private void drawStatusRowText(Canvas c, RectF row, String text) {
        drawSmallValue(c, text, row.left + row.width() * 0.64f, row.centerY() + getHeight() * 0.010f, getHeight() * 0.025f, Paint.Align.CENTER);
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