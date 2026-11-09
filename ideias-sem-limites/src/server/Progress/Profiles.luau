--!strict
-- Perfis persistentes (DataStore) com tolerância a falhas: se o DataStore não
-- estiver disponível (Studio sem permissão, Luau Execution, falha de rede),
-- o jogo continua com um perfil só da sessão.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.IdeiasShared.Config)

local Profiles = {}

export type Profile = {
	v: number,
	discovered: { [string]: boolean },
	secrets: { [string]: boolean },
	achievements: { [string]: boolean },
	stats: { [string]: number },
	favorites: { string },
	sparks: number,
	owned: { [string]: boolean },
	equipped: { [string]: string },
	regions: { [string]: boolean },
}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
Profiles.enabled = false

local function blank(): Profile
	return {
		v = 1,
		discovered = {},
		secrets = {},
		achievements = {},
		stats = {},
		favorites = {},
		sparks = 0,
		owned = {},
		equipped = {},
		regions = {},
	}
end

local function sanitize(data: any): Profile
	local p = blank()
	if type(data) ~= "table" then
		return p
	end
	for _, key in { "discovered", "secrets", "achievements", "owned", "regions" } do
		if type(data[key]) == "table" then
			for k, v in data[key] do
				if type(k) == "string" and v == true then
					(p :: any)[key][k] = true
				end
			end
		end
	end
	if type(data.stats) == "table" then
		for k, v in data.stats do
			if type(k) == "string" and type(v) == "number" then
				p.stats[k] = v
			end
		end
	end
	if type(data.favorites) == "table" then
		for _, f in data.favorites do
			if type(f) == "string" and #p.favorites < Config.Data.MaxFavorites then
				table.insert(p.favorites, string.sub(f, 1, 80))
			end
		end
	end
	if type(data.equipped) == "table" then
		for k, v in data.equipped do
			if type(k) == "string" and type(v) == "string" then
				p.equipped[k] = v
			end
		end
	end
	p.sparks = if type(data.sparks) == "number" then math.max(0, math.floor(data.sparks)) else 0
	return p
end

function Profiles.init()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok and ds then
		store = ds
		Profiles.enabled = true
	else
		warn("[Ideias] DataStore indisponível; progresso só nesta sessão.")
	end
end

function Profiles.load(player: Player): Profile
	local profile = blank()
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync("u" .. player.UserId)
		end)
		if ok then
			profile = sanitize(data)
		else
			warn("[Ideias] falha ao carregar perfil: " .. tostring(data))
		end
	end
	profiles[player] = profile
	return profile
end

function Profiles.get(player: Player): Profile?
	return profiles[player]
end

function Profiles.markDirty(player: Player)
	dirty[player] = true
end

function Profiles.save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	dirty[player] = nil
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync("u" .. player.UserId, function()
				return profile
			end)
		end)
		if ok then
			return
		end
		warn(string.format("[Ideias] falha ao salvar (%d/3): %s", attempt, tostring(err)))
		task.wait(attempt * 2)
	end
end

function Profiles.release(player: Player)
	Profiles.save(player)
	profiles[player] = nil
	dirty[player] = nil
end

function Profiles.start()
	Profiles.init()
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player in dirty do
				if player.Parent then
					task.spawn(Profiles.save, player)
				end
			end
		end
	end)
	game:BindToClose(function()
		for player in profiles do
			Profiles.save(player)
		end
	end)
	Players.PlayerRemoving:Connect(Profiles.release)
end

return Profiles
