package com.veilbreakers.prototype;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import java.util.ArrayList;
import java.util.List;

/** Native, resolution-independent interface; artwork remains in the authored sprite pipeline. */
final class GameUi {
    private final Paint ink = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint sprite = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private final Typeface titleFace = Typeface.create(Typeface.SERIF, Typeface.BOLD);
    private final Typeface bodyFace = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL);
    private final Typeface dialogueFace = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL);
    static final int IVORY = Color.rgb(235, 226, 210);
    static final int GOLD = Color.rgb(186, 150, 98);
    static final int MUTED = Color.rgb(151, 151, 160);
    private String wrappedSource = "";
    private float wrappedWidth = -1f;
    private float wrappedSize = -1f;
    private String[] wrappedLines = new String[0];
    private String proseSource = "";
    private float proseWidth, proseSize;
    private String[] proseLines = new String[0];
    final RectF statusTab = new RectF();
    final RectF journalTab = new RectF();
    final RectF inventoryTab = new RectF();
    final RectF runeTab = new RectF();
    final RectF cancelHit = new RectF();
    final RectF inventoryActionHit = new RectF();
    final RectF[] inventoryItemHits = {new RectF(), new RectF(), new RectF(), new RectF()};
    final RectF runeActionHit = new RectF();
    final RectF[] runeItemHits = {new RectF(), new RectF(), new RectF(), new RectF()};
    private GameArt art;
    private int selectedItem = InventoryState.SWORD;
    private String inventoryFeedback = "";
    private int selectedRune = RuneState.ARCANA;
    private String runeFeedback = "";

    void setArt(GameArt art) { this.art = art; }
    int selectedInventoryItem() { return selectedItem; }
    void selectInventoryItem(int item) {
        selectedItem = Math.max(0, Math.min(InventoryState.ITEM_COUNT - 1, item));
        inventoryFeedback = "";
    }
    void setInventoryFeedback(String message) { inventoryFeedback = message == null ? "" : message; }
    int selectedRune() { return selectedRune; }
    void selectRune(int rune) {
        selectedRune = Math.max(RuneState.ARCANA, Math.min(RuneState.MARK, rune));
        runeFeedback = "";
    }
    void setRuneFeedback(String message) { runeFeedback = message == null ? "" : message; }

    private boolean skin(Canvas c, String name, RectF destination) {
        if (art == null || art.bitmap(name) == null) return false;
        art.draw(c, name, destination);
        return true;
    }

    private RectF fit(Bitmap image, RectF bounds) {
        float scale = Math.min(bounds.width() / image.getWidth(), bounds.height() / image.getHeight());
        float iw = image.getWidth() * scale, ih = image.getHeight() * scale;
        return new RectF(bounds.centerX() - iw * .5f, bounds.centerY() - ih * .5f,
                bounds.centerX() + iw * .5f, bounds.centerY() + ih * .5f);
    }

    private void rect(Canvas c, float l, float t, float r, float b, int color) {
        ink.setColor(color); ink.setStyle(Paint.Style.FILL); c.drawRect(l,t,r,b,ink);
    }
    private void outline(Canvas c, RectF r, int color, float stroke) {
        ink.setColor(color); ink.setStyle(Paint.Style.STROKE); ink.setStrokeWidth(stroke);
        c.drawRect(r,ink); ink.setStyle(Paint.Style.FILL);
    }
    private void label(Canvas c, String s, float x, float y, float size, int color, boolean heading) {
        text.setTypeface(heading ? titleFace : bodyFace); text.setTextSize(size);
        text.setTextAlign(Paint.Align.LEFT); text.setColor(color); c.drawText(s,x,y,text);
    }
    private void center(Canvas c,String s,RectF r,float size,int color) {
        text.setTypeface(bodyFace); text.setTextSize(size); text.setColor(color);
        text.setTextAlign(Paint.Align.CENTER);
        c.drawText(s,r.centerX(),r.centerY()-(text.ascent()+text.descent())*.5f,text);
        text.setTextAlign(Paint.Align.LEFT);
    }
    void button(Canvas c, RectF r, String s, boolean enabled, float h) {
        boolean painted = skin(c,"ui/button.png",r);
        rect(c,r.left,r.top,r.right,r.bottom,painted
                ? Color.argb(enabled?85:175,enabled?63:13,enabled?19:15,enabled?26:22)
                : enabled?Color.rgb(85,31,40):Color.rgb(25,26,33));
        if (!painted) outline(c,r,enabled?GOLD:Color.rgb(66,65,72),Math.max(1,h*.002f));
        center(c,s,r,h*.027f,enabled?IVORY:MUTED);
    }
    private void meter(Canvas c,float x,float y,float w,float h,String name,String value,float ratio,int color) {
        label(c,name,x,y,h*.030f,MUTED,false);
        text.setTextAlign(Paint.Align.RIGHT); text.setColor(IVORY); text.setTextSize(h*.029f);
        c.drawText(value,x+w,y,text);text.setTextAlign(Paint.Align.LEFT);
        float top=y+h*.015f,bar=h*.017f;
        rect(c,x,top,x+w,top+bar,Color.rgb(33,32,40));
        rect(c,x,top,x+w*PlayerStats.clamp01(ratio),top+bar,color);
        rect(c,x,top,x+w*PlayerStats.clamp01(ratio),top+Math.max(1,h*.002f),Color.argb(95,255,235,214));
    }
    void status(Canvas c,float w,float h,float alpha,PlayerStats stats,int[] pending,int points,
                Bitmap portrait,StoryState story,InventoryState inventory,RuneState runes,int tab,RectF close,RectF confirm,
                RectF[] plus,RectF[] minus) {
        rect(c,0,0,w,h,Color.argb((int)(220*alpha),2,3,7));
        int layer=c.saveLayerAlpha(0,0,w,h,(int)(255*alpha));
        RectF panel=new RectF(w*.095f,h*.045f,w*.905f,h*.955f);
        boolean panelPainted = skin(c,"ui/status_panel.png",panel);
        if (!panelPainted) {
            ink.setShader(new LinearGradient(0,panel.top,0,panel.bottom,
                    Color.rgb(23,22,31),Color.rgb(9,12,18),Shader.TileMode.CLAMP));
            c.drawRect(panel,ink);ink.setShader(null);
        } else rect(c,panel.left+h*.012f,panel.top+h*.012f,panel.right-h*.012f,panel.bottom-h*.012f,
                Color.argb(80,5,7,15));
        if (!panelPainted) outline(c,panel,GOLD,h*.002f);
        rect(c,panel.left+h*.012f,panel.top+h*.012f,panel.left+h*.09f,panel.top+h*.016f,GOLD);
        rect(c,panel.right-h*.09f,panel.bottom-h*.016f,panel.right-h*.012f,panel.bottom-h*.012f,GOLD);
        label(c,"VEILBREAKERS",panel.left+w*.024f,panel.top+h*.047f,h*.024f,GOLD,true);
        label(c,story.questName().toUpperCase(java.util.Locale.ROOT),panel.left+w*.024f,panel.top+h*.079f,h*.016f,MUTED,false);
        statusTab.set(w*.333f,h*.069f,w*.452f,h*.143f);
        inventoryTab.set(w*.456f,h*.069f,w*.605f,h*.143f);
        runeTab.set(w*.610f,h*.069f,w*.710f,h*.143f);
        journalTab.set(w*.714f,h*.069f,w*.815f,h*.143f);
        center(c,"ATRIBUTOS",statusTab,h*.027f,tab==0?IVORY:MUTED);
        center(c,"INVENTÁRIO",inventoryTab,h*.027f,tab==2?IVORY:MUTED);
        center(c,"RUNAS",runeTab,h*.027f,tab==3?IVORY:MUTED);
        center(c,"MISSÃO",journalTab,h*.027f,tab==1?IVORY:MUTED);
        RectF selected=tab==0?statusTab:tab==2?inventoryTab:tab==3?runeTab:journalTab;
        rect(c,selected.left,selected.bottom-h*.007f,selected.right,selected.bottom-h*.004f,GOLD);
        close.set(panel.right-h*.102f,panel.top+h*.014f,panel.right-h*.022f,panel.top+h*.094f);
        button(c,close,"×",true,h);
        rect(c,panel.left+w*.022f,h*.163f,panel.right-w*.022f,h*.165f,Color.rgb(70,57,49));
        float lx=panel.left+w*.028f,lw=w*.19f;
        RectF portraitBox=new RectF(lx,h*.195f,lx+lw,h*.57f);
        rect(c,portraitBox.left,portraitBox.top,portraitBox.right,portraitBox.bottom,Color.rgb(12,14,22));
        outline(c,portraitBox,Color.rgb(68,56,55),h*.0015f);
        label(c,"VIII",portraitBox.left+h*.025f,portraitBox.top+h*.07f,h*.041f,GOLD,true);
        float scale=h*.31f/174f;
        RectF dst=new RectF(portraitBox.centerX()-128*scale,h*.554f-232*scale,
                portraitBox.centerX()+128*scale,h*.554f+24*scale);
        Bitmap illustratedPortrait = art == null ? null : art.bitmap("portraits/kael.png");
        if (illustratedPortrait != null) c.drawBitmap(illustratedPortrait,null,fit(illustratedPortrait,portraitBox),sprite);
        else c.drawBitmap(portrait,null,dst,sprite);
        label(c,"KAEL VARYN",lx,h*.620f,h*.035f,IVORY,true);
        label(c,"Portador da Marca VIII",lx,h*.653f,h*.022f,MUTED,false);
        label(c,"Nível "+stats.level+"   ·   "+stats.money+" moedas",lx,h*.708f,h*.025f,GOLD,false);
        label(c,VarynMap.zoneName(story.zone),lx,h*.753f,h*.021f,MUTED,false);
        label(c,"Arma: "+(inventory.swordEquipped?"Espada de Varyn":"nenhuma equipada"),lx,h*.790f,h*.021f,MUTED,false);
        label(c,"Bônus de arma: +"+stats.weaponAttackBonus+" ATK",lx,h*.826f,h*.021f,GOLD,false);
        label(c,"Magia: "+RuneState.name(runes.getSelectedSpell()),lx,h*.864f,h*.021f,MUTED,false);
        label(c,"JOGO PAUSADO",lx,h*.899f,h*.020f,GOLD,false);
        float rx=w*.371f,rw=panel.right-rx-w*.029f;
        inventoryActionHit.setEmpty();
        for (RectF hit : inventoryItemHits) hit.setEmpty();
        runeActionHit.setEmpty();
        for (RectF hit : runeItemHits) hit.setEmpty();
        if(tab==0) {
            float mw=(rw-w*.023f)*.5f;
            meter(c,rx,h*.218f,mw,h,"VIDA",stats.hp+" / "+stats.maxHp,stats.hpRatio(),Color.rgb(170,43,57));
            meter(c,rx+mw+w*.023f,h*.218f,mw,h,"MANA",stats.mana+" / "+stats.maxMana,stats.manaRatio(),Color.rgb(57,102,176));
            meter(c,rx,h*.307f,rw,h,"EXPERIÊNCIA",stats.xp+" / "+stats.xpToNext,stats.xpRatio(),Color.rgb(133,99,151));
            String[] names={"FORÇA","DEFESA","CRÍTICO","VELOCIDADE"};
            String[] hints={"+2 ataque por ponto","+2 defesa por ponto","+1% chance por ponto","+5 velocidade por ponto"};
            int[] base={stats.attack,stats.defense,stats.crit,stats.speed};
            int[] delta={pending[0]*2,pending[1]*2,pending[2],pending[3]*5};
            for(int i=0;i<4;i++) {
                float y=h*(.382f+i*.105f);
                rect(c,rx,y,rx+rw,y+h*.094f,i%2==0?Color.rgb(29,28,37):Color.rgb(23,24,33));
                label(c,names[i],rx+w*.013f,y+h*.039f,h*.026f,IVORY,true);
                label(c,hints[i],rx+w*.013f,y+h*.070f,h*.019f,MUTED,false);
                String val=base[i]+(i==2?"%":"")+(delta[i]>0?" → "+(base[i]+delta[i])+(i==2?"%":""):"");
                label(c,val,rx+rw*.47f,y+h*.054f,h*.030f,delta[i]>0?GOLD:IVORY,false);
                float size=h*.075f;
                minus[i].set(rx+rw-size*2.28f,y+h*.009f,rx+rw-size*1.28f,y+h*.084f);
                plus[i].set(rx+rw-size*1.12f,y+h*.009f,rx+rw-size*.12f,y+h*.084f);
                button(c,minus[i],"−",pending[i]>0,h);button(c,plus[i],"+",points>0,h);
            }
            label(c,points+" pontos disponíveis",rx,h*.844f,h*.025f,GOLD,false);
            boolean changed=false;for(int p:pending)changed|=p>0;
            confirm.set(rx+rw*.40f,h*.854f,rx+rw,h*.921f);
            cancelHit.set(rx,h*.854f,rx+rw*.35f,h*.921f);
            button(c,cancelHit,"Desfazer",changed,h);button(c,confirm,"Confirmar pontos",changed,h);
        } else if (tab==2) {
            for(RectF hit:plus)hit.setEmpty();for(RectF hit:minus)hit.setEmpty();confirm.setEmpty();cancelHit.setEmpty();
            inventory(c,w,h,rx,rw,inventory,stats);
        } else if (tab==3) {
            for(RectF hit:plus)hit.setEmpty();for(RectF hit:minus)hit.setEmpty();confirm.setEmpty();cancelHit.setEmpty();
            runes(c,w,h,rx,rw,runes,stats);
        } else {
            for(RectF r:plus)r.setEmpty();for(RectF r:minus)r.setEmpty();confirm.setEmpty();cancelHit.setEmpty();
            label(c,story.questName(),rx,h*.223f,h*.037f,IVORY,true);
            label(c,story.questComplete?"O eco continua além do santuário.":"A cidade caiu. Sua história ainda não.",rx,h*.263f,h*.025f,MUTED,false);
            String[] tasks=story.questComplete?new String[] {
                    "Aprender Brasas no santuário", "Abrir caminho na Estrada das Cinzas",
                    "Investigar o eco na cripta", "Decifrar a runa de Geada",
                    "Vencer os guardiões da cripta", "Encontrar Ivo e proteger a torre", "Despertar a Marca VIII"
            }:new String[] {"Recuperar a espada de Kael","Abrir o baú da praça","Encontrar Mara e limpar a praça",
                    "Falar com Ivo nas casas queimadas","Investigar os desaparecimentos","Vencer o Veilborn do aqueduto",
                    "Chegar ao Portão Norte"};
            boolean[] done=story.questComplete?new boolean[] {
                    story.altarUsed&&story.emberLearned,(story.clearedMask&(1<<6))!=0,
                    story.echoTraceFound,story.frostLearned,(story.clearedMask&(1<<7))!=0,
                    story.watcherMet&&(story.clearedMask&(1<<8))!=0,story.echoQuestComplete
            }:new boolean[] {story.swordFound,story.chestOpened,story.metMara&&(story.clearedMask&2)!=0,
                    story.metIvo,story.traceFound,story.bossDefeated,story.questComplete};
            for(int i=0;i<tasks.length;i++) {
                float y=h*(.316f+i*.068f);
                RectF mark=new RectF(rx,y-h*.018f,rx+h*.025f,y+h*.007f);
                outline(c,mark,done[i]?GOLD:Color.rgb(79,75,84),h*.002f);
                if(done[i])center(c,"✓",mark,h*.025f,GOLD);
                label(c,tasks[i],rx+h*.043f,y+h*.005f,h*.025f,done[i]?MUTED:IVORY,false);
            }
            label(c,story.echoQuestComplete?"MISSÃO CONCLUÍDA":"OBJETIVO ATUAL",rx,h*.845f,h*.022f,GOLD,true);
            drawWrapped(c,story.objective(),rx,h*.885f,rw,h*.025f,h*.032f,IVORY,2);
        }
        c.restoreToCount(layer);
    }

    private void inventory(Canvas c,float w,float h,float x,float width,InventoryState inventory,PlayerStats stats) {
        label(c,"MOCHILA",x,h*.223f,h*.037f,IVORY,true);
        label(c,inventory.occupiedSlots()+" / "+InventoryState.ITEM_COUNT+" espaços ocupados",x,h*.261f,h*.024f,MUTED,false);
        float gridWidth=width*.45f,gap=w*.016f;
        float side=Math.min((gridWidth-gap)*.5f,h*.185f);
        float top=h*.295f;
        for(int i=0;i<InventoryState.ITEM_COUNT;i++) {
            float left=x+(i%2)*(gridWidth-side);
            float rowTop=top+(i/2)*(side+h*.026f);
            RectF slot=inventoryItemHits[i];slot.set(left,rowTop,left+side,rowTop+side);
            if(!skin(c,"ui/item_slot.png",slot)) rect(c,slot.left,slot.top,slot.right,slot.bottom,Color.rgb(27,28,34));
            boolean owned=inventory.count(i)>0;
            boolean discovered=inventory.discovered(i);
            if(!owned)rect(c,slot.left,slot.top,slot.right,slot.bottom,Color.argb(115,4,7,12));
            outline(c,slot,i==selectedItem?GOLD:Color.rgb(69,64,59),h*(i==selectedItem?.003f:.0014f));
            Bitmap icon=art==null?null:art.bitmap(InventoryState.iconPath(i));
            if(icon!=null&&discovered) {
                float inset=side*.17f;
                RectF iconBox=new RectF(slot.left+inset,slot.top+side*.08f,slot.right-inset,slot.top+side*.73f);
                sprite.setAlpha(owned?255:70);c.drawBitmap(icon,null,fit(icon,iconBox),sprite);sprite.setAlpha(255);
            }
            text.setTypeface(bodyFace);text.setTextSize(h*.023f);text.setTextAlign(Paint.Align.RIGHT);
            text.setColor(owned?IVORY:MUTED);
            c.drawText(discovered?"×"+inventory.count(i):"—",slot.right-h*.013f,slot.top+h*.030f,text);
            text.setTextAlign(Paint.Align.LEFT);
            label(c,discovered?InventoryState.name(i):"Espaço vazio",slot.left+h*.009f,slot.bottom-h*.018f,h*.0175f,owned?IVORY:MUTED,false);
            if(i==InventoryState.SWORD&&inventory.swordEquipped) {
                label(c,"EQUIPADA",slot.left+h*.009f,slot.top+h*.026f,h*.014f,GOLD,false);
            }
        }
        meter(c,x,h*.758f,gridWidth,h,"VIDA",stats.hp+" / "+stats.maxHp,stats.hpRatio(),Color.rgb(170,43,57));
        meter(c,x,h*.853f,gridWidth,h,"MANA",stats.mana+" / "+stats.maxMana,stats.manaRatio(),Color.rgb(57,102,176));

        float detailX=x+gridWidth+w*.019f,detailWidth=width-gridWidth-w*.019f;
        RectF details=new RectF(detailX,h*.291f,detailX+detailWidth,h*.923f);
        rect(c,details.left,details.top,details.right,details.bottom,Color.argb(140,10,13,20));
        outline(c,details,Color.rgb(82,72,58),h*.0015f);
        float inner=detailX+h*.022f,innerWidth=detailWidth-h*.044f;
        Bitmap selectedIcon=art==null?null:art.bitmap(InventoryState.iconPath(selectedItem));
        boolean selectedDiscovered=inventory.discovered(selectedItem);
        if(selectedIcon!=null&&selectedDiscovered) {
            RectF iconBox=new RectF(details.centerX()-h*.063f,h*.310f,details.centerX()+h*.063f,h*.436f);
            c.drawBitmap(selectedIcon,null,fit(selectedIcon,iconBox),sprite);
        }
        drawWrapped(c,selectedDiscovered?InventoryState.name(selectedItem):"Espaço vazio",inner,h*.478f,innerWidth,h*.031f,h*.036f,IVORY,2);
        label(c,selectedDiscovered?InventoryState.kind(selectedItem):"MOCHILA · ESPAÇO LIVRE",inner,h*.548f,h*.018f,GOLD,false);
        drawWrapped(c,selectedDiscovered?InventoryState.description(selectedItem):"Itens coletados nas Ruínas de Varyn aparecerão aqui.",
                inner,h*.591f,innerWidth,h*.022f,h*.030f,MUTED,4);
        drawWrapped(c,selectedDiscovered?InventoryState.effect(selectedItem):"Explore, converse e abra baús.",inner,h*.729f,innerWidth,h*.022f,h*.029f,GOLD,2);
        inventoryActionHit.set(inner,h*.781f,inner+innerWidth,h*.847f);
        button(c,inventoryActionHit,selectedDiscovered?inventory.actionLabel(selectedItem):"SEM ITEM",inventory.canActivate(selectedItem,stats),h);
        String feedback=inventoryFeedback.isEmpty()?inventory.unavailableReason(selectedItem,stats):inventoryFeedback;
        drawWrapped(c,feedback,inner,h*.884f,innerWidth,h*.021f,h*.027f,IVORY,2);
    }

    private void runes(Canvas c,float w,float h,float x,float width,RuneState runes,PlayerStats stats) {
        label(c,"RUNAS & MARCA",x,h*.223f,h*.037f,IVORY,true);
        label(c,"Prepare uma magia antes de voltar à luta",x,h*.261f,h*.024f,MUTED,false);
        float gridWidth=width*.45f,gap=w*.016f;
        float side=Math.min((gridWidth-gap)*.5f,h*.185f),top=h*.295f;
        for(int rune=0;rune<RuneState.RUNE_COUNT;rune++) {
            float left=x+(rune%2)*(gridWidth-side),rowTop=top+(rune/2)*(side+h*.026f);
            RectF slot=runeItemHits[rune];slot.set(left,rowTop,left+side,rowTop+side);
            if(!skin(c,"ui/item_slot.png",slot))rect(c,slot.left,slot.top,slot.right,slot.bottom,Color.rgb(27,28,34));
            boolean learned=runes.isUnlocked(rune);
            if(!learned)rect(c,slot.left,slot.top,slot.right,slot.bottom,Color.argb(130,4,7,12));
            outline(c,slot,rune==selectedRune?GOLD:Color.rgb(69,64,59),h*(rune==selectedRune?.003f:.0014f));
            Bitmap icon=art==null?null:art.bitmap(RuneState.iconPath(rune));
            if(icon!=null) {
                RectF iconBox=new RectF(slot.left+side*.17f,slot.top+side*.09f,slot.right-side*.17f,slot.top+side*.74f);
                sprite.setAlpha(learned?255:55);c.drawBitmap(icon,null,fit(icon,iconBox),sprite);sprite.setAlpha(255);
            }
            label(c,RuneState.name(rune),slot.left+h*.009f,slot.bottom-h*.018f,h*.019f,learned?IVORY:MUTED,false);
            if(rune==runes.getSelectedSpell())label(c,"PREPARADA",slot.left+h*.009f,slot.top+h*.025f,h*.014f,GOLD,false);
            else if(rune==RuneState.MARK&&learned)label(c,"PODER",slot.left+h*.009f,slot.top+h*.025f,h*.014f,GOLD,false);
        }
        label(c,"MAGIA PREPARADA",x,h*.742f,h*.020f,MUTED,false);
        label(c,RuneState.name(runes.getSelectedSpell()),x,h*.784f,h*.030f,GOLD,true);
        meter(c,x,h*.853f,gridWidth,h,"MANA",stats.mana+" / "+stats.maxMana,stats.manaRatio(),Color.rgb(57,102,176));
        float detailX=x+gridWidth+w*.019f,detailWidth=width-gridWidth-w*.019f;
        RectF details=new RectF(detailX,h*.291f,detailX+detailWidth,h*.923f);
        rect(c,details.left,details.top,details.right,details.bottom,Color.argb(140,10,13,20));
        outline(c,details,Color.rgb(82,72,58),h*.0015f);
        float inner=detailX+h*.022f,innerWidth=detailWidth-h*.044f;
        Bitmap icon=art==null?null:art.bitmap(RuneState.iconPath(selectedRune));
        if(icon!=null) {
            RectF iconBox=new RectF(details.centerX()-h*.063f,h*.310f,details.centerX()+h*.063f,h*.436f);
            c.drawBitmap(icon,null,fit(icon,iconBox),sprite);
        }
        boolean learned=runes.isUnlocked(selectedRune);
        drawWrapped(c,RuneState.name(selectedRune),inner,h*.478f,innerWidth,h*.031f,h*.036f,IVORY,2);
        label(c,selectedRune==RuneState.MARK?"PODER · MARCA VIII":learned?"RUNA APRENDIDA":"RUNA NÃO APRENDIDA",inner,h*.548f,h*.018f,GOLD,false);
        drawWrapped(c,learned?RuneState.description(selectedRune):RuneState.unlockHint(selectedRune),inner,h*.591f,
                innerWidth,h*.022f,h*.030f,MUTED,4);
        String cost=RuneState.manaCost(selectedRune)+" Mana · "+String.format(java.util.Locale.ROOT,"%.1f",RuneState.cooldown(selectedRune))+" s de recarga";
        drawWrapped(c,cost,inner,h*.729f,innerWidth,h*.022f,h*.029f,GOLD,2);
        runeActionHit.set(inner,h*.781f,inner+innerWidth,h*.847f);
        boolean prepared=selectedRune==runes.getSelectedSpell();
        String action=!learned?"NÃO APRENDIDA":selectedRune==RuneState.MARK?"PODER APRENDIDO":prepared?"MAGIA PREPARADA":"PREPARAR MAGIA";
        button(c,runeActionHit,action,learned&&selectedRune!=RuneState.MARK&&!prepared,h);
        String feedback=!runeFeedback.isEmpty()?runeFeedback:!learned?RuneState.unlockHint(selectedRune)
                :selectedRune==RuneState.MARK?"Ative com MARCA durante o combate.":prepared?"A magia está pronta para o botão de conjuração.":"";
        drawWrapped(c,feedback,inner,h*.884f,innerWidth,h*.021f,h*.027f,IVORY,2);
    }
    void dialogue(Canvas c,float w,float h,String speaker,String line,int visible,Bitmap kael) {
        RectF box=new RectF(w*.075f,h*.665f,w*.925f,h*.962f);
        String portraitPath="Kael".equalsIgnoreCase(speaker)?"portraits/kael.png"
                :"Mara".equalsIgnoreCase(speaker)?"portraits/mara.png"
                :"Ivo".equalsIgnoreCase(speaker)?"portraits/ivo.png":"";
        Bitmap figure=art==null||portraitPath.isEmpty()?null:art.bitmap(portraitPath);
        if(figure!=null) {
            rect(c,0,h*.16f,w,box.top,Color.argb(55,2,3,7));
            RectF figureBox=new RectF(w*.60f,h*.140f,w*.92f,box.top-h*.005f);
            c.drawBitmap(figure,null,fit(figure,figureBox),sprite);
        }
        rect(c,box.left-h*.01f,box.top-h*.01f,box.right+h*.01f,box.bottom+h*.01f,Color.argb(150,0,0,0));
        boolean boxPainted = skin(c,"ui/dialogue_frame.png",box);
        if(!boxPainted)rect(c,box.left,box.top,box.right,box.bottom,Color.rgb(6,7,12));
        else rect(c,box.left+h*.013f,box.top+h*.013f,box.right-h*.013f,box.bottom-h*.013f,Color.argb(130,3,4,9));
        if (!boxPainted) outline(c,box,IVORY,h*.004f);
        label(c,speaker.toUpperCase(java.util.Locale.ROOT),box.left+w*.021f,box.top+h*.045f,h*.027f,GOLD,true);
        float tx=box.left+w*.026f;
        text.setTypeface(dialogueFace);text.setTextSize(h*.031f);text.setColor(IVORY);
        float available=box.width()-w*.054f;
        if(!line.equals(wrappedSource)||available!=wrappedWidth||text.getTextSize()!=wrappedSize) {
            wrappedSource=line;wrappedWidth=available;wrappedSize=text.getTextSize();wrappedLines=wrap(line,available,text);
        }
        int remaining=Math.min(visible,line.length());
        float y=box.top+h*.101f;
        for(String row:wrappedLines) {
            int show=Math.min(row.length(),Math.max(0,remaining));
            c.drawText(row.substring(0,show),tx,y,text);
            remaining-=row.length()+1;y+=h*.043f;
        }
        label(c,visible>=line.length()?"TOQUE PARA CONTINUAR  ▾":"TOQUE PARA MOSTRAR A FALA",box.left+w*.021f,
                box.bottom-h*.022f,h*.019f,MUTED,false);
    }
    void drawWrapped(Canvas c,String s,float x,float y,float width,float size,float lineHeight,int color,int maxLines) {
        text.setTypeface(bodyFace);text.setTextSize(size);text.setColor(color);text.setTextAlign(Paint.Align.LEFT);
        if (!s.equals(proseSource) || width != proseWidth || size != proseSize) {
            proseSource = s; proseWidth = width; proseSize = size;
            proseLines = wrap(s,width,text);
        }
        for(int i=0;i<Math.min(maxLines,proseLines.length);i++) c.drawText(proseLines[i],x,y+i*lineHeight,text);
    }
    private String[] wrap(String s,float width,Paint paint) {
        List<String> lines=new ArrayList<>();String current="";
        for(String word:s.split(" ")) {
            String next=current.isEmpty()?word:current+" "+word;
            if(!current.isEmpty()&&paint.measureText(next)>width) {lines.add(current);current=word;} else current=next;
        }
        if(!current.isEmpty())lines.add(current);
        return lines.toArray(new String[0]);
    }
}
