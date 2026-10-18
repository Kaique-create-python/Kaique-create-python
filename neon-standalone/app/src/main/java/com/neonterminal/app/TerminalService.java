package com.neonterminal.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.os.IBinder;

/**
 * Foreground service keeps existing Android shell sessions running while UI is hidden.
 * Android battery policies may still terminate the process; not a guaranteed daemon.
 */
public final class TerminalService extends Service {
    private static final String CHANNEL = "neon_terminal_shell";
    private static final int ID = 721;
    public static final String STOP = "com.neonterminal.app.STOP_TERMINALS";

    @Override public void onCreate() {
        super.onCreate();
        TerminalRuntime.init(new java.io.File(getFilesDir(), "home"));
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL, "Sessões do Neon Terminal", NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("Mantém sessões do terminal enquanto o aplicativo está em segundo plano");
            channel.setLightColor(Color.RED);
            ((NotificationManager) getSystemService(NOTIFICATION_SERVICE))
                .createNotificationChannel(channel);
        }
    }

    private Notification buildNotification() {
        Intent open = new Intent(this, MainActivity.class);
        open.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent openPending = PendingIntent.getActivity(this, 0, open, flags);

        Intent stop = new Intent(this, TerminalService.class).setAction(STOP);
        PendingIntent stopPending = PendingIntent.getService(this, 1, stop, flags);
        int count = 0;
        for (TerminalRuntime.Session s : TerminalRuntime.sessions()) if (s.isRunning()) count++;

        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(this, CHANNEL) : new Notification.Builder(this);
        return builder
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("Neon Terminal")
            .setContentText(count + " sessão(ões) • toque para retornar")
            .setContentIntent(openPending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(new Notification.Action.Builder(
                android.R.drawable.ic_menu_close_clear_cancel, "Encerrar sessões", stopPending).build())
            .build();
    }

    public static void refresh(Service service) {
        if (!(service instanceof TerminalService)) return;
        ((NotificationManager) service.getSystemService(NOTIFICATION_SERVICE))
            .notify(ID, ((TerminalService) service).buildNotification());
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && STOP.equals(intent.getAction())) {
            TerminalRuntime.stopAll();
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        }
        startForeground(ID, buildNotification());
        return START_STICKY;
    }

    @Override public IBinder onBind(Intent intent) { return null; }

    @Override public void onDestroy() {
        TerminalRuntime.stopAll();
        super.onDestroy();
    }
}
