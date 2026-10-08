package com.veilbreakers.prototype;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.util.Log;
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
    private final Bitmap[][] walk = new Bitmap[4][];
    private final Bitmap[][] run = new Bitmap[4][];
    private final Bitmap[][] comboLeft = new Bitmap[3][];
    private final Bitmap[][] comboRight = new Bitmap[3][];
    private final Bitmap[][] comboDown = new Bitmap[3][];
    private final Bitmap[][] comboUp = new Bitmap[3][];
    private final Bitmap[][] magicCastFrames = new Bitmap[4][];
    private Bitmap[] magicOrbFrames;
    private final Bitmap[][] enemyIdleFrames = new Bitmap[4][];
    private final Bitmap[][] enemyChaseFrames = new Bitmap[4][];
    private final Bitmap[][] enemyAttackFrames = new Bitmap[4][];
    private Bitmap[] enemyHurtFrames, enemyDeathFrames;
    private Bitmap joyBase, joyBaseActive, joyKnob, joyKnobPressed, joyGlow;
    private Bitmap attackBtnNormal, attackBtnPressed, attackBtnCombo, attackBtnDisabled, attackBtnFlash;

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
    private int magicPointer = -1;

    private int facing = DOWN;
    private int attackFacing = DOWN;
    private float idleClock = 0f;
    private float runClock = 0f;
    private boolean attacking = false;
    private float attackClock = 0f;
    private boolean attackHitApplied = false;
    private int comboStage = 0;              // 0,1,2 = three-hit chain
    private boolean comboQueued = false;
    private float comboGrace = 0f;
    private float attackButtonFlash = 0f;

    // v1.6 Arcana VIII: first Mana-powered ranged ability.
    private static final int MAGIC_COST = 18;
    private static final float MAGIC_COOLDOWN_MAX = 1.10f;
    private float magicCooldown = 0f;
    private float manaRegenDelay = 0f;
    private float manaRegenBank = 0f;
    private boolean magicCasting = false;
    private boolean magicReleased = false;
    private float magicCastClock = 0f;
    private boolean magicActive = false;
    private boolean magicHitApplied = false;
    private float magicX = 0f, magicY = 0f;
    private float magicVx = 0f, magicVy = 0f;
    private float magicLife = 0f;
    private float magicAge = 0f;
    private float magicImpactTimer = 0f;
    private float magicImpactX = 0f, magicImpactY = 0f;
    private boolean magicImpactIsHit = true;
    private int magicFacing = DOWN;

    private long lastNs = System.nanoTime();
    private boolean artReviewMode = false;
    private String artReviewState = "idle";
    private int artReviewDirection = DOWN;
    private int artReviewFrame = 0;
    private long artReviewStartNs = 0L;

    // v1.2 combat prototype: first Veilborn enemy.
    private float enemyX = -1f, enemyY = -1f;
    private float enemyVx = 0f, enemyVy = 0f;
    private float enemyKnockX = 0f, enemyKnockY = 0f;
    private int enemyMaxHp = 55, enemyHp = 55;
    private int enemyAttack = 16, enemyDefense = 4;
    private boolean enemyAlive = true;
    private float enemyAttackCooldown = 0.75f;
    private float enemyAttackAnim = 0f;
    private float enemyHurtTimer = 0f;
    private int enemyFacing = DOWN;
    private int enemyAttackFacing = DOWN;
    private boolean enemyAttackHitApplied = false;
    private float enemyDeathTimer = 0f;
    private float enemyRespawnTimer = 0f;
    private float enemyAnimClock = 0f;
    private float playerInvuln = 0f;
    private float playerHurtFlash = 0f;
    private float playerKnockX = 0f, playerKnockY = 0f;
    private boolean playerDown = false;
    private float playerDownTimer = 0f;
    private String combatText = "";
    private float combatTextTimer = 0f;
    private float combatTextX = 0f, combatTextY = 0f;
    private boolean combatTextCrit = false;

    // v1.7 authored contract: 256x256 cells, wider 512x256 combo cells; feet at (width/2,232).
    private static final String[] DIRECTIONS = {"down", "up", "left", "right"};
    private static final int CHARACTER_CELL = 256;
    private static final float CHARACTER_PIVOT_X = 128f;
    private static final float CHARACTER_PIVOT_Y = 232f;
    private static final float PLAYER_BODY_PIXELS = 174f;
    private static final float ENEMY_BODY_PIXELS = 168f;
    private static final float WALK_RUN_THRESHOLD = 0.65f;
    private static final float[] COMBO_DURATIONS = {0.38f, 0.44f, 0.54f};
    private static final float COMBO_IMPACT_START = 0.30f;
    private static final float COMBO_RECOVERY_START = 0.58f;
    private static final float[] CAST_PHASE_STARTS = {0f, 0.09f, 0.18f, 0.28f, 0.38f};
    private static final float CAST_DURATION = 0.50f;
    // Authored glove/energy sockets in each 256px cast cell: DOWN, UP, LEFT, RIGHT.
    private static final float[][][] CAST_HAND_SOCKETS = {
            {{167.39f, 174.28f}, {172.46f, 128.26f}, {148.28f, 138.40f},
                    {159.98f, 178.18f}, {167.00f, 174.28f}},
            {{166.22f, 153.22f}, {172.07f, 109.54f}, {173.24f, 69.76f},
                    {159.59f, 76.78f}, {172.46f, 153.22f}},
            {{110.06f, 175.06f}, {97.58f, 120.46f}, {71.45f, 117.34f},
                    {80.03f, 125.14f}, {106.16f, 175.06f}},
            {{159.98f, 173.50f}, {164.27f, 133.72f}, {184.16f, 123.58f},
                    {187.28f, 132.16f}, {159.98f, 172.72f}}
    };
    private static final float ENEMY_ATTACK_DURATION = 0.44f;
    private static final float ENEMY_ATTACK_HIT_TIME = 0.22f;
    private static final float ENEMY_HURT_DURATION = 0.28f;
    private static final float ENEMY_DEATH_DURATION = 0.70f;
    private static final float ORB_IMPACT_DURATION = 0.24f;
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
        // v1.7 uses painterly RGBA artwork; filtered scaling matches the enemy renderer.
        pixelPaint.setFilterBitmap(true);
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

    private Bitmap[] loadCharacterSequence(Context c, String prefix, int count) {
        Bitmap[] frames = loadSequence(c, prefix, count);
        int expectedWidth = prefix.startsWith("kael_v17/combo/") ? 512 : CHARACTER_CELL;
        for (Bitmap frame : frames) {
            if (frame.getWidth() != expectedWidth || frame.getHeight() != CHARACTER_CELL) {
                throw new IllegalStateException("Invalid " + expectedWidth + "x256 animation cell: " + prefix);
            }
        }
        return frames;
    }

    private RectF rectWithAuthoredPivot(Bitmap frame, float worldX, float worldY, float scale) {
        float left = worldX - frame.getWidth() * 0.5f * scale;
        float top = worldY - CHARACTER_PIVOT_Y * scale;
        return new RectF(left, top, left + frame.getWidth() * scale,
                top + frame.getHeight() * scale);
    }

    private void loadFrames(Context c) {
        for (int dir = 0; dir < DIRECTIONS.length; dir++) {
            String direction = DIRECTIONS[dir];
            idle[dir] = loadCharacterSequence(c, "kael_v17/idle/" + direction + "_", 4);
            walk[dir] = loadCharacterSequence(c, "kael_v17/walk/" + direction + "_", 6);
            run[dir] = loadCharacterSequence(c, "kael_v17/run/" + direction + "_", 6);
            magicCastFrames[dir] = loadCharacterSequence(c, "kael_v17/cast/" + direction + "_", 5);
            enemyIdleFrames[dir] = loadCharacterSequence(c, "enemy_v17/idle/" + direction + "_", 3);
            enemyChaseFrames[dir] = loadCharacterSequence(c, "enemy_v17/chase/" + direction + "_", 4);
            enemyAttackFrames[dir] = loadCharacterSequence(c, "enemy_v17/attack/" + direction + "_", 4);
        }
        Bitmap[][][] combos = {comboDown, comboUp, comboLeft, comboRight};
        for (int dir = 0; dir < DIRECTIONS.length; dir++) {
            for (int stage = 0; stage < 3; stage++) {
                combos[dir][stage] = loadCharacterSequence(c,
                        "kael_v17/combo/" + DIRECTIONS[dir] + "_c" + (stage + 1) + "_", 3);
            }
        }
        enemyHurtFrames = loadCharacterSequence(c, "enemy_v17/hurt_", 3);
        enemyDeathFrames = loadCharacterSequence(c, "enemy_v17/death_", 5);
        magicOrbFrames = loadSequence(c, "fx_v17/orb_", 8);
        for (Bitmap frame : magicOrbFrames) {
            if (frame.getWidth() != 160 || frame.getHeight() != 160) {
                throw new IllegalStateException("Invalid 160x160 Arcana orb cell");
            }
        }
        Log.i("VEILBREAKERS_ASSETS", "v1.7 loaded: kael_v17=120 enemy_v17=52 fx_v17=8; "
                + "character cells=256x256/512x256 pivot=width/2,232; orb cells=160 pivot=80,80");
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

        joyBase = load(c, "ui_v13/joystick_base.png");
        joyBaseActive = load(c, "ui_v13/joystick_base_active.png");
        joyKnob = load(c, "ui_v13/joystick_knob.png");
        joyKnobPressed = load(c, "ui_v13/joystick_knob_pressed.png");
        joyGlow = load(c, "ui_v13/joystick_glow.png");
        attackBtnNormal = load(c, "ui_v13/attack_normal.png");
        attackBtnPressed = load(c, "ui_v13/attack_pressed.png");
        attackBtnCombo = load(c, "ui_v13/attack_combo_ready.png");
        attackBtnDisabled = load(c, "ui_v13/attack_disabled.png");
        attackBtnFlash = load(c, "ui_v13/attack_flash.png");
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
        if (enemyX < 0f) {
            enemyX = w * 0.69f;
            enemyY = h * 0.53f;
        }
    }

    @Override
    protected void onDraw(Canvas c) {
        super.onDraw(c);
        if (artReviewMode) {
            drawArtReview(c);
            if (artReviewFrame < 0) postInvalidateOnAnimation();
            return;
        }
        long now = System.nanoTime();
        float dt = Math.min(0.032f, (now - lastNs) / 1_000_000_000f);
        lastNs = now;

        update(dt);
        drawArena(c);
        if (enemyAlive || enemyDeathTimer > 0f) {
            if (enemyY < py) {
                drawEnemy(c);
                drawPlayer(c);
            } else {
                drawPlayer(c);
                drawEnemy(c);
            }
        } else {
            drawPlayer(c);
        }
        drawMagic(c);
        drawCombatFeedback(c);
        drawHud(c);
        if (!statusOpen && statusAnim < 0.02f) drawControls(c);
        drawStatusOverlay(c);
        drawLevelUpFlash(c);

        postInvalidateOnAnimation();
    }

    /** Fixed-frame renderer for adb captures; never runs combat or writes a save. */
    public void setArtReview(String state, int direction, int frame) {
        if ((getContext().getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
            throw new IllegalStateException("Art review requires a debug APK");
        }
        artReviewMode = true;
        artReviewState = state == null ? "idle" : state;
        artReviewDirection = Math.max(DOWN, Math.min(RIGHT, direction));
        artReviewFrame = frame;
        artReviewStartNs = System.nanoTime();
        Log.i("VEILBREAKERS_REVIEW", artReviewState + " direction=" + artReviewDirection
                + " frame=" + artReviewFrame);
        invalidate();
    }

    private int currentArtReviewFrame() {
        if (artReviewFrame >= 0) return artReviewFrame;
        float elapsed = (System.nanoTime() - artReviewStartNs) / 1_000_000_000f;
        if (artReviewState.startsWith("combo")) {
            int stage = "combo2".equals(artReviewState) ? 1 : ("combo3".equals(artReviewState) ? 2 : 0);
            float progress = (elapsed % COMBO_DURATIONS[stage]) / COMBO_DURATIONS[stage];
            return progress < COMBO_IMPACT_START ? 0 : (progress < COMBO_RECOVERY_START ? 1 : 2);
        }
        if ("cast".equals(artReviewState)) {
            float phaseTime = elapsed % CAST_DURATION;
            for (int phase = 4; phase >= 0; phase--) {
                if (phaseTime >= CAST_PHASE_STARTS[phase]) return phase;
            }
        }
        if ("orb".equals(artReviewState)) {
            float[] durations = {0.05f, 0.04f, 0.10f, 0.08f, 0.10f, 0.10f, 0.11f, 0.13f};
            float time = elapsed % 0.71f;
            for (int phase = 0; phase < durations.length; phase++) {
                if (time < durations[phase]) return phase;
                time -= durations[phase];
            }
            return 7;
        }
        float fps = "walk".equals(artReviewState) ? 9f : ("run".equals(artReviewState) ? 12f : 5f);
        int count = "walk".equals(artReviewState) || "run".equals(artReviewState) ? 6 : 4;
        if ("enemy_idle".equals(artReviewState)) { fps = 4f; count = 3; }
        else if ("enemy_chase".equals(artReviewState)) { fps = 8f; count = 4; }
        else if ("enemy_attack".equals(artReviewState)) { fps = 4f / ENEMY_ATTACK_DURATION; count = 4; }
        else if ("hurt".equals(artReviewState)) { fps = 3f / ENEMY_HURT_DURATION; count = 3; }
        else if ("death".equals(artReviewState)) { fps = 5f / ENEMY_DEATH_DURATION; count = 5; }
        return ((int)(elapsed * fps)) % count;
    }

    private void drawArtReview(Canvas c) {
        int frame = currentArtReviewFrame();
        facing = attackFacing = magicFacing = artReviewDirection;
        enemyFacing = enemyAttackFacing = artReviewDirection;
        px = getWidth() * 0.33f;
        py = getHeight() * 0.68f;
        enemyX = getWidth() * 0.67f;
        enemyY = py;
        vx = vy = enemyVx = enemyVy = 0f;
        idleClock = runClock = enemyAnimClock = 0f;
        attacking = magicCasting = magicActive = magicReleased = false;
        enemyAlive = true;
        enemyHurtTimer = enemyDeathTimer = enemyAttackAnim = magicImpactTimer = 0f;
        playerHurtFlash = 0f;

        if ("idle".equals(artReviewState)) {
            idleClock = frame % 4 + 0.01f;
        } else if ("walk".equals(artReviewState) || "run".equals(artReviewState)) {
            float speedRatio = "walk".equals(artReviewState) ? 0.40f : 0.90f;
            vx = getHeight() * 0.39f * stats.moveMultiplier() * speedRatio;
            runClock = frame % 6 + 0.01f;
        } else if (artReviewState.startsWith("combo")) {
            comboStage = "combo2".equals(artReviewState) ? 1 : ("combo3".equals(artReviewState) ? 2 : 0);
            float[] poseCenters = {0.15f, 0.44f, 0.79f};
            attackClock = COMBO_DURATIONS[comboStage] * poseCenters[frame % 3];
            attacking = true;
        } else if ("cast".equals(artReviewState)) {
            int pose = frame % 5;
            float end = pose == 4 ? CAST_DURATION : CAST_PHASE_STARTS[pose + 1];
            magicCastClock = (CAST_PHASE_STARTS[pose] + end) * 0.5f;
            magicCasting = true;
            magicReleased = pose >= 3;
        } else if ("enemy_idle".equals(artReviewState)) {
            enemyAnimClock = (frame % 3 + 0.01f) / 4f;
        } else if ("enemy_chase".equals(artReviewState)) {
            enemyVx = getHeight() * 0.175f;
            enemyAnimClock = (frame % 4 + 0.01f) / 8f;
        } else if ("enemy_attack".equals(artReviewState)) {
            enemyAttackAnim = ENEMY_ATTACK_DURATION * (1f - (frame % 4 + 0.5f) / 4f);
        } else if ("hurt".equals(artReviewState)) {
            enemyHurtTimer = ENEMY_HURT_DURATION * (1f - (frame % 3 + 0.5f) / 3f);
        } else if ("death".equals(artReviewState)) {
            enemyAlive = false;
            enemyDeathTimer = ENEMY_DEATH_DURATION * (1f - (frame % 5 + 0.5f) / 5f);
        }
        drawArena(c);
        overlayPaint.setColor(Color.argb(140, 126, 47, 58));
        c.drawLine(getWidth() * 0.15f, py, getWidth() * 0.85f, py, overlayPaint);
        drawPlayer(c);
        drawEnemy(c);
        if ("orb".equals(artReviewState)) {
            drawOrb(c, frame % 8, getWidth() * 0.5f, py - getHeight() * 0.10f,
                    getHeight() * 0.105f, 255);
        } else {
            drawMagic(c);
        }
        drawSmallValue(c, "ART REVIEW  " + artReviewState + "  "
                        + DIRECTIONS[artReviewDirection] + "  frame " + frame,
                getWidth() * 0.5f, getHeight() * 0.10f, getHeight() * 0.030f, Paint.Align.CENTER);
        drawSmallValue(c, "v1.7  |  fixed pivot centerX,232  |  scale preserved across states",
                getWidth() * 0.5f, getHeight() * 0.15f, getHeight() * 0.022f, Paint.Align.CENTER);
    }

    private void update(float dt) {
        float targetStatus = statusOpen ? 1f : 0f;
        statusAnim += (targetStatus - statusAnim) * (1f - (float) Math.exp(-12f * dt));
        if (levelUpFlash > 0f) levelUpFlash = Math.max(0f, levelUpFlash - dt);
        // Opening status pauses combat, cooldowns, Mana and every spell lifecycle clock.
        if (statusOpen) {
            vx *= Math.max(0f, 1f - dt * 10f);
            vy *= Math.max(0f, 1f - dt * 10f);
            return;
        }
        if (playerInvuln > 0f) playerInvuln = Math.max(0f, playerInvuln - dt);
        if (playerHurtFlash > 0f) playerHurtFlash = Math.max(0f, playerHurtFlash - dt);
        if (combatTextTimer > 0f) combatTextTimer = Math.max(0f, combatTextTimer - dt);
        if (attackButtonFlash > 0f) attackButtonFlash = Math.max(0f, attackButtonFlash - dt);
        if (magicCooldown > 0f) magicCooldown = Math.max(0f, magicCooldown - dt);
        if (manaRegenDelay > 0f) {
            manaRegenDelay = Math.max(0f, manaRegenDelay - dt);
        } else if (!playerDown && stats.mana < stats.maxMana) {
            manaRegenBank += dt * 6.0f;
            int recovered = (int) manaRegenBank;
            if (recovered > 0) {
                manaRegenBank -= recovered;
                stats.mana = Math.min(stats.maxMana, stats.mana + recovered);
            }
        }
        updateMagic(dt);
        if (!attacking && comboGrace > 0f) {
            comboGrace = Math.max(0f, comboGrace - dt);
            if (comboGrace <= 0f) comboStage = 0;
        }

        if (playerDown) {
            playerDownTimer -= dt;
            vx *= Math.max(0f, 1f - dt * 12f);
            vy *= Math.max(0f, 1f - dt * 12f);
            if (playerDownTimer <= 0f) resetAfterDefeat();
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

        if (magicCasting) {
            float castDrag = 1f - (float) Math.exp(-13f * dt);
            vx += (0f - vx) * castDrag;
            vy += (0f - vy) * castDrag;
            px += vx * dt * 0.12f;
            py += vy * dt * 0.12f;
        } else if (attacking) {
            attackClock += dt;
            if (!attackHitApplied && currentComboVisualFrame() == 1) {
                checkPlayerAttackHit();
            }
            float attackDrag = 1f - (float) Math.exp(-(9.5f + comboStage * 1.2f) * dt);
            vx += (0f - vx) * attackDrag;
            vy += (0f - vy) * attackDrag;

            // Small controlled step instead of the sliding/teleport-like lunge seen in testing.
            float lunge = getHeight() * (0.010f + comboStage * 0.004f) * dt;
            if (attackFacing == LEFT) px -= lunge;
            else if (attackFacing == RIGHT) px += lunge;
            else if (attackFacing == UP) py -= lunge;
            else py += lunge;

            px += vx * dt * 0.32f;
            py += vy * dt * 0.32f;

            if (attackClock >= COMBO_DURATIONS[comboStage]) {
                if (comboQueued && comboStage < 2) {
                    comboStage++;
                    comboQueued = false;
                    attackClock = 0f;
                    attackHitApplied = false;
                    attackFacing = facing;
                    attackButtonFlash = 0.16f;
                } else {
                    attacking = false;
                    attackClock = 0f;
                    attackHitApplied = false;
                    comboQueued = false;
                    comboGrace = comboStage < 2 ? 0.30f : 0.16f;
                }
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
                runClock += dt * (speedRatio < WALK_RUN_THRESHOLD ? 9f : 12f);
            } else {
                idleClock += dt * 5f;
            }
        }

        px += playerKnockX * dt;
        py += playerKnockY * dt;
        playerKnockX *= (float) Math.exp(-10f * dt);
        playerKnockY *= (float) Math.exp(-10f * dt);

        updateEnemy(dt);

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
        if (statusOpen || playerDown || magicCasting) return;

        // Tapping during a swing buffers the next hit instead of restarting the same slap.
        if (attacking) {
            if (comboStage < 2 && currentComboVisualFrame() >= 1) {
                comboQueued = true;
                attackButtonFlash = 0.12f;
                haptic();
            }
            return;
        }

        if (comboGrace > 0f && comboStage < 2) comboStage++;
        else comboStage = 0;

        attacking = true;
        comboQueued = false;
        comboGrace = 0f;
        attackClock = 0f;
        attackHitApplied = false;
        attackFacing = facing;
        attackButtonFlash = 0.10f;
        haptic();
    }

    private int currentComboVisualFrame() {
        float progress = attackClock / COMBO_DURATIONS[comboStage];
        if (progress < COMBO_IMPACT_START) return 0;
        if (progress < COMBO_RECOVERY_START) return 1;
        return 2;
    }

    private int currentCastFrame() {
        for (int phase = CAST_PHASE_STARTS.length - 1; phase >= 0; phase--) {
            if (magicCastClock >= CAST_PHASE_STARTS[phase]) return phase;
        }
        return 0;
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
        if (magicCasting) {
            frame = magicCastFrames[magicFacing][currentCastFrame()];
        } else if (attacking) {
            Bitmap[][][] combos = {comboDown, comboUp, comboLeft, comboRight};
            frame = combos[attackFacing][comboStage][currentComboVisualFrame()];
        } else {
            float maxSpeed = getHeight() * 0.39f * stats.moveMultiplier();
            float speedRatio = Math.min(1f, (float) Math.hypot(vx, vy) / Math.max(1f, maxSpeed));
            if (speedRatio > 0.08f) {
                Bitmap[] cycle = speedRatio < WALK_RUN_THRESHOLD ? walk[facing] : run[facing];
                frame = cycle[((int) Math.floor(runClock)) % cycle.length];
            } else {
                frame = idle[facing][((int) Math.floor(idleClock)) % idle[facing].length];
            }
        }
        // Constant body scale and authored pivot: VFX bounds never move or resize Kael.
        float scale = getHeight() * 0.205f / PLAYER_BODY_PIXELS;
        RectF dst = rectWithAuthoredPivot(frame, px, py, scale);

        float shadowW = getHeight() * 0.085f;
        float shadowH = getHeight() * 0.020f;
        c.drawOval(new RectF(px - shadowW, py - shadowH * 0.3f, px + shadowW, py + shadowH), shadowPaint);
        if (playerHurtFlash > 0f && ((int)(playerHurtFlash * 35f) % 2 == 0)) {
            pixelPaint.setAlpha(105);
        }
        c.drawBitmap(frame, null, dst, pixelPaint);
        pixelPaint.setAlpha(255);
    }

    // ---------------- Combat prototype ----------------
    private void updateEnemy(float dt) {
        enemyAnimClock += dt;
        if (enemyHurtTimer > 0f) enemyHurtTimer = Math.max(0f, enemyHurtTimer - dt);

        if (!enemyAlive) {
            if (enemyDeathTimer > 0f) {
                enemyDeathTimer = Math.max(0f, enemyDeathTimer - dt);
            } else {
                enemyRespawnTimer -= dt;
                if (enemyRespawnTimer <= 0f) respawnEnemy();
            }
            return;
        }

        enemyAttackCooldown -= dt;
        enemyX += enemyKnockX * dt;
        enemyY += enemyKnockY * dt;
        enemyKnockX *= (float) Math.exp(-8.5f * dt);
        enemyKnockY *= (float) Math.exp(-8.5f * dt);

        float dx = px - enemyX;
        float dy = py - enemyY;
        float dist = Math.max(1f, (float) Math.hypot(dx, dy));
        if (enemyAttackAnim <= 0f) {
            enemyFacing = Math.abs(dx) > Math.abs(dy)
                    ? (dx < 0f ? LEFT : RIGHT) : (dy < 0f ? UP : DOWN);
        }

        if (enemyAttackAnim > 0f) {
            enemyAttackAnim = Math.max(0f, enemyAttackAnim - dt);
            float elapsed = ENEMY_ATTACK_DURATION - enemyAttackAnim;
            if (!enemyAttackHitApplied && elapsed >= ENEMY_ATTACK_HIT_TIME) {
                enemyAttackHitApplied = true;
                if (enemyHurtTimer <= 0f) applyEnemyAttackHit();
            }
            enemyVx *= Math.max(0f, 1f - dt * 9f);
            enemyVy *= Math.max(0f, 1f - dt * 9f);
        } else if (enemyHurtTimer <= 0f && dist > getHeight() * 0.115f) {
            float chaseSpeed = getHeight() * 0.175f;
            float blend = 1f - (float) Math.exp(-8f * dt);
            enemyVx += (dx / dist * chaseSpeed - enemyVx) * blend;
            enemyVy += (dy / dist * chaseSpeed - enemyVy) * blend;
            enemyX += enemyVx * dt;
            enemyY += enemyVy * dt;
        } else {
            enemyVx *= Math.max(0f, 1f - dt * 9f);
            enemyVy *= Math.max(0f, 1f - dt * 9f);
            if (enemyHurtTimer <= 0f && dist <= getHeight() * 0.115f
                    && enemyAttackCooldown <= 0f) {
                enemyAttackFacing = enemyFacing;
                enemyAttackAnim = ENEMY_ATTACK_DURATION;
                enemyAttackHitApplied = false;
                enemyAttackCooldown = 1.10f;
            }
        }

        float margin = getHeight() * 0.09f;
        enemyX = clamp(enemyX, margin, getWidth() - margin);
        enemyY = clamp(enemyY, getHeight() * 0.16f, getHeight() * 0.86f);
    }

    private void applyEnemyAttackHit() {
        if (playerInvuln > 0f || playerDown) return;
        float dx = px - enemyX;
        float dy = py - enemyY;
        float range = getHeight() * 0.145f;
        float dist = (float) Math.hypot(dx, dy);
        float forward, sideways;
        if (enemyAttackFacing == LEFT || enemyAttackFacing == RIGHT) {
            forward = dx * (enemyAttackFacing == LEFT ? -1f : 1f);
            sideways = Math.abs(dy);
        } else {
            forward = dy * (enemyAttackFacing == UP ? -1f : 1f);
            sideways = Math.abs(dx);
        }
        // Recheck the locked attack direction at impact; moving away can evade the strike.
        if (dist > range || forward < 0f || sideways > forward * 1.35f + range * 0.15f) return;

        int damage = Math.max(1, enemyAttack - Math.max(0, stats.defense / 2));
        stats.hp = Math.max(0, stats.hp - damage);
        playerInvuln = 0.72f;
        playerHurtFlash = 0.24f;
        float safeDist = Math.max(1f, dist);
        playerKnockX = dx / safeDist * getHeight() * 0.42f;
        playerKnockY = dy / safeDist * getHeight() * 0.42f;
        showCombatText("-" + damage + " HP", px, py - getHeight() * 0.08f, false);
        haptic();
        if (stats.hp <= 0) {
            playerDown = true;
            playerDownTimer = 1.35f;
            attacking = false;
            comboQueued = false;
            comboGrace = 0f;
            magicCasting = false;
            magicActive = false;
        }
        saveState();
    }

    private void checkPlayerAttackHit() {
        // Consume this strike when its authored impact pose begins, even when it misses.
        attackHitApplied = true;
        if (!enemyAlive) return;
        float dx = enemyX - px;
        float dy = enemyY - py;
        float range = getHeight() * 0.19f * (1f + comboStage * 0.08f);
        boolean inFront = false;
        if (attackFacing == DOWN) inFront = dy > -range * 0.15f && dy < range && Math.abs(dx) < range * 0.72f;
        else if (attackFacing == UP) inFront = dy < range * 0.15f && dy > -range && Math.abs(dx) < range * 0.72f;
        else if (attackFacing == LEFT) inFront = dx < range * 0.15f && dx > -range && Math.abs(dy) < range * 0.72f;
        else if (attackFacing == RIGHT) inFront = dx > -range * 0.15f && dx < range && Math.abs(dy) < range * 0.72f;

        if (!inFront) return;
        int damage = Math.max(1, stats.attack - enemyDefense / 2);
        float comboDamage = comboStage == 0 ? 1.00f : (comboStage == 1 ? 1.28f : 1.68f);
        damage = Math.max(1, Math.round(damage * comboDamage));
        boolean crit = Math.random() * 100.0 < stats.crit;
        if (crit) damage = Math.max(damage + 1, Math.round(damage * 1.75f));

        enemyHp = Math.max(0, enemyHp - damage);
        enemyHurtTimer = ENEMY_HURT_DURATION;
        enemyAttackAnim = 0f;
        enemyAttackHitApplied = true;
        float dist = Math.max(1f, (float)Math.hypot(dx, dy));
        float knock = getHeight() * (0.52f + comboStage * 0.16f);
        enemyKnockX = (dx / dist) * knock;
        enemyKnockY = (dy / dist) * knock;
        String hitLabel = comboStage == 0 ? "" : ("COMBO " + (comboStage + 1) + "  ");
        showCombatText(hitLabel + (crit ? "CRIT " : "") + damage, enemyX, enemyY - getHeight() * 0.12f, crit || comboStage == 2);
        haptic();

        if (enemyHp <= 0) {
            enemyAlive = false;
            enemyDeathTimer = ENEMY_DEATH_DURATION;
            enemyRespawnTimer = 3.0f;
            stats.money += 18;
            grantXp(35);
            showCombatText("+35 XP   +18", enemyX, enemyY - getHeight() * 0.15f, true);
        }
    }

    private void startMagic() {
        if (statusOpen || playerDown || attacking || playerHurtFlash > 0f
                || magicCasting || magicActive || magicCooldown > 0f) return;
        if (stats.mana < MAGIC_COST) {
            showCombatText("MANA INSUFICIENTE", px, py - getHeight() * 0.12f, false);
            haptic();
            return;
        }

        stats.mana -= MAGIC_COST;
        magicCooldown = MAGIC_COOLDOWN_MAX;
        manaRegenDelay = 1.40f;
        manaRegenBank = 0f;
        magicFacing = facing;
        magicCasting = true;
        magicReleased = false;
        magicCastClock = 0f;
        magicActive = false;
        magicHitApplied = false;

        showCombatText("ARCANA VIII", px, py - getHeight() * 0.14f, true);
        saveState();
        haptic();
    }

    private void launchMagicProjectile() {
        magicReleased = true;
        magicActive = true;
        magicHitApplied = false;
        magicLife = 0.92f;
        magicAge = 0f;

        float speed = getHeight() * 0.86f;
        magicX = castSocketWorldX(3);
        magicY = castSocketWorldY(3);
        magicVx = 0f;
        magicVy = 0f;
        if (magicFacing == LEFT) magicVx = -speed;
        else if (magicFacing == RIGHT) magicVx = speed;
        else if (magicFacing == UP) magicVy = -speed;
        else magicVy = speed;
    }

    private float castSocketWorldX(int phase) {
        float scale = getHeight() * 0.205f / PLAYER_BODY_PIXELS;
        return px + (CAST_HAND_SOCKETS[magicFacing][phase][0] - CHARACTER_PIVOT_X) * scale;
    }

    private float castSocketWorldY(int phase) {
        float scale = getHeight() * 0.205f / PLAYER_BODY_PIXELS;
        return py + (CAST_HAND_SOCKETS[magicFacing][phase][1] - CHARACTER_PIVOT_Y) * scale;
    }

    private void updateMagic(float dt) {
        if (magicImpactTimer > 0f) magicImpactTimer = Math.max(0f, magicImpactTimer - dt);
        float projectileDt = dt;

        if (magicCasting) {
            magicCastClock += dt;
            if (!magicReleased && magicCastClock >= CAST_PHASE_STARTS[3]) {
                launchMagicProjectile();
                // The projectile only moves for the time elapsed since the release boundary.
                projectileDt = Math.max(0f, magicCastClock - CAST_PHASE_STARTS[3]);
            }
            if (magicCastClock >= CAST_DURATION) magicCasting = false;
        }

        if (!magicActive) return;
        magicLife -= projectileDt;
        magicAge += projectileDt;
        magicX += magicVx * projectileDt;
        magicY += magicVy * projectileDt;

        if (!magicHitApplied && enemyAlive) {
            float hitR = getHeight() * 0.085f;
            float dx = enemyX - magicX;
            // Aim collision at the visible torso, using the same authored body scale as rendering.
            float dy = enemyY - getHeight() * 0.095f - magicY;
            if (dx * dx + dy * dy <= hitR * hitR) {
                magicHitApplied = true;
                int damage = Math.max(8, Math.round(stats.attack * 1.55f) - enemyDefense / 2);
                boolean crit = Math.random() * 100.0 < stats.crit;
                if (crit) damage = Math.max(damage + 1, Math.round(damage * 1.65f));

                enemyHp = Math.max(0, enemyHp - damage);
                enemyHurtTimer = ENEMY_HURT_DURATION;
                enemyAttackAnim = 0f;
                enemyAttackHitApplied = true;
                float speedLen = Math.max(1f, (float) Math.hypot(magicVx, magicVy));
                float knock = getHeight() * 0.72f;
                enemyKnockX = magicVx / speedLen * knock;
                enemyKnockY = magicVy / speedLen * knock;
                showCombatText((crit ? "ARCANA CRIT " : "ARCANA ") + damage,
                        enemyX, enemyY - getHeight() * 0.13f, true);
                haptic();

                if (enemyHp <= 0) {
                    enemyAlive = false;
                    enemyDeathTimer = ENEMY_DEATH_DURATION;
                    enemyRespawnTimer = 3.0f;
                    stats.money += 18;
                    grantXp(35);
                    showCombatText("+35 XP   +18", enemyX, enemyY - getHeight() * 0.15f, true);
                }
                magicImpactX = magicX;
                magicImpactY = magicY;
                magicImpactTimer = ORB_IMPACT_DURATION;
                magicImpactIsHit = true;
                magicActive = false;
            }
        }

        float margin = getHeight() * 0.05f;
        if (magicActive && (magicLife <= 0f || magicX < -margin || magicX > getWidth() + margin
                || magicY < -margin || magicY > getHeight() + margin)) {
            magicActive = false;
            magicImpactX = magicX;
            magicImpactY = magicY;
            magicImpactTimer = 0.13f;
            magicImpactIsHit = false;
        }
    }

    private void drawOrb(Canvas c, int index, float x, float y, float canvasHeight, int alpha) {
        Bitmap orb = magicOrbFrames[index];
        float scale = canvasHeight / 160f;
        RectF dst = new RectF(x - 80f * scale, y - 80f * scale,
                x + 80f * scale, y + 80f * scale);
        imagePaint.setAlpha(alpha);
        c.drawBitmap(orb, null, dst, imagePaint);
        imagePaint.setAlpha(255);
    }

    private void drawMagic(Canvas c) {
        // Birth, formation and concentration happen beside the casting hand before release.
        if (magicCasting && !magicReleased && magicCastClock >= CAST_PHASE_STARTS[1]) {
            int orbIndex = magicCastClock < 0.14f ? 0
                    : (magicCastClock < CAST_PHASE_STARTS[2] ? 1 : 2);
            int phase = currentCastFrame();
            float x = castSocketWorldX(phase);
            float y = castSocketWorldY(phase);
            drawOrb(c, orbIndex, x, y, getHeight() * 0.090f, 255);
        }
        if (magicActive) {
            int orbIndex = magicAge < 0.08f ? 3 : (4 + (((int)(magicAge * 10f)) & 1));
            drawOrb(c, orbIndex, magicX, magicY, getHeight() * 0.105f, 255);
        }
        if (magicImpactTimer > 0f) {
            boolean impact = magicImpactIsHit && magicImpactTimer > 0.13f;
            int alpha = impact ? 255 : Math.round(255f * clamp(magicImpactTimer / 0.13f, 0f, 1f));
            drawOrb(c, impact ? 6 : 7, magicImpactX, magicImpactY,
                    getHeight() * 0.140f, alpha);
        }
    }

    private void respawnEnemy() {
        enemyAlive = true;
        enemyHp = enemyMaxHp;
        enemyX = getWidth() * 0.70f;
        enemyY = getHeight() * 0.54f;
        enemyVx = enemyVy = enemyKnockX = enemyKnockY = 0f;
        enemyAttackCooldown = 0.85f;
        enemyHurtTimer = 0f;
        enemyDeathTimer = 0f;
        enemyAttackAnim = 0f;
        enemyAttackHitApplied = false;
        enemyFacing = DOWN;
        enemyAttackFacing = DOWN;
    }

    private void resetAfterDefeat() {
        playerDown = false;
        magicCasting = false;
        magicReleased = false;
        magicActive = false;
        magicImpactTimer = 0f;
        stats.hp = stats.maxHp;
        stats.mana = stats.maxMana;
        px = getWidth() * 0.50f;
        py = getHeight() * 0.52f;
        vx = vy = playerKnockX = playerKnockY = 0f;
        respawnEnemy();
        showCombatText("RESPAWN", px, py - getHeight() * 0.12f, false);
        saveState();
    }

    private void showCombatText(String text, float x, float y, boolean crit) {
        combatText = text;
        combatTextX = x;
        combatTextY = y;
        combatTextTimer = 0.95f;
        combatTextCrit = crit;
    }

    private void drawEnemy(Canvas c) {
        if (!enemyAlive && enemyDeathTimer <= 0f) return;

        Bitmap frame;
        if (!enemyAlive) {
            float p = 1f - clamp(enemyDeathTimer / ENEMY_DEATH_DURATION, 0f, 1f);
            int idx = Math.min(enemyDeathFrames.length - 1, (int)(p * enemyDeathFrames.length));
            frame = enemyDeathFrames[idx];
        } else if (enemyHurtTimer > 0f) {
            float p = 1f - clamp(enemyHurtTimer / ENEMY_HURT_DURATION, 0f, 1f);
            int idx = Math.min(enemyHurtFrames.length - 1, (int)(p * enemyHurtFrames.length));
            frame = enemyHurtFrames[idx];
        } else if (enemyAttackAnim > 0f) {
            float p = 1f - clamp(enemyAttackAnim / ENEMY_ATTACK_DURATION, 0f, 1f);
            Bitmap[] cycle = enemyAttackFrames[enemyAttackFacing];
            frame = cycle[Math.min(cycle.length - 1, (int)(p * cycle.length))];
        } else if (Math.hypot(enemyVx, enemyVy) > getHeight() * 0.02f) {
            Bitmap[] cycle = enemyChaseFrames[enemyFacing];
            frame = cycle[((int)(enemyAnimClock * 8.0f)) % cycle.length];
        } else {
            Bitmap[] cycle = enemyIdleFrames[enemyFacing];
            frame = cycle[((int)(enemyAnimClock * 4.0f)) % cycle.length];
        }
        float scale = getHeight() * 0.190f / ENEMY_BODY_PIXELS;
        RectF dst = rectWithAuthoredPivot(frame, enemyX, enemyY, scale);

        float shadowW = getHeight() * 0.070f;
        float shadowH = getHeight() * 0.016f;
        overlayPaint.setColor(Color.argb(105, 0, 0, 0));
        c.drawOval(new RectF(enemyX - shadowW, enemyY - shadowH * 0.3f,
                enemyX + shadowW, enemyY + shadowH), overlayPaint);

        if (enemyHurtTimer > 0f && ((int)(enemyHurtTimer * 45f) % 2 == 0)) imagePaint.setAlpha(150);
        c.drawBitmap(frame, null, dst, imagePaint);
        imagePaint.setAlpha(255);
        if (enemyAlive) {
            float bw = getHeight() * 0.19f;
            float bh = getHeight() * 0.018f;
            float top = enemyY - getHeight() * 0.215f;
            RectF back = new RectF(enemyX - bw * 0.5f, top, enemyX + bw * 0.5f, top + bh);
            overlayPaint.setColor(Color.argb(210, 14, 13, 18));
            c.drawRoundRect(back, bh * 0.45f, bh * 0.45f, overlayPaint);
            RectF fill = new RectF(back.left + 2f, back.top + 2f,
                    back.left + 2f + (back.width() - 4f) * (enemyHp / (float)enemyMaxHp), back.bottom - 2f);
            overlayPaint.setColor(Color.rgb(170, 34, 49));
            c.drawRoundRect(fill, bh * 0.35f, bh * 0.35f, overlayPaint);
            drawSmallValue(c, "VEILBORN WRETCH  " + enemyHp + "/" + enemyMaxHp,
                    enemyX, top - getHeight() * 0.010f, getHeight() * 0.016f, Paint.Align.CENTER);
        }
    }

    private void drawCombatFeedback(Canvas c) {
        if (playerHurtFlash > 0f) {
            overlayPaint.setColor(Color.argb((int)(80 * Math.min(1f, playerHurtFlash / 0.24f)), 150, 10, 22));
            c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);
        }
        if (combatTextTimer > 0f && !combatText.isEmpty()) {
            float rise = (1f - combatTextTimer / 0.95f) * getHeight() * 0.055f;
            float alpha = clamp(combatTextTimer / 0.30f, 0f, 1f);
            int color = combatTextCrit ? Color.rgb(255, 205, 92) : Color.rgb(244, 232, 218);
            drawSmallValueAlpha(c, combatText, combatTextX, combatTextY - rise,
                    getHeight() * (combatTextCrit ? 0.027f : 0.023f),
                    Paint.Align.CENTER, alpha, color);
        }
        if (playerDown) {
            overlayPaint.setColor(Color.argb(145, 8, 0, 3));
            c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);
            drawSmallValue(c, "DEFEATED", getWidth() * 0.5f, getHeight() * 0.48f,
                    getHeight() * 0.060f, Paint.Align.CENTER);
        }
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
        joyPointer = attackPointer = magicPointer = -1;
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
        float slideY = (1f - a) * getHeight() * 0.045f;

        overlayPaint.setColor(Color.argb((int) (210 * a), 2, 3, 6));
        c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);

        // v1.1: taller/less wide panel. Individual PNGs are fitted without distortion.
        float finalW = getWidth() * 0.76f;
        float finalH = getHeight() * 0.94f;
        float cx = getWidth() * 0.50f;
        float cy = getHeight() * 0.50f + slideY;
        float panelW = finalW * pop;
        float panelH = finalH * pop;
        RectF panel = new RectF(cx - panelW * 0.5f, cy - panelH * 0.5f,
                cx + panelW * 0.5f, cy + panelH * 0.5f);

        overlayPaint.setColor(Color.argb((int) (242 * a), 7, 8, 12));
        c.drawRoundRect(panel, getHeight() * 0.024f, getHeight() * 0.024f, overlayPaint);

        float pulse = 0.5f + 0.5f * (float) Math.sin(System.nanoTime() / 1_000_000_000.0 * 3.0);
        overlayPaint.setStyle(Paint.Style.STROKE);
        overlayPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.0042f));
        overlayPaint.setColor(Color.argb((int) ((150 + 45 * pulse) * a), 132, 28, 39));
        c.drawRoundRect(panel, getHeight() * 0.024f, getHeight() * 0.024f, overlayPaint);
        overlayPaint.setStrokeWidth(Math.max(1f, getHeight() * 0.0017f));
        overlayPaint.setColor(Color.argb((int) ((65 + 35 * pulse) * a), 245, 62, 74));
        RectF innerGlow = new RectF(panel.left + getHeight() * 0.008f, panel.top + getHeight() * 0.008f,
                panel.right - getHeight() * 0.008f, panel.bottom - getHeight() * 0.008f);
        c.drawRoundRect(innerGlow, getHeight() * 0.020f, getHeight() * 0.020f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.FILL);

        float headerReveal = revealWindow(a, 0.04f, 0.40f);
        float leftReveal = revealWindow(a, 0.12f, 0.60f);
        float rowsReveal = revealWindow(a, 0.17f, 0.70f);
        float attrReveal = revealWindow(a, 0.28f, 0.82f);
        float bottomReveal = revealWindow(a, 0.42f, 0.96f);

        RectF headerBounds = new RectF(
                panel.centerX() - panel.width() * 0.17f,
                panel.top - panel.height() * 0.015f,
                panel.centerX() + panel.width() * 0.17f,
                panel.top + panel.height() * 0.14f);
        RectF header = fitBitmapRect(statusHeader, headerBounds);
        header.offset(0f, -(1f - headerReveal) * getHeight() * 0.025f);
        drawBitmapAlpha(c, statusHeader, header, headerReveal);

        closeStatusHit.set(panel.right - getHeight() * 0.068f, panel.top + getHeight() * 0.026f,
                panel.right - getHeight() * 0.018f, panel.top + getHeight() * 0.076f);
        overlayPaint.setColor(Color.argb((int) (190 * rowsReveal), 110, 18, 28));
        c.drawRoundRect(closeStatusHit, getHeight() * 0.010f, getHeight() * 0.010f, overlayPaint);
        drawSmallValueAlpha(c, "×", closeStatusHit.centerX(),
                closeStatusHit.centerY() + getHeight() * 0.016f,
                getHeight() * 0.039f, Paint.Align.CENTER, rowsReveal, Color.rgb(245, 226, 218));

        float contentTop = panel.top + panel.height() * 0.135f;
        float leftX = panel.left + panel.width() * 0.055f;
        float leftMaxW = panel.width() * 0.235f;
        float rightX = panel.left + panel.width() * 0.355f;
        float rightMaxW = panel.width() * 0.405f;

        // LEFT COLUMN -----------------------------------------------------
        float leftOffset = (1f - leftReveal) * panel.width() * 0.035f;
        RectF portraitBounds = new RectF(
                leftX - leftOffset, contentTop,
                leftX - leftOffset + leftMaxW,
                contentTop + panel.height() * 0.315f);
        RectF portrait = fitBitmapRect(statusPortraitFrame, portraitBounds);
        drawBitmapAlpha(c, statusPortraitFrame, portrait, leftReveal);

        Bitmap kael = idle[DOWN][1];
        float portraitScale = portrait.height() * 0.70f / PLAYER_BODY_PIXELS;
        RectF kaelDst = rectWithAuthoredPivot(kael, portrait.centerX(),
                portrait.bottom - portrait.height() * 0.055f, portraitScale);
        pixelPaint.setAlpha((int) (255 * leftReveal));
        c.drawBitmap(kael, null, kaelDst, pixelPaint);
        pixelPaint.setAlpha(255);

        RectF descBounds = new RectF(
                leftX - leftOffset,
                portrait.bottom + panel.height() * 0.020f,
                leftX - leftOffset + leftMaxW,
                portrait.bottom + panel.height() * 0.185f);
        RectF desc = fitBitmapRect(statusDescFrame, descBounds);
        drawBitmapAlpha(c, statusDescFrame, desc, leftReveal);
        uiPaint.setTextAlign(Paint.Align.CENTER);
        uiPaint.setTextSize(getHeight() * 0.017f);
        uiPaint.setColor(Color.rgb(203, 196, 185));
        uiPaint.setAlpha((int) (255 * leftReveal));
        c.drawText("Kael Varyn", desc.centerX(), desc.top + desc.height() * 0.43f, uiPaint);
        c.drawText("Portador da Marca VIII", desc.centerX(), desc.top + desc.height() * 0.70f, uiPaint);
        uiPaint.setAlpha(255);
        uiPaint.setTextAlign(Paint.Align.LEFT);

        // Resource boxes now live in the left column, so the right side can breathe.
        float resourceY = desc.bottom + panel.height() * 0.028f;
        RectF apBounds = new RectF(leftX, resourceY, leftX + leftMaxW,
                resourceY + panel.height() * 0.090f);
        RectF ap = fitBitmapRect(statusAttrPoints, apBounds);
        drawBitmapAlpha(c, statusAttrPoints, ap, bottomReveal);
        drawSmallValueAlpha(c, String.valueOf(pendingPoints),
                ap.right - ap.width() * 0.090f, ap.centerY() + getHeight() * 0.008f,
                getHeight() * 0.021f, Paint.Align.RIGHT, bottomReveal, Color.rgb(255, 215, 133));

        RectF moneyBounds = new RectF(leftX, ap.bottom + panel.height() * 0.012f,
                leftX + leftMaxW, ap.bottom + panel.height() * 0.112f);
        RectF money = fitBitmapRect(statusMoney, moneyBounds);
        drawBitmapAlpha(c, statusMoney, money, bottomReveal);
        drawSmallValueAlpha(c, String.valueOf(stats.money),
                money.right - money.width() * 0.090f, money.centerY() + getHeight() * 0.008f,
                getHeight() * 0.021f, Paint.Align.RIGHT, bottomReveal, Color.rgb(255, 215, 133));

        RectF upgradeBounds = new RectF(
                leftX - panel.width() * 0.010f,
                money.bottom + panel.height() * 0.018f,
                leftX + leftMaxW + panel.width() * 0.010f,
                money.bottom + panel.height() * 0.120f);
        upgradeHit.set(fitBitmapRect(statusUpgrade, upgradeBounds));
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

        // RIGHT COLUMN ----------------------------------------------------
        Bitmap[] rowBmps = {statusHpRow, statusManaRow, statusLevelRow, statusXpRow};
        RectF[] rows = new RectF[4];
        float rowCursorY = contentTop;
        float rowGap = panel.height() * 0.012f;

        for (int i = 0; i < 4; i++) {
            float rr = revealWindow(a, 0.16f + i * 0.045f, 0.56f + i * 0.045f);
            RectF rowBounds = new RectF(
                    rightX + (1f - rr) * panel.width() * 0.035f,
                    rowCursorY,
                    rightX + rightMaxW + (1f - rr) * panel.width() * 0.035f,
                    rowCursorY + panel.height() * 0.105f);
            rows[i] = fitBitmapRect(rowBmps[i], rowBounds);
            drawBitmapAlpha(c, rowBmps[i], rows[i], rr);
            rowCursorY = rows[i].bottom + rowGap;
        }

        drawStatusMeterAlpha(c, rows[0], stats.hpRatio(), Color.rgb(205, 28, 45), rowsReveal);
        drawStatusMeterAlpha(c, rows[1], stats.manaRatio(), Color.rgb(35, 118, 232), rowsReveal);
        drawStatusMeterAlpha(c, rows[3], stats.xpRatio(), Color.rgb(151, 50, 220), rowsReveal);
        for (int i = 0; i < 4; i++) drawBitmapAlpha(c, rowBmps[i], rows[i], rowsReveal);

        drawSmallValueAlpha(c, stats.hp + " / " + stats.maxHp,
                rows[0].left + rows[0].width() * 0.61f, rows[0].centerY() + getHeight() * 0.009f,
                getHeight() * 0.019f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));
        drawSmallValueAlpha(c, stats.mana + " / " + stats.maxMana,
                rows[1].left + rows[1].width() * 0.61f, rows[1].centerY() + getHeight() * 0.009f,
                getHeight() * 0.019f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));
        drawSmallValueAlpha(c, String.valueOf(stats.level),
                rows[2].left + rows[2].width() * 0.64f, rows[2].centerY() + getHeight() * 0.009f,
                getHeight() * 0.021f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));
        drawSmallValueAlpha(c, stats.xp + " / " + stats.xpToNext,
                rows[3].left + rows[3].width() * 0.61f, rows[3].centerY() + getHeight() * 0.009f,
                getHeight() * 0.018f, Paint.Align.CENTER, rowsReveal, Color.rgb(239,229,210));

        float blockTop = rowCursorY + panel.height() * 0.010f;
        RectF blockBounds = new RectF(
                rightX + panel.width() * 0.020f,
                blockTop + (1f - attrReveal) * getHeight() * 0.018f,
                rightX + rightMaxW - panel.width() * 0.020f,
                panel.bottom - panel.height() * 0.055f);
        RectF block = fitBitmapRect(statusAttrBlock, blockBounds);
        drawBitmapAlpha(c, statusAttrBlock, block, attrReveal);

        int[] base = {stats.attack, stats.defense, stats.crit, stats.speed};
        int[] delta = {pending[0] * 2, pending[1] * 2, pending[2], pending[3] * 5};
        String[] suffix = {"", "", "%", ""};

        for (int i = 0; i < 4; i++) {
            float y0 = block.top + block.height() * (0.045f + i * 0.247f);
            float y1 = y0 + block.height() * 0.195f;
            RectF valueRect = new RectF(
                    block.left + block.width() * 0.405f, y0,
                    block.left + block.width() * 0.655f, y1);
            String preview = delta[i] > 0
                    ? base[i] + " → " + (base[i] + delta[i]) + suffix[i]
                    : base[i] + suffix[i];
            int color = delta[i] > 0 ? Color.rgb(255, 207, 118) : Color.rgb(239, 229, 210);
            drawSmallValueAlpha(c, preview, valueRect.centerX(),
                    valueRect.centerY() + getHeight() * 0.008f,
                    getHeight() * (delta[i] > 0 ? 0.018f : 0.020f),
                    Paint.Align.CENTER, attrReveal, color);

            minusHits[i].set(
                    block.left + block.width() * 0.685f, y0,
                    block.left + block.width() * 0.825f, y1);
            plusHits[i].set(
                    block.left + block.width() * 0.835f, y0,
                    block.right, y1);
        }
    }


    private RectF fitBitmapRect(Bitmap bitmap, RectF bounds) {
        float bw = Math.max(1f, bounds.width());
        float bh = Math.max(1f, bounds.height());
        float aspect = bitmap.getWidth() / (float) bitmap.getHeight();
        float w = bw;
        float h = w / aspect;
        if (h > bh) {
            h = bh;
            w = h * aspect;
        }
        float cx = bounds.centerX();
        float cy = bounds.centerY();
        return new RectF(cx - w * 0.5f, cy - h * 0.5f, cx + w * 0.5f, cy + h * 0.5f);
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
            levelUpFlash = 1.15f;
        }
        saveState();
    }

    private void drawLevelUpFlash(Canvas c) {
        if (levelUpFlash <= 0f) return;
        float fadeOut = clamp(levelUpFlash / 0.22f, 0f, 1f);
        float fadeIn = clamp((1.15f - levelUpFlash) / 0.14f, 0f, 1f);
        float a = Math.min(fadeIn, fadeOut);
        float w = getWidth() * 0.235f;
        float hh = w * levelHeader.getHeight() / (float) levelHeader.getWidth();
        RectF header = new RectF(getWidth() * 0.5f - w * 0.5f, getHeight() * 0.115f,
                getWidth() * 0.5f + w * 0.5f, getHeight() * 0.115f + hh);
        float rw = getWidth() * 0.190f;
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
    private float magicCx() { return getWidth() * 0.755f; }
    private float magicCy() { return getHeight() * 0.665f; }
    private float magicR() { return getHeight() * 0.070f; }

    private void drawControls(Canvas c) {
        float jx = joyCx(), jy = joyCy(), jr = joyR();
        boolean joyActive = joyPointer >= 0 || Math.hypot(joyX, joyY) > 0.08f;

        RectF joyBounds = new RectF(jx - jr * 1.08f, jy - jr * 1.08f, jx + jr * 1.08f, jy + jr * 1.08f);
        RectF joyDst = fitBitmapRect(joyActive ? joyBaseActive : joyBase, joyBounds);
        imagePaint.setAlpha(joyActive ? 235 : 205);
        c.drawBitmap(joyActive ? joyBaseActive : joyBase, null, joyDst, imagePaint);

        if (joyActive) {
            RectF glowBounds = new RectF(jx - jr * 1.18f, jy - jr * 1.18f, jx + jr * 1.18f, jy + jr * 1.18f);
            imagePaint.setAlpha(72);
            c.drawBitmap(joyGlow, null, fitBitmapRect(joyGlow, glowBounds), imagePaint);
        }

        float knobCx = jx + joyX * jr * 0.48f;
        float knobCy = jy + joyY * jr * 0.48f;
        float knobR = jr * 0.48f;
        Bitmap knob = joyPointer >= 0 ? joyKnobPressed : joyKnob;
        RectF knobBounds = new RectF(knobCx - knobR, knobCy - knobR, knobCx + knobR, knobCy + knobR);
        imagePaint.setAlpha(245);
        c.drawBitmap(knob, null, fitBitmapRect(knob, knobBounds), imagePaint);
        imagePaint.setAlpha(255);

        boolean disabled = playerDown || magicCasting;
        boolean pressed = attackPointer >= 0;
        boolean comboReady = !disabled && (comboQueued || comboGrace > 0f || (attacking && comboStage < 2));
        Bitmap atkButton = disabled ? attackBtnDisabled : (pressed ? attackBtnPressed : (comboReady ? attackBtnCombo : attackBtnNormal));
        float ar = atkR() * 1.18f;
        RectF atkBounds = new RectF(atkCx() - ar, atkCy() - ar, atkCx() + ar, atkCy() + ar);
        imagePaint.setAlpha(disabled ? 150 : 245);
        c.drawBitmap(atkButton, null, fitBitmapRect(atkButton, atkBounds), imagePaint);
        imagePaint.setAlpha(255);

        if (attackButtonFlash > 0f) {
            float fr = ar * 1.28f;
            RectF flashBounds = new RectF(atkCx() - fr, atkCy() - fr, atkCx() + fr, atkCy() + fr);
            imagePaint.setAlpha((int)(110 * clamp(attackButtonFlash / 0.16f, 0f, 1f)));
            c.drawBitmap(attackBtnFlash, null, fitBitmapRect(attackBtnFlash, flashBounds), imagePaint);
            imagePaint.setAlpha(255);
        }

        if (comboStage > 0 || comboQueued) {
            String label = comboQueued ? ("x" + Math.min(3, comboStage + 2)) : ("x" + (comboStage + 1));
            drawSmallValue(c, label, atkCx(), atkCy() - ar * 0.86f,
                    getHeight() * 0.016f, Paint.Align.CENTER);
        }

        // Arcana VIII button: procedural so the first spell adds no fragile binary dependency.
        float mx = magicCx(), my = magicCy(), mr = magicR();
        boolean magicDisabled = playerDown || attacking || playerHurtFlash > 0f
                || stats.mana < MAGIC_COST || magicCooldown > 0f || magicActive || magicCasting;
        boolean magicPressed = magicPointer >= 0;
        float pulse = 0.5f + 0.5f * (float)Math.sin(System.nanoTime() / 1_000_000_000.0 * 4.0);

        overlayPaint.setColor(Color.argb(magicDisabled ? 95 : (magicPressed ? 220 : 175), 31, 8, 45));
        c.drawCircle(mx, my, mr * 1.05f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.STROKE);
        overlayPaint.setStrokeWidth(Math.max(2f, getHeight() * (magicPressed ? 0.0050f : 0.0035f)));
        overlayPaint.setColor(Color.argb(magicDisabled ? 90 : (int)(185 + 55 * pulse), 178, 40, 208));
        c.drawCircle(mx, my, mr, overlayPaint);
        overlayPaint.setStrokeWidth(Math.max(1f, getHeight() * 0.0020f));
        overlayPaint.setColor(Color.argb(magicDisabled ? 65 : 190, 242, 73, 104));
        c.drawArc(new RectF(mx - mr * 0.72f, my - mr * 0.72f, mx + mr * 0.72f, my + mr * 0.72f),
                -68f, 276f, false, overlayPaint);
        overlayPaint.setStyle(Paint.Style.FILL);

        String magicLabel = magicCooldown > 0f
                ? String.format(Locale.US, "%.1f", magicCooldown)
                : "VIII";
        drawSmallValue(c, magicLabel, mx, my + getHeight() * 0.010f,
                getHeight() * 0.024f, Paint.Align.CENTER);
        drawSmallValue(c, String.valueOf(MAGIC_COST), mx, my + mr * 1.35f,
                getHeight() * 0.014f, Paint.Align.CENTER);
    }

    @Override
    public boolean onTouchEvent(MotionEvent e) {
        if (artReviewMode) return true;
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
            if (magicPointer < 0 && distance(x, y, magicCx(), magicCy()) <= magicR() * 1.55f) {
                magicPointer = pointerId;
                startMagic();
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
            if (pointerId == magicPointer || action == MotionEvent.ACTION_CANCEL) magicPointer = -1;
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
        if (artReviewMode) return;
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
