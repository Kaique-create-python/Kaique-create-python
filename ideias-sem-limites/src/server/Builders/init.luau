--!strict
-- Registro de construtores procedurais por "model" do catálogo.
-- Para adicionar uma nova família de modelos: crie o construtor e registre aqui.

local Figures = require(script.Figures)
local Beasts = require(script.Beasts)
local Monsters = require(script.Monsters)
local Vehicles = require(script.Vehicles)
local Buildings = require(script.Buildings)
local Props = require(script.Props)
local Memes = require(script.Memes)
local Fusion = require(script.Fusion)

local Builders = {}

Builders.Kit = require(script.Kit)
Builders.Rig = require(script.Rig)
Builders.Props = Props
Builders.Buildings = Buildings
Builders.Vehicles = Vehicles
Builders.Figures = Figures

local CREATURES: { [string]: (CFrame, { [string]: any }, string) -> any } = {
	figure = Figures.build,
	quadruped = Beasts.quadruped,
	theropod = Beasts.theropod,
	bird = Beasts.bird,
	fish = Beasts.fish,
	octopus = Beasts.octopus,
	serpent = Beasts.serpent,
	bug = Beasts.bug,
	slime = Beasts.slime,
	dragon = Monsters.dragon,
	ghost = Monsters.ghost,
	robot = Monsters.robot,
	ufo = Monsters.ufo,
	meme = Memes.build,
}

Builders.Creatures = CREATURES

local function plainCreature(origin: CFrame, params: { [string]: any }): any
	local f = CREATURES[params.model] or Figures.build
	return f(origin, params, params.variant or "villager")
end

Builders.Fusion = Fusion

function Builders.creature(origin: CFrame, params: { [string]: any }): any
	local rig = plainCreature(origin, params)
	local fh = params.fusionHead
	if fh then
		local ok, err = pcall(Fusion.ontoRig, rig, fh, params, { creature = plainCreature, prop = Builders.prop })
		if not ok then
			warn("[Ideias] híbrido falhou: " .. tostring(err))
		end
	end
	return rig
end

function Builders.vehicle(origin: CFrame, params: { [string]: any }): any
	local v = Vehicles.build(origin, params, params.variant or "car")
	local fh = params.fusionHead
	if fh and v and v.model then
		local ok, err = pcall(Fusion.ontoVehicle, v.model, fh, params, { creature = plainCreature, prop = Builders.prop })
		if not ok then
			warn("[Ideias] híbrido de veículo falhou: " .. tostring(err))
		end
	end
	return v
end

function Builders.building(origin: CFrame, params: { [string]: any }): any
	return Buildings.build(origin, params, params.variant or "house")
end

function Builders.prop(origin: CFrame, params: { [string]: any }): any
	return Props.build(origin, params, params.model or "prop", params.variant or "crate")
end

-- constrói qualquer conceito "físico" (usado pela chuva de objetos e testes)
function Builders.any(def: any, origin: CFrame, params: { [string]: any }): (Model?, number)
	local h = def.handler
	if h == "npc" then
		local rig = Builders.creature(origin, params)
		return rig.model, rig.height
	elseif h == "vehicle" then
		local v = Builders.vehicle(origin, params)
		return v.model, v.height
	elseif h == "building" then
		local r = Builders.building(origin, params)
		return r.model, r.height
	elseif h == "prop" then
		local r = Builders.prop(origin, params)
		return r.model, r.height
	end
	return nil, 0
end

return Builders
