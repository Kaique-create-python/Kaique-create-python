-- BIZARRE BATTLEGROUNDS :: caixas de acerto no servidor (quem foi pego por um golpe)

local Lutadores = require(script.Parent.Lutadores)

local Hitbox = {}

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.MaxParts = 400
local versaoParams = -1

local function atualizarParams()
	if versaoParams == Lutadores.versao() then
		return
	end
	local modelos = {}
	for _, l in Lutadores.todos() do
		table.insert(modelos, l.modelo)
	end
	params.FilterDescendantsInstances = modelos
	versaoParams = Lutadores.versao()
end

function Hitbox.parametros(): OverlapParams
	atualizarParams()
	return params
end

local function juntar(partes: { BasePart }, excluir: any?): { any }
	local vistos = {}
	local r = {}
	for _, p in partes do
		local l = Lutadores.daPeca(p)
		if l and l ~= excluir and not vistos[l] and l.hum.Health > 0 then
			vistos[l] = true
			table.insert(r, l)
		end
	end
	return r
end

-- caixa orientada na frente de alguém
function Hitbox.cfFrente(raiz: BasePart, dir: Vector3, frente: number, cima: number?, lado: number?): CFrame
	local pos = raiz.Position + dir * frente + Vector3.new(0, cima or 0, 0)
	local cf = CFrame.lookAt(pos, pos + dir)
	if lado and lado ~= 0 then
		cf = cf * CFrame.new(lado, 0, 0)
	end
	return cf
end

function Hitbox.caixa(cf: CFrame, tam: Vector3, excluir: any?): { any }
	atualizarParams()
	local partes = workspace:GetPartBoundsInBox(cf, tam, params)
	return juntar(partes, excluir)
end

function Hitbox.esfera(pos: Vector3, raio: number, excluir: any?): { any }
	atualizarParams()
	local partes = workspace:GetPartBoundsInRadius(pos, raio, params)
	return juntar(partes, excluir)
end

-- cone achatado (só no plano do chão, com uma folga de altura)
function Hitbox.cone(origem: Vector3, dir: Vector3, anguloGraus: number, alcance: number, excluir: any?): { any }
	local r = {}
	local cosMin = math.cos(math.rad(anguloGraus))
	local d = Vector3.new(dir.X, 0, dir.Z)
	if d.Magnitude < 1e-3 then
		d = Vector3.new(0, 0, -1)
	end
	d = d.Unit
	for _, l in Hitbox.esfera(origem, alcance + 2, excluir) do
		local v = l.raiz.Position - origem
		local plano = Vector3.new(v.X, 0, v.Z)
		if plano.Magnitude < 2.5 then
			table.insert(r, l)
		elseif math.abs(v.Y) < alcance * 0.6 + 4 and plano.Unit:Dot(d) >= cosMin then
			table.insert(r, l)
		end
	end
	return r
end

-- o inimigo mais perto na frente (para teleportes e mira automática dos bots)
function Hitbox.maisPertoNaFrente(lut: any, dir: Vector3, alcance: number, coneCos: number?): any
	local melhor, melhorD = nil, math.huge
	for _, l in Hitbox.esfera(lut.raiz.Position, alcance, lut) do
		local v = l.raiz.Position - lut.raiz.Position
		local plano = Vector3.new(v.X, 0, v.Z)
		local ok = plano.Magnitude < 3 or plano.Unit:Dot(dir) >= (coneCos or 0.2)
		if ok and v.Magnitude < melhorD then
			melhor, melhorD = l, v.Magnitude
		end
	end
	return melhor
end

return Hitbox
