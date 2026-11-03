-- BIZARRE BATTLEGROUNDS :: todos os golpes (dados). O servidor executa, o cliente anima.
-- Tempos em segundos a partir do começo do golpe. "frente" = distância do centro da caixa à frente.
-- Tipos: golpe, barragem, projetil, area, investida, agarrar, contra, teleporte, cura, especial.

local V = Vector3.new

local G = {}

----------------------------------------------------------------------------------------------- MARACATU
G.MARACATU_1 = {
	nome = "Batuque",
	desc = "O Stand vai na frente e solta uma chuva de socos no ritmo do tambor.",
	tipo = "barragem",
	cd = 12,
	trava = 1.75,
	andar = 0.3,
	alcance = 8,
	standModo = "frente",
	animU = "comando_aponta",
	animS = "barragem",
	inicio = 0.18,
	fim = 1.45,
	intervalo = 0.09,
	onomatopeia = "TUM TUM TUM!",
	hit = { dano = 0.95, atordoar = 0.42, caixa = V(6.5, 6.5, 7.5), frente = 5, empurrar = { frente = 5, cima = 0, dur = 0.08 }, som = "soco_rapido", vfx = "barragem" },
	final = { t = 1.52, dano = 5, caixa = V(7, 7, 8), frente = 5.2, empurrar = { frente = 66, cima = 22, dur = 0.24 }, ragdoll = 1.3, quebra = 2, som = "soco_forte", vfx = "impacto_forte", tremor = 0.5 },
}

G.MARACATU_2 = {
	nome = "Alfaia",
	desc = "Carrega o soco com super armadura e solta um golpe que quebra a guarda e atravessa paredes.",
	tipo = "golpe",
	cd = 14,
	trava = 0.95,
	andar = 0.1,
	alcance = 9,
	standModo = "frente",
	animU = "comando_aponta",
	animS = "soco_pesado",
	animImpacto = 0.48,
	armadura = { 0, 0.5 },
	impulsos = { { t = 0.38, frente = 46, cima = 0, dur = 0.14 } },
	onomatopeia = "DOOOM!",
	hits = {
		{ t = 0.48, dano = 14, caixa = V(7, 7, 9), frente = 5.5, empurrar = { frente = 105, cima = 26, dur = 0.3 }, ragdoll = 1.8, quebra = 3, quebraGuarda = true, som = "soco_forte", vfx = "impacto_enorme", tremor = 0.9, impactFrame = true },
	},
}

G.MARACATU_3 = {
	nome = "Terremoto",
	desc = "Pula e o Stand esmurra o chão: abre uma cratera e joga todo mundo para cima.",
	tipo = "area",
	cd = 15,
	trava = 1.05,
	andar = 0,
	alcance = 12,
	standModo = "acima",
	animU = "salto_slam",
	animS = "slam",
	animImpacto = 0.58,
	impulsos = { { t = 0.05, frente = 14, cima = 52, dur = 0.16 }, { t = 0.42, frente = 0, cima = -120, dur = 0.12 } },
	onomatopeia = "KRAKOOM!",
	areas = {
		{ t = 0.58, centro = "si", raio = 15, dano = 10, empurrar = { radial = true, frente = 28, cima = 62, dur = 0.22 }, ragdoll = 1.4, quebra = 2, raioQuebra = 17, som = "terremoto", vfx = "cratera", tremor = 0.8 },
	},
}

G.MARACATU_4 = {
	nome = "Caboclo de Lança",
	desc = "Avança como um touro; se pegar, agarra, enche de socos e joga para o alto.",
	tipo = "agarrar",
	cd = 16,
	trava = 0.55,
	andar = 0,
	alcance = 26,
	standModo = "frente",
	animU = "investida",
	animS = "agarrar",
	investida = { t = 0.06, vel = 92, dur = 0.34, caixa = V(6, 6.5, 6), frente = 3.5 },
	agarrao = {
		duracao = 1.35,
		distancia = 4.2,
		animU = "comando_cruzado",
		animS = "barragem",
		sequencia = {
			{ t = 0.15, dano = 2, som = "soco", vfx = "impacto" },
			{ t = 0.35, dano = 2, som = "soco", vfx = "impacto" },
			{ t = 0.55, dano = 2, som = "soco", vfx = "impacto" },
			{ t = 0.75, dano = 2, som = "soco", vfx = "impacto" },
		},
		final = { t = 1.1, dano = 6, empurrar = { frente = 22, cima = 88, dur = 0.24 }, ragdoll = 1.6, quebra = 1, som = "soco_forte", vfx = "impacto_forte", tremor = 0.6, animS = "uppercut" },
	},
}

