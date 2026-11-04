-- BIZARRE BATTLEGROUNDS :: todos os golpes (dados). O servidor executa, o cliente anima.
-- Tempos em segundos a partir do começo do golpe. "frente" = distância do centro da caixa à frente.
-- Tipos: golpe, barragem, projetil, area, investida, agarrar, contra, teleporte, cura, buff, especial.
-- "voz" = grito do Stand (ORA, MUDA, DORA, HORA...) que toca junto (quando o áudio existe).

local V = Vector3.new

local G = {}

----------------------------------------------------------------------------------------------- STAR PLATINUM
G.STAR_PLATINUM_1 = {
	nome = "ORA Rush",
	desc = "A rajada de socos mais famosa: ORA ORA ORA! O último soco arremessa.",
	tipo = "barragem",
	cd = 12,
	trava = 1.7,
	andar = 0.3,
	alcance = 8,
	standModo = "frente",
	animU = "comando_aponta",
	animS = "barragem",
	voz = "ORA",
	inicio = 0.18,
	fim = 1.45,
	intervalo = 0.085,
	onomatopeia = "ORA ORA ORA!",
	hit = { dano = 0.85, atordoar = 0.42, caixa = V(6.5, 6.5, 7.5), frente = 5.2, empurrar = { frente = 4, cima = 0, dur = 0.06 }, som = "soco_rapido", vfx = "barragem" },
	final = { t = 1.52, dano = 6, caixa = V(7, 7, 8), frente = 5.4, empurrar = { frente = 52, cima = 16, dur = 0.15 }, ragdoll = 1.1, quebra = 2, som = "soco_forte", vfx = "impacto_forte", tremor = 0.5, voz = "ORA_FINAL" },
}

G.STAR_PLATINUM_2 = {
	nome = "Star Finger",
	desc = "Os dedos do Star Platinum se esticam como uma lança e furam quem estiver na linha.",
	tipo = "golpe",
	cd = 11,
	trava = 0.65,
	andar = 0.15,
	alcance = 15,
	standModo = "frente",
	animU = "comando_aponta",
	animS = "star_finger",
	animImpacto = 0.3,
	vfxLinha = { t = 0.28, comp = 16, cor = "aura", dur = 0.3 },
	hits = {
		{ t = 0.3, dano = 10, atordoar = 0.9, caixa = V(2.8, 3.2, 16), frente = 9.5, empurrar = { frente = 30, cima = 6, dur = 0.12 }, quebra = 1, som = "corte", vfx = "impacto_forte", tremor = 0.4 },
	},
}

G.STAR_PLATINUM_3 = {
	nome = "Soco Pesado",
	desc = "Carrega com super armadura e solta um ORA que quebra a guarda e atravessa parede.",
	tipo = "golpe",
	cd = 14,
	trava = 0.9,
	andar = 0.1,
	alcance = 9,
	standModo = "frente",
	animU = "comando_aponta",
	animS = "soco_pesado",
	animImpacto = 0.46,
	armadura = { 0, 0.48 },
	impulsos = { { t = 0.36, frente = 40, cima = 0, dur = 0.12 } },
	onomatopeia = "ORAAAA!",
	voz = "ORA_FINAL",
	vozT = 0.4,
	hits = {
		{ t = 0.46, dano = 13, caixa = V(7, 7, 9), frente = 5.5, empurrar = { frente = 64, cima = 20, dur = 0.16 }, ragdoll = 1.4, quebra = 3, quebraGuarda = true, som = "soco_forte", vfx = "impacto_enorme", tremor = 0.9, impactFrame = true },
	},
}

G.STAR_PLATINUM_4 = {
	nome = "Bearing Shot",
	desc = "O Star Platinum dá um peteleco numa bolinha de metal com força de bala.",
	tipo = "projetil",
	cd = 9,
	trava = 0.45,
	andar = 0.5,
	alcance = 90,
	standModo = "lado",
	animU = "comando",
	animS = "lancar",
	animImpacto = 0.22,
	proj = { t = 0.22, n = 1, vel = 165, alcance = 110, raio = 1.1, visual = "rolamento", dano = 9, atordoar = 0.8, empurrar = { frente = 16, cima = 4, dur = 0.08 }, som = "soco_forte", somLancar = "whoosh", vfx = "impacto" },
}

