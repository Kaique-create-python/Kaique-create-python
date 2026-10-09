package com.veilbreakers.prototype;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;

import java.util.Random;

/** Six rooms of Varyn with authored image scenery and matching ground footprints. */
public final class VarynMap {
    public static final String SWORD = "sword";
    public static final String CHEST = "chest";
    public static final String MARA = "mara";
    public static final String IVO = "ivo";
    public static final String TRACE = "trace";
    public static final String NEXT = "next";
    public static final String PREVIOUS = "previous";
    public static final String ALTAR = "altar";
    public static final String EMBER_RUNE = "ember_rune", FROST_RUNE = "frost_rune";
    public static final String ECHO_TRACE = "echo_trace", WATCHER = "watcher";

    private static final String[] NAMES = {"Distrito Destruído", "Praça Central",
            "Casas Queimadas", "Aqueduto", "Portão Norte", "Santuário Abandonado",
            "Estrada das Cinzas", "Cripta dos Ecos", "Torre do Vigia"};
    // Raster scenery above these floor limits is architecture or sky, never ground.
    private static final float[] FLOOR_TOP = {.525f,.525f,.525f,.525f,.525f,.525f,.525f,.525f,.525f};
    private static final float[] FLOOR_BOTTOM = {.765f,.765f,.765f,.745f,.765f,.765f,.765f,.765f,.765f};
    // Collision covers the footprint of scenery, rather than the height of its silhouette.
    // The central .45-.72H corridor and authored character/object positions stay clear.
    private static final RectF[][] SOLIDS = {
            {box(.10f,.38f,.36f,.50f), box(.66f,.38f,.88f,.50f), box(0,.665f,.335f,1), box(.78f,.63f,1,1)},
            {box(.03f,.31f,.26f,.46f), box(.74f,.31f,.99f,.46f), box(.36f,.40f,.63f,.54f), box(0,.68f,.335f,1), box(.79f,.65f,1,1)},
            {box(.11f,.38f,.36f,.50f), box(.69f,.38f,.88f,.50f), box(0,.66f,.33f,1), box(.80f,.66f,1,1)},
            {box(.13f,.39f,.86f,.50f), box(.11f,.745f,.91f,.87f), box(0,.64f,.12f,1), box(.88f,.64f,1,1)},
            {box(.10f,.36f,.35f,.50f), box(.56f,.38f,.82f,.50f), box(0,.63f,.32f,1), box(.80f,.67f,1,1)},
            {box(.17f,.35f,.29f,.50f), box(.71f,.35f,.83f,.50f), box(0,.65f,.37f,1), box(.73f,.66f,1,1)},
            {box(0,.68f,.12f,1), box(.88f,.68f,1,1)},
            {box(0,.64f,.32f,1),box(.80f,.67f,1,1)},
            {box(0,.65f,.35f,1), box(.77f,.68f,1,1)}
    };

    private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bitmapPaint = new Paint(Paint.FILTER_BITMAP_FLAG);
    private final Typeface serif = Typeface.create(Typeface.SERIF, Typeface.NORMAL);
    private final RectF r = new RectF();
    private final Path path = new Path();
    private Bitmap backdrop;
    private GameArt art;
    private StoryState frameStory;
    private int backdropZone = -1;
    private int width;
    private int height;
    private float w;
    private float h;

    void setArt(GameArt art) { this.art = art; discardBackdrop(); }
    public void setStory(StoryState story) { frameStory = story; }
    public float walkTop(int zone) { return h * FLOOR_TOP[clampZone(zone)]; }
    public float walkBottom(int zone) { return h * FLOOR_BOTTOM[clampZone(zone)]; }

    public void resize(int width, int height) {
        int nextWidth = Math.max(1, width);
        int nextHeight = Math.max(1, height);
        if (this.width == nextWidth && this.height == nextHeight) return;
        this.width = nextWidth;
        this.height = nextHeight;
        w = nextWidth;
        h = nextHeight;
        discardBackdrop();
    }

    public void drawGround(Canvas canvas, int zone, StoryState story) {
        frameStory = story;
        zone = clampZone(zone);
        if (width == 0 || height == 0) resize(canvas.getWidth(), canvas.getHeight());
        if (backdrop == null || backdropZone != zone) {
            discardBackdrop();
            backdrop = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            paintBackdrop(new Canvas(backdrop), zone);
            backdropZone = zone;
        }
        canvas.drawBitmap(backdrop, 0f, 0f, bitmapPaint);
    }

    public void drawObjects(Canvas canvas, int zone, StoryState story, float clock) {
        if (width == 0 || height == 0) resize(canvas.getWidth(), canvas.getHeight());
        zone = clampZone(zone);
        drawAmbient(canvas, zone, clock);
        if (zone == 0 && !story.swordFound) drawSword(canvas, interactionX(SWORD), interactionY(SWORD), clock);
        if (zone == 2) {
            drawTrace(canvas, interactionX(TRACE), interactionY(TRACE), story.traceFound || !story.metIvo, clock);
        }
        if (zone == 5 && !story.emberLearned) drawRune(canvas, "ember", EMBER_RUNE, clock);
        if (zone == 7) {
            drawTrace(canvas, interactionX(ECHO_TRACE), interactionY(ECHO_TRACE), story.echoTraceFound, clock);
            if (!story.frostLearned) drawRune(canvas, "frost", FROST_RUNE, clock);
        }
        if (zone > 0) drawExit(canvas, false, true, zoneName(zone - 1), clock);
        if (zone < 8) drawExit(canvas, true, story.canEnterNext(), zoneName(zone + 1), clock);
    }

