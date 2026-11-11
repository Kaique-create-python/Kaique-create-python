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
local Config = require(game:GetService("ReplicatedStorage").IdeiasShared.Config)

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
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 35
	s.RollOffMaxDistance = 600
	s.Parent = p
	s:Play()
	Debris:AddItem(p, 5)
end

local spriteState = "unknown" -- unknown | loading | ok | failed | off
local announced = false

-- confere se o áudio do ElevenLabs carregou de verdade (aprovado na moderação e com
-- duração). Enquanto não, os sons embutidos do Roblox são usados.
function Effects.checkSprite()
	local sp = Config.SoundSprite
	if sp.Id == 0 then
		spriteState = "off"
		return
	end
	if spriteState == "loading" then
		return
	end
	spriteState = "loading"
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.SoundId = "rbxassetid://" .. tostring(sp.Id)
		probe.Volume = 0
		probe.Parent = game:GetService("SoundService")
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ probe })
		end)
		local t0 = os.clock()
		while not probe.IsLoaded and os.clock() - t0 < 10 do
			task.wait(0.25)
		end
		spriteState = if probe.IsLoaded and probe.TimeLength > 1 then "ok" else "failed"
		if spriteState == "failed" then
			warn("[Ideias] áudio " .. tostring(sp.Id) .. " ainda não carregou (moderação, permissão ou conexão): usando sons do Roblox")
		end
		if not announced and hud and hud.toast then
			announced = true
			if spriteState == "ok" then
				hud.toast("🔊 Sons do jogo carregados!", Color3.fromRGB(110, 235, 150))
			else
				hud.toast("🔊 Áudio indisponível: usando sons padrão. Confira moderação, permissão e conexão.", Color3.fromRGB(255, 200, 90))
			end
		end
		probe:Destroy()
	end)
end

function Effects.soundStatus(): string
	return spriteState
end
-- som de um efeito: trecho do sprite do ElevenLabs ou som embutido (fallback)
local function cue(name: string, at: Vector3?, volume: number?)
	if not Settings.values.sounds then
		return
	end
	local c = Config.SoundCues[name]
	if not c then
		return
	end
	local sp = Config.SoundSprite
	local s = Instance.new("Sound")
	local region = c.sprite and sp.Regions[c.sprite]
	if spriteState == "unknown" then
		Effects.checkSprite()
	end
	if sp.Id ~= 0 and region and spriteState == "ok" and Settings.values.soundSource ~= "roblox" then
		s.SoundId = "rbxassetid://" .. tostring(sp.Id)
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[2])
	else
		s.SoundId = c.fallback
	end
	s.Volume = (volume or 1) * (c.volume or 0.7)
	s.PlaybackSpeed = c.speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 35
	s.RollOffMaxDistance = 700
	if at then
		local holder = part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at), Transparency = 1 })
		s.Parent = holder
		Debris:AddItem(holder, 6)
	else
		s.Parent = game:GetService("SoundService")
		Debris:AddItem(s, 6)
	end
	s:Play()
end
Effects.cue = cue

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
	cue("explosion", d.p, 1)
	shake(0.8 * s * math.clamp(1 - (camPos() - d.p).Magnitude / 300, 0, 1))
	ring(d.p - Vector3.new(0, 1, 0), 18 * s, Color3.fromRGB(190, 170, 150), 0.7)
	debrisBurst(d.p, math.floor(6 + 6 * s), 0.8 + 0.4 * s, Color3.fromRGB(90, 80, 72))
	local l = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(d.p), Transparency = 1 })
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 160, 70)
	pl.Range = math.min(30 * s, 60)
	pl.Brightness = 6
	pl.Parent = l
	tween(pl, 1.2, { Brightness = 0 })
	Debris:AddItem(l, 1.3)
end

H.poof = function(d)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(240, 240, 250) }, 18, 10 * (d.s or 1), 2.5 * (d.s or 1), 1.2)
	cue("poof", d.p, 0.6)
end

