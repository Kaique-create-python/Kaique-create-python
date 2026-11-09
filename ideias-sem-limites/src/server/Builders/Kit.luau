--!strict
-- Kit de construção procedural.
-- Um "Builder" monta um Model em coordenadas locais (unidade = 1 stud na escala 1)
-- e aplica escala, posição de origem e modificadores (cor, material, elemento).
-- Papéis (role) das partes permitem que modificadores alterem só o que faz sentido:
--   primary/secondary = corpo; accent = detalhes coloridos; eye/glow = olhos e luzes;
--   fixed = nunca muda (ex.: dentes, rodas).

local Config = require(game:GetService("ReplicatedStorage").IdeiasShared.Config)

local Kit = {}

export type PartOpts = {
	role: string?,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?,
	name: string?,
	shadow: boolean?,
	parent: Instance?,
}

-- Materiais dos modificadores ----------------------------------------------
Kit.MaterialPresets = {
	gold = { material = Enum.Material.Foil, color = Color3.fromRGB(255, 196, 38), reflect = 0.25 },
	diamond = { material = Enum.Material.Glass, color = Color3.fromRGB(160, 235, 255), reflect = 0.4, transparency = 0.15 },
	crystal = { material = Enum.Material.Glass, color = Color3.fromRGB(196, 140, 255), reflect = 0.2, transparency = 0.2 },
	metal = { material = Enum.Material.DiamondPlate, color = Color3.fromRGB(140, 146, 158) },
	wood = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(150, 103, 62) },
	stone = { material = Enum.Material.Slate, color = Color3.fromRGB(118, 118, 124) },
	glass = { material = Enum.Material.Glass, color = Color3.fromRGB(200, 230, 255), transparency = 0.45 },
	candy = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(255, 140, 200) },
	jelly = { material = Enum.Material.Glass, color = Color3.fromRGB(110, 230, 120), transparency = 0.35 },
	toy = { material = Enum.Material.SmoothPlastic, color = nil },
	neon = { material = Enum.Material.Neon, color = nil },
	chocolate = { material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(92, 52, 30) },
	ice = { material = Enum.Material.Ice, color = Color3.fromRGB(170, 225, 255), transparency = 0.1 },
	lava = { material = Enum.Material.CrackedLava, color = Color3.fromRGB(255, 90, 20) },
}

-- Elementos: cores e efeitos -------------------------------------------------
Kit.Elements = {
	fire = { color = Color3.fromRGB(255, 120, 30), color2 = Color3.fromRGB(255, 220, 80), light = Color3.fromRGB(255, 140, 50), tint = Color3.fromRGB(200, 70, 30) },
	ice = { color = Color3.fromRGB(140, 220, 255), color2 = Color3.fromRGB(255, 255, 255), light = Color3.fromRGB(150, 220, 255), tint = Color3.fromRGB(120, 200, 245) },
	electric = { color = Color3.fromRGB(255, 240, 80), color2 = Color3.fromRGB(120, 200, 255), light = Color3.fromRGB(255, 245, 140), tint = Color3.fromRGB(240, 220, 60) },
	poison = { color = Color3.fromRGB(120, 230, 60), color2 = Color3.fromRGB(180, 80, 220), light = Color3.fromRGB(130, 255, 90), tint = Color3.fromRGB(90, 170, 50) },
	water = { color = Color3.fromRGB(60, 150, 255), color2 = Color3.fromRGB(200, 240, 255), light = Color3.fromRGB(90, 170, 255), tint = Color3.fromRGB(50, 120, 220) },
	shadow = { color = Color3.fromRGB(90, 40, 140), color2 = Color3.fromRGB(20, 10, 30), light = Color3.fromRGB(150, 70, 220), tint = Color3.fromRGB(45, 30, 70) },
	light = { color = Color3.fromRGB(255, 245, 190), color2 = Color3.fromRGB(255, 210, 90), light = Color3.fromRGB(255, 240, 180), tint = Color3.fromRGB(250, 235, 170) },
	lava = { color = Color3.fromRGB(255, 80, 20), color2 = Color3.fromRGB(60, 20, 10), light = Color3.fromRGB(255, 110, 40), tint = Color3.fromRGB(150, 40, 20) },
	wind = { color = Color3.fromRGB(230, 245, 255), color2 = Color3.fromRGB(180, 210, 230), light = Color3.fromRGB(220, 240, 255), tint = Color3.fromRGB(200, 225, 240) },
	nature = { color = Color3.fromRGB(110, 200, 80), color2 = Color3.fromRGB(255, 200, 220), light = Color3.fromRGB(160, 255, 140), tint = Color3.fromRGB(80, 160, 60) },
	rainbow = { color = Color3.fromRGB(255, 80, 200), color2 = Color3.fromRGB(80, 220, 255), light = Color3.fromRGB(255, 200, 255), tint = Color3.fromRGB(255, 120, 220) },
}

