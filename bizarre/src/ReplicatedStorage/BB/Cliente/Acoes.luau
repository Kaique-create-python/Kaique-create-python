-- BIZARRE BATTLEGROUNDS :: anima a ação de qualquer lutador (a sua na hora, a dos outros quando chega)
-- Mesmo código para os dois: M1, golpes do Stand, dash, evasiva, pose...

local Players = game:GetService("Players")

local BB = script.Parent.Parent
local Golpes = require(BB:WaitForChild("Golpes"))
local Stands = require(BB:WaitForChild("Stands"))
local Config = require(BB:WaitForChild("Config"))
local Animador = require(script.Parent:WaitForChild("Animador"))
local StandVisual = require(script.Parent:WaitForChild("StandVisual"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))
local Som = require(script.Parent:WaitForChild("Som"))

local Acoes = {}

local function raizDe(m: Model?): BasePart?
	return m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function standDe(m: Model): any
	return Stands.get(m:GetAttribute("BB_Stand") :: string?)
end

local M1_STAND = { "soco_e", "soco_d", "soco_e", "m1_4" }
local M1_PROPRIO = { "m1_1", "m1_2", "m1_3", "m1_4" }

-- dados = { id, n, variante, stand (bool), tipo, lado, resposta, ... }
function Acoes.tocar(modelo: Model?, dados: any)
	if not modelo then
		return
	end
	local raiz = raizDe(modelo)
	if not raiz then
		return
	end
	local id = dados.id
	local s = standDe(modelo)
	local agora = os.clock()
	if id == "m1" then
		local n = dados.n or 1
		local clipe = M1_PROPRIO[n] or "m1_1"
		local clipeS = M1_STAND[n] or "soco_d"
		if n == 4 and dados.variante == "cima" then
			clipe, clipeS = "m1_cima", "uppercut"
		elseif n == 4 and dados.variante == "baixo" then
			clipe, clipeS = "m1_baixo", "slam"
		end
		if s and s.m1 == "chutes" and (n == 2 or n == 4) and not dados.variante then
			clipe = "chute_1"
			clipeS = "chute"
		end
		if dados.stand then
			Animador.tocar(modelo, "comando_m1")
			StandVisual.acao(modelo, { modo = "frente_perto", clipe = clipeS, dur = if n == 4 then 0.45 else 0.3, impacto = 0.1 })
		else
			Animador.tocar(modelo, clipe)
		end
		Som.tocar(if n == 4 then "whoosh_forte" else "whoosh", raiz.Position, { max = 6 })
		if n == 4 then
			local cor = Efeitos.corStand(s and s.id)
			local braco = modelo:FindFirstChild("RightHand") :: BasePart?
			if dados.stand then
				local st = StandVisual.modelo(modelo)
				braco = st and st:FindFirstChild("RightHand") :: BasePart?
			end
			Efeitos.rastro(braco, cor, 0.3)
		end
		return
	elseif id == "dash" then
		local tipo = dados.tipo or "frente"
		local clipe = "dash_frente"
		if tipo == "tras" then
			clipe = "dash_tras"
		elseif tipo == "lado" then
			clipe = if dados.lado == "esquerda" then "dash_esquerda" else "dash_direita"
		end
		Animador.tocar(modelo, clipe)
		Som.tocar("dash", raiz.Position)
		local cor = Efeitos.corStand(s and s.id)
		Efeitos.fantasma(modelo, cor, 0.3)
		task.delay(0.1, function()
			Efeitos.fantasma(modelo, cor, 0.25)
		end)
		Efeitos.poeira(raiz.Position - Vector3.new(0, 2.6, 0), 2, nil, 6)
		return
	elseif id == "evasiva" then
		Animador.tocar(modelo, "evasiva")
		Som.tocar("evasiva", raiz.Position)
		local cor = Efeitos.corStand(s and s.id)
		Efeitos.anel(raiz.Position, Config.EVASIVA.raioEmpurrao, cor, 0.3, 0.5)
		Efeitos.bolha(raiz.Position, 6, cor, 0.3)
		return
	elseif id == "stand" then
		local cor = Efeitos.corStand(s and s.id)
		if dados.fora then
			Efeitos.bolha(raiz.Position + raiz.CFrame.RightVector * 2 + raiz.CFrame.LookVector * 2.4, 4, cor, 0.3, Enum.Material.Neon)
			Som.tocar("magia", raiz.Position)
		end
		return
	elseif id == "pose" then
		local n = dados.n or 1
		Animador.tocar(modelo, "pose" .. n, { ate = agora + 2.6 })
		Efeitos.ameaca(modelo, 2.4, Efeitos.corStand(s and s.id))
		StandVisual.acao(modelo, { modo = "costas", clipe = "s_ocioso", dur = 2.6 })
		return
	elseif id == "stand_visita" then
		StandVisual.visitar(modelo, dados.alvo, 0.3)
		return
	end
	-- golpe do Stand
	local g = Golpes.get(id)
	if not g then
		return
	end
	local dur = g.trava or 0.6
	if dados.resposta and g.resposta then
		local r = g.resposta
		Animador.tocar(modelo, r.animU or "chute_alto", { impacto = (r.hits and r.hits[1] and r.hits[1].t) or 0.16 })
		StandVisual.acao(modelo, { modo = "frente", clipe = r.animS or "chute", dur = 0.6, impacto = (r.hits and r.hits[1] and r.hits[1].t) or 0.16 })
		Som.tocar("whoosh_forte", raiz.Position)
		return
	end
	local impacto = g.animImpacto
	Animador.tocar(modelo, g.animU, { impacto = impacto, ate = agora + dur })
	local clipeS = g.animS
	local durStand = dur
	if g.tipo == "barragem" then
		durStand = (g.fim or dur) + 0.05
	end
	StandVisual.acao(modelo, { modo = g.standModo or "frente", clipe = clipeS, dur = durStand, impacto = impacto, escala = g.standEscala })
	Som.tocar("whoosh_forte", raiz.Position)
	local cor = Efeitos.corStand(s and s.id)
	-- barragem: punhos fantasmas e grito
	if g.tipo == "barragem" then
		task.delay(g.inicio or 0.1, function()
			if clipeS == "barragem" then
				Efeitos.punhos(StandVisual.modelo(modelo), (g.fim or 1) - (g.inicio or 0), cor)
			end
			Som.tocar("grito", raiz.Position, { vol = 0.8 })
			if g.onomatopeia then
				Efeitos.onomatopeia(raiz.Position + raiz.CFrame.LookVector * 5, g.onomatopeia, cor, 1.2)
			end
		end)
	elseif g.onomatopeia then
		local t = impacto or (g.hits and g.hits[1] and g.hits[1].t) or 0.3
		task.delay(t, function()
			Efeitos.onomatopeia(raiz.Position + raiz.CFrame.LookVector * 4, g.onomatopeia, cor, 1.1)
		end)
	end
	-- trocas de clipe no meio do golpe (FREVO voo, FUNK batidão)
	if g.animTroca then
		for _, tr in g.animTroca do
			task.delay(tr.t, function()
				Animador.tocar(modelo, tr.animU, { ate = os.clock() + math.max(0.2, dur - tr.t) })
				StandVisual.acao(modelo, { modo = g.standModo or "frente", clipe = tr.animS, dur = math.max(0.2, dur - tr.t) })
			end)
		end
	end
	if g.animRepetir then
		for i, t in g.animRepetir do
			if i > 1 then
				task.delay(t - 0.3, function()
					Animador.tocar(modelo, g.animU)
					StandVisual.acao(modelo, { modo = g.standModo or "frente", clipe = g.animS, dur = 0.4 })
				end)
			end
		end
	end
	if g.vfxContinuo and g.vfxContinuo.tipo == "lanca_chamas" then
		task.delay(g.vfxContinuo.de, function()
			Efeitos.lancaChamas(modelo, g.vfxContinuo.ate - g.vfxContinuo.de)
		end)
	end
	if g.investida and g.investida.rastro == "fogo" then
		Efeitos.rastro(raiz, Color3.fromRGB(255, 130, 30), 0.5)
	end
	if g.tipo == "investida" or (g.tipo == "agarrar" and g.investida) then
		task.delay(0.05, function()
			Efeitos.fantasma(modelo, cor, 0.3)
		end)
	end
	if g.ult then
		Efeitos.ameaca(modelo, 1.5, cor)
		Som.tocar("gongo", raiz.Position, { alcance = 400 })
	end
end

local _ = Players
return Acoes
