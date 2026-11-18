-- BIZARRE :: prévia 3D dos VFX (AJUSTE-12): cada efeito "congelado" no meio, com os bonecos
-- uso (na raiz): lune run bizarre/tools/previa_vfx.luau <pasta_saida> [fracao 0..1]
-- gera vfx_<cena>.json (peças) + cenas.json (câmeras) para o renderizador three.js.
-- Só aparecem os efeitos feitos de peças (os nossos). Partículas e os pacotes da loja não aparecem aqui.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local H = require("./harness")

local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local saida = process.args[1]
local F = tonumber(process.args[2]) or 0.35
fs.writeDir(saida)

local Rig = H.modulo("ReplicatedStorage/BB/Rig")
local Animador = H.modulo("ReplicatedStorage/BB/Cliente/Animador")
local Poses = H.modulo("ReplicatedStorage/BB/Poses")

-- TweenService da prévia: leva cada propriedade só até a fração F (o efeito "no meio")
local function misturar(a, b, k)
	local t = typeof(a)
	if t == "number" then
		return a + (b - a) * k
	elseif t == "Vector3" or t == "CFrame" or t == "Color3" then
		return a:Lerp(b, k)
	end
	return if k >= 0.5 then b else a
end
local tweenAntes = H.servicos.TweenService
H.servicos.TweenService = { Create = function(_, obj, _, props)
	return { Play = function()
		for k, v in props do
			pcall(function()
				obj[k] = misturar(obj[k], v, F)
			end)
		end
	end, Cancel = function() end, Completed = H.sinalFalso() }
end }
H.servicos.Debris = { AddItem = function() end }
local pastaVFX = roblox.Instance.new("Folder")
local CAM = Vector3.new(8, 6.5, 3)
H.extras.workspace = setmetatable({ CurrentCamera = { CFrame = CFrame.new(CAM) }, Terrain = roblox.Instance.new("Folder") }, {
	__index = function(_, k)
		if k == "FindFirstChild" then
			return function(_, nome)
				return if nome == "BB_VFX" then pastaVFX else nil
			end
		end
		return nil
	end,
})
-- a sequência do efeito (anéis que saem 0,05 s depois) aparece; a limpeza (0,2 s+) não acontece
H.extras.task = { delay = function(t, fn, ...)
	if t < 0.13 then
		fn(...)
	end
end, spawn = function(fn, ...)
	fn(...)
end, wait = function() end, defer = function(fn, ...)
	fn(...)
end }
local VFX = H.moduloNovo("ReplicatedStorage/BB/Cliente/VFX")
H.extras.workspace = nil
H.extras.task = nil
H.servicos.TweenService = tweenAntes
VFX._lojaPasta(roblox.Instance.new("Folder"))

local R6 = { RootJoint = "Root", Neck = "Neck", ["Left Shoulder"] = "LS", ["Right Shoulder"] = "RS", ["Left Hip"] = "LH", ["Right Hip"] = "RH" }
local function posar(m, pose, raizCF)
	m:FindFirstChild("HumanoidRootPart").CFrame = raizCF
	local p = Animador.paraR6(pose)
	local juntas = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") and R6[d.Name] then
			table.insert(juntas, d)
		end
	end
	table.sort(juntas, function(a, b)
		return (a.Name == "RootJoint" and 0 or 1) < (b.Name == "RootJoint" and 0 or 1)
	end)
	for _, j in juntas do
		local v = p[R6[j.Name]]
		local rot0 = j.C0 - j.C0.Position
		local alvo = if v then CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3])) else CFrame.new()
		j.Part1.CFrame = j.Part0.CFrame * j.C0 * (rot0:Inverse() * alvo * rot0) * j.C1:Inverse()
	end
end
local function rig(nome, cores)
	return Rig.montarR6(nome, cores, false)
end
local PELE, ROXO = Color3.fromRGB(245, 205, 48), Color3.fromRGB(150, 90, 230)
local function usuario()
	return rig("Usuario", { cabeca = PELE, torso = Color3.fromRGB(30, 34, 60), bracos = PELE, pernas = Color3.fromRGB(30, 30, 40) })
end
local function stand(cor)
	return rig("Stand", { cabeca = cor, torso = cor:Lerp(Color3.new(0, 0, 0), 0.25), bracos = cor, pernas = cor:Lerp(Color3.new(0, 0, 0), 0.35) })
end
local function vitima()
	return rig("Vitima", { cabeca = Color3.fromRGB(200, 160, 130), torso = Color3.fromRGB(150, 40, 40), bracos = Color3.fromRGB(200, 160, 130), pernas = Color3.fromRGB(40, 40, 50) })
