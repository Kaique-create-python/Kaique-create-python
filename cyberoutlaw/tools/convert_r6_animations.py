"""Converte as 10 animações R6 originais (animacoes_r6/*.rbxmx) em dados dentro de src/play.client.luau.

Por que dados e não AnimationIds: a Open Cloud só aceita animação baixada do Asset Delivery (publicada pelo
Studio); arquivos .rbxmx feitos fora do Studio são recusados. Os IDs registrados por script só funcionam no
Studio. Então o cliente toca as poses originais direto nos Motor6D do R6, como o Animator faria: as
KeyframeSequences usam só easing Linear e peso 1, e cada keyframe traz as 6 juntas, então interpolar
linearmente entre keyframes vizinhos reproduz a animação.

Cada pose vira um quatérnio e uma posição em 16 bits (erro < 1e-4), sem tirar nenhum keyframe.
O conversor confere os hashes do manifesto, os tempos crescentes e uniformes, o laço (primeira pose =
última) e mede, pelo rig R6 padrão, a velocidade real do pé de apoio de cada ciclo e o momento de cada
passo (usado para sincronizar as direções e tocar o som do passo).

Uso: python tools/convert_r6_animations.py   (lê animacoes_r6/, reescreve o bloco gerado no cliente)
"""
from pathlib import Path
import base64
import hashlib
import json
import math
import struct
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "animacoes_r6"
CLIENT = ROOT / "src" / "play.client.luau"
BEGIN = "-- __R6_ANIMACOES_INICIO__ (gerado por tools/convert_r6_animations.py; não editar à mão)"
END = "-- __R6_ANIMACOES_FIM__"
# Ordem das juntas nos dados: pose da KeyframeSequence -> Motor6D do R6.
JOINTS = ["Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"]
# Chave curta no jogo, arquivo e direção de deslocamento no espaço do personagem (frente = -Z, direita = +X).
CLIPS = [
    ("idle", "Idle_Okarun_R6", None),
    ("frente", "Walk_Forward_R6", (0, -1)),
    ("frente_direita", "Walk_ForwardRight_R6", (1, -1)),
    ("direita", "Walk_Right_R6", (1, 0)),
    ("tras_direita", "Walk_BackwardRight_R6", (1, 1)),
    ("tras", "Walk_Backward_R6", (0, 1)),
    ("tras_esquerda", "Walk_BackwardLeft_R6", (-1, 1)),
    ("esquerda", "Walk_Left_R6", (-1, 0)),
    ("frente_esquerda", "Walk_ForwardLeft_R6", (-1, -1)),
    ("corrida", "Sprint_Forward_Okarun_R6", (0, -1)),
]
ROT_SCALE = 32767
POS_SCALE = 8192


# Matemática de CFrame (matriz 3x4) -------------------------------------------------------------------
def cframe(x, y, z, r):
    return (x, y, z, r)


