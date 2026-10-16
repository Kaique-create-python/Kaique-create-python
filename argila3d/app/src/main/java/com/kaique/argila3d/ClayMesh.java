package com.kaique.argila3d;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Locale;

public final class ClayMesh {
    public final ArrayList<float[]> vertices = new ArrayList<>();
    public final ArrayList<int[]> faces = new ArrayList<>();
    public final ArrayList<int[]> edges = new ArrayList<>();
    public final ArrayList<ArrayList<Integer>> neighbors = new ArrayList<>();

    private int add(float x, float y, float z) {
        vertices.add(new float[]{x, y, z});
        return vertices.size() - 1;
    }

    private void tri(int a, int b, int c) {
        faces.add(new int[]{a, b, c});
    }

    public static ClayMesh sphere(int stacks, int slices) {
        ClayMesh mesh = new ClayMesh();
        int top = mesh.add(0, 1, 0);
        for (int i = 1; i < stacks; i++) {
            double phi = Math.PI * i / stacks;
            for (int j = 0; j < slices; j++) {
                double theta = j * Math.PI * 2 / slices;
                mesh.add((float)(Math.sin(phi) * Math.cos(theta)),
                        (float)Math.cos(phi),
                        (float)(Math.sin(phi) * Math.sin(theta)));
            }
        }
        int bottom = mesh.add(0, -1, 0);
        for (int j = 0; j < slices; j++) {
            int next = (j + 1) % slices;
            mesh.tri(top, 1 + next, 1 + j);
        }
        for (int i = 0; i < stacks - 2; i++) {
            for (int j = 0; j < slices; j++) {
                int next = (j + 1) % slices;
                int a = 1 + i * slices + j;
                int b = 1 + i * slices + next;
                int c = 1 + (i + 1) * slices + j;
                int d = 1 + (i + 1) * slices + next;
                mesh.tri(a, b, c);
                mesh.tri(b, d, c);
            }
        }
        int last = 1 + (stacks - 2) * slices;
        for (int j = 0; j < slices; j++)
            mesh.tri(last + j, last + (j + 1) % slices, bottom);
        mesh.rebuild();
        return mesh;
    }

    public static ClayMesh cube() {
        ClayMesh m = new ClayMesh();
        m.add(-0.8f,-0.8f,-0.8f); m.add(0.8f,-0.8f,-0.8f);
        m.add(0.8f,0.8f,-0.8f); m.add(-0.8f,0.8f,-0.8f);
        m.add(-0.8f,-0.8f,0.8f); m.add(0.8f,-0.8f,0.8f);
        m.add(0.8f,0.8f,0.8f); m.add(-0.8f,0.8f,0.8f);
        m.tri(4,5,6); m.tri(4,6,7);
        m.tri(0,2,1); m.tri(0,3,2);
        m.tri(0,4,7); m.tri(0,7,3);
        m.tri(1,2,6); m.tri(1,6,5);
        m.tri(3,7,6); m.tri(3,6,2);
        m.tri(0,1,5); m.tri(0,5,4);
        m.rebuild();
        return m;
    }

    private void connect(int a, int b, HashSet<Long> encountered) {
        int lo = Math.min(a, b), hi = Math.max(a, b);
        long key = ((long)lo << 32) | (hi & 0xffffffffL);
        if (encountered.add(key)) {
            edges.add(new int[]{lo, hi});
            neighbors.get(lo).add(hi);
            neighbors.get(hi).add(lo);
        }
    }

    public void rebuild() {
        edges.clear();
        neighbors.clear();
        for (int i = 0; i < vertices.size(); i++) neighbors.add(new ArrayList<>());
        HashSet<Long> seen = new HashSet<>();
        for (int[] f : faces) {
            connect(f[0],f[1],seen);
            connect(f[1],f[2],seen);
            connect(f[2],f[0],seen);
        }
    }

    public float[][] normals() {
        float[][] normals = new float[vertices.size()][3];
        for (int[] f : faces) {
            float[] a = vertices.get(f[0]), b = vertices.get(f[1]), c = vertices.get(f[2]);
            float ax=b[0]-a[0], ay=b[1]-a[1], az=b[2]-a[2];
            float bx=c[0]-a[0], by=c[1]-a[1], bz=c[2]-a[2];
            float nx=ay*bz-az*by, ny=az*bx-ax*bz, nz=ax*by-ay*bx;
            for (int v : f) {
                normals[v][0] += nx;
                normals[v][1] += ny;
                normals[v][2] += nz;
            }
        }
        for (float[] n : normals) {
            float len = (float)Math.sqrt(n[0]*n[0] + n[1]*n[1] + n[2]*n[2]);
            if (len > 1e-8) for (int j=0;j<3;j++) n[j] /= len;
        }
        return normals;
    }

    public String write(boolean obj) {
        StringBuilder out = new StringBuilder(obj ? "# Argila 3D v0.1 - OBJ\n" : "ARGILA3D 1\n");
        for (float[] v : vertices)
            out.append("v ").append(v[0]).append(' ').append(v[1]).append(' ').append(v[2]).append('\n');
        for (int[] f : faces)
            out.append("f ").append(f[0]+(obj?1:0)).append(' ')
               .append(f[1]+(obj?1:0)).append(' ').append(f[2]+(obj?1:0)).append('\n');
        return out.toString();
    }

    public static ClayMesh read(String data) {
        if (data == null || !data.startsWith("ARGILA3D 1\n")) throw new IllegalArgumentException("Arquivo inválido");
        ClayMesh m = new ClayMesh();
        for (String line : data.split("\n")) {
            if (line.startsWith("v ")) {
                String[] p = line.split(" ");
                if (p.length != 4) throw new IllegalArgumentException("Vértice inválido");
                m.add(Float.parseFloat(p[1]),Float.parseFloat(p[2]),Float.parseFloat(p[3]));
            } else if (line.startsWith("f ")) {
                String[] p = line.split(" ");
                if (p.length != 4) throw new IllegalArgumentException("Face inválida");
                m.tri(Integer.parseInt(p[1]),Integer.parseInt(p[2]),Integer.parseInt(p[3]));
            }
        }
        if (m.vertices.size() < 3 || m.faces.isEmpty() || m.vertices.size() > 100000)
            throw new IllegalArgumentException("Malha inválida");
        for (int[] f : m.faces) for (int v : f)
            if (v < 0 || v >= m.vertices.size()) throw new IllegalArgumentException("Índice inválido");
        m.rebuild();
        return m;
    }
}