    /** Draw NPCs once in the requested foot-baseline interval for world actor sorting. */
    public void drawNpcs(Canvas canvas, int zone, float clock, float minY, float maxY) {
        if (width == 0 || height == 0) resize(canvas.getWidth(), canvas.getHeight());
        zone = clampZone(zone);
        if (zone == 1 && interactionY(CHEST) >= minY && interactionY(CHEST) < maxY)
            drawChest(canvas, interactionX(CHEST), interactionY(CHEST), frameStory != null && frameStory.chestOpened);
        if (zone == 5 && interactionY(ALTAR) >= minY && interactionY(ALTAR) < maxY)
            drawAltar(canvas, interactionX(ALTAR), interactionY(ALTAR), frameStory != null && frameStory.altarUsed, clock);
        if (zone == 1) {
            float y = interactionY(MARA);
            if (y >= minY && y < maxY) drawSurvivor(canvas, interactionX(MARA), y, false, clock);
        } else if (zone == 2 && (frameStory == null || !frameStory.emberLearned)) {
            float y = interactionY(IVO);
            if (y >= minY && y < maxY) drawSurvivor(canvas, interactionX(IVO), y, true, clock);
        } else if (zone == 8) {
            float y = interactionY(WATCHER);
            if (y >= minY && y < maxY) drawSurvivor(canvas, interactionX(WATCHER), y, true, clock);
        }
    }

    public boolean blocked(int zone, float x, float y, float radius) {
        if (w <= 0f || h <= 0f) return false;
        radius = Math.max(0f, radius);
        zone = clampZone(zone);
        if (y - radius < walkTop(zone) - .01f || y + radius > walkBottom(zone) + .01f) return true;
        if (zone == 1 && (propCollision(CHEST,x,y,radius,.058f,.026f,.01f)
                || circleCollision(MARA,x,y,radius,h*.028f))) return true;
        if (zone == 2 && (frameStory == null || !frameStory.emberLearned)
                && circleCollision(IVO,x,y,radius,h*.028f)) return true;
        if (zone == 5 && propCollision(ALTAR,x,y,radius,.085f,.035f,.01f)) return true;
        if (zone == 8 && circleCollision(WATCHER,x,y,radius,h*.028f)) return true;
        for (RectF solid : SOLIDS[clampZone(zone)]) {
            float left = solid.left * w, right = solid.right * w;
            float top = solid.top * h, bottom = solid.bottom * h;
            float cx = Math.max(left, Math.min(right, x));
            float cy = Math.max(top, Math.min(bottom, y));
            float dx = x - cx, dy = y - cy;
            if (dx * dx + dy * dy <= radius * radius) return true;
        }
        return false;
    }

    private boolean propCollision(String id, float x, float y, float radius,
                                  float halfWidth, float back, float front) {
        float cx=interactionX(id), cy=interactionY(id);
        float closestX=Math.max(cx-h*halfWidth,Math.min(cx+h*halfWidth,x));
        float closestY=Math.max(cy-h*back,Math.min(cy+h*front,y));
        float dx=x-closestX, dy=y-closestY;
        return dx*dx+dy*dy <= radius*radius;
    }

    private boolean circleCollision(String id, float x, float y, float radius, float objectRadius) {
        float dx=x-interactionX(id), dy=y-interactionY(id), reach=radius+objectRadius;
        return dx*dx+dy*dy <= reach*reach;
    }

    public boolean clearLine(int zone, float ax, float ay, float bx, float by, float radius) {
        int steps=Math.max(1,(int)Math.ceil(Math.hypot(bx-ax,by-ay)/Math.max(1f,h*.014f)));
        for (int i=1; i<=steps; i++) {
            float t=(float)i/steps;
            if (blocked(zone,ax+(bx-ax)*t,ay+(by-ay)*t,radius)) return false;
        }
        return true;
    }

