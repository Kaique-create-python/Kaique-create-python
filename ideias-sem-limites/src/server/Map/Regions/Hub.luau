--!strict
-- Centro de Criação: praça circular com palco, lâmpada gigante (símbolo do
-- jogo), anel holográfico girando, quatro portais para as regiões, fontes,
-- jardins, bancos, postes e plataformas de viagem rápida.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapLayout = require(ReplicatedStorage.IdeiasShared.MapLayout)
local MapKit = require(script.Parent.Parent.MapKit)

local Hub = { id = "hub" }

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

function Hub.build(ctx: any)
	local rng = ctx.rng
	-- piso em anéis concêntricos
	ctx:build("Praca", CF(0, 0, 0), function(b)
		b:cylY(0.6, 190, CF(0, 0.3, 0), rgb(150, 150, 158), { role = "fixed", material = Enum.Material.Pavement })
		b:cylY(0.7, 150, CF(0, 0.35, 0), rgb(214, 210, 200), { role = "fixed", material = Enum.Material.Marble })
		b:cylY(0.75, 147, CF(0, 0.38, 0), rgb(90, 200, 255), { role = "fixed", material = Enum.Material.Neon })
		b:cylY(0.8, 144, CF(0, 0.4, 0), rgb(222, 218, 210), { role = "fixed", material = Enum.Material.Marble })
		b:cylY(0.85, 96, CF(0, 0.43, 0), rgb(70, 72, 92), { role = "fixed", material = Enum.Material.Slate })
		-- mosaico radial
		for k = 0, 23 do
			local a = k / 24 * math.pi * 2
			b:box(V(1.2, 0.2, 22), CF(math.cos(a) * 60, 0.86, math.sin(a) * 60) * ANG(0, -a + math.pi / 2, 0), if k % 2 == 0 then rgb(200, 190, 175) else rgb(180, 170, 158), { role = "fixed", material = Enum.Material.Marble, collide = false })
		end
	end)

	-- palco circular com degraus
	ctx:build("Palco", CF(0, 0, 0), function(b)
		for k = 0, 2 do
			b:cylY(1.2, 46 - k * 6, CF(0, 1.2 + k * 1.2, 0), if k == 2 then rgb(60, 60, 80) else rgb(225, 222, 215), { role = "fixed", material = if k == 2 then Enum.Material.Slate else Enum.Material.Marble })
		end
		b:cylY(0.2, 33.6, CF(0, 4.35, 0), rgb(110, 220, 255), { role = "fixed", material = Enum.Material.Neon })
		b:cylY(0.25, 32, CF(0, 4.4, 0), rgb(50, 52, 70), { role = "fixed", material = Enum.Material.Slate })
	end)

	-- lâmpada gigante: base, vidro, filamento brilhante
	local bulb = ctx:build("LampadaDasIdeias", CF(0, 4.4, 0), function(b)
		b:cylY(3, 7, CF(0, 1.5, 0), rgb(160, 165, 175), { role = "fixed", material = Enum.Material.Metal })
		for k = 0, 3 do
			b:cylY(0.6, 7.6, CF(0, 3.2 + k * 0.9, 0), rgb(190, 195, 205), { role = "fixed", material = Enum.Material.Metal })
		end
		b:cylY(1.2, 4, CF(0, 7.2, 0), rgb(40, 40, 45), { role = "fixed" })
		b:ball(20, CF(0, 17.5, 0), rgb(220, 245, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.55, name = "Vidro" })
		local core = b:ball(5.4, CF(0, 17, 0), rgb(255, 230, 120), { role = "fixed", material = Enum.Material.Neon, name = "Filamento" })
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			b:beam(V(math.cos(a) * 1.2, 8.5, math.sin(a) * 1.2), V(math.cos(a) * 1.6, 15, math.sin(a) * 1.6), 0.3, rgb(255, 210, 110), { role = "fixed", material = Enum.Material.Neon })
		end
		b:light(core, rgb(255, 230, 150), 60, 3)
	end)
	local _ = bulb

	-- anel holográfico girando em volta da lâmpada
	ctx:build("AnelHolografico", CF(0, 4.4, 0), function(b)
		local pivot = b:box(V(1, 1, 1), CF(0, 18, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false, name = "Pivo" })
		MapKit.spin(pivot, "Y", 0.35)
		for k = 0, 19 do
			local a = k / 20 * math.pi * 2
			local seg = b:box(V(4, 0.6, 0.6), CF(math.cos(a) * 15, 18 + math.sin(a * 3) * 0.8, math.sin(a) * 15) * ANG(0, -a + math.pi / 2, 0), if k % 2 == 0 then rgb(90, 220, 255) else rgb(200, 120, 255), { role = "fixed", material = Enum.Material.Neon, collide = false })
			seg.Parent = pivot
		end
	end)

	-- letreiro com o nome do jogo flutuando acima do palco, girando devagar
	ctx:build("Letreiro", CF(0, 0, 0), function(b)
		local pivot = b:box(V(1, 1, 1), CF(0, 40, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false, name = "PivoLetreiro" })
		MapKit.spin(pivot, "Y", 0.12)
		for k = 0, 1 do
			local a = k * math.pi
			local board = b:box(V(34, 6, 1), CF(0, 40, 0) * ANG(0, a, 0) * CF(0, 0, -4), rgb(30, 32, 50), { role = "fixed", collide = false, name = "Placa" })
			MapKit.sign(board, "IDEIAS SEM LIMITES", rgb(120, 230, 255), Enum.NormalId.Front)
			board.Parent = pivot
			local edge = b:box(V(34.4, 0.4, 1.2), CF(0, 37, 0) * ANG(0, a, 0) * CF(0, 0, -4), rgb(110, 220, 255), { role = "fixed", material = Enum.Material.Neon, collide = false })
			edge.Parent = pivot
		end
	end)

	-- portais para as regiões, com viagem rápida
	local gates = {
		{ id = "forest", angle = -math.pi / 2 },
		{ id = "city", angle = 0 },
		{ id = "glacier", angle = math.pi / 2 },
		{ id = "volcano", angle = math.pi },
	}
	for _, g in gates do
		local region = MapLayout.ById[g.id]
		local dir = V(math.cos(g.angle), 0, math.sin(g.angle))
		local pos = dir * 84
		local cf = CF(pos) * CFrame.lookAt(Vector3.zero, dir).Rotation
		ctx:build("Portal_" .. g.id, cf, function(b)
			for _, x in { -9, 9 } do
				b:cylY(16, 3, CF(x, 8, 0), rgb(220, 218, 212), { role = "fixed", material = Enum.Material.Marble })
				b:ball(3.6, CF(x, 16.5, 0), region.color, { role = "fixed", material = Enum.Material.Neon })
			end
			b:box(V(22, 2.4, 3), CF(0, 17, 0), rgb(220, 218, 212), { role = "fixed", material = Enum.Material.Marble })
			local board = b:box(V(16, 3.2, 0.6), CF(0, 20.4, 0), rgb(30, 32, 45), { role = "fixed", name = "Placa" })
			MapKit.sign(board, region.label, region.color, Enum.NormalId.Front)
			MapKit.sign(board, region.label, region.color, Enum.NormalId.Back)
			b:box(V(18, 0.3, 1), CF(0, 15.6, 0), region.color, { role = "fixed", material = Enum.Material.Neon })
		end)
		local target = CF(region.center + V(0, 8, 0) - dir * 40)
		ctx:teleportPad(CF(dir * 72 + V(0, 0.9, 0)), target, region.label, region.color)
	end
	-- plataformas para Deserto, Praia, Céu e Arena
	local extra = {
		{ id = "desert", angle = -math.pi / 4 },
		{ id = "beach", angle = math.pi * 3 / 4 },
		{ id = "arena", angle = math.pi / 4 },
	}
	for _, e in extra do
		local region = MapLayout.ById[e.id]
		local dir = V(math.cos(e.angle), 0, math.sin(e.angle))
		local target = if e.id == "arena" then CF(region.center + V(0, 6, 40)) else CF(region.center + V(0, 8, 0) - dir * 30)
		ctx:teleportPad(CF(dir * 80 + V(0, 0.9, 0)), target, region.label, region.color)
	end
	-- salto para as ilhas flutuantes
	local skyDir = (MapLayout.ById.sky.center - V(0, MapLayout.ById.sky.center.Y, 0)).Unit
	ctx:jumpPad(CF(V(-62, 0.9, -62)), (skyDir * 0.62 + V(0, 1, 0)).Unit, 380, rgb(200, 160, 255))

	-- fontes entre os portais
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local p = V(math.cos(a) * 52, 0, math.sin(a) * 52)
		ctx:build("Fonte", CF(p), function(b)
			b:cylY(2.4, 18, CF(0, 1.2, 0), rgb(225, 222, 215), { role = "fixed", material = Enum.Material.Marble })
			b:cylY(1.6, 15.6, CF(0, 1.8, 0), rgb(80, 170, 240), { role = "fixed", material = Enum.Material.Glass, transparency = 0.35, collide = false })
			b:cylY(6, 2.4, CF(0, 4, 0), rgb(225, 222, 215), { role = "fixed", material = Enum.Material.Marble })
			b:cylY(0.8, 7, CF(0, 7, 0), rgb(225, 222, 215), { role = "fixed", material = Enum.Material.Marble })
			local spout = b:ball(1.6, CF(0, 8.2, 0), rgb(150, 220, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.3 })
			MapKit.emitter(spout, "rbxasset://textures/particles/sparkles_main.dds", rgb(170, 225, 255), 18, {
				speed = NumberRange.new(8, 12),
				spread = Vector2.new(25, 25),
				accel = V(0, -25, 0),
				lifetime = NumberRange.new(0.8, 1.2),
				size = NumberSequence.new(0.6),
			})
		end)
	end

	-- jardins, árvores, bancos e postes em anel
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2 + math.pi / 16
		local r = 104
		local p = V(math.cos(a) * r, 0, math.sin(a) * r)
		if k % 2 == 0 then
			ctx:prop("nature", rng:pick({ "tree", "tree", "pine" }), CF(p), rng:range(0.9, 1.2))
		else
			ctx:prop("nature", "flowers", CF(p), 0.9)
		end
	end
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local p = V(math.cos(a) * 92, 0, math.sin(a) * 92)
		local face = CFrame.lookAt(p, Vector3.zero)
		local bench = ctx:prop("prop", "bench", face, 0.9)
		ctx:destructible(bench)
		local lamp = ctx:build("Poste", CF(V(math.cos(a + 0.13) * 97, 0, math.sin(a + 0.13) * 97)), function(b)
			b:cylY(12, 0.6, CF(0, 6, 0), rgb(40, 42, 50), { role = "fixed", material = Enum.Material.Metal })
			local l = b:ball(1.8, CF(0, 12.4, 0), rgb(255, 240, 200), { role = "fixed", material = Enum.Material.Neon })
			if k % 2 == 0 then
				b:light(l, rgb(255, 230, 180), 26, 1.4)
			end
		end)
		ctx:destructible(lamp)
	end
	-- caixas e barris espalhados (destrutíveis)
	for k = 1, 10 do
		local a = rng:range(0, math.pi * 2)
		local r = rng:range(112, 140)
		local m = ctx:prop("prop", rng:pick({ "crate", "crate", "barrel" }), CF(math.cos(a) * r, 0, math.sin(a) * r) * ANG(0, rng:range(0, 6), 0), 0.8)
		ctx:destructible(m)
	end
	-- escotilha para a arena subterrânea (visual) já coberta pela plataforma acima
	MapKit.flat(0, 0, 96, 0)
end

return Hub
