-- PROJETO BASTIÃO :: monta o cenário da Etapa 1 dentro do place real e confere a geometria
--   * nenhuma peça nova atravessa parede, batente, abóbada ou móvel do mapa;
--   * peças de parede encostam numa parede de verdade e móveis de chão têm chão;
--   * cada interação tem um lugar livre para ficar em pé, ao alcance do prompt;
--   * a rota do Pavel passa livre pelos corredores (cápsula do tamanho de um R6);
--   * as folhas da porta da oficina somem dentro da parede quando abertas;
--   * o mapa Sector7World fica idêntico (mesmas peças, mesmas propriedades).
-- Uso: lune run bastiao/ferramentas/teste_cenario.luau <place.rbxl>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local caminhoPlace = process.args[1] or "/tmp/claude-0/-home-user/8073e9e5-493c-555e-858a-2e1de54d2eed/scratchpad/bastiao/place/place_original.rbxl"
if not fs.isFile(caminhoPlace) then
	print("[Cenario] SKIP: place não encontrado em " .. caminhoPlace)
	process.exit(0)
end

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
}
local function carregar(caminho: string)
	return luau.load(fs.readFile(raiz .. caminho), { debugName = caminho, environment = G })()
end
local V = roblox.Vector3.new
local CF = roblox.CFrame.new

local Cenario = carregar("ServerScriptService/BastiaoServidor/Cenario.luau")
local Mundo = carregar("ServerScriptService/BastiaoServidor/Mundo.luau")
local Textos = carregar("ReplicatedStorage/BastiaoCompartilhado/Textos.luau")
local PavelRotas = (function()
	-- lê LUGARES/ROTAS do Pavel sem rodar o módulo (ele só funciona dentro do Roblox)
	local fonte = fs.readFile(raiz .. "ServerScriptService/BastiaoServidor/Pavel.luau")
	local inicio = string.find(fonte, "Pavel.LUGARES = {", 1, true)
	local fim = string.find(fonte, "local CORES", 1, true)
	local trecho = "local Pavel = {}\nlocal V = Vector3.new\n" .. string.sub(fonte, inicio, fim - 1) .. "\nreturn Pavel"
	return luau.load(trecho, { debugName = "PavelRotas", environment = G })()
end)()

local falhas = {}
local function falha(msg: string)
	table.insert(falhas, msg)
	print("[Cenario] FALHA " .. msg)
end
local function pass(nome: string)
	print("[Cenario] PASS " .. nome)
end

local game = roblox.deserializePlace(fs.readFile(caminhoPlace))
local workspace = game:GetService("Workspace")
local mapa = workspace:FindFirstChild("Sector7World")
assert(mapa, "Sector7World ausente no place")

-- ===== impressão digital do mapa (para provar que nada mudou) =====
local function arred(n: number): string
	return string.format("%.4f", n)
end
local function digital(): string
	local linhas = {}
	for _, d in mapa:GetDescendants() do
		local l = d.ClassName .. "|" .. d:GetFullName()
		if d:IsA("BasePart") then
			local c = d.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
			l ..= "|" .. table.concat({ arred(x), arred(y), arred(z), arred(r00), arred(r01), arred(r02), arred(r10), arred(r11), arred(r12), arred(r20), arred(r21), arred(r22) }, ",")
			l ..= "|" .. tostring(d.Size) .. "|" .. tostring(d.Color) .. "|" .. tostring(d.Transparency) .. "|" .. tostring(d.CanCollide) .. "|" .. tostring(d.Material)
		elseif d:IsA("Light") then
			l ..= "|" .. tostring(d.Enabled) .. "|" .. tostring(d.Color) .. "|" .. tostring(d.Brightness)
		end
		table.insert(linhas, l)
	end
	table.sort(linhas)
	return table.concat(linhas, "\n")
end
local antes = digital()
local filhosAntes = #workspace:GetChildren()

-- ===== monta igual ao servidor (Pavel falso: só guarda o estado) =====
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
local mundo = Mundo.novo(function(m)
	falha("mundo: " .. m)
end)
local cena = Cenario.construir({
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
		return {}
	end,
	criarPavel = function()
		return pavel
	end,
})

