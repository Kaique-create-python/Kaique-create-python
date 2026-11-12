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
local VFX = require(script.Parent:WaitForChild("VFX"))
local Som = require(script.Parent:WaitForChild("Som"))

local Apresentacao = require(script.Parent:WaitForChild("Apresentacao14"))
local Acoes = {}

local function raizDe(m: Model?): BasePart?
	return m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function standDe(m: Model): any
	return Stands.get(m:GetAttribute("BB_Stand") :: string?)
end

local M1_STAND = { "soco_e", "soco_d", "soco_e", "m1_4" }

-- AJUSTE7: cada ação tem um número; atordoar/congelar/derrubar muda o número e tudo o que
-- ainda ia acontecer (voz, punhos, chamas, raios) para junto
local tokens: { [Model]: number } = setmetatable({}, {__mode="k"})
local vozes: { [Model]: { Sound } } = setmetatable({}, {__mode="k"})
local atuais: { [Model]: any } = setmetatable({}, {__mode="k"})
local ultVozes: { [Model]: { any } } = setmetatable({}, {__mode="k"})
local ultAtual: { [Model]: any } = setmetatable({}, {__mode="k"})
local ultimasSeq: { [Model]: number } = setmetatable({}, {__mode="k"})
local vistos: { [Model]: { [string]: number } } = setmetatable({}, {__mode="k"})
local ultimosTempos: { [Model]: number } = setmetatable({}, {__mode="k"})
local function pararVozes(lista: any)
 for _, snd in lista or {} do pcall(function() snd:Stop() end) end
end
local function coincide(atual: any, actionId: any, seq: any): boolean
 if not atual then return false end
 if actionId ~= nil and atual.actionId ~= actionId then return false end
 if seq ~= nil and atual.seq ~= seq then return false end
 return true
end
function Acoes.confirmar(modelo: Model?, dados: any): boolean
 local a = modelo and atuais[modelo]
 if not a or (dados.seq ~= nil and a.seq ~= dados.seq) then return false end
 if a.actionId and dados.actionId and a.actionId ~= dados.actionId then return false end
 a.actionId = dados.actionId or a.actionId
 if a.actionId and a.vfxId ~= a.actionId then Apresentacao.associar(modelo,a.vfxId,a.actionId);a.vfxId=a.actionId end
 if a.tempo then a.tempo.actionId = a.actionId end
 if a.actionId then vistos[modelo] = vistos[modelo] or {}; vistos[modelo][a.actionId] = workspace:GetServerTimeNow()+150 end
 return true
end
function Acoes.vincularTempo(modelo: Model?, dados: any)
 local u = modelo and ultAtual[modelo]
 if u then u.session = dados.sessao or dados.dono; u.fim = dados.fim end
end
function Acoes.encerrarTempo(modelo: Model?, session: any?)
 if not modelo then return end
 local list=ultVozes[modelo] or {}
 for i=#list,1,-1 do
  local u=list[i]
  if session == nil or u.session == session then u.active=false;pararVozes(u.vozes);table.remove(list,i) end
 end
end
function Acoes.concluir(modelo: Model?, dados: any): boolean
 local a = modelo and atuais[modelo]
 if not modelo or not coincide(a,dados.actionId,dados.seq) then return false end
 if dados.reason and dados.reason ~= "concluida" then return Acoes.interromper(modelo,dados.actionId,dados.seq) end
 tokens[modelo] = (tokens[modelo] or 0) + 1
 pararVozes(vozes[modelo]);vozes[modelo]=nil
 Apresentacao.cancelar(modelo,a.vfxId)
 atuais[modelo]=nil
 return true
end
local REACOES = { atordoado = true, atingido = true }

local function token(modelo: Model): number
	return tokens[modelo] or 0
end

local function vivo(modelo: Model, tk: number): () -> boolean
	return function()
		return modelo.Parent ~= nil and (tokens[modelo] or 0) == tk
	end
end

-- nome = um grito ou uma lista em ordem de preferência; devolve o nome que tocou
local function falar(modelo: Model, tk: number, nome: any, pos: Vector3, tempo: any?): string?
	if not modelo.Parent or (tempo and not tempo.active) or (not tempo and (tokens[modelo] or 0) ~= tk) then
		return nil
	end
	local snd, usado = Som.voz(nome, pos)
	if snd then
		local l = if tempo then tempo.vozes else (vozes[modelo] or {})
		table.insert(l, snd)
		if not tempo then vozes[modelo] = l end
	end
	return usado
end