H.spawn = function(d)
	ring(d.p, 10 * (d.s or 1), d.c, 0.8)
	burst(d.p + Vector3.new(0, 2, 0), TEX_SPARK, { d.c, Color3.new(1, 1, 1) }, 24, 16, 0.8, 1)
	-- coluna de luz rápida: o "portal" de onde a ideia sai
	local col = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(40, 3, 3) * (d.s or 1), CFrame = CFrame.new(d.p + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = d.c, Transparency = 0.35 })
	tween(col, 0.7, { Size = Vector3.new(40, 0.2, 0.2) * (d.s or 1), Transparency = 1 })
	Debris:AddItem(col, 0.8)
	cue(d.snd or "create", d.p, 0.8)
	if d.big then
		local evil = d.c and d.c.R > 0.8 and d.c.G < 0.5
		local col = if evil then Color3.fromRGB(255, 50, 40) else Color3.fromRGB(255, 230, 140)
		cue(if evil then "demon_spawn" else "hero_spawn", nil, 1)
		ring(d.p, 26 * (d.s or 1), col, 1.4)
		for i = 1, 3 do
			task.delay(i * 0.18, function()
				local top = d.p + Vector3.new(math.random(-20, 20), 140, math.random(-20, 20))
				zigzag(top, d.p + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)), if evil then Color3.fromRGB(255, 90, 80) else Color3.fromRGB(220, 240, 255), 0.7, 0.3)
			end)
		end
		local portal = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2, 2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = if evil then Color3.fromRGB(30, 0, 0) else Color3.fromRGB(255, 250, 220), Transparency = 0.1 })
		tween(portal, 0.6, { Size = Vector3.new(0.6, 30 * (d.s or 1), 30 * (d.s or 1)) })
		task.delay(1.6, function()
			tween(portal, 0.8, { Transparency = 1 })
		end)
		Debris:AddItem(portal, 2.5)
		burst(d.p, if evil then TEX_FIRE else TEX_SPARK, { col, Color3.new(1, 1, 1) }, 60, 30, 3, 1.6, Vector3.new(0, 20, 0))
		shake(0.8 * math.clamp(1 - (camPos() - d.p).Magnitude / 300, 0, 1))
		H.flash({ p = d.p + Vector3.new(0, 6, 0), c = col, s = 40 })
	end
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
	cue("thunder", d.p, 1)
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
	local base = d.p
	-- clarão que cega e som profundo
	tint(Color3.fromRGB(255, 250, 235), 0.9)
	cue("mega_impact", nil, 1)
	cue("explosion", base, 1)
	task.delay(0.25, function()
		cue("rumble", base, 1)
	end)
	local fire = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(base), Color = Color3.fromRGB(255, 240, 200), Transparency = 0 })
	tween(fire, 1.2, { Size = Vector3.new(60, 60, 60) * (s / 3), Color = Color3.fromRGB(255, 120, 30), Transparency = 0.3 })
	Debris:AddItem(fire, 2.6)
	task.delay(1.2, function()
		tween(fire, 1.3, { Transparency = 1 })
	end)
	-- onda de choque rasteira
	local wave = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 10, 10), CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 230, 200), Transparency = 0.2 })
	tween(wave, 2.2, { Size = Vector3.new(3, 420 * (s / 3), 420 * (s / 3)), Transparency = 1 })
	Debris:AddItem(wave, 2.3)
	-- cogumelo: haste subindo + chapéu que cresce
	local stem = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 14, 14), CFrame = CFrame.new(base + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 110, 90), Material = Enum.Material.SmoothPlastic, Transparency = 0.1 })
	local cap = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(20, 20, 20), CFrame = CFrame.new(base + Vector3.new(0, 10, 0)), Color = Color3.fromRGB(255, 140, 60), Material = Enum.Material.SmoothPlastic, Transparency = 0.05 })
	local height = 90 * (s / 3)
	tween(stem, 4, { Size = Vector3.new(height, 18 * (s / 3), 18 * (s / 3)), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 95, 85) })
	tween(cap, 4, { Size = Vector3.new(80, 45, 80) * (s / 3), CFrame = CFrame.new(base + Vector3.new(0, height, 0)), Color = Color3.fromRGB(120, 100, 90) })
	burst(base + Vector3.new(0, height * 0.5, 0), TEX_SMOKE, { Color3.fromRGB(140, 120, 110), Color3.fromRGB(80, 70, 65) }, 80, 30, 18, 6, Vector3.new(0, 8, 0))
	burst(base, TEX_FIRE, { Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 80, 20) }, 80, 60, 8, 2)
	debrisBurst(base, 24, 2.5, Color3.fromRGB(80, 70, 60))
	task.delay(4, function()
		tween(stem, 4, { Transparency = 1 })
		tween(cap, 4, { Transparency = 1 })
	end)
	Debris:AddItem(stem, 8.2)
	Debris:AddItem(cap, 8.2)
	shake(3)
	task.delay(0.8, function()
		shake(2)
	end)
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

