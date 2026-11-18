-- PROJETO BASTIÃO :: exporta os textos (falas, falantes, canais, direção de voz) em JSON
-- Uso: lune run bastiao/ferramentas/textos_json.luau  (imprime o JSON; o tratamento de áudio lê isto)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local raiz = if fs.isDir("bastiao/src") then "bastiao/src/" else "src/"
local caminho = raiz .. "ReplicatedStorage/BastiaoCompartilhado/Textos.luau"
local Textos = luau.load(fs.readFile(caminho), { debugName = "Textos" })()
local falas = {}
for _, idioma in Textos.IDIOMAS do
	falas[idioma] = Textos.L[idioma].falas
end
print(serde.encode("json", {
	idiomas = Textos.IDIOMAS,
	falante = Textos.FALANTE,
	canal = Textos.CANAL,
	direcao = Textos.DIRECAO,
	falas = falas,
	falado = Textos.FALADO,
	pronuncia = Textos.PRONUNCIA,
}, false))