-- aplica todos os estados de todas as entidades (sem animação) para pegar erro de execução
local ordemEstados = {
	pavel = { "tunel", "arsenal", "enfermaria", "porta_oficina", "oficina" },
	relogio = { "0249" },
	radio = { "guardado", "oferecido", "entregue", "guardado" },
	bateria = { "no_carregador", "disponivel", "carregada", "encaixada", "no_carregador" },
	terminal_enfermaria = { "sem_energia", "ligado", "autorizado", "sem_energia" },
	porta_contencao = { "trancada", "vazando", "destravada", "trancada" },
	alarme = { "desligado", "ligado", "desligado" },
	acesso_externo = { "aberto", "bloqueado", "aberto" },
	porta_oficina = { "aberta", "trancada", "travada", "aberta" },
	terminal_oficina = { "apagado", "aguardando", "lista", "apagado" },
	fim = { "oculto", "visivel", "oculto" },
}
for id, lista in ordemEstados do
	for _, e in lista do
		local ok, err = pcall(function()
			mundo:definir(id, e, true)
		end)
		if not ok then
			falha("estado " .. id .. "=" .. e .. ": " .. tostring(err))
		end
	end
end
pass("todos_os_estados_aplicam")

-- ===== geometria =====
local function eixos(cf: any)
	return { cf:VectorToWorldSpace(V(1, 0, 0)), cf:VectorToWorldSpace(V(0, 1, 0)), cf:VectorToWorldSpace(V(0, 0, 1)) }
end
local function caixa(p: any)
	local cf, s = p.CFrame, p.Size
	local a = eixos(cf)
	local h = { s.X / 2, s.Y / 2, s.Z / 2 }
	-- AABB
	local ext = V(
		h[1] * math.abs(a[1].X) + h[2] * math.abs(a[2].X) + h[3] * math.abs(a[3].X),
		h[1] * math.abs(a[1].Y) + h[2] * math.abs(a[2].Y) + h[3] * math.abs(a[3].Y),
		h[1] * math.abs(a[1].Z) + h[2] * math.abs(a[2].Z) + h[3] * math.abs(a[3].Z)
	)
	return { parte = p, cf = cf, c = cf.Position, a = a, h = h, min = cf.Position - ext, max = cf.Position + ext }
end
local function penetracao(A: any, B: any): number
	local ls = { A.a[1], A.a[2], A.a[3], B.a[1], B.a[2], B.a[3] }
	for i = 1, 3 do
		for j = 1, 3 do
			local x = A.a[i]:Cross(B.a[j])
			if x.Magnitude > 1e-5 then
				table.insert(ls, x.Unit)
			end
		end
	end
	local d = B.c - A.c
	local menor = math.huge
	for _, L in ls do
		local rA = A.h[1] * math.abs(A.a[1]:Dot(L)) + A.h[2] * math.abs(A.a[2]:Dot(L)) + A.h[3] * math.abs(A.a[3]:Dot(L))
		local rB = B.h[1] * math.abs(B.a[1]:Dot(L)) + B.h[2] * math.abs(B.a[2]:Dot(L)) + B.h[3] * math.abs(B.a[3]:Dot(L))
		local p = rA + rB - math.abs(d:Dot(L))
		if p <= 0 then
			return p
		end
		menor = math.min(menor, p)
	end
	return menor
end
local function dentroCaixa(b: any, ponto: any, folga: number?): boolean
	local r = b.cf:PointToObjectSpace(ponto)
	local f = folga or 0
	return math.abs(r.X) <= b.h[1] + f and math.abs(r.Y) <= b.h[2] + f and math.abs(r.Z) <= b.h[3] + f
end

-- grade de busca para as peças do mapa
local CEL = 8
local grade = {}
local pecasMapa = {}
for _, d in mapa:GetDescendants() do
	if d:IsA("BasePart") then
		local b = caixa(d)
		b.solida = d.CanCollide
		b.visivel = d.Transparency < 0.99
		table.insert(pecasMapa, b)
		for gx = math.floor(b.min.X / CEL), math.floor(b.max.X / CEL) do
			for gz = math.floor(b.min.Z / CEL), math.floor(b.max.Z / CEL) do
				local k = gx .. ":" .. gz
				grade[k] = grade[k] or {}
				table.insert(grade[k], b)
			end
		end
	end
