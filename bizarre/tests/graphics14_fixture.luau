-- Fronteiras Roblox controladas; CFrame/Vector3/Enum são os reais de @lune/roblox.
-- Não representa CameraModule, renderizador, colisão física ou FPS de um cliente Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local R = require("@lune/roblox")
local V, C = R.Vector3, R.CFrame
local SOURCE = if fs.isDir("src") then "src/" else "bizarre/src/"
local Fixture = { V = V, C = C, Enum = R.Enum }

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local connection = { Connected = true }
			function connection:Disconnect() self.Connected = false end
			table.insert(callbacks, { fn = fn, connection = connection })
			return connection
		end,
		Fire = function(_, ...)
			for _, c in table.clone(callbacks) do
				if c.connection.Connected then c.fn(...) end
			end
		end,
	}
end

local function instance(class)
	local props = { ClassName = class, Name = class, children = {}, attrs = {}, signals = {}, ChildAdded = signal(), ChildRemoved = signal(), DescendantAdded = signal(), AncestryChanged = signal() }
	if class == "ColorCorrectionEffect" then props.Contrast, props.Saturation, props.Brightness, props.TintColor = 0, 0, 0, R.Color3.new(1,1,1) end
	if class == "DepthOfFieldEffect" then props.Enabled = true end
	local methods = {}
	local o
	function methods:IsA(name)
		return props.ClassName == name or (name == "BasePart" and props.ClassName == "Part")
	end
	function methods:FindFirstChild(name)
		for _, ch in props.children do if ch.Name == name then return ch end end
	end
	methods.WaitForChild = methods.FindFirstChild
	function methods:FindFirstChildOfClass(name)
		for _, ch in props.children do if ch:IsA(name) then return ch end end
	end
	function methods:GetChildren() return table.clone(props.children) end
	function methods:GetDescendants()
		local list = {}
		local function visit(node)
			for _, child in node:GetChildren() do table.insert(list, child) visit(child) end
		end
		visit(self)
		return list
	end
	function methods:GetAttribute(name) return props.attrs[name] end
	function methods:SetAttribute(name, value) props.attrs[name] = value end
	function methods:Destroy() self.Parent = nil end
	function methods:GetState() return props.state or R.Enum.HumanoidStateType.Running end
	function methods:ChangeState(state) props.state = state end
	function methods:GetPropertyChangedSignal(name)
		props.signals[name] = props.signals[name] or signal()
		return props.signals[name]
	end
	o = setmetatable({}, {
		__index = function(_, k)
			if k == "Position" and props.CFrame then return props.CFrame.Position end
			return methods[k] or props[k] or methods.FindFirstChild(o, k)
		end,
		__newindex = function(_, k, value)
			if k == "Parent" then
				local previous = props.Parent
				if previous and previous.children then
					local i = table.find(previous.children, o)
					if i then table.remove(previous.children, i) previous.ChildRemoved:Fire(o) end
				end
				if value and value.children then table.insert(value.children, o) end
			elseif k == "Position" and props.ClassName == "Part" then
				props.CFrame = C.new(value) * (props.CFrame and props.CFrame.Rotation or C.identity)
				return
			end
			props[k] = value
			if k == "Parent" then
				if value then
					value.ChildAdded:Fire(o)
					local added = {o}
					for _, desc in o:GetDescendants() do table.insert(added, desc) end
					local ancestor = value
					while ancestor do
						for _, desc in added do ancestor.DescendantAdded:Fire(desc) end
						ancestor = ancestor.Parent
					end
				end
				props.AncestryChanged:Fire(o, value)
			end
			if props.signals[k] then props.signals[k]:Fire() end
		end,
	})
	return o
end

