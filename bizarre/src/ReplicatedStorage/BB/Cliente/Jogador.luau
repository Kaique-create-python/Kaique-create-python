-- BIZARRE BATTLEGROUNDS :: o seu lutador (pedidos ao servidor sem atraso na animação)
-- Anima na hora, pede ao servidor e, se ele negar, desfaz. Também cuida do ragdoll do
-- seu personagem, da corrida automática, do dash e dos impulsos dos golpes.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BB = script.Parent.Parent
local Perfil = require(BB:WaitForChild("PerfilCombate14"))
local Config = require(BB:WaitForChild("Config"))
local Regras = require(BB:WaitForChild("Regras"))
local Golpes = require(BB:WaitForChild("Golpes"))
local Stands = require(BB:WaitForChild("Stands"))
local Animador = require(script.Parent:WaitForChild("Animador"))
local Acoes = require(script.Parent:WaitForChild("Acoes"))
local Camera = require(script.Parent:WaitForChild("Camera"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))

local Jogador = {}

local plr = Players.LocalPlayer
local remotos: any = nil
local estado = Regras.novoEstado()
local cds: { [string]: number } = {}
local ocupadoAte = 0
local bloqueando = false
local ultUsado = false
local despertoVisto = 0
local correndo = false
local movendoDesde = 0
local paradoDesde = 0
local ragdollLocal = false
local aoAviso: ((texto: string) -> ())? = nil
local aoCombo: ((n: number) -> ())? = nil
local aoCd: (() -> ())? = nil
local aoEntrada: ((d: any) -> ())? = nil

local seq14=0
local geracaoMin14=nil
local minSeq14=0
local guardaSeq14=0
local visualSeq14=0
local aceitoSeq14=0
local defesaSegurada14=false
local link14=nil
local function piloto() return Perfil.suporta(plr.Character and plr.Character:GetAttribute("BB_Stand")) end
local function enviar(tipo,d,seq)
	if piloto() then
		if not seq then seq14+=1; seq=seq14 end
		d.seq=seq
		if tipo=="bloqueio" then guardaSeq14=seq end
	end
	remotos.Acao:FireServer(tipo,d)
	return seq
end
local function prever(d)
	if piloto() then seq14+=1; d.seq=seq14; visualSeq14=seq14 end
	Acoes.tocar(plr.Character,d)
	return d.seq
end
-- Fence every request already emitted. A delayed ACK may otherwise restart a
-- buffered action after menu/focus cancellation or a round trip to the same Stand.
local function cercarPedidos(limite)
	limite=limite or seq14
	minSeq14=math.max(minSeq14,limite)
	aceitoSeq14=math.max(aceitoSeq14,minSeq14)
	if Jogador.pendente and (not Jogador.pendente.seq or Jogador.pendente.seq<=limite) then Jogador.pendente=nil end
	if link14 and (not link14.seq or link14.seq<=limite) then link14=nil end
end
function Jogador.soltarEntradas()
	Jogador.bloquear(false)
	if piloto() then enviar("soltar",{}) end
	cercarPedidos()
end

Jogador.cds = cds

local function tServ(): number
	return workspace:GetServerTimeNow()
end

local function personagem(): Model?
	return plr.Character
end

local function partes()
	local c = personagem()
	if not c then
		return nil, nil, nil
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	local raiz = c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not raiz or hum.Health <= 0 then
		return nil, nil, nil
	end
	return c, hum, raiz
end

local function atributo(nome: string): any
	local c = personagem()
	return c and c:GetAttribute(nome)
end

function Jogador.atordoado(): boolean
	local t = tServ()
	return (atributo("BB_Stun") or 0) > t
		or (atributo("BB_Ragdoll") or 0) > t
		or (atributo("BB_Congelado") or 0) > t
		or (atributo("BB_Preso") or 0) > t
		or (atributo("BB_Pedra") or 0) > t
end

local function podeAgir(): boolean
	local c = partes()
	if not c then
		return false
	end
	if Jogador.atordoado() then
		return false
	end
	return os.clock() >= ocupadoAte
end

