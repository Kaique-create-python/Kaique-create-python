package com.veilbreakers.prototype;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.FrameLayout;

public class MainActivity extends Activity {
    private static final String PREFS = "veilbreakers_save";
    private View currentView;
    private MenuVideoView menuVideo;
    private String reviewState = "idle";
    private int reviewDirection = 0;
    private int reviewFrame = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        applyImmersive();
        if (BuildConfig.DEBUG && getIntent().getBooleanExtra("art_review", false)) {
            showArtReview(getIntent());
            return;
        }
        showMenu();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (BuildConfig.DEBUG && intent.getBooleanExtra("art_review", false)) {
            showArtReview(intent);
        }
    }

    private void showArtReview(Intent intent) {
        if (!BuildConfig.DEBUG) return;
        if (intent.hasExtra("review_state")) reviewState = intent.getStringExtra("review_state");
        if (intent.hasExtra("review_direction")) reviewDirection = intent.getIntExtra("review_direction", 0);
        if (intent.hasExtra("review_frame")) reviewFrame = intent.getIntExtra("review_frame", 0);
        GameView review;
        if (currentView instanceof GameView) {
            review = (GameView) currentView;
        } else {
            if (menuVideo != null) {
                menuVideo.releasePlayer();
                menuVideo = null;
            }
            review = new GameView(this, false);
            currentView = review;
            setContentView(review);
        }
        review.setArtReview(reviewState, reviewDirection, reviewFrame);
        applyImmersive();
    }

    private void applyImmersive() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN |
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }

    public void showMenu() {
        if (currentView instanceof GameView) ((GameView) currentView).saveState();

        FrameLayout root = new FrameLayout(this);
        menuVideo = new MenuVideoView(this);
        MainMenuView menu = new MainMenuView(this);

        root.addView(menuVideo, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        root.addView(menu, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        currentView = menu;
        setContentView(root);
        applyImmersive();
    }

    public void startGame(boolean continueGame) {
        SharedPreferences prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (!continueGame) {
            prefs.edit().clear().putBoolean("has_save", true).putBoolean("vibration", true).apply();
        }

        if (menuVideo != null) {
            menuVideo.releasePlayer();
            menuVideo = null;
        }

        currentView = new GameView(this, continueGame);
        setContentView(currentView);
        applyImmersive();
    }

    public void exitGame() {
        if (currentView instanceof GameView) ((GameView) currentView).saveState();
        if (menuVideo != null) {
            menuVideo.releasePlayer();
            menuVideo = null;
        }
        finishAndRemoveTask();
    }

    @Override
    protected void onPause() {
        if (currentView instanceof GameView) ((GameView) currentView).saveState();
        if (menuVideo != null) menuVideo.pauseVideo();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        applyImmersive();
        if (menuVideo != null) menuVideo.resumeVideo();
    }

    @Override
    public void onBackPressed() {
        if (currentView instanceof GameView) {
            GameView game = (GameView) currentView;
            if (game.handleBack()) return;
            game.saveState();
            showMenu();
            return;
        }
        if (currentView instanceof MainMenuView && ((MainMenuView) currentView).handleBack()) return;
        super.onBackPressed();
    }
}
