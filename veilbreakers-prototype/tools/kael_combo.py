#!/usr/bin/env python3
"""Slice reviewed imagegen combat art into fixed-pivot production frames.

No artwork is drawn by this tool. Alpha-connected components separate poses
whose weapons reach across the generator's imperfect grid. The same physical
source scale is applied to all 36 frames, independent of sword/VFX bounds.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / "app/src/main/assets"
ARCHIVE = ASSETS / "project_archive/source_sheets/v17"
PREVIEWS = ASSETS / "project_archive/previews/v17"
RUNTIME = ASSETS / "kael_v17/combo"
DIRS = ("down", "up", "left", "right")
WIDTH, HEIGHT, PX, PY = 512, 256, 256, 232
# Fixed physical pixel ratio, not normalized independently from a VFX box.
SCALE = 174 / 250
DURATIONS = (0.38, 0.44, 0.54)
WEIGHTS = (0.30, 0.28, 0.42)
PHASES = ("anticipation", "impact", "recovery")
ORIGINALS = {
    1: "/workspace/generated_images/exec-7d435c21-7556-4f29-8fee-6975cadca9ba.png",
    2: "/workspace/generated_images/exec-5cd2760e-8bbb-41a5-b413-b4d36b96b39b.png",
    3: "/workspace/generated_images/exec-b81feeac-4e66-4a8e-81c7-e5929cc93bd3.png",
}
# Ground anchors measured against visible BOOTS, never the lowest red tracer.
# Feet lifted in a lunge retain the other planted boot's ground baseline.
ANCHORS = {
    1: [
        [(244, 306), (674, 307), (1035, 307)],
        [(222, 633), (641, 635), (1039, 633)],
        [(234, 882), (665, 880), (1069, 881)],
        [(189, 1162), (579, 1161), (1051, 1160)],
    ],
    2: [
        [(214, 338), (673, 340), (1066, 340)],
        [(240, 647), (640, 643), (1079, 643)],
        [(245, 936), (658, 930), (1078, 934)],
        [(206, 1218), (654, 1216), (1093, 1217)],
    ],
    3: [
        [(229, 315), (633, 314), (1042, 314)],
        [(212, 618), (641, 620), (1038, 619)],
        [(197, 896), (668, 898), (1081, 897)],
        [(220, 1177), (653, 1176), (1059, 1179)],
    ],
}


def components(im):
    rgba = np.array(im)
    labels, count = ndimage.label(rgba[:, :, 3] > 20)
    sizes = np.bincount(labels.ravel())
    identifiers = [i for i in range(1, count + 1) if sizes[i] > 1000]
    if len(identifiers) != 12:
        raise ValueError(f"Expected exactly 12 complete character islands: {identifiers}")
    info = []
    for i in identifiers:
        ys, xs = np.where(labels == i)
        info.append(dict(label=i, bottom=int(ys.max()), left=int(xs.min())))
    # Imperfect generated row gutters are handled by pose islands, not a grid
    # crop that would import a neighboring sword or cut a full character.
    info.sort(key=lambda x: x["bottom"])
    ordered = []
    for start in range(0, 12, 3):
        ordered.extend(sorted(info[start:start + 3], key=lambda x: x["left"]))
    principal = np.isin(labels, identifiers)
    distances, indices = ndimage.distance_transform_edt(~principal, return_indices=True)
    nearest = labels[indices[0], indices[1]]
    parts = []
    for record in ordered:
        mask = (nearest == record["label"]) & (distances <= 16) & (rgba[:, :, 3] >= 4)
        part = rgba.copy()
        part[~mask] = 0
        parts.append(Image.fromarray(part, "RGBA"))
    return parts


def aligned(part, anchor):
    ax, ay = anchor
    im = part.transform(
        (WIDTH, HEIGHT), Image.Transform.AFFINE,
        (1 / SCALE, 0, ax - PX / SCALE, 0, 1 / SCALE, ay - PY / SCALE),
        Image.Resampling.BICUBIC,
    )
    a = np.array(im)
    a[a[:, :, 3] == 0] = 0
    im = Image.fromarray(a, "RGBA")
    if np.any(a[0, :, 3]) or np.any(a[-1, :, 3]) or np.any(a[:, 0, 3]) or np.any(a[:, -1, 3]):
        raise ValueError(f"Foreground reaches canvas edge at source anchor {anchor}")
    return im


def run():
    for directory in (ARCHIVE, PREVIEWS, RUNTIME):
        directory.mkdir(parents=True, exist_ok=True)
    manifest = dict(
        version="1.7.0", animation="kael_combo", totalFrameCount=36,
        directions=list(DIRS), phases=list(PHASES), frameCountPerDirectionPerStage=3,
        comboCount=3, order=[0, 1, 2], cellWidth=WIDTH, cellHeight=HEIGHT,
        pivotX=PX, pivotY=PY, baseline=PY, referenceBodyHeight=174,
        sourceReferenceBodyHeight=250, sourceScale=SCALE,
        scale="One fixed 0.696 pixel ratio for all36poses; crouches keep physical size",
        runtimeBodyScale="playerHeight / 174", hitFrame=1,
        phaseWeights=list(WEIGHTS), stages=[], frames=[],
        qualityReview=[
            "All36cells individually reviewed for identity, face, hair, cape, armor, grips and two arms/two legs",
            "C1 LEFT direction repaired; C1 duplicate torso/back swords removed via imagegen",
            "C2 clipped overhead sword restored and crimson traces reduced via imagegen",
            "C3 giant VFX reduced; impact column redrawn as directional overhead chop",
            "512x256 cells preserve full horizontal sword/cape without rescaling only the hit pose",
            "Boot-ground anchors measured separately from sword and VFX bounds",
        ],
    )
    all_frames = {}
    for stage in range(1, 4):
        source = ARCHIVE / f"kael_combo_c{stage}_source.png"
        if not source.exists():
            shutil.copy2(ORIGINALS[stage], source)
        im = Image.open(source).convert("RGBA")
        parts = components(im)
        sheet = Image.new("RGBA", (WIDTH * 3, HEIGHT * 4))
        preview = Image.new("RGB", (WIDTH * 3, (HEIGHT + 28) * 4), (26, 23, 27))
        draw = ImageDraw.Draw(preview)
        stage_duration = DURATIONS[stage - 1]
        stage_entry = dict(
            animation=f"combo_{stage}", comboIndex=stage, frameCount=3,
            recommendedFPS=round(3 / stage_duration, 3), durationSeconds=stage_duration,
            frameDurationsSeconds=[round(stage_duration * w, 6) for w in WEIGHTS],
            phaseStartTimesSeconds=[0, round(stage_duration * WEIGHTS[0], 6), round(stage_duration * sum(WEIGHTS[:2]), 6)],
            hitFrame=1, hitTimeSeconds=round(stage_duration * WEIGHTS[0], 6),
            source=f"project_archive/source_sheets/v17/{source.name}",
            canonicalSheet=f"project_archive/source_sheets/v17/kael_combo_c{stage}_runtime_sheet.png",
            directions=list(DIRS), columns=3, rows=4,
        )
        manifest["stages"].append(stage_entry)
        for row, direction in enumerate(DIRS):
            for index in range(3):
                part = parts[row * 3 + index]
                anchor = ANCHORS[stage][row][index]
                frame = aligned(part, anchor)
                filename = f"{direction}_c{stage}_{index}.png"
                target = RUNTIME / filename
                frame.save(target, optimize=True)
                all_frames[(stage, row, index)] = frame
                sheet.alpha_composite(frame, (index * WIDTH, row * HEIGHT))
                x, y = index * WIDTH, row * (HEIGHT + 28)
                preview.paste(frame, (x, y + 24), frame)
                draw.text((x + 8, y + 6), f"C{stage} {direction.upper()} / {index} {PHASES[index]}", fill=(224, 213, 212))
                draw.line((x, y + 24 + PY, x + WIDTH, y + 24 + PY), fill=(99, 64, 72))
                draw.ellipse((x + PX - 2, y + 24 + PY - 2, x + PX + 2, y + 24 + PY + 2), fill=(220, 80, 90))
                entry = dict(
                    animation=f"combo_{stage}", direction=direction, index=index,
                    phase=PHASES[index], file=f"kael_v17/combo/{filename}",
                    frameCount=3, recommendedFPS=stage_entry["recommendedFPS"],
                    cellWidth=WIDTH, cellHeight=HEIGHT, pivotX=PX, pivotY=PY,
                    baseline=PY, sourcePivot=list(anchor), sourceScale=SCALE,
                    sourceRect=list(part.getbbox()), referenceBodyHeight=174,
                    durationSeconds=round(stage_duration * WEIGHTS[index], 6),
                    hitFrame=index == 1, hitFrameIndex=1,
                    visibleBounds=list(frame.getbbox()), sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                )
                manifest["frames"].append(entry)
        sheet.save(ARCHIVE / f"kael_combo_c{stage}_runtime_sheet.png", optimize=True)
        preview.save(PREVIEWS / f"kael_combo_c{stage}_contact.png", optimize=True)
    # Same timeline in all four directional panels. This is a technical
    # animation contact sheet, not generated art or a gameplay capture.
    gif_frames, gif_durations = [], []
    for stage in range(1, 4):
        for index in range(3):
            canvas = Image.new("RGB", (WIDTH * 2, (HEIGHT + 24) * 2), (24, 21, 25))
            draw = ImageDraw.Draw(canvas)
            for row, direction in enumerate(DIRS):
                x, y = row % 2 * WIDTH, row // 2 * (HEIGHT + 24)
                frame = all_frames[(stage, row, index)]
                canvas.paste(frame, (x, y + 24), frame)
                draw.text((x + 8, y + 7), f"{direction.upper()} C{stage} {PHASES[index]}", fill=(220, 207, 207))
            gif_frames.append(canvas)
            gif_durations.append(round(DURATIONS[stage - 1] * WEIGHTS[index] * 1000))
    gif_frames[0].save(PREVIEWS / "kael_combo_animation.gif", save_all=True,
                       append_images=gif_frames[1:], duration=gif_durations, loop=0, disposal=2)
    path = ARCHIVE / "kael_combo_manifest.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    notes = """# Kael Varyn — Combos v1.7.0

