--!strict
-- Morfologia simples (português + inglês) para palavras já sem acento:
-- plurais, diminutivos/aumentativos e prefixos como "mega", "mini", "robo".

local Inflect = {}

-- regras de plural em ordem de prioridade: {sufixo, substituto}
local PLURAL_RULES = {
	{ "oes", "ao" }, -- dragoes -> dragao
	{ "aes", "ao" }, -- caes -> cao, paes -> pao
	{ "aos", "ao" }, -- maos -> mao
	{ "ais", "al" }, -- animais -> animal
	{ "eis", "el" }, -- papeis -> papel
	{ "ois", "ol" }, -- farois -> farol
	{ "uis", "ul" },
	{ "is", "il" }, -- barris -> barril
	{ "ns", "m" }, -- homens -> homem
	{ "res", "r" }, -- flores -> flor
	{ "zes", "z" }, -- luzes -> luz
	{ "ses", "s" }, -- gases? -> gas
	{ "ies", "y" }, -- ponies -> pony
	{ "ves", "f" }, -- wolves -> wolf
	{ "es", "" }, -- boxes -> box
	{ "s", "" }, -- zumbis -> zumbi
}

function Inflect.singulars(word: string): { string }
	local out = {}
	if #word < 3 then
		return out
	end
	for _, rule in PLURAL_RULES do
		local suffix, repl = rule[1], rule[2]
		if #word > #suffix + 1 and string.sub(word, -#suffix) == suffix then
			table.insert(out, string.sub(word, 1, #word - #suffix) .. repl)
		end
	end
	return out
end

-- diminutivos e aumentativos: devolve {base, modificador}
local SIZE_SUFFIXES = {
	{ "zinhos", "", "small" },
	{ "zinhas", "", "small" },
	{ "zinho", "", "small" },
	{ "zinha", "", "small" },
	{ "inhos", "o", "small" },
	{ "inhas", "a", "small" },
	{ "inho", "o", "small" },
	{ "inha", "a", "small" },
	{ "zao", "", "giant" },
	{ "zona", "", "giant" },
	{ "ao", "o", "giant" }, -- gatao -> gato (só usado se a palavra original não existir)
	{ "ona", "a", "giant" },
}

function Inflect.sizeVariants(word: string): { { base: string, modifier: string } }
	local out = {}
	for _, rule in SIZE_SUFFIXES do
		local suffix, repl, mod = rule[1], rule[2], rule[3]
		if #word > #suffix + 2 and string.sub(word, -#suffix) == suffix then
			table.insert(out, { base = string.sub(word, 1, #word - #suffix) .. repl, modifier = mod })
		end
	end
	return out
end

-- prefixos que viram modificadores ("megadragao", "minirobo", "cyberzumbi")
local PREFIXES = {
	{ "mega", "giant" },
	{ "giga", "colossal" },
	{ "super", "giant" },
	{ "ultra", "colossal" },
	{ "hiper", "giant" },
	{ "hyper", "giant" },
	{ "mini", "small" },
	{ "micro", "tiny" },
	{ "robo", "robotic" },
	{ "cyber", "robotic" },
	{ "ciber", "robotic" },
	{ "mecha", "robotic" },
	{ "zumbi", "undead" },
	{ "zombie", "undead" },
	{ "neon", "neon" },
	{ "piro", "fire" },
	{ "crio", "ice" },
	{ "eletro", "electric" },
}

function Inflect.prefixVariants(word: string): { { base: string, modifier: string } }
	local out = {}
	for _, rule in PREFIXES do
		local prefix, mod = rule[1], rule[2]
		if #word >= #prefix + 3 and string.sub(word, 1, #prefix) == prefix then
			table.insert(out, { base = string.sub(word, #prefix + 1), modifier = mod })
		end
	end
	return out
end

return Inflect