end
local function perto(min: any, max: any): { any }
	local vistos, r = {}, {}
	for gx = math.floor(min.X / CEL), math.floor(max.X / CEL) do
		for gz = math.floor(min.Z / CEL), math.floor(max.Z / CEL) do
			for _, b in grade[gx .. ":" .. gz] or {} do
				if not vistos[b] and b.max.Y >= min.Y and b.min.Y <= max.Y and b.max.X >= min.X and b.min.X <= max.X and b.max.Z >= min.Z and b.min.Z <= max.Z then
					vistos[b] = true
					table.insert(r, b)
				end
			end
		end
	end
	return r
end
local function dentroDoMapa(ponto: any, soOpacas: boolean?): any
	for _, b in perto(ponto - V(0.01, 0.01, 0.01), ponto + V(0.01, 0.01, 0.01)) do
		if (not soOpacas or b.visivel) and dentroCaixa(b, ponto) then
			return b
		end
	end
	return nil
end
print(string.format("[Cenario] mapa: %d peças", #pecasMapa))

-- 1) peças novas x mapa, com as portas FECHADAS (pior caso dentro do vão)
mundo:definir("porta_oficina", "trancada", true)
local minhas = {}
for _, d in pasta:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.99 then
		table.insert(minhas, caixa(d))
	end
end
local conflitos = 0
for _, A in minhas do
	for _, B in perto(A.min, A.max) do
		if B.visivel or B.solida then
			local p = penetracao(A, B)
			if p > 0.03 then
				conflitos += 1
				if conflitos <= 40 then
					falha(string.format("%s atravessa %s (%.2f studs)", A.parte:GetFullName(), B.parte:GetFullName(), p))
				end
			end
		end
	end
end
if conflitos == 0 then
	pass(string.format("sem_colisao_com_o_mapa (%d peças novas)", #minhas))
end

-- 2) portas abertas: as folhas ficam escondidas dentro da parede
mundo:definir("porta_oficina", "aberta", true)
local portaOficina = pasta:FindFirstChild("PortaOficina")
for _, nome in { "FolhaNorte", "FolhaSul" } do
	local f = caixa(portaOficina:FindFirstChild(nome))
	local escondida = true
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local canto = f.cf:PointToWorldSpace(V(sx * (f.h[1] - 0.02), sy * (f.h[2] - 0.02), sz * (f.h[3] - 0.02)))
				if not dentroDoMapa(canto, true) then
					escondida = false
					falha(string.format("folha %s aberta aparece fora da parede no canto %s", nome, tostring(canto)))
				end
			end
		end
	end
	if escondida then
		pass("folha_" .. nome .. "_some_na_parede")
	end
end

-- 3) apoio: peças de parede encostam numa parede; móveis de chão têm chão
local P = Cenario.POS
local apoios = {
	{ "relogio", P.relogio * CF(0, 4.0, 0.05) },
	{ "painel_entrada", P.painelEntrada * CF(0, 6.0, 0.05) },
	{ "terminal_enfermaria", P.terminalEnfermaria * CF(0, 3.5, 0.05) },
	{ "placa_contencao", P.placaContencao * CF(0, 3.9, 0.05) },
	{ "trava_oficina", P.travaOficina * CF(0, 3.8, 0.05) },
	{ "trava_externa", P.caixaTravaExterna * CF(0, 4.0, 0.05) },
	{ "carregador_parede", P.carregador * CF(0, 1.5, 0.25) },
	{ "carregador_chao", P.carregador * CF(0, -0.05, -0.8) },
	{ "terminal_oficina_parede", P.terminalOficina * CF(0, 1.5, 0.25) },
	{ "terminal_oficina_chao", P.terminalOficina * CF(0, -0.05, -1.2) },
	{ "caixa_chao", P.caixa * CF(0, -0.05, 0) },
	{ "lampada_contencao", CF(-65.05, 8.9, -320) },
	{ "lampada_oficina", CF(65.05, 8.9, -320) },
}
for i, pose in P.giroflex do
	table.insert(apoios, { "giroflex" .. i, pose * CF(0, 4.3, 0.05) })
end
local apoiosOk = true
for _, a in apoios do
	if not dentroDoMapa(a[2].Position) then
		apoiosOk = false
		falha("sem apoio: " .. a[1] .. " em " .. tostring(a[2].Position))
	end
end
if apoiosOk then
	pass(string.format("apoio_em_parede_e_chao (%d pontos)", #apoios))
end

-- cápsula de um R6 em pé (raiz a 3 studs do chão): livre de peças sólidas do mapa e das novas
local solidasNovas = {}
local function recolherSolidas()
	table.clear(solidasNovas)
	for _, d in pasta:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			table.insert(solidasNovas, caixa(d))
		end
	end
end
local function livre(pos: any, raio: number): (boolean, string?)
	local base = V(pos.X, 0, pos.Z)
	for _, h in { 0.6, 2.2, 3.8, 4.8 } do
		for _, off in { V(0, 0, 0), V(raio, 0, 0), V(-raio, 0, 0), V(0, 0, raio), V(0, 0, -raio) } do
			local p = base + off + V(0, h, 0)
			for _, b in perto(p - V(0.01, 0.01, 0.01), p + V(0.01, 0.01, 0.01)) do
				if b.solida and dentroCaixa(b, p) then
					return false, b.parte:GetFullName()
				end
			end
			for _, b in solidasNovas do
				if dentroCaixa(b, p) then
					return false, b.parte:GetFullName()
				end
			end
		end
	end
	return true, nil
end
local function temChao(pos: any): boolean
	local p = V(pos.X, -0.05, pos.Z)
	local b = dentroDoMapa(p)
	return b ~= nil and b.solida
end

-- 4) cada interação tem onde ficar em pé, dentro do alcance do prompt (7)
mundo:definir("porta_oficina", "travada", true)
recolherSolidas()
local emPe = {
	pegar_radio = V(4.5, 3, 3.6),
	pegar_bateria = V(-88, 3, -201.6),
	encaixar_bateria = V(-62.2, 3, -306),
	fechar_trava = V(67.6, 3, -305),
	ler_terminal = V(87.7, 3, -302.3),
}
for _, def in cena.interacoes do
	local pe = emPe[def.nome]
	if pe then
		local ok, quem = livre(pe, 0.9)
		local alvo = def.posicao()
		local d = (alvo - pe).Magnitude
		if not ok then
			falha(def.nome .. ": lugar de ficar em pé ocupado por " .. tostring(quem))
		elseif not temChao(pe) then
			falha(def.nome .. ": sem chão em " .. tostring(pe))
		elseif d > 6.5 then
			falha(string.format("%s: prompt a %.1f studs do lugar em pé", def.nome, d))
		else
			pass(string.format("alcance_%s (%.1f studs)", def.nome, d))
		end
	end
end

-- 5) zonas e ponto de renascer em chão livre
for nome, z in cena.zonas do
	local ok, quem = livre(z.centro, 0.9)
	if not ok or not temChao(z.centro) then
		falha("zona " .. nome .. " em lugar bloqueado/sem chão: " .. tostring(quem))
	else
		pass("zona_" .. nome)
	end
end
local spawn = cena.spawns.oficina_segura.Position
if livre(spawn, 3.2) and temChao(spawn) then
	pass("renascer_na_oficina_livre")
else
	falha("ponto de renascer da oficina bloqueado")
end

-- 6) rota do Pavel: cápsula de 0.9 de raio a cada meio stud, com a porta como estará na hora
local trechos = {
	{ "tunel", "arsenal", "aberta" },
	{ "arsenal", "enfermaria", "aberta" },
	{ "enfermaria", "porta_oficina", "trancada" },
	{ "porta_oficina", "oficina", "aberta" },
}
local rotaOk = true
for _, t in trechos do
	mundo:definir("porta_oficina", t[3], true)
	recolherSolidas()
	local pontos = { PavelRotas.LUGARES[t[1]].pos }
	for _, p in PavelRotas.ROTAS[t[1] .. ">" .. t[2]] do
		table.insert(pontos, p)
	end
	table.insert(pontos, PavelRotas.LUGARES[t[2]].pos)
	for i = 1, #pontos - 1 do
		local a, b = pontos[i], pontos[i + 1]
		local passos = math.max(1, math.ceil((b - a).Magnitude / 0.5))
		for k = 0, passos do
			local p = a:Lerp(b, k / passos)
			local ok, quem = livre(p, 0.9)
			if not ok then
				rotaOk = false
				falha(string.format("rota %s>%s bate em %s perto de %s", t[1], t[2], tostring(quem), tostring(p)))
				break
			end
			if not temChao(p) then
				rotaOk = false
				falha(string.format("rota %s>%s sem chão em %s", t[1], t[2], tostring(p)))
				break
			end
		end
	end
