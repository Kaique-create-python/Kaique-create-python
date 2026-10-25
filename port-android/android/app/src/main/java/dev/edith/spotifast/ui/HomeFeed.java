package dev.edith.spotifast.ui;

import android.app.Activity;
import android.graphics.drawable.GradientDrawable;
import android.text.TextUtils;
import android.view.*;
import android.widget.*;
import dev.edith.spotifast.data.MusicDatabase;
import dev.edith.spotifast.data.Track;
import java.util.*;
import static dev.edith.spotifast.ui.Design.*;

/**
 * Responsive, data-driven SpotiFast home. Every card comes from a real
 * provider response or the user's own playback/library history; never
 * displays fictional tracks or fake recommendations.
 */
public final class HomeFeed {
    public interface Actions {
        void play(List<Track> tracks, int index);
        void filter(String provider, String genre);
        void playlists();
        void library();
        void search();
        void playlist(MusicDatabase.Playlist playlist);
    }

    private final Activity activity;
    private final LinearLayout content;
    private final Actions actions;
    private final LinearLayout recentShelf, trendingShelf, playlistShelf;
    private final LinearLayout featured;
    private final LinearLayout recentSection, playlistsSection;
    private final TextView featuredLabel;
    private final LinearLayout mixShelf,mixSection;

    private static final int TILE_WIDTH = 124;
    private static final int COVER = 118;

    public HomeFeed(Activity activity, LinearLayout content, Actions actions) {
        this.activity = activity;
        this.content = content;
        this.actions = actions;
        this.recentShelf = row(activity);
        this.trendingShelf = row(activity);
        this.playlistShelf = row(activity);
        this.featured = column(activity);
        this.recentSection = column(activity);
        this.playlistsSection = column(activity);
        this.featuredLabel = text(activity, "", 16, true);
        mixShelf=row(activity);mixSection=column(activity);
        build();
    }

    private LinearLayout.LayoutParams width(int w, int h) {
        return new LinearLayout.LayoutParams(w < 0 ? w : dp(activity, w),
                h < 0 ? h : dp(activity, h));
    }

    private void build() {
        content.setPadding(0, dp(activity, 10), 0, dp(activity, 20));
        String greeting = Calendar.getInstance().get(Calendar.HOUR_OF_DAY) < 12
                ? "Bom dia!" : Calendar.getInstance().get(Calendar.HOUR_OF_DAY) < 18
                ? "Boa tarde!" : "Boa noite!";
        TextView hello = text(activity, greeting, 29, true);
        content.addView(hello);
        gap(activity, content, 2);
        TextView subtitle = text(activity, "O som certo para cada momento.", 14, false);
        subtitle.setTextColor(MUTED);
        content.addView(subtitle);
        gap(activity, content, 16);

        HorizontalScrollView chips = new HorizontalScrollView(activity);
        chips.setHorizontalScrollBarEnabled(false);
        chips.setClipToPadding(false);
        LinearLayout options = row(activity);
        String[] names = {"Tudo", "Audius", "Jamendo", "Eletrônica", "Pop", "Rock"};
        for (int i = 0; i < names.length; i++) {
            final int position = i;
            Button chip = button(activity, names[i], i == 0);
            chip.setContentDescription("Filtrar músicas por " + names[i]);
            LinearLayout.LayoutParams lp = width(-2, 42);
            lp.rightMargin = dp(activity, 8);
            options.addView(chip, lp);
            chip.setOnClickListener(v -> {
                for (int j = 0; j < options.getChildCount(); j++) {
                    Button b = (Button) options.getChildAt(j);
                    b.setTextColor(j == position ? BG : WHITE);
                    b.setBackground(shape(activity, j == position ? GREEN : PANEL, 22));
                }
                switch (position) {
                    case 1: actions.filter("audius", ""); break;
                    case 2: actions.filter("jamendo", ""); break;
                    case 3: actions.filter("all", "Electronic"); break;
                    case 4: actions.filter("all", "Pop"); break;
                    case 5: actions.filter("all", "Rock"); break;
                    default: actions.filter("all", ""); break;
                }
            });
        }
        chips.addView(options);
        content.addView(chips, width(-1, 50));
        gap(activity, content, 20);

        sectionTitle(recentSection, "Tocados recentemente", "Biblioteca", actions::library);
        addScroller(recentSection, recentShelf);
        recentSection.setVisibility(View.GONE);
        content.addView(recentSection, width(-1, -2));

        featured.setVisibility(View.GONE);
        content.addView(featured, width(-1, -2));

        LinearLayout trending = column(activity);
        sectionTitle(trending, "Em alta nas fontes", "Explorar", actions::search);
        addScroller(trending, trendingShelf);
        content.addView(trending, width(-1, -2));
        gap(activity, content, 16);

        sectionTitle(mixSection,"Seu mix local","Biblioteca",actions::library);
        addScroller(mixSection,mixShelf);mixSection.setVisibility(View.GONE);content.addView(mixSection,width(-1,-2));

        sectionTitle(playlistsSection, "Suas playlists", "Ver todas", actions::playlists);
        addScroller(playlistsSection, playlistShelf);
        playlistsSection.setVisibility(View.GONE);
        content.addView(playlistsSection, width(-1, -2));

        TextView all = text(activity, "Mais músicas para descobrir", 21, true);
        all.setPadding(0, dp(activity, 8), 0, dp(activity, 3));
        content.addView(all);
    }

