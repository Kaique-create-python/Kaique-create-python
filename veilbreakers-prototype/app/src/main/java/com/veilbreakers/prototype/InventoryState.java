package com.veilbreakers.prototype;

import android.content.SharedPreferences;

/** Owned items, equipment and one-time discoveries. Item actions never advance story flags. */
public final class InventoryState {
    public static final int VERSION = 190;
    public static final int SWORD = 0;
    public static final int BANDAGE = 1;
    public static final int MANA_DRAUGHT = 2;
    public static final int IVO_NOTE = 3;
    public static final int ITEM_COUNT = 4;
    public static final int SWORD_ATTACK = 4;
    public static final int BANDAGE_HEAL = 45;
    public static final int MANA_RECOVERY = 25;

    private static final String[] KEYS = {"sword", "bandage", "mana_draught", "ivo_note"};
    private static final String[] NAMES = {"Espada de Varyn", "Ataduras", "Tônico de Mana", "Relato de Ivo"};
    private static final String[] ICONS = {"items/sword_varyn.png", "items/bandage.png",
            "items/mana_draught.png", "items/ivo_note.png"};
    private static final String[] DESCRIPTIONS = {
            "Sua espada longa, simples e desgastada. O fio sobreviveu ao ataque; seu dono também.",
            "Faixas limpas retiradas do baú de provisões. Use quando precisar tratar seus ferimentos.",
            "Uma pequena reserva de Mana encontrada entre as provisões da praça.",
            "Kael registrou o relato de Ivo: seis pessoas no abrigo, depois cinco. Ninguém abriu a porta."
    };
    private final int[] quantities = new int[ITEM_COUNT];
    private boolean swordGranted;
    private boolean chestGranted;
    private boolean ivoGranted;
    public boolean swordEquipped;

    public int count(int item) {
        return valid(item) ? quantities[item] : 0;
    }

    public int occupiedSlots() {
        int occupied = 0;
        for (int quantity : quantities) if (quantity > 0) occupied++;
        return occupied;
    }

    public boolean discovered(int item) {
        if (item == SWORD) return swordGranted;
        if (item == BANDAGE || item == MANA_DRAUGHT) return chestGranted;
        if (item == IVO_NOTE) return ivoGranted;
        return false;
    }

    public void load(SharedPreferences prefs, StoryState story, PlayerStats stats) {
        boolean current = prefs.contains("inventory_version");
        for (int i = 0; i < ITEM_COUNT; i++) {
            quantities[i] = current ? Math.max(0, Math.min(99,
                    prefs.getInt("inventory_count_" + KEYS[i], 0))) : 0;
        }
        quantities[SWORD] = Math.min(1, quantities[SWORD]);
        quantities[IVO_NOTE] = Math.min(1, quantities[IVO_NOTE]);
        swordGranted = current && prefs.getBoolean("inventory_sword_granted", quantities[SWORD] > 0);
        chestGranted = current && prefs.getBoolean("inventory_chest_granted", false);
        ivoGranted = current && prefs.getBoolean("inventory_ivo_granted", quantities[IVO_NOTE] > 0);
        swordEquipped = current && quantities[SWORD] > 0
                && prefs.getBoolean("inventory_sword_equipped", true);
        stats.setWeaponAttackBonus(swordEquipped ? SWORD_ATTACK : 0);
        synchronizeStory(story, stats);
    }

    public void save(SharedPreferences.Editor editor) {
        editor.putInt("inventory_version", VERSION)
                .putBoolean("inventory_sword_granted", swordGranted)
                .putBoolean("inventory_chest_granted", chestGranted)
                .putBoolean("inventory_ivo_granted", ivoGranted)
                .putBoolean("inventory_sword_equipped", swordEquipped);
        for (int i = 0; i < ITEM_COUNT; i++) editor.putInt("inventory_count_" + KEYS[i], quantities[i]);
    }

    /** Migrates v1.8 discoveries once. Persisted grant flags prevent replenishing consumed supplies. */
    public void synchronizeStory(StoryState story, PlayerStats stats) {
        if (story.swordFound) grantSword(stats);
        if (story.chestOpened) grantChestSupplies();
        if (story.metIvo) grantIvoNote();
    }

