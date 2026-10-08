package com.veilbreakers.prototype;

/** Six authored poses progress with ground distance, so blocked movement cannot run in place. */
final class LocomotionCycle {
    float phase;
    boolean moving;
    boolean running;

    void advance(float distance, float dt, float height, float maxSpeed) {
        float ratio = distance / Math.max(0.001f, dt * maxSpeed);
        boolean nextMoving = distance > height * dt * 0.025f;
        if (!nextMoving) { moving = false; running = false; phase = 0f; return; }
        if (!moving) phase = 0f;
        moving = true;
        running = running ? ratio > 0.58f : ratio >= 0.68f;
        float stride = height * (running ? 0.195f : 0.104f);
        phase = (phase + distance / Math.max(1f, stride) * 6f) % 6f;
    }
    void stop() { phase = 0f; moving = false; running = false; }
}
