-- Exporta as peças de cada arma (espaço da arma, sem deslocamento) para os ícones 2D e as prévias.
-- Uso: lune run tools/export_weapons.luau <saida.json>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local arsenal = luau.load(fs.readFile("src/arsenal.server.luau"), { debugName = "arsenal", environment = {
	Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum,
} })()
local weapons = {}
for _, def in arsenal.WEAPONS do
	local model = arsenal.buildModel(def)
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, {
				name = part.Name, cframe = { part.CFrame:GetComponents() }, size = { part.Size.X, part.Size.Y, part.Size.Z },
				color = { part.Color.R, part.Color.G, part.Color.B }, shape = part.Shape.Name,
				material = part.Material.Name, transparency = part.Transparency,
			})
		end
	end
	table.insert(weapons, { id = def.id, name = def.name, tipo = def.tipo, parts = parts })
end
fs.writeFile(process.args[1] or "armas.json", serde.encode("json", weapons))
print(#weapons .. " armas exportadas")
