-- Monta a corrida medonha a partir da corrida original (.rbxm): 3 ciclos, mesmas pernas e marcadores,
-- cada Pose multiplicada pelo offset do osso naquele quadro (mesma tabela usada na prévia three.js).
-- uso: lune run aplicar_rbxm.luau <08_CORRER.rbxm> <offsets.json> <saida.rbxm> <nome> [dump.json]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local CFrame = roblox.CFrame
local entrada, offArq, saida, nome, dumpArq = process.args[1], process.args[2], process.args[3], process.args[4], process.args[5]
local off = serde.decode("json", fs.readFile(offArq))
local ks = roblox.deserializeModel(fs.readFile(entrada))[1]
assert(ks.ClassName == "KeyframeSequence", "não é KeyframeSequence")
local kfs = {}
for _, k in ks:GetChildren() do
	if k.ClassName == "Keyframe" then table.insert(kfs, k) end
end
table.sort(kfs, function(a, b) return a.Time < b.Time end)
local porCiclo = #kfs - 1
assert(math.abs(porCiclo / off.fps - off.cycle) < 1e-4, "ciclo diferente do original")
for i, k in kfs do
	assert(math.abs(k.Time - (i - 1) / off.fps) < 1e-4, "quadro fora da grade de " .. off.fps .. " fps: " .. k.Time)
end
local novo = ks:Clone()
novo:ClearAllChildren()
novo.Name = nome
local dump = {}
for k = 0, off.frames - 1 do
	local origem = kfs[(k % porCiclo) + 1]
	local kf = origem:Clone()
	kf.Time = k / off.fps
	for _, pose in kf:GetDescendants() do
		if pose.ClassName == "Pose" then
			local linha = off.bones[pose.Name]
			if linha then
				local q = linha[k + 1]
				pose.CFrame = pose.CFrame * CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4])
			end
			if k == 0 and dumpArq then
				local c = { pose.CFrame:GetComponents() }
				dump[pose.Name] = c
			end
		end
	end
	kf.Parent = novo
end
fs.writeFile(saida, roblox.serializeModel({ novo }))
if dumpArq then
	-- quadro 0 da corrida ORIGINAL (para conferir a convenção rest * Transform contra o GLB)
	local orig = {}
	for _, pose in kfs[1]:GetDescendants() do
		if pose.ClassName == "Pose" then orig[pose.Name] = { pose.CFrame:GetComponents() } end
	end
	fs.writeFile(dumpArq, serde.encode("json", { novo = dump, original = orig }))
end
local n, marcadores, fim = 0, {}, 0
for _, d in novo:GetDescendants() do
	if d.ClassName == "Keyframe" then n += 1; fim = math.max(fim, d.Time) end
	if d.ClassName == "KeyframeMarker" then table.insert(marcadores, string.format("%s@%.3f", d.Name, d.Parent.Time)) end
end
table.sort(marcadores, function(a, b) return tonumber(a:match("@(.+)")) < tonumber(b:match("@(.+)")) end)
print(nome, "keyframes", n, "fim", fim, "loop", novo.Loop, tostring(novo.Priority))
print("marcadores", table.concat(marcadores, ", "))