    private void sectionTitle(LinearLayout parent, String name, String right, Runnable action) {
        LinearLayout titleRow = row(activity);
        TextView title = text(activity, name, 21, true);
        title.setMaxLines(2);
        titleRow.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        TextView link = text(activity, right + " ›", 13, true);
        link.setTextColor(GREEN);
        link.setGravity(Gravity.CENTER);
        link.setPadding(dp(activity, 8), dp(activity, 8), dp(activity, 4), dp(activity, 8));
        link.setOnClickListener(v -> action.run());
        titleRow.addView(link);
        parent.addView(titleRow, width(-1, -2));
        gap(activity, parent, 10);
    }

    private void addScroller(LinearLayout parent, LinearLayout shelf) {
        HorizontalScrollView scroll = new HorizontalScrollView(activity);
        scroll.setHorizontalScrollBarEnabled(false);
        scroll.setFillViewport(false);
        scroll.setClipToPadding(false);
        scroll.addView(shelf, new android.widget.FrameLayout.LayoutParams(-2, -2));
        parent.addView(scroll, width(-1, -2));
        gap(activity, parent, 20);
    }

    private List<Track> playable(List<Track> source) {
        List<Track> out = new ArrayList<>();
        for (Track t : source) if (t.playable()) out.add(t);
        return out;
    }

    private void cards(LinearLayout shelf, List<Track> source, int limit) {
        shelf.removeAllViews();
        List<Track> eligible = playable(source);
        for (int i = 0; i < Math.min(limit, eligible.size()); i++) {
            final int index = i;
            Track t = eligible.get(i);
            LinearLayout card = column(activity);
            card.setPadding(dp(activity, 2), 0, dp(activity, 4), dp(activity, 4));
            ImageView image = new ImageView(activity);
            card.addView(image, width(COVER, COVER));
            ImageRepository.load(activity, t.artwork, image, dp(activity, COVER));
            gap(activity, card, 7);
            TextView title = text(activity, t.title, 13, true);
            title.setSingleLine(true);
            title.setEllipsize(TextUtils.TruncateAt.END);
            card.addView(title, width(-1, -2));
            TextView artist = text(activity, t.artist, 12, false);
            artist.setTextColor(MUTED);
            artist.setSingleLine(true);
            artist.setEllipsize(TextUtils.TruncateAt.END);
            card.addView(artist, width(-1, -2));
            card.setContentDescription("Ouvir " + t.title + " de " + t.artist);
            card.setOnClickListener(v -> actions.play(eligible, index));
            shelf.addView(card, width(TILE_WIDTH, -2));
        }
    }