def mul(a, b):
    ax, ay, az, ar = a
    bx, by, bz, br = b
    r = [[sum(ar[i][k] * br[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    p = [ax + sum(ar[0][k] * (bx, by, bz)[k] for k in range(3)),
         ay + sum(ar[1][k] * (bx, by, bz)[k] for k in range(3)),
         az + sum(ar[2][k] * (bx, by, bz)[k] for k in range(3))]
    return (p[0], p[1], p[2], r)


def inverse(a):
    x, y, z, r = a
    rt = [[r[j][i] for j in range(3)] for i in range(3)]
    p = [-sum(rt[i][k] * (x, y, z)[k] for k in range(3)) for i in range(3)]
    return (p[0], p[1], p[2], rt)


def point(a, v):
    x, y, z, r = a
    return tuple((x, y, z)[i] + sum(r[i][k] * v[k] for k in range(3)) for i in range(3))


def rows(values):
    return [values[0:3], values[3:6], values[6:9]]


# Juntas do R6 padrão (C0 e C1).
R6 = {
    "Torso": (cframe(0, 0, 0, rows([-1, 0, 0, 0, 0, 1, 0, 1, 0])), cframe(0, 0, 0, rows([-1, 0, 0, 0, 0, 1, 0, 1, 0]))),
    "Head": (cframe(0, 1, 0, rows([-1, 0, 0, 0, 0, 1, 0, 1, 0])), cframe(0, -0.5, 0, rows([-1, 0, 0, 0, 0, 1, 0, 1, 0]))),
    "Right Arm": (cframe(1, 0.5, 0, rows([0, 0, 1, 0, 1, 0, -1, 0, 0])), cframe(-0.5, 0.5, 0, rows([0, 0, 1, 0, 1, 0, -1, 0, 0]))),
    "Left Arm": (cframe(-1, 0.5, 0, rows([0, 0, -1, 0, 1, 0, 1, 0, 0])), cframe(0.5, 0.5, 0, rows([0, 0, -1, 0, 1, 0, 1, 0, 0]))),
    "Right Leg": (cframe(1, -1, 0, rows([0, 0, 1, 0, 1, 0, -1, 0, 0])), cframe(0.5, 1, 0, rows([0, 0, 1, 0, 1, 0, -1, 0, 0]))),
    "Left Leg": (cframe(-1, -1, 0, rows([0, 0, -1, 0, 1, 0, 1, 0, 0])), cframe(-0.5, 1, 0, rows([0, 0, -1, 0, 1, 0, 1, 0, 0]))),
}


def quaternion(r):
    """Matriz de rotação -> quatérnio (x, y, z, w), com w >= 0."""
    m00, m01, m02 = r[0]
    m10, m11, m12 = r[1]
    m20, m21, m22 = r[2]
    trace = m00 + m11 + m22
    if trace > 0:
        s = math.sqrt(trace + 1.0) * 2
        w, x, y, z = 0.25 * s, (m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2
        w, x, y, z = (m21 - m12) / s, 0.25 * s, (m01 + m10) / s, (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2
        w, x, y, z = (m02 - m20) / s, (m01 + m10) / s, 0.25 * s, (m12 + m21) / s
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2
        w, x, y, z = (m10 - m01) / s, (m02 + m20) / s, (m12 + m21) / s, 0.25 * s
    n = math.sqrt(x * x + y * y + z * z + w * w)
    x, y, z, w = x / n, y / n, z / n, w / n
    if w < 0:
        x, y, z, w = -x, -y, -z, -w
    return x, y, z, w


def from_quaternion(px, py, pz, x, y, z, w):
    return cframe(px, py, pz, [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


# Leitura do RBXMX -------------------------------------------------------------------------------------
def read_sequence(path):
    raw = path.read_bytes()
    if b"<!DOCTYPE" in raw or b"<!ENTITY" in raw:
        raise ValueError(f"{path.name}: XML com DOCTYPE/ENTITY recusado")
    root = ET.fromstring(raw)
    sequence = root.find("Item[@class='KeyframeSequence']")
    if sequence is None:
        raise ValueError(f"{path.name}: sem KeyframeSequence")
    props = sequence.find("Properties")
    name = props.find("string[@name='Name']").text
    loop = props.find("bool[@name='Loop']").text == "true"
    priority = int(props.find("token[@name='Priority']").text)
    keyframes = []
    for item in sequence.findall("Item[@class='Keyframe']"):
        time = float(item.find("Properties/float[@name='Time']").text)
        poses = {}

        def walk(node):
            for pose in node.findall("Item[@class='Pose']"):
                p = pose.find("Properties")
                pname = p.find("string[@name='Name']").text
                cf = p.find("CoordinateFrame[@name='CFrame']")
                values = [float(cf.find(tag).text) for tag in
                          ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
                easing = int(p.find("token[@name='EasingStyle']").text)
                weight = float(p.find("float[@name='Weight']").text)
                if easing != 0 or abs(weight - 1) > 1e-9:
                    raise ValueError(f"{path.name}: pose {pname} em {time} não é Linear/peso 1")
                poses[pname] = cframe(values[0], values[1], values[2], rows(values[3:]))
                walk(pose)

        walk(item)
        missing = [j for j in JOINTS if j not in poses]
        if missing:
            raise ValueError(f"{path.name}: keyframe {time} sem {missing}")
        keyframes.append((time, poses))
    keyframes.sort(key=lambda k: k[0])
    return {"name": name, "loop": loop, "priority": priority, "keyframes": keyframes}


def body(poses):
    """Peças do R6 no espaço do HumanoidRootPart para as poses dadas."""
    root = cframe(0, 0, 0, rows([1, 0, 0, 0, 1, 0, 0, 0, 1]))
    c0, c1 = R6["Torso"]
    torso = mul(mul(mul(root, c0), poses["Torso"]), inverse(c1))
    parts = {"Torso": torso}
    for joint in JOINTS[1:]:
        c0, c1 = R6[joint]
        parts[joint] = mul(mul(mul(torso, c0), poses[joint]), inverse(c1))
    return parts


def analyse(sequence, travel):
    """Velocidade do pé de apoio (studs/s) e fase de cada passo (pé mais à frente no sentido do movimento)."""
    frames = sequence["keyframes"]
    times = [t for t, _ in frames]
    duration = times[-1] - times[0]
    feet = {"Right Leg": [], "Left Leg": []}
    for _, poses in frames:
        parts = body(poses)
        for leg in feet:
            feet[leg].append(point(parts[leg], (0, -1, 0)))
    if travel is None:
        return None, None
    tx, tz = travel
    norm = math.hypot(tx, tz)
    tx, tz = tx / norm, tz / norm
    speeds = []
    strikes = {}
    for leg, track in feet.items():
        reach = [p[0] * tx + p[2] * tz for p in track]
        strikes[leg] = times[max(range(len(reach)), key=lambda i: reach[i])] / duration
        lowest = min(p[1] for p in track)
        for i in range(len(track) - 1):
            # Pé de apoio: perto do ponto mais baixo e indo para trás no sentido do movimento.
            if track[i][1] < lowest + 0.12:
                dt = times[i + 1] - times[i]
                v = -((track[i + 1][0] - track[i][0]) * tx + (track[i + 1][2] - track[i][2]) * tz) / dt
                if v > 0:
                    speeds.append(v)
    speed = sorted(speeds)[len(speeds) // 2] if speeds else None
    return speed, (strikes["Right Leg"], strikes["Left Leg"])


def encode(sequence):
    data = bytearray()
    worst = 0.0
    for _, poses in sequence["keyframes"]:
        for joint in JOINTS:
            px, py, pz, r = poses[joint]
            q = quaternion(r)
            if max(abs(px), abs(py), abs(pz)) >= 32767 / POS_SCALE:
                raise ValueError("translação fora da faixa de 16 bits")
            ints = [round(v * ROT_SCALE) for v in q] + [round(v * POS_SCALE) for v in (px, py, pz)]
            data += struct.pack("<7h", *ints)
            # Erro da compactação: posição do fim de cada membro (2 studs) comparada com a original.
            back = from_quaternion(ints[4] / POS_SCALE, ints[5] / POS_SCALE, ints[6] / POS_SCALE,
                                   *(v / ROT_SCALE for v in ints[:4]))
            a = point((px, py, pz, r), (0, -2, 0))
            b = point(back, (0, -2, 0))
            worst = max(worst, math.dist(a, b))
    return bytes(data), worst


def main():
    manifest = {row["name"]: row for row in json.loads((SOURCE / "00_Manifesto.json").read_text(encoding="utf-8"))}
    clips = []
    blob = bytearray()
    report = []
    for key, name, travel in CLIPS:
        path = SOURCE / f"{name}.rbxmx"
        entry = manifest[name]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != entry["sha256_rbxmx"]:
            raise ValueError(f"{name}: hash diferente do manifesto")
        sequence = read_sequence(path)
        frames = sequence["keyframes"]
        times = [t for t, _ in frames]
        if sequence["name"] != entry["internal_sequence_name"] or len(frames) != entry["keyframes"]:
            raise ValueError(f"{name}: nome interno ou número de keyframes diferente do manifesto")
        duration = times[-1] - times[0]
        if abs(duration - entry["duration_seconds"]) > 1e-6 or times[0] != 0:
            raise ValueError(f"{name}: duração diferente do manifesto")
        step = duration / (len(times) - 1)
        if any(abs(times[i] - i * step) > 1e-5 for i in range(len(times))):
            raise ValueError(f"{name}: keyframes fora do passo uniforme")
        first, last = frames[0][1], frames[-1][1]
        loop_error = max(abs(a - b) for j in JOINTS for a, b in
                         zip(list(first[j][:3]) + sum(first[j][3], []), list(last[j][:3]) + sum(last[j][3], [])))
        if loop_error > 1e-5:
            raise ValueError(f"{name}: a última pose não fecha o laço ({loop_error})")
        data, worst = encode(sequence)
        speed, strikes = analyse(sequence, travel)
        clips.append({
            "key": key, "name": name, "sequence": sequence["name"], "offset": len(blob), "count": len(frames),
            "duration": duration, "reference": entry["reference_speed_studs_per_second"],
            "priority": "Idle" if sequence["priority"] == 0 else "Movement",
            "strikes": strikes, "measured": speed,
        })
        blob += data
        report.append(f"{key:16} {len(frames):4} quadros {duration:4.2f} s  ref {entry['reference_speed_studs_per_second']}"
                      f"  pé de apoio medido {speed if speed is None else round(speed, 2)}  passos {strikes and tuple(round(s, 3) for s in strikes)}"
                      f"  erro {worst:.5f}")
    encoded = base64.b64encode(bytes(blob)).decode("ascii")
    lines = [BEGIN,
             "-- Fonte: animacoes_r6/*.rbxmx (pacote do usuário, 10 ciclos R6). Juntas por keyframe: tronco, cabeça,",
             "-- braço direito, braço esquerdo, perna direita, perna esquerda; quatérnio x, y, z, w (/32767) e",
             "-- posição (/8192) em int16. passos: fase (0 a 1) em que cada pé pisa à frente, medida no rig R6.",
             "local R6_CLIPS = {"]
    for clip in clips:
        reference = "nil" if clip["reference"] is None else repr(float(clip["reference"]))
        strikes = "nil" if clip["strikes"] is None else "{ %.4f, %.4f }" % clip["strikes"]
        lines.append(f'\t{{ key = "{clip["key"]}", sequence = "{clip["sequence"]}", offset = {clip["offset"]}, '
                     f'count = {clip["count"]}, duration = {clip["duration"]:.4f}, reference = {reference}, '
                     f'priority = "{clip["priority"]}", steps = {strikes} }},')
    lines.append("}")
    lines.append(f'local R6_DATA = "{encoded}"')
    lines.append(END)
    block = "\n".join(lines)
    source = CLIENT.read_text(encoding="utf-8")
    if BEGIN in source:
        start = source.index(BEGIN)
        end = source.index(END) + len(END)
        source = source[:start] + block + source[end:]
    else:
        raise ValueError("Marque no cliente onde entra o bloco gerado (" + BEGIN + " ... " + END + ")")
    CLIENT.write_text(source, encoding="utf-8")
    print("\n".join(report))
    print(f"{len(clips)} animações, {len(blob)} bytes ({len(encoded)} em base64) gravados em {CLIENT.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