    public boolean grantSword(PlayerStats stats) {
        if (swordGranted) return false;
        swordGranted = true;
        quantities[SWORD] = 1;
        swordEquipped = true;
        stats.setWeaponAttackBonus(SWORD_ATTACK);
        return true;
    }

    public boolean grantChestSupplies() {
        if (chestGranted) return false;
        chestGranted = true;
        quantities[BANDAGE] = Math.min(99, quantities[BANDAGE] + 3);
        quantities[MANA_DRAUGHT] = Math.min(99, quantities[MANA_DRAUGHT] + 2);
        return true;
    }

    public boolean grantIvoNote() {
        if (ivoGranted) return false;
        ivoGranted = true;
        quantities[IVO_NOTE] = 1;
        return true;
    }

    public boolean canActivate(int item, PlayerStats stats) {
        if (count(item) <= 0) return false;
        if (item == SWORD || item == IVO_NOTE) return true;
        if (stats.hp <= 0) return false;
        if (item == BANDAGE) return stats.hp < stats.maxHp;
        if (item == MANA_DRAUGHT) return stats.mana < stats.maxMana;
        return false;
    }

    /** Returns visible feedback; supplies are consumed only when they restore a resource. */
    public String activate(int item, PlayerStats stats) {
        if (count(item) <= 0) return "Este item ainda não foi encontrado.";
        if (item == SWORD) {
            swordEquipped = !swordEquipped;
            stats.setWeaponAttackBonus(swordEquipped ? SWORD_ATTACK : 0);
            return swordEquipped ? "Espada equipada. +4 ATK." : "Espada guardada na mochila.";
        }
        if (item == IVO_NOTE) return "Seis pessoas. Depois cinco. A porta continuou fechada.";
        if (!canActivate(item, stats)) return unavailableReason(item, stats);
        if (item == BANDAGE) {
            int healed = Math.min(BANDAGE_HEAL, stats.maxHp - stats.hp);
            if (healed <= 0) return "Sua Vida já está cheia.";
            stats.hp += healed;
            quantities[BANDAGE]--;
            return "+" + healed + " HP. Atadura utilizada.";
        }
        if (item == MANA_DRAUGHT) {
            int recovered = Math.min(MANA_RECOVERY, stats.maxMana - stats.mana);
            if (recovered <= 0) return "Sua Mana já está cheia.";
            stats.mana += recovered;
            quantities[MANA_DRAUGHT]--;
            return "+" + recovered + " Mana. Tônico utilizado.";
        }
        return "Este item não pode ser usado.";
    }

    public String unavailableReason(int item, PlayerStats stats) {
        if (count(item) <= 0) return "Ainda não encontrado";
        if (stats.hp <= 0 && (item == BANDAGE || item == MANA_DRAUGHT)) return "Aguarde seu retorno às ruínas";
        if (item == BANDAGE && stats.hp >= stats.maxHp) return "Sua Vida já está cheia";
        if (item == MANA_DRAUGHT && stats.mana >= stats.maxMana) return "Sua Mana já está cheia";
        return "";
    }

    public String actionLabel(int item) {
        if (item == SWORD) return swordEquipped ? "GUARDAR ESPADA" : "EQUIPAR ESPADA";
        if (item == BANDAGE || item == MANA_DRAUGHT) return "USAR ITEM";
        return "LER RELATO";
    }

    public static String name(int item) {
        return valid(item) ? NAMES[item] : "Espaço vazio";
    }

    public static String description(int item) {
        return valid(item) ? DESCRIPTIONS[item] : "";
    }

    public static String iconPath(int item) {
        return valid(item) ? ICONS[item] : "";
    }

    public static String kind(int item) {
        if (item == SWORD) return "ARMA · COMUM";
        if (item == IVO_NOTE) return "MISSÃO · CINZAS DO OITAVO";
        return "CONSUMÍVEL · COMUM";
    }

    public static String effect(int item) {
        if (item == SWORD) return "+4 ATK enquanto equipada";
        if (item == BANDAGE) return "Restaura até 45 HP";
        if (item == MANA_DRAUGHT) return "Restaura até 25 Mana";
        return "Pista dos desaparecimentos";
    }

    private static boolean valid(int item) {
        return item >= 0 && item < ITEM_COUNT;
    }
}