G.STAR_PLATINUM_ULT = {
	nome = "STAR PLATINUM: THE WORLD",
	desc = "O Star Platinum também para o tempo! 3 segundos em que só você se mexe. Tudo o que bater chega junto quando o tempo voltar.",
	tipo = "especial",
	especial = "tempoParado",
	ult = true,
	cd = 1,
	trava = 0.9,
	andar = 0,
	alcance = 60,
	standModo = "costas",
	animU = "tempo",
	animS = "tempo",
	iframes = { 0, 0.95 },
	voz = "SP_THE_WORLD",
	vozT = 0.05,
	tempo = { t = 0.75, duracao = 3, raio = 150 },
	onomatopeia = "...",
}

----------------------------------------------------------------------------------------------- THE WORLD
G.THE_WORLD_1 = {
	nome = "MUDA Rush",
	desc = "MUDA MUDA MUDA! A rajada do DIO, e o último soco arremessa.",
	tipo = "barragem",
	cd = 12,
	trava = 1.7,
	andar = 0.3,
	alcance = 8,
	standModo = "frente",
	animU = "pose_dio",
	animS = "barragem",
	voz = "MUDA",
	inicio = 0.18,
	fim = 1.45,
	intervalo = 0.085,
	onomatopeia = "MUDA MUDA MUDA!",
	hit = { dano = 0.85, atordoar = 0.42, caixa = V(6.5, 6.5, 7.5), frente = 5, empurrar = { frente = 4, cima = 0, dur = 0.06 }, som = "soco_rapido", vfx = "barragem" },
	final = { t = 1.52, dano = 6, caixa = V(7, 7, 8), frente = 5.2, empurrar = { frente = 54, cima = 18, dur = 0.15 }, ragdoll = 1.1, quebra = 2, som = "soco_forte", vfx = "impacto_forte", tremor = 0.5, voz = "MUDA_FINAL" },
}

G.THE_WORLD_2 = {
	nome = "Facas",
	desc = "O DIO joga um leque de facas.",
	tipo = "projetil",
	cd = 10,
	trava = 0.5,
	andar = 0.4,
	alcance = 70,
	standModo = "costas",
	animU = "leque",
	animS = "s_ocioso",
	animImpacto = 0.24,
	proj = { t = 0.24, n = 5, espalhar = 9, vel = 125, alcance = 95, raio = 1.4, visual = "faca", dano = 3.6, atordoar = 0.45, empurrar = { frente = 8, cima = 2, dur = 0.06 }, som = "corte", somLancar = "lamina", vfx = "impacto_dourado" },
}

G.THE_WORLD_3 = {
	nome = "Salto no Tempo",
	desc = "Para o tempo por um instante e aparece nas costas do inimigo, já chutando.",
	tipo = "teleporte",
	cd = 12,
	trava = 0.7,
	andar = 0,
	alcance = 28,
	standModo = "frente",
	animU = "chute_alto",
	animS = "chute",
	animImpacto = 0.32,
	teleporte = { t = 0.14, alcance = 30, cone = 0.35, atras = 3.6, semAlvo = 16 },
	onomatopeia = "WRYYY!",
	hits = {
		{ t = 0.32, dano = 8, atordoar = 1, caixa = V(6, 6, 6.5), frente = 3.6, empurrar = { frente = 30, cima = 10, dur = 0.12 }, som = "chute", vfx = "impacto_dourado", tremor = 0.4 },
	},
}

