package com.kaique.atomstudio;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class LiveMicStreamer {

    public interface Control {
        void startBlockingPython(String code);
        void finishBlockingPython();
        String host();
        void status(String text, boolean ok);
        void log(String text);
    }

    private static final int PORT = 8267;
    private static final int RATE = 16000;

    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile boolean stop;
    private volatile Socket activeSocket;
    private volatile AudioRecord recorder;

    public void start(int volumePercent, Control ctl) {
        if (recorder != null || activeSocket != null) {
            ctl.status("O microfone já está transmitindo.", false);
            return;
        }

        stop = false;
        worker.execute(() -> run(volumePercent, ctl));
    }

    public void stop() {
        stop = true;

        AudioRecord r = recorder;
        recorder = null;

        if (r != null) {
            try { r.stop(); } catch (Exception ignored) {}
            try { r.release(); } catch (Exception ignored) {}
        }

        Socket s = activeSocket;
        activeSocket = null;

        if (s != null) {
            try { s.close(); } catch (Exception ignored) {}
        }
    }

    public void shutdown() {
        stop();
        worker.shutdownNow();
    }

    private void run(int volumePercent, Control ctl) {
        Socket socket = null;
        AudioRecord localRecorder = null;

        try {
            ctl.status("Preparando microfone estável...", true);
            ctl.startBlockingPython(serverCode());

            Thread.sleep(700);

            String host = ctl.host();

            if (host == null || host.isEmpty()) {
                throw new IllegalStateException("IP do ATOM inválido.");
            }

            socket = connectWithRetry(host, PORT, 7000);
            socket.setTcpNoDelay(true);
            socket.setSendBufferSize(8192);
            socket.setSoTimeout(5000);
            activeSocket = socket;

            InputStream inReady = socket.getInputStream();
            OutputStream out = socket.getOutputStream();

            int ready = inReady.read();

            if (ready != 82) {
                throw new IllegalStateException("ATOM não confirmou o I2S. Código=" + ready);
            }

            socket.setSoTimeout(0);

            int min = AudioRecord.getMinBufferSize(
                    RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT);

            int bufferSize = Math.max(min, 4096);

            localRecorder = new AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION,
                    RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize);

            if (localRecorder.getState() != AudioRecord.STATE_INITIALIZED) {
                throw new IllegalStateException(
                        "Não consegui inicializar o microfone do celular.");
            }

            recorder = localRecorder;

            byte[] mono = new byte[1024];

            localRecorder.startRecording();

            ctl.status("MIC AO VIVO → ATOM. Nada está sendo salvo.", true);

            while (!stop) {
                int n = localRecorder.read(mono, 0, mono.length);

                if (n <= 0) {
                    continue;
                }

                byte[] stereo =
                        monoToStereo(
                                mono,
                                n,
                                volumePercent);

                out.write(stereo);
            }

            try { out.flush(); } catch (Exception ignored) {}

            ctl.status("Microfone ao vivo parado.", true);

        } catch (Exception e) {
            if (!stop) {
                ctl.status("Erro no microfone: " + e.getMessage(), false);
                ctl.log("\n[MIC] " + e + "\n");
            }

        } finally {
            recorder = null;
            activeSocket = null;

            try {
                if (localRecorder != null) {
                    localRecorder.stop();
                    localRecorder.release();
                }
            } catch (Exception ignored) {}

            try {
                if (socket != null) {
                    socket.close();
                }
            } catch (Exception ignored) {}

            try {
                Thread.sleep(250);
                ctl.finishBlockingPython();
            } catch (Exception ignored) {}
        }
    }

    private static Socket connectWithRetry(String host, int port, long timeoutMs) throws Exception {
        long end = System.currentTimeMillis() + timeoutMs;
        Exception last = null;

        while (System.currentTimeMillis() < end) {
            Socket s = new Socket();
            try {
                s.connect(new InetSocketAddress(host, port), 700);
                return s;
            } catch (Exception e) {
                last = e;
                try { s.close(); } catch (Exception ignored) {}
                Thread.sleep(180);
            }
        }

        throw last != null ? last : new IllegalStateException("Servidor de microfone do ATOM não abriu.");
    }

    private static byte[] monoToStereo(
            byte[] mono,
            int length,
            int volumePercent) {

        double gain =
                Math.max(
                        0.05,
                        Math.min(
                                volumePercent / 100.0,
                                0.70));

        int samples =
                length / 2;

        ByteBuffer in =
                ByteBuffer
                        .wrap(
                                mono,
                                0,
                                samples * 2)
                        .order(
                                ByteOrder.LITTLE_ENDIAN);

        ByteBuffer out =
                ByteBuffer
                        .allocate(
                                samples * 4)
                        .order(
                                ByteOrder.LITTLE_ENDIAN);

        for (int i = 0; i < samples; i++) {
            int v =
                    (int) Math.round(
                            in.getShort() * gain);

            v =
                    Math.max(
                            -32768,
                            Math.min(
                                    32767,
                                    v));

            short s =
                    (short) v;

            out.putShort(s);
            out.putShort(s);
        }

        return out.array();
    }

    private static String serverCode() {
        return "import socket,gc\n" +
                "from machine import I2S,Pin\n" +
                "s=None\n" +
                "c=None\n" +
                "a=None\n" +
                "try:\n" +
                " s=socket.socket()\n" +
                " try:s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)\n" +
                " except:pass\n" +
                " s.bind(('0.0.0.0'," + PORT + "))\n" +
                " s.listen(1)\n" +
                " print('__MIC_READY__')\n" +
                " c,_=s.accept()\n" +
                " gc.collect()\n" +
                " a=I2S(0,sck=Pin(19),ws=Pin(33),sd=Pin(22),mode=I2S.TX,bits=16,format=I2S.STEREO,rate=" + RATE + ",ibuf=8192)\n" +
                " c.send(b'R')\n" +
                " print('__MIC_I2S_OK__')\n" +
                " b=bytearray(2048)\n" +
                " while True:\n" +
                "  d=c.recv(2048)\n" +
                "  if not d:break\n" +
                "  a.write(d)\n" +
                "except Exception as e:\n" +
                " try:\n" +
                "  if c:c.send(b'E')\n" +
                " except:pass\n" +
                " print('__MIC_ERROR__',repr(e))\n" +
                "finally:\n" +
                " try:a.deinit()\n" +
                " except:pass\n" +
                " try:c.close()\n" +
                " except:pass\n" +
                " try:s.close()\n" +
                " except:pass\n" +
                " gc.collect()\n" +
                " print('__MIC_DONE__')\n";
    }
}
