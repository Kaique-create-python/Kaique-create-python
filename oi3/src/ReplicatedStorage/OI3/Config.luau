-- OI3 :: configurações gerais do jogo (compartilhado entre servidor e cliente)

local Config = {}

Config.JOGO = "OI3"
Config.REVISAO = "AJUSTE-11"
Config.DONO_USERID = 1357078972
-- AJUSTE-10: outros ADMs (UserId). O dono já é ADM; ele também pode dar ADM na hora pelo painel.
Config.ADMINS = {}

-- Chave do DataStore (NUNCA trocar: troca apagaria o progresso salvo)
Config.DATASTORE = "OI3_Jogadores_v1"

-- Configurações padrão do jogador
Config.PADRAO = {
	musica = 0.7, -- 0..1 ambiente/trilha
	efeitos = 0.9, -- 0..1 efeitos sonoros
	vozes = 1.0, -- 0..1 falas
	legendas = true,
	efeitosLeves = false, -- modo leve para celular fraco
	brilho = 0, -- -0.1 .. 0.3 (ajuste de tela)
	tremor = true, -- tremor de câmera nas cenas
}

Config.LIMITES = {
	brilhoMin = -0.1,
	brilhoMax = 0.3,
}

-- Limpa/valida configurações vindas do jogador ou do DataStore
function Config.sanitizarConfig(v: any): { [string]: any }
	local out = table.clone(Config.PADRAO) :: { [string]: any }
	if type(v) ~= "table" then
		return out
	end
	for k, padrao in Config.PADRAO :: { [string]: any } do
		local x = v[k]
		if type(x) == type(padrao) then
			if type(x) == "number" then
				if x ~= x then
					continue -- NaN
				end
				if k == "brilho" then
					x = math.clamp(x, Config.LIMITES.brilhoMin, Config.LIMITES.brilhoMax)
				else
					x = math.clamp(x, 0, 1)
				end
			end
			out[k] = x
		end
	end
	return out
end

-- AJUSTE-6: os personagens são avatares do Roblox montados SÓ com itens do catálogo (nada modelado).
-- Visual igual à imagem dos criadores. rosto = rosto clássico do Roblox; rostoAcessorio = rosto feito
-- por usuários (acessório de rosto, funciona em R6). pele = cor do corpo (amarelo clássico).
Config.PELE = Color3.fromRGB(245, 205, 48)
Config.ROUPAS = {
	KE = { camisa = 11936840903, calca = 2364049062, cabelo = { 103171837469465 }, rostoAcessorio = { 84594171427321 }, escala = 0.9 },
	NI = { camisa = 6564988672, calca = 6521541544, cabelo = { 118626986786259 }, chapeu = { 129746506894352 }, rostoAcessorio = { 123099866795854 }, escala = 0.88 },
	ME = { camisa = 8128877497, calca = 3173277543, cabelo = { 130609450737661 }, rostoAcessorio = { 71785971768993 }, escala = 0.9 },
	VO = { camisa = 15287605063, calca = 11821073808, cabelo = { 137342192749534 }, rosto = 144075659, escala = 1.12 },
	-- AJUSTE-8: a cena final (a mulher e as duas crianças que o avô "ajuda") — só itens do catálogo
	MU = { camisa = 89445375743259, calca = 11256860860, cabelo = { 90520217081274 }, rosto = 144075659, escala = 1.05 },
	C1 = { camisa = 83999947073729, calca = 4526708605, cabelo = { 123627412625874 }, rosto = 144075659, escala = 0.82 },
	C2 = { camisa = 7070736405, calca = 15317825191, cabelo = { 100241424894087 }, rosto = 144075659, escala = 0.78 },
	-- AJUSTE-9: a sombra agora é um MONSTRO grotesco, só com itens do catálogo (corpo R15):
	-- "Tall Thin Scary Smile Monster" (alto, magro, todo preto, sorriso cheio de dentes e olhos brancos),
	-- "Creepy Black Abnormal Arms" (braços extras saindo das costas) e "Black Bone Spine" (espinha para fora).
	-- Se o catálogo falhar, volta o corpo antigo (avatar padrão todo preto, escala 1.42).
	CRIATURA = {
		r15 = true,
		pele = Color3.fromRGB(6, 6, 8),
		semRosto = true,
		cabeca = 121300117934913,
		torso = 80168481216504,
		bracoE = 96763870489127,
		bracoD = 72642274719223,
		pernaE = 130042895811873,
		pernaD = 71513352115673,
		costas = { 138093012499102, 135293618169318 },
		altura = 8.4, -- em pé (andando curvado fica mais baixo)
		escala = 1.42, -- só para o corpo reserva (R6)
	},
}
-- AJUSTE-10: monstros da internet (modelos grátis do Creator Store). Para valerem, o dono do jogo toca em
-- "Obter" na página de cada um (create.roblox.com/store/asset/<id>). Os scripts de dentro são apagados.
Config.MONSTROS_INTERNET = {
	{ id = 84937636042899, nome = "Magrelo de braços longos" },
	{ id = 15020057104, nome = "Wendigo (caveira de cervo)" },
	{ id = 15595921840, nome = "Pele-branca (caveira)" },
}
-- AJUSTE-11: o monstro principal é o Wendigo (quando carrega); no esconde-esconde fica a sombra do
-- catálogo (a do AJUSTE-9), como os criadores pediram
Config.MONSTRO_PRINCIPAL = "15020057104"
Config.MONSTRO_ESCONDE = "catalogo"
-- AJUSTE-7: rostos de reação (itens do catálogo) trocados na cutscene: medo, risada, nervoso.
-- Fora dessas reações cada personagem usa o rosto dele.
Config.ROSTOS_REACAO = {
	-- AJUSTE-8: rostos "só da frente" (olhos e boca, sem casco de cabeça), que aparecem na cabeça R6
	medo = 14514324629, -- Mortified Face (3D)
	rindo = 92888146308813, -- Blushing Happy Smile
	nervoso = 140691530205460, -- Nervous 3D Face
	chorando = 12846708960, -- Cute Crying 3D Face
}
Config.REACOES = { medo = "medo", grito = "medo", assustado = "medo", rindo = "rindo", nervoso = "nervoso", chorando = "chorando", triste = "chorando" }

-- Créditos oficiais (fornecidos pelos criadores)
Config.CREDITOS = {
	titulo = "CURADORES",
	pessoas = {
		{ nome = "boo_amg", funcao = "Roteiro, falas, história e design dos modelos." },
		{ nome = "Prahimer", funcao = "Animações, código, modelagem dos modelos, sons e efeitos sonoros." },
	},
	nota = "Vozes provisórias geradas com ElevenLabs (elevenlabs.io).",
}

-- Paleta (tons frios e sujos, com um vermelho de destaque)
Config.CORES = {
	fundo = Color3.fromRGB(9, 9, 12),
	painel = Color3.fromRGB(16, 15, 19),
	borda = Color3.fromRGB(92, 78, 62),
	texto = Color3.fromRGB(232, 226, 214),
	textoFraco = Color3.fromRGB(160, 152, 140),
	destaque = Color3.fromRGB(176, 38, 38),
	destaqueClaro = Color3.fromRGB(214, 74, 64),
	ouro = Color3.fromRGB(176, 142, 86),
	ok = Color3.fromRGB(96, 168, 112),
}

-- Multiplayer
Config.SALA = {
	minimoJogadores = 2,
	maximoJogadores = 3, -- três crianças
	contagem = 5, -- segundos de contagem quando todos estão prontos
	atrasoInicio = 2.5, -- segundos entre o aviso e o começo sincronizado
}

return Config
