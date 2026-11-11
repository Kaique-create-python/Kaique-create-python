-- BIZARRE BATTLEGROUNDS :: VFX da loja (AJUSTE-11)
-- Os pacotes de efeitos que o dono pegou na Creator Store ("Obter modelo"). O servidor carrega cada um
-- pelo caminho oficial do Roblox: AssetService:LoadAssetAsync (scripts já vêm desligados) e, se não der,
-- InsertService:LoadAsset (vale para o que está no inventário do dono do jogo). Depois TIRA TODOS OS
-- SCRIPTS (nenhum código de outra pessoa roda aqui), separa os efeitos por tipo pelo nome (impacto,
-- choque, explosão, corte...) e guarda só o visual em ReplicatedStorage.BB_VFXLoja.
-- O celular usa esses efeitos nos golpes (Cliente/VFX). Se nada carregar, ficam os VFX próprios.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFXLoja = {}

-- os pacotes do plano (Creator Store). Os que são só código (CraterModule, hitbox, câmera, tremor)
-- ficam de fora de propósito: seriam scripts de outra pessoa rodando no jogo.
VFXLoja.PACOTES = {
	{ id = 112672322113504, nome = "VFX PACK (Euphoric Games)" },
	{ id = 102139885640916, nome = "Explosões, lasers, fogo e fumaça" },
	{ id = 83841806206726, nome = "saythrt's Mega Pack" },
	{ id = 107474757639811, nome = "Simple VFX Pack" },
	{ id = 94340858809782, nome = "Anime Sword Slash" },
	{ id = 10153386313, nome = "Sword Slash Effect" },
}

-- palavras no nome (do pacote até o efeito) -> tipo de efeito. A primeira que bater vale.
VFXLoja.CATEGORIAS = {
	{ "explosao", { "explo", "nuke", "bomb", "detona" } },
	{ "choque", { "shock", "wave", "ring", "boom", "pulse", "nova", "blast" } },
	{ "corte", { "slash", "sword", "cut", "swing", "blade", "swoosh", "arc" } },
	{ "impacto", { "hit", "impact", "punch", "smash", "slam", "strike", "kick", "attack", "combat", "fist" } },
	{ "faisca", { "spark", "electric", "lightning", "thunder", "zap", "volt", "elec" } },
	{ "fumaca", { "smoke", "dust", "cloud", "fog", "mist" } },
	{ "fogo", { "fire", "flame", "burn", "ember", "lava" } },
	{ "laser", { "laser", "beam", "ray" } },
	{ "chao", { "crater", "ground", "rock", "debris", "crack", "floor" } },
	{ "aura", { "aura", "charge", "power", "energy", "buff", "magic", "orb" } },
	{ "flash", { "flash", "light", "star", "shine", "sparkle", "glint", "glow" } },
}
VFXLoja.MAX_POR_TIPO = 14 -- efeitos guardados por tipo (o resto fica de fora: celular leve)

local VISUAIS = { ParticleEmitter = true, Beam = true, Trail = true }
-- o que nunca entra: código e coisas que conversam pela rede ou tocam som sozinhas
local PROIBIDOS = {
	"LuaSourceContainer", "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent",
	"BindableFunction", "Sound", "Humanoid", "Tool", "ProximityPrompt", "ClickDetector",
}

local function temVisual(inst: Instance): boolean
	if VISUAIS[inst.ClassName] then
		return true
	end
	for _, d in inst:GetDescendants() do
		if VISUAIS[d.ClassName] then
			return true
		end
	end
	return false
end

-- tira todo script e tudo o que é proibido; devolve quantos saíram
function VFXLoja.limpar(raiz: Instance): number
	local tirados = 0
	for _, d in raiz:GetDescendants() do
		if d.Parent then
			for _, classe in PROIBIDOS do
				if d:IsA(classe) then
					tirados += 1
					d:Destroy()
					break
				end
			end
		end
	end
	return tirados
end

function VFXLoja.categoria(caminho: string): string
	local c = string.lower(caminho)
	for _, par in VFXLoja.CATEGORIAS do
		for _, palavra in par[2] do
			if string.find(c, palavra, 1, true) then
				return par[1]
			end
		end
	end
	return "outros"
end

-- unidades de efeito: peça/anexo com partículas, modelo "folha" (sem subgrupos com efeito) ou o
-- próprio emissor solto numa pasta
local function coletar(no: Instance, caminho: string, saida: { any })
	for _, filho in no:GetChildren() do
		local nome = caminho .. "/" .. filho.Name
		if filho:IsA("BasePart") or filho:IsA("Attachment") then
			if temVisual(filho) then
				table.insert(saida, { inst = filho, caminho = nome })
			end
		elseif filho:IsA("Model") then
			if temVisual(filho) then
				local subgrupo = false
				for _, n in filho:GetChildren() do
					if (n:IsA("Model") or n:IsA("Folder")) and temVisual(n) then
						subgrupo = true
						break
					end
				end
				if subgrupo then
					coletar(filho, nome, saida)
				else
					table.insert(saida, { inst = filho, caminho = nome })
				end
			end
		elseif filho:IsA("Folder") or filho:IsA("Configuration") then
			coletar(filho, nome, saida)
		elseif VISUAIS[filho.ClassName] then
			table.insert(saida, { inst = filho, caminho = nome })
		end
	end
