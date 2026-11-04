-- BIZARRE BATTLEGROUNDS :: converte o mapa Morioh V2 (feito no ChatGPT, .rbxlx de 217 MB) para o
-- formato binário do Roblox (.rbxl, ~2,5 MB), tirando os manequins de escala e o spawn deles.
-- uso (na raiz): lune run bizarre/tools/converter_mapa.luau <Morioh_V2.rbxlx> bizarre/assets/morioh.rbxl
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local origem, destino = process.args[1], process.args[2]
assert(origem and destino, "uso: converter_mapa.luau <entrada.rbxlx> <saida.rbxl>")
local texto = fs.readFile(origem)
-- o arquivo começa com "<?xml ...?>": o leitor do Lune quer começar direto em "<roblox"
local ini = string.find(texto, "<roblox", 1, true)
local game = roblox.deserializePlace(string.sub(texto, ini))
texto = nil
local ws = game:GetService("Workspace")
local morioh = ws:FindFirstChild("Morioh")
assert(morioh, "não achei Workspace.Morioh")
-- o SpawnLocation do mapa tem um campo com tipo errado (não salva em binário) e não é usado
for _, nome in { "Spawn_Praca", "Camera_Rua" } do
	local x = ws:FindFirstChild(nome)
	if x then
		x:Destroy()
	end
end
local ref = morioh:FindFirstChild("Referencias_Escala")
if ref then
	ref:Destroy()
end
local bin = roblox.serializePlace(game, false)
fs.writeFile(destino, bin)
print(string.format("mapa convertido: %s (%d bytes)", destino, #bin))
