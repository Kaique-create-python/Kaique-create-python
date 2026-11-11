-- BIZARRE BATTLEGROUNDS :: VFX dos golpes (AJUSTE-13)
-- Só efeitos de verdade: os dos pacotes que o dono pegou na loja do Roblox. O servidor (VFXLoja)
-- carrega cada pacote, tira os scripts, separa por tipo (impacto, choque, explosão, faísca,
-- flash, fumaça, fogo, aura, corte...) e mede cada efeito (tamanho, duração, cor).
-- Aqui cada golpe é montado em CAMADAS com esses efeitos:
--   * o mesmo golpe do mesmo Stand escolhe sempre os mesmos efeitos (cara de jogo profissional);
--   * cada efeito vai para a escala certa do golpe (soco leve pequeno, finalização enorme);
--   * a cor vira a do Stand (o branco do miolo continua branco; na aparição do Stand tudo ganha a
--     cor dele: nada de luz verde no Star Platinum);
--   * peças, feixes e luzes do pacote acendem e somem sozinhos; nada encosta em ninguém.
-- Se um tipo não existir nos pacotes (ou eles ainda não carregaram), entra só um efeito simples
-- de partículas com as texturas do próprio Roblox (as mesmas da explosão/fogo dele).
-- Nada de peças Neon desenhadas (AJUSTE-13: o dono pediu para tirar os efeitos simples).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BB = script.Parent.Parent
local Medida = require(BB:WaitForChild("VFXMedida"))

local VFX = {}

local RGB = Color3.fromRGB
local BRANCO = RGB(255, 255, 255)
local AZUL_GUARDA = RGB(150, 205, 255)
VFX.BRANCO = BRANCO
VFX.AZUL_GUARDA = AZUL_GUARDA

local rng = Random.new()
local alta = true
local vivos = 0 -- efeitos vivos agora (cada um tem várias partículas)
local TETO = 48 -- passou disso, as camadas extras são puladas (o celular não engasga)
local pasta: Instance? = nil
VFX.contagem = { pacote = 0, roblox = 0 } -- quantos efeitos saíram de cada jeito (DIAG/testes)

-- texturas que já vêm dentro do Roblox (só para a reserva, quando falta o pacote)
local TEX = {
	brilho = "rbxasset://textures/particles/sparkles_main.dds",
	onda = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	clarao = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	nucleo = "rbxasset://textures/particles/explosion01_core_main.dds",
	fumaca = "rbxasset://textures/particles/smoke_main.dds",
	fogo = "rbxasset://textures/particles/fire_main.dds",
	faisca = "rbxasset://textures/particles/fire_sparks_main.dds",
}

function VFX.qualidade(sim: boolean)
	alta = sim
end

function VFX.vivos(): number
	return vivos
end

-- só para os testes (cada cena começa do zero)
function VFX._zerarContagem()
	vivos = 0
	VFX.contagem = { pacote = 0, roblox = 0 }
end

local function obterPasta(): Instance
	if pasta and pasta.Parent then
		return pasta
	end
	local p = workspace:FindFirstChild("BB_VFX")
	if not p then
		p = Instance.new("Folder")
		p.Name = "BB_VFX"
		p.Parent = workspace
	end
	pasta = p
	return p
end