-- EFEITOS DOS NOVOS PODERES --------------------------------------------------------
H.charge = function(d)
	local s = d.s or 1
	local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(d.p + Vector3.new(0, 1.5 * s, 0)), Color = d.c, Transparency = 0.2 })
	tween(ball, d.d or 0.9, { Size = Vector3.new(5, 5, 5) * s, Transparency = 0.5 })
	Debris:AddItem(ball, (d.d or 0.9) + 0.1)
	ring(d.p, 7 * s, d.c, d.d or 0.9)
	burst(d.p, TEX_SPARK, { d.c, Color3.new(1, 1, 1) }, 40, 8, 0.7, 0.9, Vector3.new(0, 20, 0))
	cue("charge", d.p, 1)
end

H.kame = function(d)
	local mid = (d.a + d.b) / 2
	local len = (d.b - d.a).Magnitude
	local w = d.w or 2.5
	local cf = CFrame.lookAt(mid, d.b) * CFrame.Angles(0, math.rad(90), 0)
	local outer = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, w * 2.2, w * 2.2), CFrame = cf, Color = d.c, Transparency = 0.35 })
	local core = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, w, w), CFrame = cf, Color = Color3.new(1, 1, 1), Transparency = 0 })
	tween(outer, 1.1, { Size = Vector3.new(len, 0.3, 0.3), Transparency = 1 })
	tween(core, 1.1, { Size = Vector3.new(len, 0.1, 0.1), Transparency = 1 })
	Debris:AddItem(outer, 1.2)
	Debris:AddItem(core, 1.2)
	H.flash({ p = d.b, c = d.c, s = 18 })
	burst(d.b, TEX_SPARK, { d.c, Color3.new(1, 1, 1) }, 50, 40, 1.2, 1)
	cue("beam", d.a, 1)
end

H.punch = function(d)
	local s = d.s or 1
	ring(d.p, 16 * s, Color3.fromRGB(255, 255, 255), 0.5)
	ring(d.p + Vector3.new(0, 2, 0), 10 * s, Color3.fromRGB(255, 230, 120), 0.35)
	H.flash({ p = d.p, c = Color3.fromRGB(255, 250, 220), s = 14 * s })
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(230, 225, 215) }, 25, 35, 3, 1)
	cue("punch", d.p, 1)
	shake(1.2 * math.clamp(1 - (camPos() - d.p).Magnitude / 300, 0, 1))
end

H.web = function(d)
	zigzag(d.a, d.b, Color3.fromRGB(245, 245, 250), 0.15, 0.6)
	for k = 0, 3 do
		local p = part({ Size = Vector3.new(0.1, 0.1, 5), CFrame = CFrame.new(d.b) * CFrame.Angles(0, k * math.pi / 4, 0), Color = Color3.fromRGB(245, 245, 250), Material = Enum.Material.SmoothPlastic })
		tween(p, 2.5, { Transparency = 1 })
		Debris:AddItem(p, 2.6)
	end
	cue("launch", d.a, 0.5)
end

H.lasereyes = function(d)
	for _, off in { -0.25, 0.25 } do
		local a = d.a + Vector3.new(off, 0, 0)
		local mid = (a + d.b) / 2
		local len = (d.b - a).Magnitude
		local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, 0.35, 0.35), CFrame = CFrame.lookAt(mid, d.b) * CFrame.Angles(0, math.rad(90), 0), Color = d.c })
		tween(p, 0.4, { Transparency = 1 })
		Debris:AddItem(p, 0.5)
	end
	burst(d.b, TEX_FIRE, { d.c, Color3.fromRGB(255, 220, 90) }, 14, 12, 1, 0.6)
	cue("laser", d.a, 0.9)
end