G.THE_WORLD_4 = {
	nome = "Soco do Vampiro",
	desc = "Um soco carregado que quebra a guarda. O DIO suga vida de quem apanha.",
	tipo = "golpe",
	cd = 14,
	trava = 0.85,
	andar = 0.1,
	alcance = 9,
	standModo = "frente",
	animU = "pose_dio",
	animS = "soco_pesado",
	animImpacto = 0.44,
	armadura = { 0, 0.46 },
	impulsos = { { t = 0.34, frente = 38, cima = 0, dur = 0.12 } },
	onomatopeia = "MUDAAA!",
	voz = "MUDA_FINAL",
	vozT = 0.38,
	cura = { total = 6, dur = 0.5, depois = 0.45 },
	hits = {
		{ t = 0.44, dano = 12, caixa = V(7, 7, 9), frente = 5.5, empurrar = { frente = 60, cima = 18, dur = 0.15 }, ragdoll = 1.3, quebra = 3, quebraGuarda = true, som = "soco_forte", vfx = "impacto_enorme", tremor = 0.8, impactFrame = true },
	},
}

G.THE_WORLD_ULT = {
	nome = "ZA WARUDO",
	desc = "TOKI WO TOMARE! O tempo para por 5 segundos. No fim, um ROLO COMPRESSOR cai em cima do inimigo mais perto.",
	tipo = "especial",
	especial = "tempoParado",
	ult = true,
	cd = 1,
	trava = 1.05,
	andar = 0,
	alcance = 60,
	standModo = "costas",
	animU = "tempo",
	animS = "tempo",
	iframes = { 0, 1.1 },
	voz = "ZA_WARUDO",
	vozT = 0.05,
	tempo = { t = 0.95, duracao = 5, raio = 180, rolo = { antes = 1.6, raio = 34, dano = 22, empurrar = { radial = true, frente = 58, cima = 26, dur = 0.16 }, ragdoll = 1.6 } },
	onomatopeia = "ZA WARUDO!",
}

----------------------------------------------------------------------------------------------- MAGICIAN'S RED
G.MAGICIANS_RED_1 = {
	nome = "Crossfire Hurricane",
	desc = "Uma ankh de fogo que voa e explode no impacto.",
	tipo = "projetil",
	cd = 10,
	trava = 0.6,
	andar = 0.4,
	alcance = 80,
	standModo = "lado",
	animU = "lancar",
	animS = "sopro",
	animImpacto = 0.3,
	voz = "CROSSFIRE",
	vozT = 0.05,
	proj = {
		t = 0.3,
		n = 1,
		vel = 84,
		alcance = 110,
		raio = 2.6,
		visual = "ankh",
		somLancar = "fogo",
		explosao = { raio = 10, dano = 11, empurrar = { radial = true, frente = 44, cima = 18, dur = 0.14 }, ragdoll = 1, quebra = 2, som = "explosao", vfx = "explosao_fogo", queima = 3, tremor = 0.6 },
	},
}

G.MAGICIANS_RED_2 = {
	nome = "Red Bind",
	desc = "Cordas de fogo que amarram o inimigo de longe, puxam, queimam e jogam no chão.",
	tipo = "agarrar",
	cd = 15,
	trava = 0.5,
	andar = 0,
	alcance = 14,
	standModo = "frente",
	animU = "sopro",
	animS = "sopro",
	vfxLinha = { t = 0.18, comp = 16, cor = "fogo", dur = 0.35 },
	golpeAgarra = { t = 0.25, caixa = V(4.5, 5.5, 16), frente = 9 },
	agarrao = {
		duracao = 1.6,
		distancia = 5,
		fogo = true,
		animU = "sopro",
		animS = "sopro",
		sequencia = {
			{ t = 0.3, dano = 2, som = "fogo", vfx = "impacto_fogo" },
			{ t = 0.6, dano = 2, som = "fogo", vfx = "impacto_fogo" },
			{ t = 0.9, dano = 2, som = "fogo", vfx = "impacto_fogo" },
		},
		final = { t = 1.3, dano = 7, empurrar = { frente = 26, cima = 40, dur = 0.14 }, ragdoll = 1.1, quebra = 1, queima = 3, som = "explosao", vfx = "explosao_fogo", tremor = 0.5, animS = "slam" },
	},
}