G.MARACATU_ULT = {
	nome = "CORTEJO REAL",
	desc = "O Stand cresce e solta a rajada definitiva. O último soco atravessa um prédio inteiro.",
	tipo = "barragem",
	ult = true,
	cd = 1,
	trava = 3.05,
	andar = 0.15,
	alcance = 9,
	standModo = "frente",
	standEscala = 1.45,
	animU = "comando_aponta",
	animS = "barragem",
	armadura = { 0, 3.05 },
	inicio = 0.35,
	fim = 2.55,
	intervalo = 0.075,
	onomatopeia = "TUM TUM TUM TUM!",
	hit = { dano = 1.05, atordoar = 0.45, caixa = V(9, 9, 10), frente = 6.5, empurrar = { frente = 5, cima = 0, dur = 0.08 }, som = "soco_rapido", vfx = "barragem" },
	final = { t = 2.7, dano = 18, caixa = V(10, 10, 11), frente = 6.5, empurrar = { frente = 135, cima = 34, dur = 0.42 }, ragdoll = 2.3, quebra = 4, som = "explosao_grande", vfx = "impacto_enorme", tremor = 1.2, impactFrame = true },
}

----------------------------------------------------------------------------------------------- BOSSA NOVA
G.BOSSA_NOVA_1 = {
	nome = "Contratempo",
	desc = "Some e aparece nas costas do inimigo mais perto na sua frente, já chutando.",
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
	onomatopeia = "TAC!",
	hits = {
		{ t = 0.32, dano = 8, atordoar = 1, caixa = V(6, 6, 6.5), frente = 3.6, empurrar = { frente = 34, cima = 12, dur = 0.16 }, som = "chute", vfx = "impacto_dourado", tremor = 0.4 },
	},
}

G.BOSSA_NOVA_2 = {
	nome = "Lâminas Douradas",
	desc = "Lança um leque de 5 lâminas douradas.",
	tipo = "projetil",
	cd = 10,
	trava = 0.55,
	andar = 0.4,
	alcance = 70,
	standModo = "lado",
	animU = "leque",
	animS = "leque",
	animImpacto = 0.24,
	proj = { t = 0.24, n = 5, espalhar = 13, vel = 118, alcance = 95, raio = 1.6, visual = "lamina", dano = 4, atordoar = 0.5, empurrar = { frente = 10, cima = 4, dur = 0.08 }, som = "corte", somLancar = "lamina", vfx = "impacto_dourado" },
}

G.BOSSA_NOVA_3 = {
	nome = "Síncope",
	desc = "Um golpe rápido que marca o inimigo. Um segundo depois o mesmo golpe ECOA no tempo e explode.",
	tipo = "golpe",
	cd = 14,
	trava = 0.5,
	andar = 0.2,
	alcance = 8,
	standModo = "frente",
	animU = "comando",
	animS = "soco_d",
	animImpacto = 0.2,
	eco = { atraso = 1.0, dano = 8, empurrar = { frente = 52, cima = 30, dur = 0.22 }, ragdoll = 1.2, quebra = 1, som = "tempo_eco", vfx = "eco" },
	hits = {
		{ t = 0.2, dano = 6, atordoar = 0.9, caixa = V(6, 6, 7), frente = 4.5, empurrar = { frente = 8, cima = 0, dur = 0.08 }, som = "soco", vfx = "impacto_dourado", marcar = true },
	},
}

