--!nocheck
-- Exporta a base de reflexão do Roblox (embutida no Lune/rbx-dom) para JSON.
-- Uso: lune run tools/dev/exportar_reflexao.luau > reflexao.json
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local db = roblox.getReflectionDatabase()
local out = { version = db.Version, classes = {}, enums = {} }
for _, name in db:GetClassNames() do
	local c = db:GetClass(name)
	local props = {}
	for pname, p in c.Properties do
		props[pname] = p.Datatype
	end
	out.classes[name] = { super = c.Superclass, tags = c.Tags, props = props }
end
for _, name in db:GetEnumNames() do
	local e = db:GetEnum(name)
	local items = {}
	for k, v in e.Items do
		items[k] = v
	end
	out.enums[name] = items
end
print(serde.encode("json", out))
