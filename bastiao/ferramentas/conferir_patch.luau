-- PROJETO BASTIÃO :: confere um place depois do patch do instalador, com um leitor independente
-- Uso: lune run bastiao/ferramentas/conferir_patch.luau <original.rbxl> <patcheado.rbxl> <sources.json>
--   * toda instância do original continua lá, com a mesma classe e as mesmas propriedades
--     (mapa, HUD, scripts Sector7, personagem, iluminação);
--   * os scripts do pacote existem uma vez só, na classe certa e com a fonte exata;
--   * nada além dos scripts do pacote foi acrescentado.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local original = roblox.deserializePlace(fs.readFile(process.args[1]))
local patcheado = roblox.deserializePlace(fs.readFile(process.args[2]))
local fontes = serde.decode("json", fs.readFile(process.args[3]))

local falhas = 0
local function falha(m: string)
	falhas += 1
	if falhas <= 30 then
		print("[Patch] FALHA " .. m)
	end
end

local function caminho(i: any): string
	local partes = {}
	local at = i
	while at and at.Parent do
		table.insert(partes, 1, at.Name)
		at = at.Parent
	end
	return table.concat(partes, "/")
end

local PROPS = {
	BasePart = { "CFrame", "Size", "Color", "Transparency", "CanCollide", "Anchored", "Material", "Reflectance" },
	Light = { "Enabled", "Color", "Brightness", "Range" },
	LuaSourceContainer = { "Source" },
	Decal = { "Texture", "Transparency" },
	Humanoid = { "WalkSpeed", "JumpPower", "HipHeight" },
	BodyColors = { "TorsoColor3", "HeadColor3", "LeftLegColor3" },
	GuiObject = { "Visible", "Position", "Size" },
}
local function assinatura(i: any): string
	local s = i.ClassName
	for classe, lista in PROPS do
		if i:IsA(classe) then
			for _, p in lista do
				local ok, v = pcall(function()
					return i[p]
				end)
				s ..= "|" .. p .. "=" .. (if ok then tostring(v) else "?")
			end
		end
	end
	local attrs = {}
	for k, v in i:GetAttributes() do
		table.insert(attrs, k .. "=" .. tostring(v))
	end
	table.sort(attrs)
	return s .. "|" .. table.concat(attrs, ",")
end

-- conta por caminho (nomes repetidos existem no mapa: compara multiconjuntos)
local function inventario(dm: any): { [string]: { [string]: number } }
	local r = {}
	for _, i in dm:GetDescendants() do
		local c = caminho(i)
		r[c] = r[c] or {}
		local a = assinatura(i)
		r[c][a] = (r[c][a] or 0) + 1
	end
	return r
end
local antes = inventario(original)
local depois = inventario(patcheado)

local novos = {}
for _, row in fontes do
	novos[table.concat(row.path, "/")] = row
end

local total = 0
for c, assinaturas in antes do
	for a, n in assinaturas do
		total += n
		local m = depois[c] and depois[c][a] or 0
		if m ~= n then
			falha(string.format("instância original mudou ou sumiu: %s (%d -> %d)", c, n, m))
		end
	end
end
print(string.format("[Patch] %d instâncias originais conferidas", total))

local acrescentadas = 0
for c, assinaturas in depois do
	for a, n in assinaturas do
		local m = antes[c] and antes[c][a] or 0
		if n > m then
			acrescentadas += n - m
			if not novos[c] then
				falha("instância acrescentada fora do pacote: " .. c .. " (" .. a:sub(1, 60) .. ")")
			end
		end
	end
end

for c, row in novos do
	local partes = row.path
	local at = patcheado
	for _, nome in partes do
		local achados = {}
		for _, filho in at:GetChildren() do
			if filho.Name == nome then
				table.insert(achados, filho)
			end
		end
		if #achados ~= 1 then
			at = nil
			break
		end
		at = achados[1]
	end
	if not at then
		falha("script do pacote ausente ou duplicado: " .. c)
	elseif at.ClassName ~= row.cls then
		falha("classe errada em " .. c .. ": " .. at.ClassName)
	elseif at.Source ~= row.source then
		falha("fonte diferente em " .. c)
	end
end
if acrescentadas ~= #fontes then
	falha(string.format("acrescentou %d instâncias, o pacote tem %d scripts", acrescentadas, #fontes))
end

if falhas > 0 then
	print(string.format("[Patch] %d falha(s)", falhas))
	process.exit(1)
end
print(string.format("[Patch] OK: %d scripts novos, nenhuma instância original alterada", #fontes))