end
if rotaOk then
	pass("rota_do_pavel_livre")
end
for nome, l in PavelRotas.LUGARES do
	if not livre(l.pos, 1.0) or not temChao(l.pos) then
		falha("lugar do Pavel bloqueado: " .. nome)
	end
end

-- 7) o mapa não mudou e só uma pasta nova apareceu no Workspace
if digital() == antes then
	pass("mapa_identico")
else
	falha("o Sector7World mudou")
end
if #workspace:GetChildren() == filhosAntes + 1 then
	pass("so_uma_pasta_nova_no_workspace")
else
	falha("o cenário criou coisas fora da pasta BastiaoHistoria")
end

-- exporta as peças (mapa perto dos pontos + novas) para a prévia 3D
local saida = process.args[2]
if saida then
	local function linhaParte(b: any, origem: string)
		local p = b.parte
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
		local cor = p.Color
		local forma = if p:IsA("Part") then tostring(p.Shape):gsub("Enum.PartType.", "") else "Block"
		local temLuz = 0
		for _, f in p:GetChildren() do
			if f:IsA("PointLight") or f:IsA("SpotLight") then
				if f.Enabled then
					temLuz = 1
				end
			end
		end
		return string.format(
			'{"o":"%s","n":"%s","f":"%s","m":"%s","t":%.2f,"c":[%d,%d,%d],"s":[%.3f,%.3f,%.3f],"cf":[%.3f,%.3f,%.3f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f],"l":%d}',
			origem,
			p.Name,
			forma,
			tostring(p.Material):gsub("Enum.Material.", ""),
			p.Transparency,
			math.floor(cor.R * 255),
			math.floor(cor.G * 255),
			math.floor(cor.B * 255),
			p.Size.X,
			p.Size.Y,
			p.Size.Z,
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
			temLuz
		)
	end
	mundo:definir("porta_oficina", "aberta", true)
	mundo:definir("alarme", "ligado", true)
	mundo:definir("bateria", "disponivel", true)
	mundo:definir("radio", "oferecido", true)
	local linhas = {}
	local regioes = {
		{ V(-12, -1, -30), V(12, 14, 26) },
		{ V(-114, -1, -246), V(-48, 14, -194) },
		{ V(-70, -1, -345), V(-44, 14, -290) },
		{ V(44, -1, -345), V(114, 14, -294) },
	}
	local usados = {}
	for _, r in regioes do
		for _, b in perto(r[1], r[2]) do
			if not usados[b] and b.visivel then
				usados[b] = true
				table.insert(linhas, linhaParte(b, "mapa"))
			end
		end
	end
	for _, d in pasta:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			table.insert(linhas, linhaParte(caixa(d), "novo"))
		end
	end
	fs.writeFile(saida, "[\n" .. table.concat(linhas, ",\n") .. "\n]\n")
	print(string.format("[Cenario] prévia: %d peças exportadas para %s", #linhas, saida))
end

if #falhas > 0 then
	print(string.format("[Cenario] %d falha(s)", #falhas))
	process.exit(1)
end
print("[Cenario] TUDO OK")
