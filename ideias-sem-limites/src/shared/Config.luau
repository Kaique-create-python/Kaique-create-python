--!strict
-- Configuração central do "Ideias Sem Limites" (V3).
-- Todos os limites de desempenho e segurança ficam aqui para facilitar ajustes.

local Config = {}

Config.Version = "3.0.0"
Config.WorldSeed = 20261109

-- Pedidos dos jogadores ------------------------------------------------------
Config.Request = {
	Cooldown = 3.0, -- segundos entre ideias do mesmo jogador
	MaxTextLength = 60, -- caracteres aceitos depois da limpeza
	MaxRawLength = 200, -- acima disso o pedido é descartado sem processar
	MaxTokens = 12, -- palavras analisadas por pedido
	MaxGroups = 3, -- ideias combinadas em um único pedido
	SpamWindow = 10, -- janela (s) para detectar spam de RemoteEvent
	SpamMaxRequests = 7, -- pedidos permitidos na janela antes do bloqueio
	SpamMute = 15, -- bloqueio temporário (s) após spam
	GlobalWindow = 2, -- janela (s) do limite global do servidor
	GlobalMaxRequests = 10, -- ideias executadas por janela no servidor inteiro
}

-- Orçamento do mundo ---------------------------------------------------------
Config.Budget = {
	events = 12, -- acontecimentos simultâneos
	npcs = 28, -- NPCs vivos ao mesmo tempo
	dynamic = 240, -- partes físicas soltas (meteoros, objetos caindo, destroços)
	effects = 80, -- emissores de partículas, luzes e feixes
	parts = 3200, -- partes estáticas criadas por acontecimentos
	perPlayer = 3, -- acontecimentos ativos por jogador
	recycleMinAge = 8, -- idade mínima (s) para reciclar o acontecimento mais antigo
}

Config.Limits = {
	NpcPerEvent = 12,
	MaxScale = 6,
	MinScale = 0.25,
	DefaultLifetime = 60,
	MaxLifetime = 150,
	SpawnDistance = 18, -- distância à frente do jogador
}

Config.Combat = {
	PvP = false, -- jogadores não causam dano entre si
	PlayerDamageScale = 1.0,
	NpcThinkInterval = 0.3,
	PathRecomputeInterval = 1.6,
	TargetRange = 120,
}

Config.World = {
	DayLengthMinutes = 18, -- duração de um ciclo dia/noite completo
	RestoreDelay = 28, -- tempo até partes destruídas do mapa voltarem
	AmbientEventInterval = 75, -- acontecimentos ambientais aleatórios
}

Config.Data = {
	StoreName = "IdeiasPerfil_v3",
	AutosaveInterval = 120,
	MaxFavorites = 20,
	MaxHistory = 15,
}

-- Sons: arquivos embutidos no cliente Roblox (rbxasset://). Podem ser trocados por
-- IDs da Loja de Criadores (rbxassetid://...) sem mexer no resto do código.
Config.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	Create = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/button.wav",
	Whoosh = "rbxasset://sounds/swoosh.wav",
	Impact = "rbxasset://sounds/collide.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Rocket = "rbxasset://sounds/Rocket shot.wav",
	Ghost = "rbxasset://sounds/HalloweenGhost.wav",
	Glass = "rbxasset://sounds/glassbreak.wav",
	Splat = "rbxasset://sounds/splat.wav",
	Hit = "rbxasset://sounds/hit.wav",
	Snap = "rbxasset://sounds/snap.wav",
}

Config.Textures = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}

return Config
