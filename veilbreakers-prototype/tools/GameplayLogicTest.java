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
        check(state.progressStep() == 9 && !state.canEnterNext(), "Resting alone does not skip learning the sanctuary rune");
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
        empty.edit().putInt("world_zone", 999).putInt("world_cleared_mask", 1023).apply();
        restored.load(empty);
        check(restored.zone == 8 && restored.clearedMask == 511, "Invalid save values are constrained to the nine-room world");
    }

    private static void secondChapter() {
        StoryState story = new StoryState();
        story.introSeen = story.swordFound = story.chestOpened = story.metMara = story.metIvo = true;
        story.traceFound = story.bossDefeated = story.questComplete = true;
        story.clearedMask = (1 << 1) | (1 << 3);
        story.zone = 5;
        check(story.progressStep() == 8 && !story.canEnterNext(), "Chapter two starts with the sanctuary still required");
        story.altarUsed = true;
        check(!story.canEnterNext(), "Rest cannot bypass the Ember rune");
        for (String id : new String[] {"ember_rune", "echo_trace", "frost_rune", "watcher"}) {
            String[][] pages = story.dialogue(id);
            check(pages.length > 0, "New chapter interactions have dialogue: " + id);
            for (String[] page : pages) {
                check(page.length == 2 && !page[0].isEmpty() && page[1].length() <= 105,
                        "New speaker/text pages fit the dialogue presentation");
            }
        }
        check(!story.emberLearned && !story.frostLearned && !story.echoTraceFound && !story.watcherMet,
                "Reading the new dialogue cannot learn runes or complete discoveries");
        story.emberLearned = true;
        check(story.canEnterNext() && story.progressStep() == 10, "Learning Ember opens the road beyond the sanctuary");
        story.zone = 6;
        story.clearedMask |= 1 << 5;
        check(!story.canEnterNext(), "A different room's clear cannot skip the road waves");
        story.clearedMask |= 1 << 6;
        check(story.canEnterNext() && story.progressStep() == 11, "Completing the road waves opens the crypt");
        story.zone = 7;
        check(!story.canEnterNext(), "The crypt cannot be crossed without its discoveries and encounters");
        story.echoTraceFound = true;
        check(!story.canEnterNext() && story.progressStep() == 12, "The echo alone does not unlock the crypt exit");
        story.frostLearned = true;
        check(!story.canEnterNext() && story.progressStep() == 13, "Learning Frost does not skip the crypt waves");
        story.clearedMask |= 1 << 7;
        check(story.canEnterNext() && story.progressStep() == 14, "The crypt's rune, clue and encounters unlock the tower");
        story.zone = 8;
        story.watcherMet = true;
        check(!story.canCompleteEchoQuest() && story.progressStep() == 15, "Meeting Ivo cannot skip the tower encounters");
        story.clearedMask |= 1 << 8;
        check(story.canCompleteEchoQuest() && story.progressStep() == 16, "The last conversation becomes eligible after all chapter encounters");
        story.echoQuestComplete = true;
        check(story.progressStep() == 17 && !story.canEnterNext(), "Finishing the second chapter leaves no unimplemented forward exit");
        MemoryPreferences prefs = new MemoryPreferences(); story.save(prefs.edit());
        StoryState restored = new StoryState(); restored.load(prefs);
        check(restored.zone == 8 && restored.emberLearned && restored.frostLearned && restored.echoTraceFound
                && restored.watcherMet && restored.echoQuestComplete && restored.progressStep() == 17,
                "All second-chapter discoveries survive Continue");
        MemoryPreferences old = new MemoryPreferences();
        old.edit().putInt("world_version", 180).putBoolean("story_quest_complete", true)
                .putBoolean("story_altar_used", true).putInt("world_zone", 5).apply();
        StoryState migrated = new StoryState(); migrated.load(old);
        check(migrated.altarUsed && migrated.emberLearned && migrated.canEnterNext() && !migrated.echoQuestComplete,
                "An existing v1.9 sanctuary save gains its altar rune without falsely finishing chapter two");
    }

    private static void runes() {
        MemoryPreferences prefs = new MemoryPreferences();
        StoryState story = new StoryState();
        RuneState runes = new RuneState(); runes.load(prefs, story);
        check(runes.getSelectedSpell() == RuneState.ARCANA && runes.isUnlocked(RuneState.ARCANA),
                "Arcana VIII remains available on every new journey");
        check(!runes.selectSpell(RuneState.EMBER) && !runes.selectSpell(RuneState.FROST)
                && runes.getSelectedSpell() == RuneState.ARCANA, "Locked runes cannot replace the prepared spell");
        check(runes.unlock(RuneState.EMBER) && !runes.unlock(RuneState.EMBER), "Rune learning reports a new discovery only once");
        check(runes.selectSpell(RuneState.EMBER) && runes.getSelectedSpell() == RuneState.EMBER,
                "A learned rune can be prepared for actual combat");
        check(runes.unlockPower() && !runes.unlockPower() && runes.powerUnlocked,
                "The Mark power is learned once");
        check(!runes.selectSpell(RuneState.MARK) && runes.getSelectedSpell() == RuneState.EMBER,
                "The separate Mark power cannot occupy the projectile spell slot");
        runes.unlock(RuneState.FROST); runes.save(prefs.edit());
        RuneState restored = new RuneState(); restored.load(prefs, story);
        check(restored.getSelectedSpell() == RuneState.EMBER && restored.emberUnlocked && restored.frostUnlocked
                && restored.powerUnlocked, "Continue preserves rune learning, power and prepared magic");
        prefs.edit().putInt("rune_selected_spell", 999).apply(); restored.load(prefs, story);
        check(restored.getSelectedSpell() == RuneState.ARCANA, "An invalid saved spell safely falls back to Arcana");
        MemoryPreferences corrupted = new MemoryPreferences();
        corrupted.edit().putInt("rune_selected_spell", RuneState.FROST).apply(); restored.load(corrupted, story);
        check(restored.getSelectedSpell() == RuneState.ARCANA, "A saved selection cannot bypass its locked rune");
        story.altarUsed = story.emberLearned = true; restored.load(new MemoryPreferences(), story);
        check(restored.emberUnlocked && !restored.frostUnlocked && !restored.powerUnlocked,
                "v1.9 migration grants only the already-discovered sanctuary rune");
        story.frostLearned = story.echoTraceFound = true; restored.synchronizeStory(story);
        check(restored.powerUnlocked && !story.echoQuestComplete,
                "The Mark is available for crypt and tower fights before the last quest reward");
        story.echoQuestComplete = true; restored.synchronizeStory(story);
        check(restored.frostUnlocked && restored.powerUnlocked && restored.getSelectedSpell() == RuneState.ARCANA,
                "Campaign discovery learns magic without unexpectedly replacing the player's selection");
        check(RuneState.manaCost(RuneState.ARCANA) == 18 && RuneState.manaCost(RuneState.EMBER) == 22
                && RuneState.manaCost(RuneState.FROST) == 25 && RuneState.manaCost(RuneState.MARK) == 30,
                "Rune UI costs match the agreed combat balance");
        close(RuneState.cooldown(RuneState.EMBER), 1.6f, "Ember cooldown");
        close(RuneState.cooldown(RuneState.FROST), 2.0f, "Frost cooldown");
        close(RuneState.cooldown(RuneState.MARK), 12f, "Mark cooldown");
        prefs.edit().clear().apply(); restored.load(prefs, new StoryState());
        check(!restored.emberUnlocked && !restored.frostUnlocked && !restored.powerUnlocked
                && restored.getSelectedSpell() == RuneState.ARCANA, "New Game clears learned runes and power together");
    }

    private static void world() {
        VarynMap map = new VarynMap();
        for (int[] size : new int[][] {{1280, 720}, {1920, 1080}}) {
            map.resize(size[0], size[1]);
            float w = size[0], h = size[1], radius = h * .027f;
            for (int zone = 0; zone < 9; zone++) {
                StoryState story = new StoryState(); story.zone = zone;
                if (zone >= 5) story.questComplete = true;
                if (zone >= 6) story.altarUsed = story.emberLearned = true;
                map.setStory(story);
                check(VarynMap.zoneName(zone).length() > 0, "Every authored room has a visible name");
                check(map.blocked(zone, w * .50f, h * .30f, 0f), "Sky and upper architecture cannot be walked on in room " + zone);
                check(map.blocked(zone, w * .50f, map.walkTop(zone) + radius * .5f, radius),
                        "The full foot radius must stay below the ground's top edge in room " + zone);
                check(map.blocked(zone, w * .50f, map.walkBottom(zone) - radius * .5f, radius),
                        "The full foot radius must stay above the ground's bottom edge in room " + zone);
                check(!map.blocked(zone, w * .20f, h * .60f, radius),
                        "The forward room entry stays outside scenery in room " + zone);
                check(!map.blocked(zone, w * .82f, h * .60f, radius),
                        "The returning room entry stays outside scenery in room " + zone);
                ReachableFloor floor = new ReachableFloor(map, zone, w, h, radius);
                check(floor.reaches(w * .82f, h * .60f), "Forward and return entries share a connected ground route in room " + zone);
                if (zone < 8) check(floor.interacts(VarynMap.NEXT, story), "The forward exit has a reachable approach in room " + zone);
                if (zone > 0) check(floor.interacts(VarynMap.PREVIOUS, story), "The returning exit has a reachable approach in room " + zone);
                if (zone == 0) {
                    check(floor.interacts(VarynMap.SWORD, story), "The missing sword is reachable without walking through scenery");
                    story.swordFound = true;
                    check(!floor.interacts(VarynMap.SWORD, story), "A recovered sword cannot be collected twice");
                    check(map.blocked(zone, w * .85f, h * .70f, radius), "Visible foreground rubble blocks the player's feet");
                } else if (zone == 1) {
                    check(floor.interacts(VarynMap.CHEST, story) && floor.interacts(VarynMap.MARA, story),
                            "Chest and Mara have reachable approaches around their solid footprints");
                    float cx = map.interactionX(VarynMap.CHEST), cy = map.interactionY(VarynMap.CHEST);
                    float mx = map.interactionX(VarynMap.MARA), my = map.interactionY(VarynMap.MARA);
                    check(map.blocked(zone,cx,cy,radius) && map.blocked(zone,mx,my,radius),
                            "Standing inside the chest or Mara is forbidden");
                    check(!map.clearLine(zone,cx-h*.13f,cy,cx+h*.13f,cy,0f), "A line through the chest is obstructed");
                    check(!map.clearLine(zone,mx-h*.12f,my,mx+h*.12f,my,0f), "A line through Mara is obstructed");
                    check(map.clearLine(zone,w*.38f,h*.70f,w*.74f,h*.70f,radius), "The lower plaza route around props remains open");
                    story.chestOpened = true;
                    check(!floor.interacts(VarynMap.CHEST,story) && map.blocked(zone,cx,cy,radius),
                            "Opening a chest removes repeated loot while preserving its physical footprint");
                } else if (zone == 2) {
                    check(floor.interacts(VarynMap.IVO,story), "Ivo can be approached without standing inside him");
                    check(map.blocked(zone,map.interactionX(VarynMap.IVO),map.interactionY(VarynMap.IVO),0f),
                            "Ivo occupies a solid physical footprint before leaving the houses");
                    check(!floor.interacts(VarynMap.TRACE,story), "The trace remains unavailable before Ivo explains it");
                    story.metIvo = true;
                    check(floor.interacts(VarynMap.TRACE,story), "The trace can be approached after Ivo's conversation");
                    story.traceFound = true;
                    check(!floor.interacts(VarynMap.TRACE,story), "An examined trace cannot be collected repeatedly");
                    story.emberLearned = true;
                    check(!floor.interacts(VarynMap.IVO,story)
                            && !map.blocked(zone,map.interactionX(VarynMap.IVO),map.interactionY(VarynMap.IVO),0f),
                            "Ivo's old-room interaction and collider disappear when he moves to the tower");
                } else if (zone == 5) {
                    check(floor.interacts(VarynMap.ALTAR,story) && floor.interacts(VarynMap.EMBER_RUNE,story),
                            "Rest and the Ember rune can be reached around the solid altar");
                    float ax = map.interactionX(VarynMap.ALTAR), ay = map.interactionY(VarynMap.ALTAR);
                    check(map.blocked(zone,ax,ay,radius), "The player cannot stand inside the altar");
                    check(!map.clearLine(zone,ax-h*.15f,ay,ax+h*.15f,ay,0f), "A line through the altar is obstructed");
                    story.emberLearned = true;
                    check(!floor.interacts(VarynMap.EMBER_RUNE,story), "An already-learned Ember rune no longer offers repeated discovery");
                } else if (zone == 7) {
                    check(floor.interacts(VarynMap.ECHO_TRACE,story) && floor.interacts(VarynMap.FROST_RUNE,story),
                            "The crypt's echo and Frost inscription both have reachable approaches");
                    story.echoTraceFound = story.frostLearned = true;
                    check(!floor.interacts(VarynMap.ECHO_TRACE,story) && !floor.interacts(VarynMap.FROST_RUNE,story),
                            "The crypt's completed discoveries cannot repeat");
                } else if (zone == 8) {
                    check(floor.interacts(VarynMap.WATCHER,story), "Ivo at the tower has a reachable conversation approach");
                    check(map.blocked(zone,map.interactionX(VarynMap.WATCHER),map.interactionY(VarynMap.WATCHER),radius),
                            "The tower survivor has a solid footprint");
                    check(!floor.interacts(VarynMap.NEXT,story), "The tower has no forward exit into an unimplemented room");
                }
            }
            map.setStory(new StoryState());
            check(!map.blocked(1,w*.74f,h*.57f,radius) && !map.blocked(3,w*.66f,h*.57f,radius),
                    "The initial combat spawn positions remain on free ground");
        }
        map.release();
    }

    /** A reachable approach is a connected free-foot node, never the solid center of an object. */
    private static final class ReachableFloor {
        private static final int COLS=90, ROWS=26;
        private final VarynMap map;
        private final int zone;
        private final float radius,xMin,xStep,yMin,yStep;
        private final boolean[] reached=new boolean[COLS*ROWS];

        ReachableFloor(VarynMap map,int zone,float w,float h,float radius) {
            this.map=map;this.zone=zone;this.radius=radius;
            xMin=w*.055f;xStep=w*.89f/(COLS-1);
            yMin=map.walkTop(zone)+radius+h*.001f;
            yStep=(map.walkBottom(zone)-radius-h*.001f-yMin)/(ROWS-1);
            float startX=w*.20f,startY=h*.60f;
            int[] queue=new int[reached.length];int head=0,tail=0;
            for(int cell=0;cell<reached.length;cell++) {
                float dx=x(cell)-startX,dy=y(cell)-startY;
                if(dx*dx+dy*dy <= 2f*(xStep*xStep+yStep*yStep)
                        && !map.blocked(zone,x(cell),y(cell),radius)
                        && map.clearLine(zone,startX,startY,x(cell),y(cell),radius)) {
                    reached[cell]=true;queue[tail++]=cell;
                }
            }
            while(head<tail) {
                int cell=queue[head++],col=cell%COLS,row=cell/COLS;
                for(int direction=0;direction<4;direction++) {
                    int nc=col+(direction==0?-1:direction==1?1:0);
                    int nr=row+(direction==2?-1:direction==3?1:0);
                    if(nc<0||nc>=COLS||nr<0||nr>=ROWS)continue;
                    int next=nr*COLS+nc;
                    if(!reached[next]&&!map.blocked(zone,x(next),y(next),radius)
                            &&map.clearLine(zone,x(cell),y(cell),x(next),y(next),radius)) {
                        reached[next]=true;queue[tail++]=next;
                    }
                }
            }
        }

        private float x(int cell) { return xMin+(cell%COLS)*xStep; }
        private float y(int cell) { return yMin+(cell/COLS)*yStep; }

        boolean reaches(float targetX,float targetY) {
            if(map.blocked(zone,targetX,targetY,radius))return false;
            for(int cell=0;cell<reached.length;cell++)if(reached[cell]) {
                float dx=x(cell)-targetX,dy=y(cell)-targetY;
                if(dx*dx+dy*dy<=2f*(xStep*xStep+yStep*yStep)
                        &&map.clearLine(zone,x(cell),y(cell),targetX,targetY,radius))return true;
            }
            return false;
        }

        boolean interacts(String id,StoryState story) {
            for(int cell=0;cell<reached.length;cell++)if(reached[cell]
                    &&id.equals(map.nearestInteraction(zone,story,x(cell),y(cell))))return true;
            return false;
        }
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
        check(newInventory.addLoot(InventoryState.BANDAGE, 1) == 1 && newInventory.discovered(InventoryState.BANDAGE),
                "Encounter loot is visible before opening the story chest");
        newStats.hp = newStats.maxHp - 50; newInventory.activate(InventoryState.BANDAGE, newStats);
        editor = oldSave.edit(); newStats.save(editor); newStory.save(editor); newInventory.save(editor); editor.apply();
        InventoryState looted = new InventoryState(); looted.load(oldSave, newStory, newStats);
        check(looted.count(InventoryState.BANDAGE) == 0 && looted.discovered(InventoryState.BANDAGE),
                "Consumed wave loot retains its discovered details after Continue");
        check(looted.addLoot(InventoryState.MANA_DRAUGHT, Integer.MAX_VALUE) == 99
                && looted.count(InventoryState.MANA_DRAUGHT) == 99,
                "Large loot quantities clamp safely without integer overflow");
        check(looted.addLoot(InventoryState.MANA_DRAUGHT, 1) == 0
                && looted.addLoot(InventoryState.BANDAGE, -10) == 0
                && looted.addLoot(InventoryState.SWORD, 1) == 0
                && looted.addLoot(999, 1) == 0,
                "Capacity, invalid quantities and key items cannot corrupt encounter loot");
    }

    private static void encounters() {
        EncounterState state=new EncounterState();
        int count=0;
        for(int zone=0;zone<9;zone++)count+=state.total(zone);
        check(count==15 && state.total(1)==3 && state.total(3)==3 && state.total(6)==3
                && state.total(7)==4 && state.total(8)==2, "Five authored combat rooms provide fifteen sequential opponents");
        check(state.finished(0)&&state.finished(2)&&state.finished(5), "Safe rooms do not invent encounters");
        check(state.wave(1)==0 && state.hp(1)==70 && state.profile(1,0).attack==18,
                "The first plaza encounter has the authored harder profile");
        EncounterState.Profile finalEnemy=state.profile(8,1);
        check(finalEnemy.hp==160 && finalEnemy.attack==28 && finalEnemy.elite,
                "The tower finale uses its stronger elite profile");
        MemoryPreferences prefs=new MemoryPreferences();
        state.damage(1,0,45);state.save(prefs.edit());
        EncounterState restored=new EncounterState();restored.load(prefs,0);
        check(restored.wave(1)==0&&restored.hp(1)==45, "Continue preserves damage to the active unfinished opponent");
        restored.resetUnfinishedHp(1);
        check(restored.wave(1)==0&&restored.hp(1)==70, "Player defeat heals only the unfinished enemy");
        check(restored.claimDefeat(1,0)&&restored.wave(1)==1&&!restored.finished(1),
                "One kill advances exactly one plaza wave without clearing the room");
        check(!restored.claimDefeat(1,0)&&restored.wave(1)==1, "A repeated death callback cannot claim the next wave's reward");
        int secondHp=restored.hp(1);
        restored.damage(1,0,1);
        check(restored.hp(1)==secondHp, "A stale damage callback cannot affect a newly spawned opponent");
        restored.damage(1,1,30);restored.resetUnfinishedHp(1);
        check(restored.wave(1)==1&&restored.hp(1)==secondHp, "Defeat keeps every already-paid wave while healing the active one");
        check(restored.claimDefeat(1,1)&&restored.claimDefeat(1,2)&&restored.finished(1)&&restored.hp(1)==0,
                "Only the last authored wave clears the plaza encounter");
        check(!restored.claimDefeat(1,2)&&!restored.claimDefeat(1,3), "A finished encounter cannot pay more kill rewards");
        restored.save(prefs.edit());
        EncounterState completed=new EncounterState();completed.load(prefs,0);
        check(completed.finished(1)&&completed.wave(1)==3, "The completed wave ledger persists even before consulting a room mask");
        EncounterState migrated=new EncounterState();migrated.load(new MemoryPreferences(),(1<<1)|(1<<3));
        check(migrated.finished(1)&&migrated.finished(3)&&!migrated.finished(6)
                && !migrated.claimDefeat(1,0), "v1.9 cleared rooms stay cleared without backfilling rewards or skipping chapter two");
        for(int zone:new int[]{3,6,7,8}) {
            EncounterState fresh=new EncounterState();
            for(int wave=0;wave<fresh.total(zone);wave++) {
                check(fresh.claimDefeat(zone,wave), "Each authored wave can be claimed once in room "+zone);
                check(fresh.finished(zone)==(wave+1==fresh.total(zone)), "Room clear follows its last wave in room "+zone);
            }
        }
    }

    private static void spells() {
        check(SpellProfile.of(RuneState.ARCANA).damage(20,6)==28
                &&SpellProfile.of(RuneState.EMBER).damage(20,6)==29
                &&SpellProfile.of(RuneState.FROST).damage(20,6)==17,
                "The three prepared spells use their distinct authored damage profiles");
        PlayerStats stats=new PlayerStats();stats.attack=20;
        check(SpellProfile.effectiveAttack(stats.attack,true)==25&&stats.attack==20,
                "Mark VIII applies a temporary 25 percent bonus without mutating saved base attributes");
        check(SpellProfile.effectiveAttack(stats.attack,false)==20&&SpellProfile.burnDamage(20)==5,
                "Ending the Mark restores base attack and Ember burn has its own damage");
        for(int spell=RuneState.ARCANA;spell<=RuneState.FROST;spell++) {
            SpellProfile profile=SpellProfile.of(spell);
            check(profile.manaCost==RuneState.manaCost(spell), "The rune UI and combat agree on Mana cost");
            close(profile.cooldown,RuneState.cooldown(spell), "The rune UI and combat agree on cooldown");
        }
        check(SpellProfile.MARK_MANA==RuneState.manaCost(RuneState.MARK), "The Mark UI cost matches actual combat");
        close(SpellProfile.MARK_COOLDOWN,RuneState.cooldown(RuneState.MARK), "The Mark UI cooldown matches actual combat");
        close(SpellProfile.MARK_DURATION,4f, "The Mark buff lasts four gameplay seconds");
    }

    public static void main(String[] arguments) {
        locomotion();
        story();
        secondChapter();
        runes();
        world();
        inventory();
        encounters();
        spells();
        System.out.println("Gameplay logic passed: " + checks + " checks (two chapters, rune/save migration, connected ground, inventory, encounter waves, spells)");
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
