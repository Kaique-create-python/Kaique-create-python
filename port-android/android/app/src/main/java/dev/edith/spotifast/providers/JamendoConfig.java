package dev.edith.spotifast.providers;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * Public Jamendo API Client ID (not a client secret).
 *
 * The user-supplied ID is included intentionally so Jamendo works on the
 * first launch. Users can override it in Settings without rebuilding the app.
 * Do not store OAuth tokens or private secrets here.
 */
public final class JamendoConfig {
    public static final String DEFAULT_CLIENT_ID = "741278ed";
    public static final String PREFS_NAME = "FreeMusicActivity";
    public static final String KEY_CLIENT_ID = "jamendo_client_id";

    private JamendoConfig() {}

    public static String get(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String configured = preferences.getString(KEY_CLIENT_ID, "");
        return configured == null || configured.trim().isEmpty()
                ? DEFAULT_CLIENT_ID : configured.trim();
    }

    public static void save(Context context, String clientId) {
        String value = clientId == null ? "" : clientId.trim();
        // Empty value resets to the app's public default.
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putString(KEY_CLIENT_ID, value).apply();
    }
}