    public String nearestInteraction(int zone, StoryState story, float x, float y) {
        if (h <= 0f) return "";
        zone = clampZone(zone);
        String nearest = "";
        float best = h * .16f;
        best *= best;
        for (int candidate = 0; candidate < 12; candidate++) {
            String id;
            switch (candidate) {
                case 0: if (zone != 0 || story.swordFound) continue; id = SWORD; break;
                case 1: if (zone != 1 || story.chestOpened) continue; id = CHEST; break;
                case 2: if (zone != 1) continue; id = MARA; break;
                case 3: if (zone != 2 || story.emberLearned) continue; id = IVO; break;
                case 4: if (zone != 2 || !story.metIvo || story.traceFound) continue; id = TRACE; break;
                case 5: if (zone >= 8) continue; id = NEXT; break;
                case 6: if (zone <= 0) continue; id = PREVIOUS; break;
                case 7: if (zone != 5) continue; id = ALTAR; break;
                case 8: if (zone != 5 || story.emberLearned) continue; id = EMBER_RUNE; break;
                case 9: if (zone != 7 || story.frostLearned) continue; id = FROST_RUNE; break;
                case 10: if (zone != 7 || story.echoTraceFound) continue; id = ECHO_TRACE; break;
                default: if (zone != 8) continue; id = WATCHER; break;
            }
            float dx = x - interactionX(id), dy = y - interactionY(id);
            float distance = dx * dx + dy * dy;
            if (distance <= best) {
                best = distance;
                nearest = id;
            }
        }
        return nearest;
    }

    public float interactionX(String id) {
        if (SWORD.equals(id)) return w * .43f;
        if (CHEST.equals(id)) return w * .62f;
        if (MARA.equals(id)) return w * .30f;
        if (IVO.equals(id)) return w * .48f;
        if (WATCHER.equals(id)) return w * .43f;
        if (EMBER_RUNE.equals(id)) return w * .65f;
        if (FROST_RUNE.equals(id)) return w * .66f;
        if (ECHO_TRACE.equals(id)) return w * .42f;
        if (TRACE.equals(id)) return w * .64f;
        if (NEXT.equals(id)) return w * .92f;
        if (PREVIOUS.equals(id)) return w * .08f;
        if (ALTAR.equals(id)) return w * .55f;
        return w * .50f;
    }

    public float interactionY(String id) {
        if (SWORD.equals(id) || TRACE.equals(id)) return h * .60f;
        if (CHEST.equals(id)) return h * .65f;
        if (MARA.equals(id)) return h * .57f;
        if (IVO.equals(id)) return h * .55f;
        if (ALTAR.equals(id)) return h * .56f;
        if (WATCHER.equals(id)) return h * .57f;
        if (EMBER_RUNE.equals(id)) return h * .63f;
        if (FROST_RUNE.equals(id) || ECHO_TRACE.equals(id)) return h * .62f;
        if (NEXT.equals(id) || PREVIOUS.equals(id)) return h * .57f;
        return h * .60f;
    }

    public String interactionLabel(String id) {
        if (SWORD.equals(id)) return "RECUPERAR ESPADA";
        if (CHEST.equals(id)) return "ABRIR BAÚ";
        if (MARA.equals(id)) return "FALAR COM MARA";
        if (IVO.equals(id)) return "FALAR COM IVO";
        if (TRACE.equals(id)) return "EXAMINAR CINZAS";
        if (NEXT.equals(id)) return "SEGUIR";
        if (PREVIOUS.equals(id)) return "VOLTAR";
        if (ALTAR.equals(id)) return "DESCANSAR";
        if (EMBER_RUNE.equals(id)) return "EXAMINAR RUNA";
        if (FROST_RUNE.equals(id)) return "TOCAR A GEADA";
        if (ECHO_TRACE.equals(id)) return "EXAMINAR OS ECOS";
        if (WATCHER.equals(id)) return "FALAR COM IVO";
        return "INTERAGIR";
    }

    public static String zoneName(int zone) {
        return NAMES[clampZone(zone)];
    }

    public void release() {
        discardBackdrop();
    }

    private void discardBackdrop() {
        if (backdrop != null && !backdrop.isRecycled()) backdrop.recycle();
        backdrop = null;
        backdropZone = -1;
    }

    private void paintBackdrop(Canvas c, int zone) {
        if (art != null) {
            r.set(0, 0, w, h);
            art.draw(c, "scenes/zone_" + zone + ".png", r);
            return;
        }
        p.setStyle(Paint.Style.FILL);
        p.setShader(new LinearGradient(0, 0, 0, h * .60f,
                new int[] {Color.rgb(13,19,24), Color.rgb(32,37,39), Color.rgb(52,48,43)},
                null, Shader.TileMode.CLAMP));
        c.drawRect(0, 0, w, h, p);
        p.setShader(null);
        drawHollowSun(c);
        drawDistantCity(c, zone);
        p.setShader(new LinearGradient(0, h * .34f, 0, h,
                Color.rgb(58,55,50), Color.rgb(24,28,28), Shader.TileMode.CLAMP));
        c.drawRect(0, h * .34f, w, h, p);
        p.setShader(null);
        drawStreet(c, zone);
        switch (zone) {
            case 0:
                drawHouse(c, .10f, .08f, .29f, .41f, true);
                drawHouse(c, .71f, .13f, .88f, .41f, true);
                drawRubble(c, .48f, .79f, .62f, .89f, 31);
                drawScorchedBanner(c, .36f, .33f);
                break;
            case 1:
                drawFountain(c, .395f, .365f);
                drawStatue(c, .66f, .41f);
                drawRubble(c, .35f, .80f, .46f, .90f, 52);
                drawHouse(c, .03f, .10f, .24f, .30f, false);
                break;
            case 2:
                drawHouse(c, .13f, .07f, .35f, .41f, true);
                drawHouse(c, .63f, .09f, .83f, .41f, true);
                drawRubble(c, .27f, .80f, .40f, .91f, 72);
                // A small shelter door remains shut; no explanation of the disappearances yet.
                fill(c, .18f, .26f, .225f, .405f, Color.rgb(26,29,28));
                line(c, .202f, .27f, .202f, .40f, Color.rgb(86,78,60), h * .002f);
                break;
            case 3:
                drawAqueduct(c);
                break;
            case 4:
                drawNorthGate(c);
                drawRubble(c, .46f, .82f, .57f, .91f, 89);
                break;
            case 5:
                drawSanctuary(c);
                break;
        }
        drawGroundDetails(c, zone);
        // Vignette belongs to the cached scenery, avoiding a new gradient every frame.
        p.setShader(new RadialGradient(w * .52f, h * .50f, w * .68f,
                new int[] {Color.TRANSPARENT, Color.argb(25,0,0,0), Color.argb(155,0,0,0)},
                new float[] {0f,.53f,1f}, Shader.TileMode.CLAMP));
        c.drawRect(0, 0, w, h, p);
        p.setShader(null);
        p.setAlpha(255);
    }

