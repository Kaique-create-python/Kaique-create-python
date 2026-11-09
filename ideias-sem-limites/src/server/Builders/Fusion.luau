--!strict
-- Híbridos: "gato tubarão" = corpo de gato com cabeça de tubarão; "macaco
-- pizza" = macaco com uma pizza no lugar da cabeça; "crocodilo avião" = avião
-- com cabeça de crocodilo. A cabeça (ou o objeto inteiro) do segundo é
-- reconstruída, escalada e soldada no lugar da cabeça do primeiro.

local Fusion = {}

local function vmin(a: Vector3, b: Vector3): Vector3
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end

local function vmax(a: Vector3, b: Vector3): Vector3
	return Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end

-- cabeça + tudo que está soldado diretamente nela (olhos, chapéu, chifres...)
function Fusion.headGroup(model: Instance, head: BasePart): { BasePart }
	local parts = { head }
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") and d.Part0 == head and d.Part1 and d.Part1 ~= head then
			table.insert(parts, d.Part1 :: BasePart)
		end
	end
	return parts
end

function Fusion.bounds(parts: { BasePart }): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in parts do
		local r = p.Size / 2
		local ext = Vector3.new(r.Magnitude, r.Magnitude, r.Magnitude) * 0.8
		lo = vmin(lo, p.Position - ext)
		hi = vmax(hi, p.Position + ext)
	end
	return (lo + hi) / 2, hi - lo
end

-- move e escala um conjunto de partes para caber em `size` centrado em `at`
function Fusion.fit(parts: { BasePart }, at: CFrame, maxSize: number)
	local center, size = Fusion.bounds(parts)
	local biggest = math.max(size.X, size.Y, size.Z, 0.1)
	local k = math.clamp(maxSize / biggest, 0.05, 20)
	for _, p in parts do
		local rel = CFrame.new(center):ToObjectSpace(p.CFrame)
		p.Size = p.Size * k
		p.CFrame = at * (CFrame.new(rel.Position * k) * rel.Rotation)
	end
end

-- solda as partes transplantadas em `anchor` (sem física própria)
function Fusion.attach(parts: { BasePart }, anchor: BasePart, model: Model)
	for _, p in parts do
		for _, j in p:GetChildren() do
			if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
				j:Destroy()
			end
		end
		p.Anchored = anchor.Anchored
		p.CanCollide = false
		p.Massless = true
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = anchor
		w.Part1 = p
		w.Parent = p
	end
end

-- esconde a cabeça original (mantém a parte que segura a junta animada)
function Fusion.hideHead(model: Instance, head: BasePart)
	for _, p in Fusion.headGroup(model, head) do
		if p == head then
			p.Transparency = 1
			p.CanCollide = false
		else
			p:Destroy()
		end
	end
	for _, d in head:GetChildren() do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
end

-- Constrói a "cabeça" do segundo conceito. builders = { creature = fn, prop = fn }
function Fusion.makeHead(fh: any, params: { [string]: any }, builders: any): ({ BasePart }, Instance?)
	local origin = CFrame.new(0, -500, 0)
	if fh.category == "creature" then
		local ok, rig = pcall(builders.creature, origin, {
			model = fh.model,
			variant = fh.variant,
			size = fh.size or 1,
			scale = 1,
			rng = params.rng,
			element = fh.element,
			faction = params.faction,
		})
		if not ok or not rig then
			return {}, nil
		end
		local head = rig.head or rig.root
		local parts = Fusion.headGroup(rig.model, head)
		if head == rig.root or #parts <= 1 then
			-- criaturas sem cabeça separada (peixes, slimes): usa o corpo visível
			parts = {}
			for _, d in rig.model:GetDescendants() do
				if d:IsA("BasePart") and d ~= rig.root and d.Transparency < 1 then
					table.insert(parts, d)
				end
			end
		end
		return parts, rig.model
	end
	local ok, r = pcall(builders.prop, origin, { model = fh.model, variant = fh.variant, scale = 1, anchored = false })
	if not ok or not r then
		return {}, nil
	end
	local parts = {}
	for _, d in r.model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(parts, d)
		end
	end
	return parts, r.model
end

-- Aplica o híbrido num rig já montado (corpo = base). Retorna true se deu certo.
function Fusion.ontoRig(rig: any, fh: any, params: { [string]: any }, builders: any): boolean
	local head: BasePart? = rig.head
	if not head or head == rig.root then
		return false
	end
	local parts, leftover = Fusion.makeHead(fh, params, builders)
	if #parts == 0 then
		if leftover then
			leftover:Destroy()
		end
		return false
	end
	local _, headSize = Fusion.bounds(Fusion.headGroup(rig.model, head))
	local target = math.max(headSize.X, headSize.Y, headSize.Z) * (if fh.category == "creature" then 1.25 else 1.5)
	local at = head.CFrame * CFrame.new(0, headSize.Y * 0.12, 0)
	Fusion.hideHead(rig.model, head)
	Fusion.fit(parts, at, math.max(target, 1.2))
	Fusion.attach(parts, head, rig.model)
	if leftover then
		leftover:Destroy()
	end
	rig.model:SetAttribute("Hibrido", fh.id)
	return true
end

-- Cabeça de criatura como "carranca" na frente de um veículo
function Fusion.ontoVehicle(model: Model, fh: any, params: { [string]: any }, builders: any): boolean
	local main = model.PrimaryPart
	if not main then
		return false
	end
	local parts, leftover = Fusion.makeHead(fh, params, builders)
	if #parts == 0 then
		if leftover then
			leftover:Destroy()
		end
		return false
	end
	local all = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not table.find(parts, d) then
			table.insert(all, d)
		end
	end
	local center, size = Fusion.bounds(all)
	local front = main.CFrame.LookVector
	local at = CFrame.lookAt(center + front * (size.Z * 0.42) + Vector3.new(0, size.Y * 0.35, 0), center + front * size.Z)
	Fusion.fit(parts, at, math.max(size.Y * 0.9, 3))
	Fusion.attach(parts, main, model)
	if leftover then
		leftover:Destroy()
	end
	model:SetAttribute("Hibrido", fh.id)
	return true
end

return Fusion