local function tween(obj: Instance, dur: number, props: any, estilo: Enum.EasingStyle?)
	local t = TweenService:Create(obj, TweenInfo.new(dur, estilo or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- olhando para "dir" (cuida do caso de olhar reto para cima/baixo)
local function olhando(pos: Vector3, dir: Vector3): CFrame
	local u = dir.Unit
	if math.abs(u.Y) > 0.97 then
		return CFrame.new(pos) * CFrame.Angles(if u.Y > 0 then math.pi / 2 else -math.pi / 2, 0, 0)
	end
	return CFrame.lookAt(pos, pos + u)
end
VFX._olhando = olhando

local function unidade(v: Vector3?): Vector3?
	if v and v.Magnitude > 0.01 then
		return v.Unit
	end
	return nil
end

-- solta n partículas (protegido: um pacote estranho nunca derruba o efeito inteiro)
local function emitir(e: any, n: number)
	pcall(function()
		e:Emit(n)
	end)
end

----------------------------------------------------------------------------------- pacotes da loja
local pastaLojaTeste: Instance? = nil
function VFX._lojaPasta(p: Instance?)
	pastaLojaTeste = p
end
local function lojaPasta(): Instance?
	if pastaLojaTeste then
		return pastaLojaTeste
	end
	return ReplicatedStorage:FindFirstChild("BB_VFXLoja")
end

-- o que serve em cada tipo: duração máxima (efeito de aura longa não vira soco) e quantos dos
-- melhores entram na escolha fixa
local REGRAS: { [string]: { vidaMax: number, topo: number } } = {
	impacto = { vidaMax = 2, topo = 4 },
	choque = { vidaMax = 2.5, topo = 3 },
	explosao = { vidaMax = 3.5, topo = 3 },
	faisca = { vidaMax = 2, topo = 3 },
	flash = { vidaMax = 2, topo = 3 },
	fumaca = { vidaMax = 4, topo = 3 },
	fogo = { vidaMax = 4, topo = 3 },
	aura = { vidaMax = 4, topo = 4 },
	corte = { vidaMax = 2, topo = 4 },
	chao = { vidaMax = 5, topo = 2 },
	laser = { vidaMax = 3, topo = 2 },
	outros = { vidaMax = 2.5, topo = 4 },
}

function VFX.temLoja(tipo: string): boolean
	local p = lojaPasta()
	local c = p and p:FindFirstChild(tipo)
	return c ~= nil and #c:GetChildren() > 0
end

local cacheTipos: { [string]: any } = {}

-- os efeitos de um tipo, do melhor para o pior (a lista é refeita se a pasta mudar)
local function candidatos(tipo: string): { any }?
	local p = lojaPasta()
	local c = p and p:FindFirstChild(tipo)
	if not c then
		return nil
	end
	local filhos = c:GetChildren()
	if #filhos == 0 then
		return nil
	end
	local cache = cacheTipos[tipo]
	if cache and cache.pasta == c and cache.n == #filhos then
		return cache.lista
	end
	local regra = REGRAS[tipo] or REGRAS.outros
	local lista = {}
	for _, f in filhos do
		local ok, m = pcall(Medida.ler, f)
		if ok and m and m.vida <= regra.vidaMax then
			table.insert(lista, { inst = f, m = m })
		end
	end
	if #lista == 0 then
		for _, f in filhos do
			local ok, m = pcall(Medida.ler, f)
			if ok and m then
				table.insert(lista, { inst = f, m = m })
			end
		end
	end
	table.sort(lista, function(a, b)
		if a.m.nota ~= b.m.nota then
			return a.m.nota > b.m.nota
		end
		return a.inst.Name < b.inst.Name
	end)
	cacheTipos[tipo] = { pasta = c, n = #filhos, lista = lista }
	return lista
end

local function distMatiz(a: number, b: number): number
	local d = math.abs(a - b) % 1
	return math.min(d, 1 - d)
end

-- escolha FIXA (mesma chave = mesmo efeito). Com cor: entre os melhores, prefere o que já tem a
-- cor do Stand ou é branco (o que vai ser pintado fica mais bonito)
local function escolher(tipo: string, chave: string?, cor: Color3?): any
	local lista = candidatos(tipo)
	if not lista or #lista == 0 then
		return nil
	end
	local regra = REGRAS[tipo] or REGRAS.outros
	local topo = math.min(#lista, regra.topo)
	if cor and (tipo == "aura" or tipo == "flash" or tipo == "fogo") then
		local h = cor:ToHSV()
		local ordem = {}
		for i = 1, math.min(#lista, topo + 2) do
			local m = lista[i].m
			local d = if m.saturacao > 0.25 then distMatiz(m.matiz, h) else 0.12
			table.insert(ordem, { item = lista[i], d = d })
		end
		table.sort(ordem, function(a, b)
			if math.abs(a.d - b.d) > 0.02 then
				return a.d < b.d
			end
			return a.item.m.nota > b.item.m.nota
		end)
		-- só entram os que têm a cor do Stand (ou são brancos): nada de aura verde no Star Platinum
		local aceitos = {}
		for _, o in ordem do
			if o.d <= ordem[1].d + 0.06 then
				table.insert(aceitos, o)
			end
		end
		return aceitos[(Medida.hash(chave or tipo) % #aceitos) + 1].item
	end
	return lista[(Medida.hash(chave or tipo) % topo) + 1]
end
VFX._escolher = escolher

-- leva a cópia para "destino": o centro do efeito vai para o ponto do golpe e tudo gira junto
local function colocar(copia: Instance, centro: Vector3, destino: CFrame): Instance
	local base = CFrame.new(centro)
	if copia:IsA("BasePart") then
		copia.CFrame = destino * base:ToObjectSpace(copia.CFrame)
		copia.Anchored = true
		copia.Parent = obterPasta()
		return copia
	elseif copia:IsA("Model") then
		for _, d in copia:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = destino * base:ToObjectSpace(d.CFrame)
				d.Anchored = true
			end
		end
		copia.Parent = obterPasta()
		return copia
	end
	-- anexo ou emissor solto: uma peça invisível segura no lugar
	local suporte = Instance.new("Part")
	suporte.Anchored = true
	suporte.CanCollide = false
	suporte.CanQuery = false
	suporte.CanTouch = false
	suporte.CastShadow = false
	suporte.Transparency = 1
	suporte.Size = Vector3.one * 0.2
	suporte.CFrame = destino
	if copia:IsA("Attachment") then
		copia.CFrame = CFrame.identity * copia.CFrame.Rotation
		copia.Parent = suporte
	else
		local a = Instance.new("Attachment")
		a.Parent = suporte
		copia.Parent = a
	end
	suporte.Parent = obterPasta()
	return suporte
end

-- acende tudo do jeito que o pacote configurou e devolve quanto tempo dura
local function tocar(suporte: Instance, dur: number?): number
	local vida = 0.5
	local itens = suporte:GetDescendants()
	table.insert(itens, suporte)
	for _, d in itens do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			local atraso = tonumber(d:GetAttribute("EmitDelay")) or 0
			local duracao = tonumber(d:GetAttribute("EmitDuration"))
			local contar = tonumber(d:GetAttribute("EmitCount")) or tonumber(d:GetAttribute("emitcount"))
			if contar == nil and dur and d.Rate > 0 then
				duracao = duracao or dur
			end
			if duracao and duracao > 0 and contar == nil then
				-- efeito contínuo (aura, fogo): fica ligado um pouco e desliga
				task.delay(atraso, function()
					if d.Parent then
						d.Enabled = true
						task.delay(math.min(duracao, 3), function()
							if d.Parent then
								d.Enabled = false
							end
						end)
					end
				end)
				vida = math.max(vida, atraso + math.min(duracao, 3) + d.Lifetime.Max)
			else
				local n = contar or math.clamp(math.floor(d.Rate * 0.12), 2, 30)
				n = math.clamp(math.floor(n * (if alta then 1 else 0.6) + 0.5), 1, if alta then 70 else 30)
				if atraso > 0 then
					task.delay(atraso, function()
						if d.Parent then
							emitir(d, n)
						end
					end)
				else
					emitir(d, n)
				end
				vida = math.max(vida, atraso + d.Lifetime.Max)
			end
		elseif d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = true
			local t = dur or 0.25
			task.delay(t, function()
				if d.Parent then
					d.Enabled = false
				end
			end)
			vida = math.max(vida, t + 0.3)
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Transparency < 1 then
				-- as peças visíveis (ondas, cortes) eram animadas pelo script do pacote: crescem e somem
				tween(d, 0.4, { Size = d.Size * 1.45, Transparency = 1 })
			end
		elseif d:IsA("Decal") or d:IsA("Texture") then
			tween(d, 0.4, { Transparency = 1 })
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			tween(d, 0.45, { Brightness = 0 })
		end
	end
	return math.min(vida + 0.3, 6)
end

-- o = { dir, cor, raio, chave, forte (pinta o branco também), tingir (false = cores do pacote),
--       dur (efeito contínuo ligado por x s), rolar (gira em volta da direção) }
local function doPacote(tipo: string, pos: Vector3, o: any): boolean
	local item = escolher(tipo, o.chave, o.cor)
	if not item then
		return false
	end
	local ok, res = pcall(function()
		local copia = item.inst:Clone()
		if o.cor and o.tingir ~= false then
			Medida.tingir(copia, o.cor, o.forte)
		end
		local centro = Medida.centro(copia)
		local e = math.clamp((o.raio or item.m.raio) / math.max(item.m.raio, 0.3), 0.12, 5)
		Medida.escalar(copia, e, centro)
		local giro = CFrame.identity
		local d = unidade(o.dir)
		if d then
			giro = olhando(Vector3.zero, d)
		end
		if o.rolar then
			giro = giro * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
		end
		local suporte = colocar(copia, centro, CFrame.new(pos) * giro)
		vivos += 1
		local vida = tocar(suporte, o.dur)
		task.delay(vida, function()
			vivos -= 1
			suporte:Destroy()
		end)
		return true
	end)
	if ok and res then
		VFX.contagem.pacote += 1
		return true
	end
	if not ok then
		VFX.ultimoErro = string.sub(tostring(res), 1, 200) -- aparece no DIAG
	end
	return false
end

----------------------------------------------------------------------------------- reserva do Roblox
-- quando falta o pacote: partículas com as texturas que já vêm no Roblox (nunca fica sem nada)
local RESERVA: { [string]: any } = {
	impacto = { tex = "brilho", n = 10, tam = 0.45, vel = 7, vida = 0.28, luz = 1 },
	faisca = { tex = "brilho", n = 12, tam = 0.35, vel = 9, vida = 0.32, luz = 1 },
	flash = { tex = "clarao", n = 1, tam = 1.4, vel = 0, vida = 0.22, luz = 1, cresce = true },
	choque = { tex = "onda", n = 1, tam = 2, vel = 0, vida = 0.3, luz = 1, cresce = true },
	explosao = { tex = "nucleo", n = 6, tam = 0.9, vel = 4, vida = 0.45, luz = 1 },
	fumaca = { tex = "fumaca", n = 8, tam = 0.8, vel = 3, vida = 0.9, luz = 0, cinza = true },
	chao = { tex = "fumaca", n = 10, tam = 0.9, vel = 4, vida = 1, luz = 0, cinza = true },
	fogo = { tex = "fogo", n = 10, tam = 0.7, vel = 4, vida = 0.6, luz = 1, sobe = true },
	aura = { tex = "brilho", n = 16, tam = 0.4, vel = 3, vida = 0.8, luz = 1, sobe = true },
}

local function doRoblox(tipo: string, pos: Vector3, o: any): boolean
	local r = RESERVA[tipo]
	if not r then
		return false
	end
	local raio = o.raio or 2
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX[r.tex]
	local cor = if r.cinza then RGB(205, 200, 210) else (o.cor or BRANCO)
	e.Color = if r.cinza then ColorSequence.new(cor) else ColorSequence.new(BRANCO, cor)
	e.LightEmission = r.luz
	e.LightInfluence = if r.luz > 0 then 0 else 0.6
	local t0 = raio * r.tam
	e.Size = if r.cresce
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, t0 * 0.3), NumberSequenceKeypoint.new(1, t0 * 1.6) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, t0), NumberSequenceKeypoint.new(1, if r.cinza then t0 * 1.8 else 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, if r.cinza then 0.45 else 0.05), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(r.vida * 0.7, r.vida)
	e.Speed = NumberRange.new(raio * r.vel * 0.5, raio * r.vel)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 5
	e.Acceleration = if r.sobe then Vector3.new(0, raio * 4, 0) else Vector3.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.ZOffset = 1
	e.Rate = 0
	e.Parent = a
	emitir(e, math.max(1, math.floor(r.n * (if alta then 1 else 0.5))))
	Debris:AddItem(a, r.vida + 0.4)
	VFX.contagem.roblox += 1
	return true
end

----------------------------------------------------------------------------------- base
-- um efeito de um tipo no ponto. Primeiro o do pacote; sem ele, a reserva do Roblox.
function VFX.efeito(tipo: string, pos: Vector3, o: any?): boolean
	local op = o or {}
	if vivos >= TETO then
		return false
	end
	if doPacote(tipo, pos, op) then
		return true
	end
	if op.semReserva then
		return false
	end
	return doRoblox(tipo, pos, op)
end

-- o primeiro tipo da lista que existir nos pacotes (sem nenhum: reserva do primeiro)
function VFX.umDe(tipos: { string }, pos: Vector3, o: any?): boolean
	local op = table.clone(o or {})
	op.semReserva = true
	for _, t in tipos do
		if VFX.efeito(t, pos, op) then
			return true
		end
	end
	if o and o.semReserva then
		return false
	end
	return doRoblox(tipos[1], pos, o or {})
end

-- compatibilidade (AJUSTE-11/12): efeito de um tipo da loja, com escala relativa
function VFX.loja(tipo: string, pos: Vector3, dir: Vector3?, escala: number?): boolean
	local item = escolher(tipo, nil, nil)
	if not item then
		return false
	end
	return VFX.efeito(tipo, pos, { dir = dir, raio = item.m.raio * (escala or 1), semReserva = true, chave = tostring(rng:NextInteger(1, 1e6)) })
end

function VFX.lojaUm(tipos: { string }, pos: Vector3, dir: Vector3?, escala: number?): boolean
	for _, t in tipos do
		if VFX.temLoja(t) and VFX.loja(t, pos, dir, escala) then
			return true
		end
	end
	return false
end

-- clarão de luz de verdade (ilumina o chão e as paredes perto)
function VFX.luz(pos: Vector3, cor: Color3, brilho: number, alcance: number, dur: number)
	if not alta then
		return
	end
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Brightness = brilho
	l.Range = math.min(alcance, 60)
	l.Shadows = false
	l.Parent = a
	tween(l, dur, { Brightness = 0 })
	Debris:AddItem(a, dur + 0.1)
end

----------------------------------------------------------------------------------- golpes
-- impacto em níveis: 0 rajada, 1 soco do combo, 2 golpe forte, 3 finalização/ULT.
-- chave = quem bateu (Stand + golpe): o mesmo golpe tem sempre a mesma cara
function VFX.impacto(pos: Vector3, dir: Vector3?, cor: Color3, nivel: number, chave: string?)
	local d = unidade(dir)
	local k = chave or "golpe"
	if nivel <= 0 then
		VFX.efeito("impacto", pos, { dir = d, cor = cor, raio = 1.6, chave = k .. ":r" .. rng:NextInteger(1, 2) })
		return
	end
	if nivel == 1 then
		VFX.efeito("impacto", pos, { dir = d, cor = cor, raio = 2.6, chave = k .. ":i1" })
		VFX.efeito("faisca", pos, { dir = d, cor = cor, raio = 2.2, chave = k .. ":f1", semReserva = true })
		VFX.luz(pos, cor, 3, 12, 0.12)
		return
	end
	if nivel == 2 then
		VFX.efeito("impacto", pos, { dir = d, cor = cor, raio = 3.6, chave = k .. ":i2" })
		VFX.efeito("choque", pos, { dir = d, cor = cor, raio = 5, chave = k .. ":c2" })
		VFX.efeito("faisca", pos, { dir = d, cor = cor, raio = 3.2, chave = k .. ":f2" })
		VFX.efeito("fumaca", pos, { raio = 3, chave = k .. ":p2", semReserva = not alta })
		VFX.luz(pos, cor, 5, 18, 0.18)
		return
	end
	VFX.umDe({ "explosao", "impacto" }, pos, { dir = d, cor = cor, raio = 6, chave = k .. ":e3" })
	VFX.efeito("impacto", pos, { dir = d, cor = cor, raio = 4.5, chave = k .. ":i3" })
	VFX.efeito("choque", pos, { dir = d, cor = cor, raio = 8.5, chave = k .. ":c3" })
	VFX.efeito("faisca", pos, { dir = d, cor = cor, raio = 4.5, chave = k .. ":f3" })
	VFX.efeito("fumaca", pos, { raio = 5, chave = k .. ":p3" })
	VFX.luz(pos, cor, 8, 26, 0.3)
end

-- soco no vento (o Stand bate mesmo sem acertar): o ar estoura na frente do punho
function VFX.estouroAr(pos: Vector3, dir: Vector3, cor: Color3, forte: boolean?, chave: string?)
	local k = chave or "soco"
	if forte then
		VFX.efeito("choque", pos, { dir = dir, cor = cor, raio = 3.2, chave = k .. ":ar4" })
		VFX.efeito("impacto", pos + dir * 0.6, { dir = dir, cor = cor, raio = 2, chave = k .. ":ar4i", semReserva = true })
	else
		VFX.efeito("choque", pos, { dir = dir, cor = cor, raio = 1.9, chave = k .. ":ar" })
	end
end

-- onda de pressão da barragem (ORA ORA / MUDA MUDA)
function VFX.pressao(pos: Vector3, dir: Vector3, cor: Color3, chave: string?)
	local k = chave or "rajada"
	VFX.efeito("choque", pos, { dir = dir, cor = cor, raio = 2.4, chave = k .. ":pr" })
	if rng:NextNumber() < 0.45 then
		VFX.efeito("impacto", pos + dir * 0.8, { dir = dir, cor = cor, raio = 1.7, chave = k .. ":pri" .. rng:NextInteger(1, 2) })
	end
end

-- guarda: faíscas azuladas onde o soco bateu no Stand
function VFX.guarda(pos: Vector3, dir: Vector3?, cor: Color3)
	local _ = cor
	VFX.efeito("faisca", pos, { dir = dir, cor = AZUL_GUARDA, raio = 2.2, chave = "guarda:f" })
	VFX.efeito("flash", pos, { cor = AZUL_GUARDA, raio = 1.6, chave = "guarda:l", semReserva = true })
	VFX.luz(pos, AZUL_GUARDA, 3, 10, 0.12)
end

-- guarda quebrada: o escudo estoura
function VFX.quebraGuarda(pos: Vector3, dir: Vector3?)
	VFX.umDe({ "explosao", "impacto" }, pos, { dir = dir, cor = AZUL_GUARDA, raio = 3.4, chave = "quebra:e" })
	VFX.efeito("choque", pos, { dir = dir, cor = AZUL_GUARDA, raio = 5.5, chave = "quebra:c" })
	VFX.efeito("faisca", pos, { dir = dir, cor = AZUL_GUARDA, raio = 3.4, chave = "quebra:f" })
	VFX.luz(pos, AZUL_GUARDA, 6, 18, 0.25)
end

-- parry perfeito: clarão branco, onda azul e faíscas
function VFX.parry(pos: Vector3, cor: Color3)
	local _ = cor
	VFX.efeito("flash", pos, { cor = BRANCO, raio = 3.6, chave = "parry:l" })
	VFX.efeito("choque", pos, { cor = AZUL_GUARDA, raio = 5.5, chave = "parry:c" })
	VFX.efeito("faisca", pos, { cor = AZUL_GUARDA, raio = 3.2, chave = "parry:f" })
	VFX.luz(pos, BRANCO, 7, 20, 0.3)
end

-- aparição de cada Stand: camadas próprias, tudo na cor dele
local APARICAO: { [string]: { any } } = {
	STAR_PLATINUM = { { "aura", 3.4 }, { "flash", 2.6 }, { "faisca", 2.4 } },
	THE_WORLD = { { "aura", 3.4 }, { "flash", 3 }, { "choque", 3.8 } },
	MAGICIANS_RED = { { "fogo", 3.6 }, { "aura", 3 }, { "faisca", 2.2 } },
	SILVER_CHARIOT = { { "corte", 3.4 }, { "flash", 2.4 }, { "faisca", 2.2 } },
	CRAZY_DIAMOND = { { "aura", 3.2 }, { "flash", 2.8 }, { "faisca", 2.6 } },
	KILLER_QUEEN = { { "aura", 3 }, { "explosao", 2 }, { "flash", 2.2 } },
}
local APARICAO_PADRAO = { { "aura", 3.2 }, { "flash", 2.6 }, { "faisca", 2.2 } }
VFX.APARICAO = APARICAO

function VFX.invocar(pos: Vector3, cor: Color3, standId: string?, escala: number?)
	local e = escala or 1
	local id = standId or "?"
	for i, camada in APARICAO[id] or APARICAO_PADRAO do
		VFX.efeito(camada[1], pos, {
			cor = cor,
			raio = camada[2] * e,
			chave = id .. ":aparece" .. i,
			forte = true,
			dur = if camada[1] == "aura" or camada[1] == "fogo" then 0.45 * e else nil,
			rolar = camada[1] == "corte",
			semReserva = i > 1,
		})
	end
	-- onda no chão
	VFX.efeito("choque", pos - Vector3.new(0, 2.6, 0), { dir = Vector3.yAxis, cor = cor, raio = 4.2 * e, chave = id .. ":aparece_chao", forte = true, semReserva = true })
	VFX.luz(pos, cor, 4 * e, 14 * e, 0.4)
end

-- ULT: a aparição em tamanho grande, explosão de aura e onda no chão
function VFX.ult(pos: Vector3, cor: Color3, standId: string?)
	local id = standId or "?"
	VFX.invocar(pos, cor, standId, 1.8)
	VFX.umDe({ "explosao", "choque" }, pos, { cor = cor, raio = 6, chave = id .. ":ult_e", forte = true })
	VFX.efeito("choque", pos - Vector3.new(0, 2.5, 0), { dir = Vector3.yAxis, cor = cor, raio = 12, chave = id .. ":ult_c", forte = true })
	VFX.efeito("aura", pos, { cor = cor, raio = 5, chave = id .. ":ult_a", forte = true, dur = 1.1, semReserva = true })
end

-- dash: poeira nos pés e o ar abrindo atrás
function VFX.dash(pe: Vector3, dir: Vector3, cor: Color3)
	VFX.efeito("fumaca", pe + Vector3.new(0, 0.6, 0), { dir = -dir, raio = 2.4, chave = "dash:p" })
	VFX.efeito("choque", pe + Vector3.new(0, 2.4, 0) - dir * 1.5, { dir = -dir, cor = cor, raio = 2.2, chave = "dash:c", semReserva = true })
end

-- corte de lâmina (Silver Chariot): o corte do pacote virado na direção do golpe
function VFX.corte(pos: Vector3, dir: Vector3?, cor: Color3, forte: boolean?, chave: string?)
	local k = chave or "corte"
	local ok = VFX.efeito("corte", pos, { dir = dir, cor = cor, raio = if forte then 4.6 else 3.2, chave = k .. ":" .. rng:NextInteger(1, 3), rolar = true, semReserva = true })
	if not ok then
		VFX.efeito("faisca", pos, { dir = dir, cor = cor, raio = 2, chave = k .. ":f" })
	end
end

-- explosão (Killer Queen, fogo, som)
function VFX.explosao(pos: Vector3, cor: Color3, raio: number, chave: string?)
	local k = chave or "explosao"
	VFX.umDe({ "explosao", "fogo", "impacto" }, pos, { cor = cor, raio = raio, chave = k .. ":e" })
	VFX.efeito("choque", pos, { cor = cor, raio = raio * 1.4, chave = k .. ":c", semReserva = true })
	VFX.efeito("fumaca", pos, { raio = raio * 0.8, chave = k .. ":p" })
	VFX.luz(pos, cor, 9, raio * 4, 0.5)
end

function VFX.fogo(pos: Vector3, raio: number, chave: string?)
	VFX.efeito("fogo", pos, { raio = raio, chave = chave or "fogo", tingir = false, dur = 0.35 })
end

function VFX.poeira(pos: Vector3, raio: number, chave: string?)
	VFX.umDe({ "fumaca", "chao" }, pos, { raio = raio, chave = chave or "poeira" })
end

function VFX.faiscas(pos: Vector3, cor: Color3, raio: number, chave: string?)
	VFX.efeito("faisca", pos, { cor = cor, raio = raio, chave = chave or "faiscas" })
end

-- onda de choque (anel) virada para "normal" (nil = de frente para todos os lados)
function VFX.onda(pos: Vector3, cor: Color3, raio: number, normal: Vector3?, chave: string?)
	VFX.efeito("choque", pos, { dir = normal, cor = cor, raio = raio, chave = chave or "onda" })
end

function VFX.brilho(pos: Vector3, cor: Color3, raio: number, chave: string?)
	VFX.umDe({ "flash", "impacto" }, pos, { cor = cor, raio = raio, chave = chave or "brilho" })
end

-- tempo parado: onda enorme com as cores do Stand, clarão e aura
function VFX.tempo(centro: Vector3, cor1: Color3, cor2: Color3, raio: number)
	VFX.efeito("choque", centro, { cor = cor1, raio = math.min(raio * 0.3, 45), chave = "tempo:c", forte = true })
	VFX.efeito("flash", centro, { cor = cor2, raio = 10, chave = "tempo:l", forte = true })
	VFX.efeito("aura", centro, { cor = cor1, raio = 8, chave = "tempo:a", forte = true, dur = 0.8, semReserva = true })
	VFX.luz(centro, cor1, 8, 60, 0.9)
end

-- o tempo volta: onda e clarão no dono
function VFX.tempoVolta(centro: Vector3, cor: Color3, raio: number)
	VFX.efeito("choque", centro, { cor = cor, raio = math.min(raio * 0.4, 20), chave = "tempo:volta", forte = true })
	task.delay(0.35, function()
		VFX.efeito("flash", centro, { cor = cor, raio = 6, chave = "tempo:volta_l", forte = true })
	end)
end

-- ORA x MUDA: o choque das duas rajadas no meio
function VFX.clash(pos: Vector3, cor1: Color3, cor2: Color3)
	VFX.efeito("faisca", pos, { cor = cor1, raio = 2.6, chave = "clash:f" .. rng:NextInteger(1, 2) })
	VFX.efeito("impacto", pos, { cor = cor2, raio = 2.2, chave = "clash:i" .. rng:NextInteger(1, 2), semReserva = true })
	if rng:NextNumber() < 0.5 then
		VFX.efeito("choque", pos, { cor = cor1:Lerp(cor2, 0.5), raio = 3.4, chave = "clash:c", semReserva = true })
	end
end

return VFX
