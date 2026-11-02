-- OI3 :: configurações gerais do jogo (compartilhado entre servidor e cliente)

local Config = {}

Config.JOGO = "OI3"
Config.REVISAO = "AJUSTE-5"
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

-- AJUSTE-5: roupas e cabelos do catálogo do Roblox (itens clássicos, funcionam em R6).
-- 0 = ainda sem item. Keko: cabelo e rosto escolhidos pelos criadores (falta o número do item).
Config.ROUPAS = {
	KE = { camisa = 11936840903, calca = 9996628332, cabelo = {}, rosto = 0 },
	NI = { camisa = 6998311830, calca = 2979045299, cabelo = { 126460999741527 }, rosto = 0 },
	ME = { camisa = 6163926164, calca = 7718540287, cabelo = { 6714486677 }, rosto = 0 },
	VO = { camisa = 11237559621, calca = 5916135431, cabelo = { 18331282448 }, rosto = 0 },
}

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
	maximoJogadores = 4,
	contagem = 5, -- segundos de contagem quando todos estão prontos
	atrasoInicio = 2.5, -- segundos entre o aviso e o começo sincronizado
}

return Config
