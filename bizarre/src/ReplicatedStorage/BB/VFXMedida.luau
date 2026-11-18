-- BIZARRE BATTLEGROUNDS :: medida dos efeitos dos pacotes (AJUSTE-13)
-- Usado pelo servidor (VFXLoja mede cada efeito uma vez e guarda em atributos) e pelo celular
-- (VFX usa as medidas para pôr cada efeito na escala certa e com a cor do Stand).
-- Nada aqui desenha efeito: só mede e ajusta os efeitos que vieram dos pacotes da loja.

local Medida = {}

local function maxSeq(ns: NumberSequence): number
	local m = 0
	for _, k in ns.Keypoints do
		m = math.max(m, k.Value + k.Envelope)
	end
	return m
end

-- posição de referência de uma peça/anexo (relativa ao modelo do pacote)
local function posicao(inst: Instance?): Vector3?
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.CFrame.Position
	elseif inst:IsA("Attachment") then
		local pai = inst.Parent
		if pai and pai:IsA("BasePart") then
			return (pai.CFrame * inst.CFrame).Position
		end
		return inst.CFrame.Position
	end
	return nil
end

-- o "centro" do efeito: a peça/anexo dele, ou a primeira peça de um modelo
function Medida.centro(raiz: Instance): Vector3
	local p = posicao(raiz)
	if p then
		return p
	end
	if raiz:IsA("Model") then
		local ok, cf = pcall(function()
			return raiz:GetPivot()
		end)
		if ok and typeof(cf) == "CFrame" then
			return cf.Position
		end
	end
	for _, d in raiz:GetDescendants() do
		local q = posicao(d)
		if q then
			return q
		end
	end
	return Vector3.zero
end

-- alcance (studs) e vida (s) de um emissor: metade do maior tamanho + o quanto a partícula anda
function Medida.emissor(e: ParticleEmitter): (number, number)
	local vida = e.Lifetime.Max
	local vel = e.Speed.Max
	local arrasto = e.Drag
	local anda = if arrasto > 0.01 then vel / arrasto * (1 - math.exp(-arrasto * vida)) else vel * vida
	anda += math.min(e.Acceleration.Magnitude * 0.5 * vida * vida, 40) * 0.5
	local r = maxSeq(e.Size) * 0.5 + anda
	local pai = e.Parent
	if pai and pai:IsA("BasePart") then
		r += math.max(pai.Size.X, pai.Size.Y, pai.Size.Z) * 0.5
	end
	return r, vida
end

local function corMedia(seq: ColorSequence): (number, number, number)
	-- matiz/saturação/brilho médios das cores do emissor (pesando a saturação)
	local sx, sy, ss, sv, n = 0, 0, 0, 0, 0
	for _, k in seq.Keypoints do
		local h, s, v = k.Value:ToHSV()
		sx += math.cos(h * 2 * math.pi) * s
		sy += math.sin(h * 2 * math.pi) * s
		ss += s
		sv += v
		n += 1
	end
	if n == 0 then
		return 0, 0, 1
	end
	local h = math.atan2(sy, sx) / (2 * math.pi)
	if h < 0 then
		h += 1
	end
	return h, ss / n, sv / n
end

-- mede o efeito inteiro: { raio, vida, emissores, rajada, continuo, matiz, saturacao, nota }
function Medida.medir(raiz: Instance): any
	local centro = Medida.centro(raiz)
	local raio, vida = 0, 0
	local emissores, rajada, continuo, pecas = 0, 0, 0, 0
	local sx, sy, ss, nCor = 0, 0, 0, 0
	local itens = raiz:GetDescendants()
	table.insert(itens, raiz)
	for _, d in itens do
		if d:IsA("ParticleEmitter") then
			local r, v = Medida.emissor(d)
			local onde = posicao(d.Parent)
			local dist = if onde then (onde - centro).Magnitude else 0
			raio = math.max(raio, r + dist)
			local atraso = tonumber(d:GetAttribute("EmitDelay")) or 0
			local duracao = tonumber(d:GetAttribute("EmitDuration")) or 0
			vida = math.max(vida, v + atraso + duracao)
			emissores += 1
			if d:GetAttribute("EmitCount") ~= nil or d.Rate <= 0 then
				rajada += 1
			else
				continuo += 1
			end
			local h, s = corMedia(d.Color)
			sx += math.cos(h * 2 * math.pi) * s
			sy += math.sin(h * 2 * math.pi) * s
			ss += s
			nCor += 1
		elseif d:IsA("Beam") then
			local a0, a1 = posicao(d.Attachment0), posicao(d.Attachment1)
			local meio = if a0 and a1 then (a0 + a1) / 2 else centro
			local comp = if a0 and a1 then (a0 - a1).Magnitude / 2 else 0
			raio = math.max(raio, math.max(d.Width0, d.Width1) / 2 + comp + (meio - centro).Magnitude)
			vida = math.max(vida, 0.5)
			emissores += 1
			rajada += 1
		elseif d:IsA("Trail") then
			vida = math.max(vida, d.Lifetime)
			emissores += 1
		elseif d:IsA("BasePart") and d.Transparency < 1 then
			pecas += 1
			raio = math.max(raio, math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2 + (d.CFrame.Position - centro).Magnitude)
			vida = math.max(vida, 0.4)
		end
	end
	local matiz = math.atan2(sy, sx) / (2 * math.pi)
	if matiz < 0 then
		matiz += 1
	end
	local saturacao = if nCor > 0 then ss / nCor else 0
	-- nota: efeito de rajada (feito para soltar de uma vez), em camadas e curto = melhor para golpe
	local nota = 0
	if rajada > 0 then
		nota += 2
	end
	if emissores >= 2 then
		nota += 1
	end
	if emissores >= 4 then
		nota += 1
	end
	if vida >= 0.2 and vida <= 1.6 then
		nota += 1
	elseif vida > 3 then
		nota -= 2
	end
	return {
		raio = math.clamp(raio, 0.3, 120),
		vida = math.clamp(vida, 0.1, 8),
		emissores = emissores,
		rajada = rajada,
		continuo = continuo,
		pecas = pecas,
		matiz = matiz,
		saturacao = saturacao,
		nota = nota,
	}
