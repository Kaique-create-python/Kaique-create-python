package dev.edith.spotifast;

import android.app.*;
import android.content.*;
import android.graphics.Bitmap;
import android.graphics.drawable.*;
import android.media.*;
import android.net.Uri;
import android.os.*;
import android.text.*;
import android.view.*;
import android.widget.*;
import androidx.media3.common.*;
import androidx.media3.session.*;
import androidx.media3.session.MediaController;
import androidx.recyclerview.widget.*;
import androidx.palette.graphics.Palette;
import com.bumptech.glide.Glide;
import com.bumptech.glide.request.target.CustomTarget;
import com.bumptech.glide.request.transition.Transition;
import com.google.common.util.concurrent.ListenableFuture;
import dev.edith.spotifast.data.*;
import dev.edith.spotifast.providers.*;
import dev.edith.spotifast.playback.*;
import dev.edith.spotifast.ui.*;
import java.util.*;
import java.util.concurrent.Callable;
import java.util.function.Consumer;
import java.io.*;
import org.json.*;
import static dev.edith.spotifast.ui.Design.*;

/** Native Android shell for the existing app; Rust/egui remains available in Settings. */
@androidx.annotation.OptIn(markerClass=androidx.media3.common.util.UnstableApi.class)
public class FreeMusicActivity extends Activity {
    private final Handler main=new Handler(Looper.getMainLooper());
    private final TrackRepository repository=new TrackRepository();
    private ListenableFuture<MediaController> connection;private MediaController controller;
    private HomeFeed homeFeed;
    private LinearLayout homeContent;
    private TextView miniArtist;
    private ProgressBar miniProgress;
    private final Map<String,TextView> navigationItems=new LinkedHashMap<>();

    private List<Track> pendingPlayTracks;private int pendingPlayIndex;private boolean pendingPlayRandom;
    private LinearLayout root,body,mini;private TextView status,miniTitle;private Button miniPlay;
    private ImageView miniArt;private TrackAdapter adapter;private RecyclerView recycler;
    private String tab="Início",source="all",query="",genre="",library="recent",artKey="";
    private int page=0,screenGeneration=0;private boolean visible=false,loading=false,profileView=false,searchInterrupted=false;
    private MusicDatabase.Playlist selectedPlaylist;private boolean reorder=false;
    private final List<Track> allTracks=new ArrayList<>();
    private Dialog expanded;private SeekBar seek;private TextView time,fullTitle,fullArtist;private ImageView fullArt;
    private Button fullPlay,repeat,shuffle;private LinearLayout fullRoot;private boolean seeking=false;
    private String fullKey="";private CustomTarget<Bitmap> paletteTarget;
    private Uri exportUri;private MusicDatabase.Playlist coverPlaylist;private String pendingExport;
    private final Player.Listener listener=new Player.Listener(){
        @Override public void onEvents(Player p,Player.Events e){
            updatePlayer();
            if(status!=null&&p.getCurrentMediaItem()!=null&&p.getPlayerError()==null){
                if(p.getPlaybackState()==Player.STATE_BUFFERING)status.setText("Carregando áudio…");
                else if(p.isPlaying())status.setText("Tocando agora");
            }
        }
        @Override public void onPlayerError(PlaybackException error){
            if(!visible)return;
            String message="Não foi possível reproduzir esta faixa (erro "+error.errorCode+").";
            if(status!=null)status.setText(message+" Verifique a rede ou tente outra música.");
            toast(message);
        }
    };
    private final Runnable tick=new Runnable(){public void run(){if(visible){progress();main.postDelayed(this,500);}}};
    private final Runnable debounce=()->search(false);