Kit.RainbowColors = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 230, 60),
	Color3.fromRGB(80, 220, 90),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(150, 90, 255),
}

-- Builder ---------------------------------------------------------------------
local Builder = {}
Builder.__index = Builder

export type Builder = typeof(setmetatable(
	{} :: {
		model: Model,
		origin: CFrame,
		s: number,
		anchored: boolean,
		collide: boolean,
		params: { [string]: any },
		parts: { BasePart },
		roles: { [BasePart]: string },
		primary: Color3?,
	},
	Builder
))

function Kit.new(name: string, origin: CFrame, params: { [string]: any }?): Builder
	local model = Instance.new("Model")
	model.Name = name
	local p = params or {}
	local self = setmetatable({
		model = model,
		origin = origin,
		s = (p.scale or 1) * (p.size or 1),
		anchored = if p.anchored == nil then true else p.anchored,
		collide = if p.collide == nil then true else p.collide,
		params = p,
		parts = {},
		roles = {},
		primary = nil,
	}, Builder)
	return self
end

-- Converte posição/orientação locais (escala 1) em CFrame de mundo
function Builder.at(self: Builder, localCf: CFrame): CFrame
	local s = self.s
	return self.origin * (CFrame.new(localCf.Position * s) * localCf.Rotation)
end

local SHAPES = {
	block = Enum.PartType.Block,
	ball = Enum.PartType.Ball,
	cyl = Enum.PartType.Cylinder,
	wedge = "WedgePart",
	corner = "CornerWedgePart",
}

function Builder.part(self: Builder, shape: string, size: Vector3, localCf: CFrame, color: Color3, opts: PartOpts?): BasePart
	local o: PartOpts = opts or {}
	local kind = SHAPES[shape] or Enum.PartType.Block
	local part: BasePart
	-- No Roblox uma "Ball" usa sempre o MENOR eixo como diâmetro. Para elipsoides
	-- (corpos, cabeças, folhagens) usamos bloco + SpecialMesh esférico.
	local ellipsoid = shape == "ball" and (math.max(size.X, size.Y, size.Z) - math.min(size.X, size.Y, size.Z)) > 0.02
	if ellipsoid then
		kind = Enum.PartType.Block
	end
	if kind == "WedgePart" then
		part = Instance.new("WedgePart")
	elseif kind == "CornerWedgePart" then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		p.Shape = kind :: Enum.PartType
		part = p
	end
	local s = self.s
	part.Size = Vector3.new(math.max(size.X * s, 0.05), math.max(size.Y * s, 0.05), math.max(size.Z * s, 0.05))
	part.CFrame = self:at(localCf)
	part.Color = color
	part.Material = o.material or Enum.Material.SmoothPlastic
	part.Transparency = o.transparency or 0
	part.Reflectance = o.reflectance or 0
	part.Anchored = self.anchored
	local collide = if o.collide == nil then self.collide else o.collide
	part.CanCollide = collide
	part.CanTouch = false
	-- partes pequenas não fazem sombra (economia em celular)
	local volume = part.Size.X * part.Size.Y * part.Size.Z
	part.CastShadow = if o.shadow ~= nil then o.shadow else volume > 8
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Name = o.name or shape
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = o.parent or self.model
	table.insert(self.parts, part)
	self.roles[part] = o.role or "primary"
	if (o.role or "primary") == "primary" and not self.primary then
		self.primary = color
	end
	return part
end

-- atalhos
function Builder.box(self: Builder, size: Vector3, localCf: CFrame, color: Color3, opts: PartOpts?): BasePart
	return self:part("block", size, localCf, color, opts)