function Fixture.world()
	local now, queued = 0, {}
	local function launch(fn)
		local co = coroutine.create(fn)
		local function resume()
			local ok, delay = coroutine.resume(co)
			assert(ok, delay)
			if coroutine.status(co) ~= "dead" then table.insert(queued, {at=now+(delay or 0), fn=resume}) end
		end
		resume()
	end
	local ws = instance("Workspace")
	local actors = {}
	local function actor(name, pos)
		local m = instance("Model")
		m.Name = name
		m:SetAttribute("BB_Lutador", true)
		local root = instance("Part")
		root.Name, root.CFrame, root.Parent = "HumanoidRootPart", C.new(pos), m
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = V.zero, V.zero
		local h = instance("Humanoid")
		h.Health, h.AutoRotate, h.CameraOffset, h.MoveDirection = 100, true, V.zero, V.zero
		h.FloorMaterial, h.Parent = R.Enum.Material.Concrete, m
		local head = instance("Part")
		head.Name, head.CFrame, head.Parent = "Head", C.new(pos + V.new(0, 2, 0)), m
		m.Parent = ws
		actors[m] = true
		return m, root, h
	end
	local own, root, hum = actor("EuR6", V.zero)
	local target, targetRoot, targetHum = actor("AlvoR6", V.new(20, 0, -10))
	local gui = instance("PlayerGui")
	local player = instance("Player")
	player.Character, player.CharacterAdded, player.CharacterRemoving = own, signal(), signal()
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 4, 32
	gui.Parent = player
	local players = { LocalPlayer = player }
	function players:GetPlayers() return { player } end
	local function camera()
		local c = instance("Camera")
		c.CFrame, c.Focus = C.lookAt(V.new(0, 4, 12), V.new(0, 2, -20)), C.new(0, 1.7, 0)
		c.FieldOfView, c.CameraType, c.CameraSubject = 70, R.Enum.CameraType.Custom, hum
		return c
	end
	ws.CurrentCamera = camera()
	local steps = {}
	local run = { Heartbeat = signal(), RenderStepped = signal() }
	function run:BindToRenderStep(name, _, fn) steps[name] = fn end
	local map = instance("Folder")
	map.Name, map.Parent = "Morioh", ws
	local wallZ, targetOccluded = nil, false
	function ws:GetServerTimeNow() return now end
	function ws:Raycast(origin, direction, params)
		-- A linha de visada tem direção para a frente; o braço da câmera, para trás.
		if targetOccluded and direction.Z < 0 then
			return { Position = origin + direction.Unit * 2, Distance = 2 }
		end
		if wallZ and direction.Z > 0 and origin.Z < wallZ and origin.Z + direction.Z > wallZ then
			local d = (wallZ - origin.Z) / direction.Z
			return { Position = origin + direction * d, Distance = direction.Magnitude * d }
		end
		return nil
	end
	local bb, cliente = instance("Folder"), instance("Folder")
	cliente.Parent = bb
	local nodes = {}
	for _, name in { "Registro", "Camera", "Config", "Regras", "Golpes", "Stands", "Animador", "Acoes", "Efeitos", "StandVisual", "AmbienteVisual14" } do
		local n = instance("ModuleScript")
		n.Name, n.Parent = name, if table.find({ "Config", "Regras", "Golpes", "Stands" }, name) then bb else cliente
		nodes[name] = n
	end
	local actionPackets, debris = {}, {}
	local deps = {
		Registro = { lutadores = function() return actors end },
		Config = { TEMPO_PARA_CORRER = 0.3 },
		Golpes = {}, Stands = {},
		Animador = { tocar = function() end, parar = function() end },
		Acoes = { tocar = function() end },
		Efeitos = { _modelosLutadores = function() return actors end },
	}
	local servicos = {
		Players = players, RunService = run, TweenService = { Create = function(_, obj, _, values) return { Play = function() for k,v in values do obj[k] = v end end } end }, Lighting = instance("Lighting"),
		Debris = { AddItem = function(_, item, dur) table.insert(debris, { item = item, dur = dur }) end },
	}
	local env = {
		game = { GetService = function(_, name) return assert(servicos[name], name) end },
		workspace = ws, Enum = R.Enum, CFrame = C, Vector3 = V, Vector2 = R.Vector2,
		ColorSequence = R.ColorSequence, NumberSequence = R.NumberSequence, NumberSequenceKeypoint = R.NumberSequenceKeypoint, Color3 = R.Color3, TweenInfo = { new = function() return {} end }, UDim2 = R.UDim2, Instance = { new = instance },
		RaycastParams = { new = function() return {} end },
		Random = { new = function() return {
			NextInteger = function(_, a) return a end,
			NextNumber = function(_, a, b) return if a and b then a + (b - a) * 0.71 else 0.71 end,
		} end },
		os = { clock = function() return now end },
		task = {
			delay = function(delay, fn) table.insert(queued, { at = now + delay, fn = function() launch(fn) end }) end,
			spawn = launch,
			wait = function(delay) return coroutine.yield(delay or .03) end,
		},
		typeof = function(v)
			if type(v) == "table" and v.ClassName then return "Instance" end
			return typeof(v)
		end,
		require = function(node) return assert(deps[node.Name], node.Name) end,
	}
	local function load(name, category)
		env.script = nodes[name] or { Parent = cliente }
		return luau.load(fs.readFile(SOURCE .. "ReplicatedStorage/BB/" .. (category or "Cliente/") .. name .. ".luau"), {
			debugName = name .. ".luau", environment = table.clone(env),
		})()
	end
	deps.Config = load("Config", "")
	deps.Regras = load("Regras", "")
	local cameraModule = load("Camera")
	deps.Camera = cameraModule
	cameraModule.iniciar()
	local e = {
		cam = cameraModule, own = own, root = root, hum = hum,
		target = target, targetRoot = targetRoot, targetHum = targetHum,
		ws = ws, player = player, run = run, steps = steps, actor = actor, newCamera = camera,
		packets = actionPackets, debris = debris, lighting = servicos.Lighting, instance = instance, map = map, gui = gui, load = load,
	}
	function e:setTime(t) now = t end
	function e:tick(dt, nativeFrame)
		now += dt
		for i = #queued, 1, -1 do
			local job = queued[i]
			if now >= job.at then table.remove(queued, i) job.fn() end
		end
		steps.BB_CameraAntes(dt)
		-- Escrita nativa controlada: só ocorre em Custom, como a decisão de CameraType exige.
		if nativeFrame and ws.CurrentCamera.CameraType == R.Enum.CameraType.Custom then
			ws.CurrentCamera.CFrame = nativeFrame
		end
		steps.BB_Camera(dt)
		run.RenderStepped:Fire(dt)
	end
	function e:wall(z) wallZ = z end
	function e:occluded(value) targetOccluded = value end
	function e:jogador()
		local j = load("Jogador")
		j.iniciar({
			Acao = { FireServer = function(_, kind, data) table.insert(actionPackets, { kind = kind, data = data }) end },
			Privado = { OnClientEvent = signal() },
		}, {})
		return j
	end
	function e:cinematica() return load("Cinematica") end
	return e
end

return Fixture
