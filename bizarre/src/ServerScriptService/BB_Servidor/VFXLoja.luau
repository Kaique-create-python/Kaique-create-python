-- BIZARRE BATTLEGROUNDS :: VFX da loja (AJUSTE-11)
-- Os pacotes de efeitos que o dono pegou na Creator Store ("Obter modelo"). O servidor carrega cada um
-- pelo caminho oficial do Roblox: AssetService:LoadAssetAsync (scripts já vêm desligados) e, se não der,
-- InsertService:LoadAsset (vale para o que está no inventário do dono do jogo). Depois TIRA TODOS OS
-- SCRIPTS (nenhum código de outra pessoa roda aqui), separa os efeitos por tipo pelo nome (impacto,
-- choque, explosão, corte...) e guarda só o visual em ReplicatedStorage.BB_VFXLoja.
-- O celular usa esses efeitos nos golpes (Cliente/VFX). Se nada carregar, ficam os VFX próprios.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- AJUSTE-13: cada efeito guardado é medido (tamanho, duração, cor) para o celular usar na escala e
-- na cor certas; cada pacote tem a sua vaga em cada tipo (o primeiro pacote não ocupa tudo).
-- (sem o módulo de medida, o celular mede sozinho na primeira vez que usa o efeito)
local Medida: any = nil
local function medida(): any
	if Medida == nil then
		local ok, m = pcall(function()
			return require(ReplicatedStorage:WaitForChild("BB", 10):WaitForChild("VFXMedida", 10))
		end)
		Medida = if ok and m then m else false
	end
	return Medida or nil
end

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
	{ "impacto", { "hit", "impact", "punch", "smash", "slam", "strike", "kick", "attack", "combat", "fist", "dmg", "damage", "bash", "pound", "crush", "knock", "blow", "jab", "hook", "uppercut", "m1", "combo", "melee", "black" } },
	{ "faisca", { "spark", "electric", "lightning", "thunder", "zap", "volt", "elec" } },
	{ "fumaca", { "smoke", "dust", "cloud", "fog", "mist" } },
	{ "fogo", { "fire", "flame", "burn", "ember", "lava" } },
	{ "laser", { "laser", "beam", "ray" } },
	{ "chao", { "crater", "ground", "rock", "debris", "crack", "floor" } },
	{ "aura", { "aura", "charge", "power", "energy", "buff", "magic", "orb", "spirit", "chakra", "ki", "domain", "stand" } },
	{ "flash", { "flash", "light", "star", "shine", "sparkle", "glint", "glow", "twinkle", "flare" } },
}
VFXLoja.MAX_POR_TIPO = 30 -- efeitos guardados por tipo (o resto fica de fora: celular leve)
VFXLoja.MAX_POR_PACOTE_TIPO = 8 -- AJUSTE-13: vaga de cada pacote em cada tipo

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
		if #destino:GetChildren() < VFXLoja.MAX_POR_TIPO and (porTipo[tipo] or 0) < VFXLoja.MAX_POR_PACOTE_TIPO then
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
			local M = medida()
			if M then
				pcall(function()
					M.anotar(copia, M.medir(copia))
				end)
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

-- AJUSTE-13: descrição de cada efeito guardado (o teste na nuvem devolve e o instalador salva num
-- arquivo para o dono mandar no chat: assim dá para ver cada efeito e escolher o melhor por golpe)
local function hex(c: Color3): string
	return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function VFXLoja.descrever(): any
	local pasta = ReplicatedStorage:FindFirstChild("BB_VFXLoja")
	local saida = { resumo = pasta and pasta:GetAttribute("Resumo"), relatorio = VFXLoja.relatorio, tipos = {} }
	if not pasta then
		return saida
	end
	for _, tipo in pasta:GetChildren() do
		local lista = {}
		for _, e in tipo:GetChildren() do
			local item: any = {
				nome = e.Name,
				caminho = e:GetAttribute("Caminho"),
				pacote = e:GetAttribute("Pacote"),
				classe = e.ClassName,
				raio = e:GetAttribute("Raio"),
				vida = e:GetAttribute("Vida"),
				nota = e:GetAttribute("Nota"),
				emissores = {},
				pecas = {},
			}
			local todos = e:GetDescendants()
			table.insert(todos, e)
			for _, d in todos do
				if d:IsA("ParticleEmitter") and #item.emissores < 12 then
					local cores = {}
					for _, k in d.Color.Keypoints do
						table.insert(cores, hex(k.Value))
					end
					local tam = 0
					for _, k in d.Size.Keypoints do
						tam = math.max(tam, k.Value)
					end
					table.insert(item.emissores, {
						n = d.Name, tex = d.Texture, cor = table.concat(cores, " "), tam = tam,
						vida = d.Lifetime.Max, vel = d.Speed.Max, luz = d.LightEmission, taxa = d.Rate,
						emit = d:GetAttribute("EmitCount"), atraso = d:GetAttribute("EmitDelay"),
						flip = tostring(d.FlipbookLayout), orient = tostring(d.Orientation),
					})
				elseif d:IsA("BasePart") and d.Transparency < 1 and #item.pecas < 6 then
					local malha = ""
					if d:IsA("MeshPart") then
						malha = d.MeshId .. " " .. d.TextureID
					else
						local m = d:FindFirstChildOfClass("SpecialMesh")
						if m then
							malha = m.MeshId .. " " .. m.TextureId
						end
					end
					table.insert(item.pecas, { n = d.Name, classe = d.ClassName, cor = hex(d.Color), mat = tostring(d.Material), malha = malha })
				end
			end
			table.insert(lista, item)
		end
		saida.tipos[tipo.Name] = lista
	end
	return saida
end

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
	-- AJUSTE-12: os nomes de cada efeito por tipo (o DIAG mostra; serve para escolher cada um no golpe certo)
	local nomes = {}
	for _, tipo in pasta:GetChildren() do
		local l = {}
		for i, e in tipo:GetChildren() do
			if i <= 10 then
				local caminho = tostring(e:GetAttribute("Caminho") or e.Name)
				table.insert(l, string.match(caminho, "([^/]+/[^/]+)$") or caminho)
			end
		end
		table.insert(nomes, string.format("%s (%d): %s", tipo.Name, #tipo:GetChildren(), table.concat(l, ", ")))
	end
	table.sort(nomes)
	pasta:SetAttribute("Nomes", table.concat(nomes, " | "))
	pasta:SetAttribute("Pronto", true)
	print("[BB] VFX da loja: " .. tostring(pasta:GetAttribute("Resumo")))
end

return VFXLoja