    @Override public void onCreate(Bundle saved){super.onCreate(saved);setVolumeControlStream(AudioManager.STREAM_MUSIC);
        if(saved!=null){tab=saved.getString("tab","Início");query=saved.getString("query","");source=saved.getString("source","all");}
        build();navigate(tab);
    }
    @Override protected void onSaveInstanceState(Bundle out){super.onSaveInstanceState(out);out.putString("tab",tab);out.putString("query",query);out.putString("source",source);}
    private void build(){
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        root=column(this);
        root.setBackground(gradient(this,0xff101b19,BG,0));
        root.setPadding(dp(this,14),dp(this,8),dp(this,14),0);
        setContentView(root);
        root.setOnApplyWindowInsetsListener((v,insets)->{
            int bottom=insets.getSystemWindowInsetBottom();
            v.setPadding(dp(this,14),insets.getSystemWindowInsetTop()+dp(this,8),dp(this,14),bottom);
            return insets;
        });
        root.requestApplyInsets();

        LinearLayout header=row(this);
        TextView logo=text(this,"SpotiFast",27,true);
        logo.setTextColor(GREEN);
        header.addView(logo,new LinearLayout.LayoutParams(0,dp(this,52),1));
        TextView profile=text(this,"♫",22,true);
        profile.setGravity(Gravity.CENTER);
        profile.setTextColor(GREEN);
        profile.setContentDescription("Perfil e configurações");
        profile.setBackground(shape(this,RAISED,50));
        header.addView(profile,new LinearLayout.LayoutParams(dp(this,46),dp(this,46)));
        profile.setOnClickListener(v->settings());
        root.addView(header);
        gap(this,root,2);

        body=column(this);
        root.addView(body,new LinearLayout.LayoutParams(-1,0,1));

        LinearLayout miniFrame=column(this);
        miniFrame.setBackground(gradient(this,0xff293a32,0xff1a2623,16));
        miniFrame.setPadding(dp(this,8),dp(this,7),dp(this,8),dp(this,4));
        mini=row(this);
        miniArt=new ImageView(this);
        mini.addView(miniArt,new LinearLayout.LayoutParams(dp(this,46),dp(this,46)));
        LinearLayout miniText=column(this);
        miniText.setGravity(Gravity.CENTER_VERTICAL);
        miniText.setPadding(dp(this,10),0,dp(this,2),0);
        miniTitle=text(this,"Escolha uma música",14,true);
        miniTitle.setSingleLine();
        miniTitle.setEllipsize(android.text.TextUtils.TruncateAt.END);
        miniText.addView(miniTitle);
        miniArtist=text(this,"Audius • Jamendo • Música local",11,false);
        miniArtist.setTextColor(MUTED);
        miniArtist.setSingleLine();
        miniArtist.setEllipsize(android.text.TextUtils.TruncateAt.END);
        miniText.addView(miniArtist);
        mini.addView(miniText,new LinearLayout.LayoutParams(0,dp(this,48),1));
        mini.setOnClickListener(v->expand());
        mini.setContentDescription("Expandir reprodução atual");
        final float[] miniDown={0};
        mini.setOnTouchListener((view,event)->{
            if(event.getAction()==MotionEvent.ACTION_DOWN)miniDown[0]=event.getY();
            if(event.getAction()==MotionEvent.ACTION_UP&&miniDown[0]-event.getY()>dp(this,32)){
                expand();return true;
            }
            return false;
        });
        miniPlay=button(this,"▶",false);
        miniPlay.setTextSize(22);
        miniPlay.setContentDescription("Reproduzir ou pausar");
        mini.addView(miniPlay,new LinearLayout.LayoutParams(dp(this,44),dp(this,46)));
        miniPlay.setOnClickListener(v->toggle());
        TextView next=text(this,"⏭",23,false);
        next.setGravity(Gravity.CENTER);
        next.setContentDescription("Próxima faixa");
        mini.addView(next,new LinearLayout.LayoutParams(dp(this,39),dp(this,46)));
        next.setOnClickListener(v->{if(controller!=null)controller.seekToNextMediaItem();});
        miniFrame.addView(mini,new LinearLayout.LayoutParams(-1,dp(this,50)));
        miniProgress=new ProgressBar(this,null,android.R.attr.progressBarStyleHorizontal);
        miniProgress.setMax(1000);
        miniProgress.setProgressTintList(android.content.res.ColorStateList.valueOf(GREEN));
        miniProgress.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(0xff33413c));
        LinearLayout.LayoutParams progressParams=new LinearLayout.LayoutParams(-1,dp(this,3));
        progressParams.topMargin=dp(this,3);
        miniFrame.addView(miniProgress,progressParams);
        root.addView(miniFrame,new LinearLayout.LayoutParams(-1,dp(this,72)));

