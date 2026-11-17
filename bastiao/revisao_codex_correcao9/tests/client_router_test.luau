-- Executes the real latest chapter router at its Roblox/module boundaries.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local calls = {}
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local c = { Connected = true }
			function c:Disconnect() self.Connected = false end
			table.insert(listeners, { fn, c })
			return c
		end,
		Fire = function(_, ...) for _, item in listeners do if item[2].Connected then item[1](...) end end end,
	}
end
local function mark(name, ...) table.insert(calls, { name, ... }) end
local function count(name, value)
	local n = 0
	for _, call in calls do if call[1] == name and (value == nil or call[2] == value) then n += 1 end end
	return n
end
local lang, languageListeners = "en", {}
local language = {
	atual = function() return lang end,
	aoMudar = function(fn) table.insert(languageListeners, fn) end,
}
local attributes, attributeSignals = {}, {}
local shared = {}
function shared:GetAttribute(name) return attributes[name] end
function shared:GetAttributeChangedSignal(name)
	attributeSignals[name] = attributeSignals[name] or signal()
	return attributeSignals[name]
end
function shared:WaitForChild(name) return name end
function shared:FindFirstChild(name) return if name == "AudioCatalog" then name else nil end
local presentation = { OnClientEvent = signal(), IsA = function(_, kind) return kind == "RemoteEvent" end }
local remoteLanguage = { IsA = presentation.IsA }
local remotes = { WaitForChild = function(_, name) return if name == "language" then remoteLanguage else presentation end }
local playerGui = {}
local player = { WaitForChild = function() return playerGui end }
local promptService = { PromptTriggered = signal() }
local storage = { WaitForChild = function(_, name) return if name == "BastiaoCompartilhado" then shared else remotes end }
local scriptNode = { Destroying = signal(), WaitForChild = function(_, name) return name end }
local texts, legacy, catalog = {}, { ids = {}, vozes = {}, sfx = {}, loops = {} }, { version = 1, assets = {} }
local settings = {
	ATR_OBJETIVO = "objective", ATR_ALARME = "alarm", ATR_ACESSO = "access", ATR_FIM = "end", ATR_IDIOMA = "locale",
	PASTA_REMOTOS = "BastiaoRemotos", REMOTO_APRESENTACAO = "presentation", REMOTO_IDIOMA = "language",
}
local ui = {}
for _, name in { "objetivo", "alarme", "fim", "fala", "aviso", "corte", "som", "idioma", "definirSom" } do
	ui[name] = function(...) mark("caption_" .. name, ...); mark("caption_locale", lang) end
end
local sound = { grupoEfeitos = {} }
for _, name in { "fala", "som", "ruido", "estado", "precarregar", "passosExternos", "parar", "efeito" } do
	sound[name] = function(...) mark("sound_" .. name, ...); mark("sound_locale", lang) end
