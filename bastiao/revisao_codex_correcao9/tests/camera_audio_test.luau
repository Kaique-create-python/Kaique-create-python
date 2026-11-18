local Harness = require("./client_harness")
local h = Harness.new({autoLoad=true,preload=true})
local Som = h:load("src/client/Som.luau")
-- IDs here are test fixtures; production always requires a real catalog binding.
local api = Som.iniciar({ audio={ids={impacto_test=123},sfx={impacto_zumbido={0,5.6,"impacto_test"}}},
	textos={}, idioma=function() return "pt" end, alarme=function() return false end,
	acessoBloqueado=function() return false end, passosExternos=true })
local ring = api.efeito("impacto_zumbido")
assert(ring and ring.IsPlaying and ring.SoundGroup.Name == "BastiaoOuvido")
assert(ring.SoundGroup ~= api.grupoEfeitos and ring.Volume == .2 and not ring.Looped)
assert(ring.PlaybackRegion.Min == 0 and math.abs(ring.PlaybackRegion.Max - 5.6) < 1e-5)
api.parar()
assert(ring.Parent == nil and h.soundService:FindFirstChild("BastiaoOuvido") == nil)
local silent = Som.iniciar({audio={ids={},sfx={impacto_zumbido={0,5.6,"not_uploaded"}}}, textos={},
	idioma=function() return "pt" end, alarme=function() return false end, acessoBloqueado=function() return false end})
assert(silent.efeito("impacto_zumbido") == nil, "unbound audio must remain silent")
silent.parar()
print("PASS catalog-bound tinnitus routing, bounded region, cleanup and missing-ID silence")
