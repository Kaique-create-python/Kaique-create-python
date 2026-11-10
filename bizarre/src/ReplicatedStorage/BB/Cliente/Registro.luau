-- BIZARRE BATTLEGROUNDS :: quem está lutando, sem varrer o workspace toda hora (AJUSTE7)
-- O registro é atualizado quando um personagem/bot/Stand entra ou sai (eventos), e os outros
-- módulos só leem a lista pronta.

local Registro = {}

local lutadores: { [Model]: boolean } = {}
local visuais: { [Model]: boolean } = {}
local iniciado = false

local function avaliar(m: Instance)
	if m:IsA("Model") and m:GetAttribute("BB_Lutador") then
		lutadores[m] = true
	else
		lutadores[m :: any] = nil
	end
end

local function observar(pasta: Instance, conjunto: { [Model]: boolean }, filtrar: boolean)
	local function entrou(c: Instance)
		if not c:IsA("Model") then
			return
		end
		if filtrar then
			avaliar(c)
			c:GetAttributeChangedSignal("BB_Lutador"):Connect(function()
				avaliar(c)
			end)
		else
			conjunto[c] = true
		end
	end
	for _, c in pasta:GetChildren() do
		entrou(c)
	end
	pasta.ChildAdded:Connect(entrou)
	pasta.ChildRemoved:Connect(function(c)
		conjunto[c :: any] = nil
		lutadores[c :: any] = nil
	end)
end

function Registro.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	observar(workspace, lutadores, true)
	task.spawn(function()
		local bots = workspace:WaitForChild("BB_Bots", 600)
		if bots then
			observar(bots, lutadores, true)
		end
	end)
	task.spawn(function()
		local sv = workspace:WaitForChild("BB_StandsVisuais", 600)
		if sv then
			observar(sv, visuais, false)
		end
	end)
end

-- lutadores (jogadores, bots e bonecos) vivos no mapa agora
function Registro.lutadores(): { [Model]: boolean }
	if not iniciado then
		Registro.iniciar()
	end
	for m in lutadores do
		if not m.Parent then
			lutadores[m] = nil
		end
	end
	return lutadores
end

-- lutadores + os Stands desenhados (para o tempo parado congelar a animação de todos)
function Registro.todosModelos(): { [Model]: boolean }
	local r = {}
	for m in Registro.lutadores() do
		r[m] = true
	end
	for m in visuais do
		if m.Parent then
			r[m] = true
		else
			visuais[m] = nil
		end
	end
	return r
end

return Registro
