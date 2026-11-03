-- BIZARRE BATTLEGROUNDS :: os Stands (todos originais)
-- Igual na história de onde vem a ideia, cada Stand tem nome de música. Aqui são estilos de música
-- brasileira. O visual usa partes do catálogo do Roblox (IDs), recoloridas pelo jogo.

local RGB = Color3.fromRGB

local Stands = {}

Stands.ORDEM = { "MARACATU", "BOSSA_NOVA", "FREVO", "AXE", "CHORINHO", "FUNK" }

-- corpos musculosos do catálogo (UGC); se algum sair do ar, o jogo usa o próximo da lista
local CORPOS = {
	bombado = { torso = 80708935200794, bracoE = 126958744062550, bracoD = 138928224263888, pernaE = 117030322057421, pernaD = 91241816366267, cabeca = 99607483795212 },
	super = { torso = 100146285479644, bracoE = 78960847770658, bracoD = 118816811026200, pernaE = 137006374450327, pernaD = 127388639501333, cabeca = 99631456951546 },
	musculoso = { torso = 123186912342533, bracoE = 97732771626481, bracoD = 120497948437793, pernaE = 139796633278134, pernaD = 75668276044785, cabeca = 92296656165419 },
	guerreiro = { torso = 83993112608346, bracoE = 82163482912429, bracoD = 96755894254359, pernaE = 123686043267975, pernaD = 76240159383172, cabeca = 117769135104789 },
	esguio = { torso = 81799656366680, bracoE = 75481733318651, bracoD = 84448938704565, pernaE = 133196756571214, pernaD = 93903398077975, cabeca = 84434933829864 },
	forte = { torso = 139581879935814, bracoE = 126754023791812, bracoD = 122802749996325, pernaE = 76872168168398, pernaD = 79323396827336, cabeca = 79912113908248 },
	heroi = { torso = 85419867880889, bracoE = 86308698836302, bracoD = 117011441543187, pernaE = 121874212334819, pernaD = 92627825073172, cabeca = 84496396294002 },
}
Stands.CORPOS = CORPOS

