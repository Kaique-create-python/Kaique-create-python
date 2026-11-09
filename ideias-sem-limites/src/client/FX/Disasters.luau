--!strict
-- Visual local dos desastres em movimento (meteoros, tornados, tsunami,
-- buraco negro, tempestade). Lê os atributos Fx* da pasta do acontecimento e
-- usa as MESMAS trajetórias do servidor (FxPaths): movimento suave a 60 fps
-- sem nenhum tráfego de rede por quadro.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FxPaths = require(ReplicatedStorage:WaitForChild("IdeiasShared").FxPaths)
local Settings = require(script.Parent.Parent.Settings)

local Disasters = {}

type Active = { folder: Instance, kind: string, spec: FxPaths.Spec, model: Model, update: (number) -> (), stop: () -> () }

local active: { [Instance]: Active } = {}
local root: Folder

local ELEMENT_COLORS = {
	fire = Color3.fromRGB(255, 120, 40),
	ice = Color3.fromRGB(160, 225, 255),
	electric = Color3.fromRGB(255, 240, 100),
	poison = Color3.fromRGB(120, 230, 70),
	water = Color3.fromRGB(70, 160, 255),
	shadow = Color3.fromRGB(110, 60, 170),
	light = Color3.fromRGB(255, 245, 190),
	lava = Color3.fromRGB(255, 90, 20),
	wind = Color3.fromRGB(225, 235, 245),
	rainbow = Color3.fromRGB(255, 120, 220),
	stone = Color3.fromRGB(120, 110, 100),
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function newPart(model: Model, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

local function emitter(parent: Instance, texture: string, color: Color3, rate: number, opts: { [string]: any }?): ParticleEmitter
	local o = opts or {}
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Rate = rate * Settings.quality().particles
	e.Lifetime = o.lifetime or NumberRange.new(0.6, 1.2)
	e.Speed = o.speed or NumberRange.new(2, 5)
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.Size = o.size or NumberSequence.new(1)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = o.light or 0.5
	if o.accel then
		e.Acceleration = o.accel
	end
	e.Parent = parent
	return e
end

-- clones locais do "molde" (recheio: tubarões no tornado, pizzas na onda...)
local function payloadClones(folder: Instance, model: Model, n: number): { Model }
	local mold = folder:FindFirstChild("Molde")
	local out = {}
	if mold and mold:IsA("Model") then
		for _ = 1, n do
			local c = mold:Clone()
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				elseif d:IsA("Script") or d:IsA("Humanoid") then
					d:Destroy()
				end
			end
			c.Parent = model
			table.insert(out, c)
		end
	end
	return out
end

local BUILD: { [string]: (Instance, FxPaths.Spec, Model, Color3) -> ((number) -> ()) } = {}

BUILD.meteor = function(folder, spec, model, color)
	local parentFolder = folder.Parent
	local clones = if parentFolder then payloadClones(parentFolder, model, 1) else {}
	local rock: BasePart
	local mold: Model? = clones[1]
	if mold then
		rock = newPart(model, { Size = Vector3.new(1, 1, 1), Transparency = 1 })
	else
		rock = newPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * spec.radius * 0.8, Color = Color3.fromRGB(70, 55, 50), Material = Enum.Material.Basalt })
		local glow = newPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * spec.radius * 0.95, Color = color, Material = Enum.Material.Neon, Transparency = 0.55 })
		glow.Name = "Brilho"
	end
	local fireE = emitter(rock, "rbxasset://textures/particles/fire_main.dds", color, 60, { speed = NumberRange.new(1, 3), size = NumberSequence.new(spec.radius * 0.6, spec.radius * 0.1), lifetime = NumberRange.new(0.4, 0.8), light = 1 })
	local _ = fireE
	local smoke = emitter(rock, "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(80, 70, 65), 20, { speed = NumberRange.new(0, 1), size = NumberSequence.new(spec.radius * 0.4, spec.radius), lifetime = NumberRange.new(1, 2) })
	local _s = smoke
	return function(t)
		local pos, a = FxPaths.meteor(spec, t)
		local visible = t >= spec.t0 and a < 1
		local cf = CFrame.lookAt(pos, pos + spec.vel)
		rock.CFrame = cf
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Brilho" then
				d.CFrame = cf
				d.Transparency = if visible then 0.55 else 1
			end
		end
		rock.Transparency = if visible and not mold then 0 else 1
		for _, e in rock:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = visible
			end
		end
		if mold then
			mold:PivotTo(cf * CFrame.Angles(t * 3, t * 2, 0))
		end
	end
end

BUILD.tornado = function(folder, spec, model, color)
	local rings = {}
	local levels = 9
	for i = 1, levels do
		local f = i / levels
		local r = spec.radius * (0.25 + f * 0.9)
		local p = newPart(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(spec.height / levels * 0.9, r * 2, r * 2),
			Color = color:Lerp(Color3.fromRGB(150, 150, 160), 0.4),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.55 + f * 0.15,
		})
		table.insert(rings, { part = p, y = spec.height * (f - 0.5 / levels), r = r })
	end
	local core = newPart(model, { Size = Vector3.new(4, spec.height, 4), Transparency = 1 })
	emitter(core, "rbxasset://textures/particles/smoke_main.dds", color, 40, { speed = NumberRange.new(6, 14), size = NumberSequence.new(spec.radius * 0.3, spec.radius * 0.8), lifetime = NumberRange.new(1, 2), accel = Vector3.new(0, 20, 0) })
	local debris = {}
	for i = 1, 14 do
		table.insert(debris, newPart(model, { Size = Vector3.new(1.4, 1.4, 1.4), Color = Color3.fromRGB(110, 95, 80), Material = Enum.Material.Wood }))
	end
	local clones = payloadClones(folder, model, 5)
	return function(t)
		local c = FxPaths.tornado(spec, t)
		local spin = t * 3
		for _, r in rings do
			r.part.CFrame = CFrame.new(c + Vector3.new(0, r.y, 0)) * CFrame.Angles(0, spin, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		core.CFrame = CFrame.new(c + Vector3.new(0, spec.height / 2, 0))
		for i, d in debris do
			local a = spin * 1.4 + i * 0.9
			local h = (i / #debris) * spec.height * 0.8
			local rr = spec.radius * (0.4 + i / #debris)
			d.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * rr, h, math.sin(a) * rr)) * CFrame.Angles(a, a, 0)
		end
		for i, m in clones do
			local a = spin * 1.1 + i * (math.pi * 2 / #clones)
			local h = spec.height * (0.25 + 0.12 * i)
			local rr = spec.radius * (0.7 + 0.1 * i)
			m:PivotTo(CFrame.new(c + Vector3.new(math.cos(a) * rr, h, math.sin(a) * rr)) * CFrame.Angles(0, -a, 0.5))
		end
	end
end

BUILD.tsunami = function(folder, spec, model, color)
	local width = spec.radius * 2
	local dir = if spec.vel.Magnitude > 0 then spec.vel.Unit else Vector3.xAxis
	local wall = newPart(model, { Size = Vector3.new(width, spec.height, spec.height * 1.1), Color = color, Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.2 })
	local wedgeClass = Instance.new("WedgePart")
	wedgeClass.Anchored = true
	wedgeClass.CanCollide = false
	wedgeClass.CanQuery = false
	wedgeClass.CastShadow = false
	wedgeClass.Size = Vector3.new(width, spec.height, spec.height * 1.4)
	wedgeClass.Color = color
	wedgeClass.Material = Enum.Material.Glass
	wedgeClass.Transparency = 0.3
	wedgeClass.Parent = model
	local foam = newPart(model, { Size = Vector3.new(width, 3, 6), Color = Color3.fromRGB(240, 250, 255), Material = Enum.Material.SmoothPlastic })
	emitter(foam, "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(245, 250, 255), 60, { speed = NumberRange.new(3, 8), size = NumberSequence.new(3, 6), lifetime = NumberRange.new(0.8, 1.4) })
	local clones = payloadClones(folder, model, 6)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	return function(t)
		local front = FxPaths.wave(spec, t)
		local visible = t >= spec.t0 - 0.5
		local base = CFrame.lookAt(front, front + dir)
		wall.CFrame = base * CFrame.new(0, spec.height / 2 - 2, spec.height * 0.55)
		wedgeClass.CFrame = base * CFrame.new(0, spec.height / 2 - 2, -spec.height * 0.15) * CFrame.Angles(0, math.pi, 0)
		foam.CFrame = base * CFrame.new(0, spec.height - 1, 0)
		wall.Transparency = if visible then 0.25 else 1
		wedgeClass.Transparency = if visible then 0.3 else 1
		foam.Transparency = if visible then 0 else 1
		for i, m in clones do
			local lat = (i - (#clones + 1) / 2) * (width / (#clones + 1))
			m:PivotTo(CFrame.new(front + right * lat + Vector3.new(0, spec.height + 2 + math.sin(t * 3 + i) * 2, 0)) * CFrame.Angles(t + i, t * 0.7, 0))
		end
	end
end

BUILD.black_hole = function(folder, spec, model, _color)
	local core = newPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(5, 5, 8), Material = Enum.Material.SmoothPlastic })
	local halo = newPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(120, 80, 220), Material = Enum.Material.ForceField, Transparency = 0.2 })
	local disk = newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1, 1), Color = Color3.fromRGB(255, 160, 70), Material = Enum.Material.Neon, Transparency = 0.15 })
	local disk2 = newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1, 1), Color = Color3.fromRGB(190, 120, 255), Material = Enum.Material.Neon, Transparency = 0.3 })
	emitter(halo, "rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(200, 160, 255), 50, { speed = NumberRange.new(-20, -10), size = NumberSequence.new(1.5), lifetime = NumberRange.new(1, 1.5), light = 1 })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 120, 255)
	light.Range = 60
	light.Brightness = 3
	light.Parent = disk
	local clones = payloadClones(folder, model, 6)
	return function(t)
		local p = FxPaths.progress(spec, t)
		local grow = math.min(1, p * 5)
		local collapse = if p > 0.95 then (1 - p) / 0.05 else 1
		local r = spec.radius * grow * collapse
		local c = spec.pos
		core.CFrame = CFrame.new(c)
		core.Size = Vector3.new(1, 1, 1) * math.max(r * 2, 0.1)
		halo.CFrame = CFrame.new(c)
		halo.Size = Vector3.new(1, 1, 1) * math.max(r * 2.6, 0.1)
		disk.CFrame = CFrame.new(c) * CFrame.Angles(0.35, t * 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		disk.Size = Vector3.new(0.6, r * 5, r * 5)
		disk2.CFrame = CFrame.new(c) * CFrame.Angles(0.35, -t * 3, 0) * CFrame.Angles(0, 0, math.rad(90))
		disk2.Size = Vector3.new(0.4, r * 3.6, r * 3.6)
		for i, m in clones do
			local a = t * 2 + i
			local rr = r * (3 - (t % 3))
			m:PivotTo(CFrame.new(c + Vector3.new(math.cos(a) * rr, math.sin(a * 2) * 2, math.sin(a) * rr)) * CFrame.Angles(a, a, 0))
		end
	end
end

BUILD.storm = function(folder, _spec, model, _color)
	local center = folder:GetAttribute("FxPos") :: Vector3? or Vector3.zero
	local clouds = {}
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = newPart(model, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(80, 80, 80),
			Color = Color3.fromRGB(60, 62, 72),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.35,
			CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 60, 120, math.sin(a) * 60)),
		})
		table.insert(clouds, p)
	end
	return function(t)
		for i, p in clouds do
			p.CFrame = p.CFrame * CFrame.new(math.sin(t * 0.3 + i) * 0.05, 0, 0)
		end
	end
