--!strict
-- Cidade Neon: ruas com faixas, calçadas, prédios variados com fachadas de
-- vidro e neon, painéis holográficos, passarela elevada, torre central com
-- anel giratório, laboratório em cúpula, carros estacionados e postes neon.

local MapKit = require(script.Parent.Parent.MapKit)

local City = { id = "city" }

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local NEON = { rgb(255, 60, 200), rgb(60, 220, 255), rgb(140, 255, 120), rgb(255, 200, 60), rgb(170, 100, 255) }
local SIGNS = { "NEON", "IDEIAS", "LOJA 24H", "CAFÉ", "ROBÔS", "FUTURO", "PIZZA", "GAMES", "HOTEL", "LAB" }

function City.build(ctx: any)
	local rng = ctx.rng
	local c = ctx.center
	local M = Enum.Material
	MapKit.fillBlock(CF(c.X, -1.5, c.Z), V(320, 3, 320), M.Concrete)
	MapKit.flat(c.X, c.Z, 165, 0)

	-- malha de ruas
	ctx:build("Ruas", CF(c.X, 0, c.Z), function(b)
		local asphalt = rgb(48, 48, 54)
		for _, k in { -96, -32, 32, 96 } do
			b:box(V(300, 0.3, 16), CF(0, 0.15, k), asphalt, { role = "fixed", material = M.Asphalt })
			b:box(V(16, 0.31, 300), CF(k, 0.155, 0), asphalt, { role = "fixed", material = M.Asphalt })
			for s = -140, 140, 12 do
				if math.abs(s - (-96)) > 9 and math.abs(s + 32) > 9 and math.abs(s - 32) > 9 and math.abs(s - 96) > 9 then
					b:box(V(5, 0.33, 0.5), CF(s, 0.17, k), rgb(250, 220, 70), { role = "fixed", collide = false })
					b:box(V(0.5, 0.34, 5), CF(k, 0.17, s), rgb(250, 220, 70), { role = "fixed", collide = false })
				end
			end
		end
	end)

	-- quarteirões com prédios
	local blocks = { -128, -64, 0, 64, 128 }
	local lots = 0
	for _, bx in blocks do
		for _, bz in blocks do
			if not (bx == 0 and bz == 0) then
				lots += 1
				-- calçada
				ctx:build("Calcada", CF(c.X + bx, 0, c.Z + bz), function(b)
					b:box(V(44, 0.6, 44), CF(0, 0.3, 0), rgb(150, 150, 158), { role = "fixed", material = M.Pavement })
				end)
				if math.abs(bx) == 128 or math.abs(bz) == 128 or rng:chance(0.7) then
					local floors = rng:int(4, 11)
					if math.abs(bx) <= 64 and math.abs(bz) <= 64 then
						floors += 4
					end
					ctx:build("Predio", CF(c.X + bx, 0.6, c.Z + bz), function(b)
						local w = rng:range(22, 32)
						local d = rng:range(22, 32)
						local fh = 5
						local body = rng:pick({ rgb(40, 44, 60), rgb(60, 64, 80), rgb(30, 34, 46), rgb(80, 80, 96) })
						local glow = rng:pick(NEON)
						b:box(V(w, floors * fh, d), CF(0, floors * fh / 2, 0), body, { role = "fixed", material = M.Concrete })
						for f = 1, floors do
							if f % 2 == 1 or floors < 6 then
								b:box(V(w + 0.3, 1.8, d + 0.3), CF(0, (f - 0.4) * fh, 0), rgb(130, 200, 255), { role = "fixed", material = M.Glass, transparency = 0.2, reflectance = 0.25 })
							end
						end
						b:box(V(w + 0.6, 0.5, d + 0.6), CF(0, floors * fh, 0), glow, { role = "fixed", material = M.Neon })
						for _, x in { -w / 2, w / 2 } do
							b:box(V(0.4, floors * fh, 0.4), CF(x, floors * fh / 2, -d / 2 - 0.2), glow, { role = "fixed", material = M.Neon, collide = false })
						end
						if rng:chance(0.6) then
							local sign = b:box(V(12, 4, 0.6), CF(0, floors * fh * 0.55, -d / 2 - 0.6), rgb(20, 20, 30), { role = "fixed", name = "Painel" })
							MapKit.sign(sign, rng:pick(SIGNS), glow, Enum.NormalId.Front)
							sign:AddTag("IdeiasTela")
						end
						if rng:chance(0.5) then
							b:cylY(10, 0.5, CF(w * 0.2, floors * fh + 5, 0), rgb(180, 180, 190), { role = "fixed", material = M.Metal })
							local l = b:ball(1, CF(w * 0.2, floors * fh + 10.5, 0), rgb(255, 50, 50), { role = "fixed", material = M.Neon })
							local _ = l
						end
					end)
				else
					-- praça de bolso: árvore, bancos e carro
					ctx:prop("nature", "tree", CF(c.X + bx, 0.6, c.Z + bz), 1)
					local bench = ctx:prop("prop", "bench", CF(c.X + bx + 10, 0.6, c.Z + bz), 0.8)
					ctx:destructible(bench)
				end
			end
		end
	end

	-- torre central com anel girando
	ctx:build("TorreCentral", CF(c.X, 0, c.Z), function(b)
		b:box(V(44, 0.6, 44), CF(0, 0.3, 0), rgb(160, 160, 170), { role = "fixed", material = M.Pavement })
		b:cylY(110, 10, CF(0, 55, 0), rgb(200, 205, 220), { role = "fixed", material = M.Metal })
		for k = 0, 9 do
			b:cylY(1, 11, CF(0, 8 + k * 10, 0), NEON[(k % #NEON) + 1], { role = "fixed", material = M.Neon })
		end
		b:cone(18, 10, CF(0, 110, 0), rgb(200, 205, 220), 4, { role = "fixed", material = M.Metal })
		local pivot = b:box(V(1, 1, 1), CF(0, 80, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false, name = "Pivo" })
		MapKit.spin(pivot, "Y", 0.3)
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			local seg = b:box(V(5, 1, 1.4), CF(math.cos(a) * 16, 80, math.sin(a) * 16) * ANG(0, -a + math.pi / 2, 0), rgb(60, 220, 255), { role = "fixed", material = M.Neon, collide = false })
			seg.Parent = pivot
		end
		local top = b:ball(3, CF(0, 129, 0), rgb(255, 80, 200), { role = "fixed", material = M.Neon })
		b:light(top, rgb(255, 90, 210), 60, 3)
	end)

	-- passarela elevada entre dois quarteirões
	ctx:build("Passarela", CF(c.X - 64, 26, c.Z - 32), function(b)
		b:box(V(8, 1, 44), CF(0, 0, 0), rgb(200, 205, 215), { role = "fixed", material = M.Metal })
		b:box(V(8.2, 4, 44), CF(0, 2.5, 0), rgb(140, 220, 255), { role = "fixed", material = M.Glass, transparency = 0.6 })
		b:box(V(8.4, 0.3, 44), CF(0, -0.6, 0), rgb(60, 220, 255), { role = "fixed", material = M.Neon })
	end)

	-- laboratório em cúpula
	ctx:build("Laboratorio", CF(c.X + 128, 0.6, c.Z + 128), function(b)
		b:cylY(4, 34, CF(0, 2, 0), rgb(220, 225, 235), { role = "fixed", material = M.Metal })
		b:part("ball", V(30, 30, 30), CF(0, 4, 0), rgb(150, 220, 255), { role = "fixed", material = M.Glass, transparency = 0.5 })
		local core = b:ball(6, CF(0, 9, 0), rgb(120, 255, 160), { role = "fixed", material = M.Neon })
		b:light(core, rgb(120, 255, 160), 30, 2)
	end)

	-- carros estacionados e postes neon
	for k = 1, 8 do
		local lane = rng:pick({ -96, -32, 32, 96 })
		local along = rng:range(-130, 130)
		local horizontal = rng:chance(0.5)
		local x = if horizontal then along else lane + 5
		local z = if horizontal then lane + 5 else along
		local rot = if horizontal then math.pi / 2 else 0
		ctx:parkedVehicle(rng:pick({ "car", "sportscar", "car", "police_car" }), CF(c.X + x, 0.5, c.Z + z) * ANG(0, rot, 0))
	end
	for _, k in { -96, -32, 32, 96 } do
		for s = -128, 128, 64 do
			local lamp = ctx:build("PosteNeon", CF(c.X + s + 10, 0.6, c.Z + k + 9), function(b)
				b:cylY(12, 0.5, CF(0, 6, 0), rgb(40, 40, 48), { role = "fixed", material = M.Metal })
				b:box(V(4, 0.4, 0.8), CF(-1.8, 12, 0), rgb(40, 40, 48), { role = "fixed", material = M.Metal })
				b:box(V(3, 0.3, 0.7), CF(-2.4, 11.7, 0), rng:pick(NEON), { role = "fixed", material = M.Neon })
			end)
			ctx:destructible(lamp)
		end
	end
	-- caixas e lixeiras destrutíveis
	for k = 1, 12 do
		local m = ctx:prop("prop", rng:pick({ "crate", "barrel" }), CF(c.X + rng:range(-140, 140), 0.6, c.Z + rng:range(-140, 140)), 0.6)
		ctx:destructible(m)
	end
end

return City
