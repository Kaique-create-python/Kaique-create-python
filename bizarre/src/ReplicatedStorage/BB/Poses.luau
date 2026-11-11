-- BIZARRE BATTLEGROUNDS :: poses e animações feitas por código (sem Animation Editor)
-- Ângulos em graus, no espaço da peça "pai" de cada junta (R15):
--   ombro: X+ = braço para frente/cima; esquerdo Z- = para fora; direito Z+ = para fora
--   cotovelo: X+ = dobra;   quadril: X+ = perna para frente;   joelho: X- = dobra
--   cintura (Waist): X+ = inclina para trás, Y+ = gira para a esquerda, Z+ = tomba para a esquerda
--   pescoço: X+ = olha para cima;   Root: o corpo inteiro

local Poses = {}

-- nomes curtos -> juntas do R15
Poses.JUNTAS = {
	Root = "Root",
	Waist = "Waist",
	Neck = "Neck",
	LS = "LeftShoulder",
	LE = "LeftElbow",
	LW = "LeftWrist",
	RS = "RightShoulder",
	RE = "RightElbow",
	RW = "RightWrist",
	LH = "LeftHip",
	LK = "LeftKnee",
	LA = "LeftAnkle",
	RH = "RightHip",
	RK = "RightKnee",
	RA = "RightAnkle",
}

local P = {}
Poses.P = P

P.neutro = {}

P.guarda = {
	Waist = { -4, 12, 0 }, Neck = { 0, -10, 0 },
	LS = { 72, 0, -8 }, LE = { 104, 0, 0 },
	RS = { 58, 0, 14 }, RE = { 118, 0, 0 },
	LH = { 14, 0, -4 }, LK = { -16, 0, 0 }, RH = { -8, 0, 4 }, RK = { -16, 0, 0 },
}

P.soco_e_carrega = {
	Waist = { -2, 18, 0 },
	LS = { 54, 0, -14 }, LE = { 124, 0, 0 },
	RS = { 58, 0, 16 }, RE = { 116, 0, 0 },
	LH = { 14, 0, -4 }, LK = { -18, 0, 0 }, RH = { -8, 0, 4 }, RK = { -14, 0, 0 },
}

P.soco_e = {
	Waist = { -8, -22, 0 }, Neck = { 0, 16, 0 },
	LS = { 90, 0, 8 }, LE = { 4, 0, 0 }, LW = { -8, 0, 0 },
	RS = { 62, 0, 18 }, RE = { 112, 0, 0 },
	LH = { 22, 0, -4 }, LK = { -22, 0, 0 }, RH = { -14, 0, 4 }, RK = { -10, 0, 0 },
}

P.soco_d_carrega = {
	Waist = { -2, -16, 0 },
	LS = { 70, 0, -12 }, LE = { 108, 0, 0 },
	RS = { 44, 0, 20 }, RE = { 126, 0, 0 },
	LH = { 12, 0, -4 }, LK = { -16, 0, 0 }, RH = { -8, 0, 4 }, RK = { -16, 0, 0 },
}

P.soco_d = {
	Waist = { -10, 26, 0 }, Neck = { 0, -18, 0 },
	LS = { 62, 0, -18 }, LE = { 112, 0, 0 },
	RS = { 90, 0, -8 }, RE = { 4, 0, 0 }, RW = { -8, 0, 0 },
	LH = { 20, 0, -4 }, LK = { -24, 0, 0 }, RH = { -18, 0, 4 }, RK = { -8, 0, 0 },
}

P.gancho_e = {
	Waist = { -6, -34, 0 }, Neck = { 0, 22, 0 },
	LS = { 78, 0, -46 }, LE = { 84, 0, 0 },
	RS = { 60, 0, 18 }, RE = { 110, 0, 0 },
	LH = { 18, 0, -6 }, LK = { -24, 0, 0 }, RH = { -10, 0, 4 }, RK = { -12, 0, 0 },
}

P.soco_forte_carrega = {
	Waist = { 6, -34, 0 }, Root = { 0, 10, 0 }, Neck = { 0, 20, 0 },
	LS = { 70, 0, -20 }, LE = { 96, 0, 0 },
	RS = { 28, 0, 30 }, RE = { 130, 0, 0 },
	LH = { 24, 0, -6 }, LK = { -30, 0, 0 }, RH = { -10, 0, 6 }, RK = { -26, 0, 0 },
}

P.soco_forte = {
	Waist = { -14, 36, 0 }, Neck = { -4, -24, 0 },
	LS = { 38, 0, -34 }, LE = { 92, 0, 0 },
	RS = { 92, 0, -6 }, RE = { 0, 0, 0 }, RW = { -10, 0, 0 },
	LH = { 30, 0, -4 }, LK = { -34, 0, 0 }, RH = { -28, 0, 6 }, RK = { -6, 0, 0 },
}

P.uppercut = {
	Waist = { 12, 22, 0 }, Neck = { 14, -10, 0 },
	LS = { 30, 0, -28 }, LE = { 90, 0, 0 },
	RS = { 160, 0, -10 }, RE = { 30, 0, 0 },
	LH = { 10, 0, -4 }, LK = { -14, 0, 0 }, RH = { -6, 0, 4 }, RK = { -8, 0, 0 }, RA = { -20, 0, 0 },
}

P.martelo_carrega = {
	Waist = { 16, 0, 0 }, Neck = { 12, 0, 0 },
	LS = { 168, 0, 12 }, LE = { 40, 0, 0 },
	RS = { 168, 0, -12 }, RE = { 40, 0, 0 },
	LH = { 30, 0, -6 }, LK = { -40, 0, 0 }, RH = { 30, 0, 6 }, RK = { -40, 0, 0 },
}

P.martelo = {
	Waist = { -32, 0, 0 }, Neck = { -18, 0, 0 },
	LS = { 46, 0, 10 }, LE = { 22, 0, 0 },
	RS = { 46, 0, -10 }, RE = { 22, 0, 0 },
	LH = { 44, 0, -10 }, LK = { -60, 0, 0 }, RH = { 44, 0, 10 }, RK = { -60, 0, 0 },
}

