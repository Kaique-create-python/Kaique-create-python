local fs = require("@lune/fs")
local luau = require("@lune/luau")
for _, name in {"Criatura", "CriaturaCore", "Pavel", "BastiaoServidor"} do
	local ok, reason = pcall(luau.compile, fs.readFile("src/server/" .. name .. ".luau"))
	assert(ok, name .. ": " .. tostring(reason))
end
print("PASS 4 server sources compile in Lune 0.11.1; no Roblox engine execution")