    private void drawHollowSun(Canvas c) {
        float x = w * .56f, y = h * .145f, radius = h * .072f;
        p.setShader(new RadialGradient(x, y, radius * 2.3f,
                Color.argb(67,168,132,75), Color.TRANSPARENT, Shader.TileMode.CLAMP));
        c.drawCircle(x, y, radius * 2.3f, p);
        p.setShader(null);
        p.setStyle(Paint.Style.FILL);
        p.setColor(Color.rgb(12,17,20));
        c.drawCircle(x, y, radius, p);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(h * .003f);
        p.setColor(Color.rgb(154,126,82));
        c.drawCircle(x, y, radius, p);
        p.setColor(Color.argb(50,184,161,113));
        c.drawCircle(x, y, radius * 1.13f, p);
        p.setStyle(Paint.Style.FILL);
    }

    private void drawDistantCity(Canvas c, int zone) {
        Random random = new Random(731L + zone);
        for (int i = 0; i < 26; i++) {
            float left = i / 26f;
            float top = .23f - random.nextFloat() * .12f;
            fill(c, left, top, left + .044f, .35f, Color.rgb(24,29,31));
            if (i % 4 == 1) {
                path.reset();
                path.moveTo(left * w, top * h);
                path.lineTo((left + .020f) * w, (top - .05f) * h);
                path.lineTo((left + .044f) * w, top * h);
                path.close();
                p.setColor(Color.rgb(24,29,31));
                c.drawPath(path, p);
            }
        }
    }

    private void drawStreet(Canvas c, int zone) {
        // A readable warm band establishes the walkable center of every room.
        p.setShader(new LinearGradient(0, h * .43f, 0, h * .78f,
                new int[] {Color.TRANSPARENT, Color.argb(95,124,115,92), Color.TRANSPARENT},
                new float[] {0f,.48f,1f}, Shader.TileMode.CLAMP));
        c.drawRect(0, h * .43f, w, h * .78f, p);
        p.setShader(null);
        for (int row = 0; row < 10; row++) {
            float y = .35f + row * row * .006f;
            line(c, 0, y, 1, y, Color.argb(65,8,13,15), h * .0015f);
            int blocks = Math.max(8, 27 - row * 2);
            for (int col = 0; col <= blocks; col++) {
                float x = (col + (row % 2 == 0 ? 0f : .5f)) / blocks;
                line(c, x, y, x, y + .012f + row * .012f,
                        Color.argb(47,9,14,15), h * .0012f);
            }
        }
        if (zone == 5) {
            oval(c, w * .55f, h * .55f, w * .15f, h * .11f, Color.argb(35,133,128,94));
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(h * .002f);
            p.setColor(Color.argb(75,145,135,101));
            r.set(w * .40f,h * .44f,w * .70f,h * .66f);
            c.drawOval(r,p);
            p.setStyle(Paint.Style.FILL);
        }
    }

    private void drawHouse(Canvas c, float left, float top, float right, float bottom, boolean burned) {
        int stone = burned ? Color.rgb(37,38,35) : Color.rgb(54,55,49);
        fill(c, left, top, right, bottom, stone);
        fill(c, left, top, left + .016f, bottom, Color.rgb(74,71,61));
        fill(c, right - .018f, top + .018f, right, bottom, Color.rgb(18,25,27));
        line(c, left, bottom, right, bottom, Color.rgb(90,84,67), h * .008f);
        // The broken roof is deliberately irregular, rather than a clean triangle.
        path.reset();
        path.moveTo(left * w, top * h);
        path.lineTo((left + .028f) * w, (top - .035f) * h);
        path.lineTo((left + .078f) * w, (top + .024f) * h);
        path.lineTo((right - .036f) * w, (top - .022f) * h);
        path.lineTo(right * w, (top + .026f) * h);
        path.close();
        p.setColor(Color.rgb(15,21,23));
        c.drawPath(path, p);
        for (int row = 0; row < 5; row++) {
            float y = top + (bottom - top) * (row + 1) / 6f;
            line(c, left, y, right, y, Color.argb(110,17,24,26), h * .003f);
        }
        float windowY = top + (bottom - top) * .27f;
        fill(c, left + .040f, windowY, left + .073f, windowY + .075f, Color.rgb(10,16,19));
        fill(c, right - .075f, windowY, right - .040f, windowY + .075f, Color.rgb(10,16,19));
        line(c, left + .092f, top + .10f, left + .077f, top + .16f, Color.rgb(14,20,22), h * .003f);
        line(c, left + .077f, top + .16f, left + .10f, top + .20f, Color.rgb(14,20,22), h * .003f);
        if (burned) {
            line(c, left + .023f, bottom - .035f, right - .025f, top + .025f,
                    Color.rgb(18,19,17), h * .013f);
            line(c, left + .04f, bottom - .029f, right - .032f, top + .043f,
                    Color.rgb(70,56,37), h * .002f);
        }
    }

