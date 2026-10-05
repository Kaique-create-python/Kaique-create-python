package com.veilbreakers.prototype;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;

import java.io.IOException;
import java.io.InputStream;

public class MainMenuView extends View {
    private static final String PREFS = "veilbreakers_save";

    private final MainActivity activity;
    private final SharedPreferences prefs;
    private final Paint imagePaint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint overlayPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private Bitmap logo;
    private Bitmap barNormal;
    private Bitmap barSelected;
    private Bitmap footer;

    private int selected = 0;
    private int pressed = -1;
    private boolean settingsOpen = false;
    private int settingsSelected = 0;
    private String statusMessage = "";
    private long statusUntilMs = 0L;

    private final RectF[] mainHit = {new RectF(), new RectF(), new RectF(), new RectF()};
    private final RectF[] settingsHit = {new RectF(), new RectF()};
    private final float[] mainScale = {1f, 1f, 1f, 1f};
    private final float[] settingsScale = {1f, 1f};

    private long lastNs = System.nanoTime();
    private float elapsed = 0f;
    private float settingsAnim = 0f;
    private float transitionProgress = 0f;
    private int transitionAction = -1;
    private boolean transitionFired = false;

    public MainMenuView(MainActivity activity) {
        super(activity);
        this.activity = activity;
        this.prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE);

        setFocusable(true);
        setFocusableInTouchMode(true);
        requestFocus();
        setKeepScreenOn(true);
        setBackgroundColor(Color.TRANSPARENT);

