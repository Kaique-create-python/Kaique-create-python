--!strict
-- Ambiente local: clima (chuva, neve, chuva ácida, areia, aurora, festa,
-- estrelas), animação procedural dos NPCs (Motor6D.Transform), peças que
-- giram/flutuam e telas que mudam de cor. Tudo roda só no cliente.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Settings = require(script.Parent.Parent.Settings)

local Ambient = {}

-- CLIMA ------------------------------------------------------------------------------
local weatherPart: BasePart? = nil
local weatherEmitter: ParticleEmitter? = nil
local partyLights: { PointLight } = {}
local auroraModel: Model? = nil

local CLIMAS = {
	chuva = { color = Color3.fromRGB(180, 200, 230), rate = 260, speed = 90, size = 0.12, tex = "rbxasset://textures/particles/sparkles_main.dds", stretch = true },
	tempestade = { color = Color3.fromRGB(170, 190, 220), rate = 360, speed = 110, size = 0.14, tex = "rbxasset://textures/particles/sparkles_main.dds", stretch = true },
	nevasca = { color = Color3.fromRGB(255, 255, 255), rate = 220, speed = 18, size = 0.35, tex = "rbxasset://textures/particles/sparkles_main.dds" },
	chuva_acida = { color = Color3.fromRGB(150, 255, 100), rate = 220, speed = 80, size = 0.14, tex = "rbxasset://textures/particles/sparkles_main.dds", stretch = true },
	areia = { color = Color3.fromRGB(230, 200, 140), rate = 160, speed = 30, size = 1.4, tex = "rbxasset://textures/particles/smoke_main.dds", side = true },
}

local function ensureWeatherPart(): BasePart
	if not weatherPart then
		local p = Instance.new("Part")
		p.Name = "ClimaLocal"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(160, 1, 160)
		p.Parent = Workspace.CurrentCamera
		local e = Instance.new("ParticleEmitter")
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(4, 4)
		e.Lifetime = NumberRange.new(1.4, 2)
		e.Parent = p
		weatherPart = p
		weatherEmitter = e
	end
	return weatherPart :: BasePart
end

local function setWeather(clima: string)
	local cfg = CLIMAS[clima]
	ensureWeatherPart()
	local e = weatherEmitter :: ParticleEmitter
	if cfg then
		e.Enabled = true
		e.Texture = cfg.tex
		e.Color = ColorSequence.new(cfg.color)
		e.Rate = cfg.rate * Settings.quality().weather
		e.Speed = NumberRange.new(cfg.speed * 0.8, cfg.speed)
		e.Size = NumberSequence.new(cfg.size)
		e.Transparency = NumberSequence.new(0.3)
		e.LightEmission = 0.2
		e.Acceleration = if cfg.side then Vector3.new(40, 0, 10) else Vector3.zero
		e.Lifetime = if cfg.speed < 40 then NumberRange.new(4, 6) else NumberRange.new(1.2, 1.8)
	else
		e.Enabled = false
	end
	-- festa: luzes coloridas pulsando em volta do jogador
	for _, l in partyLights do
		l:Destroy()
	end
	table.clear(partyLights)
	if clima == "festa" then
		for i = 1, 3 do
			local l = Instance.new("PointLight")
			l.Range = 40
			l.Brightness = 3
			l.Parent = ensureWeatherPart()
			table.insert(partyLights, l)
		end
	end
	if auroraModel then
		auroraModel:Destroy()
		auroraModel = nil
	end
	if clima == "aurora" then
		local m = Instance.new("Model")
		m.Name = "Aurora"
		for i = 1, 14 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Size = Vector3.new(60, 50, 1)
			p.Transparency = 0.6
			p.Color = Color3.fromHSV(0.35 + i * 0.02, 0.8, 1)
			p.Parent = m
		end
		m.Parent = Workspace.CurrentCamera
		auroraModel = m
	end
end

-- ANIMAÇÃO PROCEDURAL -------------------------------------------------------------------
type Motor = { m: Motor6D, kind: string, axis: string, amp: number, phase: number, speed: number, acc: number }
type Rig = { model: Model, root: BasePart?, motors: { Motor } }

local rigs: { [Model]: Rig } = {}

