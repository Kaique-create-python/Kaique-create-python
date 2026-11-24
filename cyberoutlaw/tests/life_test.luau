-- Monta os móveis, pedestres e lixo do life.server.luau fora do Roblox e confere que nada quebra.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local source = fs.readFile("src/life.server.luau")
if not source:find("\nreturn M%s*$") then
	source ..= "\nreturn M\n"
end
local env = {
	Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange, Enum = roblox.Enum, UDim2 = roblox.UDim2, UDim = roblox.UDim,
}
local L = luau.load(source, { debugName = "life.server.luau", environment = env })()
local total = 0
for _, def in L.FURNITURE do
	local model, size = L.buildFurniture(def)
	local n = 0
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	total += n
	print(string.format("%-16s %5d €$  %2d peças  %.1f x %.1f x %.1f", def.id, def.preco, n, size.X, size.Y, size.Z))
end
print("móveis", #L.FURNITURE, "peças", total)
for _, kind in { "civil", "civil", "civil", "gangue", "alvo", "policia", "camelo", "contato" } do
	local model, spec = L.buildPedestrian(math.random(1, 1e6), kind, if kind == "gangue" or kind == "alvo" then "vudu" else nil)
	local n = 0
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	print(kind, spec.style, n)
end
for _, def in L.TRASH do
	local m = L.buildTrash(def)
	print("lixo", def.id, #m:GetChildren())
end
print("CyberOutlawVida: móveis, pedestres, lixo e regras montados")