G.MAGICIANS_RED_3 = {
	nome = "Tempestade de Fogo",
	desc = "Um mar de chamas na frente do Stand. Quem fica nele queima.",
	tipo = "area",
	cd = 12,
	trava = 1.4,
	andar = 0.35,
	alcance = 16,
	standModo = "frente",
	animU = "sopro",
	animS = "sopro",
	somLoop = "chama",
	vfxContinuo = { tipo = "lanca_chamas", de = 0.15, ate = 1.3 },
	areas = {
		{ t = 0.15, repetir = 10, intervalo = 0.12, centro = "si", cone = { angulo = 30, alcance = 19 }, dano = 1.1, atordoar = 0.32, empurrar = { frente = 3, cima = 0, dur = 0.05 }, queima = 2, vfx = "brasa", quebra = 0 },
	},
}

G.MAGICIANS_RED_4 = {
	nome = "Coluna de Fogo",
	desc = "Uma coluna de fogo explode do chão na sua frente e joga todo mundo para o alto.",
	tipo = "area",
	cd = 13,
	trava = 0.8,
	andar = 0.2,
	alcance = 16,
	standModo = "frente",
	animU = "conjurar",
	animS = "conjurar",
	onomatopeia = "FWOOM!",
	vfxColuna = { t = 0.2, dist = 12, raio = 7, ate = 0.5 },
	areas = {
		{ t = 0.5, centro = "frente", dist = 12, raio = 7.5, dano = 12, empurrar = { radial = true, frente = 10, cima = 66, dur = 0.14 }, ragdoll = 1.2, quebra = 2, raioQuebra = 8, queima = 3, som = "fogo_grande", vfx = "coluna_fogo", tremor = 0.6 },
	},
}

G.MAGICIANS_RED_ULT = {
	nome = "CROSSFIRE HURRICANE SPECIAL",
	desc = "Uma ankh de fogo GIGANTE nasce em cima de você e cai na frente, numa explosão que derruba prédios.",
	tipo = "especial",
	especial = "sol",
	ult = true,
	cd = 1,
	trava = 2.1,
	andar = 0,
	alcance = 50,
	standModo = "acima",
	animU = "conjurar",
	animS = "conjurar",
	armadura = { 0, 2.1 },
	voz = "CROSSFIRE",
	vozT = 0.1,
	sol = { formar = 1.1, cair = 0.5, dist = 28, raio = 30, danoCentro = 26, danoBorda = 12, empurrar = { radial = true, frente = 70, cima = 34, dur = 0.18 }, ragdoll = 1.8, quebra = 5, queima = 4, visual = "ankh" },
	onomatopeia = "FWOOOOM!",
}

----------------------------------------------------------------------------------------------- SILVER CHARIOT
G.SILVER_CHARIOT_1 = {
	nome = "Chuva de Estocadas",
	desc = "HORA HORA HORA! Estocadas de rapieira rápidas demais para ver. A última arremessa.",
	tipo = "barragem",
	cd = 11,
	trava = 1.25,
	andar = 0.3,
	alcance = 11,
	standModo = "frente",
	animU = "esgrima",
	animS = "estocadas",
	voz = "HORA",
	inicio = 0.15,
	fim = 0.95,
	intervalo = 0.08,
	onomatopeia = "HORA HORA!",
	hit = { dano = 1.1, atordoar = 0.4, caixa = V(4, 5, 11), frente = 6.5, empurrar = { frente = 4, cima = 0, dur = 0.06 }, som = "estocada", vfx = "corte_prata" },
	final = { t = 1.02, dano = 5, caixa = V(4.5, 5, 12), frente = 7, empurrar = { frente = 50, cima = 12, dur = 0.15 }, ragdoll = 1, quebra = 2, som = "corte", vfx = "impacto_prata", tremor = 0.4 },
}

G.SILVER_CHARIOT_2 = {
	nome = "Lâmina Voadora",
	desc = "A ponta da rapieira é disparada como uma flecha e atravessa todo mundo na linha.",
	tipo = "projetil",
	cd = 10,
	trava = 0.5,
	andar = 0.4,
	alcance = 90,
	standModo = "frente",
	animU = "esgrima",
	animS = "estocada",
	animImpacto = 0.22,
	proj = { t = 0.22, n = 1, vel = 150, alcance = 100, raio = 1.4, visual = "rapieira", perfura = true, dano = 9, atordoar = 0.7, empurrar = { frente = 14, cima = 3, dur = 0.08 }, som = "corte", somLancar = "lamina", vfx = "impacto_prata" },
}

