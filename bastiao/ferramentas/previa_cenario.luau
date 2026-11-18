-- PROJETO BASTIÃO :: exporta vistas do cenário (mapa real + peças novas) para a prévia 3D
-- Uso: lune run bastiao/ferramentas/previa_cenario.luau <place.rbxl> <pasta_saida> [pt|en|ru]
-- Gera <pasta_saida>/<vista>.json e <pasta_saida>/lote.json (para previa/shot.js).
-- A prévia é aproximada (three.js), não é o render do Roblox: serve para conferir
-- posição, escala, cor e leitura dos textos antes de publicar.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local caminhoPlace = process.args[1]
local saida = process.args[2]
assert(caminhoPlace and saida, "uso: previa_cenario.luau <place.rbxl> <pasta_saida>")
fs.writeDir(saida)

local raiz = if fs.isDir("bastiao/src") then "bastiao/src/" else "src/"
local G = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	Font = roblox.Font,
	game = { GetService = function()
		return {}
	end },
}
local function carregar(caminho: string)
	return luau.load(fs.readFile(raiz .. caminho), { debugName = caminho, environment = G })()
end
local V, CF = roblox.Vector3.new, roblox.CFrame.new
local Cenario = carregar("ServerScriptService/BastiaoServidor/Cenario.luau")
local Mundo = carregar("ServerScriptService/BastiaoServidor/Mundo.luau")
local Textos = carregar("ReplicatedStorage/BastiaoCompartilhado/Textos.luau")
local Telas = carregar("StarterPlayer/StarterPlayerScripts/BastiaoCliente/Telas.luau")
-- as telas dos terminais são desenhadas pelo cliente na língua do jogador; a prévia escolhe uma
local IDIOMA = Textos.normalizar(process.args[3] or "pt")

local game = roblox.deserializePlace(fs.readFile(caminhoPlace))
local workspace = game:GetService("Workspace")
local mapa = workspace:FindFirstChild("Sector7World")
local pasta = roblox.Instance.new("Folder")
pasta.Name = "BastiaoHistoria"
pasta.Parent = workspace
local pavel = { estado = "tunel" }
function pavel:ir(e)
	self.estado = e
end
function pavel:chegou()
	return true
end
local jogadoresFalsos = { { UserId = 1, Name = "Ana", DisplayName = "Ana" }, { UserId = 2, Name = "Bia", DisplayName = "Bia" } }
local mundo = Mundo.novo(print)
Cenario.construir({
	pasta = pasta,
	textos = Textos,
	mundo = mundo,
	servicos = {
		tween = function(inst, _t, alvo)
			for k, v in alvo do
				(inst :: any)[k] = v
			end
		end,
		atrasar = function() end,
		marcar = function(inst, tag)
			inst:AddTag(tag)
		end,
		agora = function()
			return 0
		end,
	},
	jogadores = function()
		return jogadoresFalsos
	end,
	criarPavel = function()
		return pavel
	end,
})

-- Pavel de prévia: blocos R6 com as cores do uniforme dele
local PAVEL = {
	tunel = { pos = V(3.4, 0, 2.2), olhar = V(0.5, 0, 12) },
	oficina = { pos = V(71.5, 0, -304.5), olhar = V(80, 0, -316) },
	enfermaria = { pos = V(-58.5, 0, -310.5), olhar = V(-55, 0, -298) },
	arsenal = { pos = V(-82.5, 0, -203.5), olhar = V(-82, 0, -212) },
}
local function pavelBlocos(lugar: any): { any }
	local base = roblox.CFrame.lookAt(lugar.pos + V(0, 3, 0), V(lugar.olhar.X, 3, lugar.olhar.Z))
	local pele, tronco, pernas = { 176, 148, 122 }, { 112, 104, 76 }, { 52, 56, 44 }
	local r = {}
	local function b(nome, tamanho, off, cor)
		table.insert(r, { nome = nome, cf = base * off, s = tamanho, c = cor })
	end
	b("Tronco", V(2, 2, 1), CF(0, 0, 0), tronco)
	b("Cabeca", V(1.2, 1.2, 1.2), CF(0, 1.6, 0), pele)
	b("BracoD", V(1, 2, 1), CF(1.5, 0, 0), pele)
	b("BracoE", V(1, 2, 1), CF(-1.5, 0, 0), pele)
	b("PernaD", V(1, 2, 1), CF(0.5, -2, 0), pernas)
	b("PernaE", V(1, 2, 1), CF(-0.5, -2, 0), pernas)
	b("Cinto", V(2.04, 0.22, 1.04), CF(0, -0.9, 0), { 30, 30, 26 })
	return r
end

