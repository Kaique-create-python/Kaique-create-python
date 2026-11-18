"""Corrida medonha do monstro 731-A (3 ciclos da corrida original = 2,8 s, para os tiques não ficarem repetitivos).
Pernas intactas (pés no chão e marcadores Foot_R/Foot_L no mesmo lugar); muda tronco, cabeça, braços e dedos.
Eixos locais (testados na prévia): coluna/cabeça X+ = inclina para frente, X- = ergue; Y = gira; Z = tomba de lado.
Braço: X+ = levanta para frente, X- = abaixa; Z é espelhado entre os lados."""
import math
CICLO = 28 / 30; CICLOS = 3; FPS = 30
W = 2 * math.pi / CICLO
PE_D, PE_E = 7 / 30, 21 / 30  # marcadores Foot_R e Foot_L da corrida original

def tique(t, t0, subida=1 / 30, segura=0.10, descida=0.16):
    """Espasmo: estala em 1 quadro, segura e volta devagar."""
    d = t - t0
    if d < 0: return 0.0
    if d < subida: return d / subida
    d -= subida
    if d < segura: return 1.0
    d -= segura
    if d < descida:
        u = d / descida
        return 1 - u * u * (3 - 2 * u)
    return 0.0

def ruido(t, semente):
    """Tremor determinístico (mesmo valor na prévia e no Roblox)."""
    k = int(round(t * FPS))
    x = math.sin(k * 12.9898 + semente * 78.233) * 43758.5453
    return (x - math.floor(x)) * 2 - 1

# tiques da cabeça ao longo dos 3 ciclos: (início, (x, y, z))
TIQUES_CABECA = [(0.30, (6, 30, -16)), (1.22, (-4, -8, 34)), (1.70, (0, -26, 0)), (2.25, (14, 18, 12))]
TIQUES_DEDOS = [0.55, 1.45, 2.45]

def offset(o, t):
    fase = W * t
    if o == "spine_01":
        return (9 + 2 * math.sin(2 * fase), 7 * math.sin(fase + 0.6), 5 * math.sin(fase))
    if o == "spine_02":
        return (9, 4 * math.sin(fase + 0.9), -2 * math.sin(fase))
    if o == "chest":
        return (11 + 3 * math.sin(2 * fase + 1.2), 3 * math.sin(fase + 1.3), -4 * math.sin(fase + 0.4))
    if o == "neck":
        return (-22, 0, 3 * math.sin(fase))
    if o == "head":
        x, y, z = -17, 0, 14  # cabeça erguida encarando e torta
        for t0, (ax, ay, az) in TIQUES_CABECA:
            k = tique(t, t0); x += ax * k; y += ay * k; z += az * k
        return (x + 2.5 * ruido(t, 1), y + 3 * ruido(t, 2), z + 2.5 * ruido(t, 3))
    # braços batendo como bicho, em oposição às pernas (pé direito na frente -> braço esquerdo na frente)
    if o == "upper_arm.L":  # Z- abre o braço esquerdo para fora
        return (-14 + 30 * math.cos(W * (t - PE_D)), 0, -18 - 6 * math.sin(W * (t - PE_D)))
    if o == "upper_arm.R":  # no direito é espelhado: Z+ abre
        return (-14 + 30 * math.cos(W * (t - PE_E)), 0, 18 + 6 * math.sin(W * (t - PE_E)))
    if o in ("forearm.L", "forearm.R"):
        return (-10, 0, 0)
    if o.split("_")[0] in ("index", "middle", "ring"):
        k = max(tique(t, t0, segura=0.06, descida=0.12) for t0 in TIQUES_DEDOS)
        return (-30 * k, 0, 0)  # dedos abrem de repente (espasmo) e voltam à garra
    return None