end

function Builder.ball(self: Builder, diameter: number, localCf: CFrame, color: Color3, opts: PartOpts?): BasePart
	return self:part("ball", Vector3.new(diameter, diameter, diameter), localCf, color, opts)
end

-- Elipsoide: bola esticada (Ball só aceita diâmetro uniforme; usamos bloco com SpecialMesh não disponível
-- em todos os contextos, então aproximamos com bola + bloco arredondado)
function Builder.blob(self: Builder, size: Vector3, localCf: CFrame, color: Color3, opts: PartOpts?): BasePart
	local d = math.min(size.X, size.Y, size.Z)
	if math.max(size.X, size.Y, size.Z) - d < 0.15 then
		return self:ball(d, localCf, color, opts)
	end
	-- cilindro deitado no eixo maior + duas bolas nas pontas = cápsula
	local axis: string = "X"
	local long = size.X
	if size.Y > long then
		axis, long = "Y", size.Y
	end
	if size.Z > long then
		axis, long = "Z", size.Z
	end
	local thick = d
	local bodyLen = math.max(long - thick, 0.05)
	local rot = CFrame.identity
	if axis == "Y" then
		rot = CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "Z" then
		rot = CFrame.Angles(0, math.rad(90), 0)
	end
	local main = self:part("cyl", Vector3.new(bodyLen, thick, thick), localCf * rot, color, opts)
	local dir = (rot.RightVector) * (bodyLen / 2)
	self:ball(thick, localCf * CFrame.new(dir), color, opts)
	self:ball(thick, localCf * CFrame.new(-dir), color, opts)
	return main
end

-- Cilindro em pé (eixo Y). No Roblox o eixo do Cylinder é X.
function Builder.cylY(self: Builder, height: number, diameter: number, localCf: CFrame, color: Color3, opts: PartOpts?): BasePart
	return self:part("cyl", Vector3.new(height, diameter, diameter), localCf * CFrame.Angles(0, 0, math.rad(90)), color, opts)
end

-- Segmento entre dois pontos locais (galhos, pernas, cabos)
function Builder.beam(self: Builder, a: Vector3, b: Vector3, thickness: number, color: Color3, opts: PartOpts?, round: boolean?): BasePart
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b)
	if round then
		return self:part("cyl", Vector3.new(len, thickness, thickness), cf * CFrame.Angles(0, math.rad(90), 0), color, opts)
	end
	return self:part("block", Vector3.new(thickness, thickness, len), cf, color, opts)
end

-- Cone aproximado por anéis de cilindros (telhados, chapéus, montanhas)
function Builder.cone(self: Builder, height: number, baseDiameter: number, localCf: CFrame, color: Color3, steps: number?, opts: PartOpts?): { BasePart }
	local n = steps or 4
	local out = {}
	for i = 0, n - 1 do
		local t = i / n
		local d = baseDiameter * (1 - t)
		local h = height / n
		table.insert(out, self:cylY(h, math.max(d, 0.2), localCf * CFrame.new(0, h * (i + 0.5), 0), color, opts))
	end
	return out
end

-- Telhado de duas águas com cunhas
function Builder.roof(self: Builder, width: number, depth: number, height: number, localCf: CFrame, color: Color3, opts: PartOpts?)
	local half = width / 2
	self:part("wedge", Vector3.new(depth, height, half), localCf * CFrame.new(half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(90), 0), color, opts)
	self:part("wedge", Vector3.new(depth, height, half), localCf * CFrame.new(-half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), color, opts)
end

