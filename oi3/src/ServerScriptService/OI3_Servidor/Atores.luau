-- OI3 :: atores (AJUSTE-6)
-- Os personagens são avatares do Roblox montados SÓ com IDs do catálogo, pelo sistema oficial
-- (HumanoidDescription): rosto, cabelo, chapéu, camisa, calça e cor da pele. Nada é modelado.
-- Os modelos prontos ficam em ReplicatedStorage.OI3_Atores/<código> para a cutscene copiar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OI3 = ReplicatedStorage:WaitForChild("OI3")
local Config = require(OI3:WaitForChild("Config"))
local Personagens = require(OI3:WaitForChild("Personagens"))

local Atores = {}

local function lista(ids: { number }?): string
	local t = {}
	for _, id in ids or {} do
		if tonumber(id) and tonumber(id) > 0 then
			table.insert(t, tostring(id))
		end
	end
	return table.concat(t, ",")
end

-- função pura (testável): a descrição do avatar de cada personagem
function Atores.descricao(codigo: string): HumanoidDescription
	local r = (Config.ROUPAS or {})[codigo] or {}
	local d = Instance.new("HumanoidDescription")
	d.Shirt = tonumber(r.camisa) or 0
	d.Pants = tonumber(r.calca) or 0
	d.Face = tonumber(r.rosto) or 0
	d.HairAccessory = lista(r.cabelo)
	d.HatAccessory = lista(r.chapeu)
	d.FaceAccessory = lista(r.rostoAcessorio)
	-- AJUSTE-9: corpo R15 do catálogo (o monstro) e acessórios das costas
	d.BackAccessory = lista(r.costas)
	d.Head = tonumber(r.cabeca) or 0
	d.Torso = tonumber(r.torso) or 0
	d.LeftArm = tonumber(r.bracoE) or 0
	d.RightArm = tonumber(r.bracoD) or 0
	d.LeftLeg = tonumber(r.pernaE) or 0
	d.RightLeg = tonumber(r.pernaD) or 0
	local cor = r.pele or Config.PELE
	d.HeadColor = cor
	d.TorsoColor = cor
	d.LeftArmColor = cor
	d.RightArmColor = cor
	d.LeftLegColor = cor
	d.RightLegColor = cor
	return d
end

-- tira o rosto padrão quando o rosto vem de um acessório (senão ficam dois rostos)
function Atores.ajustarRosto(modelo: Model, codigo: string)
	local r = (Config.ROUPAS or {})[codigo] or {}
	if r.semRosto or (r.rostoAcessorio and #r.rostoAcessorio > 0 and not r.rosto) then
		local cabeca = modelo:FindFirstChild("Head")
		if cabeca then
			for _, d in cabeca:GetChildren() do
				if d:IsA("Decal") then
					d:Destroy()
				end
			end
		end
	end
end

-- acessório que vai no rosto (encaixe FaceFront/FaceCenter) = rosto trocável
function Atores.marcarRostos(modelo: Instance)
	for _, a in modelo:GetChildren() do
		if a:IsA("Accessory") then
			local alca = a:FindFirstChild("Handle")
			if alca and (alca:FindFirstChild("FaceFrontAttachment") or alca:FindFirstChild("FaceCenterAttachment")) then
				a:SetAttribute("OI3_Rosto", true)
			end
		end
	end
end

-- biblioteca de rostos de reação (só o acessório do rosto, tirado de um avatar montado pelo Roblox)
function Atores.montarRosto(id: number): Accessory?
	local d = Instance.new("HumanoidDescription")
	d.FaceAccessory = tostring(id)
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R6)
	end)
	if not ok or not m then
		return nil
	end
	local achado = nil
	for _, a in m:GetChildren() do
		if a:IsA("Accessory") then
			achado = a:Clone()
			break
		end
	end
	m:Destroy()
	if achado then
		achado:SetAttribute("OI3_Rosto", true)
	end
	return achado
end

-- função pura (testável): altura do CORPO (sem acessórios), da sola ao topo da cabeça
function Atores.alturaCorpo(modelo: Model): number
	local fundo, topo = math.huge, -math.huge
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 0.95 and not p:FindFirstAncestorOfClass("Accessory") then
			local meia = p.Size.Y / 2
			fundo = math.min(fundo, p.CFrame.Position.Y - meia)
			topo = math.max(topo, p.CFrame.Position.Y + meia)
		end
	end
	if fundo == math.huge then
		return 0
	end
	return topo - fundo
