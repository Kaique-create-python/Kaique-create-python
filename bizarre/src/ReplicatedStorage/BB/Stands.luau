-- BIZARRE BATTLEGROUNDS :: os Stands (JoJo's Bizarre Adventure, partes 3 e 4)
-- O corpo é R6 com roupa e acessórios do catálogo do Roblox (itens que a comunidade fez com o
-- nome de cada Stand). Se algum item sair do ar, o jogo monta sem ele.

local RGB = Color3.fromRGB

local Stands = {}

Stands.ORDEM = { "STAR_PLATINUM", "THE_WORLD", "MAGICIANS_RED", "SILVER_CHARIOT", "CRAZY_DIAMOND", "KILLER_QUEEN" }

-- status oficiais dos Stands: Poder, Velocidade, Alcance, Resistência, Precisão, Potencial
Stands.STATUS = { "Poder", "Velocidade", "Alcance", "Resistência", "Precisão", "Potencial" }

Stands.LISTA = {
	STAR_PLATINUM = {
		id = "STAR_PLATINUM",
		nome = "STAR PLATINUM",
		usuario = "Jotaro Kujo",
		parte = "Parte 3",
		titulo = "Stardust Crusaders",
		tipo = "Força e precisão",
		dificuldade = 1,
		desc = "O Stand do Jotaro: força e velocidade absurdas, precisão de microscópio. Rajada de ORA, o Star Finger e, desperto, PARA O TEMPO por alguns segundos.",
		stats = { "A", "A", "C", "A", "A", "A" },
		cor = RGB(110, 70, 190),
		cor2 = RGB(240, 196, 70),
		corPernas = RGB(70, 46, 140),
		olhos = RGB(120, 230, 255),
		aura = RGB(150, 110, 255),
		m1 = "socos",
		grito = "ORA",
		golpes = { "STAR_PLATINUM_1", "STAR_PLATINUM_2", "STAR_PLATINUM_3", "STAR_PLATINUM_4" },
		ult = "STAR_PLATINUM_ULT",
		passiva = { nome = "Precisão", desc = "Os socos do Stand acertam um pouco mais longe.", alcanceExtra = 1 },
		visual = {
			camisa = 8207681025,
			calca = 99443129568234,
			acessorios = {
				cabelo = { 13500380465 },
				rosto = { 13954785403 },
				ombro = { 82679306599464, 124304749353974 },
				pescoco = { 101326124255429 },
				cintura = { 103316149282628 },
			},
			pele = RGB(118, 86, 196),
			escala = 1.14,
		},
	},
	THE_WORLD = {
		id = "THE_WORLD",
		nome = "THE WORLD",
		usuario = "DIO",
		parte = "Parte 3",
		titulo = "Za Warudo",
		tipo = "Tempo",
		dificuldade = 3,
		desc = "O Stand do DIO: rajada de MUDA, facas que voam e o poder de PARAR O TEMPO. Desperto, o tempo para por 5 segundos... e um ROLO COMPRESSOR cai do céu.",
		stats = { "A", "A", "C", "A", "B", "B" },
		cor = RGB(236, 192, 52),
		cor2 = RGB(60, 170, 110),
		corPernas = RGB(200, 150, 30),
		olhos = RGB(255, 80, 80),
		aura = RGB(255, 210, 70),
		m1 = "socos",
		grito = "MUDA",
		golpes = { "THE_WORLD_1", "THE_WORLD_2", "THE_WORLD_3", "THE_WORLD_4" },
		ult = "THE_WORLD_ULT",
		passiva = { nome = "Vampiro", desc = "Recupera um pouco de vida a cada golpe que acerta.", rouboVida = 0.12 },
		visual = {
			camisa = 14315350034,
			calca = 14315360712,
			acessorios = {
				chapeu = { 18448999610 },
				ombro = { 88397065251498, 71665350650293 },
				costas = { 94876676675745 },
			},
			pele = RGB(234, 194, 70),
			escala = 1.16,
		},
	},
	MAGICIANS_RED = {
		id = "MAGICIANS_RED",
		nome = "MAGICIAN'S RED",
		usuario = "Muhammad Avdol",
		parte = "Parte 3",
		titulo = "Crossfire Hurricane",
		tipo = "Fogo",
		dificuldade = 2,
		desc = "O Stand com cabeça de pássaro do Avdol: controla o fogo. Ankhs de fogo (Crossfire Hurricane), cordas de fogo (Red Bind) e chamas que derretem tudo.",
		stats = { "B", "B", "C", "B", "C", "D" },
		cor = RGB(214, 70, 40),
		cor2 = RGB(250, 196, 60),
		corPernas = RGB(170, 50, 30),
		olhos = RGB(255, 236, 140),
		aura = RGB(255, 120, 40),
		m1 = "fogo",
		grito = "FOGO",
		golpes = { "MAGICIANS_RED_1", "MAGICIANS_RED_2", "MAGICIANS_RED_3", "MAGICIANS_RED_4" },
		ult = "MAGICIANS_RED_ULT",
		passiva = { nome = "Calor", desc = "Golpes de fogo queimam por alguns segundos.", queima = true },
		visual = {
			camisa = 4926949609,
			acessorios = {
				chapeu = { 83500869419407 },
				pescoco = { 79915463608141 },
			},
			pele = RGB(204, 78, 44),
			pernas = RGB(150, 46, 30),
			escala = 1.12,
			fogo = true,
		},
	},
	SILVER_CHARIOT = {
		id = "SILVER_CHARIOT",
		nome = "SILVER CHARIOT",
		usuario = "Jean Pierre Polnareff",
		parte = "Parte 3",
		titulo = "O Cavaleiro de Prata",
		tipo = "Velocidade",
		dificuldade = 2,
		desc = "O cavaleiro de armadura do Polnareff, com rapieira. Estocadas rapidíssimas, lâmina que voa, defesa que devolve tiros e o ARMOR OFF: tira a armadura e fica muito mais rápido.",
		stats = { "C", "A", "C", "B", "B", "C" },
		cor = RGB(196, 202, 214),
		cor2 = RGB(90, 150, 220),
		corPernas = RGB(150, 156, 170),
		olhos = RGB(120, 220, 255),
		aura = RGB(170, 210, 255),
		m1 = "rapieira",
		grito = "HORA",
		golpes = { "SILVER_CHARIOT_1", "SILVER_CHARIOT_2", "SILVER_CHARIOT_3", "SILVER_CHARIOT_4" },
		ult = "SILVER_CHARIOT_ULT",
		passiva = { nome = "Esgrima", desc = "Anda 8% mais rápido.", multVelocidade = 1.08 },
		visual = {
			camisa = 4931585172,
			calca = 4931585546,
			acessorios = {
				chapeu = { 113868357803510 },
				ombro = { 103309161493468, 133335576808982 },
			},
			pele = RGB(200, 206, 218),
			escala = 1.1,
			arma = "rapieira",
		},
	},
	CRAZY_DIAMOND = {
		id = "CRAZY_DIAMOND",
		nome = "CRAZY DIAMOND",
		usuario = "Josuke Higashikata",
		parte = "Parte 4",
		titulo = "Diamond is Unbreakable",
		tipo = "Restauração",
		dificuldade = 2,
		desc = "O Stand do Josuke, de Morioh: rajada de DORA e o poder de CONSERTAR tudo o que quebra... inclusive em cima dos inimigos, que ficam presos dentro da parede. (Como na história, ele não cura o próprio usuário.)",
		stats = { "A", "A", "D", "B", "B", "C" },
		cor = RGB(236, 150, 196),
		cor2 = RGB(110, 220, 230),
		corPernas = RGB(200, 110, 170),
		olhos = RGB(120, 240, 255),
		aura = RGB(255, 160, 220),
		m1 = "socos",
		grito = "DORA",
		golpes = { "CRAZY_DIAMOND_1", "CRAZY_DIAMOND_2", "CRAZY_DIAMOND_3", "CRAZY_DIAMOND_4" },
		ult = "CRAZY_DIAMOND_ULT",
		passiva = { nome = "Diamante", desc = "Leva 8% menos dano.", multDanoRecebido = 0.92 },
		visual = {
			camisa = 5406872463,
			calca = 5406873436,
			acessorios = {
				chapeu = { 78341194178472 },
				ombro = { 88064969891275, 116859385127759 },
				cintura = { 112760404661203 },
			},
			pele = RGB(236, 156, 200),
			escala = 1.14,
		},
	},
	KILLER_QUEEN = {
		id = "KILLER_QUEEN",
		nome = "KILLER QUEEN",
		usuario = "Yoshikage Kira",
		parte = "Parte 4",
		titulo = "Bites the Dust",
		tipo = "Bombas",
		dificuldade = 3,
		desc = "O Stand do Kira: tudo o que ele toca vira bomba. Primeira bomba, o tanquinho Sheer Heart Attack que persegue e, desperto, BITES THE DUST: o tempo volta e quem te bateu explode.",
		stats = { "A", "B", "D", "B", "B", "A" },
		cor = RGB(226, 168, 214),
		cor2 = RGB(232, 190, 70),
		corPernas = RGB(170, 120, 170),
		olhos = RGB(255, 80, 120),
		aura = RGB(240, 140, 220),
		m1 = "socos",
		grito = "KQ",
		golpes = { "KILLER_QUEEN_1", "KILLER_QUEEN_2", "KILLER_QUEEN_3", "KILLER_QUEEN_4" },
		ult = "KILLER_QUEEN_ULT",
		passiva = { nome = "Detonador", desc = "O 4º soco do combo explode.", m1Explode = true },
		visual = {
			camisa = 4981332469,
			calca = 4988598681,
			acessorios = {
				chapeu = { 135336250229496 },
				ombro = { 130983249076976, 120276690488609 },
				cintura = { 74346113756989 },
			},
			pele = RGB(228, 176, 216),
			escala = 1.12,
		},
	},
}

function Stands.get(id: string?)
	if not id then
		return nil
	end
	return Stands.LISTA[id]
end

function Stands.valido(id: any): boolean
	return type(id) == "string" and Stands.LISTA[id] ~= nil
end

function Stands.padrao(): string
	return Stands.ORDEM[1]
end

-- todos os IDs do catálogo de um Stand (para conferir e pré-carregar)
function Stands.itens(s: any): { number }
	local l = {}
	local v = s.visual
	if v.camisa then
		table.insert(l, v.camisa)
	end
	if v.calca then
		table.insert(l, v.calca)
	end
	for _, lista in v.acessorios or {} do
		for _, id in lista do
			table.insert(l, id)
		end
	end
	return l
end

return Stands