36 novas poses foram produzidas por imagegen a partir do model sheet oficial.
Não são transformações procedurais dos sprites antigos. Todos os golpes são
desenhados especificamente em Down, Up, Left e Right.

- C1: preparação curta, thrust/corte direto, retorno à guarda.
- C2: preparação baixa, corte diagonal ascendente agressivo, guarda alta.
- C3: preparação acima da cabeça, finalização pesada contra o alvo na direção real, recuperação baixa.

Todas as células de runtime têm **512×256**, pivot **256,232**, baseline **232**.
O canvas largo preserva espada e capa sem reduzir o corpo apenas no impacto.
174px é a altura física de referência em postura neutra; joelhos flexionados e
inclinação fazem parte da animação e não são normalizados pela caixa de VFX.
Uma única escala de fonte 0.696 é usada em todas as 36 poses.

Tempos C1/C2/C3: .38/.44/.54 segundos. Pesos das fases .30/.28/.42.
O hit é a pose1 nos instantes .114/.132/.162s. VFX carmesim é integrado ao
traço da espada; não se deve sobrepor um corte procedural adicional.

As fontes completas geradas estão em kael_combo_cN_source.png. As sheets
canônicas com gutters, escala e pivô definitivos estão em
kael_combo_cN_runtime_sheet.png. Frames separados: kael_v17/combo/.
O script tools/kael_combo.py reconstrói frames e manifests das fontes arquivadas.

QA: direção LEFT incorreta e espada duplicada de C1 foram corrigidas via
imagegen; espada cortada/VFX amplo de C2 foi corrigido; C3 recebeu arcos
reduzidos e poses de impacto redirecionadas. As prévias são contacts técnicas,
não capturas de gameplay. A transparência é alpha real, sem checkerboard.

Substitui em runtime os 18 combos provisórios de kael_v15/combo/ (Down/Up).
Left/Right recebem outros 18 frames próprios e deixam de depender do fallback
procedural. Os sprites antigos permanecem como histórico. Não houve espelhamento de
direções nem reuso dos mesmos frames em golpes distintos.
"""
    (ARCHIVE / "KAEL_COMBO_NOTES.md").write_text(notes, encoding="utf-8")
    print(json.dumps(dict(frames=36, canvas=[WIDTH, HEIGHT], pivot=[PX, PY],
                          manifest=str(path), previews=str(PREVIEWS)), indent=2))


if __name__ == "__main__":
    run()