P.comando = {
	Waist = { 0, 14, 0 }, Neck = { 0, -10, 0 },
	LS = { 4, 0, -10 }, LE = { 18, 0, 0 },
	RS = { 90, 0, -6 }, RE = { 8, 0, 0 }, RW = { -12, 0, 0 },
	LH = { 6, 0, -6 }, RH = { -4, 0, 6 }, LK = { -6, 0, 0 },
}

P.comando_aponta = {
	Waist = { 6, 26, 6 }, Neck = { 6, -22, 0 }, Root = { 0, -6, 0 },
	LS = { 30, 0, -32 }, LE = { 122, 0, 0 }, LW = { 10, 0, 0 },
	RS = { 96, 0, -18 }, RE = { 0, 0, 0 }, RW = { -16, 0, 0 },
	LH = { 0, 0, -12 }, RH = { -12, 0, 12 }, RK = { -12, 0, 0 }, LK = { -4, 0, 0 },
}

P.comando_cruzado = {
	Waist = { 6, 0, 0 }, Neck = { 6, 0, 0 },
	LS = { 62, 0, 30 }, LE = { 104, 0, 0 },
	RS = { 58, 0, -30 }, RE = { 104, 0, 0 },
	LH = { 0, 0, -6 }, RH = { 0, 0, 6 },
}

P.cruzado_flutua = {
	Waist = { 4, 0, 0 }, Neck = { -6, 0, 0 },
	LS = { 60, 0, 30 }, LE = { 106, 0, 0 },
	RS = { 56, 0, -30 }, RE = { 106, 0, 0 },
	LH = { 12, 0, -4 }, LK = { -26, 0, 0 }, LA = { -26, 0, 0 },
	RH = { 4, 0, 4 }, RK = { -34, 0, 0 }, RA = { -24, 0, 0 },
}

P.bloqueio = {
	Waist = { -8, 0, 0 }, Neck = { -12, 0, 0 },
	LS = { 96, 0, 26 }, LE = { 112, 0, 0 },
	RS = { 92, 0, -26 }, RE = { 116, 0, 0 },
	LH = { 16, 0, -6 }, LK = { -22, 0, 0 }, RH = { 16, 0, 6 }, RK = { -22, 0, 0 },
}

-- AJUSTE-10: o Stand na frente do dono protegendo: braços cruzados em X na frente do rosto,
-- tronco curvado para a frente, pernas soltas flutuando
P.stand_guarda = {
	Waist = { -12, 0, 0 }, Neck = { -10, 0, 0 },
	LS = { 80, 0, 42 }, LE = { 90, 0, 0 },
	RS = { 78, 0, -42 }, RE = { 92, 0, 0 },
	LH = { 14, 0, -5 }, LK = { -28, 0, 0 }, RH = { 4, 0, 5 }, RK = { -36, 0, 0 },
}
-- apanhou na guarda: braços empurrados contra o rosto, tronco vai para trás
P.stand_guarda_impacto = {
	Waist = { 8, 0, 0 }, Neck = { -16, 0, 0 },
	LS = { 68, 0, 42 }, LE = { 112, 0, 0 },
	RS = { 66, 0, -42 }, RE = { 114, 0, 0 },
	LH = { 22, 0, -7 }, LK = { -34, 0, 0 }, RH = { 12, 0, 7 }, RK = { -40, 0, 0 },
}

P.lancar_carrega = {
	Waist = { 8, -36, 0 }, Neck = { 0, 26, 0 },
	LS = { 72, 0, -22 }, LE = { 40, 0, 0 },
	RS = { 150, 0, 30 }, RE = { 92, 0, 0 },
	LH = { 20, 0, -6 }, LK = { -18, 0, 0 }, RH = { -14, 0, 6 }, RK = { -14, 0, 0 },
}

P.lancar = {
	Waist = { -16, 30, 0 }, Neck = { -4, -20, 0 },
	LS = { 20, 0, -34 }, LE = { 30, 0, 0 },
	RS = { 82, 0, -14 }, RE = { 8, 0, 0 }, RW = { -20, 0, 0 },
	LH = { 26, 0, -4 }, LK = { -30, 0, 0 }, RH = { -20, 0, 6 }, RK = { -8, 0, 0 },
}

P.leque_carrega = {
	Waist = { 6, 0, 0 },
	LS = { 70, 0, 50 }, LE = { 110, 0, 0 },
	RS = { 70, 0, -50 }, RE = { 110, 0, 0 },
}

P.leque = {
	Waist = { -6, 0, 0 }, Neck = { -4, 0, 0 },
	LS = { 86, 0, -58 }, LE = { 4, 0, 0 }, LW = { -10, 0, 0 },
	RS = { 86, 0, 58 }, RE = { 4, 0, 0 }, RW = { -10, 0, 0 },
	LH = { 14, 0, -8 }, LK = { -18, 0, 0 }, RH = { 14, 0, 8 }, RK = { -18, 0, 0 },
}

P.agachar = {
	Waist = { -24, 0, 0 }, Neck = { 10, 0, 0 },
	LS = { -30, 0, -14 }, LE = { 20, 0, 0 }, RS = { -30, 0, 14 }, RE = { 20, 0, 0 },
	LH = { 62, 0, -6 }, LK = { -92, 0, 0 }, LA = { 30, 0, 0 },
	RH = { 62, 0, 6 }, RK = { -92, 0, 0 }, RA = { 30, 0, 0 },
}

P.no_ar = {
	Waist = { 8, 0, 0 }, Neck = { 8, 0, 0 },
	LS = { 150, 0, -30 }, LE = { 30, 0, 0 }, RS = { 150, 0, 30 }, RE = { 30, 0, 0 },
	LH = { 30, 0, -6 }, LK = { -60, 0, 0 }, RH = { 10, 0, 6 }, RK = { -30, 0, 0 },
}

