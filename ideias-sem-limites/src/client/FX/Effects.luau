--!strict
-- Efeitos visuais locais disparados pelo servidor (Fx). Tudo é criado numa
-- pasta local da câmera e removido com Debris: nada fica acumulado.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Settings = require(script.Parent.Parent.Settings)

local Effects = {}

local player = Players.LocalPlayer
local folder: Folder
local hud: any = nil
local movement: any = nil

local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local RAINBOW = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 235, 60), Color3.fromRGB(80, 230, 100), Color3.fromRGB(70, 160, 255), Color3.fromRGB(170, 90, 255) }

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

local function tween(inst: Instance, t: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
	tw:Play()
	return tw
end

local function burst(at: Vector3, texture: string, colors: { Color3 }, count: number, speed: number, size: number, life: number, accel: Vector3?)
	local scale = Settings.quality().particles
	local holder = part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at), Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Enabled = false
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colors[1]))
	end
	e.Color = ColorSequence.new(keys)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 1.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.LightEmission = 0.7
	e.Drag = 2
	if accel then
		e.Acceleration = accel
	end
	e.Parent = holder
	e:Emit(math.max(3, math.floor(count * scale)))
	Debris:AddItem(holder, life + 0.5)
end

local function ring(at: Vector3, radius: number, color: Color3, duration: number?)
	local d = duration or 0.6
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2, 2), CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Transparency = 0.2 })
	tween(p, d, { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(p, d + 0.1)
end

local function sound(id: string, at: Vector3, volume: number?)
	if not Settings.values.sounds then
		return
	end
	local p = part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at), Transparency = 1 })
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.7
	s.RollOffMaxDistance = 400
	s.Parent = p
	s:Play()
	Debris:AddItem(p, 5)
end

local shakeAmount = 0
local function shake(intensity: number)
	if not Settings.values.shake then
		return
	end
	shakeAmount = math.min(shakeAmount + intensity, 3)
end

local tintEffect: ColorCorrectionEffect? = nil
local function tint(color: Color3, duration: number, gray: boolean?)
	if not tintEffect then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TintaLocal"
		cc.Parent = Lighting
		tintEffect = cc
	end
	local cc = tintEffect :: ColorCorrectionEffect
	cc.TintColor = color
	cc.Saturation = if gray then -1 else 0
	cc.Enabled = true
	task.delay(duration, function()
		tween(cc, 0.6, { TintColor = Color3.new(1, 1, 1), Saturation = 0 })
	end)
end

local function zigzag(a: Vector3, b: Vector3, color: Color3, width: number, life: number)
	local segments = 7
	local prev = a
	for i = 1, segments do
		local t = i / segments
		local p = a:Lerp(b, t)
		if i < segments then
			p += Vector3.new(math.random(-40, 40) / 10, 0, math.random(-40, 40) / 10) * (1 - t * 0.5)
		end
		local mid = (prev + p) / 2
		local len = (p - prev).Magnitude
		local seg = part({ Size = Vector3.new(width, width, len), CFrame = CFrame.lookAt(mid, p), Color = color })
		tween(seg, life, { Transparency = 1 })
		Debris:AddItem(seg, life + 0.1)
		prev = p
	end
end

-- manipuladores -----------------------------------------------------------------
local H: { [string]: (any) -> () } = {}

H.ring = function(d)
	ring(d.p, d.r, d.c)
end

H.shake = function(d)
	local dist = (camPos() - d.p).Magnitude
	shake(d.i * math.clamp(1 - dist / 400, 0.1, 1))
end

H.flash = function(d)
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(d.p), Color = d.c, Transparency = 0.1 })
	tween(p, 0.35, { Size = Vector3.new(d.s, d.s, d.s), Transparency = 1 })
	local l = Instance.new("PointLight")
	l.Color = d.c
	l.Range = math.min(d.s * 2, 60)
	l.Brightness = 5
	l.Parent = p
	Debris:AddItem(p, 0.5)
end

H.bolt = function(d)
	local dist = (d.b - d.a).Magnitude
	local t = dist / d.v
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(d.w, d.w, d.w) * 1.6, CFrame = CFrame.new(d.a), Color = d.c })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, d.w * 0.4, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -d.w * 0.4, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(d.c)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = p
	tween(p, t, { CFrame = CFrame.new(d.b) }, Enum.EasingStyle.Linear)
	task.delay(t, function()
		burst(d.b, TEX_SPARK, { d.c }, 10, 12, 0.6, 0.5)
	end)
	Debris:AddItem(p, t + 0.3)
