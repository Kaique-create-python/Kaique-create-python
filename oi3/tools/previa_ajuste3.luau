-- Prévias do AJUSTE-3: exterior novo, primeira pessoa com lanterna, luar, lareira e menu
local H = require("./harness")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3.new

local Mapa = H.modulo("ReplicatedStorage/OI3/Mapa")
local ws = H.dm:GetService("Workspace")
local F = Mapa.L.F
local modelo = Mapa.construir(ws)
fs.writeFile("oi3/tools/out/mapa3.json", serde.encode("json", H.exportarPecas(modelo)))
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
	local arq = "oi3/tools/out/vm_" .. string.gsub(nome, "%s", "_") .. ".json"
	fs.writeFile(arq, serde.encode("json", H.exportarPecas(m)))
	return arq
end

local lote = {}
local function vista(nome, cam, alvo, extra)
	local opts = { w = 844, h = 390, cam = { cam.X, cam.Y, cam.Z }, alvo = { alvo.X, alvo.Y, alvo.Z }, fov = 72, lua = 0.35, ambiente = 0.42, hemi = 0.22, forcaLuz = 55, forcaSpot = 40, beams = beams, neblina = 0.004, ceu = 657936, sombras = true, rotulo = "Prévia aproximada (fora do Roblox): " .. nome }
	for k, v in extra or {} do
		opts[k] = v
	end
	local vm = nil
	if opts.overlay then
		vm = maoComLanterna(nome, cam, alvo, (opts.lanterna or 0) > 0)
	end
	table.insert(lote, { pecas = "oi3/tools/out/mapa3.json", extra = vm, saida = "oi3/tools/out/prev3_" .. string.gsub(nome, "%s", "_") .. ".png", opts = opts })
end
vista("fachada", V3(-7, 4.2, 96), V3(0, 15, 0), { fov = 55, lua = 1.0, ambiente = 0.55, neblina = 0.006, sombras = false, w = 1280, h = 720 })
vista("hall lareira", V3(5, F + 4.6, 1), V3(-10.5, F + 3.2, 6), { lanterna = 0, overlay = hud })
vista("corredor lanterna", V3(14.5, F + 4.6, 0.4), V3(50, F + 3.6, 0), { lanterna = 120, overlay = hud })
vista("dormitorio luar", V3(-14.5, F + 4.6, -5), V3(-30, F + 2.8, 0.5), { lanterna = 0, overlay = hud })
fs.writeFile("oi3/tools/out/lote3.json", serde.encode("json", lote))
print("vistas", #lote, "beams", #beams)
