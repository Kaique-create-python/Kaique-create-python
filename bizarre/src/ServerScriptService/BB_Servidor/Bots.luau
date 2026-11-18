-- BIZARRE BATTLEGROUNDS :: bonecos de treino e bots que lutam de verdade
-- Bonecos ficam parados na área de TREINO (um deles bloqueia). Bots perseguem, fazem combo,
-- bloqueiam, dão dash e usam os golpes do Stand deles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BB = ReplicatedStorage:WaitForChild("BB")
local Config = require(BB:WaitForChild("Config"))
local Regras = require(BB:WaitForChild("Regras"))
local Stands = require(BB:WaitForChild("Stands"))
local Golpes = require(BB:WaitForChild("Golpes"))
local Rig = require(BB:WaitForChild("Rig"))

local Lutadores = require(script.Parent.Lutadores)
local Combate = require(script.Parent.Combate)
local Fisica = require(script.Parent.Fisica)
local Hitbox = require(script.Parent.Hitbox)
local Mapa = require(script.Parent.Mapa)

local Bots = {}

local pasta: Folder? = nil
local bots: { any } = {}
local bonecos: { any } = {}
local NOMES = { "Rival Bizarro", "Capanga", "Valentão", "Desafiante", "Duelista", "Arruaceiro" }
local DIFICULDADE = {
	facil = { reacao = 0.55, bloqueio = 0.12, golpe = 0.25, evasiva = 0.2, combo = 2 },
	medio = { reacao = 0.32, bloqueio = 0.3, golpe = 0.45, evasiva = 0.45, combo = 4 },
	dificil = { reacao = 0.16, bloqueio = 0.5, golpe = 0.7, evasiva = 0.8, combo = 4 },
}

local function agora()
	return workspace:GetServerTimeNow()
end

local function pastaBots(): Folder
	if pasta and pasta.Parent then
		return pasta
	end
	local p = Instance.new("Folder")
	p.Name = "BB_Bots"
	p.Parent = workspace
	pasta = p
	return p
end

-- corpo do bot: avatar R6 do catálogo com cores sorteadas (ou o corpo R6 reserva)
local function corpo(nome: string, cores: any, boneco: boolean): Model
	local ok, modelo = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = cores.cabeca
		d.TorsoColor = cores.torso
		d.LeftArmColor = cores.bracos
		d.RightArmColor = cores.bracos
		d.LeftLegColor = cores.pernas
		d.RightLegColor = cores.pernas
		if not boneco then
			local chapeus = { "14012017490", "13704302370", "118122669761516" }
			d.HatAccessory = chapeus[math.random(1, #chapeus)]
		end
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R6)
	end)
	local m: Model
	if ok and modelo then
		m = modelo
		for _, s in m:GetDescendants() do
			if s:IsA("Script") or s:IsA("LocalScript") then
				s:Destroy()
			end
		end
	else
		m = Rig.montarR6(nome, cores, true)
	end
	m.Name = nome
	-- com StreamingEnabled o celular recebe o corpo inteiro de uma vez
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.MaxHealth = Config.VIDA
	hum.Health = Config.VIDA
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	return m
end

local function prepararLutador(m: Model, standId: string, opcoes: any)
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	local raiz = m:FindFirstChild("HumanoidRootPart") :: BasePart
	m.Parent = pastaBots()
	pcall(function()
		raiz:SetNetworkOwner(nil)
	end)
	Fisica.grupo(m, Fisica.GRUPOS.lutador)
	local lut = Lutadores.criar(m, nil, standId, opcoes)
	hum.Died:Connect(function()
		Combate.abate(lut)
		task.delay(3, function()
			Lutadores.remover(m)
			m:Destroy()
		end)
	end)
	return lut
end

----------------------------------------------------------------------------------------- bonecos
local function criarBoneco(i: number, cf: CFrame)
	local cores = { cabeca = Color3.fromRGB(196, 150, 96), torso = Color3.fromRGB(176, 130, 80), bracos = Color3.fromRGB(196, 150, 96), pernas = Color3.fromRGB(150, 110, 70) }
	local nome = if i == 2 then "Boneco que Bloqueia" else "Boneco de Treino"
	local m = corpo(nome, cores, true)
	m:PivotTo(cf)
	local lut = prepararLutador(m, Stands.ORDEM[1], { boneco = true, nome = nome })
	lut.hum.WalkSpeed = 0
	lut.hum.JumpHeight = 0
	lut.bloqueiaSempre = i == 2
	lut.casa = cf
	m:SetAttribute("BB_Boneco", true)
	bonecos[i] = lut
	return lut
