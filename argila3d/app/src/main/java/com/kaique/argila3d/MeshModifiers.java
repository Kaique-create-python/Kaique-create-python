package com.kaique.argila3d;

import java.util.ArrayList;
import java.util.HashMap;

/**
 * Operacoes basicas de malha para a interface por toque.
 * Nesta primeira versao as operacoes sao aplicadas na malha,
 * com retorno pelo historico Desfazer do SculptView.
 */
public final class MeshModifiers {
    private static final int MAX_VERTICES = 100000;
    private static final int MAX_SUBDIVISION_FACES = 4000;

    private MeshModifiers() {}

    public static boolean canSubdivide(ClayMesh mesh) {
        return mesh != null && !mesh.faces.isEmpty()
                && mesh.faces.size() <= MAX_SUBDIVISION_FACES
                && mesh.vertices.size() + mesh.faces.size() * 3L <= MAX_VERTICES;
    }

    private static int midpoint(ArrayList<float[]> vertices,
                                HashMap<Long, Integer> cache, int a, int b) {
        int low = Math.min(a, b), high = Math.max(a, b);
        long key = ((long) low << 32) | (high & 0xffffffffL);
        Integer found = cache.get(key);
        if (found != null) return found;
        float[] va = vertices.get(a), vb = vertices.get(b);
        int index = vertices.size();
        vertices.add(new float[]{
                (va[0] + vb[0]) * .5f,
                (va[1] + vb[1]) * .5f,
                (va[2] + vb[2]) * .5f
        });
        cache.put(key, index);
        return index;
    }

    /** Divide cada triangulo em quatro, reaproveitando pontos nas arestas. */
    public static boolean subdivide(ClayMesh mesh) {
        if (!canSubdivide(mesh)) return false;
        ArrayList<float[]> outVertices = new ArrayList<>(mesh.vertices.size());
        for (float[] vertex : mesh.vertices)
            outVertices.add(new float[]{vertex[0], vertex[1], vertex[2]});
        ArrayList<int[]> outFaces = new ArrayList<>(mesh.faces.size() * 4);
        HashMap<Long, Integer> mids = new HashMap<>();
        for (int[] face : mesh.faces) {
            int a = face[0], b = face[1], c = face[2];
            int ab = midpoint(outVertices, mids, a, b);
            int bc = midpoint(outVertices, mids, b, c);
            int ca = midpoint(outVertices, mids, c, a);
            outFaces.add(new int[]{a, ab, ca});
            outFaces.add(new int[]{ab, b, bc});
            outFaces.add(new int[]{ca, bc, c});
            outFaces.add(new int[]{ab, bc, ca});
        }
        mesh.vertices.clear();
        mesh.vertices.addAll(outVertices);
        mesh.faces.clear();
        mesh.faces.addAll(outFaces);
        mesh.rebuild();
        return true;
    }

    /** Uma passada de suavizacao Laplaciana, sem alterar a topologia. */
    public static boolean smooth(ClayMesh mesh, float weight) {
        if (mesh == null || mesh.vertices.isEmpty()) return false;
        float w = Math.max(0f, Math.min(1f, weight));
        float[][] positions = new float[mesh.vertices.size()][3];
        for (int i = 0; i < mesh.vertices.size(); i++) {
            float[] source = mesh.vertices.get(i);
            ArrayList<Integer> adjacent = mesh.neighbors.get(i);
            for (int axis = 0; axis < 3; axis++) {
                if (adjacent.isEmpty()) { positions[i][axis] = source[axis]; continue; }
                float total = 0;
                for (int index : adjacent) total += mesh.vertices.get(index)[axis];
                positions[i][axis] = source[axis] * (1f - w)
                        + (total / adjacent.size()) * w;
            }
        }
        for (int i = 0; i < positions.length; i++)
            System.arraycopy(positions[i], 0, mesh.vertices.get(i), 0, 3);
        return true;
    }

    /** Extruda um triangulo selecionado ao longo de sua normal. */
    public static boolean extrudeFace(ClayMesh mesh, int faceIndex, float distance) {
        if (mesh == null || faceIndex < 0 || faceIndex >= mesh.faces.size()
                || mesh.vertices.size() + 3 > MAX_VERTICES) return false;
        int[] face = mesh.faces.get(faceIndex);
        int a = face[0], b = face[1], c = face[2];
        float[] va = mesh.vertices.get(a), vb = mesh.vertices.get(b), vc = mesh.vertices.get(c);
        float abx = vb[0] - va[0], aby = vb[1] - va[1], abz = vb[2] - va[2];
        float acx = vc[0] - va[0], acy = vc[1] - va[1], acz = vc[2] - va[2];
        float nx = aby * acz - abz * acy;
        float ny = abz * acx - abx * acz;
        float nz = abx * acy - aby * acx;
        float length = (float) Math.sqrt(nx * nx + ny * ny + nz * nz);
        if (length < 0.000001f) return false;
        float factor = distance / length;
        int topA = mesh.vertices.size();
        mesh.vertices.add(new float[]{va[0] + nx * factor, va[1] + ny * factor, va[2] + nz * factor});
        int topB = mesh.vertices.size();
        mesh.vertices.add(new float[]{vb[0] + nx * factor, vb[1] + ny * factor, vb[2] + nz * factor});
        int topC = mesh.vertices.size();
        mesh.vertices.add(new float[]{vc[0] + nx * factor, vc[1] + ny * factor, vc[2] + nz * factor});
        mesh.faces.set(faceIndex, new int[]{topA, topB, topC});
        mesh.faces.add(new int[]{a, b, topB});
        mesh.faces.add(new int[]{a, topB, topA});
        mesh.faces.add(new int[]{b, c, topC});
        mesh.faces.add(new int[]{b, topC, topB});
        mesh.faces.add(new int[]{c, a, topA});
        mesh.faces.add(new int[]{c, topA, topC});
        mesh.rebuild();
        return true;
    }
}