function Builder.light(self: Builder, part: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = math.min(range * math.sqrt(self.s), 60)
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = part
	return l
end

function Builder.attachment(self: Builder, part: BasePart, name: string, localPos: Vector3?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = (localPos or Vector3.zero) * self.s
	a.Parent = part
	return a
end

-- Aplica modificadores visuais (cor, material, traço) às partes conforme o papel
function Builder.applyStyle(self: Builder)
	local p = self.params
	local mat = p.material and Kit.MaterialPresets[p.material]
	local color: Color3? = nil
	if type(p.color) == "table" then
		color = Color3.new(p.color[1], p.color[2], p.color[3])
	end
	local trait = p.trait
	local elem = p.element and Kit.Elements[p.element]
	local i = 0
	for _, part in self.parts do
		local role = self.roles[part]
		i += 1
		if role == "primary" or role == "secondary" then
			local base = part.Color
			if color then
				part.Color = if role == "primary" then color else color:Lerp(Color3.new(0, 0, 0), 0.35)
			end
			if trait == "undead" then
				part.Color = part.Color:Lerp(Color3.fromRGB(110, 150, 90), 0.55)
			elseif trait == "robotic" then
				part.Color = base:Lerp(Color3.fromRGB(150, 156, 168), 0.6)
			elseif trait == "ancient" or trait == "medieval" then
				part.Color = part.Color:Lerp(Color3.fromRGB(150, 140, 120), 0.45)
			end
			if elem and p.elementMod and p.element ~= "rainbow" and not color and not mat and not p.keepColor then
				part.Color = part.Color:Lerp(elem.tint, 0.45)
			end
			if p.element == "rainbow" and p.elementMod and not color then
				part.Color = Kit.RainbowColors[(i % #Kit.RainbowColors) + 1]
			end
			if mat then
				part.Material = mat.material
				if mat.color and not color then
					part.Color = if role == "primary" then mat.color else mat.color:Lerp(Color3.new(0, 0, 0), 0.25)
				end
				if mat.reflect then
					part.Reflectance = mat.reflect
				end
				if mat.transparency then
					part.Transparency = math.max(part.Transparency, mat.transparency)
				end
			end
			if trait == "ghostly" then
				part.Transparency = math.max(part.Transparency, 0.45)
				part.Material = Enum.Material.ForceField
			end
		elseif role == "accent" then
			if elem then
				part.Color = elem.color
				part.Material = Enum.Material.Neon
			elseif trait == "futuristic" or trait == "robotic" then
				part.Material = Enum.Material.Neon
			end
		elseif role == "eye" then
			if trait == "robotic" or trait == "futuristic" then
				part.Color = Color3.fromRGB(80, 230, 255)
				part.Material = Enum.Material.Neon
			elseif trait == "undead" then
				part.Color = Color3.fromRGB(190, 255, 120)
				part.Material = Enum.Material.Neon
			elseif elem and (p.faction == "hostile") then
				part.Color = elem.color
				part.Material = Enum.Material.Neon
			end
		end
	end
end

-- Efeitos de elemento (partículas + luz) presos a uma parte
function Kit.elementEffects(part: BasePart, element: string?, intensity: number?): { Instance }
	local out = {}
	if not element then
		return out
	end
	local e = Kit.Elements[element]
	if not e then
		return out
	end
	local k = intensity or 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Elemento"
	emitter.LightEmission = 0.6
	emitter.Rate = 10 * k
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * k), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(e.color, e.color2)
	if element == "fire" or element == "lava" then
		emitter.Texture = Config.Textures.Fire
		emitter.Acceleration = Vector3.new(0, 6, 0)
	elseif element == "poison" or element == "shadow" or element == "wind" then
		emitter.Texture = Config.Textures.Smoke
		emitter.Rate = 6 * k
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * k), NumberSequenceKeypoint.new(1, 2 * k) })
	else
		emitter.Texture = Config.Textures.Sparkle
	end
	emitter.Parent = part
	emitter:AddTag("IdeiasFx")
	table.insert(out, emitter)
	local light = Instance.new("PointLight")
	light.Color = e.light
	light.Range = 10 * math.min(k, 3)
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = part
	table.insert(out, light)
	return out
end

function Builder.finish(self: Builder, primaryPart: BasePart?): Model
	self:applyStyle()
	if primaryPart then
		self.model.PrimaryPart = primaryPart
	elseif self.parts[1] then
		self.model.PrimaryPart = self.parts[1]
	end
	self.model.WorldPivot = self.origin
	self.model:SetAttribute("PartCount", #self.parts)
	return self.model
end

-- Cores utilitárias
function Kit.rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

function Kit.darker(c: Color3, f: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), f)
end

function Kit.lighter(c: Color3, f: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), f)
end

-- Solda todas as partes não ancoradas de um modelo à parte raiz
function Kit.weldAll(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and not d:FindFirstChildWhichIsA("JointInstance") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

return Kit
