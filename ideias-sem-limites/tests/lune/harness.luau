--!nocheck
-- Mini-ambiente Roblox para rodar os módulos do jogo no Lune (fora do Roblox).
--   * carrega o .rbxl gerado pelo Rojo (mesma árvore que vai para a nuvem)
--   * emula require(ModuleScript) com "script" correto em cada módulo
--   * implementa serviços que o Lune não tem (Tween, Debris, Terrain, Raycast...)
-- O Lune valida nomes/tipos de propriedades com a base de reflexão do Roblox,
-- então erros como "Part.Colour" ou Material com tipo errado aparecem aqui.

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local serde = require("@lune/serde")

local Harness = {}
Harness.terrainLog = {}
Harness.debrisCount = 0
Harness.tweenCount = 0
Harness.warnings = {}

local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local function signalStub()
	local s = {}
	function s:Connect(fn)
		return { Disconnect = function() end, Connected = true }
	end
	function s:Once(fn)
		return { Disconnect = function() end, Connected = true }
	end
	function s:Wait()
		return nil
	end
	return s
end

local PART_CLASSES = { "Part", "WedgePart", "CornerWedgePart", "TrussPart", "MeshPart", "SpawnLocation", "Seat", "VehicleSeat", "UnionOperation" }

local function pivotOf(model)
	if model.PrimaryPart then
		return model.PrimaryPart.CFrame
	end
	return model.WorldPivot
end

local function installStubs()
	roblox.implementMethod("TweenService", "Create", function(_self, inst, info, goals)
		Harness.tweenCount += 1
		local tw = { Completed = signalStub(), PlaybackState = roblox.Enum.PlaybackState.Begin }
		function tw:Play()
			-- aplica o estado final imediatamente (suficiente para testes)
			for k, v in goals do
				pcall(function()
					inst[k] = v
				end)
			end
		end
		function tw:Cancel() end
		function tw:Pause() end
		function tw:Destroy() end
		return tw
	end)
	roblox.implementMethod("Debris", "AddItem", function(_self, inst, life)
		Harness.debrisCount += 1
	end)
	roblox.implementMethod("RunService", "IsServer", function()
		return true
	end)
	roblox.implementMethod("RunService", "IsClient", function()
		return false
	end)
	roblox.implementMethod("RunService", "IsStudio", function()
		return false
	end)
	roblox.implementMethod("HttpService", "GenerateGUID", function(_self, braces)
		return string.format("%08x-%04x", math.random(0, 0x7fffffff), math.random(0, 0xffff))
	end)
	roblox.implementMethod("HttpService", "JSONEncode", function(_self, v)
		return serde.encode("json", v)
	end)
	roblox.implementMethod("HttpService", "JSONDecode", function(_self, s)
		return serde.decode("json", s)
	end)
	for _, method in { "FillBlock", "FillBall", "FillCylinder", "FillWedge", "Clear", "ReplaceMaterial", "FillRegion" } do
		roblox.implementMethod("Terrain", method, function(_self, ...)
			table.insert(Harness.terrainLog, { method = method, args = { ... } })
		end)
	end
	roblox.implementMethod("Workspace", "Raycast", function()
		return nil
	end)
	roblox.implementMethod("Workspace", "GetPartBoundsInRadius", function()
		return {}
	end)
	roblox.implementMethod("Workspace", "GetPartBoundsInBox", function()
		return {}
	end)
	roblox.implementMethod("Workspace", "GetPartsInPart", function()
		return {}
	end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return os.clock()
	end)
	roblox.implementMethod("Players", "GetPlayers", function()
		return {}
	end)
	roblox.implementMethod("Model", "GetPivot", function(self)
		return pivotOf(self)
	end)
	roblox.implementMethod("Model", "PivotTo", function(self, target)
		local current = pivotOf(self)
		local delta = target * current:Inverse()
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		self.WorldPivot = target
	end)
	roblox.implementMethod("Model", "GetBoundingBox", function(self)
		local minV, maxV
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				local p = d.CFrame.Position
				local h = d.Size * 0.5
				local lo, hi = p - h, p + h
				minV = if minV then Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) else lo
				maxV = if maxV then Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) else hi
			end
		end
		if not minV then
			return pivotOf(self), Vector3.zero
		end
		return CFrame.new((minV + maxV) * 0.5), maxV - minV
	end)
	roblox.implementMethod("Model", "GetExtentsSize", function(self)
		local _, size = self:GetBoundingBox()
		return size
	end)
	roblox.implementMethod("Model", "ScaleTo", function() end)
	roblox.implementMethod("Model", "GetScale", function()
		return 1
	end)
	for _, cls in PART_CLASSES do
		roblox.implementMethod(cls, "SetNetworkOwner", function() end)
		roblox.implementMethod(cls, "CanSetNetworkOwnership", function()
			return true
		end)
		roblox.implementMethod(cls, "GetMass", function(self)
			return self.Size.X * self.Size.Y * self.Size.Z * 0.7
		end)
		roblox.implementMethod(cls, "ApplyImpulse", function() end)
		roblox.implementMethod(cls, "GetTouchingParts", function()
			return {}
		end)
		roblox.implementMethod(cls, "GetConnectedParts", function()
			return {}
		end)
		roblox.implementMethod(cls, "BreakJoints", function() end)
	end
	for _, m in { "MoveTo", "ChangeState", "SetStateEnabled", "TakeDamage", "EquipTool", "UnequipTools", "ApplyDescription" } do
		roblox.implementMethod("Humanoid", m, function() end)
	end
	roblox.implementMethod("Humanoid", "GetState", function()
		return roblox.Enum.HumanoidStateType.Running
	end)
	roblox.implementMethod("Sound", "Play", function() end)
	roblox.implementMethod("Sound", "Stop", function() end)
	roblox.implementMethod("ParticleEmitter", "Emit", function() end)
	roblox.implementMethod("ParticleEmitter", "Clear", function() end)
