-- Roda o trecho "monstro real" do teste na nuvem (texto real) no Lune, imitando a nuvem SEM
-- física. O conteúdo das animações vem dos 35 arquivos .rbxm de verdade (os mesmos enviados).
-- uso: lune run monstro_sem_fisica.luau <pasta do pacote> <glb_ossos.luau> <passo|semPasso> [semRoar|ossoErrado|proibido]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local PACOTE, OSSOS, MODO = process.args[1], process.args[2], process.args[3]
local CF, V3 = roblox.CFrame, roblox.Vector3

-- catálogo como o instalador monta (IDs falsos 1000+i ligados aos arquivos)
local plano = serde.decode("json", fs.readFile(PACOTE .. "/modelo/MONSTER_ASSET_PLAN.json"))
local catalogo = { modelId = 999, heightStuds = 9.091193199157715, meshName = "Monster_Animated_18k", animations = {} }
local arquivoPorId = {}
for i, a in plano.animations do
	catalogo.animations[a.name] = { id = 1000 + i, duration = a.duration_seconds, loop = a.loop, markers = a.markers }
	arquivoPorId[tostring(1000 + i)] = PACOTE .. "/modelo/" .. a.file
end

-- modelo importado montado a partir do próprio GLB (como no teste do contrato)
local ossos = luau.load(fs.readFile(OSSOS))()
local function montar()
	local model = roblox.Instance.new("Model")
	local mesh = roblox.Instance.new("MeshPart")
	mesh.Name = "Monster_Animated_18k"
	mesh.Size = V3.new(4.247777389757561, 9.091193299823454, 2.08837299635916)
	mesh.CFrame = CF.new()
	mesh.MeshId = "rbxassetid://123"
	mesh.Parent = model
	local por = {}
	for _, o in ossos do
		local b = roblox.Instance.new("Bone")
		b.Name = o.name
		local cf = CF.new(o.t[1], o.t[2], o.t[3], o.q[1], o.q[2], o.q[3], o.q[4])
		if o.parent == "Monster_Animated_18k" then
			cf = CF.Angles(0, math.pi, 0) * CF.new(-V3.new(0.0018871191776159701, 4.546296459496564, -0.0023563702901204797)) * cf
		end
		b.CFrame = cf
		por[o.name] = b
	end
	for _, o in ossos do por[o.name].Parent = if o.parent == "Monster_Animated_18k" then mesh else por[o.parent] end
	return model
end

-- tracks e Animator de mentira: sem física nada anda; StepAnimations anda (se o modo deixar)
local function marcadoresDoArquivo(id)
	local seq = roblox.deserializeModel(fs.readFile(arquivoPorId[id]))[1]
	local r = {}
	for _, d in seq:GetDescendants() do
		if d.ClassName == "KeyframeMarker" then table.insert(r, { nome = d.Name, t = d.Parent.Time }) end
	end
	return r
end
local function novoAnimator()
	local self = { tracks = {}, ClassName = "Animator" }
	function self:LoadAnimation(anim)
		local id = string.match(anim.AnimationId, "%d+")
		local nome = anim.Name
		local t = { Length = catalogo.animations[nome].duration, IsPlaying = false, TimePosition = 0, Looped = false, sinais = {} }
		t.marcas = marcadoresDoArquivo(id)
		function t:Play() self.IsPlaying = true; self.TimePosition = 0 end
		function t:Stop() self.IsPlaying = false end
		function t:Destroy() end
		function t:GetMarkerReachedSignal(m)
			return { Connect = function(_, fn)
				self.sinais[m] = self.sinais[m] or {}
				table.insert(self.sinais[m], fn)
				return { Disconnect = function() end }
			end }
		end
		table.insert(self.tracks, t)
		return t
	end
	function self:StepAnimations(dt)
		if MODO ~= "passo" then error("The current thread cannot call 'StepAnimations' (lacking capability Plugin)") end
		for _, t in self.tracks do
			if t.IsPlaying then
				local antes = t.TimePosition
				t.TimePosition += dt
				for _, m in t.marcas do
					if m.t > antes and m.t <= t.TimePosition then
						for _, fn in t.sinais[m.nome] or {} do fn() end
					end
				end
			end
		end
	end
	return self
