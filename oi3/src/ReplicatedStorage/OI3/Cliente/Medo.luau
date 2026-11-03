-- OI3 :: MEDO (AJUSTE-9) — o corpo da criança reage quando o monstro chega perto
-- * a câmera embaça (desfoque), perde a cor e treme;
-- * a respiração fica pesada (gravações reais de respiração ofegante, um pouco mais aguda = criança);
-- * o coração bate cada vez mais rápido e mais alto (gravação real de batimento, uma batida por vez);
-- * escondido e com o monstro colado: a criança PRENDE a respiração... e puxa o ar quando ele vai embora.
-- Nada aqui é sintetizado: só gravações da biblioteca licenciada do Roblox (SonsBiblioteca).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Som = require(script.Parent.Som)

local Medo = {}

type Fonte = { raiz: BasePart? }

local estado = {
	iniciado = false,
	nivel = 0, -- 0..1 (suavizado)
	forcado = 0,
	forcadoAte = 0,
	fontes = {} :: { [any]: boolean },
	blur = nil :: BlurEffect?,
	cor = nil :: ColorCorrectionEffect?,
	proximaBatida = 0,
	proximoFolego = 0,
	prendendo = false,
	prendeuEm = 0,
	escondido = false,
	impulso = 0, -- tremor extra (passos pesados)
	ultimoEscrito = nil :: CFrame?,
	ultimoOffset = CFrame.identity,
	tremorLigado = true,
	tempo = 0,
	pausado = false,
}

local function alvoPorDistancia(d: number): number
	-- colado (≤ 6 studs) = 1; longe (≥ 30 studs) = 0
	return math.clamp((30 - d) / 24, 0, 1)
end

-- função pura (testável): batidas por minuto para um nível de medo
function Medo.bpm(nivel: number): number
	return 64 + 100 * math.clamp(nivel, 0, 1)
end

-- função pura (testável): intervalo entre um fôlego e outro (segundos)
function Medo.intervaloFolego(nivel: number): number
	local n = math.clamp(nivel, 0, 1)
	return 2.3 - 1.45 * n
end

local function passo(dt: number)
	dt = math.min(dt, 0.1)
	estado.tempo += dt
	local agora = os.clock()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	-- 1) quão perto está o monstro mais próximo (da câmera: escondido, o corpo fica longe da câmera)
	local alvo = 0
	local maisPerto = math.huge
	for fonte in estado.fontes do
		local r = fonte.raiz
		if r and r.Parent then
			local d = (r.Position - cam.CFrame.Position).Magnitude
			maisPerto = math.min(maisPerto, d)
			alvo = math.max(alvo, alvoPorDistancia(d))
		else
			estado.fontes[fonte] = nil
		end
	end
	if agora < estado.forcadoAte then
		alvo = math.max(alvo, estado.forcado)
	end
	if estado.pausado then
		alvo = 0
	end
	-- sobe rápido, desce devagar (o corpo demora a acalmar)
	local taxa = if alvo > estado.nivel then 2.6 else 0.45
	estado.nivel += (alvo - estado.nivel) * math.min(1, dt * taxa)
	if estado.nivel < 0.002 then
		estado.nivel = 0
	end
	local n = estado.nivel

	-- 2) câmera embaçando e perdendo a cor. Prendendo o ar (o monstro colado na fresta) a vista
	-- "foca" de novo por um instante — dá para ver o rosto dele direitinho.
	if estado.blur then
		local foco = if estado.prendendo then 0.3 else 1
		estado.blur.Size = if n > 0.04 then (1.2 + 5.3 * n ^ 1.4) * foco else 0
		estado.blur.Enabled = n > 0.04
	end
	if estado.cor then
		estado.cor.Enabled = n > 0.02
		estado.cor.Saturation = -0.5 * n
		estado.cor.Contrast = 0.14 * n
		estado.cor.Brightness = -0.05 * n
		estado.cor.TintColor = Color3.new(1, 1 - 0.1 * n, 1 - 0.12 * n)
	end

	-- 3) coração: uma batida gravada por vez, cada vez mais rápido
	if n > 0.12 and agora >= estado.proximaBatida then
		estado.proximaBatida = agora + 60 / Medo.bpm(n)
		Som.tocar("coracao_batida", { volume = 0.2 + 0.95 * n, velocidade = 0.97 + 0.06 * n })
	end

	-- 4) respiração pesada; colado no esconderijo, prende o ar
	local deveSegurar = estado.escondido and maisPerto < 5.5
	if deveSegurar and not estado.prendendo then
		estado.prendendo = true
		estado.prendeuEm = agora
	elseif estado.prendendo and (not deveSegurar or agora - estado.prendeuEm > 9) then
		estado.prendendo = false
		-- solta o ar de uma vez (o "ufa" de quem segurou)
		Som.tocar("ofegar", { volume = 1.1, velocidade = 1.22, variante = 3 })
		estado.proximoFolego = agora + 0.9
	end
	if n > 0.28 and not estado.prendendo and agora >= estado.proximoFolego then
		estado.proximoFolego = agora + Medo.intervaloFolego(n) * (0.85 + math.random() * 0.3)
		Som.tocar("ofegar", { volume = 0.25 + 0.75 * n, velocidade = 1.16 + math.random() * 0.12 })
	end

	-- 5) tremor da câmera (medo + pisadas pesadas). Não acumula: tira o tremor do quadro anterior
	-- quando ninguém mexeu na câmera (câmera fixa do esconderijo / cutscene).
	estado.impulso = math.max(0, estado.impulso - dt * 2.2)
	local amp = (0.006 * n ^ 1.5 + 0.03 * estado.impulso) * (if estado.tremorLigado then 1 else 0.3)
	local base = cam.CFrame
	if estado.ultimoEscrito and cam.CFrame == estado.ultimoEscrito then
		base = estado.ultimoEscrito * estado.ultimoOffset:Inverse()
	end
	local offset = CFrame.identity
	if amp > 0.0004 then
		local t = estado.tempo
		offset = CFrame.Angles(
			math.noise(t * 7.3, 0.5) * amp * 3,
			math.noise(t * 6.1, 2.5) * amp * 3,
			math.noise(t * 5.2, 4.5) * amp * 2
		)
	end
	if offset ~= CFrame.identity or estado.ultimoOffset ~= CFrame.identity then
		local novo = base * offset
		cam.CFrame = novo
		estado.ultimoEscrito = novo
		estado.ultimoOffset = offset
	end