end

-- O Lune não calcula propriedades derivadas (BasePart.Position,
-- AssemblyLinearVelocity...). Só nos testes, reescrevemos as leituras para
-- funções auxiliares que usam CFrame; atribuições físicas viram no-op.
local function preprocess(source: string): string
	local out = {}
	for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
		local indent, target, kind, rhs = string.match(line, "^(%s*)([%a_][%w_%.]*)%.Assembly(%a+)Velocity%s*%+?=%s*(.+)$")
		if indent then
			line = indent .. "__noop(" .. target .. ", " .. rhs .. ")"
		else
			local lhs, rest = string.match(line, "^(%s*[%a_][%w_%.]*%.Position%s*=)([^=].*)$")
			local function rewrite(text: string): string
				text = string.gsub(text, "([%a_][%w_%.]*)%.Position([^%w_])", "__pos(%1)%2")
				text = string.gsub(text, "([%a_][%w_%.]*)%.Position$", "__pos(%1)")
				text = string.gsub(text, "([%a_][%w_%.]*)%.AssemblyLinearVelocity", "__vel(%1)")
				text = string.gsub(text, "([%a_][%w_%.]*)%.AssemblyMass", "__mass(%1)")
				return text
			end
			if lhs then
				line = lhs .. rewrite(rest)
			else
				line = rewrite(line)
			end
		end
		table.insert(out, line)
	end
	return table.concat(out, "\n")
end
Harness.preprocess = preprocess

local function makeRandomClass()
	local R = {}
	R.__index = R
	function R.new(seed)
		local self = setmetatable({ s = (seed or os.clock() * 1000) % 2147483647 }, R)
		if self.s <= 0 then
			self.s = 1
		end
		return self
	end
	function R:NextNumber(a, b)
		self.s = (self.s * 16807) % 2147483647
		local f = (self.s - 1) / 2147483646
		if a then
			return a + (b - a) * f
		end
		return f
	end
	function R:NextInteger(a, b)
		return a + math.floor(self:NextNumber() * (b - a + 1))
	end
	return R
end

