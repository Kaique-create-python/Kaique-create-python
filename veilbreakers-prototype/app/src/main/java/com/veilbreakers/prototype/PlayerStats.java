package com.veilbreakers.prototype;

import android.content.SharedPreferences;

public class PlayerStats {
    public int level;
    public int xp;
    public int xpToNext;
    public int hp;
    public int maxHp;
    public int mana;
    public int maxMana;
    public int attack;
    public int weaponAttackBonus;
    public int defense;
    public int crit;
    public int speed;
    public int attributePoints;
    public int money;

    public PlayerStats() {
        resetDefaults();
    }

    public void resetDefaults() {
        level = 1;
        xp = 0;
        xpToNext = xpRequirement(level);
        maxHp = 120;
        hp = maxHp;
        maxMana = 60;
        mana = maxMana;
        attack = 12;
        weaponAttackBonus = 0;
        defense = 8;
        crit = 5;
        speed = 100;
        attributePoints = 3; // Prototype starts with points so the upgrade screen is testable now.
        money = 100;
    }

    public void load(SharedPreferences prefs) {
        level = prefs.getInt("stat_level", 1);
        xp = prefs.getInt("stat_xp", 0);
        xpToNext = prefs.getInt("stat_xp_next", xpRequirement(level));
        maxHp = prefs.getInt("stat_max_hp", 120);
        hp = prefs.getInt("stat_hp", maxHp);
        maxMana = prefs.getInt("stat_max_mana", 60);
        mana = prefs.getInt("stat_mana", maxMana);
        attack = prefs.getInt("stat_attack", 12);
        weaponAttackBonus = Math.max(0, prefs.getInt("stat_weapon_attack_bonus", 0));
        defense = prefs.getInt("stat_defense", 8);
        crit = prefs.getInt("stat_crit", 5);
        speed = prefs.getInt("stat_speed", 100);
        attributePoints = prefs.getInt("stat_attr_points", 3);
        money = prefs.getInt("stat_money", 100);
        hp = clampInt(hp, 0, maxHp);
        mana = clampInt(mana, 0, maxMana);
    }

    public void save(SharedPreferences.Editor editor) {
        editor.putInt("stat_level", level)
                .putInt("stat_xp", xp)
                .putInt("stat_xp_next", xpToNext)
                .putInt("stat_hp", hp)
                .putInt("stat_max_hp", maxHp)
                .putInt("stat_mana", mana)
                .putInt("stat_max_mana", maxMana)
                .putInt("stat_attack", attack)
                .putInt("stat_weapon_attack_bonus", weaponAttackBonus)
                .putInt("stat_defense", defense)
                .putInt("stat_crit", crit)
                .putInt("stat_speed", speed)
                .putInt("stat_attr_points", attributePoints)
                .putInt("stat_money", money);
    }

    public int addXp(int amount) {
        int gainedLevels = 0;
        xp += Math.max(0, amount);
        while (xp >= xpToNext) {
            xp -= xpToNext;
            level++;
            gainedLevels++;
            attributePoints += 3;
            maxHp += 10;
            maxMana += 5;
            hp = maxHp;
            mana = maxMana;
            xpToNext = xpRequirement(level);
        }
        return gainedLevels;
    }

    public int xpRequirement(int lvl) {
        return 100 + Math.max(0, lvl - 1) * 45;
    }

    /** The public attack value includes equipment. Switching replaces its previous contribution. */
    public void setWeaponAttackBonus(int bonus) {
        int nextBonus = Math.max(0, bonus);
        attack = Math.max(1, attack - weaponAttackBonus + nextBonus);
        weaponAttackBonus = nextBonus;
    }

    public float hpRatio() {
        return maxHp <= 0 ? 0f : clamp01(hp / (float) maxHp);
    }

    public float manaRatio() {
        return maxMana <= 0 ? 0f : clamp01(mana / (float) maxMana);
    }

    public float xpRatio() {
        return xpToNext <= 0 ? 0f : clamp01(xp / (float) xpToNext);
    }

    public float moveMultiplier() {
        return Math.max(0.70f, speed / 100f);
    }

    public static float clamp01(float v) {
        return Math.max(0f, Math.min(1f, v));
    }

    private int clampInt(int v, int min, int max) {
        return Math.max(min, Math.min(max, v));
    }
}
