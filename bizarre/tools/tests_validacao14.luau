-- Testa o validador que será executado no Roblox, com catálogo/Instances reais do Lune.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local H = require("./harness")
local okModule, V = pcall(H.modulo, "ReplicatedStorage/BB/Validacao14")
local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed += 1; print("PASS " .. name) else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function fixture()
	assert(okModule and type(V) == "table", "validador nativo AJ14 ainda não implementado")
	local game = roblox.Instance.new("DataModel")
	local rs = game:GetService("ReplicatedStorage")
	local bb = roblox.Instance.new("Folder"); bb.Name = "BB"; bb.Parent = rs
	local source = roblox.Instance.new("ModuleScript"); source.Name = "Probe"; source.Source = "return 14"; source.Parent = bb
	local cfg = { package = "BIZARRE-AJUSTE-14", stage = 14, universe = 10774214555, place = 108061345551908,
		hashes = { { path = { "ReplicatedStorage", "BB", "Probe" }, class = "ModuleScript", bytes = 9, hash = "021abcaa" } } }
	local catalog = roblox.deserializeModel(fs.readFile("bizarre/assets/vfx14/catalogo.rbxm"))[1]
	catalog.Parent = rs
	local config = { REVISAO = "AJUSTE-14", UNIVERSE_ID = 10774214555, PLACE_ID = 108061345551908 }
	return game, cfg, config, H.modulo("ReplicatedStorage/BB/VFXReceitas"), H.modulo("ReplicatedStorage/BB/PerfilCombate14"), source, catalog
end
test("hash UTF8 compatível com Python", function()
	assert(okModule, "validador ausente")
	assert(V.djb("") == "00001505")
	assert(V.djb("abc") == "0b885c8b")
	assert(V.djb("return 14") == "021abcaa")
end)
test("catálogo real e fontes reconhecidas são aprovados", function()
	local g,cfg,c,r,p = fixture(); local report = V.executar(g,cfg,c,r,p)
	assert(report.passed, table.concat(report.erros," | ")); assert(report.info.templates == 23)
	assert(report.info.beams == 2 and report.info.emissores == 59)
end)
test("fonte alterada bloqueia sem revelar seu conteúdo", function()
	local g,cfg,c,r,p,source = fixture(); source.Source = "SEGREDO-NAO-EXIBIR"
	local report = V.executar(g,cfg,c,r,p)
	assert(not report.passed); assert(not string.find(table.concat(report.erros," | "),"SEGREDO",1,true))
end)
test("fonte duplicada não pode esconder alteração", function()
	local g,cfg,c,r,p,source = fixture(); source:Clone().Parent = source.Parent
	assert(not V.executar(g,cfg,c,r,p).passed)
end)
test("destino e revisão incorretos bloqueiam", function()
	local g,cfg,c,r,p = fixture(); cfg.place = 4508269622
	assert(not V.executar(g,cfg,c,r,p).passed)
	cfg.place = 108061345551908; c.REVISAO = "AJUSTE-13"
	assert(not V.executar(g,cfg,c,r,p).passed)
end)
test("manifesto vazio não aprova qualquer jogo", function()
	local g,cfg,c,r,p = fixture(); cfg.hashes = {}
	assert(not V.executar(g,cfg,c,r,p).passed)
end)
test("código dentro dos visuais bloqueia", function()
	local g,cfg,c,r,p,_,cat = fixture()
	local script = roblox.Instance.new("Script"); script.Source = "return nil"; script.Parent = cat:GetChildren()[1]
	assert(not V.executar(g,cfg,c,r,p).passed)
end)
test("template ausente e Beam desconectado bloqueiam", function()
	local g,cfg,c,r,p,_,cat = fixture(); cat:GetChildren()[1]:Destroy()
	assert(not V.executar(g,cfg,c,r,p).passed)
	g,cfg,c,r,p,_,cat = fixture()
	local outside = roblox.Instance.new("Attachment"); outside.Name="ReferenciaExterna"; outside.Parent=cat
	for _,d in cat:GetDescendants() do if d:IsA("Beam") then d.Attachment0 = outside; break end end
	assert(not V.executar(g,cfg,c,r,p).passed)
end)
print(string.format("Validação14: %d PASS, %d FAIL",passed,failed))
assert(failed == 0, "validação nativa não aprovada")
