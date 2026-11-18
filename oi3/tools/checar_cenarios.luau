-- Monta todos os cenários das missões (Lune) e confere se todo ponto de missão existe
local H = require("./harness")
local roblox = require("@lune/roblox")
local MM = H.modulo("ReplicatedStorage/OI3/MissoesMapa")
local Missoes = H.modulo("ReplicatedStorage/OI3/Missoes")
local total = 0
for _, nome in MM.CENARIOS do
	local pasta = roblox.Instance.new("Folder")
	local ok, modelo, l = pcall(MM.construir, nome, pasta)
	if not ok then
		print("ERRO", nome, modelo)
	else
		local n = 0
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") then n += 1 end
		end
		total += n
		print(string.format("%-16s %5d peças", nome, n))
	end
end
print("total", total)
for n, m in Missoes.LISTA do
	local l = MM.layout(m.cenario)
	for i, p in m.passos do
		for _, id in Missoes.pontosDoPasso(p) do
			assert(l.pontos[id], string.format("missão %d passo %d: ponto %s não existe no cenário %s", n, i, id, m.cenario))
		end
		for _, id in p.falsos or {} do
			assert(l.pontos[id], "ponto falso sem posição: " .. id)
		end
	end
end
print("pontos ok")