end

-- pasta pública com os efeitos por tipo
local function pastaLoja(): Folder
	local p = ReplicatedStorage:FindFirstChild("BB_VFXLoja")
	if not p then
		p = Instance.new("Folder")
		p.Name = "BB_VFXLoja"
		p.Parent = ReplicatedStorage
	end
	return p :: Folder
end

-- guarda os efeitos de um pacote já carregado; devolve { efeitos, tirados, porTipo }
function VFXLoja.processar(modelo: Instance, pacote: any): any
	local tirados = VFXLoja.limpar(modelo)
	local unidades = {}
	coletar(modelo, pacote.nome, unidades)
	if #unidades == 0 and temVisual(modelo) then
		table.insert(unidades, { inst = modelo, caminho = pacote.nome })
	end
	local pasta = pastaLoja()
	local porTipo: { [string]: number } = {}
	local guardados = 0
	for i, u in unidades do
		local tipo = VFXLoja.categoria(u.caminho)
		local destino = pasta:FindFirstChild(tipo)
		if not destino then
			destino = Instance.new("Folder")
			destino.Name = tipo
			destino.Parent = pasta
		end
		if #destino:GetChildren() < VFXLoja.MAX_POR_TIPO then
			local copia = u.inst:Clone()
			copia.Name = string.format("%d_%d", pacote.id, i)
			copia:SetAttribute("Caminho", string.sub(u.caminho, 1, 120))
			copia:SetAttribute("Pacote", pacote.nome)
			-- nada encosta em ninguém e nada sai emitindo sozinho
			for _, d in copia:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
				elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
					d.Enabled = false
				end
			end
			if copia:IsA("BasePart") then
				copia.Anchored = true
				copia.CanCollide = false
				copia.CanQuery = false
				copia.CanTouch = false
			elseif copia:IsA("ParticleEmitter") or copia:IsA("Beam") or copia:IsA("Trail") then
				copia.Enabled = false
			end
			copia.Parent = destino
			porTipo[tipo] = (porTipo[tipo] or 0) + 1
			guardados += 1
		end
	end
	return { efeitos = guardados, tirados = tirados, porTipo = porTipo, unidades = #unidades }
end

-- carrega um pacote pelo caminho oficial (sem nunca rodar os scripts dele)
local function carregarPacote(id: number): (Instance?, string)
	local ok, res = pcall(function()
		return game:GetService("AssetService"):LoadAssetAsync(id)
	end)
	if ok and typeof(res) == "Instance" then
		return res, "LoadAssetAsync"
	end
	local erro1 = tostring(res)
	local ok2, res2 = pcall(function()
		return game:GetService("InsertService"):LoadAsset(id)
	end)
	if ok2 and typeof(res2) == "Instance" then
		return res2, "LoadAsset"
	end
	return nil, string.sub(erro1 .. " | " .. tostring(res2), 1, 160)
end

local function resumoTipos(porTipo: { [string]: number }): string
	local l = {}
	for tipo, n in porTipo do
		table.insert(l, tipo .. " " .. n)
	end
	table.sort(l)
	return table.concat(l, ", ")
end

VFXLoja.relatorio = {} :: { any }

function VFXLoja.iniciar()
	local pasta = pastaLoja()
	pasta:SetAttribute("Resumo", "carregando os pacotes...")
	local partes = {}
	for _, pacote in VFXLoja.PACOTES do
		local modelo, como = carregarPacote(pacote.id)
		local r: any = { id = pacote.id, nome = pacote.nome }
		if modelo then
			local ok, res = pcall(VFXLoja.processar, modelo, pacote)
			modelo:Destroy()
			if ok then
				r.ok = true
				r.como = como
				r.efeitos = res.efeitos
				r.tirados = res.tirados
				r.tipos = resumoTipos(res.porTipo)
				table.insert(partes, string.format("%s: OK (%d efeitos; %s; %d scripts tirados)", pacote.nome, res.efeitos, r.tipos, res.tirados))
			else
				r.erro = "erro ao separar: " .. tostring(res)
				table.insert(partes, pacote.nome .. ": " .. r.erro)
			end
		else
			r.erro = como
			table.insert(partes, pacote.nome .. ": NÃO CARREGOU (" .. como .. ")")
		end
		table.insert(VFXLoja.relatorio, r)
		pasta:SetAttribute("Resumo", table.concat(partes, " · "))
	end
	pasta:SetAttribute("Pronto", true)
	print("[BB] VFX da loja: " .. tostring(pasta:GetAttribute("Resumo")))
end

return VFXLoja
