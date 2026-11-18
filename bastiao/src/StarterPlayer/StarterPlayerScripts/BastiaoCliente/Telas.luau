--!strict
-- PROJETO BASTIÃO :: telas dos terminais (cliente)
-- O servidor só marca a peça (tag BastiaoTela) e diz qual tela e qual estado. Cada cliente
-- desenha a tela na própria língua com um SurfaceGui local (Adornee na peça). Com streaming a
-- peça entra e sai; a tela vai junto.

local CollectionService = game:GetService("CollectionService")

local Telas = {}

local TAG = "BastiaoTela"
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local FUNDO = Color3.fromRGB(9, 13, 11)
local COR = {
	apagado = Color3.fromRGB(70, 74, 66),
	ambar = Color3.fromRGB(244, 186, 88),
	vermelho = Color3.fromRGB(255, 96, 76),
	verde = Color3.fromRGB(150, 236, 160),
	verdeApagado = Color3.fromRGB(64, 92, 70),
}

-- completa com espaços contando letras (não bytes): o russo usa 2 bytes por letra
function Telas.coluna(texto: string, largura: number): string
	local n = utf8.len(texto) or #texto
	if n >= largura then
		return texto .. " "
	end
	return texto .. string.rep(" ", largura - n)
end

-- texto e cor de uma tela, numa língua (função pura: os testes usam direto)
function Telas.conteudo(L: any, id: string, estado: string, nomes: string): (string, Color3)
	local T = L.terminais
	if id == "enfermaria" then
		local texto = T["enfermaria_" .. estado] or ""
		local cor = if estado == "sem_energia" then COR.apagado elseif estado == "ligado" then COR.ambar else COR.vermelho
		return texto, cor
	elseif id == "oficina" then
		if estado == "lista" then
			local linhas = { T.oficina_cabecalho }
			table.insert(linhas, "  " .. Telas.coluna(T.sgt, 8) .. Telas.coluna(T.antonov, 18) .. T.presente)
			local i = 0
			for nome in string.gmatch(nomes or "", "[^\n]+") do
				i += 1
				table.insert(linhas, "  " .. Telas.coluna("KEDR-" .. i, 8) .. Telas.coluna(nome, 18) .. T.presente)
			end
			table.insert(linhas, "  " .. Telas.coluna("731-A", 8) .. Telas.coluna(T.sokolov, 18) .. T.avaliacao)
			table.insert(linhas, "")
			table.insert(linhas, T.oficina_rodape)
			return table.concat(linhas, "\n"), COR.verde
		end
		return T["oficina_" .. estado] or "", if estado == "apagado" then COR.verdeApagado else COR.verde
	end
	return "", COR.ambar
end

function Telas.iniciar(op: { playerGui: Instance, textos: any, idioma: () -> string, aoMudar: (fn: (string) -> ()) -> () })
	local pasta = Instance.new("Folder")
	pasta.Name = "BastiaoTelas"
	pasta.Parent = op.playerGui
	local telas: { [BasePart]: { gui: SurfaceGui, texto: TextLabel, conexoes: { RBXScriptConnection } } } = {}

	local function desenhar(parte: BasePart)
		local t = telas[parte]
		if not t then
			return
		end
		local id = tostring(parte:GetAttribute("BastiaoTela") or "")
		local estado = tostring(parte:GetAttribute("BastiaoTelaEstado") or "")
		local nomes = tostring(parte:GetAttribute("BastiaoTelaNomes") or "")
		local texto, cor = Telas.conteudo(op.textos.de(op.idioma()), id, estado, nomes)
		t.texto.Text = texto
		t.texto.TextColor3 = cor
	end

	local function remover(inst: Instance)
		local parte = inst :: BasePart
		local t = telas[parte]
		if not t then
			return
		end
		for _, c in t.conexoes do
			c:Disconnect()
		end
		t.gui:Destroy()
		telas[parte] = nil
	end

	local function criar(inst: Instance)
		if not inst:IsA("BasePart") or telas[inst] then
			return
		end
		local parte = inst :: BasePart
		local tamanho = tonumber(parte:GetAttribute("BastiaoTelaTamanho")) or 15
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Tela_" .. tostring(parte:GetAttribute("BastiaoTela"))
		sg.Adornee = parte
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = tonumber(parte:GetAttribute("BastiaoTelaPPS")) or 160
		sg.LightInfluence = 0
		sg.ClipsDescendants = true
		sg.ResetOnSpawn = false
		pcall(function()
			(sg :: any).Brightness = 1.6
		end)
		local fundo = Instance.new("Frame")
		fundo.Size = UDim2.fromScale(1, 1)
		fundo.BorderSizePixel = 0
		fundo.BackgroundColor3 = FUNDO
		fundo.Parent = sg
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, math.floor(tamanho * 0.8))
		pad.PaddingRight = UDim.new(0, math.floor(tamanho * 0.6))
		pad.PaddingTop = UDim.new(0, math.floor(tamanho * 0.7))
		pad.Parent = fundo
		local texto = Instance.new("TextLabel")
		texto.BackgroundTransparency = 1
		texto.Size = UDim2.fromScale(1, 1)
		texto.FontFace = MONO
		texto.TextSize = tamanho
		texto.TextXAlignment = Enum.TextXAlignment.Left
		texto.TextYAlignment = Enum.TextYAlignment.Top
		texto.TextWrapped = true
		texto.LineHeight = 1.05
		texto.Parent = fundo
		sg.Parent = pasta
		local conexoes = {}
		for _, atributo in { "BastiaoTelaEstado", "BastiaoTelaNomes" } do
			table.insert(
				conexoes,
				parte:GetAttributeChangedSignal(atributo):Connect(function()
					desenhar(parte)
				end)
			)
		end
		table.insert(
			conexoes,
			parte.AncestryChanged:Connect(function()
				if not parte:IsDescendantOf(workspace) then
					remover(parte)
				end
			end)
		)
		telas[parte] = { gui = sg, texto = texto, conexoes = conexoes }
		desenhar(parte)
	end

	for _, inst in CollectionService:GetTagged(TAG) do
		criar(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(criar)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remover)
	op.aoMudar(function()
		for parte in telas do
			desenhar(parte)
		end
	end)
end

return Telas