H.holy = function(d)
	local dur = d.d or 10
	local pillar = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(400, 14, 14), CFrame = CFrame.new(d.p + Vector3.new(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 240, 190), Transparency = 0.55 })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 240, 190)
	l.Range = 60
	l.Brightness = 3
	l.Parent = pillar
	tween(pillar, dur, { Transparency = 1, Size = Vector3.new(400, 4, 4) })
	Debris:AddItem(pillar, dur + 0.2)
	ring(d.p, d.r or 40, Color3.fromRGB(255, 235, 170), 2)
	burst(d.p + Vector3.new(0, 4, 0), TEX_SPARK, { Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 225, 140) }, 80, 12, 1, 3, Vector3.new(0, 6, 0))
	-- pombas brancas circulando
	for i = 1, 6 do
		local dove = part({ Size = Vector3.new(1.2, 0.3, 0.8), Color = Color3.fromRGB(250, 250, 255), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(d.p) })
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t > dur or not dove.Parent then
				conn:Disconnect()
				dove:Destroy()
				return
			end
			local a = t * 0.9 + i * math.pi / 3
			local pos = d.p + Vector3.new(math.cos(a) * 14, 12 + math.sin(t * 2 + i) * 2, math.sin(a) * 14)
			dove.CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
		end)
	end
	tint(Color3.fromRGB(255, 245, 220), 1.2)
	cue("holy", d.p, 1)
end

H.calm = function(d)
	burst(d.p + Vector3.new(0, 4, 0), TEX_SPARK, { Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 200, 230) }, 12, 4, 0.6, 1.5, Vector3.new(0, 4, 0))
end

H.poop = function(d)
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(120, 85, 50), Color3.fromRGB(160, 120, 70) }, 22, 10 * (d.s or 1), 2.5 * (d.s or 1), 1.4)
	cue("fart", d.p, 1)
end

H.launch = function(d)
	local t = d.t or 0.8
	local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(d.a), Color = d.c or Color3.fromRGB(255, 220, 120) })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.5, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(d.c or Color3.fromRGB(255, 220, 120))
	trail.LightEmission = 1
	trail.Parent = ball
	local t0 = os.clock()
	local h = math.max(8, (d.b - d.a).Magnitude * 0.35)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / t, 0, 1)
		ball.CFrame = CFrame.new(d.a:Lerp(d.b, k) + Vector3.new(0, math.sin(k * math.pi) * h, 0))
		if k >= 1 then
			conn:Disconnect()
			ball:Destroy()
			H.poof({ p = d.b, s = 1.2 })
		end
	end)
	cue("launch", d.a, 1)
end

H.notes = function(d)
	for i = 1, 6 do
		task.delay(i * 0.2, function()
			local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(d.p + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))), Color = RAINBOW[(i % #RAINBOW) + 1] })
			tween(p, 1.4, { CFrame = p.CFrame + Vector3.new(math.random(-2, 2), 7, math.random(-2, 2)), Transparency = 1 })
			Debris:AddItem(p, 1.5)
		end)
	end
end

H.fuse = function(d)
	local dur = d.d or 1.1
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(d.p + Vector3.new(0, 2, 0)), Color = Color3.fromRGB(255, 60, 40), Transparency = 0.5 })
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < dur and p.Parent do
			p.Transparency = if p.Transparency > 0.6 then 0.3 else 0.85
			task.wait(0.12)
		end
		p:Destroy()
	end)
	cue("hiss", d.p, 1)
end

H.petrify = function(d)
	H.flash({ p = d.p, c = Color3.fromRGB(170, 170, 160), s = 10 })
	burst(d.p, TEX_SMOKE, { Color3.fromRGB(150, 150, 145) }, 16, 8, 2, 1.2)
	cue("crack", d.p, 1)
end

H.drum = function(d)
	for k = 0, 2 do
		task.delay(k * 0.35, function()
			ring(d.p, (d.r or 14) * (0.6 + k * 0.2), Color3.fromRGB(200, 150, 90), 0.4)
			cue("drum", d.p, 1)
			shake(0.35 * math.clamp(1 - (camPos() - d.p).Magnitude / 200, 0, 1))
		end)
	end
end

-- CENA CINEMATOGRÁFICA: algo grande apareceu -------------------------------------------
local inCutscene = false
function Effects.busy(): boolean
	return inCutscene
