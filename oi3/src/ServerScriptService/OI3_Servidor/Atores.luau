-- OI3 :: atores (AJUSTE-6)
-- Os personagens são avatares do Roblox montados SÓ com IDs do catálogo, pelo sistema oficial
-- (HumanoidDescription): rosto, cabelo, chapéu, camisa, calça e cor da pele. Nada é modelado.
-- Os modelos prontos ficam em ReplicatedStorage.OI3_Atores/<código> para a cutscene copiar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OI3 = ReplicatedStorage:WaitForChild("OI3")
local Config = require(OI3:WaitForChild("Config"))

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

function Atores.montar(codigo: string): (Model?, string?)
	local r = (Config.ROUPAS or {})[codigo]
	if not r then
		return nil, "personagem desconhecido"
	end
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Atores.descricao(codigo), Enum.HumanoidRigType.R6)
	end)
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
	if math.abs(s - 1) > 0.001 then
		pcall(function()
			modelo:ScaleTo(s)
		end)
	end
	modelo:SetAttribute("Escala", s)
	modelo:SetAttribute("Codigo", codigo)
	return modelo, nil
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
	char:SetAttribute("Codigo", codigo)
end

return Atores
