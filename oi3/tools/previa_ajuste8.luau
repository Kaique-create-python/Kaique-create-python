-- Prévias do AJUSTE-8: o assoalho de madeira aparecendo (tapetes menores)
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3.new

local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
local ws = H.dm:GetService("Workspace")
local F = Mapa.L.F
local modelo = Mapa.construir(ws)
fs.writeFile("oi3/tools/out/mapa8.json", serde.encode("json", H.exportarPecas(modelo)))
local beams = H.exportarBeams(modelo)

local hud = [[
<div style="position:absolute;inset:0;background:radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(0,0,0,.55) 100%)"></div>
<div style="position:absolute;left:50%;top:50%;width:5px;height:5px;margin:-2px;border-radius:50%;background:rgba(240,236,228,.55)"></div>
<div style="position:absolute;left:50%;bottom:22px;width:230px;height:7px;margin-left:-115px;border-radius:4px;background:rgba(14,13,16,.65);box-shadow:0 0 0 1px rgba(240,232,216,.18);overflow:hidden"><div style="width:68%;height:100%;border-radius:4px;background:linear-gradient(#fff,#bdb6aa)"></div></div>
<div style="position:absolute;right:12px;top:10px;width:88px;height:36px;border-radius:4px;background:rgba(34,31,36,.85);box-shadow:0 0 0 1px rgba(92,78,62,.6);color:#e8e2d6;font:700 16px sans-serif;display:flex;align-items:center;justify-content:center">MENU</div>
<div style="position:absolute;right:24px;bottom:176px;width:62px;height:62px;border-radius:4px;background:rgba(26,24,29,.88);box-shadow:0 0 0 1px rgba(92,78,62,.6);color:#e8e2d6;font:700 11px sans-serif;display:flex;align-items:flex-end;justify-content:center;padding-bottom:3px;box-sizing:border-box">CORRER</div>
<div style="position:absolute;right:96px;bottom:176px;width:62px;height:62px;border-radius:4px;background:rgba(196,150,70,.95);color:#1e160c;font:700 11px sans-serif;display:flex;align-items:flex-end;justify-content:center;padding-bottom:3px;box-sizing:border-box">LUZ</div>
<div style="position:absolute;right:30px;bottom:30px;width:74px;height:74px;border-radius:50%;background:rgba(255,255,255,.18);box-shadow:0 0 0 2px rgba(255,255,255,.35)"></div>
<div style="position:absolute;left:60px;bottom:40px;width:110px;height:110px;border-radius:50%;box-shadow:0 0 0 2px rgba(255,255,255,.3)"></div>
]]

-- mão + lanterna da primeira pessoa (mesma posição que o jogo usa, sem o balanço)
local PP = H.modulo("ReplicatedStorage/OI3/Cliente/PrimeiraPessoa")
local function maoComLanterna(nome, cam, alvo, ligada)
	local m, lente = PP.montarLanterna()
	if not ligada then
		lente.Color = roblox.Color3.fromRGB(40, 40, 44)
		lente.Material = roblox.Enum.Material.Glass
	end
	H.moverModelo(m, roblox.CFrame.lookAt(cam, alvo) * roblox.CFrame.new(0.78, -0.72, -1.35))
	local arq = "oi3/tools/out/vm8_" .. string.gsub(nome, "%s", "_") .. ".json"
	fs.writeFile(arq, serde.encode("json", H.exportarPecas(m)))
	return arq
end

local variantes = {}
for _, t in serde.decode("json", fs.readFile("oi3/assets/texturas/texturas.json")) do
	local base = "../../assets/texturas/"
	variantes[t.nome] = { nome = t.nome, cor = base .. t.mapas.cor, normal = base .. t.mapas.normal, rug = base .. t.mapas.rugosidade, studs = t.studs }
end

local lote = {}
local function vista(nome, cam, alvo, extra)
	local opts = { w = 844, h = 390, cam = { cam.X, cam.Y, cam.Z }, alvo = { alvo.X, alvo.Y, alvo.Z }, fov = 72, lua = 0.35, ambiente = 0.42, hemi = 0.22, forcaLuz = 55, forcaSpot = 40, beams = beams, neblina = 0.004, ceu = 657936, sombras = true, variantes = variantes, rotulo = "Prévia aproximada (fora do Roblox): " .. nome }
	for k, v in extra or {} do
		opts[k] = v
	end
	local vm = nil
	if opts.overlay then
		vm = maoComLanterna(nome, cam, alvo, (opts.lanterna or 0) > 0)
	end
	table.insert(lote, { pecas = "oi3/tools/out/mapa8.json", extra = vm, saida = "oi3/tools/out/prev8_" .. string.gsub(nome, "%s", "_") .. ".png", opts = opts })
end
local tarde = { lua = 1.3, ambiente = 0.95, hemi = 0.55, neblina = 0.002, overlay = hud, lanterna = 0 }
local noite = { overlay = hud, lanterna = 1 }
vista("hall mesa", V3(-3, F + 4.6, 12.5), V3(0, F + 0.5, 1), tarde)
vista("hall lareira", V3(4, F + 4.6, 9), V3(-8, F + 1, 0), tarde)
vista("dormitorio", V3(-13.5, F + 4.6, -1), V3(-24, F + 0.5, -6), tarde)
vista("hall noite", V3(-3, F + 4.6, 12.5), V3(0, F + 0.5, 1), noite)
fs.writeFile("oi3/tools/out/lote8.json", serde.encode("json", lote))
print("vistas", #lote, "beams", #beams)