end

H.cutscene = function(d)
	if inCutscene or Settings.values.cutscenes == false then
		return
	end
	local cam = Workspace.CurrentCamera
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not cam or not pg then
		return
	end
	inCutscene = true
	local disaster = d.k == "disaster"
	local gui = Instance.new("ScreenGui")
	gui.Name = "IdeiasCena"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.Parent = pg
	local bars = {}
	for _, top in { true, false } do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = if top then Vector2.new(0, 0) else Vector2.new(0, 1)
		f.Position = if top then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 1)
		f.Size = UDim2.new(1, 0, 0, 0)
		f.Parent = gui
		tween(f, 0.35, { Size = UDim2.new(1, 0, 0.11, 0) })
		table.insert(bars, f)
	end
	local color = if d.evil then Color3.fromRGB(255, 70, 60) elseif disaster then Color3.fromRGB(255, 190, 80) else Color3.fromRGB(255, 240, 200)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.74)
	title.Size = UDim2.fromScale(0.9, 0.11)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Text = string.upper(tostring(d.t or ""))
	title.TextColor3 = color
	title.TextTransparency = 1
	title.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Parent = title
	local sub = title:Clone()
	sub.Text = if disaster then "ESTÁ CHEGANDO!" else "APARECEU!"
	sub.Position = UDim2.fromScale(0.5, 0.82)
	sub.Size = UDim2.fromScale(0.6, 0.05)
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Parent = gui
	task.delay(0.45, function()
		tween(title, 0.4, { TextTransparency = 0 })
		tween(stroke, 0.4, { Transparency = 0 })
		tween(sub, 0.4, { TextTransparency = 0 })
		local s2 = sub:FindFirstChildOfClass("UIStroke")
		if s2 then
			tween(s2, 0.4, { Transparency = 0 })
		end
	end)
	cue(if d.evil then "demon_spawn" elseif disaster then "rumble" else "hero_spawn", nil, 1)
	local old = cam.CFrame
	local oldType = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	local h = d.h or 8
	local target = d.p + Vector3.new(0, h * 0.55, 0)
	local dist = math.clamp(h * 2.6, 24, 150)
	if disaster then
		target = d.p + Vector3.new(0, 30, 0)
		dist = 110
	end
	local rel = old.Position - target
	local a0 = math.atan2(rel.Z, rel.X)
	local t0 = os.clock()
	local dur = 3.4
	local skip = false
	local conn = game:GetService("UserInputService").InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if os.clock() - t0 > 0.6 then
				skip = true
			end
		end
	end)
	shake(0.6)
	local function finish()
		RunService:UnbindFromRenderStep("IdeiasCena")
		conn:Disconnect()
		pcall(function()
			cam.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
		end)
		for _, f in bars do
			tween(f, 0.3, { Size = UDim2.new(1, 0, 0, 0) })
		end
		tween(title, 0.3, { TextTransparency = 1 })
		tween(sub, 0.3, { TextTransparency = 1 })
		Debris:AddItem(gui, 0.4)
		inCutscene = false
	end
	RunService:BindToRenderStep("IdeiasCena", Enum.RenderPriority.Camera.Value + 2, function()
		local k = (os.clock() - t0) / dur
		if k >= 1 or skip then
			finish()
			return
		end
		local e = k * k * (3 - 2 * k)
		local ang = a0 + math.rad(55) * e
		local r = dist * (1.25 - 0.35 * e)
		local pos = Vector3.new(target.X + math.cos(ang) * r, target.Y + dist * (0.35 - 0.2 * e), target.Z + math.sin(ang) * r)
		local cf = CFrame.lookAt(pos, target)
		if k < 0.18 then
			cf = old:Lerp(cf, (k / 0.18) ^ 2)
		end
		cam.CFrame = cf
	end)
end