    private void drawRubble(Canvas c, float left, float top, float right, float bottom, int seed) {
        Random random = new Random(seed);
        for (int i = 0; i < 30; i++) {
            float x = left + random.nextFloat() * (right - left);
            float y = top + random.nextFloat() * (bottom - top);
            float size = h * (.007f + random.nextFloat() * .016f);
            p.setColor(i % 3 == 0 ? Color.rgb(65,61,48) : Color.rgb(38,41,38));
            r.set(x * w,y * h,x * w + size * 1.8f,y * h + size);
            c.drawRoundRect(r,h * .003f,h * .003f,p);
        }
    }

    private void drawScorchedBanner(Canvas c, float x, float y) {
        line(c, x, y - .14f, x, y + .06f, Color.rgb(89,82,65), h * .005f);
        path.reset();
        path.moveTo(x * w,(y - .14f) * h);
        path.lineTo((x + .043f) * w,(y - .125f) * h);
        path.lineTo((x + .035f) * w,(y - .05f) * h);
        path.lineTo((x + .017f) * w,(y - .070f) * h);
        path.lineTo(x * w,(y - .055f) * h);
        path.close();
        p.setColor(Color.rgb(79,40,37));
        c.drawPath(path,p);
    }

    private void drawFountain(Canvas c, float x, float y) {
        oval(c,x * w,y * h,w * .045f,h * .052f,Color.rgb(75,74,62));
        oval(c,x * w,(y - .01f) * h,w * .037f,h * .032f,Color.rgb(22,36,39));
        fill(c,x - .009f,y - .09f,x + .009f,y,Color.rgb(82,79,66));
        oval(c,x * w,(y - .09f) * h,w * .020f,h * .019f,Color.rgb(100,94,75));
        line(c,x - .034f,y + .030f,x - .006f,y + .009f,Color.rgb(23,29,29),h * .004f);
    }

    private void drawStatue(Canvas c, float x, float footY) {
        fill(c,x - .050f,footY - .035f,x + .050f,footY,Color.rgb(86,80,64));
        fill(c,x - .036f,footY - .10f,x + .036f,footY - .035f,Color.rgb(57,62,59));
        path.reset();
        path.moveTo((x - .025f) * w,(footY - .10f) * h);
        path.lineTo((x - .010f) * w,(footY - .245f) * h);
        path.lineTo((x + .014f) * w,(footY - .225f) * h);
        path.lineTo((x + .030f) * w,(footY - .10f) * h);
        path.close();
        p.setColor(Color.rgb(65,69,62));
        c.drawPath(path,p);
        // Head is absent: the monument's identity is deliberately unclaimed.
        line(c,x - .009f,footY - .16f,x + .018f,footY - .12f,Color.rgb(26,32,31),h * .005f);
    }

    private void drawAqueduct(Canvas c) {
        fill(c,.20f,.34f,.83f,.42f,Color.rgb(28,51,52));
        fill(c,.20f,.79f,.83f,.87f,Color.rgb(21,43,46));
        line(c,.20f,.42f,.83f,.42f,Color.rgb(85,89,77),h * .007f);
        line(c,.20f,.79f,.83f,.79f,Color.rgb(85,89,77),h * .007f);
        fill(c,.23f,.16f,.84f,.19f,Color.rgb(74,78,68));
        for (int i = 0; i < 4; i++) {
            float x = .25f + i * .15f;
            fill(c,x,.19f,x + .026f,.335f,Color.rgb(75,80,73));
            fill(c,x + .021f,.19f,x + .031f,.335f,Color.rgb(32,43,44));
            p.setStyle(Paint.Style.STROKE);
            p.setStrokeWidth(h * .018f);
            p.setColor(Color.rgb(71,78,70));
            r.set((x + .025f) * w,h * .14f,(x + .150f) * w,h * .30f);
            c.drawArc(r,180,180,false,p);
            p.setStyle(Paint.Style.FILL);
        }
        for (int i = 0; i < 10; i++) {
            float x = .235f + i * .057f;
            line(c,x,.376f,x + .025f,.376f,Color.argb(95,102,127,122),h * .0014f);
            line(c,x,.825f,x + .023f,.825f,Color.argb(80,98,119,115),h * .0014f);
        }
    }