G.BOSSA_NOVA_4 = {
	nome = "Desafinado",
	desc = "Postura de contra-ataque. Se te baterem nessa hora, você aparece atrás deles e chuta para o céu.",
	tipo = "contra",
	cd = 14,
	trava = 0.85,
	andar = 0,
	alcance = 6,
	standModo = "costas",
	animU = "contra_pose",
	animS = "guarda",
	contra = { inicio = 0.04, janela = 0.8, tipos = { melee = true }, reflete = false },
	resposta = {
		teleAtras = 3.4,
		animU = "chute_alto",
		animS = "chute",
		hits = {
			{ t = 0.16, dano = 12, caixa = V(7, 7, 7), frente = 3.4, empurrar = { frente = 70, cima = 46, dur = 0.24 }, ragdoll = 1.6, quebra = 2, som = "chute", vfx = "impacto_dourado", tremor = 0.6, inbloqueavel = true },
		},
	},
}

G.BOSSA_NOVA_ULT = {
	nome = "SILÊNCIO",
	desc = "PARA O TEMPO por 4 segundos. Só você se mexe. Todo golpe dado no tempo parado chega junto quando ele volta.",
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
	tempo = { t = 0.9, duracao = 4, raio = 160 },
	onomatopeia = "...",
}

----------------------------------------------------------------------------------------------- FREVO
G.FREVO_1 = {
	nome = "Passo do Frevo",
	desc = "Avança girando a sombrinha e acerta todo mundo no caminho.",
	tipo = "investida",
	cd = 9,
	trava = 0.55,
	andar = 0,
	alcance = 24,
	standModo = "frente",
	animU = "giro",
	animS = "giro",
	investida = { t = 0.04, vel = 96, dur = 0.38, caixa = V(7, 6, 7), frente = 1.5, multi = true, intervalo = 0.12 },
	hit = { dano = 2.5, atordoar = 0.7, empurrar = { frente = 14, cima = 6, dur = 0.1 }, som = "estocada", vfx = "corte_colorido" },
	final = { t = 0.46, dano = 3, caixa = V(8, 6, 8), frente = 2, empurrar = { frente = 42, cima = 16, dur = 0.16 }, som = "chute", vfx = "impacto_colorido" },
}

G.FREVO_2 = {
	nome = "Estocada",
	desc = "Uma sequência de estocadas longas com a sombrinha; a última arremessa.",
	tipo = "barragem",
	cd = 12,
	trava = 1.25,
	andar = 0.3,
	alcance = 11,
	standModo = "frente",
	animU = "comando",
	animS = "estocadas",
	inicio = 0.15,
	fim = 0.95,
	intervalo = 0.085,
	onomatopeia = "SHK SHK SHK!",
	hit = { dano = 1.2, atordoar = 0.4, caixa = V(4, 5, 11), frente = 6.5, empurrar = { frente = 4, cima = 0, dur = 0.07 }, som = "estocada", vfx = "corte_colorido" },
	final = { t = 1.02, dano = 5, caixa = V(4.5, 5, 12), frente = 7, empurrar = { frente = 74, cima = 14, dur = 0.24 }, ragdoll = 1.2, quebra = 2, som = "corte", vfx = "impacto_colorido", tremor = 0.4 },
}

G.FREVO_3 = {
	nome = "Sombrinha Giratória",
	desc = "Gira a sombrinha na frente: segura golpes, DEVOLVE projéteis e responde com uma estocada.",
	tipo = "contra",
	cd = 13,
	trava = 1.1,
	andar = 0.35,
	alcance = 7,
	standModo = "frente",
	animU = "comando",
	animS = "gira_sombrinha",
	contra = { inicio = 0.05, janela = 1.0, tipos = { melee = true, projetil = true }, reflete = true, frenteApenas = true, continua = true },
	resposta = {
		animS = "estocada",
		hits = {
			{ t = 0.08, dano = 9, atordoar = 1.2, caixa = V(5, 6, 9), frente = 5, empurrar = { frente = 46, cima = 10, dur = 0.16 }, som = "corte", vfx = "impacto_colorido" },
		},
	},
}

G.FREVO_4 = {
	nome = "Voo da Sombrinha",
	desc = "Salta alto, plana com a sombrinha e mergulha num chute que racha o chão.",
	tipo = "especial",
	especial = "voo",
	cd = 14,
	trava = 1.25,
	andar = 0,
	alcance = 22,
	standModo = "acima",
	animU = "planar",
	animS = "planar",
	impulsos = { { t = 0.02, frente = 26, cima = 78, dur = 0.2 }, { t = 0.78, frente = 52, cima = -125, dur = 0.24 } },
	onomatopeia = "FRUUU!",
	areas = {
		{ t = 1.02, centro = "si", raio = 11, dano = 11, empurrar = { radial = true, frente = 40, cima = 40, dur = 0.2 }, ragdoll = 1.3, quebra = 2, raioQuebra = 12, som = "terremoto", vfx = "cratera", tremor = 0.6 },
	},
	animTroca = { { t = 0.75, animU = "mergulho", animS = "mergulho" } },
}