function Acoes.interromper(modelo: Model?, actionId: string?, seq: number?): boolean
 if not modelo then return false end
 local a = atuais[modelo]
 if (actionId ~= nil or seq ~= nil) and not coincide(a,actionId,seq) then return false end
 tokens[modelo] = (tokens[modelo] or 0) + 1
 pararVozes(vozes[modelo]);vozes[modelo]=nil
 if actionId == nil and seq == nil then Acoes.encerrarTempo(modelo)
 elseif a and a.tempo then a.tempo.active=false;pararVozes(a.tempo.vozes) end
 Apresentacao.cancelar(modelo,if (actionId ~= nil or seq ~= nil) and a then a.vfxId else nil)
 atuais[modelo]=nil
 local atual = Animador.tocando(modelo)
 if atual and not REACOES[atual] then Animador.cortar(modelo) end
 StandVisual.cancelar(modelo)
 if modelo == Players.LocalPlayer.Character then require(script.Parent:WaitForChild("Cinematica")).cancelar() end
 return true
end
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
	local anterior = atuais[modelo]
 if vistos[modelo] then for key,expiry in vistos[modelo] do if expiry<=workspace:GetServerTimeNow() then vistos[modelo][key]=nil end end end
 if dados.seq==nil and dados.actionId and dados.t and dados.t<(ultimosTempos[modelo] or -math.huge) then return end
 if dados.actionId and vistos[modelo] and vistos[modelo][dados.actionId] then return end
 if dados.seq ~= nil and dados.seq <= (ultimasSeq[modelo] or -math.huge) then return end
 if anterior then
  pararVozes(vozes[modelo]);vozes[modelo]=nil
  Apresentacao.cancelar(modelo,anterior.vfxId)
  if anterior.tempo and not anterior.tempo.session and workspace:GetServerTimeNow()<anterior.tempo.inicio then
   anterior.tempo.active=false;pararVozes(anterior.tempo.vozes)
  end
 end
 tokens[modelo] = token(modelo) + 1
 local tk = token(modelo)
 local acao = {seq=dados.seq, actionId=dados.actionId, t=dados.t or workspace:GetServerTimeNow(), vfxId=dados.actionId or ("previsao:"..tostring(tk)), id=id, tk=tk}
 atuais[modelo] = acao
 if dados.seq==nil and dados.actionId and dados.t then ultimosTempos[modelo]=dados.t end
 if dados.seq ~= nil then ultimasSeq[modelo] = dados.seq end
 if dados.actionId then vistos[modelo]=vistos[modelo] or {};vistos[modelo][dados.actionId]=workspace:GetServerTimeNow()+150 end
 local function terminarEm(duracao: number)
  task.delay(duracao,function()
   if atuais[modelo] == acao then Acoes.concluir(modelo,{actionId=acao.actionId,seq=acao.seq,reason="concluida"}) end
  end)
 end
 local piloto = Apresentacao.disponivel(s and s.id)
 local function antecipar(move: string, duracao: number?)
  local ctx = Apresentacao.contexto(modelo,dados);ctx.actionId=acao.vfxId;ctx.dur=duracao;ctx.variant="antecipacao"
  return Apresentacao.tocar(s and s.id,move,"inicio",ctx)
 end
	if id == "m1" or id == "m1_aereo" then
		local n = if id == "m1_aereo" then 1 else (dados.n or 1)
		local impactoM1 = if n == 4 then 0.16 else 0.1
		terminarEm(if n == 4 then 0.45 else 0.3)
		antecipar(id)
		local variante = dados.variante or dados.variant
		local clipe = M1_PROPRIO[n] or "m1_1"
		local clipeS = M1_STAND[n] or "soco_d"
		if n == 4 and variante == "cima" then
			clipe, clipeS = "m1_cima", "uppercut"
		elseif n == 4 and variante == "baixo" then
			clipe, clipeS = "m1_baixo", "slam"
		end
		if s and s.m1 == "chutes" and (n == 2 or n == 4) and not variante then
			clipe = "chute_1"
			clipeS = "chute"
		end
		if s and s.m1 == "rapieira" and not variante then
			clipeS = "estocada" -- Silver Chariot: estocadas com a rapieira
		end
		local corM1 = Efeitos.corStand(s and s.id)
		if dados.stand then
			Animador.tocar(modelo, "comando_m1")
			StandVisual.acao(modelo, { modo = "frente_perto", clipe = clipeS, dur = if n == 4 then 0.45 else 0.3, impacto = impactoM1 })
			-- AJUSTE-10: o Stand avança no soco, o braço que bate deixa rastro e o ar estoura na
			-- frente do punho (mesmo errando o golpe o soco tem peso)
			local st = StandVisual.modelo(modelo)
			local bracoS = st and st:FindFirstChild(if n % 2 == 1 then "Left Arm" else "Right Arm") :: BasePart?
			if n < 4 and not piloto then
				Efeitos.rastro(bracoS, corM1, 0.2)
			end
			task.delay(impactoM1, function()
				if token(modelo) ~= tk or not modelo.Parent then
					return
				end
				StandVisual.investida(modelo, if n == 4 then 1.9 else 1.1)
				local rs = st and st:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rs and rs.Parent and not piloto then
					local frente = rs.CFrame.LookVector
					VFX.estouroAr(rs.Position + frente * 2.4 + Vector3.new(0, 0.7, 0), frente, corM1, n == 4, tostring(s and s.id) .. ":m1")
				end
			end)
		else
			Animador.tocar(modelo, clipe)
			-- AJUSTE-12: todo soco solta o efeito na frente do punho (no 4º, o forte)
			task.delay(if n == 4 then 0.16 else 0.1, function()
				if token(modelo) == tk and modelo.Parent and raiz.Parent and not piloto then
					local frente = raiz.CFrame.LookVector
					VFX.estouroAr(raiz.Position + frente * 2.2 + Vector3.new(0, 0.6, 0), frente, corM1, n == 4, tostring(s and s.id) .. ":m1")
				end
			end)
		end
		Som.tocar(if n == 4 then "whoosh_forte" else "whoosh", raiz.Position, { max = 6 })
		if n == 4 then
			-- AJUSTE-13: o braço indo forte (whoosh do som que o dono mandou)
			Som.golpe("WHOOSH_SOCO", raiz.Position, { vol = 0.9 })
		end
		if n == 4 and not piloto then
			local cor = Efeitos.corStand(s and s.id)
			local braco = (modelo:FindFirstChild("Right Arm") or modelo:FindFirstChild("RightHand")) :: BasePart?
			if dados.stand then
				local st = StandVisual.modelo(modelo)
				braco = st and (st:FindFirstChild("Right Arm") or st:FindFirstChild("RightHand")) :: BasePart?
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
		Som.tocar("whoosh_forte", raiz.Position, { vol = 0.7, vel = 1.15 })
		local cor = Efeitos.corStand(s and s.id)
		local pe = raiz.Position - Vector3.new(0, 2.6, 0)
		-- AJUSTE-13: dash com os efeitos do pacote (poeira nos pés e o ar abrindo atrás) e, se o
		-- dash é seu, a câmera "puxa" (FOV) por um instante
		local cf = raiz.CFrame
		local dirDash = if tipo == "tras" then -cf.LookVector elseif tipo == "lado" then (if dados.lado == "esquerda" then -cf.RightVector else cf.RightVector) else cf.LookVector
		if not antecipar("dash",0.28) then VFX.dash(pe, dirDash, cor) end
		terminarEm(0.28)
		if modelo == game:GetService("Players").LocalPlayer.Character then
			require(script.Parent:WaitForChild("Camera")).fov(9, 0.28)
		end
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
		local _ = cor
		if dados.fora then
			-- AJUSTE-13: o efeito de aparecer é o do Stand (StandVisual -> VFX.invocar)
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
 terminarEm(dur)
 antecipar(id,dur)
 local tempoVoz = nil
 if g.tempo then
  tempoVoz = {active=true,vozes={},actionId=acao.actionId,inicio=workspace:GetServerTimeNow()+g.tempo.t,fim=workspace:GetServerTimeNow()+g.tempo.t+g.tempo.duracao}
  acao.tempo=tempoVoz;ultAtual[modelo]=tempoVoz
  ultVozes[modelo]=ultVozes[modelo] or {}
  for i=#ultVozes[modelo],1,-1 do if not ultVozes[modelo][i].active then table.remove(ultVozes[modelo],i) end end
  table.insert(ultVozes[modelo],tempoVoz)
  task.delay(g.tempo.t+g.tempo.duracao,function() tempoVoz.active=false;pararVozes(tempoVoz.vozes) end)
 end
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
	local vozBarragem: string? = nil
	if g.tipo == "barragem" then
		task.delay(if piloto then 0 else (g.inicio or 0.1), function()
			if token(modelo) ~= tk or not modelo.Parent then
				return
			end
			if clipeS == "barragem" and not piloto then
				Efeitos.punhos(StandVisual.modelo(modelo), (g.fim or 1) - (g.inicio or 0), cor, vivo(modelo, tk))
			end
			local usado = falar(modelo, tk, g.voz or (s and s.grito), raiz.Position)
			vozBarragem = usado
			-- AJUSTE-8: o som do anime cobre a rajada inteira; um grito curto repete até o fim
			local total = (g.fim or 1) - (g.inicio or 0)
			local d = Som.duracaoVoz(usado)
			if not piloto and usado and d > 0.3 and d < total - 0.4 then
				task.spawn(function()
					local feito = d
					while feito < total - 0.3 do
						task.wait(d)
						feito += d
						if token(modelo) ~= tk or not modelo.Parent then
							return
						end
						falar(modelo, tk, usado, raiz.Position)
					end
				end)
			end
		end)
	end
	if piloto and g.tipo == "barragem" and g.final then
  local contato = g.final.t or 4.35
  task.delay(g.fim or 3.7,function()
   if token(modelo) ~= tk or not modelo.Parent then return end
   local restante=contato-(g.fim or 3.7)
   StandVisual.acao(modelo,{modo="frente",clipe=if s and s.id=="SILVER_CHARIOT" then "sc_final15" else "soco_pesado",dur=dur-(g.fim or 3.7),impacto=restante})
  end)
 end
 -- trocas de clipe no meio do golpe (FREVO voo, FUNK batidão)
	if g.animTroca then
		for _, tr in g.animTroca do
			task.delay(tr.t, function()
				if token(modelo) ~= tk or not modelo.Parent then return end
				Animador.tocar(modelo, tr.animU, { ate = os.clock() + math.max(0.2, dur - tr.t) })
				StandVisual.acao(modelo, { modo = g.standModo or "frente", clipe = tr.animS, dur = math.max(0.2, dur - tr.t) })
			end)
		end
	end
	if g.animRepetir then
		for i, t in g.animRepetir do
			if i > 1 then
				task.delay(t - 0.3, function()
					if token(modelo) ~= tk or not modelo.Parent then return end
					Animador.tocar(modelo, g.animU)
					StandVisual.acao(modelo, { modo = g.standModo or "frente", clipe = g.animS, dur = 0.4 })
				end)
			end
		end
	end
	-- grito do Stand (ORA! MUDA! DORA!...) e o grito do golpe final da barragem
	if g.voz and g.tipo ~= "barragem" then
		task.delay(g.vozT or 0.1, function()
			falar(modelo, tk, g.voz, raiz.Position, tempoVoz)
		end)
	end
	if g.final and g.final.voz then
		task.delay(g.final.t or 1, function()
			-- o som do anime já tem o grito final (ORAAA / MUDAAA)
			if vozBarragem and vozBarragem == g.vozComFinal then
				return
			end
			falar(modelo, tk, g.final.voz, raiz.Position)
		end)
	end
	-- raio reto da mão do Stand (Star Finger, Red Bind)
	if g.vfxLinha and not piloto then
		local l = g.vfxLinha
		task.delay(l.t or 0.2, function()
			if token(modelo) ~= tk or not modelo.Parent then
				return
			end
			local corL = if l.cor == "fogo" then Color3.fromRGB(255, 130, 30) else cor
			Efeitos.linha(modelo, l.comp or 14, corL, l.dur or 0.3, l.cor == "fogo")
		end)
	end
	-- coluna de fogo na frente (Magician's Red)
	if g.vfxColuna and not piloto then
		local c = g.vfxColuna
		task.delay(c.t or 0.2, function()
			if token(modelo) ~= tk or not modelo.Parent then
				return
			end
			local r = raizDe(modelo)
			if r then
				Efeitos.coluna(r.Position + r.CFrame.LookVector * (c.dist or 10), c.raio or 6, Color3.fromRGB(255, 120, 30), math.max(0.2, (c.ate or 0.6) - (c.t or 0.2)))
			end
		end)
	end
	if not piloto and g.vfxContinuo and g.vfxContinuo.tipo == "lanca_chamas" then
		task.delay(g.vfxContinuo.de, function()
			if token(modelo) == tk and modelo.Parent then
				Efeitos.lancaChamas(modelo, g.vfxContinuo.ate - g.vfxContinuo.de, vivo(modelo, tk))
			end
		end)
	end
	if g.investida and g.investida.rastro == "fogo" then
		Efeitos.rastro(raiz, Color3.fromRGB(255, 130, 30), 0.5)
	end
	if g.tipo == "investida" or (g.tipo == "agarrar" and g.investida) then
		task.delay(0.05, function()
			if token(modelo) == tk and not piloto then Efeitos.fantasma(modelo, cor, 0.3) end
		end)
	end
	if g.ult then
		if not piloto then Efeitos.ameaca(modelo, 1.5, cor) end
		Som.tocar("gongo", raiz.Position, { alcance = 400 })
		-- AJUSTE-13: a ULT explode a aparição do Stand em tamanho grande (efeitos do pacote, cor dele)
		if not piloto then VFX.ult(raiz.Position + Vector3.new(0, 0.6, 0), cor, s and s.id) end
		-- cena de anime: câmera de cinema para quem usou, nome do golpe para quem está perto
		require(script.Parent:WaitForChild("Cinematica")).ult(modelo, s, g)
	end
end

local _ = Players
return Acoes
