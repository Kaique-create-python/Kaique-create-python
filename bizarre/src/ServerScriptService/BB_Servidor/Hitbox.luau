-- BIZARRE BATTLEGROUNDS :: caixas de acerto no servidor (quem foi pego por um golpe)

local Lutadores = require(script.Parent.Lutadores)

local Treino17=require(game:GetService("ReplicatedStorage"):WaitForChild("BB"):WaitForChild("Laboratorio17"))
local Hitbox = {}
local CORPO = { Head=true, Torso=true, ["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true, HumanoidRootPart=true }
function Hitbox.corpo(p, lut)
	local torso=lut.modelo:FindFirstChild("Torso")
	return torso and torso:IsA("BasePart") and p and CORPO[p.Name] == true and p.Parent == lut.modelo and p:IsA("BasePart")
end

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

local function juntar(partes: { BasePart }, excluir: any?, apenasCorpo: boolean?): { any }
	local vistos = {}
	local r = {}
	for _, p in partes do
		local l = Lutadores.daPeca(p)
		local piloto = apenasCorpo or (excluir and (excluir.standId == "STAR_PLATINUM" or excluir.standId == "THE_WORLD"))
		if l and l ~= excluir and Treino17.permite(excluir or {},l) and not vistos[l] and l.hum.Health > 0 and (not piloto or Hitbox.corpo(p,l)) then
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

function Hitbox.esfera(pos: Vector3, raio: number, excluir: any?, apenasCorpo: boolean?): { any }
	atualizarParams()
	local partes = workspace:GetPartBoundsInRadius(pos, raio, params)
	return juntar(partes, excluir, apenasCorpo)
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

-- "grude" do servidor: se tem um inimigo perto e quase na frente, o golpe vira para ele
-- (o celular manda a direção um pouquinho atrasada; isso evita errar soco que acertou na tela)
function Hitbox.grudar(lut: any, dir: Vector3, alcance: number, cosMin: number?): Vector3
	local raiz = lut.raiz
	local d0 = Vector3.new(dir.X, 0, dir.Z)
	if d0.Magnitude < 1e-3 then
		return dir
	end
	d0 = d0.Unit
	local melhor, nota = nil, math.huge
	for _, l in Hitbox.esfera(raiz.Position, alcance, lut) do
		local v = l.raiz.Position - raiz.Position
		local plano = Vector3.new(v.X, 0, v.Z)
		if plano.Magnitude > 0.3 then
			local frente = plano.Unit:Dot(d0)
			if frente >= (cosMin or 0.55) then
				local n = plano.Magnitude * (2 - frente)
				if n < nota then
					melhor, nota = plano.Unit, n
				end
			end
		end
	end
	return melhor or d0
end

return Hitbox