        LinearLayout nav=row(this);
        nav.setGravity(Gravity.CENTER);
        nav.setPadding(0,dp(this,7),0,0);
        nav.setBackgroundColor(0xff0b0f10);
        navigationItems.clear();
        String[] names={"Início","Buscar","Biblioteca","Playlists"};
        String[] icons={"⌂","⌕","▥","⊕"};
        for(int i=0;i<names.length;i++){
            final String destination=names[i];
            LinearLayout item=column(this);
            item.setGravity(Gravity.CENTER);
            TextView icon=text(this,icons[i],28,false);
            icon.setGravity(Gravity.CENTER);
            item.addView(icon,new LinearLayout.LayoutParams(-1,dp(this,32)));
            TextView label=text(this,names[i],11,false);
            label.setGravity(Gravity.CENTER);
            item.addView(label,new LinearLayout.LayoutParams(-1,dp(this,24)));
            item.setContentDescription("Ir para "+names[i]);
            item.setOnClickListener(v->navigate(destination));
            nav.addView(item,new LinearLayout.LayoutParams(0,dp(this,60),1));
            navigationItems.put(names[i],icon);
        }
        root.addView(nav,new LinearLayout.LayoutParams(-1,dp(this,63)));
    }

    private void refreshNavigation(){
        for(Map.Entry<String,TextView> entry:navigationItems.entrySet()){
            boolean active=entry.getKey().equals(tab);
            entry.getValue().setTextColor(active?GREEN:WHITE);
            View parent=(View)entry.getValue().getParent();
            if(parent instanceof LinearLayout){
                LinearLayout item=(LinearLayout)parent;
                for(int i=0;i<item.getChildCount();i++){
                    View child=item.getChildAt(i);
                    if(child instanceof TextView)((TextView)child).setTextColor(active?GREEN:MUTED);
                }
            }
        }
    }

    private void setupHome(){
        ScrollView scroll=new ScrollView(this);
        scroll.setFillViewport(false);
        scroll.setVerticalScrollBarEnabled(false);
        scroll.setClipToPadding(false);
        homeContent=column(this);
        scroll.addView(homeContent,new ScrollView.LayoutParams(-1,-2));
        body.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        homeFeed=new HomeFeed(this,homeContent,new HomeFeed.Actions(){
            @Override public void play(List<Track> tracks,int index){playTracks(tracks,index,false);}
            @Override public void filter(String provider,String category){
                source=provider;
                genre=category;
                search(false);
            }
            @Override public void playlists(){navigate("Playlists");}
            @Override public void library(){navigate("Biblioteca");}
            @Override public void search(){navigate("Buscar");}
            @Override public void playlist(MusicDatabase.Playlist playlist){navigate("Playlists");openPlaylist(playlist);}
        });
        int stamp=screenGeneration;
        task(()->db().library("recent"),tracks->{
            if(stamp==screenGeneration&&homeFeed!=null&&tab.equals("Início"))homeFeed.showRecent(tracks);
        });
        task(()->db().playlists(),items->{
            if(stamp==screenGeneration&&homeFeed!=null&&tab.equals("Início"))homeFeed.showPlaylists(items);
        });
    }

    private void navigate(String destination){
        tab=destination;profileView=false;selectedPlaylist=null;reorder=false;page=0;genre="";loading=false;screenGeneration++;repository.cancel();main.removeCallbacks(debounce);body.removeAllViews();
        homeFeed=null;homeContent=null;refreshNavigation();
        if(tab.equals("Início")){
            setupHome();
            makeList();
            search(false);
            return;
        }
        TextView title=text(this,tab,25,true);body.addView(title);gap(this,body,12);
        if(tab.equals("Buscar")){
            EditText input=input(this,"Música, artista ou álbum");input.setText(query);body.addView(input);input.addTextChangedListener(watcher(s->{query=s;main.removeCallbacks(debounce);main.postDelayed(debounce,350);}));
            LinearLayout filters=row(this);for(String name:new String[]{"Todas","Audius","Jamendo"}){Button b=button(this,name,false);filters.addView(b,new LinearLayout.LayoutParams(0,dp(this,48),1));b.setOnClickListener(v->{source=name.equals("Todas")?"all":name.toLowerCase(Locale.ROOT);search(false);});}body.addView(filters);
            Button youtube=button(this,"Vídeos no YouTube ↗",false);body.addView(youtube);youtube.setOnClickListener(v->openYouTube());
        }else if(tab.equals("Início")){
            TextView note=text(this,"Em alta nas fontes conectadas",13,false);note.setTextColor(MUTED);body.addView(note);
            HorizontalScrollView scroll=new HorizontalScrollView(this);scroll.setHorizontalScrollBarEnabled(false);LinearLayout genres=row(this);
            for(String g:new String[]{"Todos","Electronic","Hip-Hop/Rap","Pop","Rock","Jazz","Ambient"}){Button b=button(this,g,false);genres.addView(b);b.setOnClickListener(v->{genre=g.equals("Todos")?"":g;search(false);});}scroll.addView(genres);body.addView(scroll);
        }else if(tab.equals("Biblioteca")){
            LinearLayout options=row(this);String[] names={"Recentes","Curtidas","Mais ouvidas"},keys={"recent","favorites","most"};
            for(int i=0;i<names.length;i++){String key=keys[i];Button b=button(this,names[i],false);options.addView(b,new LinearLayout.LayoutParams(0,dp(this,48),1));b.setOnClickListener(v->{library=key;loadLibrary();});}body.addView(options);
            Button local=button(this,"Abrir músicas do celular",false);body.addView(local);local.setOnClickListener(v->openDocument("audio/*",104,true));
        }else {showPlaylists();return;}
        makeList();if(tab.equals("Biblioteca"))loadLibrary();else search(false);
    }
    private void makeList(){
        boolean home=tab.equals("Início")&&!profileView&&selectedPlaylist==null&&homeContent!=null;
        LinearLayout host=home?homeContent:body;
        status=text(this,"",12,false);status.setTextColor(MUTED);status.setPadding(0,dp(this,6),0,dp(this,6));host.addView(status);
        recycler=new RecyclerView(this);recycler.setLayoutManager(new LinearLayoutManager(this));recycler.setClipToPadding(false);
        adapter=new TrackAdapter(this,new TrackAdapter.Actions(){public void play(int position){playTracks(new ArrayList<>(adapter.tracks),position,false);}public void menu(int p){trackMenu(adapter.tracks.get(p),p);}});adapter.setDragEnabled(reorder);recycler.setAdapter(adapter);
        recycler.setNestedScrollingEnabled(!home);
        recycler.setPadding(0,0,0,dp(this,8));
        host.addView(recycler,new LinearLayout.LayoutParams(-1,home?-2:0,home?0:1));
        new ItemTouchHelper(new ItemTouchHelper.SimpleCallback(ItemTouchHelper.UP|ItemTouchHelper.DOWN,0){
            boolean moved;
            @Override public boolean isLongPressDragEnabled(){return reorder&&selectedPlaylist!=null;}
            @Override public boolean onMove(RecyclerView rv,RecyclerView.ViewHolder a,RecyclerView.ViewHolder b){if(!reorder)return false;adapter.move(a.getBindingAdapterPosition(),b.getBindingAdapterPosition());moved=true;return true;}
            @Override public void onSwiped(RecyclerView.ViewHolder h,int d){}
            @Override public void clearView(RecyclerView rv,RecyclerView.ViewHolder h){super.clearView(rv,h);if(moved&&selectedPlaylist!=null){moved=false;long id=selectedPlaylist.id;List<Track> values=new ArrayList<>(adapter.tracks);allTracks.clear();allTracks.addAll(values);task(()->{db().replace(id,values);return true;},ok->{});}}
        }).attachToRecyclerView(recycler);
        if(!profileView&&(tab.equals("Início")||tab.equals("Buscar"))){Button more=button(this,"Carregar mais músicas",false);LinearLayout.LayoutParams mp=new LinearLayout.LayoutParams(-1,dp(this,48));mp.topMargin=dp(this,6);host.addView(more,mp);more.setOnClickListener(v->search(true));}
    }
    private String client(){return getPreferences(MODE_PRIVATE).getString("jamendo_client_id","");}
    private void search(boolean more){
        if(profileView||!(tab.equals("Início")||tab.equals("Buscar")))return;if(more&&loading)return;
        if(!more){page=0;allTracks.clear();adapter.submit(allTracks);if(tab.equals("Início")&&homeFeed!=null)homeFeed.showTrending(Collections.emptyList());}else page++;
        final boolean requestedMore=more;
        loading=true;status.setText("Buscando em "+(source.equals("all")?"fontes conectadas":source)+"…");String q=tab.equals("Início")?"":query;
        repository.search(q,genre,source,client(),page*25,(tracks,error)->{loading=false;if(requestedMore&&tracks.isEmpty()&&!error.isEmpty())page=Math.max(0,page-1);Set<String> keys=new HashSet<>();for(Track t:allTracks)keys.add(t.key());for(Track t:tracks)if(keys.add(t.key()))allTracks.add(t);
            adapter.submit(allTracks);
            if(tab.equals("Início")&&homeFeed!=null)homeFeed.showTrending(allTracks);
            status.setText(error.isEmpty()?(allTracks.isEmpty()?"Nenhum resultado. Tente outra busca.":allTracks.size()+" faixas · "+(source.equals("all")?"fontes conectadas":source)):error);
            List<Track> copy=new ArrayList<>(tracks);task(()->{for(Track t:copy)db().save(t);return true;},ok->{});
        });
    }
    private void loadLibrary(){int stamp=screenGeneration;task(()->db().library(library),tracks->{if(stamp==screenGeneration){allTracks.clear();allTracks.addAll(tracks);adapter.submit(tracks);status.setText(tracks.isEmpty()?"Sua biblioteca começa com a primeira música.":tracks.size()+" músicas salvas neste celular");}});}
    private void playTracks(List<Track> tracks,int index,boolean random){
        if(controller==null){
            pendingPlayTracks=new ArrayList<>(tracks);pendingPlayIndex=index;pendingPlayRandom=random;
            if(status!=null)status.setText("Conectando ao player… a música começará após a conexão.");
            return;
        }
        if(index<0||index>=tracks.size())return;if(!tracks.get(index).playable()){toast(tracks.get(index).unavailable);return;}
        List<Track> allowed=new ArrayList<>();int start=0;for(int i=0;i<tracks.size();i++)if(tracks.get(i).playable()){if(i==index)start=allowed.size();allowed.add(tracks.get(i));}
        if(status!=null)status.setText("Preparando "+tracks.get(index).title+"…");
        try {
            controller.setMediaItems(MediaItems.of(allowed),start,0);
            controller.setShuffleModeEnabled(random);
            controller.prepare();
            controller.play();
        }catch(RuntimeException e){
            if(status!=null)status.setText("Falha ao iniciar player. Abra novamente ou escolha outra música.");
            toast("Não foi possível iniciar a reprodução.");
        }
    }
    private void toggle(){if(controller==null)return;if(controller.isPlaying())controller.pause();else if(controller.getMediaItemCount()>0){if(controller.getPlaybackState()==Player.STATE_IDLE)controller.prepare();if(controller.getPlaybackState()==Player.STATE_ENDED)controller.seekTo(0);controller.play();}}
    private void trackMenu(Track t,int position){
        List<String> choices=new ArrayList<>(Arrays.asList("Curtir / descurtir","Adicionar à playlist","Adicionar à fila","Compartilhar","Ver artista","Ver álbum","Licença e fonte"));
        if(selectedPlaylist!=null&&position>=0)choices.add("Remover da playlist");
        new AlertDialog.Builder(this).setTitle(t.title).setItems(choices.toArray(new String[0]),(d,i)->{
            switch(i){case 0:task(()->db().favorite(t),liked->{toast(liked?"Adicionada às curtidas":"Removida das curtidas");if(tab.equals("Biblioteca"))loadLibrary();});break;
            case 1:addToPlaylist(t);break;case 2:if(controller!=null&&t.playable()){controller.addMediaItem(MediaItems.of(t));toast("Adicionada à fila");}else toast(t.unavailable);break;
            case 3:share(t.title+" — "+t.artist+(t.shareUrl.isEmpty()?"":"\n"+t.shareUrl));break;
            case 4:artist(t,false);break;case 5:artist(t,true);break;case 6:new AlertDialog.Builder(this).setTitle(t.provider).setMessage(t.license.isEmpty()?"Consulte as condições na página oficial da faixa.":t.license).setPositiveButton("Fechar",null).show();break;
            case 7:if(selectedPlaylist!=null){long id=selectedPlaylist.id;List<Track> copy=new ArrayList<>(allTracks);int actual=copy.indexOf(t);if(actual>=0)copy.remove(actual);task(()->{db().replace(id,copy);return true;},ok->openPlaylist(selectedPlaylist));}break;
            }
        }).show();
    }
    private void artist(Track t,boolean album){
        if((album&&t.albumId.isEmpty())||(!album&&t.artistId.isEmpty())){toast("Esta fonte não forneceu esse perfil.");return;}
        repository.cancel();main.removeCallbacks(debounce);profileView=true;screenGeneration++;selectedPlaylist=null;reorder=false;body.removeAllViews();body.addView(text(this,album?t.album:t.artist,26,true));makeList();status.setText("Carregando catálogo da fonte…");int stamp=screenGeneration;
        // Provider work uses a dedicated short-lived task; UI stays responsive.
        java.util.concurrent.ExecutorService work=java.util.concurrent.Executors.newSingleThreadExecutor();work.execute(()->{try{List<Track> list=t.provider.equals("audius")?new AudiusProvider().artist(t.artistId,0,this):album?new JamendoProvider(client()).album(t.albumId,this):new JamendoProvider(client()).artist(t.artistId,0,this);main.post(()->{if(!isDestroyed()&&stamp==screenGeneration){allTracks.clear();allTracks.addAll(list);adapter.submit(list);status.setText("Catálogo · "+t.provider);}});}catch(Exception e){main.post(()->{if(!isDestroyed()&&stamp==screenGeneration)status.setText("Perfil indisponível. Tente novamente.");});}finally{work.shutdown();}});
    }
    private void showPlaylists(){
        LinearLayout actions=row(this);Button create=button(this,"Criar playlist",true),imp=button(this,"Importar",false);actions.addView(create,new LinearLayout.LayoutParams(0,dp(this,48),1));actions.addView(imp,new LinearLayout.LayoutParams(0,dp(this,48),1));body.addView(actions);create.setOnClickListener(v->newPlaylist(null));imp.setOnClickListener(v->openDocument("application/json",102,false));
        ScrollView scroll=new ScrollView(this);LinearLayout list=column(this);scroll.addView(list);body.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));int stamp=screenGeneration;
        task(()->db().playlists(),playlists->{if(stamp!=screenGeneration)return;if(playlists.isEmpty())list.addView(text(this,"Crie uma playlist para guardar suas descobertas.",15,false));for(MusicDatabase.Playlist p:playlists){
            LinearLayout item=row(this);item.setPadding(0,dp(this,8),0,dp(this,8));ImageView art=new ImageView(this);item.addView(art,new LinearLayout.LayoutParams(dp(this,64),dp(this,64)));ImageRepository.load(this,p.artwork,art,dp(this,64));Button b=button(this,p.name+"\n"+p.count+" músicas · "+time(p.duration),false);item.addView(b,new LinearLayout.LayoutParams(0,-2,1));b.setOnClickListener(v->openPlaylist(p));b.setOnLongClickListener(v->{playlistMenu(p);return true;});Button menu=button(this,"⋮",false);item.addView(menu,new LinearLayout.LayoutParams(dp(this,48),dp(this,48)));menu.setContentDescription("Opções de "+p.name);menu.setOnClickListener(v->playlistMenu(p));list.addView(item);
        }});
    }
    private void newPlaylist(Track add){EditText name=input(this,"Nome da playlist");new AlertDialog.Builder(this).setTitle("Nova playlist").setView(name).setPositiveButton("Criar",(d,w)->{String value=name.getText().toString();task(()->{long id=db().createPlaylist(value);if(add!=null)db().add(id,add);return id;},id->{toast("Playlist criada");if(tab.equals("Playlists"))navigate("Playlists");});}).setNegativeButton("Cancelar",null).show();}
    private void addToPlaylist(Track t){task(()->db().playlists(),playlists->{List<String> names=new ArrayList<>();names.add("+ Nova playlist");for(MusicDatabase.Playlist p:playlists)names.add(p.name);new AlertDialog.Builder(this).setTitle("Adicionar a…").setItems(names.toArray(new String[0]),(d,i)->{if(i==0)newPlaylist(t);else task(()->{db().add(playlists.get(i-1).id,t);return true;},ok->toast("Música adicionada"));}).show();});}
    private void openPlaylist(MusicDatabase.Playlist p){
        if(p==null)return;screenGeneration++;repository.cancel();selectedPlaylist=p;reorder=true;body.removeAllViews();body.addView(text(this,p.name,25,true));TextView desc=text(this,p.description,13,false);body.addView(desc);
        LinearLayout controls=row(this);String[] labels={"Tocar","Aleatório","Opções"};for(int i=0;i<3;i++){final int action=i;Button b=button(this,labels[i],i==0);controls.addView(b,new LinearLayout.LayoutParams(0,dp(this,48),1));b.setOnClickListener(v->{if(action<2)playTracks(new ArrayList<>(adapter.tracks),0,action==1);else playlistMenu(p);});}body.addView(controls);
        EditText filter=input(this,"Buscar nesta playlist");body.addView(filter);makeList();int stamp=screenGeneration;
        task(()->db().playlist(p.id),tracks->{if(stamp==screenGeneration){allTracks.clear();allTracks.addAll(tracks);adapter.submit(tracks);status.setText(tracks.size()+" músicas · "+time(tracks.stream().mapToLong(t->t.duration).sum())+" · segure para reordenar");}});
        filter.addTextChangedListener(watcher(value->{reorder=value.isEmpty();adapter.setDragEnabled(reorder);List<Track> filtered=new ArrayList<>();for(Track t:allTracks)if((t.title+" "+t.artist).toLowerCase(Locale.ROOT).contains(value.toLowerCase(Locale.ROOT)))filtered.add(t);adapter.submit(filtered);}));
    }
    private void playlistMenu(MusicDatabase.Playlist p){new AlertDialog.Builder(this).setTitle(p.name).setItems(new String[]{"Editar nome e descrição","Escolher capa","Duplicar","Adicionar à fila","Ordenar por nome","Ordenar por artista","Exportar","Excluir","Ordenar por inclusão"},(d,i)->{
        if(i==0){LinearLayout form=column(this);EditText name=input(this,"Nome"),description=input(this,"Descrição");name.setText(p.name);description.setText(p.description);form.addView(name);form.addView(description);new AlertDialog.Builder(this).setTitle("Editar playlist").setView(form).setPositiveButton("Salvar",(a,b)->{String n=name.getText().toString(),desc=description.getText().toString();task(()->{db().editPlaylist(p.id,n,desc,p.artwork);return true;},ok->navigate("Playlists"));}).setNegativeButton("Cancelar",null).show();}
        else if(i==1){coverPlaylist=p;openDocument("image/*",103,false);}
        else if(i==2)task(()->db().duplicate(p),id->navigate("Playlists"));
        else if(i==3)task(()->db().playlist(p.id),tracks->{if(controller!=null){List<Track> playable=new ArrayList<>();for(Track t:tracks)if(t.playable())playable.add(t);controller.addMediaItems(MediaItems.of(playable));toast("Playlist adicionada à fila");}});
        else if(i==4||i==5)task(()->{List<Track> tracks=db().playlist(p.id);tracks.sort(Comparator.comparing(t->(i==4?t.title:t.artist).toLowerCase(Locale.ROOT)));db().replace(p.id,tracks);return true;},ok->openPlaylist(p));
        else if(i==6)exportPlaylist(p);
        else if(i==8)task(()->{db().replace(p.id,db().playlistByDate(p.id));return true;},ok->openPlaylist(p));
        else new AlertDialog.Builder(this).setTitle("Excluir “"+p.name+"”?").setMessage("A playlist será removida deste celular.").setNegativeButton("Cancelar",null).setPositiveButton("Excluir",(a,b)->task(()->{db().deletePlaylist(p.id);return true;},ok->navigate("Playlists"))).show();
    }).show();}
    private void settings(){new AlertDialog.Builder(this).setTitle("Seu SpotiFast · V4 preview").setItems(new String[]{"Configurar Jamendo","Sleep timer","Volume do sistema","Limpar cache de capas e buscas","Interface original Rust / Spotify","Sobre esta versão","Limite do cache de capas"},(d,i)->{
        if(i==0){EditText id=input(this,"Client ID legítimo");id.setText(client());new AlertDialog.Builder(this).setTitle("Jamendo Developer").setMessage("Insira o Client ID da sua aplicação no Jamendo. Nenhuma senha é necessária.").setView(id).setPositiveButton("Salvar",(a,b)->{getPreferences(MODE_PRIVATE).edit().putString("jamendo_client_id",id.getText().toString().trim()).apply();ApiClient.clear();navigate(tab);}).setNeutralButton("Portal",(a,b)->external("https://devportal.jamendo.com/")).setNegativeButton("Cancelar",null).show();}
        else if(i==1)new AlertDialog.Builder(this).setTitle("Parar reprodução após…").setItems(new String[]{"Desativar","15 minutos","30 minutos","60 minutos"},(a,b)->{if(controller!=null){Bundle args=new Bundle();args.putInt("minutes",new int[]{0,15,30,60}[b]);controller.sendCustomCommand(new SessionCommand(PlaybackService.SLEEP,Bundle.EMPTY),args);toast("Temporizador atualizado");}}).show();
        else if(i==2)((AudioManager)getSystemService(AUDIO_SERVICE)).adjustStreamVolume(AudioManager.STREAM_MUSIC,AudioManager.ADJUST_SAME,AudioManager.FLAG_SHOW_UI);
        else if(i==3){Glide.get(this).clearMemory();task(()->{Glide.get(getApplicationContext()).clearDiskCache();ApiClient.clear();return true;},ok->toast("Cache limpo"));}
        else if(i==4){if(controller!=null)controller.pause();startActivity(new Intent(this,SpotiFastActivity.class));}
        else if(i==6)new AlertDialog.Builder(this).setTitle("Cache em disco").setItems(new String[]{"32 MB","64 MB","128 MB"},(a,b)->{getPreferences(MODE_PRIVATE).edit().putInt("image_cache_mb",new int[]{32,64,128}[b]).apply();toast("Limite aplicado na próxima inicialização do aplicativo");}).show();
        else new AlertDialog.Builder(this).setTitle("SpotiFast V4 preview 1").setMessage("Player Android com Media3 e biblioteca local SQLite.\n\nAudius e Jamendo seguem as permissões das fontes. YouTube usa vídeo oficial visível.\n\nA interface Rust original foi preservada. Não há acesso gratuito ao catálogo pago do Spotify. Não há download de áudio remoto.").setPositiveButton("Fechar",null).show();
    }).show();}
    private void expand(){
        if(controller==null||controller.getCurrentMediaItem()==null){toast("Escolha uma música para começar");return;}if(expanded!=null&&expanded.isShowing())return;
        expanded=new Dialog(this);ScrollView scroll=new ScrollView(this);fullRoot=column(this);fullRoot.setPadding(dp(this,24),dp(this,24),dp(this,24),dp(this,24));fullRoot.setBackgroundColor(BG);scroll.addView(fullRoot);expanded.setContentView(scroll);
        Button down=button(this,"⌄  Tocando agora",false);fullRoot.addView(down);down.setOnClickListener(v->expanded.dismiss());gap(this,fullRoot,20);
        fullArt=new ImageView(this);int size=Math.min(getResources().getDisplayMetrics().widthPixels-dp(this,48),dp(this,420));LinearLayout.LayoutParams artParams=new LinearLayout.LayoutParams(size,size);artParams.gravity=Gravity.CENTER_HORIZONTAL;fullRoot.addView(fullArt,artParams);gap(this,fullRoot,24);
        fullTitle=text(this,"",25,true);fullArtist=text(this,"",16,false);fullArtist.setTextColor(MUTED);fullRoot.addView(fullTitle);fullRoot.addView(fullArtist);gap(this,fullRoot,16);
        seek=new SeekBar(this);seek.setContentDescription("Posição na música");seek.setMax(1000);fullRoot.addView(seek);time=text(this,"0:00 / 0:00",12,false);fullRoot.addView(time);seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){public void onStartTrackingTouch(SeekBar s){seeking=true;}public void onProgressChanged(SeekBar s,int p,boolean user){}public void onStopTrackingTouch(SeekBar s){if(controller!=null&&controller.isCurrentMediaItemSeekable()&&controller.getDuration()>0)controller.seekTo(controller.getDuration()*s.getProgress()/1000);seeking=false;}});
        LinearLayout controls=row(this);Button previous=button(this,"❮",false),next=button(this,"❯",false);fullPlay=button(this,"▶",true);previous.setContentDescription("Faixa anterior");next.setContentDescription("Próxima faixa");for(Button b:new Button[]{previous,fullPlay,next})controls.addView(b,new LinearLayout.LayoutParams(0,dp(this,64),1));fullRoot.addView(controls);previous.setOnClickListener(v->controller.seekToPrevious());next.setOnClickListener(v->controller.seekToNextMediaItem());fullPlay.setOnClickListener(v->toggle());
        LinearLayout modes=row(this);shuffle=button(this,"Aleatório",false);repeat=button(this,"Repetir",false);modes.addView(shuffle,new LinearLayout.LayoutParams(0,dp(this,48),1));modes.addView(repeat,new LinearLayout.LayoutParams(0,dp(this,48),1));fullRoot.addView(modes);shuffle.setOnClickListener(v->controller.setShuffleModeEnabled(!controller.getShuffleModeEnabled()));repeat.setOnClickListener(v->controller.setRepeatMode((controller.getRepeatMode()+1)%3));
        LinearLayout actions=row(this);for(String name:new String[]{"Curtir","Fila","Mais"}){Button b=button(this,name,false);actions.addView(b,new LinearLayout.LayoutParams(0,dp(this,48),1));b.setOnClickListener(v->{Track t=current();if(t==null)return;if(name.equals("Curtir"))task(()->db().favorite(t),liked->toast(liked?"Música curtida":"Curtida removida"));else if(name.equals("Fila"))queue();else trackMenu(t,-1);});}fullRoot.addView(actions);
        final float[] y={0};down.setOnTouchListener((v,e)->{if(e.getAction()==MotionEvent.ACTION_DOWN)y[0]=e.getY();if(e.getAction()==MotionEvent.ACTION_UP&&e.getY()-y[0]>dp(this,50)){expanded.dismiss();return true;}return false;});
        fullKey="";expanded.setOnDismissListener(d->{if(paletteTarget!=null){Glide.with(this).clear(paletteTarget);paletteTarget=null;}seek=null;fullPlay=null;fullRoot=null;fullArt=null;fullTitle=null;});expanded.show();expanded.getWindow().setLayout(-1,-1);updatePlayer();
    }
    private Track current(){try{return controller==null||controller.getCurrentMediaItem()==null?null:MediaItems.track(controller.getCurrentMediaItem());}catch(Exception e){return null;}}
    private void updatePlayer(){
        if(controller==null)return;Track t=current();miniPlay.setText(controller.isPlaying()?"Ⅱ":"▶");
        if(t!=null){miniTitle.setText(t.title);if(miniArtist!=null)miniArtist.setText(t.artist+"  •  "+t.provider);if(!artKey.equals(t.key()+t.artwork)){artKey=t.key()+t.artwork;ImageRepository.load(this,t.artwork,miniArt,dp(this,46));}}
        if(status!=null&&controller.getPlayerError()!=null)status.setText("Não foi possível reproduzir. Verifique a conexão ou a disponibilidade na fonte. Toque em reproduzir para tentar novamente.");
        if(fullPlay!=null&&t!=null){fullPlay.setText(controller.isPlaying()?"Ⅱ Pausar":"▶ Tocar");fullPlay.setContentDescription(controller.isPlaying()?"Pausar":"Reproduzir");fullTitle.setText(t.title);fullArtist.setText(t.artist+" · "+t.provider);repeat.setText(new String[]{"Repetir: não","Repetir: faixa","Repetir: fila"}[controller.getRepeatMode()]);shuffle.setText(controller.getShuffleModeEnabled()?"Aleatório: sim":"Aleatório: não");
            if(!fullKey.equals(t.key()+t.artwork)){fullKey=t.key()+t.artwork;ImageRepository.load(this,t.artwork,fullArt,Math.min(1000,getResources().getDisplayMetrics().widthPixels));if(paletteTarget!=null)Glide.with(this).clear(paletteTarget);String key=fullKey;
                paletteTarget=new CustomTarget<Bitmap>(){public void onResourceReady(Bitmap bitmap,Transition<? super Bitmap> transition){Palette.from(bitmap).maximumColorCount(8).generate(palette->{if(fullRoot!=null&&key.equals(fullKey)&&palette!=null){int color=palette.getDarkMutedColor(PANEL);fullRoot.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,new int[]{color,BG}));}});}public void onLoadCleared(Drawable drawable){}};
                Glide.with(this).asBitmap().load(t.artwork).override(64,64).into(paletteTarget);
            }
        }progress();
    }
    private void progress(){if(controller!=null){long duration=controller.getDuration(),position=controller.getCurrentPosition();int value=duration>0?(int)(Math.max(0,position)*1000/duration):0;if(miniProgress!=null)miniProgress.setProgress(Math.max(0,Math.min(1000,value)));if(seek!=null){seek.setEnabled(duration>0&&controller.isCurrentMediaItemSeekable());if(!seeking)seek.setProgress(value);if(time!=null)time.setText(time(position)+" / "+(duration>0?time(duration):"—"));}}}
    private void queue(){
        if(controller==null)return;List<String> names=new ArrayList<>();for(int i=0;i<controller.getMediaItemCount();i++)names.add((i==controller.getCurrentMediaItemIndex()?"▶ ":"")+controller.getMediaItemAt(i).mediaMetadata.title);
        new AlertDialog.Builder(this).setTitle("Fila de reprodução").setItems(names.toArray(new String[0]),(d,index)->{
            if(controller==null||index>=controller.getMediaItemCount())return;String id=controller.getMediaItemAt(index).mediaId;
            new AlertDialog.Builder(this).setItems(new String[]{"Tocar agora","Remover","Mover para cima","Mover para baixo"},(a,action)->{if(controller==null||index>=controller.getMediaItemCount()||!id.equals(controller.getMediaItemAt(index).mediaId))return;
                if(action==0){controller.seekToDefaultPosition(index);controller.prepare();controller.play();}
                else if(action==1)controller.removeMediaItem(index);else if(action==2&&index>0)controller.moveMediaItem(index,index-1);else if(action==3&&index+1<controller.getMediaItemCount())controller.moveMediaItem(index,index+1);queue();}).show();
        }).setNegativeButton("Fechar",null).show();
    }
    private void openYouTube(){if(controller!=null)controller.pause();startActivity(new Intent(this,YouTubeActivity.class).putExtra("query",query));}
    private void openDocument(String mime,int request,boolean multiple){Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT).setType(mime).addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_ALLOW_MULTIPLE,multiple);try{startActivityForResult(i,request);}catch(ActivityNotFoundException e){toast("Seletor de arquivos indisponível");}}
    private void exportPlaylist(MusicDatabase.Playlist p){task(()->{JSONArray tracks=new JSONArray();for(Track t:db().playlist(p.id))tracks.put(t.json());return new JSONObject().put("format","spotifast-playlist").put("version",1).put("name",p.name).put("description",p.description).put("tracks",tracks).toString(2);},json->{pendingExport=json;Intent intent=new Intent(Intent.ACTION_CREATE_DOCUMENT).setType("application/json").addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_TITLE,"SpotiFast-playlist.json");startActivityForResult(intent,101);});}
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null)return;
        Uri uri=data.getData();
        if(request==101&&uri!=null&&pendingExport!=null){String json=pendingExport;pendingExport=null;task(()->{try(OutputStream out=getContentResolver().openOutputStream(uri)){if(out==null)throw new IOException();out.write(json.getBytes(java.nio.charset.StandardCharsets.UTF_8));}return true;},ok->toast("Playlist exportada"));}
        else if(request==102&&uri!=null)task(()->{String json;try(InputStream in=getContentResolver().openInputStream(uri)){if(in==null)throw new IOException();ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buf=new byte[8192];int n;while((n=in.read(buf))!=-1){if(out.size()+n>2_000_000)throw new IOException("Arquivo grande demais");out.write(buf,0,n);}json=out.toString("UTF-8");}JSONObject o=new JSONObject(json);if(!o.optString("format").equals("spotifast-playlist")||o.optInt("version")!=1)throw new IOException("Formato não suportado");JSONArray a=o.getJSONArray("tracks");if(a.length()>1000)throw new IOException("Limite de 1000 faixas por importação");List<Track> tracks=new ArrayList<>();for(int j=0;j<a.length();j++)tracks.add(Track.fromJson(a.getJSONObject(j)));return db().importPlaylist(o.optString("name","Playlist importada"),o.optString("description"),tracks);},id->navigate("Playlists"));
        else if(request==103&&uri!=null&&coverPlaylist!=null){persist(uri,data);MusicDatabase.Playlist p=coverPlaylist;task(()->{db().editPlaylist(p.id,p.name,p.description,uri.toString());return true;},ok->navigate("Playlists"));}
        else if(request==104){List<Uri> uris=new ArrayList<>();if(uri!=null)uris.add(uri);if(data.getClipData()!=null)for(int j=0;j<data.getClipData().getItemCount();j++)uris.add(data.getClipData().getItemAt(j).getUri());for(Uri u:uris)persist(u,data);
            task(()->{List<Track> tracks=new ArrayList<>();for(Uri u:uris){MediaMetadataRetriever r=new MediaMetadataRetriever();try{r.setDataSource(this,u);String title=r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),artist=r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST);Track t=new Track("local",u.toString(),title==null?"Arquivo de áudio":title,artist==null?"No dispositivo":artist);String duration=r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);t.duration=duration==null?0:Long.parseLong(duration);db().save(t);tracks.add(t);}finally{r.release();}}return tracks;},tracks->{allTracks.clear();allTracks.addAll(tracks);adapter.submit(tracks);status.setText("Arquivos autorizados neste dispositivo");playTracks(tracks,0,false);});}
    }
    private void persist(Uri uri,Intent data){try{if ((data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0) getContentResolver().takePersistableUriPermission(uri,Intent.FLAG_GRANT_READ_URI_PERMISSION);}catch(SecurityException e){toast("Permissão temporária: selecione novamente após reiniciar.");}}
    private TextWatcher watcher(Consumer<String> callback){return new TextWatcher(){public void beforeTextChanged(CharSequence s,int start,int count,int after){}public void onTextChanged(CharSequence s,int start,int before,int count){callback.accept(s.toString());}public void afterTextChanged(Editable e){}};}
    private MusicDatabase db(){return MusicDatabase.get(this);}
    private <T> void task(Callable<T> work,Consumer<T> done){MusicDatabase.IO.execute(()->{try{T result=work.call();main.post(()->{if(!isDestroyed())done.accept(result);});}catch(Exception e){main.post(()->{if(!isDestroyed())toast("Não foi possível concluir. Verifique os dados e o armazenamento.");});}});}
    private void toast(String message){Toast.makeText(this,message,Toast.LENGTH_LONG).show();}
    private void share(String value){startActivity(Intent.createChooser(new Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,value),"Compartilhar música"));}
    private void external(String url){try{startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse(url)));}catch(ActivityNotFoundException e){toast("Navegador indisponível");}}
    @Override protected void onStart(){super.onStart();visible=true;if(searchInterrupted){searchInterrupted=false;search(false);}connection=new MediaController.Builder(this,new SessionToken(this,new ComponentName(this,PlaybackService.class))).buildAsync();final ListenableFuture<MediaController> pending=connection;pending.addListener(()->{if(!visible||connection!=pending)return;try{
            controller=pending.get();controller.addListener(listener);updatePlayer();
            if(pendingPlayTracks!=null){
                List<Track> tracks=pendingPlayTracks;int index=pendingPlayIndex;boolean random=pendingPlayRandom;
                pendingPlayTracks=null;playTracks(tracks,index,random);
            }
        }catch(Exception e){if(status!=null)status.setText("Falha ao conectar ao serviço de áudio.");toast("Não foi possível conectar ao player");}},command->main.post(command));main.post(tick);}
    @Override protected void onStop(){visible=false;searchInterrupted=loading&&!profileView;main.removeCallbacks(tick);main.removeCallbacks(debounce);repository.cancel();ApiClient.cancel(this);if(expanded!=null)expanded.dismiss();if(controller!=null)controller.removeListener(listener);if(connection!=null)MediaController.releaseFuture(connection);connection=null;controller=null;super.onStop();}
    @Override protected void onDestroy(){pendingPlayTracks=null;repository.close();main.removeCallbacksAndMessages(null);super.onDestroy();}
}
