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
                check(!map.blocked(zone, w * .20f, h * .60f, radius),
                        "The forward room entry stays outside scenery in room " + zone);
                check(!map.blocked(zone, w * .82f, h * .60f, radius),
                        "The returning room entry stays outside scenery in room " + zone);
                check(!map.blocked(zone, map.interactionX(VarynMap.NEXT), map.interactionY(VarynMap.NEXT), radius),
                        "The right exit remains physically accessible in room " + zone);
                check(!map.blocked(zone, map.interactionX(VarynMap.PREVIOUS), map.interactionY(VarynMap.PREVIOUS), radius),
                        "The left exit remains physically accessible in room " + zone);
            }
            check(map.blocked(0, w * .20f, h * .44f, radius), "The generated ruin's actual foundation blocks movement");
            check(map.blocked(0, w * .55f, h * .84f, radius), "Lower rubble blocks movement");
            check(!map.blocked(0, w * .20f, h * .55f, radius), "The floor beyond the foundation remains walkable");
            check(!map.blocked(0, w * .20f, h * .35f, 0f), "The building's upper silhouette is not its collision footprint");
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
            check(!map.blocked(1, cx, cy, radius), "The plaza chest is outside the generated fountain's foundation");
            float mx = map.interactionX(VarynMap.MARA), my = map.interactionY(VarynMap.MARA);
            check(VarynMap.MARA.equals(map.nearestInteraction(1, story, mx, my)), "Mara can be spoken to beside the plaza fountain");
            check(!map.blocked(1, mx, my, radius), "Mara's relocated feet remain on accessible floor");
            float ix = map.interactionX(VarynMap.IVO), iy = map.interactionY(VarynMap.IVO);
            check(VarynMap.IVO.equals(map.nearestInteraction(2, story, ix, iy)), "Ivo can be reached outside the burnt houses");
            check(!map.blocked(2, ix, iy, radius), "Ivo's feet do not intersect the new house foundations");
            float tx = map.interactionX(VarynMap.TRACE), ty = map.interactionY(VarynMap.TRACE);
            check(!VarynMap.TRACE.equals(map.nearestInteraction(2, story, tx, ty)),
                    "The disappearances clue remains unavailable until Ivo explains it");
            story.metIvo = true;
            check(VarynMap.TRACE.equals(map.nearestInteraction(2, story, tx, ty)), "Ivo's clue can then be investigated");
            check(!map.blocked(2, tx, ty, radius), "The ash trace remains outside the new ruin foundations");
            story.traceFound = true;
            check(!VarynMap.TRACE.equals(map.nearestInteraction(2, story, tx, ty)), "An examined clue cannot be collected repeatedly");
            float ax = map.interactionX(VarynMap.ALTAR), ay = map.interactionY(VarynMap.ALTAR);
            check(VarynMap.ALTAR.equals(map.nearestInteraction(5, story, ax, ay)), "The sanctuary altar is reachable for rest");
            check(!map.blocked(5, ax, ay, radius), "The altar's relocated feet stay outside sanctuary pillars");
            check(!map.blocked(1, w * .74f, h * .57f, radius), "The plaza enemy spawns on reachable floor");
            check(!map.blocked(3, w * .66f, h * .57f, radius), "The aqueduct boss spawns in the traverse corridor");
            check(map.blocked(0, w * .20f, h * .44f, radius)
                    && !map.blocked(0, w * .20f, h * .55f, radius),
                    "Collecting items and changing quest flags cannot alter immutable scenery collision");
            check(VarynMap.PREVIOUS.equals(map.nearestInteraction(5, story,
                    map.interactionX(VarynMap.PREVIOUS), map.interactionY(VarynMap.PREVIOUS))),
                    "The final room retains a route back through Varyn");
        }
        map.release();
    }

    private static void inventory() {
        MemoryPreferences prefs = new MemoryPreferences();
        PlayerStats stats = new PlayerStats();
        StoryState story = new StoryState();
        InventoryState inventory = new InventoryState();
        inventory.load(prefs, story, stats);
        check(inventory.occupiedSlots() == 0 && !inventory.swordEquipped && stats.attack == 12,
                "A new journey has no phantom items or equipment bonus");
        check(!inventory.discovered(InventoryState.SWORD) && !inventory.discovered(InventoryState.IVO_NOTE),
                "The empty inventory cannot reveal an undiscovered weapon or mission clue");
        story.swordFound = true;
        check(inventory.grantSword(stats) && !inventory.grantSword(stats), "Sword discovery is granted once");
        check(inventory.count(InventoryState.SWORD) == 1 && inventory.swordEquipped
                && stats.attack == 16 && stats.weaponAttackBonus == 4, "Recovered sword equips its real ATK bonus");
        stats.attack += 6;
        inventory.activate(InventoryState.SWORD, stats);
        check(!inventory.swordEquipped && stats.attack == 18 && stats.weaponAttackBonus == 0,
                "Unequipping removes only equipment, preserving attribute upgrades");
        inventory.activate(InventoryState.SWORD, stats);
        stats.setWeaponAttackBonus(4);
        stats.setWeaponAttackBonus(4);
        check(inventory.swordEquipped && stats.attack == 22, "Re-equipping or repeating reconciliation cannot stack ATK");
        story.chestOpened = true;
        check(inventory.grantChestSupplies() && !inventory.grantChestSupplies(), "Chest supplies are granted once");
        check(inventory.count(InventoryState.BANDAGE) == 3 && inventory.count(InventoryState.MANA_DRAUGHT) == 2,
                "Chest supplies are physical counted items");
        stats.hp = stats.maxHp - 2;
        inventory.activate(InventoryState.BANDAGE, stats);
        check(stats.hp == stats.maxHp && inventory.count(InventoryState.BANDAGE) == 2,
                "Healing near maximum is capped and consumes exactly one item");
        inventory.activate(InventoryState.BANDAGE, stats);
        check(inventory.count(InventoryState.BANDAGE) == 2, "Full health cannot waste an atadura");
        stats.hp = 0;
        inventory.activate(InventoryState.BANDAGE, stats);
        check(stats.hp == 0 && inventory.count(InventoryState.BANDAGE) == 2,
                "The defeated character cannot consume a healing item behind its return timer");
        stats.hp = 30;
        inventory.activate(InventoryState.BANDAGE, stats);
        check(stats.hp == 75 && inventory.count(InventoryState.BANDAGE) == 1, "An atadura restores 45 real HP");
        stats.mana = stats.maxMana - 1;
        inventory.activate(InventoryState.MANA_DRAUGHT, stats);
        check(stats.mana == stats.maxMana && inventory.count(InventoryState.MANA_DRAUGHT) == 1,
                "Mana restoration respects its cap and consumes exactly one tonic");
        inventory.activate(InventoryState.MANA_DRAUGHT, stats);
        check(inventory.count(InventoryState.MANA_DRAUGHT) == 1, "Full Mana cannot waste a tonic");
        stats.mana = 0;
        inventory.activate(InventoryState.MANA_DRAUGHT, stats);
        check(stats.mana == 25 && inventory.count(InventoryState.MANA_DRAUGHT) == 0,
                "The final tonic restores 25 Mana and leaves an empty stack");
        check(inventory.discovered(InventoryState.MANA_DRAUGHT),
                "A consumed item retains its discovered details without implying a remaining quantity");
        inventory.activate(InventoryState.MANA_DRAUGHT, stats);
        check(stats.mana == 25 && inventory.count(InventoryState.MANA_DRAUGHT) == 0,
                "An empty stack cannot create free Mana or negative quantities");
        story.metIvo = true;
        check(inventory.grantIvoNote() && !inventory.grantIvoNote(), "Ivo's clue is granted once");
        inventory.activate(InventoryState.IVO_NOTE, stats);
        check(inventory.count(InventoryState.IVO_NOTE) == 1, "Reading a mission clue never consumes it");
        SharedPreferences.Editor editor = prefs.edit();
        stats.save(editor); story.save(editor); inventory.save(editor); editor.apply();
        PlayerStats restoredStats = new PlayerStats(); restoredStats.load(prefs);
        StoryState restoredStory = new StoryState(); restoredStory.load(prefs);
        InventoryState restored = new InventoryState(); restored.load(prefs, restoredStory, restoredStats);
        check(restoredStats.attack == 22 && restoredStats.hp == 75 && restoredStats.mana == 25
                && restored.swordEquipped, "Continue keeps equipment and resource changes without adding its bonus twice");
        check(restored.count(InventoryState.BANDAGE) == 1 && restored.count(InventoryState.MANA_DRAUGHT) == 0
                && restored.count(InventoryState.IVO_NOTE) == 1,
                "Consumed supplies and mission clues survive Continue");
        for (int i = 0; i < 8; i++) restored.synchronizeStory(restoredStory, restoredStats);
        check(restoredStats.attack == 22 && restored.count(InventoryState.BANDAGE) == 1
                && restored.count(InventoryState.MANA_DRAUGHT) == 0,
                "Revisiting completed discoveries cannot replenish items or stack equipment");
        restored.activate(InventoryState.SWORD, restoredStats);
        editor = prefs.edit(); restoredStats.save(editor); restoredStory.save(editor); restored.save(editor); editor.apply();
        PlayerStats unarmedStats = new PlayerStats(); unarmedStats.load(prefs);
        InventoryState unarmed = new InventoryState(); unarmed.load(prefs, restoredStory, unarmedStats);
        check(!unarmed.swordEquipped && unarmedStats.attack == 18 && unarmed.count(InventoryState.SWORD) == 1,
                "An unequipped sword remains owned and unequipped after Continue");

        MemoryPreferences oldSave = new MemoryPreferences();
        oldSave.edit().putInt("world_version", 180).putBoolean("has_save", true)
                .putInt("stat_attack", 26).putInt("stat_hp", 77).putInt("stat_mana", 13)
                .putBoolean("story_sword_found", true).putBoolean("story_chest_opened", true)
                .putBoolean("story_met_ivo", true).apply();
        PlayerStats migratedStats = new PlayerStats(); migratedStats.load(oldSave);
        StoryState migratedStory = new StoryState(); migratedStory.load(oldSave);
        InventoryState migrated = new InventoryState(); migrated.load(oldSave, migratedStory, migratedStats);
        check(migratedStats.attack == 30 && migratedStats.hp == 77 && migratedStats.mana == 13,
                "v1.8 migration preserves resources and base ATK while applying the new equipment once");
        check(migrated.count(InventoryState.BANDAGE) == 3 && migrated.count(InventoryState.MANA_DRAUGHT) == 2
                && migrated.count(InventoryState.IVO_NOTE) == 1,
                "Completed v1.8 discoveries migrate to the visible inventory");
        oldSave.edit().clear().putInt("world_version", StoryState.WORLD_VERSION).putBoolean("has_save", true).apply();
        PlayerStats newStats = new PlayerStats();
        StoryState newStory = new StoryState(); newStory.load(oldSave);
        InventoryState newInventory = new InventoryState(); newInventory.load(oldSave, newStory, newStats);
        check(newInventory.occupiedSlots() == 0 && newStats.attack == 12 && !newInventory.swordEquipped,
                "New Game clears items, equipment and migration rewards together");
    }

    public static void main(String[] arguments) {
        locomotion();
        story();
        world();
        inventory();
        System.out.println("Gameplay logic passed: " + checks + " checks (story, save migration, world collisions, locomotion, inventory/equipment)");
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
