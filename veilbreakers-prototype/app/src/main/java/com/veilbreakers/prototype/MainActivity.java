package com.veilbreakers.prototype;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;

public class MainActivity extends Activity {
    private static final String PREFS = "veilbreakers_save";
    private View currentView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        applyImmersive();
        showMenu();
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
        currentView = new MainMenuView(this);
        setContentView(currentView);
        applyImmersive();
    }

    public void startGame(boolean continueGame) {
        SharedPreferences prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        if (!continueGame) {
            prefs.edit()
                    .putBoolean("has_save", true)
                    .remove("player_x_norm")
                    .remove("player_y_norm")
                    .remove("player_facing")
                    .apply();
        }
        currentView = new GameView(this, continueGame);
        setContentView(currentView);
        applyImmersive();
    }

    public void exitGame() {
        if (currentView instanceof GameView) ((GameView) currentView).saveState();
        finishAndRemoveTask();
    }

    @Override
    protected void onPause() {
        if (currentView instanceof GameView) ((GameView) currentView).saveState();
        super.onPause();
    }

    @Override
    public void onBackPressed() {
        if (currentView instanceof GameView) {
            ((GameView) currentView).saveState();
            showMenu();
            return;
        }
        if (currentView instanceof MainMenuView && ((MainMenuView) currentView).handleBack()) return;
        super.onBackPressed();
    }
}