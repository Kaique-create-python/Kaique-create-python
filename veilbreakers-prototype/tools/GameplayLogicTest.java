package com.veilbreakers.prototype;

import android.content.SharedPreferences;
import java.util.HashMap;
import java.util.Map;

/** Tests actual campaign/collision/locomotion classes without running Android rendering. */
public final class GameplayLogicTest {
    private static int checks;

    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }

    private static void close(float actual, float expected, String message) {
        check(Math.abs(actual - expected) < .0001f, message + ": " + actual + " / " + expected);
    }

    private static void locomotion() {
        LocomotionCycle cycle = new LocomotionCycle();
        cycle.advance(21f, .1f, 720f, 420f);
        check(cycle.moving && !cycle.running, "Half-speed movement uses walk poses");
        check(cycle.phase > 0f, "Ground movement advances authored poses");
        cycle.advance(0f, .1f, 720f, 420f);
        check(!cycle.moving && !cycle.running && cycle.phase == 0f,
                "A wall stops the pose cycle even while the joystick remains held");
        cycle.advance(29.4f, .1f, 720f, 420f);
        check(cycle.running, "Running begins above the 68 percent threshold");
        cycle.advance(26.46f, .1f, 720f, 420f);
        check(cycle.running, "Running does not flicker within its hysteresis band");
        cycle.advance(23.94f, .1f, 720f, 420f);
        check(!cycle.running, "Running ends below the 58 percent threshold");
        cycle.advance(26.46f, .1f, 720f, 420f);
        check(!cycle.running, "Walking does not flicker within the same hysteresis band");
        cycle.stop();
        check(!cycle.moving && !cycle.running && cycle.phase == 0f, "Pause/attack resets locomotion");
        LocomotionCycle split = new LocomotionCycle();
        LocomotionCycle single = new LocomotionCycle();
        for (int frame = 0; frame < 10; frame++) split.advance(10f, .02f, 720f, 600f);
        single.advance(100f, .2f, 720f, 600f);
        close(split.phase, single.phase, "Pose phase depends on traveled distance across frame rates");
    }

    private static void story() {
        MemoryPreferences empty = new MemoryPreferences();
        StoryState state = new StoryState();
        state.load(empty);
        check(!state.introSeen && !state.swordFound && state.progressStep() == 0,
                "An empty save starts with the opening and missing sword");
        check(!state.canEnterNext(), "The starting exit requires recovering the sword");
        MemoryPreferences fresh = new MemoryPreferences();
        fresh.edit().putInt("world_version", StoryState.WORLD_VERSION).putBoolean("has_save", true).apply();
        state.load(fresh);
        check(!state.introSeen && !state.swordFound, "New Game is not mistaken for a legacy save");
        MemoryPreferences legacy = new MemoryPreferences();
        legacy.edit().putInt("stat_level", 7).putBoolean("has_save", true).apply();
        state.load(legacy);
        check(state.introSeen && state.swordFound && state.zone == 0 && !state.chestOpened,
                "A legacy character keeps its sword while beginning the new campaign");
        state = new StoryState();
        for (String interaction : new String[] {"intro", "sword", "chest", "mara", "ivo", "trace", "gate", "altar"}) {
            String[][] pages = state.dialogue(interaction);
            check(pages.length > 0 && pages[0].length == 2, "Every interaction supplies speaker/text pages");
        }
        check(state.progressStep() == 0 && !state.introSeen && !state.swordFound && !state.chestOpened,
                "Reading or reopening dialogue does not grant rewards or commit story events");
        state.swordFound = true;
        check(state.progressStep() == 1 && state.canEnterNext(), "Recovering sword unlocks room one");
        state.zone = 1;
        check(!state.canEnterNext(), "The central square cannot be skipped");
        state.chestOpened = true;
        check(state.progressStep() == 2 && !state.canEnterNext(), "Chest alone does not unlock the square");
        state.metMara = true;
        check(state.progressStep() == 3 && !state.canEnterNext(), "Mara still needs the Veilborn defeated");
        state.clearedMask = 1;
        check(!state.canEnterNext(), "Defeating an enemy in another room cannot unlock the square");
        state.clearedMask |= 1 << 1;
        check(state.progressStep() == 4 && state.canEnterNext(), "Square objectives unlock the burnt houses");
        state.zone = 2;
        state.metIvo = true;
        check(state.progressStep() == 5 && !state.canEnterNext(), "Ivo directs the player to the ash trace");
        state.traceFound = true;
        check(state.progressStep() == 6 && state.canEnterNext(), "The ash trace unlocks the aqueduct");
        state.zone = 3;
        check(!state.canEnterNext(), "The aqueduct boss blocks the northern gate");
        state.bossDefeated = true;
        check(state.progressStep() == 7 && state.canEnterNext(), "Defeating the boss unlocks the northern gate");
        state.zone = 4;
        check(!state.canEnterNext(), "The northern gate scene must finish before entering the sanctuary");
        state.questComplete = true;
        check(state.progressStep() == 8 && state.canEnterNext(), "Finishing the gate scene unlocks the sanctuary");
        state.zone = 5;
        state.altarUsed = true;
        state.introSeen = true;
        check(state.progressStep() == 9 && !state.canEnterNext(), "The altar concludes the playable chapter");
        state.save(empty.edit());
        StoryState restored = new StoryState();
        restored.load(empty);
        check(restored.progressStep() == 9 && restored.zone == 5 && restored.introSeen,
                "Campaign completion, room and introductory state survive save/load");
        restored.save(empty.edit());
        StoryState repeated = new StoryState();
        repeated.load(empty);
        check(repeated.progressStep() == 9 && repeated.chestOpened && repeated.altarUsed,
                "Repeated saves keep completed interactions completed");
        empty.edit().putInt("world_zone", 999).putInt("world_cleared_mask", 255).apply();
        restored.load(empty);
        check(restored.zone == 5 && restored.clearedMask == 63, "Invalid save values are constrained");
    }

    private static void world() {
        VarynMap map = new VarynMap();
        for (int[] size : new int[][] {{1280, 720}, {1920, 1080}}) {
            map.resize(size[0], size[1]);
            float w = size[0], h = size[1], radius = h * .027f;
            for (int zone = 0; zone < 6; zone++) {
                for (int column = 1; column < 20; column++) {
                    check(!map.blocked(zone, w * column / 20f, h * .57f, radius),
                            "The central traversal corridor stays passable in room " + zone);
                }
                check(VarynMap.zoneName(zone).length() > 0, "Every authored room has a visible name");
            }
            check(map.blocked(0, w * .20f, h * .35f, radius), "Ruined building footprint blocks movement");
            check(map.blocked(0, w * .55f, h * .84f, radius), "Lower rubble blocks movement");
            check(!map.blocked(0, w * .20f, h * .44f, 0f), "The building silhouette does not block nearby floor");
            StoryState story = new StoryState();
            float sx = map.interactionX(VarynMap.SWORD), sy = map.interactionY(VarynMap.SWORD);
            check(VarynMap.SWORD.equals(map.nearestInteraction(0, story, sx, sy)),
                    "The missing sword can be reached at its authored position");
            check(!map.blocked(0, sx, sy, radius), "The sword interaction is outside scenery collisions");
            story.swordFound = true;
            check(map.nearestInteraction(0, story, sx, sy).isEmpty(), "A recovered sword cannot be collected twice");
            float cx = map.interactionX(VarynMap.CHEST), cy = map.interactionY(VarynMap.CHEST);
            check(VarynMap.CHEST.equals(map.nearestInteraction(1, story, cx, cy)), "The square chest is reachable");
            story.chestOpened = true;
            check(!VarynMap.CHEST.equals(map.nearestInteraction(1, story, cx, cy)), "An opened chest is removed from available loot");
            check(VarynMap.PREVIOUS.equals(map.nearestInteraction(5, story,
                    map.interactionX(VarynMap.PREVIOUS), map.interactionY(VarynMap.PREVIOUS))),
                    "The final room retains a route back through Varyn");
        }
        map.release();
    }

    public static void main(String[] arguments) {
        locomotion();
        story();
        world();
        System.out.println("Gameplay logic passed: " + checks + " checks (story, save migration, world collisions, locomotion)");
    }

    private static final class MemoryPreferences implements SharedPreferences {
        private final Map<String, Object> values = new HashMap<>();
        public boolean contains(String key) { return values.containsKey(key); }
        public boolean getBoolean(String key, boolean fallback) {
            Object value = values.get(key); return value instanceof Boolean ? (Boolean) value : fallback;
        }
        public int getInt(String key, int fallback) {
            Object value = values.get(key); return value instanceof Integer ? (Integer) value : fallback;
        }
        public Editor edit() {
            return new Editor() {
                public Editor putInt(String key, int value) { values.put(key, value); return this; }
                public Editor putBoolean(String key, boolean value) { values.put(key, value); return this; }
                public Editor clear() { values.clear(); return this; }
                public void apply() { }
            };
        }
    }
}
