package com.veilbreakers.prototype;

/** Immutable spell rules; runtime bonuses never mutate saved base attributes. */
public final class SpellProfile {
    public static final int ARCANA = 0, EMBER = 1, FROST = 2;
    public static final int MARK_MANA = 30;
    public static final float MARK_COOLDOWN = 12f, MARK_DURATION = 4f;
    public final int id, manaCost;
    public final String name;
    public final float cooldown, damageMultiplier;

    private SpellProfile(int id, String name, int mana, float cooldown, float damage) {
        this.id = id; this.name = name; this.manaCost = mana; this.cooldown = cooldown; this.damageMultiplier = damage;
    }

    private static final SpellProfile[] PROFILES = {
            new SpellProfile(ARCANA, "ARCANA VIII", 18, 1.10f, 1.55f),
            new SpellProfile(EMBER, "BRASAS", 22, 1.60f, 1.60f),
            new SpellProfile(FROST, "GEADA", 25, 2.00f, 1.00f)
    };

    public static SpellProfile of(int id) { return PROFILES[Math.max(0, Math.min(2, id))]; }
    public int damage(int attack, int defense) { return Math.max(1, Math.round(attack * damageMultiplier) - Math.max(0, defense / 2)); }
    public static int effectiveAttack(int base, boolean mark) { return Math.max(1, mark ? Math.round(base * 1.25f) : base); }
    public static int burnDamage(int attack) { return Math.max(2, Math.round(attack * .25f)); }
}
