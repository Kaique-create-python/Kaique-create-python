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
    private final Paint shadowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private Bitmap background;
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

    public MainMenuView(MainActivity activity) {
        super(activity);
        this.activity = activity;
        this.prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE);

        setFocusable(true);
        setFocusableInTouchMode(true);
        requestFocus();
        setKeepScreenOn(true);

        textPaint.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        shadowPaint.setColor(Color.argb(120, 0, 0, 0));
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
        background = load(c, "menu/menu_bg.jpg");
        logo = load(c, "menu/menu_logo.png");
        barNormal = load(c, "menu/menu_bar.png");
        barSelected = load(c, "menu/menu_bar_selected.png");
        footer = load(c, "menu/menu_footer.png");
    }

    @Override
    protected void onDraw(Canvas c) {
        super.onDraw(c);
        drawBackground(c);
        drawDarkLeftFade(c);
        drawLogo(c);

        if (settingsOpen) drawSettings(c);
        else drawMainMenu(c);

        drawFooter(c);
        drawStatus(c);

        if (System.currentTimeMillis() < statusUntilMs) postInvalidateOnAnimation();
    }

    private void drawBackground(Canvas c) {
        float cw = getWidth();
        float ch = getHeight();
        float iw = background.getWidth();
        float ih = background.getHeight();
        float scale = Math.max(cw / iw, ch / ih);
        float dw = iw * scale;
        float dh = ih * scale;
        RectF dst = new RectF((cw - dw) * 0.5f, (ch - dh) * 0.5f,
                (cw + dw) * 0.5f, (ch + dh) * 0.5f);
        c.drawBitmap(background, null, dst, imagePaint);
    }

    private void drawDarkLeftFade(Canvas c) {
        LinearGradient gradient = new LinearGradient(
                0, 0, getWidth() * 0.60f, 0,
                new int[]{Color.argb(190, 3, 5, 8), Color.argb(115, 3, 5, 8), Color.TRANSPARENT},
                new float[]{0f, 0.62f, 1f}, Shader.TileMode.CLAMP);
        overlayPaint.setShader(gradient);
        c.drawRect(0, 0, getWidth() * 0.67f, getHeight(), overlayPaint);
        overlayPaint.setShader(null);
    }

    private void drawLogo(Canvas c) {
        float w = getWidth() * 0.44f;
        float h = w * logo.getHeight() / (float) logo.getWidth();
        float x = getWidth() * 0.038f;
        float y = getHeight() * 0.055f;
        c.drawBitmap(logo, null, new RectF(x, y, x + w, y + h), imagePaint);
    }

    private void drawMainMenu(Canvas c) {
        String[] labels = {"New Game", "Continue", "Settings", "Exit"};
        float x = getWidth() * 0.055f;
        float w = getWidth() * 0.31f;
        float h = getHeight() * 0.096f;
        float gap = getHeight() * 0.016f;
        float startY = getHeight() * 0.405f;

        for (int i = 0; i < labels.length; i++) {
            float y = startY + i * (h + gap);
            RectF rect = mainHit[i];
            rect.set(x, y, x + w, y + h);
            boolean active = i == selected;
            Bitmap bar = active ? barSelected : barNormal;
            c.drawBitmap(bar, null, rect, imagePaint);

            boolean continueDisabled = i == 1 && !prefs.getBoolean("has_save", false);
            drawButtonText(c, labels[i], rect, active, continueDisabled);
        }
    }

    private void drawSettings(Canvas c) {
        float panelLeft = getWidth() * 0.045f;
        float panelTop = getHeight() * 0.35f;
        float panelRight = getWidth() * 0.42f;
        float panelBottom = getHeight() * 0.75f;

        overlayPaint.setColor(Color.argb(205, 4, 5, 8));
        c.drawRoundRect(new RectF(panelLeft, panelTop, panelRight, panelBottom),
                getHeight() * 0.018f, getHeight() * 0.018f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.STROKE);
        overlayPaint.setStrokeWidth(Math.max(2f, getHeight() * 0.003f));
        overlayPaint.setColor(Color.argb(150, 130, 42, 48));
        c.drawRoundRect(new RectF(panelLeft, panelTop, panelRight, panelBottom),
                getHeight() * 0.018f, getHeight() * 0.018f, overlayPaint);
        overlayPaint.setStyle(Paint.Style.FILL);

        textPaint.setTextAlign(Paint.Align.LEFT);
        textPaint.setTextSize(getHeight() * 0.052f);
        textPaint.setColor(Color.rgb(232, 226, 218));
        c.drawText("Settings", panelLeft + getWidth() * 0.025f,
                panelTop + getHeight() * 0.075f, textPaint);

        boolean vibration = prefs.getBoolean("vibration", true);
        String[] labels = {"Vibration: " + (vibration ? "ON" : "OFF"), "Back"};
        float x = panelLeft + getWidth() * 0.018f;
        float w = panelRight - panelLeft - getWidth() * 0.036f;
        float h = getHeight() * 0.10f;
        float y0 = panelTop + getHeight() * 0.12f;
        float gap = getHeight() * 0.035f;

        for (int i = 0; i < labels.length; i++) {
            float y = y0 + i * (h + gap);
            RectF rect = settingsHit[i];
            rect.set(x, y, x + w, y + h);
            boolean active = i == settingsSelected;
            c.drawBitmap(active ? barSelected : barNormal, null, rect, imagePaint);
            drawButtonText(c, labels[i], rect, active, false);
        }
    }

    private void drawButtonText(Canvas c, String label, RectF rect, boolean active, boolean disabled) {
        float textSize = getHeight() * 0.042f;
        textPaint.setTextAlign(Paint.Align.LEFT);
        textPaint.setTextSize(textSize);
        textPaint.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));

        float x = rect.left + rect.width() * 0.16f;
        float baseline = rect.centerY() - (textPaint.ascent() + textPaint.descent()) * 0.5f;

        textPaint.setColor(Color.argb(150, 0, 0, 0));
        c.drawText(label, x + 2f, baseline + 2f, textPaint);

        if (disabled) textPaint.setColor(Color.rgb(118, 118, 121));
        else if (active) textPaint.setColor(Color.rgb(246, 239, 228));
        else textPaint.setColor(Color.rgb(202, 198, 194));
        c.drawText(label, x, baseline, textPaint);
    }

    private void drawFooter(Canvas c) {
        float w = getWidth() * 0.90f;
        float h = w * footer.getHeight() / (float) footer.getWidth();
        float x = (getWidth() - w) * 0.5f;
        float y = getHeight() - h - getHeight() * 0.026f;
        c.drawBitmap(footer, null, new RectF(x, y, x + w, y + h), imagePaint);
    }

    private void drawStatus(Canvas c) {
        if (System.currentTimeMillis() >= statusUntilMs || statusMessage.isEmpty()) return;
        textPaint.setTextAlign(Paint.Align.LEFT);
        textPaint.setTextSize(getHeight() * 0.026f);
        textPaint.setColor(Color.rgb(226, 180, 184));
        c.drawText(statusMessage, getWidth() * 0.06f, getHeight() * 0.86f, textPaint);
    }

    private int hitMain(float x, float y) {
        for (int i = 0; i < mainHit.length; i++) if (mainHit[i].contains(x, y)) return i;
        return -1;
    }

    private int hitSettings(float x, float y) {
        for (int i = 0; i < settingsHit.length; i++) if (settingsHit[i].contains(x, y)) return i;
        return -1;
    }

    private void executeMain(int index) {
        selected = index;
        switch (index) {
            case 0:
                activity.startGame(false);
                break;
            case 1:
                if (prefs.getBoolean("has_save", false)) activity.startGame(true);
                else showStatus("No save data yet — start a New Game first.");
                break;
            case 2:
                settingsOpen = true;
                settingsSelected = 0;
                invalidate();
                break;
            case 3:
                activity.exitGame();
                break;
        }
    }

    private void executeSettings(int index) {
        settingsSelected = index;
        if (index == 0) {
            boolean value = !prefs.getBoolean("vibration", true);
            prefs.edit().putBoolean("vibration", value).apply();
            invalidate();
        } else {
            settingsOpen = false;
            invalidate();
        }
    }

    private void showStatus(String message) {
        statusMessage = message;
        statusUntilMs = System.currentTimeMillis() + 2300L;
        invalidate();
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();
        float x = event.getX();
        float y = event.getY();

        if (action == MotionEvent.ACTION_DOWN) {
            pressed = settingsOpen ? hitSettings(x, y) : hitMain(x, y);
            if (pressed >= 0) {
                if (settingsOpen) settingsSelected = pressed;
                else selected = pressed;
                invalidate();
            }
            return true;
        }

        if (action == MotionEvent.ACTION_UP) {
            int released = settingsOpen ? hitSettings(x, y) : hitMain(x, y);
            if (pressed >= 0 && released == pressed) {
                if (settingsOpen) executeSettings(released);
                else executeMain(released);
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
        if (keyCode == KeyEvent.KEYCODE_DPAD_UP) {
            if (settingsOpen) settingsSelected = (settingsSelected + 1) % 2;
            else selected = (selected + 3) % 4;
            invalidate();
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN) {
            if (settingsOpen) settingsSelected = (settingsSelected + 1) % 2;
            else selected = (selected + 1) % 4;
            invalidate();
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_ENTER || keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_BUTTON_A) {
            if (settingsOpen) executeSettings(settingsSelected);
            else executeMain(selected);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_BACK) return handleBack();
        return super.onKeyDown(keyCode, event);
    }

    public boolean handleBack() {
        if (settingsOpen) {
            settingsOpen = false;
            invalidate();
            return true;
        }
        return false;
    }
}