local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local total, erros = H.compilarTudo()
print("compilados:", total, "erros:", #erros)
for _, e in erros do print("  ", e) end

local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
local ws = H.dm:GetService("Workspace")
local t0 = os.clock()
local modelo, refs = Mapa.construir(ws)
print(string.format("mapa ok: %d peças em %.2fs", #modelo:GetDescendants(), os.clock() - t0))
local luzes = 0
for _, d in modelo:GetDescendants() do if d:IsA("Light") then luzes += 1 end end
print("luzes:", luzes)
for k, v in refs do print("ref", k, v) end
fs.writeFile("oi3/tools/out/mapa.json", serde.encode("json", H.exportarPecas(modelo)))
-- reflexo do quarto do espelho
local Construtor = H.modulo("ReplicatedStorage/OI3/Construtor")
local pasta = roblox.Instance.new("Folder")
pasta.Parent = ws
local cr = Construtor.novo(pasta, { refletir = Mapa.refletorEspelho() })
Mapa.construirQuartoEspelho(cr, true)
print("reflexo:", #pasta:GetDescendants(), "peças")
fs.writeFile("oi3/tools/out/reflexo.json", serde.encode("json", H.exportarPecas(pasta)))
print("exportado")
