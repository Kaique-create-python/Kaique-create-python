"""Measure foot clearance against the same anchored geometry exported from the Roblox place."""
import json
import math
from pathlib import Path
import sys


GRID = 32
SAMPLE = 2
HALF_SHOULDER = 1.7
HEADROOM = 5.55


def vertical_interval(part, x, z):
    center, half, axes = part
    a, b = -math.inf, math.inf
    for axis, extent in zip(axes, half):
        origin = axis[0] * (x - center[0]) - axis[1] * center[1] + axis[2] * (z - center[2])
        slope = axis[1]
        if abs(slope) <= 1e-6:
            if abs(origin) > extent + 1e-6:
                return None
            continue
        u, v = (-extent - origin) / slope, (extent - origin) / slope
        a, b = max(a, min(u, v)), min(b, max(u, v))
        if a > b + 1e-6:
            return None
    return a, b


def make_grid(parts):
    grid = {}
    for record in parts:
        if not record["collision"]:
            continue
        cf, size = record["cf"], record["size"]
        axes = [(cf[3 + i], cf[6 + i], cf[9 + i]) for i in range(3)]
        part = (cf[:3], [dimension / 2 for dimension in size], axes)
        half_x = sum(abs(axis[0]) * s / 2 for axis, s in zip(axes, size))
        half_z = sum(abs(axis[2]) * s / 2 for axis, s in zip(axes, size))
        for x in range(math.floor((cf[0] - half_x) / GRID), math.floor((cf[0] + half_x) / GRID) + 1):
            for z in range(math.floor((cf[2] - half_z) / GRID), math.floor((cf[2] + half_z) / GRID) + 1):
                grid.setdefault((x, z), []).append((part, record["name"]))
    return grid


def intervals(grid, x, z):
    for part, name in grid.get((math.floor(x / GRID), math.floor(z / GRID)), ()):
        bounds = vertical_interval(part, x, z)
        if bounds:
            yield (*bounds, name)


def inspect_walk(grid, start, end):
    dx, dz = end[0] - start[0], end[2] - start[2]
    distance = math.hypot(dx, dz)
    px, pz = dz / distance * HALF_SHOULDER, -dx / distance * HALF_SHOULDER
    samples = max(1, math.ceil(distance / SAMPLE))
    for i in range(samples + 1):
        fraction = i / samples
        x, ref, z = (lo + (hi - lo) * fraction for lo, hi in zip(start, end))
        below = [top for _low, top, _name in intervals(grid, x, z) if ref - .90 <= top <= ref + .76]
        if not below:
            raise AssertionError(f"sem piso perto de ({x:.2f}, {ref:.2f}, {z:.2f})")
        floor = max(below)
        for side in (-1, 0, 1):
            for low, top, name in intervals(grid, x + side * px, z + side * pz):
                if top > floor + .77 and low < floor + HEADROOM:
                    raise AssertionError(f"{name} bloqueia a passagem em ({x:.2f}, {floor:.2f}, {z:.2f})")


def main():
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    grid = make_grid(data["parts"])
    routes = {
        "Praça do Dique até a orla": [(-115, 0.25, -83), (-38, 0.0, -83)],
        "Ponte principal abaixo do monotrilho": [(-81, -0.27, -12), (81, -0.27, -12)],
        "Passarela do parque": [(-77, -0.27, 240), (77, -0.27, 240)],
        "Mercado Sódio, de ponta a ponta": [(-360, 0.07, -211), (-360, 0.07, -31)],
        "Mercado Sódio até as duas ruas laterais": [(-462, 0.07, -120), (-254, 0.07, -120)],
        "Doca do Sal pelo eixo do galpão": [(-840, 0.08, 511), (-840, 0.08, 689)],
        "Doca do Sal, pátios oeste e leste": [(-936, 0.08, 628), (-744, 0.08, 628)],
        "Entrada frontal da Torre Vértice": [(360, 0.17, -443), (360, 0.49, -396)],
        "Subida da estação norte": [(108, 0.12, -64.85), (108, 27.8, -24.95), (108, 27.84, -17.8)],
        "Subida da estação sul": [(142, 0.12, 64.85), (142, 27.8, 24.95), (142, 27.84, 17.8)],
        "Plataforma norte para o primeiro vagão": [(78.1, 27.82, -18), (78.1, 28.5, -6.75)],
    }
    failures = []
    for name, points in routes.items():
        try:
            for start, end in zip(points, points[1:]):
                inspect_walk(grid, start, end)
            print(f"OK {name}")
        except AssertionError as error:
            failures.append(f"{name}: {error}")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"{len(routes)} rotas geométricas verificadas.")


if __name__ == "__main__":
    main()