local function rgb(c: any): string
	return string.format("[%d,%d,%d]", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function esc(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "\\", "\\\\"), '"', '\\"'), "\n", "\\n"))
end
local function luzesDe(p: any): string
	local l = {}
	for _, f in p:GetChildren() do
		if (f:IsA("PointLight") or f:IsA("SpotLight")) and f.Enabled then
			local ang = if f:IsA("SpotLight") then f.Angle else 0
			local face = if f:IsA("SpotLight") then string.gsub(tostring(f.Face), "Enum.NormalId.", "") else ""
			table.insert(l, string.format('{"tipo":"%s","c":%s,"b":%.2f,"a":%.1f,"ang":%.1f,"face":"%s"}', f.ClassName, rgb(f.Color), f.Brightness, f.Range, ang, face))
		end
	end
	return "[" .. table.concat(l, ",") .. "]"
end
local function telaDe(p: any): string
	local id = p:GetAttribute("BastiaoTela")
	if type(id) == "string" and id ~= "" then
		-- igual ao Telas.luau do cliente: fundo escuro, texto mono, padding e cor por estado
		local texto, cor = Telas.conteudo(Textos.de(IDIOMA), id, tostring(p:GetAttribute("BastiaoTelaEstado") or ""), tostring(p:GetAttribute("BastiaoTelaNomes") or ""))
		return string.format(
			'{"face":"Front","pps":%d,"bg":[9,13,11],"bgt":0.00,"cor":%s,"px":%d,"txt":"%s","ax":"Left","ay":"Top","luz":false}',
			tonumber(p:GetAttribute("BastiaoTelaPPS")) or 160,
			rgb(cor),
			tonumber(p:GetAttribute("BastiaoTelaTamanho")) or 15,
			esc(texto)
		)
	end
	local sg = p:FindFirstChild("Tela")
	if not sg then
		return "null"
	end
	local fundo = sg:FindFirstChild("Fundo")
	local t = fundo and fundo:FindFirstChild("Texto")
	if not t then
		return "null"
	end
	local face = string.gsub(tostring(sg.Face), "Enum.NormalId.", "")
	return string.format(
		'{"face":"%s","pps":%d,"bg":%s,"bgt":%.2f,"cor":%s,"px":%d,"txt":"%s","ax":"%s","ay":"%s","luz":%s}',
		face,
		sg.PixelsPerStud,
		rgb(fundo.BackgroundColor3),
		fundo.BackgroundTransparency,
		rgb(t.TextColor3),
		t.TextSize,
		esc(t.Text),
		(string.gsub(tostring(t.TextXAlignment), "Enum.TextXAlignment.", "")),
		(string.gsub(tostring(t.TextYAlignment), "Enum.TextYAlignment.", "")),
		tostring(sg.LightInfluence > 0.5)
	)
end
local function linha(cf: any, s: any, cor: string, material: string, transp: number, forma: string, novo: boolean, luzes: string, tela: string, nome: string): string
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return string.format(
		'{"n":"%s","novo":%s,"f":"%s","m":"%s","t":%.2f,"c":%s,"s":[%.3f,%.3f,%.3f],"p":[%.3f,%.3f,%.3f],"r":[%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f],"luz":%s,"tela":%s}',
		esc(nome),
		tostring(novo),
		forma,
		material,
		transp,
		cor,
		s.X,
		s.Y,
		s.Z,
		x,
		y,
		z,
		r00,
		r01,
		r02,
		r10,
		r11,
		r12,
		r20,
		r21,
		r22,
		luzes,
		tela
	)
end
local function parteJson(p: any, novo: boolean): string
	local forma = if p:IsA("Part") then (string.gsub(tostring(p.Shape), "Enum.PartType.", "")) else "Block"
	return linha(p.CFrame, p.Size, rgb(p.Color), (string.gsub(tostring(p.Material), "Enum.Material.", "")), p.Transparency, forma, novo, luzesDe(p), if novo then telaDe(p) else "null", p.Name)
end

