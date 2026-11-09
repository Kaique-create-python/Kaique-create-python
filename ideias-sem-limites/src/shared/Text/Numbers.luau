--!strict
-- Reconhece quantidades escritas com dígitos ou por extenso (PT/EN).

local Numbers = {}

local WORDS: { [string]: number } = {
	-- português (sem acento)
	um = 1,
	uma = 1,
	dois = 2,
	duas = 2,
	tres = 3,
	quatro = 4,
	cinco = 5,
	seis = 6,
	sete = 7,
	oito = 8,
	nove = 9,
	dez = 10,
	onze = 11,
	doze = 12,
	quinze = 15,
	vinte = 20,
	trinta = 30,
	quarenta = 40,
	cinquenta = 50,
	cem = 100,
	cento = 100,
	mil = 1000,
	milhao = 1000000,
	milhoes = 1000000,
	bilhao = 1000000000,
	-- inglês
	one = 1,
	two = 2,
	three = 3,
	four = 4,
	five = 5,
	six = 6,
	seven = 7,
	eight = 8,
	nine = 9,
	ten = 10,
	twelve = 12,
	twenty = 20,
	fifty = 50,
	hundred = 100,
	thousand = 1000,
	million = 1000000,
	dozen = 12,
	duzia = 12,
}

function Numbers.parse(token: string): number?
	if string.match(token, "^%d+$") then
		if #token > 9 then
			return 999999999
		end
		return tonumber(token)
	end
	return WORDS[token]
end

-- "um"/"uma"/"one" funcionam como artigo: não devem ser tratados como pedido de quantidade
function Numbers.isArticle(token: string): boolean
	return token == "um" or token == "uma" or token == "one"
end

return Numbers