function Jogador.standAtual(): any
	return Stands.get(atributo("BB_Stand"))
end

function Jogador.desperto(): boolean
	return (atributo("BB_Desperto") or 0) > tServ()
end

function Jogador.ultUsada(): boolean
	return ultUsado
end

function Jogador.cdRestante(chave: string): number
	if plr:GetAttribute("BB_SemRecarga") then
		return 0
	end
	return math.max(0, (cds[chave] or 0) - tServ())
end

-- empurra o próprio personagem (dash, investidas, saltos dos golpes)
local function impulso(vel: Vector3, dur: number)
	local _, _, raiz = partes()
	if not raiz then
		return
	end
	local velho = raiz:FindFirstChild("BB_Proprio")
	if velho then
		velho:Destroy()
	end
	local anexo = raiz:FindFirstChild("RootAttachment") :: Attachment?
	if not anexo then
		local a = Instance.new("Attachment")
		a.Name = "RootAttachment"
		a.Parent = raiz
		anexo = a
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "BB_Proprio"
	lv.Attachment0 = anexo
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 4e5
	lv.VectorVelocity = vel
	lv.Parent = raiz
	Debris:AddItem(lv, dur)
end

local function pararImpulso()
	local _, _, raiz = partes()
	local velho = raiz and raiz:FindFirstChild("BB_Proprio")
	if velho then
		velho:Destroy()
	end
end

-- mira com ímã ("grude"): vira para o inimigo travado ou para o melhor alvo na frente da câmera.
-- Devolve a direção e a distância até o alvo (nil se não tem ninguém).
local ALCANCE_IMA = 22
function Jogador.mirar(): (Vector3, number?)
	local c, _, raiz = partes()
	local cam = workspace.CurrentCamera
	local olhar = Regras.achatar(cam.CFrame.LookVector)
	if not c or not raiz then
		return olhar, nil
	end
	local alvo: BasePart? = nil
	local travado = Camera.travado()
	if travado then
		alvo = travado:FindFirstChild("HumanoidRootPart") :: BasePart?
	else
		local nota = math.huge
		for modelo in Efeitos._modelosLutadores() do
			if modelo == c or not modelo:GetAttribute("BB_Lutador") then
				continue
			end
			local r = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
			local h = modelo:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				local v = r.Position - raiz.Position
				local d = v.Magnitude
				local frente = Regras.achatar(v):Dot(olhar)
				if d < ALCANCE_IMA and frente > 0.25 then
					local n = d * (2 - frente)
					if n < nota then
						nota = n
						alvo = r
					end
				end
			end
		end
	end
	local dir = olhar
	local dist = nil
	if alvo then
		dir = Regras.achatar(alvo.Position - raiz.Position)
		dist = (alvo.Position - raiz.Position).Magnitude
	end
	raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + dir)
	return dir, dist
end

------------------------------------------------------------------------------------- ações
function Jogador.m1()
	if bloqueando then
		Jogador.bloquear(false)
	end
	local t = tServ()
	local seguindo=piloto() and link14 and t<=link14.fecha and not link14.usado
	local aereo=seguindo and t>=link14.abre and not Jogador.atordoado()
	local function direcaoM1()
		if seguindo then return Regras.achatar(workspace.CurrentCamera.CFrame.LookVector),nil end
		return Jogador.mirar()
	end
	if not podeAgir() and not aereo then
		if piloto() and not Jogador.atordoado() then enviar("m1",{dir=direcaoM1(),alvo=Camera.travado()}) end
		return
	end
	local n = if aereo then 1 else Regras.m1(estado, t)
	if not n then
		if piloto() and estado.m1ProntoEm-t<=Perfil.bufferTTL then enviar("m1",{dir=direcaoM1(),alvo=Camera.travado()}) end
		return
	end
	local _, hum, raiz = partes()
	if not hum or not raiz then
		return
	end
	local dir, dist = direcaoM1()
	local variante = nil
	if n == 4 and hum.FloorMaterial == Enum.Material.Air then
		variante = if raiz.AssemblyLinearVelocity.Y > 4 then "cima" else "baixo"
	end
	local _,rec=Perfil.tempos(n)
	ocupadoAte = os.clock() + (if piloto() then rec else 0.18)
	if aereo then link14.usado=true; Perfil.seguimento(estado,t) end
	local seq=prever({ id = if aereo then "m1_aereo" else "m1", n = n, variante = variante, variant=variante, stand = atributo("BB_StandFora") == true })
	enviar("m1", { dir = dir, variante = variante, alvo=Camera.travado() },seq)
	if not variante and not aereo then
		-- ímã: chega perto do alvo para o soco pegar (sem atravessar ele)
		if dist and dist > 4.2 and dist < 14 then
			impulso(dir * math.clamp((dist - 3.6) / 0.1, 9, 62), 0.1)
		else
			impulso(dir * 9, 0.07)
		end
	end