end

-- guarda as medidas como atributos (o celular lê sem medir de novo)
function Medida.anotar(inst: Instance, m: any)
	inst:SetAttribute("Raio", m.raio)
	inst:SetAttribute("Vida", m.vida)
	inst:SetAttribute("Emissores", m.emissores)
	inst:SetAttribute("Rajada", m.rajada)
	inst:SetAttribute("Continuo", m.continuo)
	inst:SetAttribute("Matiz", m.matiz)
	inst:SetAttribute("Saturacao", m.saturacao)
	inst:SetAttribute("Nota", m.nota)
end

function Medida.ler(inst: Instance): any
	local raio = inst:GetAttribute("Raio")
	if type(raio) ~= "number" then
		local m = Medida.medir(inst)
		Medida.anotar(inst, m)
		return m
	end
	return {
		raio = raio,
		vida = inst:GetAttribute("Vida") or 1,
		emissores = inst:GetAttribute("Emissores") or 1,
		rajada = inst:GetAttribute("Rajada") or 0,
		continuo = inst:GetAttribute("Continuo") or 0,
		matiz = inst:GetAttribute("Matiz") or 0,
		saturacao = inst:GetAttribute("Saturacao") or 0,
		nota = inst:GetAttribute("Nota") or 0,
	}
end

----------------------------------------------------------------------------------- cor do Stand
-- troca a cor mantendo o brilho: o que é colorido vira a cor do Stand; o branco do miolo fica
-- branco ("suave") ou ganha um pouco da cor ("forte", para aura e aparição do Stand)
function Medida.tingirCor(c: Color3, alvo: Color3, forte: boolean?): Color3
	local h, s, v = c:ToHSV()
	local ha, sa, _ = alvo:ToHSV()
	if s < 0.15 then
		if forte then
			return c:Lerp(Color3.fromHSV(ha, sa, v), 0.5)
		end
		return c
	end
	return Color3.fromHSV(ha, math.clamp(s * 0.35 + sa * 0.65, 0, 1), v)
end

function Medida.tingirSeq(seq: ColorSequence, alvo: Color3, forte: boolean?): ColorSequence
	local k = {}
	for _, kp in seq.Keypoints do
		table.insert(k, ColorSequenceKeypoint.new(kp.Time, Medida.tingirCor(kp.Value, alvo, forte)))
	end
	return ColorSequence.new(k)
end

-- pinta o efeito inteiro (partículas, feixes, rastros, peças e luzes)
function Medida.tingir(raiz: Instance, alvo: Color3, forte: boolean?)
	local itens = raiz:GetDescendants()
	table.insert(itens, raiz)
	for _, d in itens do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Color = Medida.tingirSeq(d.Color, alvo, forte)
		elseif d:IsA("BasePart") then
			d.Color = Medida.tingirCor(d.Color, alvo, forte)
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Color = alvo
		end
	end
end

----------------------------------------------------------------------------------- escala
local function escalarSeq(seq: NumberSequence, e: number): NumberSequence
	local k = {}
	for _, kp in seq.Keypoints do
		table.insert(k, NumberSequenceKeypoint.new(kp.Time, kp.Value * e, kp.Envelope * e))
	end
	return NumberSequence.new(k)
end

-- aumenta/diminui o efeito inteiro em volta do centro (peças, anexos, partículas, feixes, luzes)
function Medida.escalar(raiz: Instance, e: number, centro: Vector3)
	if math.abs(e - 1) < 0.01 then
		return
	end
	local itens = raiz:GetDescendants()
	table.insert(itens, raiz)
	for _, d in itens do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			d.Size = d.Size * e
			d.CFrame = CFrame.new(centro + (cf.Position - centro) * e) * cf.Rotation
		elseif d:IsA("Attachment") then
			if d.Parent and d.Parent:IsA("BasePart") then
				d.CFrame = CFrame.new(d.CFrame.Position * e) * d.CFrame.Rotation
			end
		elseif d:IsA("ParticleEmitter") then
			d.Size = escalarSeq(d.Size, e)
			d.Speed = NumberRange.new(d.Speed.Min * e, d.Speed.Max * e)
			d.Acceleration = d.Acceleration * e
		elseif d:IsA("Beam") then
			d.Width0 *= e
			d.Width1 *= e
			d.CurveSize0 *= e
			d.CurveSize1 *= e
		elseif d:IsA("SpecialMesh") then
			d.Scale = d.Scale * e
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(60, d.Range * e)
		end
	end
end

-- número fixo para um texto (o mesmo golpe do mesmo Stand escolhe sempre o mesmo efeito)
function Medida.hash(s: string): number
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 2147483647
	end
	return h
end

return Medida
