-- OI3 :: confere as texturas realistas no aparelho do jogador (AJUSTE-5).
-- Se algum mapa de um material não carregar (moderação, permissão ou internet), aquele material
-- volta para o visual normal do Roblox, em vez de aparecer cinza ou branco.

local ContentProvider = game:GetService("ContentProvider")
local MaterialService = game:GetService("MaterialService")

local OI3 = script.Parent.Parent
local Recursos = require(OI3.Recursos)

local Texturas = {}

function Texturas.verificar()
	local lista = Recursos.texturas
	if type(lista) ~= "table" then
		return
	end
	task.spawn(function()
		for material, mapas in lista do
			local ids = {}
			for _, id in mapas do
				table.insert(ids, "rbxassetid://" .. tostring(id))
			end
			local falhou = false
			local ok = pcall(function()
				ContentProvider:PreloadAsync(ids, function(_, status)
					if status ~= Enum.AssetFetchStatus.Success then
						falhou = true
					end
				end)
			end)
			if falhou or not ok then
				local mv = MaterialService:FindFirstChild(material)
				if mv then
					mv.Name = material .. "_SemTextura"
				end
				warn("[OI3] a textura '" .. material .. "' não carregou; usando o material normal do Roblox.")
			end
		end
	end)
end

return Texturas