end

function Jogador.golpe(slot: any)
	if bloqueando then
		Jogador.bloquear(false)
	end
	local s = Jogador.standAtual()
	local g, id = Golpes.doSlot(s, slot)
	if not g or not id then
		return
	end
	if not podeAgir() then
		if piloto() and not Jogador.atordoado() and not g.ult then enviar("golpe",{slot=slot,dir=Jogador.mirar()}) end
		return
	end
	local t = tServ()
	if g.ult then
		if not Jogador.desperto() then
			if aoAviso then
				aoAviso("Encha a barra e DESPERTE primeiro (G)")
			end
			return
		end
		if ultUsado and not plr:GetAttribute("BB_SemRecarga") then
			return
		end
	end
	if Jogador.cdRestante(id) > 0 then
		if piloto() and Jogador.cdRestante(id)<=Perfil.bufferTTL then enviar("golpe",{slot=slot,dir=Jogador.mirar()}) end
		return
	end
	local dir = Jogador.mirar()
	local mult = ((s.passiva and s.passiva.multRecarga) or 1) * (if Jogador.desperto() then Config.DESPERTAR.multRecarga else 1)
	local anterior = cds[id]
	cds[id] = t + (g.cd or 10) * mult
	if g.ult then
		ultUsado = true
	end
	ocupadoAte = os.clock() + (g.trava or 0.5)
	local seq=prever({id=id})
	Jogador.pendente = { id = id, cd = anterior, ult = g.ult, seq=seq }
	enviar("golpe", { slot = slot, dir = dir },seq)
	local impulsoSeq=visualSeq14
	-- o seu corpo se mexe no golpe (pulo, investida, avanço)
	for _, i in g.impulsos or {} do
		task.delay(i.t, function()
			local _, _, raiz = partes()
			if raiz and (not piloto() or visualSeq14==impulsoSeq) and not Jogador.atordoado() and os.clock() < ocupadoAte + 0.1 then
				impulso(dir * (i.frente or 0) + Vector3.new(0, i.cima or 0, 0), i.dur or 0.15)
			end
		end)
	end
	local inv = g.investida
	if inv then
		task.delay(inv.t or 0, function()
			if (not piloto() or visualSeq14==impulsoSeq) and not Jogador.atordoado() and os.clock() < ocupadoAte + 0.1 then
				impulso(dir * inv.vel, inv.dur)
			end
		end)
	end
	if aoCd then
		aoCd()
	end
end

function Jogador.bloquear(ligar: boolean)
	local mudou=defesaSegurada14~=ligar
	defesaSegurada14=ligar
	if piloto() and not ligar and not bloqueando then
		if mudou then enviar("bloqueio",{ligar=false}) end
		return
	end
	if piloto() and ligar and not podeAgir() then
		if mudou then enviar("bloqueio",{ligar=true}) end
		return
	end
	if ligar == bloqueando and (not piloto() or not mudou) then
		return
	end
	if ligar and not podeAgir() then
		return
	end
	bloqueando = ligar
	local c = personagem()
	-- AJUSTE-10: o Stand entra na frente na hora (o servidor confirma depois)
	require(script.Parent:WaitForChild("StandVisual")).prever(c, ligar)
	if ligar then
		estado.bloqueioInicio = os.clock()
		Animador.tocar(c, "bloqueio")
	else
		Animador.parar(c)
	end
	enviar("bloqueio", { ligar = ligar })
