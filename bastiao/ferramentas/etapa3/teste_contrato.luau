-- Testa o contrato do monstro com ossos montados a partir do próprio GLB (como um importador faria).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance
local env = { CFrame = CFrame, Vector3 = Vector3, Instance = Instance, typeof = roblox.typeof or typeof }
setmetatable(env, { __index = _G })
local process = require("@lune/process")
-- uso: lune run teste_contrato.luau <MonsterImportContract.luau> <glb_ossos.luau>
local Contract = luau.load(fs.readFile(process.args[1]), { environment = env })()
local ossos = luau.load(fs.readFile(process.args[2]))()
local function quat(t, q)
	local x, y, z, w = q[1], q[2], q[3], q[4]
	return CFrame.new(t[1], t[2], t[3], x, y, z, w)
end
local function montar(op)
	local model = Instance.new("Model")
	local mesh = Instance.new("MeshPart")
	mesh.Name = "Monster_Animated_18k"
	mesh.Size = op.size or Vector3.new(4.247777389757561, 9.091193299823454, 2.08837299635916)
	mesh.CFrame = op.meshCF or CFrame.new()
	pcall(function() mesh.MeshId = "rbxassetid://123" end)
	mesh.Parent = model
	local porNome = {}
	for _, o in ossos do
		local b = Instance.new("Bone")
		b.Name = o.name
		local cf = quat(o.t, o.q)
		if o.parent == "Monster_Animated_18k" then
			cf = CFrame.new(-Vector3.new(0.0018871191776159701, 4.546296459496564, -0.0023563702901204797)) * cf
			if op.raiz then cf = op.raiz * cf end
		elseif op.filho then
			cf = op.filho(o.name, cf)
		end
		b.CFrame = cf
		porNome[o.name] = b
	end
	for _, o in ossos do
		porNome[o.name].Parent = if o.parent == "Monster_Animated_18k" then mesh else porNome[o.parent]
	end
	return model, mesh
end
local function caso(nome, op, esperaOk)
	local model = montar(op)
	local ok, r = pcall(Contract.Inspect, model)
	if not ok then error(nome .. ": Inspect quebrou: " .. tostring(r)) end
	local s = Contract.Summary(r)
	print(string.format("%-34s ok=%s giro=%.1f pior=%s %.5f/%.5f razao=%.4f..%.4f %s", nome, tostring(r.ok), s.giro_importador_graus,
		tostring(s.pior_osso), s.repouso_studs, s.repouso_rad, s.razao_min, s.razao_max, table.concat(r.errors, " | ")))
	assert(r.ok == esperaOk, nome .. ": resultado inesperado")
	return r
end
local r = caso("igual ao arquivo", {}, true)
assert(math.abs(r.importYawDegrees) < 0.01)
local r180 = caso("importador girou 180", { raiz = CFrame.Angles(0, math.pi, 0), size = Vector3.new(4.247777389757561, 9.091193299823454, 2.08837299635916) }, true)
assert(math.abs(math.abs(r180.importYawDegrees) - 180) < 0.01)
local r90 = caso("importador girou 90", { raiz = CFrame.Angles(0, math.pi / 2, 0), size = Vector3.new(2.08837299635916, 9.091193299823454, 4.247777389757561) }, true)
assert(math.abs(r90.importYawDegrees - 90) < 0.01)
caso("girou 90 sem trocar tamanho", { raiz = CFrame.Angles(0, math.pi / 2, 0) }, false)
caso("MeshPart girada 180", { meshCF = CFrame.Angles(0, math.pi, 0) }, true)
caso("deitado (eixo Z pra cima)", { raiz = CFrame.Angles(-math.pi / 2, 0, 0), size = Vector3.new(4.247777389757561, 2.08837299635916, 9.091193299823454) }, false)
caso("raiz em outra referencia 0.3", { raiz = CFrame.new(0, 0.3, 0) }, true)
caso("raiz deslocada 0.8", { raiz = CFrame.new(0, 0.8, 0) }, false)
caso("MeshPart deitada e raiz compensa", { meshCF = CFrame.Angles(-math.pi / 2, 0, 0), raiz = CFrame.Angles(math.pi / 2, 0, 0),
	size = Vector3.new(4.247777389757561, 2.08837299635916, 9.091193299823454) }, true)
caso("ossos filhos em outra escala", { filho = function(_, cf) return cf.Rotation + cf.Position * 1.05 end }, false)
local C = CFrame.Angles(0, math.pi, 0)
caso("troca de base em todos os ossos", { raiz = C, filho = function(_, cf) return C * cf * C:Inverse() end }, false)
caso("ruido pequeno (float)", { filho = function(_, cf) return cf * CFrame.Angles(0.0005, 0, 0) end }, true)
-- rotações zeradas: cada osso com rotação identidade e posição = deslocamento no mundo
local porNome = {}
for _, o in ossos do porNome[o.name] = o end
local mundo = {}
local function W(nome)
	if mundo[nome] then return mundo[nome] end
	local o = porNome[nome]
	local cf = quat(o.t, o.q)
	if o.parent == "Monster_Animated_18k" then
		cf = CFrame.new(-Vector3.new(0.0018871191776159701, 4.546296459496564, -0.0023563702901204797)) * cf
	else
		cf = W(o.parent) * cf
	end
	mundo[nome] = cf
	return cf
end
local rz = caso("rotacoes zeradas", { filho = function(nome)
	local o = porNome[nome]
	return CFrame.new(W(nome).Position - W(o.parent).Position)
end }, false)
assert(Contract.Summary(rz).causa_provavel == "rotacoes_zeradas", "causa zerada não reconhecida")
local rc = caso("troca de eixo 180 (de novo)", { raiz = C, filho = function(_, cf) return C * cf * C:Inverse() end }, false)
assert(string.find(Contract.Summary(rc).causa_provavel, "troca_de_eixo_", 1, true), "troca de eixo não reconhecida: " .. tostring(Contract.Summary(rc).causa_provavel))
local re = caso("escala 1.05 (de novo)", { filho = function(_, cf) return cf.Rotation + cf.Position * 1.05 end }, false)
assert(string.find(Contract.Summary(re).causa_provavel, "escala_1.05", 1, true), "escala não reconhecida")
print("PASS contrato do monstro: 15 casos")
