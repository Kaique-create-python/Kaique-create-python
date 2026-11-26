-- North at negative Z. Block names are stable between builds.
local layout = {
    pitch = 240,
    columns = 10,
    rows = 8,
    halfX = 1200,
    halfZ = 960,
    roadY = -0.266,
    walkY = 0.04,
    canalWidth = 52,
    bank = 42,
    sidewalkWidth = 12.8,
    bridgeRows = { [-960] = "road", [-720] = "road", [-480] = "foot", [-240] = "road", [0] = "road",
                    [240] = "foot", [480] = "road", [720] = "foot", [960] = "road" },
    footWidth = 14,
    spawnX = -115,
    spawnZ = -83,
    stationX = 125,
    stationZ = -4.6,
    deck = 27,
    turnaround = 1170,
}
--   Oeste                                                           Canal     Leste
local blocks = {
    {"apartments", "towers",     "apartments", "mixed",     "levee",   "park",     "hotel",   "towers",     "mixed",      "warehouse"},
    {"apartments", "mixed",      "towers",     "mixed",     "park",    "finance",  "tech",    "towers",     "apartments", "grid"},
    {"towers",     "apartments", "mixed",      "arcade",    "levee",   "tech",     "vertice", "finance",    "hotel",      "towers"},
    {"apartments", "mixed",      "arcade",     "sodio",     "spawn",   "station",  "hotel",   "finance",    "tech",       "mixed"},
    {"warehouse",  "towers",     "arcade",     "mixed",     "park",    "arcade",   "tech",    "mixed",      "apartments", "grid"},
    {"warehouse",  "grid",       "apartments", "mixed",     "levee",   "mixed",    "park",    "towers",     "apartments", "warehouse"},
    {"warehouse",  "docks",      "warehouse",  "apartments","park",    "mixed",    "towers",  "apartments", "grid",       "warehouse"},
    {"grid",       "warehouse",  "warehouse",  "towers",    "levee",   "park",     "mixed",   "warehouse",  "apartments", "grid"},
}
layout.blocks = blocks

function layout.cell(column, row)
    return -layout.halfX + (column - 0.5) * layout.pitch, -layout.halfZ + (row - 0.5) * layout.pitch
end

function layout.avenueWidth(z)
    if z == 0 then
        return 50
    elseif z == -480 or z == 480 then
        return 44
    else
        return 34
    end
end

function layout.streetWidth(x)
    return if math.abs(x) == 720 then 44 else 34
end

return layout