end

function Jogador.bloqueando(): boolean
	return bloqueando
end

function Jogador.dash()
	local c, hum, raiz = partes()
	if not c or not hum or not raiz then
		return
	end
	local t = tServ()
	if Jogador.atordoado() then
		if (atributo("BB_Evasiva") or 0) <= t then
			enviar("evasiva", {})
		end
		return
	end
	if not podeAgir() then
		return
	end
	local mov = hum.MoveDirection
	local tipo, lado = "frente", nil
	local dirMundo = raiz.CFrame.LookVector
	if mov.Magnitude > 0.1 then
		local localDir = raiz.CFrame:VectorToObjectSpace(mov)
		tipo = Regras.tipoDash(localDir)
		dirMundo = mov.Unit
		if tipo == "lado" then
			lado = if localDir.X > 0 then "direita" else "esquerda"
		end
	else
		dirMundo = Regras.achatar(workspace.CurrentCamera.CFrame.LookVector)
	end
	local chave = "dash_" .. tipo
	if Jogador.cdRestante(chave) > 0 then
		return
	end
	local def = Config.DASH[tipo]
	cds[chave] = t + def.recarga
	ocupadoAte = os.clock() + def.dur
	if bloqueando then
		Jogador.bloquear(false)
	end
	-- AJUSTE-5: com a mira travada o dash gruda no alvo (como no Jujutsu Shenanigans):
	-- para frente encosta nele, de lado gira em volta dele, para trás se afasta
	local travado = Camera.travado()
	local rAlvo = travado and travado:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rAlvo then
		local paraAlvo = Regras.achatar(rAlvo.Position - raiz.Position)
		local dist = (rAlvo.Position - raiz.Position).Magnitude
		if tipo == "frente" then
			dirMundo = paraAlvo
			local dur = math.clamp((dist - 4) / def.vel, 0.05, def.dur)
			impulso(paraAlvo * def.vel, dur)
			ocupadoAte = os.clock() + dur
		elseif tipo == "tras" then
			dirMundo = -paraAlvo
			impulso(-paraAlvo * def.vel, def.dur)
		else
			local sinal = if lado == "direita" then 1 else -1
			local fimDash = os.clock() + def.dur
			local raio = math.max(dist, 5)
			impulso(paraAlvo:Cross(Vector3.new(0, 1, 0)) * sinal * def.vel, def.dur)
			task.spawn(function()
				while os.clock() < fimDash and rAlvo.Parent and raiz.Parent do
					local lv = raiz:FindFirstChild("BB_Proprio") :: LinearVelocity?
					if not lv then
						break
					end
					local v = Regras.achatar(rAlvo.Position - raiz.Position)
					local d = (rAlvo.Position - raiz.Position).Magnitude
					local tangente = v:Cross(Vector3.new(0, 1, 0)) * sinal
					-- mantém a mesma distância do alvo enquanto gira
					lv.VectorVelocity = tangente * def.vel + v * (d - raio) * 6
					raiz.CFrame = CFrame.lookAt(raiz.Position, raiz.Position + v)
					task.wait()
				end
			end)
		end
	else
		impulso(Regras.achatar(dirMundo) * def.vel, def.dur)
	end
	local seq=prever({ id = "dash", tipo = tipo, lado = lado })
	enviar("dash", { tipo = tipo, lado = lado, mov = dirMundo },seq)
	if aoCd then
		aoCd()
	end
end

function Jogador.despertar()
	if Jogador.desperto() then
		return Jogador.golpe("ult")
	end
	enviar("despertar", {})
end

function Jogador.alternarStand()
	local c = partes()
	if not c then
		return
	end
	local fora = not (atributo("BB_StandFora") == true)
	Acoes.tocar(c, { id = "stand", fora = fora })
	enviar("stand", {})
end

local poseN = 0
function Jogador.pose()
	if not podeAgir() then
		return
	end
	poseN = poseN % 3 + 1
	Acoes.tocar(personagem(), { id = "pose", n = poseN })
	enviar("pose", { n = poseN })
