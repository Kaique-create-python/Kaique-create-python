package com.veilbreakers.prototype;

import android.content.SharedPreferences;

/** One active opponent per room; completed waves are also the reward ledger. */
public final class EncounterState {
    public static final int ZONE_COUNT = 9;
    private final int[] completed = new int[ZONE_COUNT];
    private final int[] remainingHp = new int[ZONE_COUNT];

    public EncounterState() {
        for (int i = 0; i < ZONE_COUNT; i++) remainingHp[i] = -1;
    }

    public static final class Profile {
        public final String name;
        public final int hp, attack, defense, xp, coins;
        public final float speed, cooldown;
        public final boolean elite;
        Profile(String name, int hp, int attack, int defense, float speed, float cooldown,
                int xp, int coins, boolean elite) {
            this.name = name; this.hp = hp; this.attack = attack; this.defense = defense;
            this.speed = speed; this.cooldown = cooldown; this.xp = xp; this.coins = coins; this.elite = elite;
        }
    }

    public int total(int zone) {
        switch (zone) {
            case 1: case 3: case 6: return 3;
            case 7: return 4;
            case 8: return 2;
            default: return 0;
        }
    }

    public int wave(int zone) { return valid(zone) ? completed[zone] : 0; }
    public boolean finished(int zone) { return total(zone) == 0 || wave(zone) >= total(zone); }

    public Profile profile(int zone, int wave) {
        int index = Math.max(0, Math.min(Math.max(0, total(zone) - 1), wave));
        if (zone == 1) return new Profile("VEILBORN WRETCH", 70 + index * 9, 18 + index,
                4 + index / 2, .180f + index * .005f, 1.08f - index * .025f,
                22 + index * 5, 10 + index * 3, false);
        if (zone == 3) return new Profile(index == 2 ? "GUARDA DAS CINZAS" : "VEILBORN GUARDIÃO",
                95 + index * 15, 21 + index * 2, 6 + index, .190f + index * .007f,
                1.03f - index * .035f, 35 + index * 10, 18 + index * 5, index == 2);
        if (zone == 6) return new Profile("VEILBORN DAS RAÍZES", 100 + index * 12, 22 + index,
                7 + index / 2, .195f + index * .007f, 1.00f - index * .025f,
                45 + index * 5, 22 + index * 3, false);
        if (zone == 7) return new Profile(index == 3 ? "CAÇADOR DA CRIPTA" : "VEILBORN DA CRIPTA",
                115 + index * 11, 23 + index, 8 + index / 2, .205f + index * .005f,
                1.00f - index * .025f, 48 + index * 6, 25 + index * 3, index == 3);
        if (zone == 8) return new Profile(index == 1 ? "VIGIA DO VÉU" : "SENTINELA DO ECO",
                index == 1 ? 160 : 138, index == 1 ? 28 : 25, index == 1 ? 10 : 9,
                index == 1 ? .230f : .210f, index == 1 ? .92f : .99f,
                index == 1 ? 100 : 65, index == 1 ? 60 : 35, index == 1);
        return new Profile("VEILBORN WRETCH", 70, 18, 4, .180f, 1.08f, 0, 0, false);
    }

    public int hp(int zone) {
        if (finished(zone)) return 0;
        int maximum = profile(zone, wave(zone)).hp;
        return remainingHp[zone] < 1 ? maximum : Math.min(maximum, remainingHp[zone]);
    }

    public void damage(int zone, int expectedWave, int hp) {
        if (valid(zone) && !finished(zone) && wave(zone) == expectedWave && hp > 0)
            remainingHp[zone] = Math.min(profile(zone, expectedWave).hp, hp);
    }

    /** Compare the killed wave token: repeated callbacks cannot award another kill. */
    public boolean claimDefeat(int zone, int expectedWave) {
        if (!valid(zone) || finished(zone) || wave(zone) != expectedWave) return false;
        completed[zone]++;
        remainingHp[zone] = -1;
        return true;
    }

    /** Defeat heals the unfinished opponent, keeping every already-paid wave. */
    public void resetUnfinishedHp(int zone) {
        if (valid(zone) && !finished(zone)) remainingHp[zone] = -1;
    }

    public void load(SharedPreferences prefs, int clearedMask) {
        for (int zone = 0; zone < ZONE_COUNT; zone++) {
            int count = total(zone);
            completed[zone] = Math.max(0, Math.min(count, prefs.getInt("encounter_wave_" + zone, 0)));
            // A room cleared in v1.9 remains cleared after migration.
            if ((clearedMask & (1 << zone)) != 0) completed[zone] = count;
            int max = profile(zone, completed[zone]).hp;
            remainingHp[zone] = Math.max(-1, Math.min(max, prefs.getInt("encounter_hp_" + zone, -1)));
            if (finished(zone)) remainingHp[zone] = -1;
        }
    }

    public void save(SharedPreferences.Editor editor) {
        editor.putInt("encounter_version", 200);
        for (int zone = 0; zone < ZONE_COUNT; zone++)
            editor.putInt("encounter_wave_" + zone, completed[zone]).putInt("encounter_hp_" + zone, remainingHp[zone]);
    }

    private boolean valid(int zone) { return zone >= 0 && zone < ZONE_COUNT; }
}