end

function Atores.montar(codigo: string): (Model?, string?)
	local r = (Config.ROUPAS or {})[codigo]
	if not r then
		return nil, "personagem desconhecido"
	end
	local tipo = if r.r15 then Enum.HumanoidRigType.R15 else Enum.HumanoidRigType.R6
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Atores.descricao(codigo), tipo)
	end)
	if (not ok or not m) and r.r15 then
		-- AJUSTE-9: tenta o corpo do monstro sem os acessórios das costas antes de desistir
		local d = Atores.descricao(codigo)
		d.BackAccessory = ""
		ok, m = pcall(function()
			return Players:CreateHumanoidModelFromDescription(d, tipo)
		end)
		if ok and m then
			warn("[OI3] acessórios das costas do " .. codigo .. " não carregaram; o corpo veio sem eles")
		end
	end
	if not ok or not m then
		-- se algum item do catálogo falhar, monta o avatar padrão do Roblox com a mesma cor
		local d = Instance.new("HumanoidDescription")
		local cor = r.pele or Config.PELE
		d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = cor, cor, cor, cor, cor, cor
		local ok2, m2 = pcall(function()
			return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R6)
		end)
		if not ok2 or not m2 then
			return nil, tostring(m)
		end
		warn("[OI3] itens de " .. codigo .. " não carregaram; usando o avatar padrão:", m)
		m = m2
	end
	local modelo = m :: Model
	modelo.Name = codigo
	Atores.ajustarRosto(modelo, codigo)
	Atores.marcarRostos(modelo)
	-- scripts que vêm junto (Animate/Health) não servem para atores de cena
	for _, x in modelo:GetDescendants() do
		if x:IsA("BaseScript") then
			x:Destroy()
		end
	end
	local s = tonumber(r.escala) or 1
	-- AJUSTE-9: corpo R15 do catálogo: escala para a altura pedida (cada pacote vem de um tamanho)
	if r.r15 and modelo:FindFirstChild("UpperTorso") and tonumber(r.altura) then
		local h = Atores.alturaCorpo(modelo)
		if h > 0.5 then
			s = math.clamp(r.altura / h, 0.5, 3)
		end
		modelo:SetAttribute("R15", true)
	end
	if math.abs(s - 1) > 0.001 then
		pcall(function()
			modelo:ScaleTo(s)
		end)
	end
	modelo:SetAttribute("Escala", s)
	-- AJUSTE-8: rosto encaixado e medido (na cabeça R6 alguns rostos ficavam escondidos)
	pcall(Personagens.fixarRostos, modelo, s)
	modelo:SetAttribute("Codigo", codigo)
	return modelo, nil
end

---------------------------------------------------------------------------
-- AJUSTE-10: MONSTROS DA INTERNET (modelos grátis do Creator Store do Roblox)
-- Só carregam se estiverem no inventário do dono do jogo (tocar em "Obter" na página do modelo) ou se
-- o jogo permitir "recursos de terceiros". TODO script de dentro é apagado antes de usar (segurança),
-- e só servem modelos com Humanoid e juntas padrão (para o monstro se contorcer). Se nenhum carregar,
-- o monstro do catálogo (AJUSTE-9) continua.
---------------------------------------------------------------------------
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local DataStoreService = game:GetService("DataStoreService")

local JUNTAS_PADRAO = { "Neck", "Root", "Root Joint", "Waist", "LeftShoulder", "Left Shoulder", "RightShoulder", "Right Shoulder", "LeftHip", "Left Hip", "RightHip", "Right Hip", "LeftKnee", "RightKnee", "LeftElbow", "RightElbow" }
local LIXO = { "LuaSourceContainer", "Sound", "ProximityPrompt", "ClickDetector", "BillboardGui", "Tool", "BodyMover", "AnimationController", "Animator", "Dialog", "ForceField", "Explosion", "Fire", "Smoke", "Sparkles" }

-- função pura (testável): quantas juntas padrão um conjunto de nomes de Motor6D tem
function Atores.contarJuntas(nomes: { string }): number
	local n = 0
	for _, j in JUNTAS_PADRAO do
		if table.find(nomes, j) then
			n += 1
		end
	end
	return n
end