end

------------------------------------------------------------------------------------- servidor
local function aoPrivado(tipo: string, d: any)
	if geracaoMin14 and (tipo=="confirmado" or tipo=="negado" or tipo=="airlink") and (not d.generation or d.generation<geracaoMin14) then return end
	if piloto() and (tipo=="confirmado" or tipo=="negado" or tipo=="airlink") and d.seq==nil then return end
	if (tipo=="confirmado" or tipo=="airlink") and d.standId and d.standId~=atributo("BB_Stand") then return end
	if d.seq and d.seq<=minSeq14 and (tipo=="confirmado" or tipo=="negado" or tipo=="airlink") then return end
	if piloto() and tipo=="negado" and d.seq and d.seq~=(if d.acao=="bloqueio" then guardaSeq14 else visualSeq14) then return end
	if piloto() and (tipo=="negado" or tipo=="confirmado") and d.seq and d.seq<math.max(visualSeq14,aceitoSeq14) then return end
	if tipo=="airlink" then link14=d; return end
	if tipo == "negado" then
		local p = Jogador.pendente
		if d.acao == "golpe" and p then
			cds[p.id] = p.cd
			if p.ult then
				ultUsado = false
			end
			Jogador.pendente = nil
			if piloto() then Acoes.interromper(personagem(),nil,d.seq) else Animador.parar(personagem()) end
			pararImpulso()
			ocupadoAte = 0
			if aoAviso and d.motivo and d.motivo ~= "recarga" and d.motivo ~= "ocupado" then
				aoAviso(d.motivo)
			end
		elseif d.acao == "m1" then
			ocupadoAte = 0
			if piloto() and d.seq==visualSeq14 then Acoes.interromper(personagem(),nil,d.seq) end
		elseif d.acao=="dash" and piloto() then
			ocupadoAte=0; pararImpulso(); Acoes.interromper(personagem(),nil,d.seq)
		elseif d.acao == "bloqueio" then
			if bloqueando then Animador.parar(personagem()) end
			bloqueando = false
		elseif d.acao == "despertar" and aoAviso and d.motivo then
			aoAviso(d.motivo)
		end
		if aoCd then
			aoCd()
		end
	elseif tipo == "cd" then
		cds[d.chave] = d.fim
		local g = Golpes.get(d.chave)
		if g and g.ult then
			ultUsado = true
		end
		if aoCd then
			aoCd()
		end
	elseif tipo == "confirmado" then
		if piloto() and d.seq then
			if d.seq<=aceitoSeq14 then return end
			aceitoSeq14=d.seq
			if d.seq~=visualSeq14 then
				Acoes.tocar(personagem(),d)
				visualSeq14=d.seq
			end
			if Acoes.confirmar then Acoes.confirmar(personagem(),d) end
			if d.acaoAte then ocupadoAte=os.clock()+math.max(0,d.acaoAte-tServ()) end
			if d.m1ProntoEm then estado.m1ProntoEm=d.m1ProntoEm end
			if d.combo then estado.combo=d.combo; estado.comboT=d.t end
		end
		Jogador.pendente = nil
	elseif tipo == "combo" then
		if aoCombo then
			aoCombo(d.n)
		end
	elseif tipo == "mover" then
		local _, _, raiz = partes()
		if raiz and typeof(d.cf) == "CFrame" then
			pararImpulso()
			raiz.CFrame = d.cf
			raiz.AssemblyLinearVelocity = Vector3.zero
		end
	elseif tipo == "parar" then
		pararImpulso()
	elseif tipo == "aviso" then
		if aoAviso then
			aoAviso(d.texto)
		end
	elseif tipo == "entrada" then
		if aoEntrada then
			aoEntrada(d)
		end
	end
end

local CORPO_CAIDO = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "UpperTorso", "LowerTorso" }
local virandoParaAlvo = false