end

function Medo.iniciar()
	if estado.iniciado then
		return
	end
	estado.iniciado = true
	local blur = Instance.new("BlurEffect")
	blur.Name = "OI3_MedoDesfoque"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting
	estado.blur = blur
	local cor = Instance.new("ColorCorrectionEffect")
	cor.Name = "OI3_MedoCor"
	cor.Enabled = false
	cor.Parent = Lighting
	estado.cor = cor
	RunService:BindToRenderStep("OI3_Medo", Enum.RenderPriority.Camera.Value + 3, passo)
end

-- um monstro (ou qualquer coisa com .raiz) passa a assustar
function Medo.registrar(fonte: Fonte)
	Medo.iniciar()
	estado.fontes[fonte] = true
end

function Medo.remover(fonte: Fonte)
	estado.fontes[fonte] = nil
end

-- medo mínimo por um tempo (ex.: o monstro espiando o esconderijo)
function Medo.forcar(nivel: number, dur: number)
	Medo.iniciar()
	estado.forcado = math.clamp(nivel, 0, 1)
	estado.forcadoAte = os.clock() + dur
end

-- pisada pesada perto: a câmera treme (mais forte quanto mais perto)
function Medo.pisada(pos: Vector3, forca: number?)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local d = (pos - cam.CFrame.Position).Magnitude
	local k = math.clamp((26 - d) / 20, 0, 1) * (forca or 1)
	estado.impulso = math.min(1.2, estado.impulso + k * 0.55)
end

function Medo.escondido(sim: boolean)
	estado.escondido = sim
	if not sim then
		estado.prendendo = false
	end
end

function Medo.configurar(o: { tremor: boolean? })
	if o.tremor ~= nil then
		estado.tremorLigado = o.tremor
	end
end

function Medo.nivel(): number
	return estado.nivel
end

-- tira todos os efeitos na hora (fim de missão, menu)
function Medo.limpar()
	estado.fontes = {}
	estado.forcadoAte = 0
	estado.nivel = 0
	estado.impulso = 0
	estado.prendendo = false
	estado.escondido = false
	if estado.blur then
		estado.blur.Size = 0
		estado.blur.Enabled = false
	end
	if estado.cor then
		estado.cor.Enabled = false
	end
end

return Medo
