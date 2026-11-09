--!strict
-- Ferramentas para gerar o mapa:
--   * terreno (Terrain) com registro das elevações -> heightAt(x, z) analítico,
--     sem depender de raycast (funciona igual no Roblox e nos testes do Lune)
--   * atalhos para peças, objetos e construções reutilizando os construtores
--   * marcação de destrutíveis, perigos (lava), plataformas de salto e teleportes
-- A conexão de eventos (prompts, toques) fica em MapRuntime, fora da geração.

local Workspace = game:GetService("Workspace")
local Builders = require(script.Parent.Parent.Builders)
local Kit = Builders.Kit

local MapKit = {}
MapKit.__index = MapKit

export type Hill = { x: number, z: number, r: number, top: number, kind: string }

local hills: { Hill } = {}
local flats: { { x: number, z: number, r: number, y: number } } = {}

MapKit.SURFACE = 0 -- altura do chão da ilha

function MapKit.resetTerrain()
	table.clear(hills)
	table.clear(flats)
end

-- altura do chão em (x, z) considerando morros e platôs registrados
function MapKit.heightAt(x: number, z: number): number
	local h = MapKit.SURFACE
	local dist = math.sqrt(x * x + z * z)
	if dist > 585 then
		h = -3
	end
	for _, f in flats do
		local d = math.sqrt((x - f.x) ^ 2 + (z - f.z) ^ 2)
		if d < f.r then
			h = f.y
		end
	end
	for _, hill in hills do
		local d = math.sqrt((x - hill.x) ^ 2 + (z - hill.z) ^ 2)
		if d < hill.r then
			local y: number
			if hill.kind == "cone" then
				y = hill.top * (1 - d / hill.r)
			else
				-- calota esférica
				local t = d / hill.r
				y = hill.top * math.sqrt(math.max(0, 1 - t * t))
			end
			h = math.max(h, y)
		end
	end
	return h
end

local terrain = Workspace.Terrain

function MapKit.fillBlock(cf: CFrame, size: Vector3, material: Enum.Material)
	terrain:FillBlock(cf, size, material)
end

function MapKit.fillBall(center: Vector3, radius: number, material: Enum.Material)
	terrain:FillBall(center, radius, material)
end

function MapKit.fillCylinder(cf: CFrame, height: number, radius: number, material: Enum.Material)
	terrain:FillCylinder(cf, height, radius, material)
end

-- morro arredondado: bola enterrada; registra altura para heightAt
function MapKit.hill(x: number, z: number, radius: number, top: number, material: Enum.Material)
	-- esfera de raio R com centro em y = top - R corta o chão em raio r
	local R = (radius * radius + top * top) / (2 * top)
	terrain:FillBall(Vector3.new(x, top - R, z), R, material)
	table.insert(hills, { x = x, z = z, r = radius, top = top, kind = "dome" })
end

-- montanha cônica em degraus de cilindros
function MapKit.mountain(x: number, z: number, radius: number, top: number, material: Enum.Material, capMaterial: Enum.Material?)
	local steps = 8
	for i = 0, steps - 1 do
		local t0 = i / steps
		local r = radius * (1 - t0)
		local y0 = top * t0
		local mat = if capMaterial and t0 > 0.65 then capMaterial else material
		terrain:FillCylinder(CFrame.new(x, y0 + top / steps / 2 - 1, z), top / steps + 2, r, mat)
	end
	table.insert(hills, { x = x, z = z, r = radius, top = top, kind = "cone" })
end

function MapKit.flat(x: number, z: number, radius: number, y: number)
	table.insert(flats, { x = x, z = z, r = radius, y = y })
end

-- Contexto de uma região -----------------------------------------------------------
function MapKit.region(folder: Instance, destructibles: Instance, rng: any, center: Vector3): any
	return setmetatable({ folder = folder, destr = destructibles, rng = rng, center = center, parts = 0 }, MapKit)
end

function MapKit.at(self: any, x: number, z: number, yOffset: number?, rotY: number?): CFrame
	local wx, wz = self.center.X + x, self.center.Z + z
	return CFrame.new(wx, MapKit.heightAt(wx, wz) + (yOffset or 0), wz) * CFrame.Angles(0, rotY or 0, 0)
end

function MapKit.world(self: any, x: number, z: number): (number, number)
	return self.center.X + x, self.center.Z + z
end

