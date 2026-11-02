-- OI3 :: configurações gerais do jogo (compartilhado entre servidor e cliente)

local Config = {}

Config.JOGO = "OI3"
Config.REVISAO = "AJUSTE-7"
Config.DONO_USERID = 1357078972

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
	-- a sombra do espelho: avatar padrão do Roblox, todo preto e sem rosto (aparência oficial ainda não definida)
	CRIATURA = { pele = Color3.fromRGB(4, 4, 6), semRosto = true, escala = 1.42 },
}
-- AJUSTE-7: rostos de reação (itens do catálogo) trocados na cutscene: medo, risada, nervoso.
-- Fora dessas reações cada personagem usa o rosto dele.
Config.ROSTOS_REACAO = {
	medo = 99348810187853,
	rindo = 18600770545,
	nervoso = 113101418764487,
}
Config.REACOES = { medo = "medo", grito = "medo", assustado = "medo", rindo = "rindo", nervoso = "nervoso" }

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
