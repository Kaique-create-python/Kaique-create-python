package com.veilbreakers.prototype;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

/** Authored casting sockets and directional, isolated Arcana VIII artwork. */
final class ArcanaVisuals {
    static final float[] CAST_STARTS = {0f, .07f, .18f, .34f, .44f, .58f};
    static final float CAST_DURATION = .72f;
    static final float RELEASE_TIME = .34f;
    static final float IMPACT_DURATION = .335f;
    static final int FRAME_COUNT = 12;
    private static final float[] REVIEW_DURATIONS = {
            .05f, .07f, .12f, .08f, .08f, .08f, .08f, .08f, .045f, .07f, .10f, .12f
    };
    private static final String[] DIRECTIONS = {"down", "up", "left", "right"};
    private final Bitmap[] effects = new Bitmap[FRAME_COUNT];
    private final float[][][] sockets = new float[4][6][2];
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);

    ArcanaVisuals(Context context) {
        try {
            for (int i = 0; i < effects.length; i++) {
                try (InputStream input = context.getAssets().open("fx_v19/arcana_" + i + ".png")) {
                    BitmapFactory.Options options = new BitmapFactory.Options();
                    options.inScaled = false;
                    effects[i] = BitmapFactory.decodeStream(input, null, options);
                    if (effects[i] == null || effects[i].getWidth() != 256 || effects[i].getHeight() != 256)
                        throw new IllegalStateException("Invalid authored Arcana frame " + i);
                }
            }
            try (InputStream input = context.getAssets().open("kael_v19/cast_manifest.json")) {
                ByteArrayOutputStream bytes = new ByteArrayOutputStream();
                byte[] block = new byte[4096];
                int count;
                while ((count = input.read(block)) != -1) bytes.write(block, 0, count);
                JSONArray animations = new JSONObject(bytes.toString("UTF-8")).getJSONArray("animations");
                for (int direction = 0; direction < DIRECTIONS.length; direction++) {
                    JSONObject animation = animations.getJSONObject(direction);
                    if (!DIRECTIONS[direction].equals(animation.getString("direction")))
                        throw new IllegalStateException("Arcana socket direction order mismatch");
                    JSONArray frames = animation.getJSONArray("frames");
                    if (frames.length() != 6) throw new IllegalStateException("Arcana requires six casting phases");
                    for (int frame = 0; frame < 6; frame++) {
                        JSONArray point = frames.getJSONObject(frame).getJSONArray("orbSocketPx");
                        sockets[direction][frame][0] = (float) point.getDouble(0);
                        sockets[direction][frame][1] = (float) point.getDouble(1);
                    }
                }
            }
        } catch (Exception error) {
            throw new IllegalStateException("Missing or invalid v1.9 Arcana artwork/sockets", error);
        }
    }

    float socketX(int direction, int phase) { return sockets[direction][phase][0]; }
    float socketY(int direction, int phase) { return sockets[direction][phase][1]; }

    static int castFrame(float time) {
        for (int frame = CAST_STARTS.length - 1; frame >= 0; frame--)
            if (time >= CAST_STARTS[frame]) return frame;
        return 0;
    }

    static int reviewFrame(float elapsed) {
        float duration = 0f;
        for (float phase : REVIEW_DURATIONS) duration += phase;
        float time = elapsed % duration;
        for (int frame = 0; frame < REVIEW_DURATIONS.length; frame++) {
            if (time < REVIEW_DURATIONS[frame]) return frame;
            time -= REVIEW_DURATIONS[frame];
        }
        return REVIEW_DURATIONS.length - 1;
    }

    void drawFrame(Canvas canvas, int index, float x, float y, float size, int alpha, int direction) {
        index = Math.max(0, Math.min(effects.length - 1, index));
        canvas.save();
        canvas.translate(x, y);
        // Launch/flight assets face RIGHT. Radial charge and impact keep their
        // authored orientation. Rotate around the core, never tail bounds.
        if (index >= 3 && index <= 7) {
            float degrees = direction == 0 ? 90f : direction == 1 ? -90f : direction == 2 ? 180f : 0f;
            canvas.rotate(degrees);
        }
        paint.setAlpha(Math.max(0, Math.min(255, alpha)));
        float half = size * .5f;
        canvas.drawBitmap(effects[index], null, new RectF(-half, -half, half, half), paint);
        paint.setAlpha(255);
        canvas.restore();
    }

    void drawCharge(Canvas canvas, float clock, float x, float y, float screenHeight, int direction) {
        if (clock < CAST_STARTS[1] || clock >= RELEASE_TIME) return;
        int index = clock < .12f ? 0 : clock < .21f ? 1 : 2;
        drawFrame(canvas, index, x, y, screenHeight * .16f, 255, direction);
    }

    void drawRelease(Canvas canvas, float clock, float x, float y, float screenHeight, int direction) {
        float age = clock - RELEASE_TIME;
        // A brief muzzle shock merges with the outgoing core, then disappears
        // before it can read as a second stationary sphere beside the glove.
        if (age < 0f || age >= .055f) return;
        drawFrame(canvas, 3, x, y, screenHeight * .19f,
                Math.round(230f * (1f - age / .055f)), direction);
    }

    void drawFlight(Canvas canvas, float age, float x, float y, float screenHeight, int direction) {
        int index = 4 + (((int) (age * 24f)) & 3);
        drawFrame(canvas, index, x, y, screenHeight * .18f, 255, direction);
    }

    void drawImpact(Canvas canvas, float remaining, boolean hit, float x, float y, float screenHeight, int direction) {
        if (remaining <= 0f) return;
        if (!hit) {
            drawFrame(canvas, 11, x, y, screenHeight * .19f,
                    Math.round(210f * Math.min(1f, remaining / .13f)), direction);
            return;
        }
        float elapsed = Math.max(0f, IMPACT_DURATION - remaining);
        int index = elapsed < .045f ? 8 : elapsed < .115f ? 9 : elapsed < .215f ? 10 : 11;
        int alpha = index == 11 ? Math.round(255f * Math.min(1f, remaining / .12f)) : 255;
        drawFrame(canvas, index, x, y, screenHeight * .27f, alpha, direction);
    }
}