local function count(self: any, m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			self.parts += 1
		end
	end
	if m:IsA("BasePart") then
		self.parts += 1
	end
end

-- constrói peças com o Kit e coloca na região
function MapKit.build(self: any, name: string, cf: CFrame, fn: (any) -> (), params: { [string]: any }?): Model
	local p = params or {}
	if p.anchored == nil then
		p.anchored = true
	end
	local b = Kit.new(name, cf, p)
	fn(b)
	local m = b:finish()
	m.Parent = self.folder
	count(self, m)
	return m
end

function MapKit.prop(self: any, model: string, variant: string, cf: CFrame, scale: number?, extra: { [string]: any }?): Model
	local params: { [string]: any } = { scale = scale or 1, rng = self.rng }
	if extra then
		for k, v in extra do
			params[k] = v
		end
	end
	local r = Builders.Props.build(cf, params, model, variant)
	r.model.Parent = self.folder
	count(self, r.model)
	return r.model
end

function MapKit.building(self: any, variant: string, cf: CFrame, params: { [string]: any }?): any
	local p: { [string]: any } = params or {}
	p.rng = self.rng
	p.scale = p.scale or 1
	local r = Builders.Buildings.build(cf, p, variant)
	r.model.Parent = self.folder
	pcall(function()
		(r.model :: any).ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	count(self, r.model)
	return r
end

-- veículo decorativo (estacionado e ancorado)
function MapKit.parkedVehicle(self: any, variant: string, cf: CFrame): Model
	local v = Builders.Vehicles.build(cf, { rng = self.rng, scale = 1 }, variant)
	for _, d in v.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("VehicleSeat") then
			d.Disabled = true
		end
	end
	v.model:RemoveTag("IdeiasVeiculo")
	v.model.Parent = self.folder
	count(self, v.model)
	return v.model
end

-- move um modelo para o grupo de destrutíveis (volta sozinho depois)
function MapKit.destructible(self: any, model: Instance)
	model.Parent = self.destr
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d:AddTag("Destrutivel")
		end
	end
	if model:IsA("BasePart") then
		model:AddTag("Destrutivel")
	end
end

function MapKit.hazard(part: BasePart, kind: string, dps: number)
	part:AddTag("Perigo")
	part:SetAttribute("Perigo", kind)
	part:SetAttribute("Dano", dps)
end

function MapKit.jumpPad(self: any, cf: CFrame, direction: Vector3, force: number, color: Color3?): BasePart
	local m = self:build("PlataformaSalto", cf, function(b)
		b:cylY(1, 10, CFrame.new(0, 0.5, 0), Color3.fromRGB(40, 40, 55), { role = "fixed", material = Enum.Material.DiamondPlate })
		local pad = b:cylY(0.4, 8, CFrame.new(0, 1.1, 0), color or Color3.fromRGB(80, 255, 200), { role = "fixed", material = Enum.Material.Neon, name = "Pulo" })
		pad:AddTag("IdeiasPulo")
		pad:SetAttribute("Forca", force)
		pad:SetAttribute("Direcao", direction.Unit)
		b:part("wedge", Vector3.new(1.4, 0.6, 2.4), CFrame.new(0, 1.5, 0) * CFrame.lookAt(Vector3.zero, Vector3.new(direction.X, 0, direction.Z)).Rotation * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(255, 255, 255), { role = "fixed", material = Enum.Material.Neon, collide = false })
	end)
	return m:FindFirstChild("Pulo", true) :: BasePart
end

-- plataforma de teleporte com ProximityPrompt (conectada em MapRuntime)
function MapKit.teleportPad(self: any, cf: CFrame, target: CFrame, label: string, color: Color3): BasePart
	local m = self:build("Teleporte", cf, function(b)
		b:cylY(1.2, 12, CFrame.new(0, 0.6, 0), Color3.fromRGB(35, 35, 45), { role = "fixed", material = Enum.Material.Slate })
		local ring = b:cylY(0.3, 10, CFrame.new(0, 1.3, 0), color, { role = "fixed", material = Enum.Material.Neon, name = "Anel" })
		ring:AddTag("IdeiasTeleporte")
		ring:SetAttribute("Destino", target)
		ring:SetAttribute("Rotulo", label)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Viajar"
		prompt.ObjectText = label
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = ring
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Rate = 6
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(3, 6)
		e.EmissionDirection = Enum.NormalId.Top
		e.Color = ColorSequence.new(color)
		e.Parent = ring
	end)
	return m:FindFirstChild("Anel", true) :: BasePart
end

function MapKit.sign(part: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(600, 150)
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.5
	label.Parent = gui
	gui.Parent = part
end

function MapKit.spin(part: BasePart, axis: string, speed: number)
	part:AddTag("IdeiasGirar")
	part:SetAttribute("GirarEixo", axis)
	part:SetAttribute("GirarVel", speed)
end

function MapKit.emitter(part: BasePart, texture: string, color: Color3, rate: number, opts: { [string]: any }?): ParticleEmitter
	local o = opts or {}
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Lifetime = o.lifetime or NumberRange.new(2, 4)
	e.Speed = o.speed or NumberRange.new(1, 3)
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.Size = o.size or NumberSequence.new(0.5)
	e.LightEmission = o.light or 0.5
	e.Transparency = o.transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if o.accel then
		e.Acceleration = o.accel
	end
	e.Parent = part
	return e
end

return MapKit