-- TERREMOTO: poeira subindo das rachaduras e tremor contínuo --------------------------
H.quake = function(d)
	local dur = d.d or 12
	for i = 0, math.floor(dur / 0.8) do
		task.delay(i * 0.8, function()
			local a = math.random() * math.pi * 2
			local r = math.random() * (d.r or 50)
			local p = d.p + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			burst(p, TEX_SMOKE, { Color3.fromRGB(160, 140, 115), Color3.fromRGB(120, 105, 90) }, 14, 14, 4, 1.8, Vector3.new(0, 6, 0))
			local dist = (camPos() - d.p).Magnitude
			shake(0.25 * math.clamp(1 - dist / 400, 0, 1))
			if i % 3 == 0 then
				cue("rumble", d.p, 0.8)
			end
		end)
	end
	tint(Color3.fromRGB(200, 170, 140), 1.2)
end

-- destroços físicos voando (só no cliente: não pesa o servidor)
local function debrisBurst(at: Vector3, n: number, size: number, color: Color3)
	local q = math.max(1, math.floor(n * Settings.quality().particles))
	for _ = 1, q do
		local rock = Instance.new("Part")
		rock.Size = Vector3.new(1, 1, 1) * size * (0.5 + math.random())
		rock.Color = color
		rock.Material = Enum.Material.Slate
		rock.CanQuery = false
		rock.CanTouch = false
		rock.CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		rock.Parent = folder
		local dir = Vector3.new(math.random() - 0.5, 0.6 + math.random() * 0.8, math.random() - 0.5).Unit
		rock.AssemblyLinearVelocity = dir * (40 + math.random() * 50) * math.sqrt(size)
		rock.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		Debris:AddItem(rock, 4)
	end
end
Effects.debrisBurst = debrisBurst

-- BURACO NEGRO: aviso (céu escurece, pedras sobem) e colapso final ---------------------
H.bh_warn = function(d)
	tint(Color3.fromRGB(120, 90, 180), d.d or 1.5)
	cue("rumble", d.p, 1)
	for i = 1, 24 do
		task.delay(math.random() * (d.d or 1.5), function()
			local at = d.p + Vector3.new(math.random(-80, 80), -30 + math.random(0, 10), math.random(-80, 80))
			local rock = part({ Size = Vector3.new(1, 1, 1) * (0.8 + math.random() * 2), CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Color = Color3.fromRGB(90, 85, 80), Material = Enum.Material.Slate })
			tween(rock, 2.5 + math.random(), { CFrame = CFrame.new(d.p) * CFrame.Angles(math.random() * 6, 0, 0), Size = Vector3.new(0.1, 0.1, 0.1) }, Enum.EasingStyle.Quad)
			Debris:AddItem(rock, 3.6)
		end)
	end
end

H.bh_collapse = function(d)
	local s = d.s or 1
	tint(Color3.fromRGB(230, 200, 255), 1.2)
	cue("mega_impact", nil, 1)
	cue("thunder", d.p, 1)
	local core = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(30, 30, 30) * s, CFrame = CFrame.new(d.p), Color = Color3.fromRGB(255, 255, 255), Transparency = 0 })
	tween(core, 0.35, { Size = Vector3.new(2, 2, 2) })
	task.delay(0.35, function()
		tween(core, 1.4, { Size = Vector3.new(260, 260, 260) * s, Transparency = 1, Color = Color3.fromRGB(180, 120, 255) })
	end)
	Debris:AddItem(core, 2)
	for k = 1, 3 do
		task.delay(0.35 + k * 0.12, function()
			local ringP = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 6, 6), CFrame = CFrame.new(d.p) * CFrame.Angles(math.random() * 3, math.random() * 3, math.rad(90)), Color = Color3.fromRGB(200, 160, 255), Transparency = 0.2 })
			tween(ringP, 1.6, { Size = Vector3.new(1.5, 400 * s, 400 * s), Transparency = 1 })
			Debris:AddItem(ringP, 1.7)
		end)
	end
	burst(d.p, TEX_SPARK, { Color3.fromRGB(230, 200, 255), Color3.new(1, 1, 1) }, 120, 80, 2.5, 2.5)
	debrisBurst(d.p, 30, 2, Color3.fromRGB(70, 60, 80))
	shake(3)
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
	task.delay(3, Effects.checkSprite)
	task.spawn(function()
		local seen, list = {}, {}
		for _, c in Config.SoundCues do
			if c.fallback and not seen[c.fallback] then
				seen[c.fallback] = true
				local snd = Instance.new("Sound")
				snd.SoundId = c.fallback
				table.insert(list, snd)
			end
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end)
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