G.FREVO_ULT = {
	nome = "CARNAVAL",
	desc = "Vira um borrão colorido: pula de inimigo em inimigo acertando todos várias vezes e termina numa explosão de confete.",
	tipo = "especial",
	especial = "carnaval",
	ult = true,
	cd = 1,
	trava = 2.6,
	andar = 0,
	alcance = 60,
	standModo = "frente",
	animU = "giro",
	animS = "estocadas",
	iframes = { 0, 2.6 },
	carnaval = { raio = 60, maxAlvos = 5, golpesPorAlvo = 3, intervalo = 0.11, dano = 3.5, final = { dano = 10, empurrar = { frente = 70, cima = 46, dur = 0.24 }, ragdoll = 1.8, quebra = 2 } },
	onomatopeia = "ALA-LAÔ!!",
}

----------------------------------------------------------------------------------------------- AXÉ
G.AXE_1 = {
	nome = "Bola de Fogo",
	desc = "Uma bola de fogo que explode no impacto e queima.",
	tipo = "projetil",
	cd = 10,
	trava = 0.6,
	andar = 0.4,
	alcance = 80,
	standModo = "lado",
	animU = "lancar",
	animS = "sopro",
	animImpacto = 0.3,
	proj = {
		t = 0.3,
		n = 1,
		vel = 88,
		alcance = 115,
		raio = 2.6,
		visual = "fogo",
		somLancar = "fogo",
		explosao = { raio = 10, dano = 11, empurrar = { radial = true, frente = 55, cima = 24, dur = 0.2 }, ragdoll = 1.1, quebra = 2, som = "explosao", vfx = "explosao_fogo", queima = 3, tremor = 0.6 },
	},
}

G.AXE_2 = {
	nome = "Labareda",
	desc = "Um lança-chamas na sua frente. Quem fica nele queima.",
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
		{ t = 0.15, repetir = 10, intervalo = 0.12, centro = "si", cone = { angulo = 30, alcance = 19 }, dano = 1.15, atordoar = 0.32, empurrar = { frente = 3, cima = 0, dur = 0.06 }, queima = 2, som = nil, vfx = "brasa", quebra = 0 },
	},
}

G.AXE_3 = {
	nome = "Trio Elétrico",
	desc = "Uma parede de fogo atravessa a rua na sua frente arrastando quem estiver no caminho.",
	tipo = "especial",
	especial = "onda",
	cd = 16,
	trava = 0.8,
	andar = 0.2,
	alcance = 50,
	standModo = "frente",
	animU = "conjurar",
	animS = "sopro",
	onomatopeia = "VRUUUM!",
	onda = { t = 0.35, largura = 18, altura = 9, vel = 55, alcance = 62, visual = "parede_fogo", dano = 12, empurrar = { frente = 62, cima = 26, dur = 0.24 }, ragdoll = 1.3, quebra = 3, queima = 3, som = "fogo_grande" },
}

G.AXE_4 = {
	nome = "Fênix",
	desc = "Avança em chamas. O primeiro que pegar sobe voando.",
	tipo = "investida",
	cd = 13,
	trava = 0.6,
	andar = 0,
	alcance = 30,
	standModo = "frente",
	animU = "investida",
	animS = "uppercut",
	investida = { t = 0.05, vel = 104, dur = 0.34, caixa = V(6.5, 7, 6.5), frente = 3, rastro = "fogo" },
	hit = { dano = 9, empurrar = { frente = 16, cima = 92, dur = 0.24 }, ragdoll = 1.6, quebra = 1, queima = 3, som = "explosao", vfx = "explosao_fogo", tremor = 0.5 },
}

