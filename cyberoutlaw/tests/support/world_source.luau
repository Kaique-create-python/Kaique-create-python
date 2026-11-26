-- Expand the same world fragments that install/cyber_installer.py uses.
local fs = require("@lune/fs")

local modules = {
    {"Context", "context"},
    {"Layout", "layout"},
    {"Streets", "streets"},
    {"Transit", "transit"},
    {"PublicSpace", "public_space"},
    {"Buildings", "buildings"},
    {"Commerce", "commerce"},
}

return function(art)
    local source = fs.readFile("src/world.server.luau")
    local fragments = {"local Mare = {}"}
    for _, module in modules do
        local code = fs.readFile("src/mare-baixa/" .. module[2] .. ".luau")
        table.insert(fragments, "Mare." .. module[1] .. " = (function()\n" .. code .. "\nend)()")
    end
    local count
    source, count = source:gsub("%-%- __CYBEROUTLAW_MARE_MODULES__", function()
        return table.concat(fragments, "\n")
    end)
    assert(count == 1, "o gerador precisa de um marcador de módulos")
    return (source:gsub("__CYBEROUTLAW_ART__", function() return art or "{}" end))
end