P.slam = {
	Waist = { -36, 0, 0 }, Neck = { -6, 0, 0 },
	LS = { -18, 0, -40 }, LE = { 30, 0, 0 },
	RS = { 64, 0, -6 }, RE = { 16, 0, 0 },
	LH = { 72, 0, -22 }, LK = { -104, 0, 0 }, LA = { 30, 0, 0 },
	RH = { 30, 0, 22 }, RK = { -70, 0, 0 }, RA = { 30, 0, 0 },
}

P.investida = {
	Root = { -26, 0, 0 }, Waist = { -14, 10, 0 }, Neck = { 22, -6, 0 },
	LS = { -40, 0, -16 }, LE = { 30, 0, 0 },
	RS = { 94, 0, -6 }, RE = { 0, 0, 0 },
	LH = { 34, 0, -4 }, LK = { -40, 0, 0 }, RH = { -36, 0, 4 }, RK = { -30, 0, 0 },
}

P.agarrar_carrega = {
	Waist = { 4, 0, 0 },
	LS = { 100, 0, -46 }, LE = { 20, 0, 0 },
	RS = { 100, 0, 46 }, RE = { 20, 0, 0 },
}

P.agarrar = {
	Waist = { -10, 0, 0 }, Neck = { -6, 0, 0 },
	LS = { 92, 0, 14 }, LE = { 36, 0, 0 },
	RS = { 92, 0, -14 }, RE = { 36, 0, 0 },
	LH = { 18, 0, -6 }, LK = { -20, 0, 0 }, RH = { -10, 0, 6 }, RK = { -12, 0, 0 },
}

P.chute_carrega = {
	Waist = { 8, 20, 0 }, Neck = { 0, -10, 0 },
	LS = { 40, 0, -40 }, LE = { 60, 0, 0 }, RS = { 30, 0, 50 }, RE = { 60, 0, 0 },
	RH = { 70, 0, 4 }, RK = { -100, 0, 0 }, LK = { -18, 0, 0 },
}

P.chute_alto = {
	Waist = { 18, 14, 0 }, Neck = { -8, -10, 0 },
	LS = { -28, 0, -52 }, LE = { 20, 0, 0 }, RS = { -16, 0, 44 }, RE = { 20, 0, 0 },
	RH = { 116, 0, 6 }, RK = { 0, 0, 0 }, RA = { -30, 0, 0 },
	LH = { -6, 0, -4 }, LK = { -12, 0, 0 },
}

P.contra_pose = {
	Waist = { -4, -22, 0 }, Neck = { 0, 24, 0 },
	LS = { 102, 0, 18 }, LE = { 64, 0, 0 }, LW = { 20, 0, 0 },
	RS = { 30, 0, -40 }, RE = { 104, 0, 0 },
	LH = { 22, 0, -10 }, LK = { -28, 0, 0 }, RH = { -12, 0, 10 }, RK = { -26, 0, 0 },
}

P.cura = {
	Waist = { 6, 0, 0 }, Neck = { 22, 0, 0 },
	LS = { 58, 0, 30 }, LE = { 92, 0, 0 },
	RS = { 58, 0, -30 }, RE = { 92, 0, 0 },
	LH = { 0, 0, -4 }, RH = { 0, 0, 4 },
}

P.conjurar = {
	Waist = { 12, 0, 0 }, Neck = { 26, 0, 0 },
	LS = { 168, 0, -22 }, LE = { 12, 0, 0 },
	RS = { 168, 0, 22 }, RE = { 12, 0, 0 },
	LH = { 0, 0, -10 }, RH = { 0, 0, 10 },
}

P.pisao_carrega = {
	Waist = { 6, 0, 0 },
	LS = { 30, 0, -50 }, LE = { 40, 0, 0 }, RS = { 30, 0, 50 }, RE = { 40, 0, 0 },
	RH = { 84, 0, 6 }, RK = { -92, 0, 0 }, LK = { -10, 0, 0 },
}

P.pisao = {
	Waist = { -20, 0, 0 }, Neck = { -10, 0, 0 },
	LS = { -10, 0, -48 }, LE = { 30, 0, 0 }, RS = { -10, 0, 48 }, RE = { 30, 0, 0 },
	RH = { 24, 0, 8 }, RK = { -30, 0, 0 }, LH = { 24, 0, -8 }, LK = { -34, 0, 0 },
}

P.sopro = {
	Waist = { -6, 0, 0 }, Neck = { -2, 0, 0 },
	LS = { 90, 0, 12 }, LE = { 6, 0, 0 }, LW = { -56, 0, 0 },
	RS = { 90, 0, -12 }, RE = { 6, 0, 0 }, RW = { -56, 0, 0 },
	LH = { 20, 0, -6 }, LK = { -20, 0, 0 }, RH = { -14, 0, 6 }, RK = { -10, 0, 0 },
}

P.tempo = {
	Waist = { 16, 0, 0 }, Neck = { 22, 0, 0 },
	LS = { 12, 0, -102 }, LE = { 10, 0, 0 },
	RS = { 12, 0, 102 }, RE = { 10, 0, 0 },
	LH = { 0, 0, -10 }, RH = { 0, 0, 10 },
}

-- poses "bizarras" (despertar e emotes)
P.despertar = {
	Root = { 0, 18, 0 }, Waist = { -6, -36, 12 }, Neck = { -10, 30, 10 },
	RS = { 150, 0, -58 }, RE = { 112, 0, 0 },
	LS = { -30, 0, -44 }, LE = { 40, 0, 0 },
	LH = { -10, 0, 16 }, LK = { -6, 0, 0 }, RH = { 26, 0, 10 }, RK = { -36, 0, 0 },
}

P.pose1 = {
	Waist = { 0, -26, 8 }, Neck = { 8, 26, 0 },
	RS = { 92, 0, -20 }, RE = { 0, 0, 0 }, RW = { -20, 0, 0 },
	LS = { 10, 0, -56 }, LE = { 112, 0, 0 },
	LH = { 0, 0, -16 }, RH = { 16, 0, 12 }, RK = { -22, 0, 0 },
}

