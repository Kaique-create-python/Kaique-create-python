-- Auditoria de uma versão do lugar (ex.: a V1 salva como versão 4).
-- Enviado pela Luau Execution API: lista serviços, contagem de classes e
-- scripts (nome, caminho, tamanho do código quando a leitura é permitida).
-- Serve para documentar o que existe na nuvem antes de substituir.

local SERVICES = { "Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService", "Teams" }

local out = { servicos = {}, classes = {}, scripts = {}, totalPecas = 0 }
local seen = 0

for _, name in SERVICES do
	local ok, svc = pcall(function()
		return game:GetService(name)
	end)
	if ok and svc then
		local list = svc:GetDescendants()
		out.servicos[name] = #list
		for _, d in list do
			seen += 1
			out.classes[d.ClassName] = (out.classes[d.ClassName] or 0) + 1
			if d:IsA("BasePart") then
				out.totalPecas += 1
			end
			if d:IsA("LuaSourceContainer") and #out.scripts < 60 then
				local info = { caminho = d:GetFullName(), classe = d.ClassName }
				local okSrc, src = pcall(function()
					return (d :: any).Source
				end)
				if okSrc and type(src) == "string" then
					info.bytes = #src
					info.inicio = string.sub(src, 1, 120)
				else
					info.bytes = "leitura não permitida"
				end
				table.insert(out.scripts, info)
			end
		end
	end
end
out.totalInstancias = seen
out.streaming = workspace.StreamingEnabled
print(string.format("[auditoria] %d instâncias, %d peças, %d scripts", seen, out.totalPecas, #out.scripts))
return out
