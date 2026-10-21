package dev.edith.spotifast;

import android.app.NativeActivity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/**
 * Thin Android bridge for the ORIGINAL Rust SpotiFast UI and playback engine.
 * Never handles Spotify login credentials itself: opens the system browser,
 * and encrypts reusable OAuth grants using a non-exportable AndroidKeyStore key.
 */
public final class SpotiFastActivity extends NativeActivity {
    private static final String STORE = "spotifast.sealed_grants.v1";
    private static final String KEY_ALIAS = "dev.edith.spotifast.grants.aes.v1";
    private static final int IV_BYTES = 12;

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
    }

    public String appFilesPath() {
        return getFilesDir().getAbsolutePath();
    }

    public void openExternalUrl(String url) {
        if (url == null || (!url.startsWith("https://") && !url.startsWith("http://"))) {
            throw new IllegalArgumentException("Unsupported URL protocol");
        }
        runOnUiThread(() -> {
            try {
                Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                intent.addCategory(Intent.CATEGORY_BROWSABLE);
                startActivity(intent);
            } catch (ActivityNotFoundException | SecurityException e) {
                android.util.Log.e("SpotiFast", "No browser found to complete sign-in", e);
            }
        });
    }

    private synchronized SecretKey secretKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        if (keyStore.containsAlias(KEY_ALIAS)) {
            KeyStore.Entry entry = keyStore.getEntry(KEY_ALIAS, null);
            if (entry instanceof KeyStore.SecretKeyEntry) {
                return ((KeyStore.SecretKeyEntry) entry).getSecretKey();
            }
            throw new IOException("Android Keystore entry has the wrong type");
        }
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build());
        return generator.generateKey();
    }

    private SharedPreferences grants() {
        return getSharedPreferences(STORE, MODE_PRIVATE);
    }

    public synchronized byte[] readSecret(String key) throws Exception {
        String encrypted = grants().getString(key, null);
        if (encrypted == null) return null;
        byte[] payload = Base64.decode(encrypted, Base64.NO_WRAP);
        if (payload.length <= IV_BYTES + 16) throw new IOException("Encrypted grant is truncated");
        byte[] iv = Arrays.copyOfRange(payload, 0, IV_BYTES);
        byte[] ciphertext = Arrays.copyOfRange(payload, IV_BYTES, payload.length);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, secretKey(), new GCMParameterSpec(128, iv));
        cipher.updateAAD(key.getBytes(StandardCharsets.UTF_8));
        return cipher.doFinal(ciphertext);
    }

    public synchronized void writeSecret(String key, byte[] secret) throws Exception {
        if (key == null || key.isEmpty() || secret == null) throw new IllegalArgumentException();
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, secretKey());
        cipher.updateAAD(key.getBytes(StandardCharsets.UTF_8));
        byte[] iv = cipher.getIV();
        if (iv == null || iv.length != IV_BYTES) throw new IOException("Invalid encryption IV");
        byte[] encrypted = cipher.doFinal(secret);
        byte[] payload = new byte[iv.length + encrypted.length];
        System.arraycopy(iv, 0, payload, 0, iv.length);
        System.arraycopy(encrypted, 0, payload, iv.length, encrypted.length);
        if (!grants().edit().putString(key, Base64.encodeToString(payload, Base64.NO_WRAP)).commit()) {
            throw new IOException("Could not persist encrypted grant");
        }
    }

    public synchronized void deleteSecret(String key) throws Exception {
        if (!grants().edit().remove(key).commit()) {
            throw new IOException("Could not delete encrypted grant");
        }
    }
}
