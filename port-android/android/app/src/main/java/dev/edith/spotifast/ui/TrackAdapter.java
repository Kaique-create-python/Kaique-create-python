package dev.edith.spotifast.ui;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.graphics.drawable.RippleDrawable;
import android.text.TextUtils;
import android.view.*;
import android.widget.*;
import androidx.recyclerview.widget.RecyclerView;
import dev.edith.spotifast.data.Track;
import java.util.*;
import static dev.edith.spotifast.ui.Design.*;

/** Proper MATCH_PARENT rows keep weighted title/artist labels visible on Android. */
public final class TrackAdapter extends RecyclerView.Adapter<TrackAdapter.Holder> {
    public interface Actions { void play(int position); void menu(int position); }
    public final List<Track> tracks = new ArrayList<>();
    private final Activity activity;
    private final Actions actions;
    private boolean dragEnabled;

    public TrackAdapter(Activity activity, Actions actions) {
        this.activity = activity;
        this.actions = actions;
        setHasStableIds(true);
    }

    public void setDragEnabled(boolean enabled) { dragEnabled = enabled; }
    public void submit(List<Track> values) {
        tracks.clear();
        tracks.addAll(values);
        notifyDataSetChanged();
    }
    public void move(int from, int to) {
        Track t = tracks.remove(from);
        tracks.add(to, t);
        notifyItemMoved(from, to);
    }
    @Override public long getItemId(int position) { return tracks.get(position).key().hashCode(); }
    @Override public int getItemCount() { return tracks.size(); }

    @Override public Holder onCreateViewHolder(ViewGroup parent, int type) {
        LinearLayout root = row(activity);
        root.setOrientation(LinearLayout.HORIZONTAL);
        root.setGravity(Gravity.CENTER_VERTICAL);
        // Critical: a RecyclerView root without MATCH_PARENT measured as wrap_content.
        // Its 0dp/weight=1 text column consequently received ZERO WIDTH.
        root.setLayoutParams(new RecyclerView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.setPadding(dp(activity, 8), dp(activity, 9), dp(activity, 7), dp(activity, 9));
        root.setBackground(new RippleDrawable(
                ColorStateList.valueOf(0x2266eeaf), shape(activity, BG, 12), null));

        ImageView art = new ImageView(activity);
        art.setContentDescription("Capa da música");
        root.addView(art, new LinearLayout.LayoutParams(dp(activity, 58), dp(activity, 58)));

        LinearLayout info = column(activity);
        info.setGravity(Gravity.CENTER_VERTICAL);
        info.setPadding(dp(activity, 12), 0, dp(activity, 6), 0);
        TextView title = text(activity, "", 15, true);
        title.setMaxLines(1);
        title.setEllipsize(TextUtils.TruncateAt.END);
        TextView subtitle = text(activity, "", 12, false);
        subtitle.setMaxLines(1);
        subtitle.setTextColor(MUTED);
        subtitle.setEllipsize(TextUtils.TruncateAt.END);
        info.addView(title, new LinearLayout.LayoutParams(-1, -2));
        gap(activity, info, 5);
        info.addView(subtitle, new LinearLayout.LayoutParams(-1, -2));
        root.addView(info, new LinearLayout.LayoutParams(0, dp(activity, 58), 1));

        TextView more = text(activity, "⋮", 26, false);
        more.setGravity(Gravity.CENTER);
        more.setContentDescription("Opções da música");
        more.setBackground(new RippleDrawable(
                ColorStateList.valueOf(0x224fe7ac), shape(activity, BG, 24), null));
        root.addView(more, new LinearLayout.LayoutParams(dp(activity, 40), dp(activity, 48)));

        Holder h = new Holder(root, art, title, subtitle, more);
        root.setOnClickListener(v -> {
            int p = h.getBindingAdapterPosition();
            if (p != RecyclerView.NO_POSITION) actions.play(p);
        });
        root.setOnLongClickListener(v -> {
            if (dragEnabled) return false;
            int p = h.getBindingAdapterPosition();
            if (p != RecyclerView.NO_POSITION) actions.menu(p);
            return true;
        });
        more.setOnClickListener(v -> {
            int p = h.getBindingAdapterPosition();
            if (p != RecyclerView.NO_POSITION) actions.menu(p);
        });
        return h;
    }

    @Override public void onBindViewHolder(Holder h, int position) {
        Track t = tracks.get(position);
        h.title.setText(t.title);
        h.subtitle.setText(t.artist + "  •  " +
                (t.provider.equals("audius") ? "Audius" :
                 t.provider.equals("jamendo") ? "Jamendo" : "No celular") +
                (t.playable() ? "" : " • Indisponível"));
        h.itemView.setAlpha(t.playable() ? 1f : .55f);
        h.itemView.setContentDescription(t.title + ", " + t.artist);
        h.more.setContentDescription("Opções de " + t.title);
        ImageRepository.load(activity, t.artwork, h.art, dp(activity, 58));
    }

    @Override public void onViewRecycled(Holder h) {
        com.bumptech.glide.Glide.with(activity).clear(h.art);
    }

    public static final class Holder extends RecyclerView.ViewHolder {
        final ImageView art;
        final TextView title, subtitle, more;
        Holder(View root, ImageView art, TextView title, TextView subtitle, TextView more) {
            super(root);
            this.art = art;
            this.title = title;
            this.subtitle = subtitle;
            this.more = more;
        }
    }
}
