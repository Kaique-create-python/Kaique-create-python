-- roda o ArmaModelo de verdade (biblioteca roblox do Lune) e exporta as peças para a prévia three.js
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local env = { Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, math = math, table = table, assert = assert, pairs = pairs, ipairs = ipairs }
local Arma = luau.load(fs.readFile(process.args[1]), { environment = env, injectGlobals = true })()
local modelo = Arma.construir({ bracos = process.args[3] == "bracos" })
local saida = {}
for _, p in modelo:GetChildren() do
	if p:IsA("BasePart") then
		local forma = if p.ClassName == "WedgePart" then "cunha" elseif p.Shape == roblox.Enum.PartType.Cylinder then "cilindro" else "bloco"
		table.insert(saida, { nome = p.Name, forma = forma, tam = { p.Size.X, p.Size.Y, p.Size.Z }, cf = { p.CFrame:GetComponents() },
			cor = { p.Color.R, p.Color.G, p.Color.B }, material = tostring(p.Material) })
	end
end
local pontos = {}
for _, a in modelo.PrimaryPart:GetChildren() do
	if a:IsA("Attachment") then local w = modelo.PrimaryPart.CFrame * a.CFrame; pontos[a.Name] = { w.Position.X, w.Position.Y, w.Position.Z } end
end
fs.writeFile(process.args[2], serde.encode("json", { pecas = saida, pontos = pontos }))
print("peças", #saida, "pontos", pontos.Cano and "ok" or "?")