local function collect(model: Model)
	if rigs[model] then
		return
	end
	local rig: Rig = { model = model, root = model.PrimaryPart, motors = {} }
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d:GetAttribute("Anim") then
			table.insert(rig.motors, {
				m = d,
				kind = d:GetAttribute("Anim") :: string,
				axis = (d:GetAttribute("AnimAxis") :: string?) or "X",
				amp = (d:GetAttribute("AnimAmp") :: number?) or 0.5,
				phase = (d:GetAttribute("AnimPhase") :: number?) or 0,
				speed = (d:GetAttribute("AnimSpeed") :: number?) or 1,
				acc = 0,
			})
		end
	end
	if #rig.motors > 0 then
		rigs[model] = rig
	end
end

local function rot(axis: string, a: number): CFrame
	if axis == "Y" then
		return CFrame.Angles(0, a, 0)
	elseif axis == "Z" then
		return CFrame.Angles(0, 0, a)
	end
	return CFrame.Angles(a, 0, 0)
end

local function animate(dt: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	local serverT = Workspace:GetServerTimeNow()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		local root = rig.root
		if not root then
			continue
		end
		local dist = (root.Position - camPos).Magnitude
		if dist > 220 then
			continue
		end
		local vel = root.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local move = math.clamp(speed / 10, 0.12, 1)
		local dancing = model:GetAttribute("Dancando") == true
		local hitAt = model:GetAttribute("GolpeEm") :: number?
		local hitting = hitAt ~= nil and serverT - hitAt < 0.45
		for _, mo in rig.motors do
			local k = mo.kind
			local a = 0
			if k == "leg" or k == "arm" then
				local f = 1.7 * mo.speed * (0.6 + move)
				a = math.sin(t * f * math.pi * 2 + mo.phase) * mo.amp * move
				if dancing then
					a = math.sin(t * 8 + mo.phase) * mo.amp * 1.2
				elseif hitting and k == "arm" then
					a = -mo.amp * 1.6
				end
				mo.m.Transform = rot(mo.axis, a)
			elseif k == "wing" then
				a = math.sin(t * 2 * math.pi * 1.1 * mo.speed + mo.phase) * mo.amp
				mo.m.Transform = rot(mo.axis, a)
			elseif k == "tail" or k == "segment" or k == "tentacle" or k == "fin" or k == "cape" then
				local f = 0.8 * mo.speed * (1 + move)
				a = math.sin(t * f * math.pi * 2 + mo.phase) * mo.amp
				mo.m.Transform = rot(mo.axis, a)
			elseif k == "head" then
				a = math.sin(t * 0.7 * mo.speed + mo.phase) * mo.amp
				if hitting then
					a = 0
				end
				mo.m.Transform = rot(mo.axis, a)
			elseif k == "jaw" then
				a = if hitting then mo.amp else math.abs(math.sin(t * 0.6)) * mo.amp * 0.2
				mo.m.Transform = rot(mo.axis, a)
			elseif k == "bob" then
				local y = math.sin(t * 2 * math.pi * 0.5 * mo.speed + mo.phase) * mo.amp * 0.5
				mo.m.Transform = CFrame.new(0, y + (if dancing then math.abs(math.sin(t * 6)) else 0), 0)
			elseif k == "spin" then
				mo.acc += dt * mo.speed * math.pi * 2 * 0.5
				mo.m.Transform = rot(mo.axis, mo.acc)
			elseif k == "wheel" then
				mo.acc += dt * speed * 0.6
				mo.m.Transform = rot(mo.axis, -mo.acc)
			end
		end
	end
end

-- PEÇAS QUE GIRAM / FLUTUAM / TELAS --------------------------------------------------------
type Spinner = { part: BasePart, base: CFrame, axis: string, vel: number, pivot: Vector3, children: { { any } } }
local spinners: { [BasePart]: Spinner } = {}
local floaters: { [Instance]: { base: CFrame } } = {}
local screens: { [Instance]: boolean } = {}

local function addSpinner(part: Instance)
	if not part:IsA("BasePart") or spinners[part] then
		return
	end
	local children = {}
	for _, d in part:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(children, { d, part.CFrame:ToObjectSpace(d.CFrame) })
		end
	end
	spinners[part] = {
		part = part,
		base = part.CFrame,
		axis = (part:GetAttribute("GirarEixo") :: string?) or "Y",
		vel = (part:GetAttribute("GirarVel") :: number?) or 1,
		pivot = (part:GetAttribute("GirarPivo") :: Vector3?) or Vector3.zero,
		children = children,
	}
end

local function spin(dt: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	for part, s in spinners do
		if not part.Parent then
			spinners[part] = nil
		elseif (s.base.Position - camPos).Magnitude < 450 then
			local r = rot(s.axis, t * s.vel)
			local cf = s.base * CFrame.new(s.pivot) * r * CFrame.new(-s.pivot)
			part.CFrame = cf
			for _, ch in s.children do
				ch[1].CFrame = cf * ch[2]
			end
		end
	end
	for inst, f in floaters do
		if not inst.Parent then
			floaters[inst] = nil
		elseif inst:IsA("Model") then
			inst:PivotTo(f.base + Vector3.new(0, math.sin(t * 1.3) * 0.8, 0))
		end
	end
	-- telas mudam de cor devagar
	local hue = (t * 0.05) % 1
	for scr in screens do
		if not scr.Parent then
			screens[scr] = nil
		else
			local gui = scr:FindFirstChildOfClass("SurfaceGui")
			local frame = gui and gui:FindFirstChildOfClass("Frame")
			if frame then
				frame.BackgroundColor3 = Color3.fromHSV(hue, 0.6, 0.9)
			end
		end
	end
	-- luzes de festa
	for i, l in partyLights do
		l.Color = Color3.fromHSV((t * 0.5 + i / 3) % 1, 1, 1)
	end
	if auroraModel then
		local base = camPos + Vector3.new(0, 140, -200)
		for i, p in auroraModel:GetChildren() do
			local bp = p :: BasePart
			bp.CFrame = CFrame.new(base + Vector3.new((i - 7) * 45, math.sin(t * 0.4 + i * 0.6) * 15, math.cos(t * 0.3 + i) * 20)) * CFrame.Angles(0, math.sin(t * 0.2 + i) * 0.5, 0)
		end
	end
	if weatherPart then
		weatherPart.CFrame = CFrame.new(camPos + Vector3.new(0, 45, 0))
	end
	local _ = dt
end

function Ambient.init()
	local events = Workspace:WaitForChild("IdeiasEventos", 30)
	local function onNpc(inst: Instance)
		if inst:IsA("Model") then
			task.defer(collect, inst)
		end
	end
	for _, m in CollectionService:GetTagged("IdeiasNpc") do
		onNpc(m)
	end
	CollectionService:GetInstanceAddedSignal("IdeiasNpc"):Connect(onNpc)
	-- veículos (rodas/hélices) também têm juntas animadas
	for _, m in CollectionService:GetTagged("IdeiasVeiculo") do
		onNpc(m)
	end
	CollectionService:GetInstanceAddedSignal("IdeiasVeiculo"):Connect(onNpc)
	for _, p in CollectionService:GetTagged("IdeiasGirar") do
		addSpinner(p)
	end
	CollectionService:GetInstanceAddedSignal("IdeiasGirar"):Connect(function(p)
		task.defer(addSpinner, p)
	end)
	local function onFloat(m: Instance)
		if m:IsA("Model") then
			floaters[m] = { base = m:GetPivot() }
		end
	end
	for _, m in CollectionService:GetTagged("IdeiasFlutuar") do
		onFloat(m)
	end
	CollectionService:GetInstanceAddedSignal("IdeiasFlutuar"):Connect(onFloat)
	for _, s in CollectionService:GetTagged("IdeiasTela") do
		screens[s] = true
	end
	CollectionService:GetInstanceAddedSignal("IdeiasTela"):Connect(function(s)
		screens[s] = true
	end)
	-- clima
	setWeather(Workspace:GetAttribute("Clima") or "")
	Workspace:GetAttributeChangedSignal("Clima"):Connect(function()
		setWeather(Workspace:GetAttribute("Clima") or "")
	end)
	RunService.Stepped:Connect(function(_t, dt)
		animate(dt)
	end)
	RunService.RenderStepped:Connect(spin)
	local _ = events
	local _l = Lighting
end

return Ambient