-- limpa e prepara um modelo baixado: acha o personagem, apaga scripts e o que não for visual,
-- confere as juntas e deixa a raiz ancorada (igual aos outros atores)
function Atores.adaptarMonstro(bruto: Instance): (Model?, string?)
	local alvo: Model? = nil
	if bruto:IsA("Model") and bruto:FindFirstChildOfClass("Humanoid") then
		alvo = bruto
	else
		for _, d in bruto:GetDescendants() do
			if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
				alvo = d.Parent :: Model
				break
			end
		end
	end
	if not alvo then
		return nil, "sem Humanoid"
	end
	for _, d in alvo:GetDescendants() do
		for _, classe in LIXO do
			if d:IsA(classe) then
				d:Destroy()
				break
			end
		end
	end
	local raiz = alvo:FindFirstChild("HumanoidRootPart")
	if not (raiz and raiz:IsA("BasePart")) then
		return nil, "sem HumanoidRootPart"
	end
	local nomes = {}
	for _, d in alvo:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(nomes, d.Name)
		end
	end
	local juntas = Atores.contarJuntas(nomes)
	if juntas < 5 then
		return nil, "rig sem juntas padrão (" .. juntas .. ")"
	end
	for _, p in alvo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = p == raiz
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
		end
	end
	raiz.Transparency = 1
	alvo.PrimaryPart = raiz
	local hum = alvo:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	alvo:SetAttribute("Juntas", juntas)
	return alvo, nil
end

local function carregarModelo(id: number): (Instance?, string?)
	-- 1º jeito novo (respeita "recursos de terceiros"), 2º o clássico (modelo no inventário do dono)
	local ok, m = pcall(function()
		return (AssetService :: any):LoadAssetAsync(id)
	end)
	if ok and m then
		return m, nil
	end
	local ok2, m2 = pcall(function()
		return InsertService:LoadAsset(id)
	end)
	if ok2 and m2 then
		return m2, nil
	end
	return nil, tostring(if ok2 then m else m2)
end

-- monta um monstro da internet (escala para a altura do monstro)
function Atores.montarMonstroInternet(info: { id: number, nome: string }): (Model?, string?)
	local bruto, erro = carregarModelo(info.id)
	if not bruto then
		return nil, "não carregou: " .. tostring(erro)
	end
	local m, err = Atores.adaptarMonstro(bruto)
	if not m then
		bruto:Destroy()
		return nil, err
	end
	if m.Parent then
		m.Parent = nil
	end
	local h = Atores.alturaCorpo(m)
	local alvo = tonumber((Config.ROUPAS.CRIATURA or {}).altura) or 8.4
	local s = if h > 0.5 then math.clamp(alvo / h, 0.2, 6) else 1
	if math.abs(s - 1) > 0.01 then
		pcall(function()
			m:ScaleTo(s)
		end)
	end
	m:SetAttribute("Escala", s)
	m:SetAttribute("Codigo", "CRIATURA")
	m:SetAttribute("Origem", "internet")
	m:SetAttribute("NomeMonstro", info.nome)
	m:SetAttribute("AssetId", info.id)
	m.Name = "CRIATURA"
	if bruto ~= m then
		bruto:Destroy()
	end
	return m, nil
end

-- qual monstro está valendo (escolhido pelo ADM e guardado num DataStore SEPARADO, de configuração)
local configStore: DataStore? = nil
pcall(function()
	configStore = DataStoreService:GetDataStore("OI3_Configuracao_v1")
end)

function Atores.lerEscolhaMonstro(): string?
	if not configStore then
		return nil
	end
	local ok, v = pcall(function()
		return (configStore :: DataStore):GetAsync("monstro_v2")
	end)
	return if ok and type(v) == "string" then v else nil
end

function Atores.salvarEscolhaMonstro(chave: string)
	if configStore then
		pcall(function()
			(configStore :: DataStore):SetAsync("monstro_v2", chave)
		end)
	end
end

-- troca o monstro que vale (chave = "catalogo" ou o ID do modelo); devolve o nome ou nil
function Atores.usarMonstro(chave: string): string?
	local pasta = ReplicatedStorage:FindFirstChild("OI3_Atores")
	local variantes = pasta and pasta:FindFirstChild("Monstros")
	if not variantes then
		return nil
	end
	local escolhido = variantes:FindFirstChild(chave)
	if not escolhido then
		return nil
	end
	local antigo = (pasta :: Instance):FindFirstChild("CRIATURA")
	local novo = escolhido:Clone()
	novo.Name = "CRIATURA"
	if antigo then
		antigo:Destroy()
	end
	novo.Parent = pasta
	;(pasta :: Instance):SetAttribute("MonstroAtivo", chave)
	return escolhido:GetAttribute("NomeMonstro") or chave
