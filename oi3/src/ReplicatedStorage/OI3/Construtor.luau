-- OI3 :: construtor de peças por código (paredes com aberturas, móveis, reflexo de espelho)
-- Tudo é montado com peças nativas do Roblox. Nada de modelos prontos.

local Construtor = {}
Construtor.__index = Construtor

export type Abertura = {
	centro: number, -- distância (studs) a partir do início da parede
	largura: number,
	base: number, -- altura da base da abertura (relativa ao chão da parede)
	topo: number, -- altura do topo da abertura (relativa ao chão da parede)
}

local Material = Enum.Material

-- Cria um construtor. opcoes.refletir (opcional) recebe um CFrame e devolve o CFrame refletido.
function Construtor.novo(pai: Instance, opcoes: { refletir: ((CFrame) -> CFrame)?, sombras: boolean? }?)
	local self = setmetatable({}, Construtor)
	self.pai = pai
	self.refletir = opcoes and opcoes.refletir or nil
	self.contagem = 0
	return self
end

-- Reflexo por um plano (ponto + normal). Mantém a forma das peças simétricas
-- (bloco, cunha, cilindro, bola) e gera uma rotação válida.
function Construtor.refletorPlano(origem: Vector3, normal: Vector3): (CFrame) -> CFrame
	local n = normal.Unit
	local function refV(v: Vector3): Vector3
		return v - 2 * v:Dot(n) * n
	end
	return function(cf: CFrame): CFrame
		local p = cf.Position
		local p2 = p - 2 * (p - origem):Dot(n) * n
		local r, u, b = cf.RightVector, cf.UpVector, -cf.LookVector
		return CFrame.fromMatrix(p2, -refV(r), refV(u), refV(b))
	end
end

local CHAVES_ESPECIAIS = { classe = true, forma = true, pai = true, colisao = true, sombra = true }

function Construtor:peca(cf: CFrame, tamanho: Vector3, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local classe = (extra and extra.classe) or "Part"
	local p = Instance.new(classe) :: any
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra and extra.forma then
		p.Shape = extra.forma
	end
	p.Size = tamanho
	p.CFrame = if self.refletir then self.refletir(cf) else cf
	p.Color = cor
	p.Material = material or Material.SmoothPlastic
	p.CanTouch = false
	local maior = math.max(tamanho.X, tamanho.Y, tamanho.Z)
	local pequena = maior < 1.6
	if pequena then
		p.CastShadow = false
		p.CanCollide = false
		p.CanQuery = false
	end
	if extra then
		if extra.colisao ~= nil then
			p.CanCollide = extra.colisao
			p.CanQuery = extra.colisao or p.CanQuery
		end
		if extra.sombra ~= nil then
			p.CastShadow = extra.sombra
		end
		for k, v in extra do
			if not CHAVES_ESPECIAIS[k] then
				p[k] = v
			end
		end
	end
	p.Parent = (extra and extra.pai) or self.pai
	self.contagem += 1
	return p
end

function Construtor:bloco(cf: CFrame, tamanho: Vector3, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	return self:peca(cf, tamanho, cor, material, extra)
end

-- Caixa alinhada aos eixos a partir do centro
function Construtor:caixa(centro: Vector3, tamanho: Vector3, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	return self:peca(CFrame.new(centro), tamanho, cor, material, extra)
end

-- Caixa a partir de dois cantos (min/max)
function Construtor:entre(a: Vector3, b: Vector3, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local tam = mx - mn
	tam = Vector3.new(math.max(tam.X, 0.05), math.max(tam.Y, 0.05), math.max(tam.Z, 0.05))
	return self:peca(CFrame.new((mn + mx) / 2), tam, cor, material, extra)
end

function Construtor:cunha(cf: CFrame, tamanho: Vector3, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local e = table.clone(extra or {})
	e.classe = "WedgePart"
	return self:peca(cf, tamanho, cor, material, e)
end

-- Cilindro com eixo no X local
function Construtor:cilindro(cf: CFrame, comprimento: number, diametro: number, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local e = table.clone(extra or {})
	e.forma = Enum.PartType.Cylinder
	return self:peca(cf, Vector3.new(comprimento, diametro, diametro), cor, material, e)
end

-- Cilindro em pé (a partir da base)
function Construtor:coluna(base: Vector3, altura: number, diametro: number, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local cf = CFrame.new(base + Vector3.new(0, altura / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return self:cilindro(cf, altura, diametro, cor, material, extra)
end

function Construtor:bola(centro: Vector3, diametro: number | Vector3, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	local e = table.clone(extra or {})
	e.forma = Enum.PartType.Ball
	local tam = if typeof(diametro) == "Vector3" then diametro else Vector3.new(diametro, diametro, diametro)
	return self:peca(CFrame.new(centro), tam :: Vector3, cor, material, e)
end

-- Parede reta entre p1 e p2 (no plano XZ), do chão yBase até yBase+altura, com aberturas
function Construtor:parede(
	p1: Vector3,
	p2: Vector3,
	yBase: number,
	altura: number,
	espessura: number,
	cor: Color3,
	material: Enum.Material?,
	aberturas: { Abertura }?,
	extra: { [string]: any }?
): { BasePart }
	local a = Vector3.new(p1.X, 0, p1.Z)
	local b = Vector3.new(p2.X, 0, p2.Z)
	local delta = b - a
	local comprimento = delta.Magnitude
	local d = delta.Unit
	local pecas = {}

	local function seg(ini: number, fim: number, y0: number, y1: number)
		ini = math.clamp(ini, 0, comprimento)
		fim = math.clamp(fim, 0, comprimento)
		y0 = math.clamp(y0, 0, altura)
		y1 = math.clamp(y1, 0, altura)
		local L = fim - ini
		local H = y1 - y0
		if L <= 0.02 or H <= 0.02 then
			return
		end
		local meio = a + d * ((ini + fim) / 2)
		local pos = Vector3.new(meio.X, yBase + (y0 + y1) / 2, meio.Z)
		local cf = CFrame.fromMatrix(pos, d, Vector3.yAxis)
		table.insert(pecas, self:peca(cf, Vector3.new(L, H, espessura), cor, material, extra))
	end

	local lista = table.clone(aberturas or {})
	table.sort(lista, function(x, y)
		return x.centro < y.centro
	end)
	local cursor = 0
	for _, ab in lista do
		local ini = ab.centro - ab.largura / 2
		local fim = ab.centro + ab.largura / 2
		seg(cursor, ini, 0, altura)
		seg(ini, fim, 0, ab.base)
		seg(ini, fim, ab.topo, altura)
		cursor = fim
	end
	seg(cursor, comprimento, 0, altura)
	return pecas
end

-- Piso/teto (laje) com o topo na altura y
function Construtor:laje(x1: number, z1: number, x2: number, z2: number, yTopo: number, espessura: number, cor: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
	return self:entre(Vector3.new(x1, yTopo - espessura, z1), Vector3.new(x2, yTopo, z2), cor, material, extra)
end

function Construtor:luz(parte: Instance, classe: string, props: { [string]: any }): Light
	local l = Instance.new(classe) :: any
	for k, v in props do
		l[k] = v
	end
	l.Parent = parte
	return l
end

return Construtor
