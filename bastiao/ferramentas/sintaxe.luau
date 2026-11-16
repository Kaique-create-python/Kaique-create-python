-- PROJETO BASTIÃO :: compila todo .luau de bastiao/src (erro de sintaxe derruba o teste)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local raiz = if fs.isDir("bastiao/src") then "bastiao/src" else "src"
local total, falhas = 0, 0
local function varrer(caminho: string)
	for _, nome in fs.readDir(caminho) do
		local c = caminho .. "/" .. nome
		if fs.isDir(c) then
			varrer(c)
		elseif string.sub(nome, -5) == ".luau" then
			total += 1
			local ok, err = pcall(luau.compile, fs.readFile(c))
			if not ok then
				falhas += 1
				print("[Sintaxe] FALHA " .. c .. ": " .. tostring(err))
			end
		end
	end
end
varrer(raiz)
print(string.format("[Sintaxe] %d arquivos, %d com erro", total, falhas))
if falhas > 0 then
	process.exit(1)
end