Stands.LISTA = {
	MARACATU = {
		id = "MARACATU",
		nome = "MARACATU",
		titulo = "Punho dos Tambores",
		tipo = "Força",
		dificuldade = 1,
		desc = "Um Stand enorme que bate no ritmo dos tambores. Socos pesados, rajadas e terremotos. Ótimo para começar.",
		cor = RGB(64, 54, 178),
		cor2 = RGB(246, 196, 44),
		corPernas = RGB(40, 34, 120),
		olhos = RGB(255, 226, 92),
		aura = RGB(122, 110, 255),
		m1 = "socos",
		grito = "TUM! TUM! TUM!",
		golpes = { "MARACATU_1", "MARACATU_2", "MARACATU_3", "MARACATU_4" },
		ult = "MARACATU_ULT",
		passiva = { nome = "Couro de Alfaia", desc = "Leva 10% menos dano.", multDanoRecebido = 0.9 },
		visual = {
			corpos = { "bombado", "forte", "heroi" },
			acessorios = { 117863952882880 }, -- cocar de penas laranja
			escala = { altura = 1.12, largura = 1.08, profundidade = 1.05, cabeca = 1 },
			olhos = true,
		},
	},
	BOSSA_NOVA = {
		id = "BOSSA_NOVA",
		nome = "BOSSA NOVA",
		titulo = "O Compasso Dourado",
		tipo = "Tempo",
		dificuldade = 3,
		desc = "Um Stand dourado e elegante que mexe no tempo: aparece nas suas costas, faz o golpe ecoar e, desperto, PARA O TEMPO.",
		cor = RGB(236, 186, 40),
		cor2 = RGB(36, 168, 160),
		corPernas = RGB(196, 146, 26),
		olhos = RGB(80, 255, 236),
		aura = RGB(255, 214, 80),
		m1 = "chutes",
		grito = "TIC-TAC!",
		golpes = { "BOSSA_NOVA_1", "BOSSA_NOVA_2", "BOSSA_NOVA_3", "BOSSA_NOVA_4" },
		ult = "BOSSA_NOVA_ULT",
		passiva = { nome = "Swing", desc = "Recargas 10% mais rápidas.", multRecarga = 0.9 },
		visual = {
			corpos = { "guerreiro", "musculoso", "heroi" },
			acessorios = { 14012017490, 13327536349 }, -- chapéu fedora e máscara veneziana
			escala = { altura = 1.1, largura = 1, profundidade = 1, cabeca = 1 },
			olhos = false,
		},
	},
	FREVO = {
		id = "FREVO",
		nome = "FREVO",
		titulo = "A Sombrinha Veloz",
		tipo = "Velocidade",
		dificuldade = 2,
		desc = "Rápido e acrobático, luta com uma sombrinha afiada: estocadas, giros que devolvem projéteis e voos com mergulho.",
		cor = RGB(232, 44, 70),
		cor2 = RGB(36, 200, 96),
		corPernas = RGB(40, 120, 230),
		olhos = RGB(255, 248, 120),
		aura = RGB(255, 90, 120),
		m1 = "sombrinha",
		grito = "ALA-LAÔ!",
		golpes = { "FREVO_1", "FREVO_2", "FREVO_3", "FREVO_4" },
		ult = "FREVO_ULT",
		passiva = { nome = "Passo Ligeiro", desc = "Anda 8% mais rápido.", multVelocidade = 1.08 },
		visual = {
			corpos = { "esguio", "guerreiro", "musculoso" },
			acessorios = { 123031145668425 }, -- cocar de carnaval
			escala = { altura = 1.08, largura = 0.95, profundidade = 0.95, cabeca = 1 },
			olhos = true,
			arma = "sombrinha",
		},
	},
	AXE = {
		id = "AXE",
		nome = "AXÉ",
		titulo = "O Sol da Bahia",
		tipo = "Fogo",
		dificuldade = 2,
		desc = "Pura energia de fogo: bolas de fogo, lança-chamas, uma onda de trio elétrico e, desperto, um SOL inteiro caindo.",
		cor = RGB(255, 112, 28),
		cor2 = RGB(255, 214, 60),
		corPernas = RGB(196, 40, 22),
		olhos = RGB(255, 255, 210),
		aura = RGB(255, 140, 40),
		m1 = "fogo",
		grito = "SOBE, SOL!",
		golpes = { "AXE_1", "AXE_2", "AXE_3", "AXE_4" },
		ult = "AXE_ULT",
		passiva = { nome = "Calor", desc = "Golpes de fogo queimam um pouco por 3 s.", queima = true },
		visual = {
			corpos = { "super", "bombado", "heroi" },
			acessorios = { 125093887001578, 84965512650204 }, -- auréola dourada e asas vermelhas
			escala = { altura = 1.1, largura = 1.05, profundidade = 1.05, cabeca = 1 },
			olhos = true,
			fogo = true,
		},
	},
	CHORINHO = {
		id = "CHORINHO",
		nome = "CHORINHO",
		titulo = "O Remendo",
		tipo = "Restauração",
		dificuldade = 2,
		desc = "Conserta tudo o que quebra... inclusive EM CIMA dos inimigos. Quanto mais destruído o mapa, mais forte ele fica. Também se cura.",
		cor = RGB(255, 132, 196),
		cor2 = RGB(150, 236, 255),
		corPernas = RGB(214, 88, 160),
		olhos = RGB(160, 255, 255),
		aura = RGB(255, 160, 220),
		m1 = "cristal",
		grito = "VOLTA PRO LUGAR!",
		golpes = { "CHORINHO_1", "CHORINHO_2", "CHORINHO_3", "CHORINHO_4" },
		ult = "CHORINHO_ULT",
		passiva = { nome = "Saudade", desc = "Cura 1 de vida por segundo fora de combate desde cedo.", regenRapida = true },
		visual = {
			corpos = { "musculoso", "heroi", "guerreiro" },
			acessorios = { 7331284875 }, -- coroa de cristais rosa
			escala = { altura = 1.1, largura = 1, profundidade = 1, cabeca = 1 },
			olhos = true,
			cristais = true,
		},
	},
	FUNK = {
		id = "FUNK",
		nome = "FUNK",
		titulo = "O Paredão do Grave",
		tipo = "Som",
		dificuldade = 1,
		desc = "O grave que derruba prédio: empurra todo mundo longe, quebra vidros, levanta um paredão de caixas de som e faz um BAILE que treme o mapa.",
		cor = RGB(130, 46, 220),
		cor2 = RGB(36, 36, 44),
		corPernas = RGB(28, 26, 36),
		olhos = RGB(80, 255, 140),
		aura = RGB(160, 80, 255),
		m1 = "grave",
		grito = "TUTS TUTS!",
		golpes = { "FUNK_1", "FUNK_2", "FUNK_3", "FUNK_4" },
		ult = "FUNK_ULT",
		passiva = { nome = "Batida Pesada", desc = "O 4º golpe do combo empurra 25% mais longe.", empurraoFinal = 1.25 },
		visual = {
			corpos = { "forte", "bombado", "super" },
			acessorios = { 81576078203849, 124853841101197 }, -- fone roxo e ombreira de espinhos
			escala = { altura = 1.12, largura = 1.1, profundidade = 1.05, cabeca = 1 },
			olhos = true,
			caixasDeSom = true,
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

return Stands
