package com.veilbreakers.prototype;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Rect;
import android.util.Log;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/** Authored PNG artwork. Only the current scenery is decoded, keeping memory bounded. */
final class GameArt {
    private static final String ROOT = "art_v19/";
    private static final String[] REQUIRED = {
        "scenes/zone_0.png", "scenes/zone_1.png", "scenes/zone_2.png",
        "scenes/zone_3.png", "scenes/zone_4.png", "scenes/zone_5.png",
        "npc/mara_0.png", "npc/mara_1.png", "npc/mara_2.png",
        "npc/ivo_0.png", "npc/ivo_1.png", "npc/ivo_2.png",
        "portraits/kael.png", "portraits/mara.png", "portraits/ivo.png",
        "ui/status_panel.png", "ui/dialogue_frame.png", "ui/item_slot.png", "ui/button.png",
        "items/sword_varyn.png", "items/bandage.png", "items/mana_draught.png", "items/ivo_note.png",
        "props/chest_closed.png", "props/chest_open.png", "props/sword_ground.png",
        "props/trace.png", "props/altar.png"
        ,"scenes/zone_6.png", "scenes/zone_7.png", "scenes/zone_8.png",
        "runes/arcana.png", "runes/ember.png", "runes/frost.png", "runes/mark.png"
    };
    private final Context context;
    private final Map<String, Bitmap> images = new HashMap<>();
    private final Map<String, RectF> visible = new HashMap<>();
    private final Paint paint = new Paint();
    private final Rect source = new Rect();
    private final RectF tile = new RectF();
    private final int[] sx = new int[4], sy = new int[4];
    private final float[] dx = new float[4], dy = new float[4];
    private String currentScene = "";

    GameArt(Context context) {
        this.context = context;
        paint.setFilterBitmap(false);
        for (String path : REQUIRED) {
            if (path.startsWith("scenes/")) {
                // Verify headers without keeping all six backgrounds in the Java heap.
                try (InputStream stream = context.getAssets().open(assetPath(path))) {
                    BitmapFactory.Options options = new BitmapFactory.Options();
                    options.inJustDecodeBounds = true;
                    BitmapFactory.decodeStream(stream, null, options);
                    if (options.outWidth <= 0 || options.outHeight <= 0) throw new IOException("Invalid image");
                } catch (IOException error) {
                    throw new IllegalStateException("Missing v1.9 artwork: " + path, error);
                }
            } else {
                Bitmap image = decode(path);
                images.put(path, image);
                if (path.startsWith("props/")) {
                    int[] pixels = new int[image.getWidth() * image.getHeight()];
                    image.getPixels(pixels,0,image.getWidth(),0,0,image.getWidth(),image.getHeight());
                    int left=image.getWidth(), top=image.getHeight(), right=0, bottom=0;
                    for (int y=0; y<image.getHeight(); y++) for (int x=0; x<image.getWidth(); x++) {
                        if ((pixels[y*image.getWidth()+x] >>> 24) < 128) continue;
                        left=Math.min(left,x); top=Math.min(top,y);
                        right=Math.max(right,x+1); bottom=Math.max(bottom,y+1);
                    }
                    visible.put(path, new RectF(left,top,right,bottom));
                }
            }
        }
        Log.i("VEILBREAKERS_GAME_ART", "v1.10 loaded: scenes=9 npc=6 portraits=3 ui=4 items=4 props=5 runes=4");
    }

    private String assetPath(String name) {
        boolean current = name.startsWith("runes/") || (name.startsWith("scenes/zone_") && name.charAt(12)>='6');
        return (current ? "art_v20/" : ROOT) + name;
    }

    RectF visibleBounds(String name) { return visible.get(name); }

    private Bitmap decode(String name) {
        try (InputStream stream = context.getAssets().open(assetPath(name))) {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inScaled = false;
            Bitmap result = BitmapFactory.decodeStream(stream, null, options);
            if (result == null) throw new IOException("Invalid PNG");
            return result;
        } catch (IOException error) {
            throw new IllegalStateException("Missing v1.9 artwork: " + name, error);
        }
    }

    Bitmap bitmap(String name) {
        if (name.startsWith("scenes/") && !name.equals(currentScene)) {
            Bitmap previous = images.remove(currentScene);
            if (previous != null && !previous.isRecycled()) previous.recycle();
            currentScene = name;
            images.put(name, decode(name));
        }
        return images.get(name);
    }

    void draw(Canvas canvas, String name, RectF bounds) {
        Bitmap image = bitmap(name);
        if (image == null) return;
        if (!name.startsWith("ui/")) { canvas.drawBitmap(image, null, bounds, paint); return; }
        // Nine-slice keeps the authored corners proportional on wide phone screens.
        int border = Math.max(1, (int)(Math.min(image.getWidth(), image.getHeight()) * .18f));
        float edge = Math.min(bounds.width(), bounds.height()) * .15f;
        sx[0]=0; sx[1]=border; sx[2]=image.getWidth()-border; sx[3]=image.getWidth();
        sy[0]=0; sy[1]=border; sy[2]=image.getHeight()-border; sy[3]=image.getHeight();
        dx[0]=bounds.left; dx[1]=bounds.left+edge; dx[2]=bounds.right-edge; dx[3]=bounds.right;
        dy[0]=bounds.top; dy[1]=bounds.top+edge; dy[2]=bounds.bottom-edge; dy[3]=bounds.bottom;
        for (int row=0; row<3; row++) for (int col=0; col<3; col++) {
            source.set(sx[col],sy[row],sx[col+1],sy[row+1]);
            tile.set(dx[col],dy[row],dx[col+1],dy[row+1]);
            canvas.drawBitmap(image,source,tile,paint);
        }
    }

    void release() {
        for (Bitmap image : images.values()) if (!image.isRecycled()) image.recycle();
        images.clear();
        currentScene = "";
    }
}
