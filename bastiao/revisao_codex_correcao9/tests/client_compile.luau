local fs = require("@lune/fs")
local luau = require("@lune/luau")
for _, name in { "BastiaoCliente", "Som", "Interface", "Foley" } do
	local ok, reason = pcall(luau.compile, fs.readFile("src/client/" .. name .. ".luau"))
	assert(ok, name .. ": " .. tostring(reason))
end
print("PASS all four merged client sources compile with Lune 0.11.1 (no engine)")
