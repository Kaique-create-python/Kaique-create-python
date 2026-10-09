package com.veilbreakers.prototype;

import android.content.SharedPreferences;

/** Learned runes and prepared magic. Combat timers and Mana payments belong to GameView. */
public final class RuneState {
    public static final int VERSION = 200;
    public static final int ARCANA = 0;
    public static final int EMBER = 1;
    public static final int FROST = 2;
    public static final int MARK = 3;
    public static final int RUNE_COUNT = 4;
    public int selectedSpell = ARCANA;
    public boolean emberUnlocked;
    public boolean frostUnlocked;
    public boolean powerUnlocked;

    public void load(SharedPreferences prefs, StoryState story) {
        emberUnlocked = prefs.getBoolean("rune_ember_unlocked", false);
        frostUnlocked = prefs.getBoolean("rune_frost_unlocked", false);
        powerUnlocked = prefs.getBoolean("rune_power_unlocked", false);
        synchronizeStory(story);
        int saved = prefs.getInt("rune_selected_spell", ARCANA);
        selectedSpell = saved >= ARCANA && saved <= FROST && isUnlocked(saved) ? saved : ARCANA;
    }

    public void save(SharedPreferences.Editor editor) {
        editor.putInt("rune_version", VERSION)
                .putBoolean("rune_ember_unlocked", emberUnlocked)
                .putBoolean("rune_frost_unlocked", frostUnlocked)
                .putBoolean("rune_power_unlocked", powerUnlocked)
                .putInt("rune_selected_spell", getSelectedSpell());
    }

    public void synchronizeStory(StoryState story) {
        emberUnlocked |= story.emberLearned || story.altarUsed;
        frostUnlocked |= story.frostLearned;
        powerUnlocked |= story.echoQuestComplete
                || (story.emberLearned && story.frostLearned && story.echoTraceFound);
    }

    public boolean isUnlocked(int rune) {
        if (rune == ARCANA) return true;
        if (rune == EMBER) return emberUnlocked;
        if (rune == FROST) return frostUnlocked;
        if (rune == MARK) return powerUnlocked;
        return false;
    }

    /** Returns whether a new rune was learned, so reward callsites can remain idempotent. */
    public boolean unlock(int rune) {
        if (isUnlocked(rune)) return false;
        if (rune == EMBER) { emberUnlocked = true; return true; }
        if (rune == FROST) { frostUnlocked = true; return true; }
        if (rune == MARK) { powerUnlocked = true; return true; }
        return false;
    }

    public boolean unlockPower() { return unlock(MARK); }

    public boolean selectSpell(int spell) {
        if (spell < ARCANA || spell > FROST || !isUnlocked(spell)) return false;
        selectedSpell = spell;
        return true;
    }

    public int getSelectedSpell() {
        return selectedSpell >= ARCANA && selectedSpell <= FROST && isUnlocked(selectedSpell)
                ? selectedSpell : ARCANA;
    }

    public static String name(int rune) {
        if (rune == EMBER) return "Brasas";
        if (rune == FROST) return "Geada";
        if (rune == MARK) return "Marca VIII";
        return "Arcana VIII";
    }

    public static int manaCost(int rune) {
        if (rune == EMBER) return 22;
        if (rune == FROST) return 25;
        if (rune == MARK) return 30;
        return 18;
    }

    public static float cooldown(int rune) {
        if (rune == EMBER) return 1.6f;
        if (rune == FROST) return 2.0f;
        if (rune == MARK) return 12f;
        return 1.10f;
    }

    public static String iconPath(int rune) {
        if (rune == EMBER) return "runes/ember.png";
        if (rune == FROST) return "runes/frost.png";
        if (rune == MARK) return "runes/mark.png";
        return "runes/arcana.png";
    }

    public static String description(int rune) {
        if (rune == EMBER) return "Uma descarga de fogo que mantém a ameaça longe. Aprendida no altar do santuário.";
        if (rune == FROST) return "Um projétil frio que desacelera a criatura atingida. Aprendido na Cripta dos Ecos.";
        if (rune == MARK) return "Desperta a Marca VIII por 4 segundos: +25% de ataque. Use o botão MARCA durante a luta.";
        return "A primeira magia de Kael. Um projétil carmesim ligado à Marca VIII.";
    }

    public static String unlockHint(int rune) {
        if (rune == EMBER) return "Aprenda no altar do Santuário Abandonado";
        if (rune == FROST) return "Decifre a inscrição na Cripta dos Ecos";
        if (rune == MARK) return "Investigue os ecos e aprenda Geada na cripta";
        return "Disponível desde o início";
    }
}