    public void showRecent(List<Track> tracks) {
        if (tracks == null || tracks.isEmpty()) {
            recentSection.setVisibility(View.GONE);
            return;
        }
        cards(recentShelf, tracks, 10);
        recentSection.setVisibility(recentShelf.getChildCount() > 0 ? View.VISIBLE : View.GONE);
    }
    public void showRecommendations(List<Track> tracks){
        cards(mixShelf,tracks,10);mixSection.setVisibility(mixShelf.getChildCount()>0?View.VISIBLE:View.GONE);
    }

    public void showTrending(List<Track> tracks) {
        cards(trendingShelf, tracks, 12);
        featured.removeAllViews();
        List<Track> allowed = playable(tracks);
        if (allowed.isEmpty()) {
            featured.setVisibility(View.GONE);
            return;
        }
        Track t = allowed.get(0);
        featured.setVisibility(View.VISIBLE);
        featured.setBackground(gradient(activity, 0xff183a2e, 0xff142020, 20));
        featured.setPadding(dp(activity, 14), dp(activity, 14), dp(activity, 12), dp(activity, 14));
        LinearLayout inner = row(activity);
        LinearLayout details = column(activity);
        TextView kicker = text(activity, "EM DESTAQUE  •  " + t.provider.toUpperCase(Locale.ROOT), 11, true);
        kicker.setTextColor(GREEN);
        details.addView(kicker);
        gap(activity, details, 9);
        TextView title = text(activity, t.title, 23, true);
        title.setMaxLines(2);
        title.setEllipsize(TextUtils.TruncateAt.END);
        details.addView(title);
        gap(activity, details, 4);
        TextView artist = text(activity, t.artist, 13, false);
        artist.setTextColor(MUTED);
        artist.setMaxLines(1);
        artist.setEllipsize(TextUtils.TruncateAt.END);
        details.addView(artist);
        gap(activity, details, 16);
        Button play = button(activity, "▶  Ouvir agora", true);
        play.setOnClickListener(v -> actions.play(allowed, 0));
        details.addView(play, width(-2, 46));
        inner.addView(details, new LinearLayout.LayoutParams(0, -2, 1));
        ImageView cover = new ImageView(activity);
        LinearLayout.LayoutParams cp = width(106, 106);
        cp.leftMargin = dp(activity, 10);
        inner.addView(cover, cp);
        ImageRepository.load(activity, t.artwork, cover, dp(activity, 106));
        featured.addView(inner, width(-1, -2));
        LinearLayout.LayoutParams cardParams = (LinearLayout.LayoutParams)featured.getLayoutParams();
        if (cardParams != null) {
            cardParams.bottomMargin = dp(activity, 22);
            featured.setLayoutParams(cardParams);
        }
    }

    public void showPlaylists(List<MusicDatabase.Playlist> playlists) {
        playlistShelf.removeAllViews();
        if (playlists == null || playlists.isEmpty()) {
            playlistsSection.setVisibility(View.GONE);
            return;
        }
        for (int i = 0; i < Math.min(8, playlists.size()); i++) {
            MusicDatabase.Playlist p = playlists.get(i);
            LinearLayout card = column(activity);
            ImageView cover = new ImageView(activity);
            card.addView(cover, width(COVER, COVER));
            ImageRepository.load(activity, p.artwork == null ? "" : p.artwork, cover, dp(activity, COVER));
            gap(activity, card, 8);
            TextView title = text(activity, p.name, 14, true);
            title.setSingleLine();
            title.setEllipsize(TextUtils.TruncateAt.END);
            card.addView(title);
            TextView subtitle = text(activity, p.count + " músicas", 12, false);
            subtitle.setTextColor(MUTED);
            card.addView(subtitle);
            card.setOnClickListener(v -> actions.playlist(p));
            playlistShelf.addView(card, width(TILE_WIDTH, -2));
        }
        playlistsSection.setVisibility(View.VISIBLE);
    }
}