end

H.zap = function(d)
	zigzag(d.a, d.b, d.c, 0.35, 0.25)
end

H.push = function(d)
	if movement then
		movement.push(d.v, d.m)
	end
end

H.tint = function(d)
	tint(d.c, d.d, d.gray)
end

H.toast = function(d)
	if hud then
		hud.toast(d.t, d.c)
	end
end

H.boom = function(d)
	local s = d.s or 1
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4) * s, CFrame = CFrame.new(d.p), Color = Color3.fromRGB(255, 170, 60), Transparency = 0 })
	tween(p, 0.5, { Size = Vector3.new(26, 26, 26) * s, Transparency = 1, Color = Color3.fromRGB(255, 80, 20) })
	Debris:AddItem(p, 0.6)
	burst(d.p, TEX_FIRE, { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 80, 20) }, 30, 30 * s, 3 * s, 0.9)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(90, 85, 80) }, 20, 14 * s, 5 * s, 2.5, Vector3.new(0, 6, 0))
	sound("rbxasset://sounds/collide.wav", d.p, 1)
	shake(0.8 * s * math.clamp(1 - (camPos() - d.p).Magnitude / 300, 0, 1))
end

H.poof = function(d)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(240, 240, 250) }, 18, 10 * (d.s or 1), 2.5 * (d.s or 1), 1.2)
end

H.spawn = function(d)
	ring(d.p, 10 * (d.s or 1), d.c, 0.8)
	burst(d.p + Vector3.new(0, 2, 0), TEX_SPARK, { d.c, Color3.new(1, 1, 1) }, 24, 16, 0.8, 1)
	sound("rbxasset://sounds/electronicpingshort.wav", d.p, 0.5)
end

H.build = function(d)
	ring(d.p, d.r or 20, Color3.fromRGB(230, 220, 200), 1)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(210, 200, 185) }, 26, 18, 4, 1.6)
end

H.confetti = function(d)
	burst(d.p + Vector3.new(0, 3, 0), TEX_SPARK, if d.gold then { Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 255, 200) } else RAINBOW, 60, 30, 0.7, 2, Vector3.new(0, -20, 0))
	sound("rbxasset://sounds/electronicpingshort.wav", d.p, 0.6)
end

H.steam = function(d)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(250, 250, 255) }, 40, 20 * (d.s or 1), 6 * (d.s or 1), 2.5, Vector3.new(0, 10, 0))
end

H.dust = function(d)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(170, 150, 120) }, 14, 10, 3 * (d.s or 1) / 3, 1.2)
end

H.warn = function(d)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, d.r * 2, d.r * 2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 50, 50), Transparency = 0.55 })
	tween(p, math.max(d.d or 1, 0.2), { Transparency = 0.2 })
	Debris:AddItem(p, math.max(d.d or 1, 0.2) + 0.1)
end

H.lightning = function(d)
	local top = d.p + Vector3.new(math.random(-15, 15), 180, math.random(-15, 15))
	zigzag(top, d.p, Color3.fromRGB(220, 240, 255), 0.8, 0.35)
	H.flash({ p = d.p, c = Color3.fromRGB(220, 235, 255), s = 30 })
	tint(Color3.fromRGB(230, 240, 255), 0.08)
	sound("rbxasset://sounds/collide.wav", d.p, 1)
	shake(0.5 * math.clamp(1 - (camPos() - d.p).Magnitude / 300, 0, 1))
end

H.laser = function(d)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(300, 6, 6), CFrame = CFrame.new(d.p + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = d.c, Transparency = 0.1 })
	tween(p, 0.6, { Size = Vector3.new(300, 0.5, 0.5), Transparency = 1 })
	Debris:AddItem(p, 0.7)
	ring(d.p, 12, d.c, 0.5)
end

H.beam = function(d)
	local mid = (d.a + d.b) / 2
	local len = (d.b - d.a).Magnitude
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 8, 8), CFrame = CFrame.lookAt(mid, d.b) * CFrame.Angles(0, math.rad(90), 0), Color = d.c, Transparency = 0.6 })
	tween(p, d.d or 1.5, { Transparency = 1 })
	Debris:AddItem(p, (d.d or 1.5) + 0.1)
