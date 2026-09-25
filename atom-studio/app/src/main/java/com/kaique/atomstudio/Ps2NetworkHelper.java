package com.kaique.atomstudio;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Ps2NetworkHelper {

    public interface Listener {
        void onResult(boolean ok, String message);
    }

    private final ExecutorService worker = Executors.newSingleThreadExecutor();

    public void test(String ps2Ip, String atomIp, Listener listener) {
        worker.execute(() -> {
            try {
                if (ps2Ip == null || ps2Ip.trim().isEmpty()) {
                    listener.onResult(false, "Digite o IP do PS2.");
                    return;
                }

                boolean reachable = ping(ps2Ip.trim());

                if (!reachable) {
                    try {
                        reachable = InetAddress.getByName(ps2Ip.trim()).isReachable(1500);
                    } catch (Exception ignored) {}
                }

                if (!reachable) {
                    listener.onResult(false,
                            "PS2 não respondeu na rede. No OPL, inicie ETH/rede e confira o IP do PS2.");
                    return;
                }

                boolean sameLan = same24(ps2Ip.trim(), atomIp);

                if (sameLan) {
                    listener.onResult(true,
                            "PS2 acessível. PS2 e ATOM parecem estar na mesma rede local.");
                } else {
                    listener.onResult(true,
                            "PS2 respondeu, mas PS2 e ATOM parecem estar em sub-redes diferentes.");
                }

            } catch (Exception e) {
                listener.onResult(false, "Erro testando PS2: " + e.getMessage());
            }
        });
    }

    private boolean ping(String ip) {
        Process p = null;
        try {
            p = new ProcessBuilder("ping", "-c", "1", "-W", "1", ip)
                    .redirectErrorStream(true)
                    .start();

            BufferedReader br =
                    new BufferedReader(new InputStreamReader(p.getInputStream()));

            String line;
            boolean ok = false;

            while ((line = br.readLine()) != null) {
                String s = line.toLowerCase();
                if (s.contains("1 received")
                        || s.contains("1 packets received")
                        || s.contains("bytes from")) {
                    ok = true;
                }
            }

            try { p.waitFor(); } catch (InterruptedException ignored) {}
            return ok || p.exitValue() == 0;

        } catch (Exception e) {
            return false;
        } finally {
            if (p != null) {
                try { p.destroy(); } catch (Exception ignored) {}
            }
        }
    }

    private boolean same24(String a, String b) {
        try {
            if (b == null) return false;
            String[] aa = a.split("\\.");
            String[] bb = b.split("\\.");
            return aa.length == 4
                    && bb.length == 4
                    && aa[0].equals(bb[0])
                    && aa[1].equals(bb[1])
                    && aa[2].equals(bb[2]);
        } catch (Exception e) {
            return false;
        }
    }

    public void shutdown() {
        worker.shutdownNow();
    }
}