G.AXE_ULT = {
	nome = "SOL DO MEIO-DIA",
	desc = "Um sol nasce em cima de você e cai na frente: a maior explosão do jogo, derruba prédios.",
	tipo = "especial",
	especial = "sol",
	ult = true,
	cd = 1,
	trava = 2.2,
	andar = 0,
	alcance = 50,
	standModo = "acima",
	animU = "conjurar",
	animS = "conjurar",
	armadura = { 0, 2.2 },
	sol = { formar = 1.2, cair = 0.55, dist = 30, raio = 34, danoCentro = 30, danoBorda = 14, empurrar = { radial = true, frente = 112, cima = 52, dur = 0.32 }, ragdoll = 2.4, quebra = 5, queima = 4 },
	onomatopeia = "FWOOOOM!",
}

----------------------------------------------------------------------------------------------- CHORINHO
G.CHORINHO_1 = {
	nome = "Remendo",
	desc = "O Stand conserta o seu corpo: cura 24 de vida em 2,5 segundos.",
	tipo = "cura",
	cd = 18,
	trava = 0.8,
	andar = 0.6,
	alcance = 0,
	standModo = "costas",
	animU = "cura",
	animS = "cura",
	cura = { total = 24, dur = 2.5 },
}

G.CHORINHO_2 = {
	nome = "Estilhaços",
	desc = "Junta cacos do chão e atira em leque. Se o mapa estiver quebrado por perto, atira o DOBRO.",
	tipo = "projetil",
	cd = 10,
	trava = 0.6,
	andar = 0.4,
	alcance = 60,
	standModo = "frente",
	animU = "comando",
	animS = "leque",
	animImpacto = 0.28,
	proj = { t = 0.28, n = 6, nComDestrocos = 11, raioDestrocos = 30, espalhar = 9, vel = 112, alcance = 80, raio = 1.4, visual = "caco", dano = 3, atordoar = 0.45, empurrar = { frente = 8, cima = 3, dur = 0.08 }, som = "cristal", somLancar = "whoosh", vfx = "impacto_rosa" },
}

G.CHORINHO_3 = {
	nome = "Reconstruir",
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
	reconstruir = { t = 0.5, raio = 45, danoPreso = 12, preso = 2.0, danoPerto = 7, raioPerto = 5, semNada = { raio = 11, dano = 6, empurrar = { radial = true, frente = 42, cima = 18, dur = 0.18 } } },
}

G.CHORINHO_4 = {
	nome = "Abraço de Pedra",
	desc = "O Stand agarra e transforma o inimigo em pedra; depois estilhaça.",
	tipo = "agarrar",
	cd = 14,
	trava = 0.5,
	andar = 0,
	alcance = 7,
	standModo = "frente",
	animU = "comando",
	animS = "agarrar",
	golpeAgarra = { t = 0.22, caixa = V(6, 6.5, 7), frente = 4.2 },
	agarrao = {
		duracao = 1.6,
		distancia = 4,
		pedra = true,
		animU = "comando_aponta",
		animS = "guarda",
		sequencia = {},
		final = { t = 1.4, dano = 13, empurrar = { frente = 50, cima = 22, dur = 0.2 }, ragdoll = 1.2, quebra = 1, som = "pedra", vfx = "estilhaco", tremor = 0.6, animS = "soco_pesado" },
	},
}

G.CHORINHO_ULT = {
	nome = "SAUDADE",
	desc = "Restaura o mapa inteiro em volta, prende todos os inimigos perto em pedra e o Stand bate em cada um. Você se cura.",
	tipo = "especial",
	especial = "saudade",
	ult = true,
	cd = 1,
	trava = 2.4,
	andar = 0,
	alcance = 40,
	standModo = "acima",
	animU = "conjurar",
	animS = "conjurar",
	iframes = { 0, 2.4 },
	saudade = { raioMapa = 110, raio = 40, preso = 2.2, dano = 8, final = 10, cura = 30 },
	onomatopeia = "VOLTA!!",
}