G.SILVER_CHARIOT_3 = {
	nome = "Defesa da Rapieira",
	desc = "Gira a rapieira na frente: segura golpes, DEVOLVE projéteis e responde com uma estocada.",
	tipo = "contra",
	cd = 13,
	trava = 1.1,
	andar = 0.35,
	alcance = 7,
	standModo = "frente",
	animU = "esgrima",
	animS = "gira_sombrinha",
	contra = { inicio = 0.05, janela = 1.0, tipos = { melee = true, projetil = true }, reflete = true, frenteApenas = true, continua = true },
	resposta = {
		animS = "estocada",
		hits = {
			{ t = 0.08, dano = 9, atordoar = 1.2, caixa = V(5, 6, 9), frente = 5, empurrar = { frente = 34, cima = 8, dur = 0.12 }, som = "corte", vfx = "impacto_prata" },
		},
	},
}

G.SILVER_CHARIOT_4 = {
	nome = "ARMOR OFF",
	desc = "O Silver Chariot tira a armadura: por 8 segundos você fica muito mais rápido, bate mais forte e deixa imagens residuais.",
	tipo = "buff",
	cd = 22,
	trava = 0.6,
	andar = 0,
	alcance = 0,
	standModo = "frente",
	animU = "esgrima",
	animS = "conjurar",
	onomatopeia = "ARMOR OFF!",
	buff = { dur = 8, velocidade = 1.35, dano = 1.15, standSemArmadura = true },
}

G.SILVER_CHARIOT_ULT = {
	nome = "IMAGENS RESIDUAIS",
	desc = "Rápido como a luz: o Silver Chariot vira várias cópias e acerta todos os inimigos em volta várias vezes.",
	tipo = "especial",
	especial = "carnaval",
	ult = true,
	cd = 1,
	trava = 2.6,
	andar = 0,
	alcance = 60,
	standModo = "frente",
	animU = "esgrima",
	animS = "estocadas",
	iframes = { 0, 2.6 },
	voz = "HORA",
	carnaval = { raio = 60, maxAlvos = 5, golpesPorAlvo = 3, intervalo = 0.11, dano = 3.4, visual = "prata", final = { dano = 10, empurrar = { frente = 50, cima = 30, dur = 0.15 }, ragdoll = 1.4, quebra = 2 } },
	onomatopeia = "HORA HORA HORA!",
}

----------------------------------------------------------------------------------------------- CRAZY DIAMOND
G.CRAZY_DIAMOND_1 = {
	nome = "DORA Rush",
	desc = "DORARARARA! A rajada do Josuke. O último soco arremessa.",
	tipo = "barragem",
	cd = 12,
	trava = 1.7,
	andar = 0.3,
	alcance = 8,
	standModo = "frente",
	animU = "pose_josuke",
	animS = "barragem",
	voz = "DORA",
	inicio = 0.18,
	fim = 1.45,
	intervalo = 0.085,
	onomatopeia = "DORARARA!",
	hit = { dano = 0.85, atordoar = 0.42, caixa = V(6.5, 6.5, 7.5), frente = 5, empurrar = { frente = 4, cima = 0, dur = 0.06 }, som = "soco_rapido", vfx = "barragem" },
	final = { t = 1.52, dano = 6, caixa = V(7, 7, 8), frente = 5.2, empurrar = { frente = 52, cima = 16, dur = 0.15 }, ragdoll = 1.1, quebra = 2, som = "soco_forte", vfx = "impacto_rosa", tremor = 0.5, voz = "DORA_FINAL" },
}