end
local foley = { ui = function(key) mark("ui", key) end, destroy = function() mark("destroy_foley") end }
local modules = {
	[shared] = settings, Textos = texts, Audio = legacy, AudioCatalog = catalog,
	Idioma = { iniciar = function(op)
		assert(op.textos == texts and op.atributo == "locale" and op.remoto == remoteLanguage and op.playerGui == playerGui)
		return language
	end },
	Interface = { criar = function(pg, t, current) assert(pg == playerGui and t == texts and current == language.atual); return ui end },
	Prompts = { iniciar = function(pg, op) assert(pg == playerGui and op.textos == texts and op.idioma == language.atual and op.aoMudar == language.aoMudar); mark("prompts_localized") end },
	Telas = { iniciar = function(op) assert(op.playerGui == playerGui and op.textos == texts and op.idioma == language.atual and op.aoMudar == language.aoMudar); mark("terminals_localized") end },
	Giroflex = { iniciar = function() end },
	Som = { iniciar = function(op)
		assert(op.audio == legacy and op.textos == texts and op.idioma == language.atual)
		assert(op.alarme() == false and op.acessoBloqueado() == false)
		return sound
	end },
	Foley = { start = function(p, c, op)
		assert(p == player and c == catalog and op.grupo == sound.grupoEfeitos)
		op.aoPassosMudar(false)
		return foley
	end },
	MonstroSom = { iniciar = function(op)
		assert(op.jogador == player and op.passos == true and op.grupo == sound.grupoEfeitos and type(op.efeito) == "function",
			"MonstroSom com passos no pé e sons do ElevenLabs")
		mark("monstro_som_ligado")
		return { parar = function() mark("monstro_som_parado") end }
	end },
	Efeitos = { iniciar = function(op)
		assert(op.jogador == player and op.playerGui == playerGui and type(op.efeito) == "function" and type(op.ui) == "function")
		mark("efeitos_ligados")
		return { destroy = function() mark("efeitos_desligados") end }
	end },
}
local environment = {
	game = { GetService = function(_, name) return ({ Players = { LocalPlayer = player }, ReplicatedStorage = storage, ProximityPromptService = promptService })[name] end },
	script = scriptNode, workspace = { GetServerTimeNow = function() return 100 end },
	require = function(module) assert(modules[module], tostring(module)); return modules[module] end,
	warn = function(...) mark("warn", ...) end,
}
luau.load(fs.readFile("src/client/BastiaoCliente.luau"), { environment = environment, injectGlobals = true })()
presentation.OnClientEvent:Fire({ tipo = "fala", chave = "pavel_cafe", duracao = 4 })
presentation.OnClientEvent:Fire({ tipo = "som", chave = "tres_toques", duracao = 2.6 })
presentation.OnClientEvent:Fire({ tipo = "ruido", chave = "terminal_bip" })
assert(count("caption_som") == 0, "story effects must play without pretend-audio captions")
assert(count("sound_fala", "pavel_cafe") == 1 and count("caption_fala", "pavel_cafe") == 1)
assert(count("sound_som", "tres_toques") == 1 and count("sound_ruido", "terminal_bip") == 1)
assert(count("prompts_localized") == 1 and count("terminals_localized") == 1)
assert(count("efeitos_ligados") == 1, "efeitos do cliente (menu/lanterna/perseguição) não foram ligados")
assert(count("monstro_som_ligado") == 1, "sons do bote do monstro não foram ligados")
lang = "ru"
for _, listener in languageListeners do listener(lang) end
assert(count("caption_idioma") == 1 and count("sound_precarregar") == 1)
presentation.OnClientEvent:Fire({ tipo = "fala", chave = "orlov_ordem", duracao = 8.26 })
assert(count("caption_locale", "ru") > 0 and count("sound_locale", "ru") > 0)
local storyPrompt = { GetAttribute = function(_, name) return if name == "Bastiao" then true else nil end }
local otherPrompt = { GetAttribute = function() return false end }
promptService.PromptTriggered:Fire(otherPrompt, player)
promptService.PromptTriggered:Fire(storyPrompt, {})
assert(count("ui", "ui_click") == 0)
promptService.PromptTriggered:Fire(storyPrompt, player)
assert(count("ui", "ui_click") == 1)
presentation.OnClientEvent:Fire({ tipo = "aviso", chave = "aguarde_pavel", args = { "Ana" } })
assert(count("ui", "ui_denied") == 1 and count("caption_aviso", "aguarde_pavel") == 1)
promptService.PromptTriggered:Fire(storyPrompt, player)
attributes.objective = "bateria"
attributeSignals.objective:Fire()
assert(count("ui", "ui_confirm") == 1 and count("caption_objetivo", "bateria") == 1)
attributeSignals.access:Fire()
assert(count("sound_estado") >= 2)
presentation.OnClientEvent:Fire({ tipo = "aviso", texto = "not a localized chapter key" })
assert(count("caption_aviso") == 1)
scriptNode.Destroying:Fire()
presentation.OnClientEvent:Fire({ tipo = "som", chave = "trava" })
promptService.PromptTriggered:Fire(storyPrompt, player)
for _, listener in languageListeners do listener("pt") end
assert(count("sound_parar") == 1 and count("destroy_foley") == 1 and count("monstro_som_parado") == 1)
assert(count("sound_som", "trava") == 0 and count("ui", "ui_click") == 2 and count("caption_idioma") == 1)
-- Os efeitos visuais são opcionais: se quebrarem ou faltarem, legendas, som e prompts continuam.
local AVISO = "[Bastiao] efeitos visuais desligados:"
local AVISO_SOM = "[Bastiao] sons do bote desligados:"
for _, caso in { "erro", "ausente" } do
	calls = {}
	if caso == "erro" then
		modules.Efeitos = { iniciar = function() error("menu quebrado de proposito") end }
		modules.MonstroSom = { iniciar = function() error("som quebrado de proposito") end }
	else
		scriptNode.WaitForChild = function(_, name) return if name == "Efeitos" or name == "MonstroSom" then nil else name end
	end
	luau.load(fs.readFile("src/client/BastiaoCliente.luau"), { environment = environment, injectGlobals = true })()
	assert(count("warn", AVISO) == 1, "falha dos efeitos (" .. caso .. ") deve virar só um aviso")
	assert(count("warn", AVISO_SOM) == 1, "falha do MonstroSom (" .. caso .. ") deve virar só um aviso")
	presentation.OnClientEvent:Fire({ tipo = "fala", chave = "pavel_cafe", duracao = 4 })
	assert(count("sound_fala", "pavel_cafe") == 1 and count("caption_fala", "pavel_cafe") == 1, "cliente parou junto com os efeitos")
	assert(count("prompts_localized") == 1 and count("terminals_localized") == 1)
	scriptNode.Destroying:Fire()
	assert(count("sound_parar") == 1 and count("destroy_foley") == 1, "desmontar sem efeitos falhou")
end
print("PASS latest locale/terminal hooks, chapter event routing, prompt activation and teardown; client survives broken or missing effects and bite sounds (service harness; no engine)")
