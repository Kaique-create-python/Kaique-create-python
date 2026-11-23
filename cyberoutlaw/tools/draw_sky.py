"""Desenha por código o céu noturno de Maré Baixa (seis faces do Sky do Roblox, sem IA).

O céu depende só da altura acima do horizonte e de uma variação suave de cor entre o lado das docas
(+Z, brilho alaranjado de vapor de sódio) e o lado oposto (roxo e magenta do néon). Abaixo do horizonte,
o céu repete o de cima, um pouco mais escuro: é o que as poças refletem. Por isso as faces encaixam
mesmo que alguma fique espelhada na lateral.
Uso: python tools/draw_sky.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZE = 512

# Direção de cada pixel nas faces, vista de dentro do cubo (+Y para cima).
FACES = {
    "ceu_ft": lambda u, v: (u, -v, -np.ones_like(u)),   # -Z
    "ceu_bk": lambda u, v: (-u, -v, np.ones_like(u)),   # +Z
    "ceu_lf": lambda u, v: (-np.ones_like(u), -v, -u),  # -X
    "ceu_rt": lambda u, v: (np.ones_like(u), -v, u),    # +X
    "ceu_up": lambda u, v: (u, np.ones_like(u), v),     # +Y
    "ceu_dn": lambda u, v: (u, -np.ones_like(u), -v),   # -Y
}


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def sky(direction):
    x, y, z = direction
    length = np.sqrt(x * x + y * y + z * z)
    x, y, z = x / length, y / length, z / length
    below = y < 0
    e = np.abs(y)  # o céu de baixo espelha o de cima
    side = z / np.maximum(1e-6, np.sqrt(x * x + z * z))  # 1 para as docas (+Z), -1 para o lado oposto
    warm = smooth((side + 1) / 2)
    zenith = np.array([5, 5, 14], float)
    mid = np.array([20, 15, 42], float)
    glow_cool = np.array([104, 52, 112], float)
    glow_warm = np.array([150, 82, 64], float)
    glow = glow_cool[None, None] * (1 - warm[..., None]) + glow_warm[None, None] * warm[..., None]
    # Gradiente: brilho forte rente ao horizonte, roxo médio até ~25 graus, escuro no zênite.
    a = smooth(1 - e / 0.3)[..., None] ** 1.6
    b = smooth(1 - e / 0.75)[..., None]
    color = zenith * (1 - b) + mid * b
    color = color * (1 - a) + glow * a
    # Faixas de névoa iluminadas por baixo, variando devagar com o azimute (simétricas em X).
    angle = np.arccos(np.clip(side, -1, 1))
    bands = 0.5 + 0.5 * np.cos(angle * 3 + 0.7) * np.cos(angle * 5 + 1.9)
    haze = np.exp(-((e - 0.07) / 0.05) ** 2) * (0.25 + 0.75 * bands) + np.exp(-((e - 0.2) / 0.06) ** 2) * 0.35 * bands
    color += haze[..., None] * glow * 0.55
    color = np.where(below[..., None], color * 0.82, color)
    return color


def stars(image, seed):
    rng = np.random.default_rng(seed)
    count = 40
    xs, ys = rng.integers(0, SIZE, count), rng.integers(0, SIZE, count)
    for x, y in zip(xs, ys):
        level = rng.uniform(60, 140)
        image[y, x] = np.maximum(image[y, x], [level, level, level * 1.1])
    return image


def main():
    out = ROOT / "media" / "art"
    out.mkdir(parents=True, exist_ok=True)
    grid = (np.arange(SIZE) + 0.5) / SIZE * 2 - 1
    u, v = np.meshgrid(grid, grid)
    for index, (name, mapping) in enumerate(FACES.items()):
        color = sky(mapping(u, v))
        if name == "ceu_up":
            color = stars(color, 77)
        # Ruído fino evita faixas de quantização no gradiente.
        color += np.random.default_rng(index).uniform(-1.2, 1.2, color.shape)
        image = Image.fromarray(np.clip(color, 0, 255).astype("uint8"), "RGB")
        path = out / f"{name}.png"
        image.save(path, optimize=True)
        print(name, image.size, path.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
