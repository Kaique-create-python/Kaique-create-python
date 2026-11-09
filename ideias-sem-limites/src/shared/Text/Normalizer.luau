--!strict
-- Normalização de texto: minúsculas (inclusive letras acentuadas), remoção de
-- acentos, pontuação, letras repetidas ("gigaaante") e separação número/palavra.
-- O resultado contém apenas [a-z0-9], espaços e o marcador "," (lista/combinação).

local Normalizer = {}

-- segundo byte da sequência UTF-8 0xC3 0xNN -> letra ASCII
local LATIN1: { [number]: string } = {}
local function map(from: number, to: number, ascii: string)
	for b = from, to do
		LATIN1[b] = ascii
	end
end
map(0x80, 0x85, "a")
map(0xA0, 0xA5, "a")
map(0x86, 0x86, "ae")
map(0xA6, 0xA6, "ae")
map(0x87, 0x87, "c")
map(0xA7, 0xA7, "c")
map(0x88, 0x8B, "e")
map(0xA8, 0xAB, "e")
map(0x8C, 0x8F, "i")
map(0xAC, 0xAF, "i")
map(0x90, 0x90, "d")
map(0xB0, 0xB0, "d")
map(0x91, 0x91, "n")
map(0xB1, 0xB1, "n")
map(0x92, 0x96, "o")
map(0xB2, 0xB6, "o")
map(0x98, 0x98, "o")
map(0xB8, 0xB8, "o")
map(0x97, 0x97, " ")
map(0xB7, 0xB7, " ")
map(0x99, 0x9C, "u")
map(0xB9, 0xBC, "u")
map(0x9D, 0x9D, "y")
map(0xBD, 0xBD, "y")
map(0xBF, 0xBF, "y")
map(0x9E, 0x9E, "th")
map(0xBE, 0xBE, "th")
map(0x9F, 0x9F, "ss")

local function stripLatin(s: string): string
	return (string.gsub(s, "\xC3([\x80-\xBF])", function(c: string): string
		return LATIN1[string.byte(c)] or " "
	end))
end

-- reduz sequências de 3+ letras iguais para uma ("gigaaante" -> "gigante")
local function squeezeRuns(s: string): string
	local out = table.create(#s)
	local last, run = "", 0
	for i = 1, #s do
		local ch = string.sub(s, i, i)
		if ch == last and string.match(ch, "%a") then
			run += 1
		else
			last, run = ch, 1
		end
		out[#out + 1] = ch
		if run == 3 then
			-- remove as duas cópias anteriores, mantendo uma letra só
			out[#out] = nil
			out[#out] = nil
		elseif run > 3 then
			out[#out] = nil
		end
	end
	return table.concat(out)
end

function Normalizer.normalize(raw: string): string
	local s = string.lower(raw)
	s = stripLatin(s)
	-- qualquer outro caractere não ASCII (emoji, etc.) vira espaço
	s = string.gsub(s, "[\128-\255]+", " ")
	-- marcadores de combinação
	s = string.gsub(s, "[,;&%+/|]", " , ")
	-- apóstrofos somem ("dragon's" -> "dragons")
	s = string.gsub(s, "'", "")
	-- demais símbolos viram espaço
	s = string.gsub(s, "[^%w%s,]", " ")
	-- separa números colados em palavras ("100zumbis")
	s = string.gsub(s, "(%d)(%a)", "%1 %2")
	s = string.gsub(s, "(%a)(%d)", "%1 %2")
	s = squeezeRuns(s)
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, "^ ", "")
	s = string.gsub(s, " $", "")
	return s
end

function Normalizer.tokens(raw: string, maxTokens: number?): { string }
	local norm = Normalizer.normalize(raw)
	local list = {}
	local limit = maxTokens or 32
	for word in string.gmatch(norm, "%S+") do
		-- vírgulas repetidas viram uma só
		if not (word == "," and list[#list] == ",") then
			list[#list + 1] = word
		end
		if #list >= limit then
			break
		end
	end
	-- remove vírgulas nas pontas
	while list[1] == "," do
		table.remove(list, 1)
	end
	while list[#list] == "," do
		list[#list] = nil
	end
	return list
end

-- Limpeza de segurança do texto bruto enviado pelo cliente (antes de qualquer uso)
function Normalizer.sanitize(raw: string, maxLen: number): string?
	if type(raw) ~= "string" then
		return nil
	end
	if utf8.len(raw) == nil then
		return nil -- UTF-8 inválido
	end
	-- remove caracteres de controle
	local s = string.gsub(raw, "[%c]", " ")
	s = string.gsub(s, "%s+", " ")
	s = string.gsub(s, "^ ", "")
	s = string.gsub(s, " $", "")
	if #s == 0 then
		return nil
	end
	-- corta respeitando limites de caracteres UTF-8
	if (utf8.len(s) or 0) > maxLen then
		local cut = utf8.offset(s, maxLen + 1)
		if cut then
			s = string.sub(s, 1, cut - 1)
		end
	end
	return s
end

return Normalizer
