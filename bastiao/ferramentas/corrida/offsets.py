"""Gera offsets.json (um quaternion por osso por quadro) a partir de uma função de pose.
uso: python3 offsets.py <modulo_spec.py> <saida.json>
O spec define: CICLO (s), CICLOS (int), FPS, e offset(osso, t) -> (x, y, z) em graus ou None.
A mesma tabela vai para a prévia (three.js) e para o .rbxm (Lune): resultado idêntico nos dois."""
import json, math, sys, importlib.util
spec = importlib.util.spec_from_file_location("spec", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
OSSOS = ["pelvis", "spine_01", "spine_02", "chest", "neck", "head", "clavicle.L", "clavicle.R", "upper_arm.L", "upper_arm.R",
         "forearm.L", "forearm.R", "hand.L", "hand.R", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R", "toe.L", "toe.R"]
for lado in "LR":
    for dedo in ("index", "middle", "ring", "thumb"):
        for k in (1, 2, 3):
            OSSOS.append(f"{dedo}_0{k}.{lado}")
def quat(xd, yd, zd):
    def eixo(ax, ang):
        h = math.radians(ang) / 2; s = math.sin(h)
        return [ax[0] * s, ax[1] * s, ax[2] * s, math.cos(h)]
    def mul(a, b):
        ax, ay, az, aw = a; bx, by, bz, bw = b
        return [aw*bx+ax*bw+ay*bz-az*by, aw*by-ax*bz+ay*bw+az*bx, aw*bz+ax*by-ay*bx+az*bw, aw*bw-ax*bx-ay*by-az*bz]
    return mul(mul(eixo((1, 0, 0), xd), eixo((0, 1, 0), yd)), eixo((0, 0, 1), zd))
n = int(round(m.CICLO * m.CICLOS * m.FPS)) + 1
saida = {"fps": m.FPS, "frames": n, "cycle": m.CICLO, "cycles": m.CICLOS, "bones": {}}
for osso in OSSOS:
    linha, usado = [], False
    for k in range(n):
        t = k / m.FPS
        if k == n - 1: t = 0.0  # o último quadro fecha o loop igual ao primeiro
        r = m.offset(osso, t)
        if r is None or all(abs(v) < 1e-6 for v in r):
            linha.append([0.0, 0.0, 0.0, 1.0])
        else:
            usado = True
            linha.append([round(v, 6) for v in quat(*r)])
    if usado: saida["bones"][osso] = linha
json.dump(saida, open(sys.argv[2], "w"))
print("quadros", n, "ossos com offset", len(saida["bones"]), sorted(saida["bones"]))