end

function Bots.criarLaboratorio17(dono: Player, cf: CFrame)
 local cores={cabeca=Color3.fromRGB(199,171,136),torso=Color3.fromRGB(83,80,101),bracos=Color3.fromRGB(199,171,136),pernas=Color3.fromRGB(51,48,65)}
 local m=corpo("Alvo de "..dono.DisplayName,cores,true)
 m:PivotTo(cf)
 local lut=prepararLutador(m,Stands.ORDEM[1],{boneco=true,nome=m.Name})
 lut.hum.WalkSpeed=0;lut.hum.JumpHeight=0;lut.imortal=true
 lut.laboratorioDono17=dono;lut.casa=cf
 m:SetAttribute("BB_Boneco",true);m:SetAttribute("BB_LaboratorioDono",dono.UserId)
 return lut
end

function Bots.criarBonecos()
	local treino = Mapa.treino()
	if not treino then
		return
	end
	for i, cf in treino.bonecos do
		if not bonecos[i] or not bonecos[i].modelo.Parent or bonecos[i].hum.Health <= 0 then
			criarBoneco(i, cf)
		end
	end
end

----------------------------------------------------------------------------------------- bots
function Bots.criar(perto: Vector3?, standId: string?, dificuldade: string?, dono: Player?)
	local ativos = 0
	for _, b in bots do
		if b.modelo.Parent then
			ativos += 1
		end
	end
	if ativos >= Config.BOTS.maximo then
		return nil, "limite de bots no servidor"
	end
	local stand = standId or Stands.ORDEM[math.random(1, #Stands.ORDEM)]
	local s = Stands.get(stand)
	local cores = {
		cabeca = Color3.fromRGB(245, 205, 48),
		torso = s.cor,
		bracos = Color3.fromRGB(245, 205, 48),
		pernas = s.corPernas or s.cor,
	}
	local nome = NOMES[math.random(1, #NOMES)]
	local m = corpo(nome, cores, false)
	local spawns = Mapa.spawns()
	local cf = if perto then CFrame.new(perto + Vector3.new(math.random(-14, 14), 4, math.random(-14, 14))) else spawns[math.random(1, math.max(1, #spawns))]
	m:PivotTo(cf or CFrame.new(0, 6, 0))
	local lut = prepararLutador(m, stand, { bot = true, nome = nome .. " [" .. s.nome .. "]" })
	lut.dificuldade = DIFICULDADE[dificuldade or Config.BOTS.dificuldade] or DIFICULDADE.medio
	lut.dono = dono
	lut.proximaDecisao = 0
	m:SetAttribute("BB_Bot", true)
	table.insert(bots, lut)
	return lut
end

-- quantos bots esse jogador já chamou (o treino não cria bot duplicado)
function Bots.doDono(dono: Player): number
	local n = 0
	for _, b in bots do
		if b.dono == dono and b.modelo.Parent and b.hum.Health > 0 then
			n += 1
		end
	end
	return n
end

function Bots.limpar(dono: Player?)
	for i = #bots, 1, -1 do
		local b = bots[i]
		if not dono or b.dono == dono then
			Lutadores.remover(b.modelo)
			b.modelo:Destroy()
			table.remove(bots, i)
		end
	end
end

local function alvoMaisPerto(b: any): any
	local melhor, d = nil, math.huge
	for _, l in Lutadores.vivos() do
		if l ~= b and not l.boneco and not l.bot then
			local dist = (l.raiz.Position - b.raiz.Position).Magnitude
			if dist < d and dist < 220 then
				melhor, d = l, dist
			end
		end
	end
	return melhor, d
end

local function virarPara(b: any, pos: Vector3)
	local p = b.raiz.Position
	local alvo = Vector3.new(pos.X, p.Y, pos.Z)
	if (alvo - p).Magnitude < 0.3 then
		return
	end
	b.hum.AutoRotate = false
	b.raiz.CFrame = CFrame.lookAt(p, alvo)
	b.dir = Regras.achatar(alvo - p)
	b.dirT = agora()
end

local function pensar(b: any)
	local t = agora()
	local e = b.estado
	local dif = b.dificuldade
	if b.hum.Health <= 0 or t < b.proximaDecisao then
		return
	end
	b.proximaDecisao = t + dif.reacao * (0.6 + math.random() * 0.8)
	-- atordoado: às vezes usa a evasiva
	if Regras.atordoado(e, t) then
		if Regras.podeEvasiva(e, t) and math.random() < dif.evasiva * 0.5 then
			Combate.evasiva(b)
		end
		return
	end
	local alvo, dist = alvoMaisPerto(b)
	if not alvo then
		b.hum:Move(Vector3.zero)
		b.hum.AutoRotate = true
		return
	end
	-- despertar quando der
	if Regras.podeDespertar(e, t) then
		Combate.despertar(b)
		return
	end
	if Regras.desperto(e, t) and not e.ultUsado and dist < 30 and math.random() < 0.5 then
		virarPara(b, alvo.raiz.Position)
		Combate.golpe(b, "ult", {})
		return
	end
	-- o alvo está atacando de perto: bloqueia às vezes
	local alvoAtacando = t < alvo.estado.acaoAte and dist < 12
	if alvoAtacando and math.random() < dif.bloqueio then
		virarPara(b, alvo.raiz.Position)
		Combate.bloquear(b, true)
		task.delay(0.6 + math.random() * 0.5, function()
			Combate.bloquear(b, false)
		end)
		return
	end
	if e.bloqueando then
		Combate.bloquear(b, false)
	end
	-- golpe do Stand se estiver no alcance
	if math.random() < dif.golpe then
		local opcoes = {}
		for slot = 1, 4 do
			local g, id = Golpes.doSlot(b.stand, slot)
			if g and id and Regras.cdPronto(e, id, t) then
				local alcance = g.alcance or 8
				if (alcance == 0 and b.hum.Health < b.hum.MaxHealth * 0.6) or (alcance > 0 and dist <= alcance + 2 and dist >= math.min(4, alcance * 0.3)) then
					table.insert(opcoes, slot)
				end
			end
		end
		if #opcoes > 0 then
			virarPara(b, alvo.raiz.Position)
			Combate.golpe(b, opcoes[math.random(1, #opcoes)], {})
			return
		end
	end
	-- perto: combo de M1
	if dist < 7.5 then
		virarPara(b, alvo.raiz.Position)
		b.hum:Move(Vector3.zero)
		local n = 0
		local limite = dif.combo
		local function socar()
			if b.hum.Health <= 0 or n >= limite then
				return
			end
			n += 1
			virarPara(b, alvo.raiz.Position)
			if not b.estado.standFora and math.random() < 0.4 then
				Combate.alternarStand(b)
			end
			Combate.m1(b, { variante = nil })
			task.delay(Config.M1.intervalo + 0.03, socar)
		end
		socar()
		b.proximaDecisao = t + Config.M1.intervalo * limite + 0.2
		return
	end
	-- longe: corre atrás (às vezes dá dash)
	b.hum.AutoRotate = true
	b.correndo = dist > 25
	b.hum:MoveTo(alvo.raiz.Position)
	if dist > 18 and dist < 45 and Regras.cdPronto(e, "dash_frente", t) and math.random() < 0.35 then
		virarPara(b, alvo.raiz.Position)
		Combate.dash(b, { tipo = "frente", mov = b.dir })
	end
end

function Bots.iniciar()
	local acum = 0
	RunService.Heartbeat:Connect(function(dt)
		acum += dt
		if acum < 0.1 then
			return
		end
		acum = 0
		for i = #bots, 1, -1 do
			local b = bots[i]
			if not b.modelo.Parent then
				table.remove(bots, i)
			else
				pcall(pensar, b)
			end
		end
		-- bonecos: o que bloqueia segura a guarda; todos voltam para o lugar
		local t = agora()
		for _, bo in bonecos do
			if bo.modelo.Parent and bo.hum.Health > 0 then
				if bo.bloqueiaSempre and not bo.estado.bloqueando and not Regras.atordoado(bo.estado, t) and bo.estado.guarda > 30 then
					Combate.bloquear(bo, true)
				end
				if not Regras.atordoado(bo.estado, t) and (bo.raiz.Position - bo.casa.Position).Magnitude > 6 and not bo.raiz.Anchored then
					bo.modelo:PivotTo(bo.casa)
				end
			end
		end
	end)
	-- bonecos que morreram voltam
	task.spawn(function()
		while true do
			task.wait(3)
			pcall(Bots.criarBonecos)
		end
	end)
end

function Bots.lista()
	return bots
end

return Bots
