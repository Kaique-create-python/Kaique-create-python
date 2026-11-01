-- OI3 :: configurações do jogador (aplica na hora e salva no servidor com atraso)

local Lighting = game:GetService("Lighting")

local OI3 = script.Parent.Parent
local Config = require(OI3.Config)

local Ajustes = {}

Ajustes.valores = table.clone(Config.PADRAO)

local ouvintes: { (string, any) -> () } = {}
local salvarFn: ((any) -> ())? = nil
local tokenSalvar = 0
local correcao: ColorCorrectionEffect? = nil
local estadoLuz: { [string]: any } = {}

local sanitizar = Config.sanitizarConfig
Ajustes.sanitizar = sanitizar

function Ajustes.iniciar(valoresSalvos: any, salvar: (any) -> ())
	Ajustes.valores = sanitizar(valoresSalvos)
	salvarFn = salvar
	local cam = workspace.CurrentCamera
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "OI3_Brilho"
	cc.Parent = cam
	correcao = cc
	-- guarda o estado original da iluminação (para o modo leve)
	estadoLuz.GlobalShadows = Lighting.GlobalShadows
	for _, d in Lighting:GetChildren() do
		if d:IsA("PostEffect") then
			estadoLuz[d] = d.Enabled
		end
	end
	Ajustes.aplicarTudo()
end

function Ajustes.aoMudar(fn: (string, any) -> ())
	table.insert(ouvintes, fn)
end

function Ajustes.aplicarTudo()
	for k, v in Ajustes.valores do
		Ajustes.aplicar(k, v)
	end
end

function Ajustes.aplicar(chave: string, valor: any)
	if chave == "brilho" and correcao then
		correcao.Brightness = valor
		correcao.Contrast = -valor * 0.15
	elseif chave == "efeitosLeves" then
		-- modo leve: menos sombras e efeitos de pós-processamento
		pcall(function()
			Lighting.GlobalShadows = if valor then false else (estadoLuz.GlobalShadows ~= false)
		end)
		for d, ligado in estadoLuz do
			if typeof(d) == "Instance" and d:IsA("PostEffect") and d.Parent then
				if d:IsA("ColorCorrectionEffect") then
					continue
				end
				d.Enabled = if valor then false else ligado
			end
		end
	end
	for _, fn in ouvintes do
		task.spawn(fn, chave, valor)
	end
end

function Ajustes.definir(chave: string, valor: any)
	if Ajustes.valores[chave] == nil then
		return
	end
	Ajustes.valores[chave] = valor
	Ajustes.aplicar(chave, valor)
	tokenSalvar += 1
	local token = tokenSalvar
	task.delay(1.5, function()
		if token == tokenSalvar and salvarFn then
			salvarFn(table.clone(Ajustes.valores))
		end
	end)
end

return Ajustes