G.CRAZY_DIAMOND_2 = {
	nome = "Disparo Restaurado",
	desc = "Junta cacos do chão e eles voam de volta para o lugar, atravessando quem estiver no caminho. Com o mapa quebrado por perto, atira o DOBRO.",
	tipo = "projetil",
	cd = 10,
	trava = 0.6,
	andar = 0.4,
	alcance = 60,
	standModo = "frente",
	animU = "pose_josuke",
	animS = "leque",
	animImpacto = 0.28,
	proj = { t = 0.28, n = 6, nComDestrocos = 11, raioDestrocos = 30, espalhar = 9, vel = 112, alcance = 80, raio = 1.4, visual = "caco", dano = 3, atordoar = 0.45, empurrar = { frente = 8, cima = 3, dur = 0.06 }, som = "cristal", somLancar = "whoosh", vfx = "impacto_rosa" },
}

G.CRAZY_DIAMOND_3 = {
	nome = "Restauração",
	desc = "Conserta tudo o que está quebrado em volta. Quem estiver no lugar fica PRESO dentro da parede.",
	tipo = "especial",
	especial = "reconstruir",
	cd = 16,
	trava = 0.9,
	andar = 0.2,
	alcance = 40,
	standModo = "acima",
	animU = "conjurar",
	animS = "conjurar",
	onomatopeia = "KRIK-KRAK!",
	reconstruir = { t = 0.5, raio = 45, danoPreso = 12, preso = 2.0, danoPerto = 7, raioPerto = 5, semNada = { raio = 11, dano = 6, empurrar = { radial = true, frente = 34, cima = 14, dur = 0.12 } } },
}

G.CRAZY_DIAMOND_4 = {
	nome = "Prisão de Pedra",
	desc = "Como fez com o Angelo: o Crazy Diamond agarra, funde o inimigo numa pedra e depois estilhaça.",
	tipo = "agarrar",
	cd = 14,
	trava = 0.5,
	andar = 0,
	alcance = 7,
	standModo = "frente",
	animU = "pose_josuke",
	animS = "agarrar",
	golpeAgarra = { t = 0.22, caixa = V(6, 6.5, 7), frente = 4.2 },
	agarrao = {
		duracao = 1.6,
		distancia = 4,
		pedra = true,
		animU = "comando_aponta",
		animS = "guarda",
		sequencia = {},
		final = { t = 1.4, dano = 13, empurrar = { frente = 40, cima = 18, dur = 0.14 }, ragdoll = 1.1, quebra = 1, som = "pedra", vfx = "estilhaco", tremor = 0.6, animS = "soco_pesado" },
	},
}

G.CRAZY_DIAMOND_ULT = {
	nome = "FÚRIA DE DIAMANTE",
	desc = "Restaura o mapa inteiro em volta, prende todos os inimigos perto em pedra e o Crazy Diamond soca cada um com DORA.",
	tipo = "especial",
	especial = "saudade",
	ult = true,
	cd = 1,
	trava = 2.4,
	andar = 0,
	alcance = 40,
	standModo = "acima",
	animU = "pose_josuke",
	animS = "conjurar",
	iframes = { 0, 2.4 },
	voz = "DORA",
	vozT = 0.9,
	saudade = { raioMapa = 110, raio = 40, preso = 2.2, dano = 9, final = 11, cura = 0 },
	onomatopeia = "DORARARA!!",
}

----------------------------------------------------------------------------------------------- KILLER QUEEN
G.KILLER_QUEEN_1 = {
	nome = "Primeira Bomba",
	desc = "A Killer Queen toca o inimigo e ele VIRA BOMBA: um segundo depois, explode.",
	tipo = "especial",
	especial = "bomba",
	cd = 12,
	trava = 0.55,
	andar = 0.2,
	alcance = 7,
	standModo = "frente",
	animU = "detonar",
	animS = "soco_d",
	animImpacto = 0.25,
	voz = "KQ_BOMBA",
	vozT = 0.6,
	bomba = { t = 0.25, caixa = V(6, 6, 7), frente = 4.2, toque = { dano = 2, atordoar = 0.5 }, atraso = 1.2, explosao = { raio = 9, dano = 13, empurrar = { radial = true, frente = 44, cima = 22, dur = 0.14 }, ragdoll = 1.2, quebra = 2, som = "explosao", vfx = "explosao_fogo", tremor = 0.6 } },
}