end

BUILD.wind = function(folder, _spec, model, _color)
	local dir = folder:GetAttribute("FxVel") :: Vector3? or Vector3.xAxis
	local holder = newPart(model, { Size = Vector3.new(1, 1, 1), Transparency = 1 })
	local e = emitter(holder, "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(240, 245, 255), 30, { speed = NumberRange.new(40, 60), spread = Vector2.new(5, 30), size = NumberSequence.new(0.6, 2), lifetime = NumberRange.new(1, 2) })
	e.EmissionDirection = Enum.NormalId.Front
	return function(_t)
		local cam = Workspace.CurrentCamera
		if cam then
			local p = cam.CFrame.Position - dir * 40 + Vector3.new(0, 5, 0)
			holder.CFrame = CFrame.lookAt(p, p + dir)
		end
	end
end

local function attach(folder: Instance)
	if active[folder] then
		return
	end
	local kind = folder:GetAttribute("FxKind")
	if type(kind) ~= "string" or not BUILD[kind] then
		return
	end
	local spec = FxPaths.fromFolder(folder)
	local element = folder:GetAttribute("FxElement")
	local color = ELEMENT_COLORS[element or ""] or Color3.fromRGB(200, 200, 210)
	local model = Instance.new("Model")
	model.Name = "Visual_" .. kind
	model.Parent = root
	local ok, update = pcall(BUILD[kind], folder, spec, model, color)
	if not ok then
		warn("[Ideias] visual " .. kind .. ": " .. tostring(update))
		model:Destroy()
		return
	end
	active[folder] = {
		folder = folder,
		kind = kind,
		spec = spec,
		model = model,
		update = update,
		stop = function()
			model:Destroy()
		end,
	}
end

local function scan(inst: Instance)
	if inst:IsA("Folder") then
		if inst:GetAttribute("FxKind") then
			attach(inst)
		end
		inst:GetAttributeChangedSignal("FxKind"):Connect(function()
			attach(inst)
		end)
	end
end

function Disasters.init()
	root = Instance.new("Folder")
	root.Name = "DesastresLocais"
	root.Parent = Workspace.CurrentCamera or Workspace
	local events = Workspace:WaitForChild("IdeiasEventos", 30)
	if not events then
		return
	end
	for _, d in events:GetDescendants() do
		scan(d)
	end
	events.DescendantAdded:Connect(scan)
	RunService.RenderStepped:Connect(function()
		local t = now()
		for folder, a in active do
			if not folder.Parent then
				a.stop()
				active[folder] = nil
			else
				local ok = pcall(a.update, t)
				if not ok then
					a.stop()
					active[folder] = nil
				end
			end
		end
	end)
end

return Disasters