        textPaint.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        loadAssets(activity);
    }

    private Bitmap load(Context c, String path) {
        try (InputStream in = c.getAssets().open(path)) {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inScaled = false;
            Bitmap b = BitmapFactory.decodeStream(in, null, options);
            if (b == null) throw new IOException("Could not decode " + path);
            return b;
        } catch (IOException e) {
            throw new RuntimeException("Missing menu asset: " + path, e);
        }
    }

    private void loadAssets(Context c) {
        logo = load(c, "menu/menu_logo.png");
        barNormal = load(c, "menu/menu_bar.png");
        barSelected = load(c, "menu/menu_bar_selected.png");
        footer = load(c, "menu/menu_footer.png");
    }

    @Override
    protected void onDraw(Canvas c) {
        super.onDraw(c);
        float dt = computeDeltaSeconds();
        updateAnimations(dt);

        drawVideoTone(c);
        drawDarkLeftFade(c);

        float logoIn = smooth(clamp01((elapsed - 0.05f) / 0.50f));
        drawLogo(c, logoIn);

        float mainAlpha = 1f - settingsAnim;
        if (mainAlpha > 0.01f) drawMainMenu(c, mainAlpha);
        if (settingsAnim > 0.01f) drawSettings(c, settingsAnim);

        float footerIn = smooth(clamp01((elapsed - 0.55f) / 0.40f));
        drawFooter(c, footerIn);
        drawStatus(c);

        drawEntryFade(c);
        drawExitFade(c);

        postInvalidateOnAnimation();
    }

    private float computeDeltaSeconds() {
        long now = System.nanoTime();
        float dt = Math.min(0.05f, (now - lastNs) / 1_000_000_000f);
        lastNs = now;
        return dt;
    }

    private void updateAnimations(float dt) {
        elapsed += dt;
        float lerp = 1f - (float) Math.exp(-12f * dt);

        for (int i = 0; i < mainScale.length; i++) {
            mainScale[i] += (targetMainScaleFor(i) - mainScale[i]) * lerp;
        }
        for (int i = 0; i < settingsScale.length; i++) {
            settingsScale[i] += (targetSettingsScaleFor(i) - settingsScale[i]) * lerp;
        }

        float settingsTarget = settingsOpen ? 1f : 0f;
        settingsAnim += (settingsTarget - settingsAnim) * (1f - (float) Math.exp(-10f * dt));

        if (transitionAction >= 0) {
            transitionProgress = Math.min(1f, transitionProgress + dt / 0.28f);
            if (transitionProgress >= 1f && !transitionFired) {
                transitionFired = true;
                final int action = transitionAction;
                post(() -> performTransitionAction(action));
            }
        }
    }

    private float targetMainScaleFor(int i) {
        if (settingsOpen) return 1f;
        if (pressed == i) return 1.085f;
        if (selected == i) return 1.035f;
        return 1f;
    }

    private float targetSettingsScaleFor(int i) {
        if (!settingsOpen) return 1f;
        if (pressed == i) return 1.085f;
        if (settingsSelected == i) return 1.035f;
        return 1f;
    }

    private void drawVideoTone(Canvas c) {
        // A very light tint keeps moving video from competing with UI.
        overlayPaint.setColor(Color.argb(24, 0, 0, 0));
        c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);
    }

    private void drawDarkLeftFade(Canvas c) {
        LinearGradient gradient = new LinearGradient(
                0, 0, getWidth() * 0.62f, 0,
                new int[]{Color.argb(205, 2, 4, 7), Color.argb(126, 2, 4, 7), Color.argb(25, 2, 4, 7), Color.TRANSPARENT},
                new float[]{0f, 0.48f, 0.82f, 1f}, Shader.TileMode.CLAMP);
        overlayPaint.setShader(gradient);
        c.drawRect(0, 0, getWidth() * 0.70f, getHeight(), overlayPaint);
        overlayPaint.setShader(null);
    }

    private void drawLogo(Canvas c, float in) {
        if (in <= 0f) return;
        float w = getWidth() * 0.44f;
        float h = w * logo.getHeight() / (float) logo.getWidth();
        float x = getWidth() * 0.038f;
        float finalY = getHeight() * 0.055f;
        float y = finalY - getHeight() * 0.025f * (1f - in);

        imagePaint.setAlpha((int) (255 * in));
        c.drawBitmap(logo, null, new RectF(x, y, x + w, y + h), imagePaint);
        imagePaint.setAlpha(255);
    }

    private void drawMainMenu(Canvas c, float globalAlpha) {
        String[] labels = {"New Game", "Continue", "Settings", "Exit"};
        float x = getWidth() * 0.055f;
        float w = getWidth() * 0.31f;
        float h = getHeight() * 0.096f;
        float gap = getHeight() * 0.016f;
        float startY = getHeight() * 0.405f;

        for (int i = 0; i < labels.length; i++) {
            float y = startY + i * (h + gap);
            RectF hit = mainHit[i];
            hit.set(x, y, x + w, y + h);

            float delay = 0.25f + i * 0.075f;
            float reveal = smooth(clamp01((elapsed - delay) / 0.34f)) * globalAlpha;
            if (reveal <= 0.001f) continue;

            boolean active = i == selected || i == pressed;
            float slideX = -getWidth() * 0.018f * (1f - reveal);
            RectF drawRect = scaledRect(hit, mainScale[i], slideX);

            if (active) drawSelectionGlow(c, drawRect, reveal);

            imagePaint.setAlpha((int) (255 * reveal));
            c.drawBitmap(active ? barSelected : barNormal, null, drawRect, imagePaint);
            imagePaint.setAlpha(255);

            boolean continueDisabled = i == 1 && !prefs.getBoolean("has_save", false);
            drawButtonText(c, labels[i], drawRect, active, continueDisabled, reveal);
        }
    }

    private void drawSelectionGlow(Canvas c, RectF rect, float alpha) {
        float pulse = 0.5f + 0.5f * (float) Math.sin(elapsed * 4.0f);
        float pad = getHeight() * (0.006f + pulse * 0.003f);
        overlayPaint.setColor(Color.argb((int) (50 * alpha + 30 * pulse * alpha), 170, 18, 28));
        c.drawRoundRect(new RectF(rect.left - pad, rect.top - pad * 0.5f,
                        rect.right + pad, rect.bottom + pad * 0.5f),
                getHeight() * 0.016f, getHeight() * 0.016f, overlayPaint);
    }

    private void drawSettings(Canvas c, float a) {
        float scale = 0.965f + 0.035f * smooth(a);
        float panelLeft = getWidth() * 0.045f;
        float panelTop = getHeight() * 0.35f;
        float panelRight = getWidth() * 0.42f;
        float panelBottom = getHeight() * 0.75f;
        RectF panel = new RectF(panelLeft, panelTop, panelRight, panelBottom);
        RectF drawPanel = scaledRect(panel, scale, 0f);

        overlayPaint.setColor(Color.argb((int) (212 * a), 4, 5, 8));
        c.drawRoundRect(drawPanel, getHeight() * 0.018f, getHeight() * 0.018f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.STROKE);
        overlayPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.003f));
        overlayPaint.setColor(Color.argb((int) (165 * a), 130, 42, 48));
        c.drawRoundRect(drawPanel, getHeight() * 0.018f, getHeight() * 0.018f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.FILL);

        textPaint.setTextAlign(Paint.Align.LEFT);
        textPaint.setTextSize(getHeight() * 0.052f);
        textPaint.setColor(Color.rgb(232, 226, 218));
        textPaint.setAlpha((int) (255 * a));
        c.drawText("Settings", panelLeft + getWidth() * 0.025f,
                panelTop + getHeight() * 0.075f, textPaint);
        textPaint.setAlpha(255);

        boolean vibration = prefs.getBoolean("vibration", true);
        String[] labels = {"Vibration: " + (vibration ? "ON" : "OFF"), "Back"};
        float x = panelLeft + getWidth() * 0.018f;
        float w = panelRight - panelLeft - getWidth() * 0.036f;
        float h = getHeight() * 0.10f;
        float y0 = panelTop + getHeight() * 0.12f;
        float gap = getHeight() * 0.035f;

        for (int i = 0; i < labels.length; i++) {
            float y = y0 + i * (h + gap);
            RectF hit = settingsHit[i];
            hit.set(x, y, x + w, y + h);
            boolean active = i == settingsSelected || i == pressed;
            RectF drawRect = scaledRect(hit, settingsScale[i], 0f);
            if (active) drawSelectionGlow(c, drawRect, a);

            imagePaint.setAlpha((int) (255 * a));
            c.drawBitmap(active ? barSelected : barNormal, null, drawRect, imagePaint);
            imagePaint.setAlpha(255);
            drawButtonText(c, labels[i], drawRect, active, false, a);
        }
    }

    private RectF scaledRect(RectF base, float scale, float offsetX) {
        float cx = base.centerX() + offsetX;
        float cy = base.centerY();
        float hw = base.width() * 0.5f * scale;
        float hh = base.height() * 0.5f * scale;
        return new RectF(cx - hw, cy - hh, cx + hw, cy + hh);
    }

    private void drawButtonText(Canvas c, String label, RectF rect, boolean active,
                                boolean disabled, float alpha) {
        float textSize = getHeight() * 0.042f;
        textPaint.setTextAlign(Paint.Align.LEFT);
        textPaint.setTextSize(textSize);
        textPaint.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        textPaint.setAlpha((int) (255 * alpha));

        float x = rect.left + rect.width() * 0.16f;
        float baseline = rect.centerY() - (textPaint.ascent() + textPaint.descent()) * 0.5f;

        textPaint.setColor(Color.rgb(0, 0, 0));
        c.drawText(label, x + 2f, baseline + 2f, textPaint);

        if (disabled) textPaint.setColor(Color.rgb(118, 118, 121));
        else if (active) textPaint.setColor(Color.rgb(250, 242, 230));
        else textPaint.setColor(Color.rgb(202, 198, 194));
        c.drawText(label, x, baseline, textPaint);
        textPaint.setAlpha(255);
    }

    private void drawFooter(Canvas c, float a) {
        if (a <= 0f) return;
        float w = getWidth() * 0.90f;
        float h = w * footer.getHeight() / (float) footer.getWidth();
        float x = (getWidth() - w) * 0.5f;
        float y = getHeight() - h - getHeight() * 0.026f + getHeight() * 0.015f * (1f - a);
        imagePaint.setAlpha((int) (255 * a));
        c.drawBitmap(footer, null, new RectF(x, y, x + w, y + h), imagePaint);
        imagePaint.setAlpha(255);
    }

    private void drawStatus(Canvas c) {
        if (System.currentTimeMillis() >= statusUntilMs || statusMessage.isEmpty()) return;
        textPaint.setTextAlign(Paint.Align.LEFT);
        textPaint.setTextSize(getHeight() * 0.026f);
        textPaint.setColor(Color.rgb(226, 180, 184));
        c.drawText(statusMessage, getWidth() * 0.06f, getHeight() * 0.86f, textPaint);
    }

    private void drawEntryFade(Canvas c) {
        float fade = 1f - smooth(clamp01(elapsed / 0.52f));
        if (fade <= 0f) return;
        overlayPaint.setColor(Color.argb((int) (255 * fade), 0, 0, 0));
        c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);
    }

    private void drawExitFade(Canvas c) {
        if (transitionAction < 0) return;
        float p = smooth(transitionProgress);
        overlayPaint.setColor(Color.argb((int) (255 * p), 0, 0, 0));
        c.drawRect(0, 0, getWidth(), getHeight(), overlayPaint);
    }

    private int hitMain(float x, float y) {
        for (int i = 0; i < mainHit.length; i++) if (mainHit[i].contains(x, y)) return i;
        return -1;
    }

    private int hitSettings(float x, float y) {
        for (int i = 0; i < settingsHit.length; i++) if (settingsHit[i].contains(x, y)) return i;
        return -1;
    }

    private void activateMain(int index) {
        selected = index;
        if (index == 1 && !prefs.getBoolean("has_save", false)) {
            showStatus("No save data yet — start a New Game first.");
            return;
        }
        if (index == 2) {
            settingsOpen = true;
            settingsSelected = 0;
            pressed = -1;
            return;
        }
        beginTransition(index);
    }

    private void beginTransition(int action) {
        transitionAction = action;
        transitionProgress = 0f;
        transitionFired = false;
        pressed = -1;
    }

    private void performTransitionAction(int action) {
        if (action == 0) activity.startGame(false);
        else if (action == 1) activity.startGame(true);
        else if (action == 3) activity.exitGame();
    }

    private void executeSettings(int index) {
        settingsSelected = index;
        if (index == 0) {
            boolean value = !prefs.getBoolean("vibration", true);
            prefs.edit().putBoolean("vibration", value).apply();
        } else {
            settingsOpen = false;
            pressed = -1;
        }
    }

    private void showStatus(String message) {
        statusMessage = message;
        statusUntilMs = System.currentTimeMillis() + 2300L;
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (transitionAction >= 0 || elapsed < 0.45f) return true;

        int action = event.getActionMasked();
        float x = event.getX();
        float y = event.getY();

        if (action == MotionEvent.ACTION_DOWN) {
            pressed = settingsOpen ? hitSettings(x, y) : hitMain(x, y);
            if (pressed >= 0) {
                if (settingsOpen) settingsSelected = pressed;
                else selected = pressed;
            }
            return true;
        }

        if (action == MotionEvent.ACTION_MOVE) {
            int hover = settingsOpen ? hitSettings(x, y) : hitMain(x, y);
            if (hover != pressed) {
                pressed = hover;
                if (pressed >= 0) {
                    if (settingsOpen) settingsSelected = pressed;
                    else selected = pressed;
                }
            }
            return true;
        }

        if (action == MotionEvent.ACTION_UP) {
            int released = settingsOpen ? hitSettings(x, y) : hitMain(x, y);
            if (released >= 0) {
                if (settingsOpen) executeSettings(released);
                else activateMain(released);
            }
            pressed = -1;
            return true;
        }

        if (action == MotionEvent.ACTION_CANCEL) {
            pressed = -1;
            return true;
        }
        return true;
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (transitionAction >= 0) return true;
        if (keyCode == KeyEvent.KEYCODE_DPAD_UP) {
            if (settingsOpen) settingsSelected = (settingsSelected + 1) % 2;
            else selected = (selected + 3) % 4;
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN) {
            if (settingsOpen) settingsSelected = (settingsSelected + 1) % 2;
            else selected = (selected + 1) % 4;
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_ENTER || keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_BUTTON_A) {
            if (settingsOpen) executeSettings(settingsSelected);
            else activateMain(selected);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_BACK) return handleBack();
        return super.onKeyDown(keyCode, event);
    }

    public boolean handleBack() {
        if (transitionAction >= 0) return true;
        if (settingsOpen) {
            settingsOpen = false;
            pressed = -1;
            return true;
        }
        return false;
    }

    private float clamp01(float v) {
        return Math.max(0f, Math.min(1f, v));
    }

    private float smooth(float v) {
        v = clamp01(v);
        return v * v * (3f - 2f * v);
    }
}