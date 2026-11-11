-- BIZARRE BATTLEGROUNDS :: importa as animações do dono (.rbxm do Roblox Studio) para o jogo.
-- Lê bizarre/assets/animacoes/*.rbxm (KeyframeSequence R6), guarda cada quadro de cada junta e
-- escreve src/ReplicatedStorage/BB/AnimacoesDono.luau. O jogo toca isso direto nas juntas do R6
-- (Motor6D.Transform), sem precisar enviar animação para o Roblox.
-- uso (na raiz): lune run bizarre/tools/importar_animacoes.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local PASTA = "bizarre/assets/animacoes"
local SAIDA = "bizarre/src/ReplicatedStorage/BB/AnimacoesDono.luau"
-- arquivo -> nome no jogo
local ARQUIVOS = { andar_dono = "andar", correr_dono = "correr" }
local JUNTAS = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local PASSO = 2 -- guarda 1 de cada 2 quadros (30 por segundo; o jogo interpola)

local function n(x: number): string
	local s = string.format("%.4f", x)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	if s == "-0" then
		s = "0"
	end
	return s
end

local linhas = {
	"-- BIZARRE BATTLEGROUNDS :: animações do dono (andar e correr R6), importadas dos .rbxm do Drive",
	"-- GERADO por bizarre/tools/importar_animacoes.luau — não edite à mão.",
	"-- quadros[i] = { tempo, { junta = { x, y, z, rx, ry, rz } } } (posição em studs, ângulos em radianos XYZ)",
	"return {",
}
local nomes = {}
for arq in ARQUIVOS do
	table.insert(nomes, arq)
end
table.sort(nomes)
for _, arq in nomes do
	local caminho = PASTA .. "/" .. arq .. ".rbxm"
	local inst = roblox.deserializeModel(fs.readFile(caminho))
	local seq = nil
	for _, r in inst do
		for _, d in r:GetDescendants() do
			if d:IsA("KeyframeSequence") then
				seq = d
			end
		end
	end
	assert(seq, caminho .. ": sem KeyframeSequence")
	local kfs = seq:GetChildren()
	table.sort(kfs, function(a, b)
		return a.Time < b.Time
	end)
	local dur = kfs[#kfs].Time
	table.insert(linhas, string.format("\t%s = { dur = %s, loop = %s, origem = %q, quadros = {", ARQUIVOS[arq], n(dur), tostring(seq.Loop), seq.Name))
	local usados = 0
	for i, kf in kfs do
		if (i - 1) % PASSO ~= 0 and i ~= #kfs then
			continue
		end
		local poses = {}
		for _, p in kf:GetDescendants() do
			if p:IsA("Pose") and p.Weight > 0 then
				poses[p.Name] = p.CFrame
			end
		end
		local partes = {}
		for _, j in JUNTAS do
			local cf = poses[j]
			if cf then
				local rx, ry, rz = cf:ToEulerAnglesXYZ()
				local pp = cf.Position
				table.insert(partes, string.format("[%q] = { %s, %s, %s, %s, %s, %s }", j, n(pp.X), n(pp.Y), n(pp.Z), n(rx), n(ry), n(rz)))
			end
		end
		table.insert(linhas, string.format("\t\t{ %s, { %s } },", n(kf.Time), table.concat(partes, ", ")))
		usados += 1
	end
	table.insert(linhas, "\t} },")
	print(string.format("%s: %s (%d quadros de %d, %.3f s, loop %s)", arq, seq.Name, usados, #kfs, dur, tostring(seq.Loop)))
end
table.insert(linhas, "}")
fs.writeFile(SAIDA, table.concat(linhas, "\n") .. "\n")
print("escrito " .. SAIDA)