G.KILLER_QUEEN_2 = {
	nome = "Sheer Heart Attack",
	desc = "O tanquinho-bomba da mão esquerda: persegue o inimigo mais quente e explode. \"Olhe aqui!\"",
	tipo = "projetil",
	cd = 14,
	trava = 0.5,
	andar = 0.4,
	alcance = 60,
	standModo = "lado",
	animU = "detonar",
	animS = "lancar",
	animImpacto = 0.25,
	proj = {
		t = 0.25,
		n = 1,
		vel = 38,
		alcance = 150,
		raio = 2,
		visual = "tanque",
		guiado = 2.6,
		somLancar = "metal",
		explosao = { raio = 9, dano = 12, empurrar = { radial = true, frente = 42, cima = 26, dur = 0.14 }, ragdoll = 1.2, quebra = 2, som = "explosao", vfx = "explosao_fogo", tremor = 0.6 },
	},
}

G.KILLER_QUEEN_3 = {
	nome = "Moeda Bomba",
	desc = "Joga uma moeda que virou bomba. Explode no que encostar (ou no fim do voo).",
	tipo = "projetil",
	cd = 9,
	trava = 0.45,
	andar = 0.5,
	alcance = 50,
	standModo = "costas",
	animU = "lancar",
	animS = "s_ocioso",
	animImpacto = 0.26,
	proj = {
		t = 0.26,
		n = 1,
		vel = 72,
		alcance = 55,
		raio = 1.2,
		visual = "moeda",
		explodeNoFim = true,
		somLancar = "whoosh",
		explosao = { raio = 8, dano = 9, empurrar = { radial = true, frente = 36, cima = 18, dur = 0.12 }, ragdoll = 0.9, quebra = 2, som = "explosao", vfx = "explosao_fogo", tremor = 0.5 },
	},
}

G.KILLER_QUEEN_4 = {
	nome = "Soco Detonador",
	desc = "Um soco rápido que marca o inimigo; um instante depois a marca explode.",
	tipo = "golpe",
	cd = 12,
	trava = 0.5,
	andar = 0.2,
	alcance = 8,
	standModo = "frente",
	animU = "comando",
	animS = "soco_d",
	animImpacto = 0.2,
	eco = { atraso = 0.45, dano = 8, empurrar = { frente = 44, cima = 22, dur = 0.14 }, ragdoll = 1.1, quebra = 2, som = "explosao", vfx = "explosao_fogo" },
	hits = {
		{ t = 0.2, dano = 5, atordoar = 0.9, caixa = V(6, 6, 7), frente = 4.5, empurrar = { frente = 6, cima = 0, dur = 0.06 }, som = "soco", vfx = "impacto_rosa", marcar = true },
	},
}

G.KILLER_QUEEN_ULT = {
	nome = "BITES THE DUST",
	desc = "O tempo volta 5 segundos: você volta para onde estava, com a vida que tinha, e quem te bateu nesse tempo EXPLODE.",
	tipo = "especial",
	especial = "rebobinar",
	ult = true,
	cd = 1,
	trava = 1.2,
	andar = 0,
	alcance = 40,
	standModo = "costas",
	animU = "detonar",
	animS = "conjurar",
	iframes = { 0, 1.4 },
	voz = "BITES_THE_DUST",
	vozT = 0.05,
	rebobinar = { t = 0.7, segundos = 5, memoria = 8, raio = 60, dano = 18, empurrar = { radial = true, frente = 48, cima = 26, dur = 0.14 }, ragdoll = 1.4, quebra = 2 },
	onomatopeia = "BITES THE DUST",
}

-- utilitários --------------------------------------------------------------------------------------
local Golpes = {}
Golpes.LISTA = G

function Golpes.get(id: string?)
	if not id then
		return nil
	end
	return G[id]
end

-- o golpe do "slot" (1 a 4, ou "ult") do Stand
function Golpes.doSlot(stand: any, slot: any)
	if not stand then
		return nil, nil
	end
	if slot == "ult" then
		return G[stand.ult], stand.ult
	end
	local n = tonumber(slot)
	if not n then
		return nil, nil
	end
	local id = stand.golpes[n]
	return G[id], id
end

function Golpes.duracao(g: any): number
	return g.trava or 0.5
end

return Golpes