    private void drawNorthGate(Canvas c) {
        drawHouse(c,.12f,.07f,.35f,.42f,false);
        drawHouse(c,.51f,.05f,.81f,.42f,false);
        fill(c,.85f,.18f,.985f,.67f,Color.rgb(12,19,22));
        fill(c,.84f,.14f,.873f,.69f,Color.rgb(82,81,68));
        fill(c,.976f,.14f,.999f,.69f,Color.rgb(55,63,58));
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(h * .023f);
        p.setColor(Color.rgb(86,84,68));
        r.set(w * .856f,h * .04f,w * .99f,h * .37f);
        c.drawArc(r,180,180,false,p);
        p.setStyle(Paint.Style.FILL);
        for (int i = 0; i < 6; i++) {
            float x = .865f + i * .023f;
            line(c,x,.16f,x,.34f,Color.rgb(20,29,30),h * .005f);
        }
        drawScorchedBanner(c,.41f,.30f);
    }

    private void drawSanctuary(Canvas c) {
        // Open nave; the altar is an ordinary shelter/checkpoint, not a lore revelation.
        fill(c,.22f,.07f,.79f,.12f,Color.rgb(49,59,57));
        for (int side = 0; side < 2; side++) {
            float x = side == 0 ? .22f : .73f;
            fill(c,x,.12f,x + .060f,.42f,Color.rgb(70,80,74));
            fill(c,x + .045f,.12f,x + .060f,.42f,Color.rgb(31,46,47));
            fill(c,x - .008f,.39f,x + .068f,.42f,Color.rgb(97,101,85));
            line(c,x + .012f,.17f,x + .012f,.37f,Color.rgb(98,101,85),h * .002f);
        }
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(h * .016f);
        p.setColor(Color.rgb(66,80,75));
        r.set(w * .27f,-h * .03f,w * .74f,h * .41f);
        c.drawArc(r,180,180,false,p);
        p.setStyle(Paint.Style.FILL);
        drawRubble(c,.29f,.81f,.38f,.91f,120);
        for (int i = 0; i < 11; i++) {
            float x = .24f + (i % 2) * .012f;
            line(c,x,.14f + i * .018f,x + .02f,.15f + i * .018f,
                    Color.rgb(49,68,48),h * .006f);
        }
    }

    private void drawGroundDetails(Canvas c, int zone) {
        Random random = new Random(1193L + zone);
        for (int i = 0; i < 190; i++) {
            float x = random.nextFloat(), y = .34f + random.nextFloat() * .63f;
            float length = .002f + random.nextFloat() * .007f;
            line(c,x,y,x + length,y - random.nextFloat() * .007f,
                    i % 4 == 0 ? Color.argb(85,120,109,84) : Color.argb(78,10,16,18),h * .0017f);
        }
        for (int i = 0; i < 22; i++) {
            float x = random.nextFloat(), y = .43f + random.nextFloat() * .47f;
            line(c,x,y,x + .012f,y + .015f,Color.argb(75,12,19,20),h * .002f);
            line(c,x + .012f,y + .015f,x + .009f,y + .025f,
                    Color.argb(75,12,19,20),h * .0015f);
        }
    }

    private void drawAmbient(Canvas c, int zone, float clock) {
        // Sparse particles, deterministic phases, no asset decode or allocations.
        for (int i = 0; i < 13; i++) {
            float phase = (clock * (.009f + i * .0006f) + i * .077f) % 1f;
            float x = (i * .137f + (float) Math.sin(clock * .18f + i) * .012f) % 1f;
            if (x < 0f) x += 1f;
            float y = .75f - phase * .46f;
            int alpha = (int) (30 + Math.sin(phase * Math.PI) * 64);
            p.setColor(zone == 5 ? Color.argb(alpha,132,158,121) : Color.argb(alpha,194,121,62));
            c.drawCircle(x * w,y * h,h * (i % 3 == 0 ? .0025f : .0016f),p);
        }
        for (int i = 0; i < 3; i++) {
            float drift = (float) Math.sin(clock * .13f + i * 2.1f) * w * .05f;
            oval(c,w * (.24f + i * .28f) + drift,h * (.74f + i * .032f),
                    w * .16f,h * .015f,Color.argb(11,177,181,169));
        }
    }

    private void worldProp(Canvas c, String name, float x, float y, float size) {
        oval(c, x, y, size * .40f, size * .06f, Color.argb(90,0,0,0));
        String path="props/"+name+".png";
        RectF visible=art.visibleBounds(path);
        float scale=size/256f;
        float center=visible == null ? 128f : (visible.left+visible.right)*.5f;
        float bottom=visible == null ? 240f : visible.bottom;
        r.set(x-center*scale,y-bottom*scale,x+(256f-center)*scale,y+(256f-bottom)*scale);
        art.draw(c, path, r);
    }

