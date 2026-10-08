package com.veilbreakers.prototype;

import android.content.SharedPreferences;

/** Saved campaign progress. Dialogue is read-only; GameView commits events at the last page. */
public final class StoryState {
    public static final int WORLD_VERSION = 180;

    public boolean introSeen;
    public boolean swordFound;
    public boolean chestOpened;
    public boolean metMara;
    public boolean metIvo;
    public boolean traceFound;
    public boolean bossDefeated;
    public boolean questComplete;
    public boolean altarUsed;
    public int zone;
    public int clearedMask;

    public void load(SharedPreferences prefs) {
        boolean legacy = !prefs.contains("world_version")
                && (prefs.getBoolean("has_save", false) || prefs.contains("stat_level"));
        introSeen = prefs.getBoolean("story_intro_seen", legacy);
        swordFound = prefs.getBoolean("story_sword_found", legacy);
        chestOpened = prefs.getBoolean("story_chest_opened", false);
        metMara = prefs.getBoolean("story_met_mara", false);
        metIvo = prefs.getBoolean("story_met_ivo", false);
        traceFound = prefs.getBoolean("story_trace_found", false);
        bossDefeated = prefs.getBoolean("story_boss_defeated", false);
        questComplete = prefs.getBoolean("story_quest_complete", false);
        altarUsed = prefs.getBoolean("story_altar_used", false);
        zone = Math.max(0, Math.min(5, prefs.getInt("world_zone", 0)));
        clearedMask = prefs.getInt("world_cleared_mask", 0) & 63;
    }

    public void save(SharedPreferences.Editor editor) {
        editor.putInt("world_version", WORLD_VERSION)
                .putInt("world_zone", zone)
                .putInt("world_cleared_mask", clearedMask)
                .putBoolean("story_intro_seen", introSeen)
                .putBoolean("story_sword_found", swordFound)
                .putBoolean("story_chest_opened", chestOpened)
                .putBoolean("story_met_mara", metMara)
                .putBoolean("story_met_ivo", metIvo)
                .putBoolean("story_trace_found", traceFound)
                .putBoolean("story_boss_defeated", bossDefeated)
                .putBoolean("story_quest_complete", questComplete)
                .putBoolean("story_altar_used", altarUsed);
    }

    /** Global objective remains visible if the player revisits an earlier room. */
    public String objective() {
        if (!swordFound) return "Recupere sua espada nas ruínas";
        if (!chestOpened) return "Abra o baú na Praça Central";
        if (!metMara) return "Converse com Mara na praça";
        if ((clearedMask & (1 << 1)) == 0) return "Derrote o Veilborn da praça";
        if (!metIvo) return "Encontre Ivo nas Casas Queimadas";
        if (!traceFound) return "Examine as cinzas perto do abrigo";
        if (!bossDefeated) return "Derrote o Veilborn no Aqueduto";
        if (!questComplete) return "Alcance o Portão Norte";
        if (!altarUsed) return "Descanse no Santuário Abandonado";
        return "Cinzas do Oitavo concluída — explore Varyn";
    }

    /** Number of completed ordered objectives, from 0 to 9. */
    public int progressStep() {
        if (!swordFound) return 0;
        if (!chestOpened) return 1;
        if (!metMara) return 2;
        if ((clearedMask & (1 << 1)) == 0) return 3;
        if (!metIvo) return 4;
        if (!traceFound) return 5;
        if (!bossDefeated) return 6;
        if (!questComplete) return 7;
        return altarUsed ? 9 : 8;
    }

    public boolean canEnterNext() {
        switch (zone) {
            case 0: return swordFound;
            case 1: return chestOpened && metMara && (clearedMask & (1 << 1)) != 0;
            case 2: return metIvo && traceFound;
            case 3: return bossDefeated;
            case 4: return questComplete;
            default: return false;
        }
    }