----------------------------------------------------------------------------------------------- FUNK
G.FUNK_1 = {
	nome = "Grave",
	desc = "Um estouro de grave em cone: arremessa longe e estoura os vidros em volta.",
	tipo = "area",
	cd = 11,
	trava = 0.6,
	andar = 0.2,
	alcance = 18,
	standModo = "frente",
	animU = "sopro",
	animS = "sopro",
	animImpacto = 0.3,
	onomatopeia = "BOOOM!",
	areas = {
		{ t = 0.3, centro = "si", cone = { angulo = 34, alcance = 23 }, dano = 9, empurrar = { frente = 82, cima = 20, dur = 0.26 }, ragdoll = 1.2, quebra = 2, quebraVidroRaio = 32, som = "grave", vfx = "onda_som", tremor = 0.5 },
	},
}

G.FUNK_2 = {
	nome = "Paredão",
	desc = "Levanta um paredão de caixas de som na sua frente: segura tiros, bloqueia a passagem e empurra quem chega perto.",
	tipo = "especial",
	especial = "paredao",
	cd = 18,
	trava = 0.6,
	andar = 0.3,
	alcance = 14,
	standModo = "frente",
	animU = "conjurar",
	animS = "pisao",
	paredao = { t = 0.35, dist = 7, largura = 15, altura = 10, duracao = 5.5, pulso = 0.6, raioPulso = 13, dano = 2, empurrar = { frente = 38, cima = 10, dur = 0.12 } },
}

G.FUNK_3 = {
	nome = "Batidão",
	desc = "Três pisões que soltam anéis de som em volta. O último joga para cima.",
	tipo = "area",
	cd = 13,
	trava = 1.25,
	andar = 0.1,
	alcance = 14,
	standModo = "costas",
	animU = "pisao",
	animS = "pisao",
	onomatopeia = "TUTS TUTS TUTS!",
	areas = {
		{ t = 0.3, centro = "si", raio = 12, dano = 4, atordoar = 0.7, empurrar = { radial = true, frente = 14, cima = 6, dur = 0.1 }, som = "sub", vfx = "anel_som", tremor = 0.3 },
		{ t = 0.65, centro = "si", raio = 15, dano = 4, atordoar = 0.7, empurrar = { radial = true, frente = 16, cima = 8, dur = 0.1 }, som = "sub", vfx = "anel_som", tremor = 0.35 },
		{ t = 1.0, centro = "si", raio = 18, dano = 5, empurrar = { radial = true, frente = 22, cima = 58, dur = 0.2 }, ragdoll = 1.2, quebra = 1, raioQuebra = 12, som = "grave", vfx = "anel_som_grande", tremor = 0.6 },
	},
	animRepetir = { 0.3, 0.65, 1.0 },
}

G.FUNK_4 = {
	nome = "Pancadão",
	desc = "Uma bola de som grande e lenta que explode quando encosta em alguém.",
	tipo = "projetil",
	cd = 14,
	trava = 0.6,
	andar = 0.4,
	alcance = 60,
	standModo = "frente",
	animU = "lancar",
	animS = "soco_pesado",
	animImpacto = 0.32,
	proj = {
		t = 0.32,
		n = 1,
		vel = 46,
		alcance = 72,
		raio = 4.2,
		visual = "bola_som",
		somLancar = "sub",
		explosao = { raio = 14, dano = 13, empurrar = { radial = true, frente = 72, cima = 30, dur = 0.24 }, ragdoll = 1.4, quebra = 3, som = "grave", vfx = "explosao_som", tremor = 0.7 },
	},
}

G.FUNK_ULT = {
	nome = "BAILE",
	desc = "Um paredão gigante nasce atrás de você e o grave pulsa no ritmo: cada batida mais forte, a última destrói tudo em volta.",
	tipo = "especial",
	especial = "baile",
	ult = true,
	cd = 1,
	trava = 3.3,
	andar = 0,
	alcance = 45,
	standModo = "acima",
	animU = "pose2",
	animS = "conjurar",
	armadura = { 0, 3.3 },
	baile = { inicio = 0.6, batidas = 5, intervalo = 0.5, raio = 44, dano = 4.5, empurrarBatida = { radial = true, frente = 18, cima = 34, dur = 0.12 }, final = { dano = 15, empurrar = { radial = true, frente = 104, cima = 46, dur = 0.3 }, ragdoll = 2, quebra = 4 } },
	onomatopeia = "TUTS TUTS!!",
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

-- maior tempo de golpe dentro do golpe (para saber quando acaba)
function Golpes.duracao(g: any): number
	return g.trava or 0.5
end

return Golpes