P.pose2 = {
	Root = { 0, 0, 8 }, Waist = { 0, 16, -16 }, Neck = { -6, 0, 16 },
	LS = { 160, 0, -40 }, LE = { 120, 0, 0 },
	RS = { 150, 0, 50 }, RE = { 102, 0, 0 },
	LH = { 20, 0, -10 }, LK = { -40, 0, 0 }, RH = { 0, 0, 8 },
}

P.pose3 = {
	Waist = { -10, 60, 0 }, Neck = { 0, 40, 0 },
	RS = { 40, 0, -80 }, RE = { 130, 0, 0 },
	LS = { 120, 0, 10 }, LE = { 92, 0, 0 },
	LH = { -20, 0, -4 }, RH = { 30, 0, 20 }, RK = { -32, 0, 0 },
}

P.atordoado = {
	Waist = { 16, 10, 0 }, Neck = { 22, 0, 0 },
	LS = { -18, 0, -26 }, LE = { 30, 0, 0 }, RS = { -18, 0, 26 }, RE = { 30, 0, 0 },
	LK = { -16, 0, 0 }, RK = { -12, 0, 0 },
}

P.atingido = {
	Waist = { 22, 0, 0 }, Neck = { 28, 0, 0 },
	LS = { 40, 0, -30 }, LE = { 60, 0, 0 }, RS = { 40, 0, 30 }, RE = { 60, 0, 0 },
	LK = { -10, 0, 0 }, RK = { -10, 0, 0 },
}

P.ragdoll = {
	Waist = { 20, 0, 0 }, Neck = { 30, 0, 0 },
	LS = { 140, 0, -50 }, LE = { 30, 0, 0 }, RS = { 120, 0, 60 }, RE = { 40, 0, 0 },
	LH = { 40, 0, -20 }, LK = { -50, 0, 0 }, RH = { 10, 0, 24 }, RK = { -20, 0, 0 },
}

