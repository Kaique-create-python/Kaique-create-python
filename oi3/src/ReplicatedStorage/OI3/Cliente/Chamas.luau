-- OI3 :: chamas de vela e lâmpadas tremulando (um laço só para todas)

local RunService = game:GetService("RunService")

local Chamas = {}

type Item = { parte: BasePart, luz: Light?, malha: SpecialMesh?, brilhoBase: number, escalaBase: Vector3?, semente: number, lampada: boolean }

local itens: { Item } = {}
local registrados: { [Instance]: boolean } = {}
local leve = false
local conexao: RBXScriptConnection? = nil
local acumulado = 0

function Chamas.registrar(raiz: Instance)
	for _, d in raiz:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "OI3_Chama" or d.Name == "OI3_Lampada") and not registrados[d] then
			registrados[d] = true
			local luz = d:FindFirstChildWhichIsA("Light")
			local malha = d:FindFirstChildOfClass("SpecialMesh")
			table.insert(itens, {
				parte = d,
				luz = luz,
				malha = malha,
				brilhoBase = if luz then luz.Brightness else 0,
				escalaBase = if malha then malha.Scale else nil,
				semente = math.random() * 100,
				lampada = d.Name == "OI3_Lampada",
			})
		end
	end
end

function Chamas.limparAusentes()
	for i = #itens, 1, -1 do
		if not itens[i].parte.Parent then
			registrados[itens[i].parte] = nil
			table.remove(itens, i)
		end
	end
end

function Chamas.modoLeve(sim: boolean)
	leve = sim
end

function Chamas.iniciar()
	if conexao then
		return
	end
	conexao = RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		local passo = if leve then 0.12 else 0.033
		if acumulado < passo then
			return
		end
		acumulado = 0
		local t = os.clock()
		for _, it in itens do
			local n = math.noise(t * 3.1, it.semente, 0.3)
			local n2 = math.noise(t * 9.7, it.semente * 0.5, 1.7)
			if it.lampada then
				-- lâmpada velha: às vezes falha
				local falha = if math.noise(t * 0.8, it.semente, 4) > 0.42 then 0.25 else 1
				if it.luz then
					it.luz.Brightness = it.brilhoBase * falha * (0.92 + n2 * 0.1)
				end
				it.parte.Transparency = if falha < 1 then 0.6 else 0
			else
				local k = 0.86 + n * 0.22 + n2 * 0.08
				if it.luz then
					it.luz.Brightness = it.brilhoBase * k
				end
				if it.malha and it.escalaBase and not leve then
					it.malha.Scale = Vector3.new(it.escalaBase.X * (0.95 + n2 * 0.1), it.escalaBase.Y * (0.88 + n * 0.25), it.escalaBase.Z * (0.95 + n2 * 0.1))
				end
			end
		end
	end)
end

return Chamas