-- Emula eventos de instância (o Lune não tem sinais): cada acesso devolve um
-- sinal que aceita Connect/Once/Wait. Suficiente para executar o servidor.
local EVENTS = {
	Humanoid = { "Died", "HealthChanged", "Running", "StateChanged", "Touched" },
	ProximityPrompt = { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden" },
	Tool = { "Activated", "Deactivated", "Equipped", "Unequipped" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	RunService = { "Heartbeat", "Stepped", "RenderStepped", "PreSimulation", "PostSimulation" },
	Lighting = { "ChildAdded", "Changed" },
	Workspace = { "ChildAdded", "DescendantAdded" },
	Folder = { "ChildAdded", "DescendantAdded", "ChildRemoved" },
	RemoteEvent = { "OnServerEvent" },
}

function Harness.enableServerEvents()
	for cls, list in EVENTS do
		for _, ev in list do
			pcall(function()
				roblox.implementProperty(cls, ev, function()
					return signalStub()
				end)
			end)
		end
	end
	for _, cls in PART_CLASSES do
		pcall(function()
			roblox.implementProperty(cls, "Touched", function()
				return signalStub()
			end)
		end)
		roblox.implementMethod(cls, "GetJoints", function()
			return {}
		end)
	end
	roblox.implementMethod("CollectionService", "GetTagged", function(_self, tag)
		local out = {}
		if Harness.game then
			for _, d in Harness.game:GetDescendants() do
				if d:HasTag(tag) then
					table.insert(out, d)
				end
			end
		end
		return out
	end)
	roblox.implementMethod("CollectionService", "GetInstanceAddedSignal", function()
		return signalStub()
	end)
	roblox.implementMethod("CollectionService", "GetInstanceRemovedSignal", function()
		return signalStub()
	end)
	roblox.implementMethod("DataModel", "BindToClose", function() end)
	for _, cls in { "RemoteEvent", "UnreliableRemoteEvent" } do
		roblox.implementMethod(cls, "FireClient", function() end)
		roblox.implementMethod(cls, "FireAllClients", function() end)
	end
	roblox.implementMethod("VehicleSeat", "Sit", function() end)
	roblox.implementMethod("Seat", "Sit", function() end)
	for _, cls in { "Humanoid", "Model", "Part", "Folder", "Workspace" } do
		roblox.implementMethod(cls, "GetPropertyChangedSignal", function()
			return signalStub()
		end)
		roblox.implementMethod(cls, "GetAttributeChangedSignal", function()
			return signalStub()
		end)
	end
end

function Harness.load(placePath: string)
	installStubs()
	local game = roblox.deserializePlace(fs.readFile(placePath))
	Harness.game = game
	local cache = {}
	local loading = {}
	local env

	local globals = {
		game = game,
		workspace = game:GetService("Workspace"),
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		Vector3int16 = roblox.Vector3int16,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		Font = roblox.Font,
		PhysicalProperties = roblox.PhysicalProperties,
		Ray = roblox.Ray,
		Rect = roblox.Rect,
		Region3 = roblox.Region3,
		Faces = roblox.Faces,
		Axes = roblox.Axes,
		task = task,
		tick = os.clock,
		time = os.clock,
		wait = task.wait,
		delay = task.delay,
		spawn = task.spawn,
		warn = function(...)
			table.insert(Harness.warnings, table.concat({ ... }, " "))
		end,
		TweenInfo = {
			new = function(...)
				return { args = { ... } }
			end,
		},
		RaycastParams = {
			new = function()
				return { FilterDescendantsInstances = {} }
			end,
		},
		OverlapParams = {
			new = function()
				return { FilterDescendantsInstances = {}, MaxParts = 0 }
			end,
		},
		Random = makeRandomClass(),
		__pos = function(x)
			if typeof(x) == "Instance" then
				if x:IsA("BasePart") then
					return x.CFrame.Position
				elseif x:IsA("Model") then
					return (if x.PrimaryPart then x.PrimaryPart.CFrame else x.WorldPivot).Position
				end
			end
			return x.Position
		end,
		__vel = function(_x)
			return roblox.Vector3.zero
		end,
		__mass = function(x)
			return if typeof(x) == "Instance" and x:IsA("BasePart") then x.Size.X * x.Size.Y * x.Size.Z * 0.7 else 1
		end,
		__noop = function() end,
		DateTime = {
			now = function()
				return { UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000 }
			end,
		},
	}

	local function requireModule(mod)
		if typeof(mod) ~= "Instance" then
			error("require() espera um ModuleScript, recebeu " .. typeof(mod), 2)
		end
		if cache[mod] ~= nil then
			return cache[mod]
		end
		if loading[mod] then
			error("require circular: " .. mod:GetFullName(), 2)
		end
		assert(mod.ClassName == "ModuleScript", "não é ModuleScript: " .. mod:GetFullName())
		loading[mod] = true
		-- o Lune copia só as chaves diretas do ambiente: montamos uma cópia completa
		local moduleEnv = table.clone(globals)
		moduleEnv.script = mod
		moduleEnv.require = requireModule
		local chunk = luau.load(preprocess(mod.Source), { debugName = mod:GetFullName(), environment = moduleEnv })
		local result = chunk()
		loading[mod] = nil
		cache[mod] = result
		return result
	end

	env = setmetatable(globals, { __index = _G })
	globals.require = requireModule

	return {
		game = game,
		require = requireModule,
		find = function(path: string)
			local node = game
			for part in string.gmatch(path, "[^%.]+") do
				node = node:FindFirstChild(part) or (node == game and game:GetService(part))
				assert(node, "não encontrado: " .. path)
			end
			return node
		end,
	}
end

return Harness
