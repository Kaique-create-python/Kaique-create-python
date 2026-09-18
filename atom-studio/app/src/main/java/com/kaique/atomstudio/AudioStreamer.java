package com.kaique.atomstudio;

import android.content.Context;
import android.media.AudioFormat;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.net.Uri;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class AudioStreamer {
    public interface Control {
        void runPython(String code);
        String host();
        void status(String text, boolean ok);
        void log(String text);
    }

    private static final int PORT = 8267;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private volatile Socket activeSocket;
    private volatile boolean stop;

    public void start(Context context, Uri uri, int volumePercent, Control ctl) {
        if (activeSocket != null) {
            ctl.status("Já existe um áudio sendo transmitido.", false);
            return;
        }

        stop = false;
        worker.execute(() -> stream(context, uri, volumePercent, ctl));
    }

    public void stop() {
        stop = true;
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

    private void stream(Context context, Uri uri, int volumePercent, Control ctl) {
        MediaExtractor extractor = new MediaExtractor();
        MediaCodec decoder = null;
        Socket socket = null;

        try {
            extractor.setDataSource(context, uri, null);

            int track = -1;
            MediaFormat inputFormat = null;

            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat f = extractor.getTrackFormat(i);
                String mime = f.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    track = i;
                    inputFormat = f;
                    break;
                }
            }

            if (track < 0 || inputFormat == null) {
                throw new IllegalStateException("Nenhuma faixa de áudio encontrada.");
            }

            extractor.selectTrack(track);

            String mime = inputFormat.getString(MediaFormat.KEY_MIME);
            int rate = inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)
                    ? inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE) : 16000;
            int channels = inputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
                    ? inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT) : 1;

            int safeRate = Math.max(8000, Math.min(rate, 48000));

            ctl.status("Preparando áudio em " + safeRate + " Hz...", true);
            ctl.runPython(serverCode(safeRate));

            Thread.sleep(1100);

            String host = ctl.host();
            if (host == null || host.isEmpty()) {
                throw new IllegalStateException("IP do ATOM inválido.");
            }

            socket = new Socket();
            socket.connect(new InetSocketAddress(host, PORT), 5000);
            socket.setTcpNoDelay(true);
            socket.setSendBufferSize(32768);
            activeSocket = socket;

            OutputStream out = socket.getOutputStream();

            decoder = MediaCodec.createDecoderByType(mime);
            decoder.configure(inputFormat, null, null, 0);
            decoder.start();

            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            boolean inputDone = false;
            boolean outputDone = false;
            int pcmEncoding = AudioFormat.ENCODING_PCM_16BIT;
            int outputChannels = channels;

            ctl.status("Transmitindo áudio ao vivo. Nada é salvo no ATOM.", true);

            while (!outputDone && !stop) {
                if (!inputDone) {
                    int inIndex = decoder.dequeueInputBuffer(10000);
                    if (inIndex >= 0) {
                        ByteBuffer in = decoder.getInputBuffer(inIndex);
                        if (in != null) {
                            in.clear();
                            int size = extractor.readSampleData(in, 0);
                            if (size < 0) {
                                decoder.queueInputBuffer(
                                        inIndex, 0, 0, 0,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                                inputDone = true;
                            } else {
                                long pts = extractor.getSampleTime();
                                decoder.queueInputBuffer(inIndex, 0, size, pts, 0);
                                extractor.advance();
                            }
                        }
                    }
                }

                int outIndex = decoder.dequeueOutputBuffer(info, 10000);

                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    MediaFormat f = decoder.getOutputFormat();
                    if (f.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        outputChannels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                    }
                    if (f.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                        pcmEncoding = f.getInteger(MediaFormat.KEY_PCM_ENCODING);
                    }
                } else if (outIndex >= 0) {
                    ByteBuffer b = decoder.getOutputBuffer(outIndex);
                    if (b != null && info.size > 0) {
                        b.position(info.offset);
                        b.limit(info.offset + info.size);

                        byte[] decoded = new byte[info.size];
                        b.get(decoded);

                        byte[] stereo = toStereo16(
                                decoded,
                                Math.max(1, outputChannels),
                                pcmEncoding,
                                volumePercent);

                        if (stereo.length > 0) out.write(stereo);
                    }

                    outputDone = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                    decoder.releaseOutputBuffer(outIndex, false);
                }
            }

            try { out.flush(); } catch (Exception ignored) {}
            ctl.status(stop ? "Áudio parado." : "Áudio terminou.", true);

        } catch (Exception e) {
            if (!stop) {
                ctl.status("Erro no áudio: " + e.getMessage(), false);
                ctl.log("\n[AUDIO] " + e + "\n");
            }
        } finally {
            activeSocket = null;
            try { if (socket != null) socket.close(); } catch (Exception ignored) {}
            try {
                if (decoder != null) {
                    decoder.stop();
                    decoder.release();
                }
            } catch (Exception ignored) {}
            try { extractor.release(); } catch (Exception ignored) {}
        }
    }

    private static String serverCode(int rate) {
        return "import _thread,socket\n" +
                "from machine import I2S,Pin\n" +
                "def __atom_audio_server():\n" +
                " s=None\n" +
                " c=None\n" +
                " a=None\n" +
                " try:\n" +
                "  s=socket.socket()\n" +
                "  try:s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)\n" +
                "  except:pass\n" +
                "  s.bind(('0.0.0.0'," + PORT + "))\n" +
                "  s.listen(1)\n" +
                "  print('__AUDIO_READY__')\n" +
                "  c,_=s.accept()\n" +
                "  a=I2S(0,sck=Pin(19),ws=Pin(33),sd=Pin(22),mode=I2S.TX,bits=16,format=I2S.STEREO,rate=" + rate + ",ibuf=32768)\n" +
                "  b=bytearray(4096)\n" +
                "  while True:\n" +
                "   n=c.recv_into(b)\n" +
                "   if not n:break\n" +
                "   a.write(memoryview(b)[:n])\n" +
                " except Exception as e:\n" +
                "  print('__AUDIO_ERROR__',repr(e))\n" +
                " finally:\n" +
                "  try:a.deinit()\n" +
                "  except:pass\n" +
                "  try:c.close()\n" +
                "  except:pass\n" +
                "  try:s.close()\n" +
                "  except:pass\n" +
                "  print('__AUDIO_DONE__')\n" +
                "_thread.start_new_thread(__atom_audio_server,())\n" +
                "print('__AUDIO_THREAD_STARTED__')\n";
    }

    private static byte[] toStereo16(byte[] src, int channels, int encoding, int volume) {
        double gain = Math.max(0.05, Math.min(volume / 100.0, 0.70));

        int bytesPerSample;
        if (encoding == AudioFormat.ENCODING_PCM_FLOAT) bytesPerSample = 4;
        else if (encoding == AudioFormat.ENCODING_PCM_8BIT) bytesPerSample = 1;
        else bytesPerSample = 2;

        int frameBytes = bytesPerSample * channels;
        if (frameBytes <= 0) return new byte[0];

        int frames = src.length / frameBytes;
        ByteBuffer input = ByteBuffer.wrap(src).order(ByteOrder.LITTLE_ENDIAN);
        ByteBuffer output = ByteBuffer.allocate(frames * 4).order(ByteOrder.LITTLE_ENDIAN);

        for (int frame = 0; frame < frames; frame++) {
            int base = frame * frameBytes;
            short left = readSample(input, base, encoding, gain);
            short right = channels > 1
                    ? readSample(input, base + bytesPerSample, encoding, gain)
                    : left;
            output.putShort(left);
            output.putShort(right);
        }

        return output.array();
    }

    private static short readSample(ByteBuffer input, int offset, int encoding, double gain) {
        double value;

        if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
            value = Math.max(-1.0, Math.min(1.0, input.getFloat(offset))) * 32767.0;
        } else if (encoding == AudioFormat.ENCODING_PCM_8BIT) {
            value = ((input.get(offset) & 0xff) - 128) * 256.0;
        } else {
            value = input.getShort(offset);
        }

        int scaled = (int) Math.round(value * gain);
        scaled = Math.max(-32768, Math.min(32767, scaled));
        return (short) scaled;
    }
}
