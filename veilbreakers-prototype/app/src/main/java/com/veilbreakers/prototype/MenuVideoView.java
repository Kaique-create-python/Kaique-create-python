package com.veilbreakers.prototype;

import android.content.Context;
import android.graphics.Matrix;
import android.graphics.SurfaceTexture;
import android.media.MediaPlayer;
import android.view.Surface;
import android.view.TextureView;

public class MenuVideoView extends TextureView implements TextureView.SurfaceTextureListener {
    private MediaPlayer player;
    private Surface surface;
    private int videoW = 0;
    private int videoH = 0;
    private boolean wantsPlayback = true;

    public MenuVideoView(Context context) {
        super(context);
        setSurfaceTextureListener(this);
        setOpaque(true);
        setKeepScreenOn(true);
    }

    @Override
    public void onSurfaceTextureAvailable(SurfaceTexture texture, int width, int height) {
        releasePlayer();
        surface = new Surface(texture);
        player = MediaPlayer.create(getContext(), R.raw.menu_background);
        if (player == null) return;

        player.setSurface(surface);
        player.setLooping(true);
        player.setVolume(0f, 0f);
        player.setOnVideoSizeChangedListener((mp, w, h) -> {
            videoW = w;
            videoH = h;
            SurfaceTexture st = getSurfaceTexture();
            if (st != null && w > 0 && h > 0) st.setDefaultBufferSize(w, h);
            applyCenterCrop();
        });
        player.setOnPreparedListener(mp -> {
            videoW = mp.getVideoWidth();
            videoH = mp.getVideoHeight();
            SurfaceTexture st = getSurfaceTexture();
            if (st != null && videoW > 0 && videoH > 0) st.setDefaultBufferSize(videoW, videoH);
            applyCenterCrop();
            if (wantsPlayback) mp.start();
        });

        // MediaPlayer.create() returns an already-prepared player, so the prepared callback
        // may not fire on every Android version. Start safely here as well.
        videoW = player.getVideoWidth();
        videoH = player.getVideoHeight();
        applyCenterCrop();
        if (wantsPlayback) {
            try { player.start(); } catch (IllegalStateException ignored) {}
        }
    }

    @Override
    public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
        applyCenterCrop();
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture texture) {
        releasePlayer();
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture surface) {
        // No per-frame work. MediaPlayer renders directly to the TextureView.
    }

    private void applyCenterCrop() {
        if (videoW <= 0 || videoH <= 0 || getWidth() <= 0 || getHeight() <= 0) return;

        float viewRatio = getWidth() / (float) getHeight();
        float videoRatio = videoW / (float) videoH;
        float scaleX = 1f;
        float scaleY = 1f;

        if (videoRatio > viewRatio) {
            scaleX = videoRatio / viewRatio;
        } else {
            scaleY = viewRatio / videoRatio;
        }

        Matrix matrix = new Matrix();
        matrix.setScale(scaleX, scaleY, getWidth() * 0.5f, getHeight() * 0.5f);
        setTransform(matrix);
    }

    public void pauseVideo() {
        wantsPlayback = false;
        if (player != null) {
            try {
                if (player.isPlaying()) player.pause();
            } catch (IllegalStateException ignored) {}
        }
    }

    public void resumeVideo() {
        wantsPlayback = true;
        if (player != null) {
            try {
                if (!player.isPlaying()) player.start();
            } catch (IllegalStateException ignored) {}
        }
    }

    public void releasePlayer() {
        if (player != null) {
            try { player.stop(); } catch (Exception ignored) {}
            try { player.reset(); } catch (Exception ignored) {}
            player.release();
            player = null;
        }
        if (surface != null) {
            surface.release();
            surface = null;
        }
    }

    @Override
    protected void onDetachedFromWindow() {
        releasePlayer();
        super.onDetachedFromWindow();
    }
}