-- fim do ragdoll: fica em pé no chão, olhando para onde estava virado (não levanta torto/enterrado)
local function levantarEmPe(c: Model, hum: Humanoid, raiz: BasePart)
	local frente = Vector3.new(raiz.CFrame.LookVector.X, 0, raiz.CFrame.LookVector.Z)
	if frente.Magnitude < 0.2 then
		frente = Vector3.new(raiz.CFrame.UpVector.X, 0, raiz.CFrame.UpVector.Z)
	end
	if frente.Magnitude < 0.2 then
		frente = Vector3.new(0, 0, -1)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { c }
	pcall(function()
		params.RespectCanCollide = true
	end)
	local base = raiz.Position
	local chao = workspace:Raycast(base + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	local y = if chao then chao.Position.Y + 3.1 else base.Y + 1.5
	local pos = Vector3.new(base.X, math.max(y, base.Y), base.Z)
	raiz.CFrame = CFrame.lookAt(pos, pos + frente.Unit)
	raiz.AssemblyLinearVelocity = Vector3.zero
	raiz.AssemblyAngularVelocity = Vector3.zero
	hum.AutoRotate = true
	hum:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local function passo()
	local c, hum, raiz = partes()
	if not c or not hum or not raiz then
		ragdollLocal = false
		return
	end
	local t = tServ()
	-- ragdoll do seu personagem (o servidor marca, o seu celular deita)
	local ate = c:GetAttribute("BB_Ragdoll") or 0
	if ate > t then
		if not ragdollLocal then
			ragdollLocal = true
			bloqueando = false
			hum.AutoRotate = false
		end
		if hum:GetState() ~= Enum.HumanoidStateType.Physics then
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end
		-- deitado, o corpo todo colide com o chão (não atravessa o mapa; o Humanoid tenta desligar)
		for _, nome in CORPO_CAIDO do
			local p = c:FindFirstChild(nome) :: BasePart?
			if p and not p.CanCollide then
				p.CanCollide = true
			end
		end
	elseif ragdollLocal then
		ragdollLocal = false
		levantarEmPe(c, hum, raiz)
	end
	-- mira travada: o personagem fica sempre de frente para o alvo (anda de lado em volta dele)
	-- AJUSTE-13: Shift Lock (sem mira travada): de frente para onde a câmera olha
	local travado = Camera.travado()
	local rAlvo = travado and travado:FindFirstChild("HumanoidRootPart") :: BasePart?
	local olharPara: Vector3? = nil
	local manter = false
	if rAlvo and not ragdollLocal and not Jogador.atordoado() then
		local d = Vector3.new(rAlvo.Position.X - raiz.Position.X, 0, rAlvo.Position.Z - raiz.Position.Z)
		if d.Magnitude > 0.6 then
			olharPara = d.Unit
		else
			manter = true
		end
	elseif Camera.shiftLock() and not rAlvo and not ragdollLocal and not Jogador.atordoado() and Camera.dono() == "jogo" then
		local olhar = workspace.CurrentCamera.CFrame.LookVector
		local plano = Vector3.new(olhar.X, 0, olhar.Z)
		if plano.Magnitude > 0.1 then
			olharPara = plano.Unit
		end
	end
	if olharPara then
		hum.AutoRotate = false
		local alvoCf = CFrame.lookAt(raiz.Position, raiz.Position + olharPara)
		raiz.CFrame = raiz.CFrame:Lerp(alvoCf, if rAlvo then 0.4 else 0.55)
		virandoParaAlvo = true
	elseif manter then
		local _ = manter
	elseif virandoParaAlvo then
		virandoParaAlvo = false
		if not ragdollLocal then
			hum.AutoRotate = true
		end
	end
	-- despertar novo: a ULT volta a ficar disponível
	local d = c:GetAttribute("BB_Desperto") or 0
	if d ~= despertoVisto then
		despertoVisto = d
		if d > t then
			ultUsado = false
		end
	end
	if piloto() and defesaSegurada14 and not bloqueando and c:GetAttribute("BB_Bloqueando")==true then
		bloqueando=true; Animador.tocar(c,"bloqueio")
	end
	-- o servidor tirou o bloqueio (guarda quebrada, atordoado)
	if bloqueando and c:GetAttribute("BB_Bloqueando") == false and os.clock() - estado.bloqueioInicio > 0.5 then
		bloqueando = false
		Animador.parar(c)
	end
	-- corrida automática: andou um pouquinho, começa a correr
	local movendo = hum.MoveDirection.Magnitude > 0.5 and not bloqueando and os.clock() >= ocupadoAte
	local agora = os.clock()
	if movendo then
		paradoDesde = agora
		if movendoDesde == 0 then
			movendoDesde = agora
		end
		if not correndo and agora - movendoDesde >= Config.TEMPO_PARA_CORRER then
			correndo = true
			enviar("correr", { ligar = true })
			Camera.correndo(true)
		end
	else
		movendoDesde = 0
		if correndo and agora - paradoDesde > 0.18 then
			correndo = false
			enviar("correr", { ligar = false })
			Camera.correndo(false)
		end
	end
end

local observados14=setmetatable({}, {__mode="k"})
local function observarPersonagem14(c)
	if not c or observados14[c] then return end
	observados14[c]=true
	local ultimoStand=c:GetAttribute("BB_Stand")
	local ultimaGeracao=c:GetAttribute("BB_Geracao14")
	local seqAntesDaGeracao=nil
	local function cancelarLocal(limite)
		if plr.Character~=c then return end
		limite=limite or seq14
		cercarPedidos(limite)
		if guardaSeq14<=limite then defesaSegurada14=false; bloqueando=false end
		if visualSeq14>limite then return end
		ocupadoAte=0
		Acoes.interromper(c)
		local r=c:FindFirstChild("HumanoidRootPart")
		local lv=r and r:FindFirstChild("BB_Proprio")
		if lv then lv:Destroy() end
	end
	local function mudou()
		if plr.Character~=c then return end
		local stand=c:GetAttribute("BB_Stand")
		local geracao=c:GetAttribute("BB_Geracao14")
		if stand==ultimoStand and geracao==ultimaGeracao then return end
		if type(geracao)=="number" and (not geracaoMin14 or geracao>geracaoMin14) then
			-- Generation replication is authority for ACK validity, never an order to
			-- cancel a new prediction. Stand and generation can arrive separately.
			geracaoMin14=geracao
			if type(ultimaGeracao)=="number" and geracao>ultimaGeracao then seqAntesDaGeracao=seq14 end
			if link14 and (not link14.generation or link14.generation<geracao) then link14=nil end
		end
		if stand~=ultimoStand then
			table.clear(cds); ultUsado=false
			cancelarLocal(seqAntesDaGeracao or seq14)
			seqAntesDaGeracao=nil
		end
		ultimoStand=stand; ultimaGeracao=geracao
	end
	c:GetAttributeChangedSignal("BB_Stand"):Connect(mudou)
	c:GetAttributeChangedSignal("BB_Geracao14"):Connect(mudou)
	local hum=c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(cancelarLocal)
	else
		-- CharacterAdded can precede replication of the Humanoid.
		local connection
		connection=c.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				child.Died:Connect(cancelarLocal)
				connection:Disconnect()
			end
		end)
	end
end

function Jogador.iniciar(rem: any, ganchos: any)
	remotos = rem
	aoAviso = ganchos.aviso
	aoCombo = ganchos.combo
	aoCd = ganchos.cd
	aoEntrada = ganchos.entrada
	rem.Privado.OnClientEvent:Connect(aoPrivado)
	RunService.Heartbeat:Connect(passo)
	observarPersonagem14(personagem())
	plr.CharacterAdded:Connect(function(c)
		observarPersonagem14(c or personagem())
		table.clear(cds)
		estado = Regras.novoEstado()
		defesaSegurada14=false; link14=nil; geracaoMin14=nil; minSeq14=seq14; visualSeq14=seq14; aceitoSeq14=seq14; guardaSeq14=seq14; Jogador.pendente=nil
		ocupadoAte = 0
		bloqueando = false
		ultUsado = false
		correndo = false
		Camera.correndo(false)
		Camera.travar(nil)
		if aoCd then
			aoCd()
		end
	end)
end

return Jogador
