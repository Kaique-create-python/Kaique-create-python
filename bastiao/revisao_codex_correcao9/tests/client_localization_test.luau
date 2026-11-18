local Harness = require("./client_harness")
local h = Harness.new()
local texts = h:load("tests/fixtures/baseline/3_Textos.luau")
local lang = "pt"
local ui = h:load("src/client/Interface.luau").criar(h.playerGui, texts, function() return lang end)
local title = h.playerGui:FindFirstChild("ObjetivoTitulo", true)
local caption = h.playerGui:FindFirstChild("Texto", true)
for _, locale in { "pt", "en", "ru" } do
	lang = locale; ui.idioma(); ui.fala("pavel_cafe", 4)
	assert(title.Text == texts.de(locale).ui.objetivo)
	assert(string.gsub(caption.Text, "\n", " ") == texts.de(locale).falas.pavel_cafe)
end
local Telas = h:load("tests/fixtures/baseline/22_Telas.luau")
local terminal = h:new("Part", "Terminal", h.story)
terminal:SetAttribute("BastiaoTela", "enfermaria")
terminal:SetAttribute("BastiaoTelaEstado", "ligado")
h.tagged.BastiaoTela = { terminal }
local listeners = {}
Telas.iniciar({ playerGui = h.playerGui, textos = texts, idioma = function() return lang end, aoMudar = function(fn) table.insert(listeners, fn) end })
local surface = h.playerGui:FindFirstChild("Tela_enfermaria", true)
local terminalText = surface:FindFirstChildOfClass("Frame"):FindFirstChildOfClass("TextLabel")
for _, locale in { "pt", "en", "ru" } do
	lang = locale
	for _, fn in listeners do fn(locale) end
	assert(terminalText.Text == texts.de(locale).terminais.enfermaria_ligado)
end
print("PASS real latest Interface speech captions and streamed terminal redraw in PT/EN/RU (UI boundary; no rendering engine)")