end

H.whirl = function(d)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(230, 220, 200) }, 30, 25, 3, 1.5, Vector3.new(0, 25, 0))
end

H.slash = function(d)
	for i = -2, 2 do
		local p = part({ Size = Vector3.new(0.3, 0.3, 4), CFrame = CFrame.new(d.p) * CFrame.Angles(0, i * 0.35, 0), Color = d.c })
		tween(p, 0.25, { Transparency = 1 })
		Debris:AddItem(p, 0.3)
	end
end

H.cone = function(d)
	local dir = (d.b - d.a)
	for k = 1, 6 do
		local at = d.a + dir * (k / 6)
		burst(at, TEX_FIRE, { Color3.fromRGB(255, 220, 90), d.c }, 6, 6, 1 + k * 0.4, 0.5)
	end
end

H.fireworks = function(d)
	for i = 1, d.n or 3 do
		task.delay(i * 0.25, function()
			local from = d.p + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
			local to = from + Vector3.new(math.random(-10, 10), math.random(50, 90), math.random(-10, 10))
			local c = RAINBOW[math.random(1, #RAINBOW)]
			H.bolt({ a = from, b = to, c = c, v = 80, w = 0.6 })
			task.delay((to - from).Magnitude / 80, function()
				burst(to, TEX_SPARK, { c, Color3.new(1, 1, 1) }, 60, 45, 1.2, 1.8, Vector3.new(0, -12, 0))
			end)
		end)
	end
end

H.nuke = function(d)
	local s = d.s or 3
	for k = 0, 4 do
		local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(10, 10, 10), CFrame = CFrame.new(d.p + Vector3.new(0, k * 14 * s * 0.4, 0)), Color = Color3.fromRGB(120, 105, 95), Material = Enum.Material.SmoothPlastic, Transparency = 0.2 })
		tween(p, 2.5, { Size = Vector3.new(30, 30, 30) * s * (if k == 4 then 1.6 else 0.6), Transparency = 1 })
		Debris:AddItem(p, 2.6)
	end
	tint(Color3.fromRGB(255, 220, 190), 1.5)
end

H.power = function(d)
	ring(d.p - Vector3.new(0, 2.5, 0), 8, Color3.fromRGB(255, 230, 120), 0.6)
	burst(d.p, TEX_SPARK, { Color3.fromRGB(255, 240, 160), Color3.fromRGB(140, 220, 255) }, 20, 10, 0.6, 1)
end

H.fly = function(d)
	if movement then
		movement.fly(d.d or 20)
	end
end

H.slowfall = function(d)
	if movement then
		movement.slowfall(d.d or 10)
	end
end

H.shootingstar = function(_d)
	local cam = camPos()
	local from = cam + Vector3.new(math.random(-300, 300), 260, math.random(-300, 300))
	local to = from + Vector3.new(math.random(-200, 200), -80, math.random(-200, 200))
	H.bolt({ a = from, b = to, c = Color3.fromRGB(255, 255, 230), v = 260, w = 1 })
end

function Effects.handle(data: any)
	if type(data) ~= "table" then
		return
	end
	local f = H[data.k]
	if f then
		local ok, err = pcall(f, data)
		if not ok then
			warn("[Ideias] efeito " .. tostring(data.k) .. ": " .. tostring(err))
		end
	end
end

function Effects.init(hudModule: any, movementModule: any)
	hud = hudModule
	movement = movementModule
	folder = Instance.new("Folder")
	folder.Name = "EfeitosLocais"
	folder.Parent = Workspace.CurrentCamera or Workspace
	-- tremor aplicado logo depois da câmera padrão (prioridade Camera + 1)
	RunService:BindToRenderStep("IdeiasTremor", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shakeAmount > 0.01 then
			local cam = Workspace.CurrentCamera
			if cam then
				local a = shakeAmount * 0.35
				cam.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * a * 4), math.rad((math.random() - 0.5) * a * 4), 0)
			end
			shakeAmount = math.max(0, shakeAmount - dt * 2.5)
		end
	end)
end

Effects.folder = function()
	return folder
end
Effects.burst = burst
Effects.part = part
Effects._player = player

return Effects