end

local InstanceFalso = { new = function(classe)
	if classe == "Animator" then return novoAnimator() end
	return roblox.Instance.new(classe)
end }
local servicos = {
	KeyframeSequenceProvider = { GetKeyframeSequenceAsync = function(_, url)
		local id = string.match(url, "%d+")
		local seq = roblox.deserializeModel(fs.readFile(arquivoPorId[id]))[1]
		local ESTRAGO = process.args[4]
		if ESTRAGO and string.find(arquivoPorId[id], "06_RUGIDO", 1, true) then
			for _, d in seq:GetDescendants() do
				if ESTRAGO == "semRoar" and d.ClassName == "KeyframeMarker" and d.Name == "Roar" then d:Destroy() end
				if ESTRAGO == "ossoErrado" and d.ClassName == "Pose" and d.Name == "head" then d.Name = "cabeca_inexistente" end
			end
		end
		if ESTRAGO == "proibido" then error("The current thread cannot access 'KeyframeSequenceProvider' (lacking capability)") end
		return seq
	end },
}
local gameFalso = { GetService = function(_, n) return servicos[n] end }

-- trecho real do teste
local teste = fs.readFile(PACOTE .. "/src/teste_nuvem.luau")
local a = assert(string.find(teste, "checar(\"monstro real, importação e animações nativas\"", 1, true))
local b = assert(string.find(teste, "-- 7) o Pavel anda", 1, true))
local trecho = string.sub(teste, a, b - 1)
trecho = string.gsub(trecho, "modelo:PivotTo%(CFrame.new%(21000, 20000, 0%)%)", "--[[PivotTo]]")
trecho = string.gsub(trecho, "animator.Parent = controller", "--[[parent]]")
local contrato = luau.load(fs.readFile(PACOTE .. "/modelo/MonsterImportContract.luau"), { environment = { CFrame = CF, Vector3 = V3, typeof = typeof, math = math, string = string, table = table, select = select, tostring = tostring, assert = assert, error = error, pairs = pairs, next = next } })()
local core = luau.load(fs.readFile(PACOTE .. "/src/server/CriaturaCore.luau"), { injectGlobals = true })()
local out = { passed = true, erros = {}, avisos = {}, info = {} }
local env = {
	out = out, MonsterCatalog = catalogo, MonsterImportContract = contrato, CriaturaCore = core,
	falha = function(m) out.passed = false; table.insert(out.erros, tostring(m)) end,
	aviso = function(m) table.insert(out.avisos, m) end,
	checar = function(nome, fn) local ok, e = pcall(fn); if not ok then out.passed = false; table.insert(out.erros, nome .. ": " .. tostring(e)) end; return ok end,
	AssetService = { LoadAssetAsync = function() return montar() end },
	ContentProvider = { PreloadAsync = function(_, lista, cb) for _, x in lista do cb("x", roblox.Enum.AssetFetchStatus.Success) end end },
	HttpService = { JSONEncode = function() return "{}" end },
	Instance = InstanceFalso, CFrame = CF, Vector3 = V3, Enum = roblox.Enum, game = gameFalso,
	pasta = roblox.Instance.new("Folder"), fisicaRoda = false,
	task = { spawn = function(fn, ...) fn(...) end, wait = function() return 0 end },
	typeof = function(x) if type(x) == "table" and x.ClassName then return "Instance" end return typeof(x) end,
}
for k, v in _G do if env[k] == nil then env[k] = v end end
local ok, err = pcall(luau.load(trecho, { debugName = "teste_nuvem:monstro", environment = env }))
print("trecho rodou:", ok, err or "")
print("etapas:", serde.encode("json", out.info.monstro_etapas or {}))
print("tocar:", out.info.monstro_tocar, "| conferidas:", out.info.monstro_animacoes_conferidas, "| giro:", out.info.monstro_contrato and out.info.monstro_contrato.giro_importador_graus)
for _, e in out.erros do print("ERRO:", e) end
for _, x in out.avisos do print("aviso:", x) end
if not ok or not out.passed then process.exit(1) end
print("PASS monstro sem física (" .. MODO .. ")")
