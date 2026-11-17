local Harness = require("./client_harness")
local h = Harness.new()
h.services.ReplicatedStorage = h:new("ReplicatedStorage")
h.services.Lighting = h:new("Lighting")
local Efeitos = h:load("src/client/Efeitos.luau")
assert(type(Efeitos.amostraImpacto) == "function", "pure impact envelope missing")
local sample = Efeitos.amostraImpacto
assert(sample(1, 0).intensidade == 0)
assert(sample(1, .045).intensidade == 1)
assert(sample(.5, .045).duracao == 3.75)
assert(sample(1, .65).pitch == 0 and sample(1, .65).roll == 0, "kick must settle early")
local prior = 1
for i = 1, 550 do
	local s = sample(1, .045 + i / 100)
	assert(s.intensidade >= 0 and s.intensidade <= prior + 1e-9, "recovery must be monotonic")
	assert(math.abs(s.pitch) <= math.rad(2.8) and math.abs(s.roll) <= math.rad(1.8))
	prior = s.intensidade
end
assert(sample(1, 5.5).intensidade == 0)
assert(sample(0 / 0, 1).intensidade == 0)
assert(sample(1, math.huge).intensidade == 0)
assert(sample(1, .001, .8).intensidade >= .8, "retrigger must retain current intensity")
print("PASS pure bounded impact envelope, early kick, monotonic recovery and finite inputs")
