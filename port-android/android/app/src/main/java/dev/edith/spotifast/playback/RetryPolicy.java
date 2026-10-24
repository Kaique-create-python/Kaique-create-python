package dev.edith.spotifast.playback;

/** Bounded recovery; decoding, authorization and missing-file errors are not retried. */
public final class RetryPolicy {
    private RetryPolicy() {}
    public static long delay(int code, int attempt) {
        if (attempt < 0 || attempt >= 3) return -1;
        // Media3 ERROR_CODE_IO_NETWORK_CONNECTION_FAILED / TIMEOUT.
        if (code != 2001 && code != 2002) return -1;
        return 1000L << attempt;
    }
}
