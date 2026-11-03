-- OI3 :: cutscene de abertura (8 cenas). Roda só no cliente, com atores locais.
-- Adaptação provisória da história dos criadores (nomes do menino/pai e a criatura ainda não definidos).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Mapa = require(OI3.Mapa)
local Construtor = require(OI3.Construtor)
local Dialogos = require(OI3.Dialogos)
local Util = require(OI3.Util)
local Ator = require(script.Parent.Ator)
local Som = require(script.Parent.Som)
local Cinema = require(script.Parent.Cinema)
local Chamas = require(script.Parent.Chamas)

local Cutscene = {}

local V3 = Vector3.new
local PULAR = { motivo = "pular" }

local opcoes = { tremor = true }
local ativa = false

function Cutscene.configurar(o: { tremor: boolean })
	opcoes.tremor = o.tremor
end

function Cutscene.ativa(): boolean
	return ativa
end

local function acharNoMapa(nome: string): BasePart?
	local orf = workspace:FindFirstChild("Orfanato")
	if not orf then
		return nil
	end
	local p = orf:FindFirstChild(nome, true)
	if p and p:IsA("BasePart") then
		return p
	end
	return nil
end

function Cutscene.tocar(params: { inicio: number?, aoTerminar: (pulou: boolean) -> () })
	if ativa then
		return
	end
	ativa = true
	local P = Mapa.pontos()
	local F = Mapa.L.F
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	local pasta = Instance.new("Folder")
	pasta.Name = "OI3_Cutscene"
	pasta.Parent = workspace
	local pastaReflexo: Folder? = nil
	local atores = {}
	local pulou = false
	local camEstado = { cf = camera.CFrame, fov = 70 }
	local camMov: any = nil
	local tremor = 0
	local contador = 0
	local vidro = acharNoMapa("VidroEspelho")
	local fundoEsp = acharNoMapa("FundoEspelho")
	local estadoVidro = if vidro then { vidro.Transparency, vidro.Reflectance } else nil

	-- AJUSTE-5: acabamento de cinema — câmera na mão, foco automático, luz suave no rosto e cor de filme
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	local dofAntes = if dof then { dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius } else nil
	if dof then
		dof.FarIntensity = 0.42
		dof.NearIntensity = 0.3
	end
	local corCena = Instance.new("ColorCorrectionEffect")
	corCena.Name = "OI3_CorCena"
	corCena.Saturation = -0.2
	corCena.Contrast = 0.1
	corCena.TintColor = Color3.fromRGB(232, 236, 255)
	corCena.Parent = Lighting
	local suporteLuz = Instance.new("Part")
	suporteLuz.Name = "OI3_LuzRosto"
	suporteLuz.Anchored = true
	suporteLuz.CanCollide = false
	suporteLuz.CanQuery = false
	suporteLuz.CanTouch = false
	suporteLuz.Transparency = 1
	suporteLuz.Size = Vector3.new(0.2, 0.2, 0.2)
	suporteLuz.Parent = pasta
	local luzRosto = Instance.new("PointLight")
	luzRosto.Brightness = 0.32
	luzRosto.Range = 9
	luzRosto.Color = Color3.fromRGB(255, 236, 214)
	luzRosto.Shadows = false
	luzRosto.Parent = suporteLuz
	local raioFoco = RaycastParams.new()
	raioFoco.FilterType = Enum.RaycastFilterType.Exclude
	raioFoco.FilterDescendantsInstances = if vidro then { suporteLuz, vidro } else { suporteLuz }
	local focoAtual = 20
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmosferaAntes = if atmosfera then { atmosfera.Density, atmosfera.Color } else nil

	local function esperar(t: number)
		local fim = os.clock() + t
		while os.clock() < fim do
			if pulou then
				error(PULAR, 0)
			end
			task.wait()
		end
		if pulou then
			error(PULAR, 0)
		end
	end

	local function ocultarOutros(oculto: boolean)
		for _, plr in Players:GetPlayers() do
			if plr.Character then
				for _, d in plr.Character:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = if oculto then 1 else 0
					end
				end
			end
		end
	end

	local conexao = RunService.RenderStepped:Connect(function(dt)
		for _, a in atores do
			a:passo()
		end
		local cf, fov
		local m = camMov
		if m then
			local k = math.clamp((os.clock() - m.t0) / m.dur, 0, 1)
			local e = Util.suave(k)
			cf = m.de:Lerp(m.para, e)
			fov = m.fovDe + (m.fovPara - m.fovDe) * e
			if k >= 1 then
				camEstado.cf = m.para
				camEstado.fov = m.fovPara
				camMov = nil
			end
		else
			cf = camEstado.cf
			fov = camEstado.fov
		end
		if tremor > 0 and opcoes.tremor then
			local t = os.clock()
			cf = cf * CFrame.Angles(math.noise(t * 9, 1.1) * 0.02 * tremor, math.noise(t * 9, 2.2) * 0.02 * tremor, math.noise(t * 7, 3.3) * 0.012 * tremor)
		end
		if opcoes.tremor then
			-- câmera na mão: respiração bem sutil do operador
			local t = os.clock()
			cf = cf * CFrame.Angles(math.noise(t * 0.6, 7.7) * 0.006, math.noise(t * 0.5, 8.8) * 0.007, math.noise(t * 0.4, 9.9) * 0.004)
		end
		if dof then
			-- foco automático no que está no meio do quadro (o fundo fica levemente desfocado)
			local hit = workspace:Raycast(cf.Position, cf.LookVector * 90, raioFoco)
			local alvo = if hit then hit.Distance else 45
			focoAtual += (alvo - focoAtual) * math.min(1, (dt or 0.016) * 4)
			dof.FocusDistance = focoAtual
			dof.InFocusRadius = math.clamp(focoAtual * 0.3, 2.5, 20)
		end
		suporteLuz.CFrame = cf * CFrame.new(0.8, 0.6, -1.2)
		camera.CFrame = cf
		camera.FieldOfView = fov
		contador += 1
		if contador % 12 == 0 then
			ocultarOutros(true)
		end
	end)

	local function corte(cf: CFrame, fov: number?)
		camMov = nil
		camEstado.cf = cf
		camEstado.fov = fov or camEstado.fov
	end
	local function mover(de: CFrame, para: CFrame, dur: number, fovDe: number?, fovPara: number?)
		camMov = { de = de, para = para, t0 = os.clock(), dur = dur, fovDe = fovDe or camEstado.fov, fovPara = fovPara or fovDe or camEstado.fov }
	end
	local function olhar(pos: Vector3, alvo: Vector3): CFrame
		return CFrame.lookAt(pos, alvo)
	end
	local function duracao(id: string): number
		local d = Som.duracao(id)
		if d then
			return d
		end
		local fala = Dialogos.FALAS[id]
		return Util.duracaoTexto(fala and fala.texto or "")
	end
	local function falar(id: string, depois: number?)
		local dur = duracao(id)
		Som.tocar(id, { grupo = "Vozes" })
		Cinema.legenda(id, dur + 0.3)
		esperar(dur + (depois or 0.25))
	end
	local function falarSemEsperar(id: string): number
		local dur = duracao(id)
		Som.tocar(id, { grupo = "Vozes" })
		Cinema.legenda(id, dur + 0.3)
		return dur
	end
	local function novoAtor(codigo: string, pos: Vector3, alvo: Vector3?, alvoPasta: Instance?)
		local a = Ator.novo(codigo, alvoPasta or pasta, pos, alvo)
		a.aoPasso = function(ator)
			local pisada = "pisada_madeira" .. math.random(1, 5)
			if not Som.disponivel(pisada) then
				pisada = "passo" .. math.random(1, 3)
			end
			Som.tocar(pisada, { pai = ator.raiz, volume = 0.32 * ator.escala, alcance = 50, velocidade = 0.95 + math.random() * 0.1 })
		end
		table.insert(atores, a)
		return a
	end
	local function removerAtor(a)
		local i = table.find(atores, a)
		if i then
			table.remove(atores, i)
		end
		a:destruir()
	end

	local function sequencia()
		-- sincronia do multiplayer
		if params.inicio then
			Cinema.escurecer(1, 0)
			while workspace:GetServerTimeNow() < params.inicio do
				task.wait()
			end
		end
		Cinema.escurecer(1, 0)
		Cinema.faixas(true, 0.6)
		task.delay(1.5, function()
			if ativa and not pulou then
				Cinema.botaoPular(true, function()
					pulou = true
				end)
			end
		end)

		-----------------------------------------------------------------
		-- CENA 1: o orfanato à noite
		Som.ambiente("vento", 0.9, 1.5)
		corte(P.camExtA, 55)
		mover(P.camExtA, P.camExtB, 10, 55, 50)
		Cinema.escurecer(0, 2.5)
		esperar(2.5)
		Som.tocar("rangido", { volume = 0.35 })
		esperar(4.6)
		Cinema.escurecer(1, 1.5)
		esperar(1.7)

		-----------------------------------------------------------------
		-- CENA 2: as crianças e o Vô
		Som.ambiente("vento", 0.25, 1.2)
		Som.ambiente("interior", 0.8, 1.2)
		local centroCriancas = V3(-25, F, -7)
		local menino = novoAtor("ME", P.menino, P.vo)
		local nina = novoAtor("NI", P.nina, P.vo)
		local keko = novoAtor("KE", P.keko, P.vo)
		local vo = novoAtor("VO", P.vo, centroCriancas)
		vo:lamparina(1.15)
		Chamas.registrar(pasta)
		local planoAberto = olhar(V3(-34.5, F + 7.5, -21.5), V3(-19, F + 3, -2))
		corte(planoAberto, 62)
		mover(planoAberto, olhar(V3(-33.6, F + 7.0, -20.2), V3(-19, F + 3, -2)), 6, 62, 58)
		Cinema.escurecer(0, 1.2)
		esperar(1.4)
		corte(olhar(V3(-19.8, F + 5.6, -4.2), vo:cabeca()), 50)
		vo:expressao("feliz")
		falar("VO_1", 0.3)
		vo:gesto("acenar")
		falar("VO_2", 0.2)
		-- Vô sai do quarto
		corte(olhar(V3(-24, F + 5.5, -6.5), V3(-12.5, F + 4, 0)), 60)
		vo:virar(P.portaDorm, 0.5)
		esperar(0.5)
		local dVo = vo:andar(V3(P.portaDorm.X - 1.2, F, 0.1), 4.2)
		esperar(dVo)
		local dVo2 = vo:andar(P.voSaida, 4.2)
		esperar(dVo2 * 0.6)
		removerAtor(vo)
		esperar(0.9)

		-----------------------------------------------------------------
		-- CENA 3: o convite do Keko
		keko:expressao("serio")
		corte(olhar(V3(-23.3, F + 5.6, -17.6), V3(-24.5, F + 3.2, -5)), 62)
		local dKeko = keko:andar(P.kekoPerto, 3.6)
		esperar(0.6)
		menino:virar(P.kekoPerto, 0.6)
		nina:virar(P.kekoPerto, 0.7)
		esperar(math.max(dKeko - 0.6, 0.2))
		keko:virar(V3(-23.3, F, -13.5), 0.3)
		esperar(0.3)

		local closeKeko = olhar(V3(-23.6, F + 4.5, -12.4), keko:cabeca())
		corte(closeKeko, 48)
		keko:expressao("sapeca")
		falar("KE_1", 0.2)

		nina:expressao("curioso")
		corte(olhar(V3(-21.8, F + 4.3, -10.6), nina:cabeca()), 48)
		falar("NI_1", 0.2)

		keko:expressao("serio")
		mover(olhar(V3(-23.5, F + 4.4, -12.1), keko:cabeca()), olhar(V3(-23.4, F + 4.25, -11.0), keko:cabeca()), duracao("KE_2") + 0.4, 50, 44)
		falar("KE_2", 0)
		Cinema.piscarTexto("OI3")
		Som.tocar("estatica", { volume = 0.55 })
		esperar(1.0)

		corte(olhar(V3(-29.5, F + 4.8, -12.5), V3(-23.5, F + 3.6, -10.5)), 58)
		keko:gesto("apontar", 0.8)
		falar("KE_3", 0.3)

		menino:expressao("nervoso")
		corte(olhar(V3(-24.6, F + 4.3, -10.8), menino:cabeca()), 48)
		falar("ME_1", 0.2)

		keko:virar(menino.pos, 0.3)
		keko:expressao("sapeca")
		corte(closeKeko, 48)
		esperar(0.3)
		keko:gesto("apontar")
		falar("KE_4", 0.3)

		menino:expressao("medo")
		corte(olhar(V3(-24.6, F + 4.3, -10.8), menino:cabeca()), 46)
		esperar(0.2)
		task.delay(0.9, function()
			if menino.modelo.Parent then
				menino:expressao("nervoso")
			end
		end)
		falar("ME_2", 0.3)
		Cinema.escurecer(1, 1.2)
		esperar(1.4)

		-----------------------------------------------------------------
		-- CENA 4: o corredor
		Som.ambiente("vento", 0.15, 1)
		menino:posicionar(V3(14.6, F, -1.0), V3(30, F, -1))
		nina:posicionar(V3(13.4, F, 1.7), V3(30, F, 1.7))
		keko:posicionar(V3(16.6, F, 0.7), V3(30, F, 0.7))
		menino:expressao("nervoso")
		nina:expressao("neutro")
		keko:expressao("serio")
		keko:lamparina(1.0)
		Chamas.registrar(pasta)
		local cCorr1 = olhar(V3(54.5, F + 5.4, -1.2), V3(30, F + 3.4, 0))
		corte(cCorr1, 56)
		mover(cCorr1, olhar(V3(53.2, F + 5.0, -1.0), V3(30, F + 3.4, 0)), 9, 56, 52)
		keko:andar(V3(47, F, 0.7), 3.2)
		menino:andar(V3(45, F, -1.0), 3.2)
		nina:andar(V3(43.6, F, 1.7), 3.2)
		Cinema.escurecer(0, 1.0)
		esperar(3.2)
		nina:expressao("nervoso")
		falarSemEsperar("NI_2")
		esperar(3.6)
		Som.tocar("rangido", { volume = 0.5 })
		Cinema.escurecer(1, 1.2)
		esperar(1.4)

		-----------------------------------------------------------------
		-- CENA 5: o ritual no espelho
		local refletir = Mapa.refletorEspelho()
		if vidro then
			vidro.Transparency = 0.9
			vidro.Reflectance = 0
		end
		if fundoEsp then
			fundoEsp.LocalTransparencyModifier = 1
		end
		local pr = Instance.new("Folder")
		pr.Name = "OI3_Reflexo"
		pr.Parent = workspace
		pastaReflexo = pr
		Mapa.construirQuartoEspelho(Construtor.novo(pr, { refletir = refletir }), true)
		Chamas.registrar(pr)
		-- a porta do quarto (só nesta cena): fechada no ritual, aberta depois do apagão
		local XQE = 56
		local dobradica = CFrame.new(XQE + 0.62, F, -2.2)
		local function cfPorta(angulo: number): CFrame
			return dobradica * CFrame.Angles(0, -math.rad(angulo), 0) * CFrame.new(0, 3.95, 2.2)
		end
		local function criarPorta(pai: Instance, refl: ((CFrame) -> CFrame)?): BasePart
			local folha = Instance.new("Part")
			folha.Name = "OI3_PortaCena"
			folha.Anchored = true
			folha.CanCollide = false
			folha.CanQuery = false
			folha.Size = Vector3.new(0.18, 7.9, 4.4)
			folha.Color = Color3.fromRGB(58, 40, 30)
			folha.Material = Enum.Material.Wood
			folha.MaterialVariant = "OI3_Madeira"
			folha.CFrame = if refl then refl(cfPorta(0)) else cfPorta(0)
			local macaneta = Instance.new("Part")
			macaneta.Name = "Macaneta"
			macaneta.Anchored = true
			macaneta.CanCollide = false
			macaneta.CanQuery = false
			macaneta.Shape = Enum.PartType.Ball
			macaneta.Size = Vector3.new(0.28, 0.28, 0.28)
			macaneta.Color = Color3.fromRGB(150, 120, 70)
			macaneta.Material = Enum.Material.Metal
			macaneta.Parent = folha
			folha.Parent = pai
			return folha
		end
		local portaReal = criarPorta(pasta, nil)
		local portaReflexo = criarPorta(pr, refletir)
		local function porAngulo(angulo: number)
			local cf = cfPorta(angulo)
			portaReal.CFrame = cf
			portaReal.Macaneta.CFrame = cf * CFrame.new(0.15, -0.2, 1.75)
			portaReflexo.CFrame = refletir(cf)
			portaReflexo.Macaneta.CFrame = refletir(cf * CFrame.new(0.15, -0.2, 1.75))
		end
		porAngulo(0)

		local alvoEsp = V3(Mapa.L.XESP, F, 0)
		menino:posicionar(P.espMenino, alvoEsp + V3(0, 0, 0))
		nina:posicionar(P.espNina, V3(66, F, -0.5))
		keko:posicionar(P.espKeko, V3(66, F, 0.5))
		menino:criarReflexo(refletir, pr)
		nina:criarReflexo(refletir, pr)
		keko:criarReflexo(refletir, pr)
		Chamas.registrar(pr)
		Som.ambiente("vento", 0, 1)
		Som.ambiente("interior", 0.45, 1)

		local planoA = olhar(V3(60.2, F + 5.6, -5.6), V3(Mapa.L.XESP, F + 4.0, 0.6))
		corte(planoA, 60)
		Cinema.escurecer(0, 1.0)
		esperar(1.2)
		menino:expressao("nervoso")
		falar("ME_3", 0.5)

		local planoB = olhar(V3(63.6, F + 4.7, -1.7), V3(Mapa.L.XESP, F + 4.3, 0.4))
		corte(planoB, 58)
		esperar(0.6)
		-- 1º chamado: nada acontece
		menino:expressao("grito")
		tremor = 0.3
		falar("ME_4A", 0.1)
		tremor = 0
		menino:expressao("nervoso")
		esperar(1.5)
		-- 2º chamado: silêncio estranho
		menino:expressao("grito")
		tremor = 0.35
		falar("ME_4B", 0.1)
		tremor = 0
		menino:expressao("medo")
		Som.pararAmbientes(1.2)
		mover(planoB, olhar(V3(64.6, F + 4.6, -1.0), V3(Mapa.L.XESP, F + 4.3, 0.3)), 2.4, 58, 54)
		esperar(1.6)
		Som.tocar("tensao", { volume = 0.8 })
		esperar(1.0)
		-- 3º chamado
		menino:expressao("grito")
		tremor = 0.55
		falar("ME_4C", 0.05)
		tremor = 0

		-----------------------------------------------------------------
		-- CENA 6: a criatura (só no ponto de vista do menino)
		local cab = menino:cabeca()
		local pov = olhar(cab + V3(0.7, 0.05, 0), V3(Mapa.L.XESP, cab.Y - 0.2, 0))
		corte(pov, 66)
		menino:expressao("medo")
		esperar(0.7)
		local posCriatura = V3(2 * Mapa.L.XESP - 63.8, F, 0.95)
		local criatura = novoAtor("CRIATURA", posCriatura, V3(50, F, 0.95), pr)
		if criatura.semMedo then
			criatura:semMedo() -- AJUSTE-9: aqui a câmera não embaça (é preciso ver o rosto dele)
		end
		criatura:visivel(false)
		for _, v in { true, false, true, false, true } do
			criatura:visivel(v)
			esperar(0.06)
		end
		if criatura.contorcer then
			criatura:contorcer(1.6) -- se contorce no espelho, ossos estalando
		end
		Som.tocar("susto", { volume = 1 })
		Som.tocar("respiracao", { volume = 0.8 })
		tremor = 0.9
		mover(pov, olhar(cab + V3(0.95, 0.05, 0), V3(Mapa.L.XESP, cab.Y - 0.1, 0.25)), 1.2, 66, 50)
		esperar(0.7)
		tremor = 0.25
		esperar(0.9)
		tremor = 0
		removerAtor(criatura)

		-- o menino recua e grita
		corte(olhar(V3(66.6, F + 4.6, -4.9), V3(64.6, F + 3.6, 0)), 60)
		menino:expressao("grito")
		menino:andar(V3(63.6, F, 0), 2.6, true)
		tremor = 0.7
		local dGrito = falarSemEsperar("ME_5")
		esperar(dGrito * 0.6)
		tremor = 0.2
		esperar(dGrito * 0.4 + 0.3)
		tremor = 0

		-----------------------------------------------------------------
		-- CENA 7: as risadas
		menino:expressao("medo")
		corte(olhar(V3(67.4, F + 4.8, 4.8), V3(61.6, F + 3.6, 0)), 58)
		nina:virar(alvoEsp, 0.5)
		keko:virar(alvoEsp, 0.5)
		nina:expressao("curioso")
		keko:expressao("serio")
		esperar(1.1)
		corte(olhar(V3(58.8, F + 5.2, 4.8), V3(Mapa.L.XESP, F + 4.1, -0.4)), 60)
		esperar(1.4)
		-- os dois riem olhando para o menino
		local function closeDe(ator, alvo: Vector3, lado: number): CFrame
			local cab = ator:cabeca()
			local d = (V3(alvo.X, 0, alvo.Z) - V3(ator.pos.X, 0, ator.pos.Z)).Unit
			local perp = V3(-d.Z, 0, d.X) * lado
			return olhar(cab + d * 2.6 + perp * 1.6 + V3(0, 0.25, 0), cab)
		end
		keko:virar(menino.pos, 0.35)
		nina:virar(menino.pos, 0.45)
		esperar(0.35)
		corte(closeDe(keko, menino.pos, 1), 50)
		keko:expressao("rindo")
		keko:gesto("rir")
		falar("KE_5", 0.1)
		corte(closeDe(nina, menino.pos, -1), 50)
		nina:expressao("rindo")
		nina:gesto("rir")
		local dNina = falarSemEsperar("NI_3")
		esperar(math.max(dNina - 0.8, 0.6))
		-- close lento no rosto do menino
		local cabM = menino:cabeca()
		local c1 = olhar(V3(66.2, cabM.Y + 0.1, 0.55), cabM)
		local c2 = olhar(V3(65.0, cabM.Y + 0.02, 0.2), cabM)
		corte(c1, 50)
		mover(c1, c2, 4.2, 50, 42)
		local coracao = Som.tocar("coracao", { volume = 0.9, loop = true })
		esperar(3.9)

		-----------------------------------------------------------------
		-- CENA 7B (história do Capítulo 1): o espelho responde, as luzes apagam e a porta está aberta
		local centroVidro = V3(Mapa.L.XESP, Mapa.L.ESP_Y, 0)
		local placa = Instance.new("Part")
		placa.Name = "OI3_FraseEspelho"
		placa.Anchored = true
		placa.CanCollide = false
		placa.CanQuery = false
		placa.Transparency = 1
		-- a frase fica no ALTO do espelho, acima da cabeça das crianças (antes a cabeça do menino tapava)
		local altoVidro = centroVidro + V3(0, Mapa.L.ESP_A * 0.27, 0)
		placa.Size = Vector3.new(Mapa.L.ESP_L * 0.92, Mapa.L.ESP_A * 0.34, 0.05)
		placa.CFrame = CFrame.lookAt(altoVidro - V3(0.08, 0, 0), altoVidro - V3(10, 0, 0))
		placa.Parent = pasta
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.LightInfluence = 0
		sg.Brightness = 1.4
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 60
		sg.Parent = placa
		local frase = Instance.new("TextLabel")
		frase.BackgroundTransparency = 1
		frase.Size = UDim2.fromScale(1, 1)
		frase.Text = "VOCÊS\nDEMORARAM."
		frase.TextScaled = true
		frase.FontFace = Font.new("rbxasset://fonts/families/SpecialElite.json")
		frase.TextColor3 = Color3.fromRGB(150, 14, 14)
		frase.TextStrokeColor3 = Color3.fromRGB(20, 0, 0)
		frase.TextStrokeTransparency = 0.4
		frase.TextTransparency = 1
		frase.MaxVisibleGraphemes = 0
		frase.Parent = sg
		-- câmera alta, olhando por cima das cabeças para o alto do espelho
		local cfA = olhar(V3(61.6, F + 6.6, -2.8), altoVidro + V3(0, -0.3, 0.2))
		local cfB = olhar(V3(63.4, F + 6.7, -1.5), altoVidro + V3(0, -0.15, 0.1))
		corte(cfA, 54)
		menino:virar(alvoEsp, 0.35)
		nina:virar(alvoEsp, 0.45)
		keko:virar(alvoEsp, 0.45)
		esperar(0.6)
		Som.tocar("estatica", { volume = 0.45 })
		Som.tocar("tensao", { volume = 0.75 })
		TweenService:Create(frase, TweenInfo.new(0.4), { TextTransparency = 0.05 }):Play()
		task.spawn(function()
			-- as letras aparecem uma por uma, como se alguém escrevesse do outro lado
			local total = utf8.len(frase.Text) or 17
			for i = 1, total do
				if not frase.Parent then
					break
				end
				frase.MaxVisibleGraphemes = i
				task.wait(0.13 + math.random() * 0.06)
			end
		end)
		TweenService:Create(corCena, TweenInfo.new(2.4), { TintColor = Color3.fromRGB(255, 214, 214), Contrast = 0.18 }):Play()
		nina:expressao("medo")
		keko:expressao("medo")
		mover(cfA, cfB, 3.6, 54, 47)
		esperar(3.7)
		-- apagão
		Cinema.limparLegenda()
		Cinema.escurecer(1, 0.04)
		if coracao then
			coracao:Destroy()
			coracao = nil
		end
		luzRosto.Enabled = false
		Som.tocar("impacto", { volume = 0.85 })
		esperar(1.9)
		-- quando a luz volta: a porta aberta e o corredor que não é mais o mesmo
		placa:Destroy()
		porAngulo(104)
		corCena.TintColor = Color3.fromRGB(255, 200, 200)
		corCena.Saturation = -0.35
		if atmosfera then
			atmosfera.Density = 0.62
			atmosfera.Color = Color3.fromRGB(120, 60, 60)
		end
		for i, x in { 50, 40, 30, 20 } do
			local ponto = Instance.new("Part")
			ponto.Name = "OI3_LuzCorredor"
			ponto.Anchored = true
			ponto.CanCollide = false
			ponto.CanQuery = false
			ponto.Transparency = 1
			ponto.Size = Vector3.new(0.2, 0.2, 0.2)
			ponto.Position = V3(x, F + 7.5, if i % 2 == 0 then 1.5 else -1.5)
			ponto.Parent = pasta
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(190, 30, 26)
			l.Brightness = 1.6
			l.Range = 16
			l.Shadows = i == 1
			l.Parent = ponto
		end
		local cfPortaA = olhar(V3(66.2, F + 4.5, 2.6), V3(XQE - 8, F + 3.8, -0.6))
		local cfPortaB = olhar(V3(63.0, F + 4.4, 1.6), V3(XQE - 8, F + 3.8, -0.4))
		corte(cfPortaA, 58)
		Cinema.escurecer(0, 1.6)
		Som.tocar("rangido", { volume = 0.55, velocidade = 0.8 })
		Som.ambiente("vento", 0.28, 1.5) -- some na limpeza (pararAmbientes)
		mover(cfPortaA, cfPortaB, 5.2, 58, 50)
		esperar(5.0)

		-----------------------------------------------------------------
		-- CENA 8: o título
		Cinema.limparLegenda()
		Cinema.escurecer(1, 2.2)
		esperar(2.4)
		if coracao then
			coracao:Destroy()
		end
		esperar(0.6)
		Som.tocar("impacto", { volume = 1 })
		Cinema.titulo("OI3", true, 1.4)
		esperar(2.8)
		Cinema.rodape("A brincadeira terminou. O jogo começou.", true)
		esperar(2.4)
		Cinema.titulo("OI3", false, 1.2)
		Cinema.rodape("A brincadeira terminou. O jogo começou.", false)
		esperar(1.4)
	end

	local ok, err = pcall(sequencia)
	if not ok and err ~= PULAR then
		warn("[OI3] erro na cutscene:", err)
	end
	local foiPulada = (not ok and err == PULAR)
	Cinema.limparLegenda()
	Cinema.botaoPular(false, nil)
	if foiPulada then
		Cinema.escurecer(1, 0.35)
		task.wait(0.45)
		Som.tocar("impacto", { volume = 0.8 })
		Cinema.titulo("OI3", true, 0.6)
		task.wait(1.8)
		Cinema.titulo("OI3", false, 0.6)
		task.wait(0.7)
	else
		Cinema.escurecer(1, 0.3)
		task.wait(0.35)
	end

	-- limpeza
	conexao:Disconnect()
	if dof and dofAntes then
		dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = dofAntes[1], dofAntes[2], dofAntes[3], dofAntes[4]
	end
	corCena:Destroy()
	if atmosfera and atmosferaAntes then
		atmosfera.Density = atmosferaAntes[1]
		atmosfera.Color = atmosferaAntes[2]
	end
	for _, a in atores do
		a:destruir()
	end
	atores = {}
	pasta:Destroy()
	if pastaReflexo then
		pastaReflexo:Destroy()
	end
	Chamas.limparAusentes()
	if vidro and estadoVidro then
		vidro.Transparency = estadoVidro[1]
		vidro.Reflectance = estadoVidro[2]
	end
	if fundoEsp then
		fundoEsp.LocalTransparencyModifier = 0
	end
	ocultarOutros(false)
	Som.pararAmbientes(0.5)
	Cinema.faixas(false, 0.4)
	ativa = false
	params.aoTerminar(foiPulada)
end

return Cutscene
