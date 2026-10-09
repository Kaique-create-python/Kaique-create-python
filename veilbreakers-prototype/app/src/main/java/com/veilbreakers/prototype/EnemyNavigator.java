package com.veilbreakers.prototype;

import java.util.Arrays;
import java.util.PriorityQueue;

/** A small walkability grid lets the single opponent go around room props. */
final class EnemyNavigator {
    interface Collision { boolean blocked(float x, float y, float radius); }
    private static final int COLS = 40, ROWS = 15, COUNT = COLS * ROWS;
    private final float[] cost = new float[COUNT];
    private final int[] previous = new int[COUNT];
    private final boolean[] passable = new boolean[COUNT];
    private static final class Node implements Comparable<Node> {
        final int index; final float score;
        Node(int index, float score) { this.index = index; this.score = score; }
        public int compareTo(Node other) { return Float.compare(score, other.score); }
    }

    float[] next(float x, float y, float targetX, float targetY, float width, float height,
                 float radius, float minY, float maxY, Collision collision) {
        float x0 = width * .055f, y0 = minY;
        float dx = width * .89f / (COLS - 1), dy = Math.max(1f, maxY - minY) / (ROWS - 1);
        int start = -1, goal = -1;
        float nearestStart = Float.POSITIVE_INFINITY, nearestGoal = Float.POSITIVE_INFINITY;
        for (int i = 0; i < COUNT; i++) {
            float nx = x0 + i % COLS * dx, ny = y0 + i / COLS * dy;
            passable[i] = !collision.blocked(nx, ny, radius);
            if (!passable[i]) continue;
            float from = square(nx - x) + square(ny - y);
            float to = square(nx - targetX) + square(ny - targetY);
            if (from < nearestStart) { nearestStart = from; start = i; }
            if (to < nearestGoal) { nearestGoal = to; goal = i; }
        }
        if (start < 0 || goal < 0) return new float[] {x, y};
        Arrays.fill(cost, Float.POSITIVE_INFINITY);
        Arrays.fill(previous, -1);
        PriorityQueue<Node> open = new PriorityQueue<>();
        cost[start] = 0f; open.add(new Node(start, 0f));
        while (!open.isEmpty()) {
            Node node = open.poll();
            if (node.score > cost[node.index]) continue;
            if (node.index == goal) break;
            int cx = node.index % COLS, cy = node.index / COLS;
            for (int oy = -1; oy <= 1; oy++) for (int ox = -1; ox <= 1; ox++) {
                if (ox == 0 && oy == 0) continue;
                int nx = cx + ox, ny = cy + oy;
                if (nx < 0 || nx >= COLS || ny < 0 || ny >= ROWS) continue;
                int next = ny * COLS + nx;
                if (!passable[next]) continue;
                if (ox != 0 && oy != 0 && (!passable[cy * COLS + nx] || !passable[ny * COLS + cx])) continue;
                float mx = x0 + (cx + nx) * .5f * dx, my = y0 + (cy + ny) * .5f * dy;
                if (collision.blocked(mx, my, radius)) continue;
                float distance = (float) Math.hypot(ox * dx, oy * dy);
                float nextCost = cost[node.index] + distance;
                if (nextCost < cost[next]) {
                    cost[next] = nextCost; previous[next] = node.index;
                    open.add(new Node(next, nextCost));
                }
            }
        }
        if (goal != start && previous[goal] < 0) return new float[] {x, y};
        int waypoint = goal;
        while (previous[waypoint] >= 0 && previous[waypoint] != start) waypoint = previous[waypoint];
        if (goal == start) return new float[] {targetX, targetY};
        return new float[] {x0 + waypoint % COLS * dx, y0 + waypoint / COLS * dy};
    }

    private static float square(float x) { return x * x; }
}