end
local chao = { n = "Chao", f = "Block", s = { 160, 1, 160 }, p = { 0, -0.5, 0 }, r = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, c = { 58, 56, 66 }, m = "Concrete", t = 0 }

local FRENTE = Vector3.new(0, 0, -1)
local HIT = Vector3.new(0, 3.5, 1.1)
local cenas = {}
local function cena(nome, titulo, montar, efeito, cam, alvo)
	pastaVFX:ClearAllChildren()
	VFX._zerarContagem()
	local modelos = montar()
	efeito()
	local pecas = {}
	for _, m in modelos do
		for _, p in H.exportarPecas(m) do
			table.insert(pecas, p)
		end
	end
	local nVfx = 0
	for _, p in H.exportarPecas(pastaVFX) do
		table.insert(pecas, p)
		nVfx += 1
	end
	table.insert(pecas, chao)
	fs.writeFile(saida .. "/vfx_" .. nome .. ".json", serde.encode("json", pecas))
	table.insert(cenas, { nome = nome, titulo = titulo, cam = cam or { CAM.X, CAM.Y, CAM.Z }, alvo = alvo or { 0, 3.4, 1.6 }, pecas = nVfx })
end

-- golpe do Stand: usuário atrás, Stand na frente socando, vítima apanhando
local function lutaStand(cor)
	return function()
		local u, s, v = usuario(), stand(cor), vitima()
		posar(u, Poses.P.comando, CFrame.new(0, 3, 6))
		posar(s, Poses.P.soco_d, CFrame.new(0.3, 3.15, 3.4))
		posar(v, Poses.P.atingido, CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, 5)))
		return { u, s, v }
	end
end
cena("leve", "Soco do combo (M1)", lutaStand(ROXO), function()
	VFX.estouroAr(Vector3.new(0.3, 3.9, 1.9), FRENTE, ROXO, false)
	VFX.impacto(HIT, FRENTE, ROXO, 1)
end)
cena("forte", "4º soco (forte)", lutaStand(ROXO), function()
	VFX.estouroAr(Vector3.new(0.3, 3.9, 1.9), FRENTE, ROXO, true)
	VFX.impacto(HIT, FRENTE, ROXO, 2)
end)
cena("enorme", "Golpe final / ULT", lutaStand(Color3.fromRGB(255, 200, 60)), function()
	VFX.impacto(HIT, FRENTE, Color3.fromRGB(255, 200, 60), 3)
end, { 13, 8, 6 }, { 0, 3.4, 0.5 })
cena("guarda", "Guarda (Stand na frente)", function()
	local u, s, a = usuario(), stand(ROXO), vitima()
	posar(u, Poses.P.bloqueio, CFrame.new(0, 3, 4.5))
	posar(s, Poses.P.stand_guarda, CFrame.new(0, 3.45, 2.2))
	posar(a, Poses.P.soco_d, CFrame.lookAt(Vector3.new(0, 3, -1.2), Vector3.new(0, 3, 4)))
	return { u, s, a }
end, function()
	VFX.guarda(Vector3.new(0, 4.4, 1.5), Vector3.new(0, 0, -1), ROXO)
end)
cena("parry", "Parry perfeito", function()
	local u, s, a = usuario(), stand(ROXO), vitima()
	posar(u, Poses.P.bloqueio, CFrame.new(0, 3, 4.5))
	posar(s, Poses.P.soco_d, CFrame.new(0, 3.3, 2.0))
	posar(a, Poses.P.atordoado, CFrame.lookAt(Vector3.new(0, 3, -1.2), Vector3.new(0, 3, 4)))
	return { u, s, a }
end, function()
	VFX.parry(Vector3.new(0, 4, 0.6), ROXO)
end)
cena("clash", "ORA x MUDA (clash)", function()
	local sp, tw = stand(ROXO), stand(Color3.fromRGB(255, 200, 60))
	posar(sp, Poses.P.soco_d, CFrame.lookAt(Vector3.new(0, 3.2, 3), Vector3.new(0, 3.2, -3)))
	posar(tw, Poses.P.soco_e, CFrame.lookAt(Vector3.new(0, 3.2, -1.6), Vector3.new(0, 3.2, 5)))
	return { sp, tw }
end, function()
	VFX.clash(Vector3.new(0, 3.9, 0.7), ROXO, Color3.fromRGB(255, 200, 60))
	VFX.pressao(Vector3.new(0, 3.8, 0.2), FRENTE, ROXO)
end, { 9, 6, 1 }, { 0, 3.5, 0.7 })
fs.writeFile(saida .. "/cenas.json", serde.encode("json", cenas))
for _, c in cenas do
	print(c.nome, c.pecas .. " peças de efeito")
end
