package com.veilbreakers.prototype;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;

import java.io.InputStream;

/** Distinct authored fire/frost sprites; Arcana's approved atlas stays intact. */
final class SpellVisuals {
    private final ArcanaVisuals arcana;
    private final Bitmap[][] effects = new Bitmap[2][12];
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);

    SpellVisuals(Context context, ArcanaVisuals arcana) {
        this.arcana = arcana;
        String[] names = {"fire", "ice"};
        try {
            for (int school = 0; school < 2; school++) for (int frame = 0; frame < 12; frame++) {
                try (InputStream input = context.getAssets().open("fx_v20/" + names[school] + "_" + frame + ".png")) {
                    BitmapFactory.Options options = new BitmapFactory.Options(); options.inScaled = false;
                    Bitmap image = BitmapFactory.decodeStream(input, null, options);
                    if (image == null || image.getWidth() != 256 || image.getHeight() != 256)
                        throw new IllegalStateException("Invalid spell atlas " + names[school] + "/" + frame);
                    effects[school][frame] = image;
                }
            }
        } catch (Exception error) { throw new IllegalStateException("Missing v1.10 spell artwork", error); }
    }

    void drawFrame(Canvas c, int spell, int frame, float x, float y, float size, int alpha, int direction) {
        if (spell == SpellProfile.ARCANA) { arcana.drawFrame(c, frame, x, y, size, alpha, direction); return; }
        spell = Math.max(1, Math.min(2, spell)); frame = Math.max(0, Math.min(11, frame));
        c.save(); c.translate(x, y);
        if (frame >= 3 && frame <= 7) c.rotate(direction == 0 ? 90f : direction == 1 ? -90f : direction == 2 ? 180f : 0f);
        paint.setAlpha(Math.max(0, Math.min(255, alpha)));
        float half = size * .5f;
        c.drawBitmap(effects[spell - 1][frame], null, new RectF(-half, -half, half, half), paint);
        paint.setAlpha(255); c.restore();
    }

    void drawCharge(Canvas c, int spell, float clock, float x, float y, float h, int direction) {
        if (clock < .07f || clock >= .34f) return;
        drawFrame(c, spell, clock < .12f ? 0 : clock < .21f ? 1 : 2, x, y, h * .16f, 255, direction);
    }
    void drawRelease(Canvas c, int spell, float clock, float x, float y, float h, int direction) {
        float age = clock - .34f;
        if (age < 0f || age >= .055f) return;
        drawFrame(c, spell, 3, x, y, h * .19f, Math.round(230f * (1f - age / .055f)), direction);
    }
    void drawFlight(Canvas c, int spell, float age, float x, float y, float h, int direction) {
        drawFrame(c, spell, 4 + (((int)(age * 24f)) & 3), x, y, h * .18f, 255, direction);
    }
    void drawImpact(Canvas c, int spell, float remaining, boolean hit, float x, float y, float h, int direction) {
        if (remaining <= 0f) return;
        float elapsed = Math.max(0f, ArcanaVisuals.IMPACT_DURATION - remaining);
        int frame = !hit ? 11 : elapsed < .045f ? 8 : elapsed < .115f ? 9 : elapsed < .215f ? 10 : 11;
        int alpha = frame == 11 ? Math.round(255f * Math.min(1f, remaining / (hit ? .12f : .13f))) : 255;
        drawFrame(c, spell, frame, x, y, h * (hit ? .27f : .19f), alpha, direction);
    }
}