    private void drawRune(Canvas c, String rune, String id, float clock) {
        if (art == null) return;
        float x=interactionX(id), y=interactionY(id), size=h*.085f;
        r.set(x-size*.5f,y-size*.5f,x+size*.5f,y+size*.5f);
        art.draw(c,"runes/"+rune+".png",r);
        marker(c,x,y-h*.075f,clock);
    }

    private void drawSword(Canvas c, float x, float y, float clock) {
        if (art != null) {
            worldProp(c, "sword_ground", x, y, h * .16f);
            marker(c, x, y - h * .11f, clock);
            return;
        }
        oval(c,x,y,h * .052f,h * .009f,Color.argb(100,0,0,0));
        linePixels(c,x - h * .033f,y + h * .003f,x + h * .044f,y - h * .046f,
                Color.rgb(156,165,162),h * .007f);
        linePixels(c,x - h * .047f,y + h * .014f,x - h * .027f,y,
                Color.rgb(78,54,38),h * .008f);
        linePixels(c,x - h * .039f,y - h * .011f,x - h * .020f,y + h * .018f,
                Color.rgb(128,105,65),h * .005f);
        marker(c,x,y - h * .085f,clock);
    }

    private void drawChest(Canvas c, float x, float y, boolean opened) {
        if (art != null) {
            worldProp(c, opened ? "chest_open" : "chest_closed", x, y, h * .15f);
            return;
        }
        oval(c,x,y,h * .048f,h * .012f,Color.argb(120,0,0,0));
        r.set(x - h * .047f,y - h * .049f,x + h * .047f,y);
        p.setColor(Color.rgb(68,48,32));
        c.drawRoundRect(r,h * .006f,h * .006f,p);
        r.set(x - h * .044f,y - h * (opened ? .082f : .066f),
                x + h * .044f,y - h * (opened ? .052f : .035f));
        p.setColor(Color.rgb(99,70,40));
        c.drawRoundRect(r,h * .008f,h * .008f,p);
        linePixels(c,x - h * .023f,y - h * .060f,x - h * .023f,y,Color.rgb(138,114,69),h * .005f);
        linePixels(c,x + h * .023f,y - h * .060f,x + h * .023f,y,Color.rgb(138,114,69),h * .005f);
        if (!opened) {
            p.setColor(Color.rgb(192,157,89));
            c.drawCircle(x,y - h * .032f,h * .004f,p);
        }
    }

    private void drawSurvivor(Canvas c, float x, float y, boolean ivo, float clock) {
        if (art != null) {
            oval(c, x, y, h * .052f, h * .012f, Color.argb(105,0,0,0));
            float scale = h * .205f / 174f;
            r.set(x - 128f * scale, y - 232f * scale, x + 128f * scale, y + 24f * scale);
            art.draw(c, "npc/" + (ivo ? "ivo_" : "mara_") + ((int)(clock * .5f) % 3) + ".png", r);
            p.setTypeface(serif); p.setTextAlign(Paint.Align.CENTER); p.setTextSize(h * .024f);
            p.setColor(Color.rgb(235,226,210));
            c.drawText(ivo ? "Ivo" : "Mara", x, y - h * .222f, p);
            return;
        }
        float size = h * .17f;
        float sway = (float) Math.sin(clock * 1.6f) * h * .001f;
        oval(c,x,y,h * .033f,h * .010f,Color.argb(105,0,0,0));
        linePixels(c,x - size * .09f,y - size * .24f,x - size * .09f,y,
                Color.rgb(27,31,30),size * .11f);
        linePixels(c,x + size * .09f,y - size * .24f,x + size * .09f,y,
                Color.rgb(27,31,30),size * .11f);
        path.reset();
        path.moveTo(x - size * .14f,y - size * .76f + sway);
        path.lineTo(x + size * .14f,y - size * .76f + sway);
        path.lineTo(x + size * .25f,y - size * .18f);
        path.lineTo(x - size * .25f,y - size * .18f);
        path.close();
        p.setColor(ivo ? Color.rgb(53,62,49) : Color.rgb(59,48,50));
        c.drawPath(path,p);
        linePixels(c,x - size * .13f,y - size * .72f,x - size * .24f,y - size * .39f,
                Color.rgb(45,46,41),size * .11f);
        linePixels(c,x + size * .13f,y - size * .72f,x + size * .25f,y - size * .39f,
                Color.rgb(45,46,41),size * .11f);
        oval(c,x,y - size * .87f + sway,size * .105f,size * .14f,Color.rgb(143,130,107));
        oval(c,x,y - size * .95f + sway,size * .125f,size * .095f,
                ivo ? Color.rgb(34,37,31) : Color.rgb(70,54,43));
        linePixels(c,x - size * .15f,y - size * .72f,x + size * .12f,y - size * .68f,
                ivo ? Color.rgb(128,117,77) : Color.rgb(135,66,59),size * .07f);
        linePixels(c,x,y - size * .52f,x + size * .04f,y - size * .20f,
                Color.rgb(91,85,63),size * .018f);
        if (ivo) {
            float lx = x + size * .28f, ly = y - size * .25f;
            oval(c,lx,ly,size * .17f,size * .19f,Color.argb(22,208,158,75));
            r.set(lx - size * .045f,ly - size * .07f,lx + size * .045f,ly + size * .06f);
            p.setColor(Color.rgb(174,128,56));
            c.drawRoundRect(r,size * .016f,size * .016f,p);
        }
        p.setTypeface(serif);
        p.setTextAlign(Paint.Align.CENTER);
        p.setTextSize(h * .021f);
        p.setColor(Color.rgb(217,204,170));
        c.drawText(ivo ? "Ivo" : "Mara",x,y - size * 1.14f,p);
    }