    /** Pages are {speaker, text}; no campaign flag or reward changes here. */
    public String[][] dialogue(String interaction) {
        if ("intro".equals(interaction)) return new String[][] {
                {"Kael", "Eu caí. Lembro do golpe... e de não conseguir respirar."},
                {"Kael", "Então por que meu coração ainda bate?"},
                {"Kael", "Essa marca no meu peito... VIII. Não estava aqui antes."},
                {"Kael", "Minha espada está entre os escombros. Preciso descobrir quem sobreviveu."}
        };
        if (VarynMap.SWORD.equals(interaction)) return new String[][] {
                {"Kael", "O fio está gasto. O cabo também. Ainda é a minha espada."},
                {"Kael", "Não vou deixar mais ninguém para trás."}
        };
        if (VarynMap.CHEST.equals(interaction)) return chestOpened ? new String[][] {
                {"Kael", "Só restaram madeira queimada e o cheiro de fumaça."}
        } : new String[][] {
                {"Kael", "Provisões. Quem deixou isto talvez esperasse voltar."},
                {"Kael", "Três ataduras e dois tônicos. Vou guardar na mochila."},
                {"Kael", "Vou levar o que ainda serve. E procurar essa pessoa."}
        };
        if (VarynMap.MARA.equals(interaction)) return metMara ? new String[][] {
                {"Mara", "O caminho para o norte passa pelas casas e pelo aqueduto."},
                {"Mara", "Se encontrar Ivo, diga para parar de contar mortos e começar a chamar vivos."}
        } : new String[][] {
                {"Mara", "Você caminha. Ótimo. Os mortos já estão dando trabalho demais."},
                {"Kael", "O que aconteceu aqui?"},
                {"Mara", "O Domínio Áureo. Fogo, aço... Depois vieram essas criaturas."},
                {"Mara", "Ivo ficou no abrigo, entre as casas. Eu cuido de quem chega à praça."},
                {"Mara", "Tem provisões no baú. E um Veilborn rondando. Não deixe que ele chegue até mim."}
        };
        if (VarynMap.IVO.equals(interaction)) return metIvo ? new String[][] {
                {"Ivo", "As cinzas ainda estão ali, perto da parede do abrigo. Veja por si mesmo."},
                {"Ivo", "Se passar pelo aqueduto, cuidado. A coisa que está lá é maior que as outras."}
        } : new String[][] {
                {"Ivo", "Eu contei seis pessoas no abrigo. Depois contei cinco."},
                {"Kael", "Uma delas saiu?"},
                {"Ivo", "Ninguém abriu a porta. Eu estava olhando. Acho... que estava."},
                {"Ivo", "As pegadas acabam nas cinzas. Pode olhar. Eu prefiro olhar daqui."},
                {"Ivo", "O aqueduto leva ao Portão Norte. Mas um Veilborn tomou a passagem."}
        };
        if (VarynMap.TRACE.equals(interaction)) return new String[][] {
                {"Kael", "As pegadas chegam até aqui. Não há nenhuma seguindo para fora."},
                {"Kael", "Cinzas frias. E o abrigo ainda fechado... Ivo não inventou isso."},
                {"Kael", "Preciso passar pelo aqueduto. Talvez alguém no portão tenha visto mais."}
        };
        if ("gate".equals(interaction)) return questComplete ? new String[][] {
                {"Kael", "O céu voltou ao normal. Minha mão ainda está tremendo."},
                {"Kael", "Há um santuário além do portão. Preciso recuperar o fôlego."}
        } : new String[][] {
                {"Kael", "O Portão Norte. Por um instante achei que não chegaria aqui."},
                {"Kael", "Por que o céu... escureceu? Minha marca está queimando."},
                {"Kael", "Atrás do Hollow Sun... Aquilo estava olhando para mim?"},
                {"Kael", "Fumaça. Deve ter sido fumaça. Eu só preciso continuar."}
        };
        if (VarynMap.ALTAR.equals(interaction)) return new String[][] {
                {"Kael", "As paredes seguram o vento. Por enquanto, isso basta."},
                {"Kael", "Ainda há gente viva em Varyn. E perguntas demais nas cinzas."},
                {"Kael", "Vou descansar. Depois volto a procurar respostas."}
        };
        if ("blocked".equals(interaction)) {
            String text;
            switch (zone) {
                case 0: text = "Minha espada ainda está aqui. Não vou sair sem ela."; break;
                case 1:
                    text = !metMara ? "Aquela sobrevivente precisa de ajuda. Vou falar com ela."
                            : !chestOpened ? "Mara indicou provisões no baú. É melhor conferir."
                            : "O Veilborn ainda ronda a praça. Não vou deixá-lo perto de Mara.";
                    break;
                case 2: text = !metIvo ? "Alguém ficou no abrigo. Preciso encontrá-lo."
                            : "Ivo falou das pegadas nas cinzas. Vou examiná-las antes de seguir."; break;
                case 3: text = "A criatura bloqueia a passagem. Preciso derrotá-la."; break;
                case 4: text = "Quero examinar o portão antes de atravessar."; break;
                default: text = "O caminho termina aqui. Posso voltar às ruínas.";
            }
            return new String[][] {{"Kael", text}};
        }
        return new String[][] {{"Kael", "O vento espalha as cinzas. Ainda preciso seguir."}};
    }
}