end

function Atores.listaMonstros(): { { chave: string, nome: string } }
	local pasta = ReplicatedStorage:FindFirstChild("OI3_Atores")
	local variantes = pasta and pasta:FindFirstChild("Monstros")
	local l = {}
	for _, v in (variantes and variantes:GetChildren()) or {} do
		table.insert(l, { chave = v.Name, nome = v:GetAttribute("NomeMonstro") or v.Name })
	end
	table.sort(l, function(a, b)
		return a.chave < b.chave
	end)
	return l
end

function Atores.preparar()
	task.spawn(function()
		local pasta = Instance.new("Folder")
		pasta.Name = "OI3_Atores_Montando"
		for codigo in Config.ROUPAS or {} do
			local m, erro = Atores.montar(codigo)
			if m then
				m.Parent = pasta
			else
				warn("[OI3] não deu para montar o ator " .. codigo .. ":", erro)
			end
		end
		-- AJUSTE-10: as variações do monstro (catálogo + internet) e a que está valendo
		local variantes = Instance.new("Folder")
		variantes.Name = "Monstros"
		local base = pasta:FindFirstChild("CRIATURA")
		if base then
			local c = base:Clone()
			c.Name = "catalogo"
			c:SetAttribute("NomeMonstro", "Sombra do catálogo (sorriso)")
			c.Parent = variantes
		end
		local relatorio = {}
		for _, info in Config.MONSTROS_INTERNET or {} do
			local m, erro = Atores.montarMonstroInternet(info)
			if m then
				m.Name = tostring(info.id)
				m.Parent = variantes
				table.insert(relatorio, info.nome .. ": ok")
			else
				table.insert(relatorio, info.nome .. ": " .. tostring(erro))
			end
		end
		variantes.Parent = pasta
		workspace:SetAttribute("OI3_MonstrosInternet", table.concat(relatorio, " | "))
		-- qual vale: a escolha salva do ADM; senão o principal (Wendigo); senão o 1º da internet que
		-- carregou; senão o do catálogo
		local escolha = Atores.lerEscolhaMonstro()
		if not (escolha and variantes:FindFirstChild(escolha)) then
			escolha = nil
			-- AJUSTE-11: os criadores escolheram o Wendigo; se ele não carregar, fica a sombra do catálogo
			-- (os outros da internet só entram se o ADM escolher no painel)
			if Config.MONSTRO_PRINCIPAL and variantes:FindFirstChild(Config.MONSTRO_PRINCIPAL) then
				escolha = Config.MONSTRO_PRINCIPAL
			end
		end
		if escolha and escolha ~= "catalogo" then
			local v = variantes:FindFirstChild(escolha)
			if v then
				local antigo = pasta:FindFirstChild("CRIATURA")
				if antigo then
					antigo:Destroy()
				end
				local c = v:Clone()
				c.Name = "CRIATURA"
				c.Parent = pasta
			end
		end
		pasta:SetAttribute("MonstroAtivo", escolha or "catalogo")
		local rostos = Instance.new("Folder")
		rostos.Name = "Rostos"
		for nome, id in Config.ROSTOS_REACAO or {} do
			local a = Atores.montarRosto(id)
			if a then
				a.Name = nome
				a.Parent = rostos
			else
				warn("[OI3] rosto de reação '" .. nome .. "' não carregou")
			end
		end
		rostos.Parent = pasta
		local antiga = ReplicatedStorage:FindFirstChild("OI3_Atores")
		if antiga then
			antiga:Destroy()
		end
		pasta.Name = "OI3_Atores"
		pasta.Parent = ReplicatedStorage
	end)
end

-- O personagem do jogador vira a criança escolhida (mesmos itens do catálogo)
function Atores.vestirJogador(plr: Player, codigo: string)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local ok, err = pcall(function()
		hum:ApplyDescription(Atores.descricao(codigo))
	end)
	if not ok then
		warn("[OI3] não deu para vestir " .. plr.Name .. " como " .. codigo .. ":", err)
		return
	end
	Atores.ajustarRosto(char :: Model, codigo)
	pcall(Personagens.fixarRostos, char :: Model, 1)
	char:SetAttribute("Codigo", codigo)
end

return Atores
