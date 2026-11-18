local fs = require("@lune/fs")
local luau = require("@lune/luau")

local source = fs.readFile("src/teste_nuvem.luau")
assert(#source < 200000, "native source exceeds its package budget")
local header = 'local cfg = { package = "BASTIAO-ETAPA-3", stage = 3, universe = 10776462844, place = 89520940302906, hashes = {} }\n'
local ok, err = pcall(luau.compile, header .. source)
assert(ok, tostring(err))
print("PASS native Saved-cloud script compiles with Lune 0.11.1; Roblox engine not executed")
