-- AJUSTE-14: perfil alto de Morioh. Só aparência; nenhum limite por FPS ou mudança de física.
local Lighting = game:GetService("Lighting")
local AmbienteVisual14 = {}
local iniciou = false
local RGB = Color3.fromRGB
local observadores: { [Instance]: { any } } = {}
local conexaoWorkspace: any = nil
local materiaisOriginais = setmetatable({}, { __mode = "k" })

local function efeito(classe: string, nome: string): any
	local existente = Lighting:FindFirstChild(nome)
	if existente and existente:IsA(classe) then return existente end
	-- Perfis AJ13 conhecidos são reaproveitados; não empilhar bloom/grade sobre Morioh.
	local nomesLegados = if classe == "BloomEffect" then { "BloomEffect" }
		elseif classe == "ColorCorrectionEffect" then { "Paleta_Morioh", "Vivo" } else {}
	for _, legado in nomesLegados do
		local antigo = Lighting:FindFirstChild(legado)
		if antigo and antigo:IsA(classe) then return antigo end
	end
	-- Atmosphere é único no renderizador: reaproveitar o existente evita uma segunda camada.
	if classe == "Atmosphere" then
		local atmosfera = Lighting:FindFirstChildOfClass(classe)
		if atmosfera then return atmosfera end
	end
	local novo = Instance.new(classe)
	novo.Name = nome
	novo.Parent = Lighting
	return novo
end

local PAPEIS = {
	asfalto = Enum.Material.Asphalt, asphalt = Enum.Material.Asphalt,
	rua = Enum.Material.Asphalt, road = Enum.Material.Asphalt,
	concreto = Enum.Material.Concrete, concrete = Enum.Material.Concrete,
	calcada = Enum.Material.Concrete, sidewalk = Enum.Material.Concrete,
	metal = Enum.Material.Metal, steel = Enum.Material.Metal, aco = Enum.Material.Metal,
	vidro = Enum.Material.Glass, glass = Enum.Material.Glass,
	janela = Enum.Material.Glass, window = Enum.Material.Glass,
}
local function materialReconhecido(parte: BasePart): Enum.Material?
	-- Material já explícito é preservado. Não inferir papéis de cor ou posição.
	for _, material in { Enum.Material.Asphalt, Enum.Material.Concrete, Enum.Material.Metal, Enum.Material.Glass } do
		if parte.Material == material then return nil end
	end
	if parte.Material ~= Enum.Material.SmoothPlastic and parte.Material ~= Enum.Material.Plastic then return nil end
	if parte.MaterialVariant ~= "" and parte.MaterialVariant ~= nil then return nil end
	if parte:IsA("MeshPart") and parte.TextureID ~= "" then return nil end
	for _, filho in parte:GetDescendants() do
		if filho:IsA("SurfaceAppearance") or filho:IsA("Texture") or filho:IsA("Decal") then return nil end
	end
	-- Tokens inteiros: "metal" reconhece Metal_01, mas não recolore uma peça "metallicaLogo".
	for token in string.lower(parte.Name):gmatch("[%a]+") do
		if PAPEIS[token] then return PAPEIS[token] end
	end
	return nil
end

local function aplicarMaterial(item: Instance)
	if item:IsA("SurfaceAppearance") or item:IsA("Texture") or item:IsA("Decal") then
		-- Streaming pode entregar o filho de aparência depois da parte. Restaurar somente
		-- a nossa alteração; a textura especial e seus parâmetros nunca são modificados.
		local pai = item.Parent
		while pai and not pai:IsA("BasePart") do pai = pai.Parent end
		if pai and materiaisOriginais[pai] ~= nil then
			pai.Material = materiaisOriginais[pai]
			materiaisOriginais[pai] = nil
		end
	elseif item:IsA("BasePart") then
		local material = materialReconhecido(item)
		if material then
			materiaisOriginais[item] = item.Material
			item.Material = material
		end
	end
end

local function desconectarMapa(mapa: Instance)
	local conexoes = observadores[mapa]
	if not conexoes then return end
	for _, con in conexoes do con:Disconnect() end
	observadores[mapa] = nil
end

local function observarMapa(mapa: Instance)
	if mapa.Parent ~= workspace or (mapa.Name ~= "Morioh" and mapa.Name ~= "BB_Mapa") or observadores[mapa] then return end
	local conexoes = {}
	observadores[mapa] = conexoes
	table.insert(conexoes, mapa.DescendantAdded:Connect(aplicarMaterial))
	table.insert(conexoes, mapa.AncestryChanged:Connect(function()
		if mapa.Parent ~= workspace then desconectarMapa(mapa) end
	end))
	for _, item in mapa:GetDescendants() do aplicarMaterial(item) end
end

-- Desconecta todos os observadores; mantém o perfil visual já aplicado.
function AmbienteVisual14.parar()
	if conexaoWorkspace then conexaoWorkspace:Disconnect() conexaoWorkspace = nil end
	for mapa in observadores do desconectarMapa(mapa) end
	iniciou = false
end

function AmbienteVisual14.iniciar()
	if iniciou then return end
	iniciou = true
	Lighting.ClockTime = 15.8
	-- WriteSecurity=None no Creator API. pcall preserva compatibilidade de clientes antigos.
	pcall(function() Lighting.LightingStyle = Enum.LightingStyle.Realistic end)
	pcall(function() Lighting.PrioritizeLightingQuality = true end)
	Lighting.GlobalShadows = true
	Lighting.Brightness = 2.3
	Lighting.ExposureCompensation = -0.12
	Lighting.ShadowSoftness = 0.28
	Lighting.Ambient = RGB(73, 81, 108)
	Lighting.OutdoorAmbient = RGB(112, 123, 147)
	Lighting.ColorShift_Top = RGB(35, 24, 10)
	Lighting.ColorShift_Bottom = RGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.8

	local ar = efeito("Atmosphere", "BB_Ambiente14_Atmosfera")
	ar.Density, ar.Offset = 0.22, 0.12
	ar.Color, ar.Decay = RGB(214, 224, 244), RGB(128, 117, 108)
	ar.Glare, ar.Haze = 0.12, 0.65
	local bloom = efeito("BloomEffect", "BB_Ambiente14_Bloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.16, 28, 1.25
	local grade = efeito("ColorCorrectionEffect", "BB_Ambiente14_Cor")
	grade.Brightness, grade.Contrast, grade.Saturation = -0.015, 0.12, 0.09
	grade.TintColor = RGB(255, 247, 237)
	-- DOF pertence exclusivamente à sessão de cinema em CurrentCamera.
	for _, item in Lighting:GetChildren() do
		if item:IsA("DepthOfFieldEffect") then item.Enabled = false end
	end
	conexaoWorkspace = workspace.ChildAdded:Connect(observarMapa)
	for _, nome in { "Morioh", "BB_Mapa" } do
		local mapa = workspace:FindFirstChild(nome)
		if mapa then observarMapa(mapa) end
	end
end

return AmbienteVisual14
