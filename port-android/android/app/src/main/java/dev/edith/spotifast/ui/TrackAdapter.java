package dev.edith.spotifast.ui;

import android.app.Activity;
import android.view.*;
import android.widget.*;
import androidx.recyclerview.widget.RecyclerView;
import dev.edith.spotifast.data.Track;
import java.util.*;
import static dev.edith.spotifast.ui.Design.*;

public final class TrackAdapter extends RecyclerView.Adapter<TrackAdapter.Holder> {
    public interface Actions{void play(int position);void menu(int position);}
    public final List<Track> tracks=new ArrayList<>();private final Activity activity;private final Actions actions;private boolean dragEnabled;
    public TrackAdapter(Activity activity,Actions actions){this.activity=activity;this.actions=actions;}
    public void setDragEnabled(boolean enabled){dragEnabled=enabled;}
    public void submit(List<Track> values){tracks.clear();tracks.addAll(values);notifyDataSetChanged();}
    public void move(int from,int to){Track t=tracks.remove(from);tracks.add(to,t);notifyItemMoved(from,to);}
    @Override public int getItemCount(){return tracks.size();}
    @Override public Holder onCreateViewHolder(ViewGroup parent,int type){
        LinearLayout row=row(activity);row.setPadding(dp(activity,4),dp(activity,7),dp(activity,4),dp(activity,7));
        row.setBackground(new android.graphics.drawable.RippleDrawable(android.content.res.ColorStateList.valueOf(0x3344dd99),shape(activity,BG,12),null));
        ImageView art=new ImageView(activity);art.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);row.addView(art,new LinearLayout.LayoutParams(dp(activity,56),dp(activity,56)));
        LinearLayout info=column(activity);info.setPadding(dp(activity,12),0,dp(activity,6),0);TextView title=text(activity,"",16,true),subtitle=text(activity,"",12,false);title.setMaxLines(2);subtitle.setSingleLine();subtitle.setTextColor(MUTED);subtitle.setEllipsize(android.text.TextUtils.TruncateAt.END);info.addView(title);gap(activity,info,4);info.addView(subtitle);row.addView(info,new LinearLayout.LayoutParams(0,-2,1));Button more=button(activity,"⋮",false);more.setTextSize(23);row.addView(more,new LinearLayout.LayoutParams(dp(activity,48),dp(activity,48)));
        Holder h=new Holder(row,art,title,subtitle);row.setOnClickListener(v->{int p=h.getBindingAdapterPosition();if(p!=RecyclerView.NO_POSITION)actions.play(p);});row.setOnLongClickListener(v->{if(dragEnabled)return false;int p=h.getBindingAdapterPosition();if(p!=RecyclerView.NO_POSITION)actions.menu(p);return true;});more.setOnClickListener(v->{int p=h.getBindingAdapterPosition();if(p!=RecyclerView.NO_POSITION)actions.menu(p);});return h;
    }
    @Override public void onBindViewHolder(Holder h,int position){Track t=tracks.get(position);h.title.setText(t.title);h.subtitle.setText(t.artist+" · "+t.provider+(t.playable()?"":" · Indisponível"));h.itemView.setAlpha(t.playable()?1:.55f);h.itemView.setContentDescription(t.title+", "+t.artist+", "+t.provider);((ViewGroup)h.itemView).getChildAt(2).setContentDescription("Opções de "+t.title);ImageRepository.load(activity,t.artwork,h.art,dp(activity,56));}
    @Override public void onViewRecycled(Holder h){com.bumptech.glide.Glide.with(activity).clear(h.art);}
    public static final class Holder extends RecyclerView.ViewHolder{final ImageView art;final TextView title,subtitle;Holder(View root,ImageView art,TextView title,TextView subtitle){super(root);this.art=art;this.title=title;this.subtitle=subtitle;}}
}