P.dash_frente = {
	Root = { -28, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { 20, 0, 0 },
	LS = { -50, 0, -16 }, LE = { 20, 0, 0 }, RS = { -50, 0, 16 }, RE = { 20, 0, 0 },
	LH = { 44, 0, -4 }, LK = { -70, 0, 0 }, RH = { -20, 0, 4 }, RK = { -20, 0, 0 },
}

P.dash_tras = {
	Root = { 16, 0, 0 }, Waist = { 10, 0, 0 },
	LS = { 70, 0, -20 }, LE = { 60, 0, 0 }, RS = { 70, 0, 20 }, RE = { 60, 0, 0 },
	LH = { 30, 0, -4 }, LK = { -40, 0, 0 }, RH = { 10, 0, 4 }, RK = { -30, 0, 0 },
}

P.dash_direita = {
	Root = { 0, 0, -22 }, Waist = { 0, 0, -8 },
	LS = { 20, 0, -60 }, LE = { 30, 0, 0 }, RS = { -10, 0, 30 },
	LH = { 0, 0, -26 }, RH = { 0, 0, 12 }, LK = { -20, 0, 0 },
}

P.dash_esquerda = {
	Root = { 0, 0, 22 }, Waist = { 0, 0, 8 },
	RS = { 20, 0, 60 }, RE = { 30, 0, 0 }, LS = { -10, 0, -30 },
	RH = { 0, 0, 26 }, LH = { 0, 0, -12 }, RK = { -20, 0, 0 },
}

P.estocada_carrega = {
	Waist = { 4, -26, 0 }, Neck = { 0, 18, 0 },
	RS = { 60, 0, 12 }, RE = { 112, 0, 0 },
	LS = { 40, 0, -40 }, LE = { 30, 0, 0 },
	LH = { 20, 0, -6 }, LK = { -24, 0, 0 }, RH = { -8, 0, 6 },
}

P.estocada = {
	Waist = { -12, 30, 0 }, Neck = { 0, -20, 0 },
	RS = { 90, 0, -2 }, RE = { 0, 0, 0 }, RW = { -4, 0, 0 },
	LS = { -30, 0, -52 }, LE = { 16, 0, 0 },
	LH = { 40, 0, -6 }, LK = { -52, 0, 0 }, RH = { -32, 0, 6 }, RK = { -4, 0, 0 },
}

P.gira_sombrinha = {
	Waist = { -4, 0, 0 },
	RS = { 92, 0, -4 }, RE = { 30, 0, 0 }, RW = { 0, 0, 0 },
	LS = { 30, 0, -40 }, LE = { 40, 0, 0 },
	LH = { 16, 0, -8 }, LK = { -18, 0, 0 }, RH = { -6, 0, 8 },
}

P.planar = {
	Waist = { 6, 0, 0 }, Neck = { -10, 0, 0 },
	RS = { 172, 0, 6 }, RE = { 8, 0, 0 },
	LS = { 30, 0, -64 }, LE = { 20, 0, 0 },
	LH = { 22, 0, -6 }, LK = { -40, 0, 0 }, RH = { -8, 0, 6 }, RK = { -24, 0, 0 },
}

P.mergulho = {
	Root = { -42, 0, 0 }, Waist = { -8, 0, 0 }, Neck = { 30, 0, 0 },
	LS = { 150, 0, -30 }, LE = { 20, 0, 0 }, RS = { 150, 0, 30 }, RE = { 20, 0, 0 },
	RH = { 46, 0, 4 }, RK = { 0, 0, 0 }, RA = { -40, 0, 0 },
	LH = { -16, 0, -6 }, LK = { -84, 0, 0 },
}

P.giro = {
	Waist = { -8, 0, 0 },
	LS = { 80, 0, -70 }, LE = { 10, 0, 0 }, RS = { 80, 0, 70 }, RE = { 10, 0, 0 },
	LH = { 20, 0, -8 }, LK = { -30, 0, 0 }, RH = { -10, 0, 8 }, RK = { -20, 0, 0 },
}

-- AJUSTE-2: poses da JoJo ---------------------------------------------------------------------
-- Star Finger: o braço do Stand estica reto para a frente
P.star_finger_carrega = {
	Waist = { 6, -30, 0 }, Neck = { 0, 20, 0 },
	RS = { 40, 0, 20 }, RE = { 110, 0, 0 },
	LS = { 60, 0, -20 }, LE = { 90, 0, 0 },
}
P.star_finger = {
	Root = { -10, 0, 0 }, Waist = { -10, 32, 0 }, Neck = { -4, -24, 0 },
	RS = { 94, 0, -2 }, RE = { 0, 0, 0 }, RW = { -12, 0, 0 },
	LS = { -24, 0, -34 }, LE = { 20, 0, 0 },
	LH = { 24, 0, -6 }, LK = { -30, 0, 0 }, RH = { -24, 0, 6 }, RK = { -6, 0, 0 },
}
-- DIO: inclinado para trás, mão no rosto e outra na cintura
P.pose_dio = {
	Root = { 6, 10, 0 }, Waist = { 16, -26, -10 }, Neck = { 18, 22, 6 },
	RS = { 146, 0, -44 }, RE = { 104, 0, 0 },
	LS = { 18, 0, -62 }, LE = { 112, 0, 0 },
	RH = { 12, 0, 12 }, RK = { -22, 0, 0 }, LH = { -10, 0, -12 },
}
P.wryyy = {
	Root = { 18, 0, 0 }, Waist = { 34, 0, 0 }, Neck = { 38, 0, 0 },
	LS = { 46, 0, -112 }, LE = { 30, 0, 0 },
	RS = { 46, 0, 112 }, RE = { 30, 0, 0 },
	LH = { 16, 0, -14 }, LK = { -24, 0, 0 }, RH = { 16, 0, 14 }, RK = { -24, 0, 0 },
}
-- Josuke: uma mão ajeitando o topete, a outra apontando
P.pose_josuke = {
	Waist = { 2, 22, 6 }, Neck = { 6, -16, 0 },
	RS = { 152, 0, 30 }, RE = { 118, 0, 0 },
	LS = { 92, 0, 12 }, LE = { 4, 0, 0 }, LW = { -10, 0, 0 },
	LH = { 10, 0, -14 }, RH = { -8, 0, 14 }, RK = { -10, 0, 0 },
}
P.topete = {
	Waist = { 6, 0, 0 }, Neck = { 12, 0, 0 },
	RS = { 156, 0, 24 }, RE = { 120, 0, 0 },
	LS = { 156, 0, -24 }, LE = { 120, 0, 0 },
	LH = { 6, 0, -10 }, RH = { 6, 0, 10 },
}
-- Polnareff: em guarda de esgrima, de lado
P.esgrima = {
	Root = { 0, -18, 0 }, Waist = { -6, 40, 0 }, Neck = { 0, -34, 0 },
	RS = { 82, 0, -6 }, RE = { 18, 0, 0 },
	LS = { 124, 0, -72 }, LE = { 84, 0, 0 },
	LH = { 22, 0, -16 }, LK = { -32, 0, 0 }, RH = { -22, 0, 12 }, RK = { -22, 0, 0 },
}
P.saudacao = {
	Waist = { 4, 20, 0 }, Neck = { 6, -14, 0 },
	RS = { 160, 0, -8 }, RE = { 10, 0, 0 },
	LS = { 20, 0, -40 }, LE = { 70, 0, 0 },
	LH = { 6, 0, -8 }, RH = { 6, 0, 8 },
}
-- Kira: mão levantada, polegar no "detonador"
P.detonar = {
	Waist = { 4, 16, 0 }, Neck = { 8, -12, 0 },
	RS = { 104, 0, -12 }, RE = { 64, 0, 0 }, RW = { -30, 0, 0 },
	LS = { 8, 0, -14 }, LE = { 16, 0, 0 },
	LH = { 4, 0, -6 }, RH = { 2, 0, 6 },
}
P.pose_kira = {
	Waist = { 8, -20, 4 }, Neck = { 10, 18, 0 },
	RS = { 122, 0, -36 }, RE = { 96, 0, 0 }, RW = { -20, 0, 0 },
	LS = { 52, 0, 34 }, LE = { 104, 0, 0 },
	LH = { -6, 0, -10 }, RH = { 14, 0, 10 }, RK = { -16, 0, 0 },
}
-- Jotaro: puxa a aba do boné e aponta
P.aba_bone = {
	Waist = { -2, 10, 0 }, Neck = { -14, -8, 0 },
	RS = { 158, 0, -26 }, RE = { 132, 0, 0 },
	LS = { 4, 0, -18 }, LE = { 30, 0, 0 },
	LH = { 4, 0, -8 }, RH = { -4, 0, 8 },
}
-- Stand rugindo (despertar)
P.stand_ruge = {
	Root = { -8, 0, 0 }, Waist = { 22, 0, 0 }, Neck = { 30, 0, 0 },
	LS = { 70, 0, -96 }, LE = { 70, 0, 0 },
	RS = { 70, 0, 96 }, RE = { 70, 0, 0 },
	LH = { 20, 0, -18 }, LK = { -40, 0, 0 }, RH = { 20, 0, 18 }, RK = { -40, 0, 0 },
}

-- espelha uma pose (troca esquerda/direita)
local TROCA = { LS = "RS", RS = "LS", LE = "RE", RE = "LE", LW = "RW", RW = "LW", LH = "RH", RH = "LH", LK = "RK", RK = "LK", LA = "RA", RA = "LA" }
function Poses.espelhar(p: { [string]: { number } }): { [string]: { number } }
	local r = {}
	for k, v in p do
		local alvo = TROCA[k] or k
		r[alvo] = { v[1], -v[2], -v[3] }
	end
	return r
end

P.lancar_e = Poses.espelhar(P.lancar)
P.lancar_carrega_e = Poses.espelhar(P.lancar_carrega)

------------------------------------------------------------------------------------------- clipes
-- keys = { {tempo, pose, suavização} }. impacto = momento do golpe dentro do clipe
-- (o cliente acelera ou freia o clipe para o impacto cair junto com o golpe de verdade)
local C = {}
Poses.C = C

local function soco(carrega, solta, dur)
	return { dur = dur or 0.34, impacto = 0.1, keys = { { 0, carrega }, { 0.06, carrega, "saida" }, { 0.1, solta, "estalo" }, { 0.22, solta }, { dur or 0.34, "guarda", "suave" } } }
end

-- M1 do próprio usuário (Stand guardado)
C.m1_1 = soco("soco_e_carrega", "soco_e")
C.m1_2 = soco("soco_d_carrega", "soco_d")
C.m1_3 = { dur = 0.36, impacto = 0.12, keys = { { 0, "soco_e_carrega" }, { 0.07, "soco_e_carrega", "saida" }, { 0.12, "gancho_e", "estalo" }, { 0.24, "gancho_e" }, { 0.36, "guarda", "suave" } } }
C.m1_4 = { dur = 0.5, impacto = 0.16, keys = { { 0, "soco_forte_carrega" }, { 0.1, "soco_forte_carrega", "saida" }, { 0.16, "soco_forte", "estalo" }, { 0.36, "soco_forte" }, { 0.5, "guarda", "suave" } } }
C.m1_cima = { dur = 0.5, impacto = 0.15, keys = { { 0, "agachar" }, { 0.09, "agachar", "saida" }, { 0.15, "uppercut", "estalo" }, { 0.36, "uppercut" }, { 0.5, "guarda", "suave" } } }
C.m1_baixo = { dur = 0.5, impacto = 0.15, keys = { { 0, "martelo_carrega" }, { 0.09, "martelo_carrega", "saida" }, { 0.15, "martelo", "estalo" }, { 0.36, "martelo" }, { 0.5, "guarda", "suave" } } }
-- chutes (estilo BOSSA NOVA)
C.chute_1 = { dur = 0.34, impacto = 0.11, keys = { { 0, "chute_carrega" }, { 0.06, "chute_carrega", "saida" }, { 0.11, "chute_alto", "estalo" }, { 0.22, "chute_alto" }, { 0.34, "guarda", "suave" } } }

-- usuário comandando o Stand
C.comando_m1 = { dur = 0.3, impacto = 0.1, keys = { { 0, "guarda" }, { 0.1, "comando", "estalo" }, { 0.2, "comando" }, { 0.3, "guarda", "suave" } } }
C.comando = { dur = 0.6, impacto = 0.15, keys = { { 0, "guarda" }, { 0.15, "comando", "estalo" }, { 0.5, "comando" }, { 0.6, "guarda", "suave" } } }
C.comando_aponta = { segurar = true, keys = { { 0, "comando_aponta", "estalo" }, { 0.2, "comando_aponta" } } }
C.comando_cruzado = { segurar = true, keys = { { 0, "comando_cruzado", "suave" }, { 0.2, "comando_cruzado" } } }
C.lancar = { dur = 0.6, impacto = 0.3, keys = { { 0, "lancar_carrega" }, { 0.22, "lancar_carrega", "saida" }, { 0.3, "lancar", "estalo" }, { 0.5, "lancar" }, { 0.6, "guarda", "suave" } } }
C.leque = { dur = 0.55, impacto = 0.24, keys = { { 0, "leque_carrega" }, { 0.18, "leque_carrega", "saida" }, { 0.24, "leque", "estalo" }, { 0.45, "leque" }, { 0.55, "guarda", "suave" } } }
C.salto_slam = { dur = 1.0, impacto = 0.58, keys = { { 0, "agachar" }, { 0.08, "no_ar", "saida" }, { 0.4, "martelo_carrega", "suave" }, { 0.58, "slam", "estalo" }, { 0.85, "slam" }, { 1.0, "guarda", "suave" } } }
C.investida = { segurar = true, keys = { { 0, "investida", "estalo" }, { 0.2, "investida" } } }
C.agarrar = { dur = 0.5, impacto = 0.22, keys = { { 0, "agarrar_carrega" }, { 0.16, "agarrar_carrega" }, { 0.22, "agarrar", "estalo" }, { 0.5, "agarrar" } } }
C.chute_alto = { dur = 0.6, impacto = 0.16, keys = { { 0, "chute_carrega" }, { 0.1, "chute_carrega", "saida" }, { 0.16, "chute_alto", "estalo" }, { 0.42, "chute_alto" }, { 0.6, "guarda", "suave" } } }
C.contra_pose = { segurar = true, keys = { { 0, "contra_pose", "estalo" }, { 0.2, "contra_pose" } } }
C.cura = { segurar = true, keys = { { 0, "cura", "suave" }, { 0.3, "cura" } } }
C.conjurar = { segurar = true, keys = { { 0, "agachar" }, { 0.18, "conjurar", "saida" }, { 0.4, "conjurar" } } }
C.pisao = { dur = 0.35, impacto = 0.3, keys = { { 0, "pisao_carrega" }, { 0.2, "pisao_carrega", "saida" }, { 0.3, "pisao", "estalo" }, { 0.35, "pisao" } } }
C.sopro = { segurar = true, impacto = 0.3, keys = { { 0, "agachar" }, { 0.2, "agachar" }, { 0.3, "sopro", "estalo" }, { 0.5, "sopro" } } }
C.tempo = { segurar = true, keys = { { 0, "cruzado_flutua" }, { 0.5, "comando_cruzado", "suave" }, { 0.9, "tempo", "estalo" }, { 1.2, "tempo" } } }
C.despertar = { dur = 1.4, keys = { { 0, "agachar" }, { 0.25, "despertar", "estalo" }, { 1.25, "despertar" }, { 1.4, "guarda", "suave" } } }
C.pose1 = { segurar = true, keys = { { 0, "pose1", "estalo" }, { 0.3, "pose1" } } }
C.pose2 = { segurar = true, keys = { { 0, "pose2", "estalo" }, { 0.3, "pose2" } } }
C.pose3 = { segurar = true, keys = { { 0, "pose3", "estalo" }, { 0.3, "pose3" } } }
C.bloqueio = { segurar = true, keys = { { 0, "bloqueio", "estalo" }, { 0.1, "bloqueio" } } }
C.atordoado = { dur = 0.45, keys = { { 0, "atingido", "estalo" }, { 0.2, "atordoado", "suave" }, { 0.45, "atordoado" } } }
C.dash_frente = { dur = 0.32, keys = { { 0, "dash_frente", "estalo" }, { 0.24, "dash_frente" }, { 0.32, "guarda", "suave" } } }
C.dash_tras = { dur = 0.28, keys = { { 0, "dash_tras", "estalo" }, { 0.2, "dash_tras" }, { 0.28, "guarda", "suave" } } }
C.dash_direita = { dur = 0.28, keys = { { 0, "dash_direita", "estalo" }, { 0.2, "dash_direita" }, { 0.28, "guarda", "suave" } } }
C.dash_esquerda = { dur = 0.28, keys = { { 0, "dash_esquerda", "estalo" }, { 0.2, "dash_esquerda" }, { 0.28, "guarda", "suave" } } }
C.evasiva = { dur = 0.5, giro = { { 0, 0 }, { 0.4, 360 } }, keys = { { 0, "giro", "estalo" }, { 0.4, "giro" }, { 0.5, "guarda", "suave" } } }
C.giro = { segurar = true, giro = { { 0, 0 }, { 0.12, 360 } }, giroLoop = true, keys = { { 0, "giro", "estalo" }, { 0.1, "giro" } } }
C.planar = { segurar = true, keys = { { 0, "agachar" }, { 0.12, "planar", "saida" }, { 0.3, "planar" } } }
C.mergulho = { segurar = true, keys = { { 0, "mergulho", "estalo" }, { 0.2, "mergulho" } } }
C.estocada = { dur = 0.4, impacto = 0.12, keys = { { 0, "estocada_carrega" }, { 0.07, "estocada_carrega", "saida" }, { 0.12, "estocada", "estalo" }, { 0.28, "estocada" }, { 0.4, "guarda", "suave" } } }
C.uppercut = { dur = 0.5, impacto = 0.15, keys = { { 0, "agachar" }, { 0.08, "agachar", "saida" }, { 0.15, "uppercut", "estalo" }, { 0.4, "uppercut" }, { 0.5, "guarda", "suave" } } }

-- Stand
C.s_ocioso = { segurar = true, keys = { { 0, "cruzado_flutua", "suave" }, { 0.3, "cruzado_flutua" } } }
C.guarda = { segurar = true, keys = { { 0, "guarda", "suave" }, { 0.15, "guarda" } } }
-- AJUSTE-10: guarda do Stand (segura enquanto bloquear) e o tranco quando apanha nela
C.s_guarda = { segurar = true, keys = { { 0, "stand_guarda", "estalo" }, { 0.14, "stand_guarda" } } }
C.s_guarda_impacto = { dur = 0.24, keys = { { 0, "stand_guarda_impacto", "estalo" }, { 0.08, "stand_guarda_impacto" }, { 0.24, "stand_guarda", "suave" } } }
C.soco_d = soco("soco_d_carrega", "soco_d", 0.36)
C.soco_e = soco("soco_e_carrega", "soco_e", 0.36)
C.soco_pesado = { dur = 0.75, impacto = 0.48, keys = { { 0, "soco_forte_carrega" }, { 0.4, "soco_forte_carrega", "suave" }, { 0.48, "soco_forte", "estalo" }, { 0.66, "soco_forte" }, { 0.75, "guarda", "suave" } } }
C.slam = { dur = 0.9, impacto = 0.58, keys = { { 0, "martelo_carrega" }, { 0.48, "martelo_carrega", "suave" }, { 0.58, "martelo", "estalo" }, { 0.8, "martelo" }, { 0.9, "guarda", "suave" } } }
C.chute = C.chute_alto
C.estocadas = { proc = "estocadas", segurar = true, keys = { { 0, "estocada_carrega" } } }
C.gira_sombrinha = { segurar = true, giro = { { 0, 0 }, { 0.16, 360 } }, giroLoop = true, keys = { { 0, "gira_sombrinha", "estalo" }, { 0.1, "gira_sombrinha" } } }
C.barragem = { proc = "barragem", segurar = true, keys = { { 0, "guarda" } } }

-- AJUSTE-2: clipes da JoJo
C.star_finger = { dur = 0.62, impacto = 0.3, keys = { { 0, "star_finger_carrega" }, { 0.22, "star_finger_carrega", "suave" }, { 0.3, "star_finger", "estalo" }, { 0.52, "star_finger" }, { 0.62, "guarda", "suave" } } }
C.pose_dio = { segurar = true, keys = { { 0, "pose_dio", "estalo" }, { 0.25, "pose_dio" } } }
C.pose_josuke = { segurar = true, keys = { { 0, "pose_josuke", "estalo" }, { 0.25, "pose_josuke" } } }
C.esgrima = { segurar = true, keys = { { 0, "esgrima", "estalo" }, { 0.2, "esgrima" } } }
C.detonar = { segurar = true, keys = { { 0, "detonar", "suave" }, { 0.25, "detonar" } } }
C.pose_kira = { segurar = true, keys = { { 0, "pose_kira", "estalo" }, { 0.3, "pose_kira" } } }
-- despertar: um para cada Stand (o usuário faz a pose do personagem dele)
C.despertar_STAR_PLATINUM = { dur = 1.5, keys = { { 0, "agachar" }, { 0.2, "aba_bone", "estalo" }, { 0.75, "aba_bone" }, { 0.95, "comando_aponta", "estalo" }, { 1.35, "comando_aponta" }, { 1.5, "guarda", "suave" } } }
C.despertar_THE_WORLD = { dur = 1.6, keys = { { 0, "agachar" }, { 0.25, "wryyy", "estalo" }, { 0.95, "wryyy" }, { 1.15, "pose_dio", "estalo" }, { 1.45, "pose_dio" }, { 1.6, "guarda", "suave" } } }
C.despertar_MAGICIANS_RED = { dur = 1.5, keys = { { 0, "agachar" }, { 0.25, "conjurar", "estalo" }, { 0.8, "conjurar" }, { 1.0, "tempo", "estalo" }, { 1.35, "tempo" }, { 1.5, "guarda", "suave" } } }
C.despertar_SILVER_CHARIOT = { dur = 1.5, keys = { { 0, "esgrima" }, { 0.25, "saudacao", "estalo" }, { 0.85, "saudacao" }, { 1.05, "esgrima", "estalo" }, { 1.35, "esgrima" }, { 1.5, "guarda", "suave" } } }
C.despertar_CRAZY_DIAMOND = { dur = 1.5, keys = { { 0, "agachar" }, { 0.25, "topete", "estalo" }, { 0.8, "topete" }, { 1.0, "pose_josuke", "estalo" }, { 1.35, "pose_josuke" }, { 1.5, "guarda", "suave" } } }
C.despertar_KILLER_QUEEN = { dur = 1.6, keys = { { 0, "pose_kira" }, { 0.3, "pose_kira" }, { 0.55, "detonar", "estalo" }, { 1.0, "detonar" }, { 1.2, "pose_kira", "estalo" }, { 1.45, "pose_kira" }, { 1.6, "guarda", "suave" } } }
C.stand_ruge = { dur = 1.5, keys = { { 0, "cruzado_flutua" }, { 0.3, "stand_ruge", "estalo" }, { 1.2, "stand_ruge" }, { 1.5, "cruzado_flutua", "suave" } } }

function Poses.clipe(nome: string?)
	if not nome then
		return nil
	end
	return C[nome]
end

-- suavizações
local function ease(nome: string?, a: number): number
	if nome == "saida" then
		return 1 - (1 - a) * (1 - a)
	elseif nome == "entrada" then
		return a * a
	elseif nome == "suave" then
		return 0.5 - math.cos(a * math.pi) * 0.5
	elseif nome == "estalo" then
		-- passa um pouco do ponto e volta (golpe "estalado")
		local c1, c3 = 1.9, 2.9
		return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
	end
	return a
end
Poses.ease = ease

-- amostra um clipe no tempo t: devolve { junta = {x,y,z} } (graus) e o giro do Root (graus)
function Poses.amostrar(clipe: any, t: number): ({ [string]: { number } }, number)
	local keys = clipe.keys
	local n = #keys
	local resultado: { [string]: { number } } = {}
	if n == 0 then
		return resultado, 0
	end
	local a, b = keys[1], keys[1]
	if t >= keys[n][1] then
		a, b = keys[n], keys[n]
	else
		for i = 1, n - 1 do
			if t >= keys[i][1] and t < keys[i + 1][1] then
				a, b = keys[i], keys[i + 1]
				break
			end
		end
	end
	local pa = if type(a[2]) == "table" then a[2] else (P[a[2]] or P.neutro)
	local pb = if type(b[2]) == "table" then b[2] else (P[b[2]] or P.neutro)
	local f = 1
	if b[1] > a[1] then
		f = ease(b[3], math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1))
	end
	for k in Poses.JUNTAS do
		local va = pa[k]
		local vb = pb[k]
		if va or vb then
			va = va or { 0, 0, 0 }
			vb = vb or { 0, 0, 0 }
			resultado[k] = { va[1] + (vb[1] - va[1]) * f, va[2] + (vb[2] - va[2]) * f, va[3] + (vb[3] - va[3]) * f }
		end
	end
	local giro = 0
	if clipe.giro then
		local g = clipe.giro
		local tt = t
		if clipe.giroLoop then
			tt = t % g[#g][1]
		end
		for i = 1, #g - 1 do
			if tt >= g[i][1] and tt <= g[i + 1][1] then
				local ff = (tt - g[i][1]) / math.max(1e-3, g[i + 1][1] - g[i][1])
				giro = g[i][2] + (g[i + 1][2] - g[i][2]) * ff
				break
			end
		end
		if tt > g[#g][1] then
			giro = g[#g][2]
		end
	end
	return resultado, giro
end

-- barragem: braços alternando bem rápido (com um pouco de bagunça para parecer "mil socos")
function Poses.barragem(t: number, semente: number): { [string]: { number } }
	local fase = math.floor(t / 0.065)
	local lado = fase % 2
	local r = math.sin((fase + semente) * 12.9898) * 43758.5453
	r = r - math.floor(r)
	local ex, rec = "soco_e", "soco_d"
	local base = P.soco_e
	if lado == 1 then
		base = P.soco_d
	end
	local p = {}
	for k, v in base do
		p[k] = { v[1], v[2], v[3] }
	end
	-- o braço que não está socando volta
	if lado == 0 then
		p.RS = { 50, 0, 20 }
		p.RE = { 116, 0, 0 }
	else
		p.LS = { 50, 0, -20 }
		p.LE = { 116, 0, 0 }
	end
	local braco = if lado == 0 then "LS" else "RS"
	p[braco] = { 82 + r * 22, 0, (r - 0.5) * 36 }
	p.Waist = { -10, (if lado == 0 then -18 else 18) + (r - 0.5) * 10, 0 }
	p.Neck = { -6, 0, 0 }
	local _ = ex
	local _ = rec
	return p
end

-- estocadas da sombrinha (o braço direito vai e volta)
function Poses.estocadas(t: number): { [string]: { number } }
	local fase = (t % 0.085) / 0.085
	local f = if fase < 0.45 then fase / 0.45 else 1 - (fase - 0.45) / 0.55
	local a, b = P.estocada_carrega, P.estocada
	local p = {}
	for k in Poses.JUNTAS do
		local va = a[k] or { 0, 0, 0 }
		local vb = b[k] or { 0, 0, 0 }
		if a[k] or b[k] then
			p[k] = { va[1] + (vb[1] - va[1]) * f, va[2] + (vb[2] - va[2]) * f, va[3] + (vb[3] - va[3]) * f }
		end
	end
	return p
end

return Poses