local function exportar(nome: string, centro: any, raio: number, extras: { any }?): string
	local linhas = {}
	local function perto(p: any): boolean
		local c = p.CFrame.Position
		local m = math.max(p.Size.X, p.Size.Y, p.Size.Z) / 2
		return math.abs(c.X - centro.X) <= raio + m and math.abs(c.Z - centro.Z) <= raio + m and math.abs(c.Y - centro.Y) <= 30 + m
	end
	for _, d in mapa:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 and perto(d) then
			table.insert(linhas, parteJson(d, false))
		end
	end
	for _, d in pasta:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 and d:IsDescendantOf(workspace) and perto(d) then
			table.insert(linhas, parteJson(d, true))
		end
	end
	for _, e in extras or {} do
		table.insert(linhas, linha(e.cf, e.s, string.format("[%d,%d,%d]", e.c[1], e.c[2], e.c[3]), "SmoothPlastic", 0, "Block", true, "[]", "null", e.nome))
	end
	local arquivo = saida .. "/" .. nome .. ".json"
	fs.writeFile(arquivo, "[\n" .. table.concat(linhas, ",\n") .. "\n]\n")
	print(string.format("[Previa] %s: %d peças", nome, #linhas))
	return arquivo
end

local function estados(t: { [string]: string })
	for id, e in t do
		mundo:definir(id, e, true)
	end
end

local OLHO = 4.3 -- câmera de peito da bodycam
local vistas = {
	{
		nome = "1_tunel_pavel",
		rotulo = "Cena 1 · túnel de entrada: Pavel, caixa com rádio, caneca e lista de turno, relógio 02:49",
		estados = { radio = "oferecido", acesso_externo = "aberto", alarme = "desligado" },
		pavel = "tunel",
		cam = V(0.4, OLHO, 13.5),
		alvo = V(4.2, 2.6, 1.6),
	},
	{
		nome = "2_acesso_externo",
		rotulo = "Cena 5 · antepara atrás do spawn: ACESSO EXTERNO BLOQUEADO no isolamento",
		estados = { acesso_externo = "bloqueado", alarme = "ligado" },
		cam = V(-1.5, OLHO, 13.5),
		alvo = V(2.6, 5.4, 24),
	},
	{
		nome = "3_arsenal_carregador",
		rotulo = "Cena 3 · arsenal: carregador com o módulo de reserva disponível",
		estados = { bateria = "disponivel" },
		pavel = "arsenal",
		cam = V(-80.5, OLHO, -213),
		alvo = V(-88, 2.4, -199),
	},
	{
		nome = "4_enfermaria_terminal",
		rotulo = "Cena 4 · corredor oeste: terminal externo com o módulo encaixado e a porta de contenção",
		estados = { bateria = "encaixada", terminal_enfermaria = "autorizado", porta_contencao = "destravada", alarme = "desligado" },
		pavel = "enfermaria",
		cam = V(-56.5, OLHO, -296),
		alvo = V(-65, 3.2, -314),
	},
	{
		nome = "5_isolamento_corredor",
		rotulo = "Cena 5 · isolamento: giroflex ligado no corredor de serviço",
		estados = { alarme = "ligado", porta_contencao = "trancada", terminal_enfermaria = "autorizado", bateria = "encaixada" },
		cam = V(-58, OLHO, -270),
		alvo = V(-52, 4.2, -290),
	},
	{
		nome = "6_oficina_porta",
		rotulo = "Cena 7 · porta da oficina trancada vista do corredor leste",
		estados = { porta_oficina = "trancada", alarme = "ligado" },
		cam = V(56, OLHO, -306),
		alvo = V(65, 3.6, -320),
	},
	{
		nome = "7_oficina_trava",
		rotulo = "Cena 7 · dentro da oficina: alavanca da trava (abaixada) e o Pavel",
		estados = { porta_oficina = "travada", alarme = "ligado" },
		pavel = "oficina",
		cam = V(79, OLHO, -317),
		alvo = V(66, 3.4, -306),
	},
	{
		nome = "8_terminal_lista",
		rotulo = "Cena 8 · terminal da oficina com a lista do turno (nomes dos jogadores do servidor)",
		estados = { terminal_oficina = "lista" },
		cam = V(87.4, 4.6, -303.6),
		alvo = V(87.7, 3.7, -299.2),
		fov = 58,
	},
}

local lote = {}
for _, v in vistas do
	estados(v.estados)
	local extras = if v.pavel then pavelBlocos(PAVEL[v.pavel]) else nil
	local arq = exportar(v.nome, v.cam, 46, extras)
	table.insert(
		lote,
		string.format(
			'{"pecas":"%s","saida":"%s/%s.png","opts":{"w":1280,"h":720,"cam":[%.2f,%.2f,%.2f],"alvo":[%.2f,%.2f,%.2f],"fov":%d,"rotulo":"%s"}}',
			arq,
			saida,
			v.nome,
			v.cam.X,
			v.cam.Y,
			v.cam.Z,
			v.alvo.X,
			v.alvo.Y,
			v.alvo.Z,
			v.fov or 72,
			esc(v.rotulo)
		)
	)
end
fs.writeFile(saida .. "/lote.json", "[\n" .. table.concat(lote, ",\n") .. "\n]\n")
print("[Previa] lote pronto: " .. saida .. "/lote.json")