    private void drawTrace(Canvas c, float x, float y, boolean examined, float clock) {
        if (art != null) {
            r.set(x - h * .10f, y - h * .06f, x + h * .10f, y + h * .06f);
            art.draw(c, "props/trace.png", r);
            if (!examined) marker(c, x, y - h * .085f, clock);
            return;
        }
        oval(c,x,y,h * .055f,h * .025f,Color.argb(110,107,106,94));
        for (int i = 0; i < 5; i++) {
            float fx = x - h * .043f + i * h * .016f;
            float fy = y + (i % 2 == 0 ? h * .006f : -h * .006f);
            oval(c,fx,fy,h * .006f,h * .010f,Color.rgb(27,35,33));
        }
        if (!examined) marker(c,x,y - h * .062f,clock);
    }

    private void drawAltar(Canvas c, float x, float y, boolean used, float clock) {
        if (art != null) {
            worldProp(c, "altar", x, y, h * .23f);
            if (!used) marker(c, x, y - h * .21f, clock);
            return;
        }
        oval(c,x,y,h * .080f,h * .017f,Color.argb(95,0,0,0));
        r.set(x - h * .058f,y - h * .059f,x + h * .058f,y);
        p.setColor(Color.rgb(69,80,74));
        c.drawRect(r,p);
        r.set(x - h * .083f,y - h * .084f,x + h * .083f,y - h * .057f);
        p.setColor(Color.rgb(113,119,96));
        c.drawRoundRect(r,h * .004f,h * .004f,p);
        for (int i = -1; i <= 1; i += 2) {
            float cx = x + i * h * .050f;
            linePixels(c,cx,y - h * .087f,cx,y - h * .120f,Color.rgb(195,179,128),h * .006f);
            float flicker = h * (.005f + (float) Math.sin(clock * 6f + i) * .001f);
            oval(c,cx,y - h * .125f,h * .004f,flicker,Color.rgb(235,187,91));
        }
        if (!used) marker(c,x,y - h * .17f,clock);
    }

    private void drawExit(Canvas c, boolean next, boolean open, String label, float clock) {
        float x = w * (next ? .92f : .08f), y = h * .57f;
        int color = open ? Color.rgb(151,147,107) : Color.rgb(110,84,68);
        oval(c,x,y,h * .055f,h * .016f,Color.argb(45,145,132,84));
        float direction = next ? 1f : -1f;
        path.reset();
        path.moveTo(x - direction * h * .011f,y - h * .015f);
        path.lineTo(x + direction * h * .008f,y);
        path.lineTo(x - direction * h * .011f,y + h * .015f);
        p.setStyle(Paint.Style.STROKE);
        p.setStrokeWidth(h * .003f);
        p.setColor(color);
        c.drawPath(path,p);
        p.setStyle(Paint.Style.FILL);
        p.setTypeface(serif);
        p.setTextSize(h * .017f);
        p.setTextAlign(Paint.Align.CENTER);
        p.setColor(Color.argb(180,179,172,144));
        c.drawText(label,x,y - h * .055f,p);
    }

    private void marker(Canvas c, float x, float y, float clock) {
        y += (float) Math.sin(clock * 2.4f) * h * .003f;
        path.reset();
        path.moveTo(x,y - h * .006f);
        path.lineTo(x + h * .004f,y);
        path.lineTo(x,y + h * .006f);
        path.lineTo(x - h * .004f,y);
        path.close();
        p.setColor(Color.rgb(211,174,101));
        c.drawPath(path,p);
    }

    private void fill(Canvas c, float left, float top, float right, float bottom, int color) {
        p.setColor(color);
        p.setStyle(Paint.Style.FILL);
        c.drawRect(left * w,top * h,right * w,bottom * h,p);
    }

    private void oval(Canvas c, float x, float y, float rx, float ry, int color) {
        p.setColor(color);
        p.setStyle(Paint.Style.FILL);
        r.set(x - rx,y - ry,x + rx,y + ry);
        c.drawOval(r,p);
    }

    private void line(Canvas c, float x1, float y1, float x2, float y2, int color, float stroke) {
        linePixels(c,x1 * w,y1 * h,x2 * w,y2 * h,color,stroke);
    }

    private void linePixels(Canvas c, float x1, float y1, float x2, float y2, int color, float stroke) {
        p.setColor(color);
        p.setStrokeWidth(stroke);
        c.drawLine(x1,y1,x2,y2,p);
    }

    private static RectF box(float l, float t, float r, float b) {
        return new RectF(l,t,r,b);
    }

    private static int clampZone(int zone) {
        return Math.max(0,Math.min(NAMES.length-1,zone));
    }
}
