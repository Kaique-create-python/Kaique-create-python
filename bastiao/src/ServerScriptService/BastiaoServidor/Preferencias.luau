--!strict
-- PROJETO BASTIÃO :: Preferencias (língua das vozes e legendas de cada jogador)
-- Começa pela língua da conta Roblox (pt/ru/en) e troca pelo menu da bodycam. A escolha fica
-- num DataStore próprio e pequeno ("BastiaoPreferencias_v1"); nenhum outro dado é lido, mudado
-- ou apagado. Se o DataStore falhar, o jogo segue com a língua da conta.

local DataStoreService = game:GetService("DataStoreService")

local Preferencias = {}
Preferencias.__index = Preferencias

local NOME_STORE = "BastiaoPreferencias_v1"
local ESPERA_GRAVAR = 6 -- várias trocas seguidas viram uma escrita só

export type Opcoes = {
	textos: any,
	atributo: string,
	log: ((string) -> ())?,
}

function Preferencias.novo(op: Opcoes)
	local self = setmetatable({}, Preferencias)
	self.op = op
	self.log = op.log or function(_m: string) end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(NOME_STORE)
	end)
	self.store = if ok then store else nil
	self.pendentes = {} :: { [number]: string }
	self.ultimaTroca = {} :: { [number]: number }
	self.trocou = {} :: { [number]: boolean }
	return self
end

function Preferencias:carregar(jogador: Player)
	local inicial = self.op.textos.daLocalidade(jogador.LocaleId)
	jogador:SetAttribute(self.op.atributo, inicial)
	if not self.store then
		return
	end
	task.spawn(function()
		local ok, valor = pcall(function()
			return self.store:GetAsync("u" .. jogador.UserId)
		end)
		-- se o jogador já trocou nesta sessão, a troca vale mais que o salvo
		if ok and type(valor) == "table" and jogador.Parent and not self.trocou[jogador.UserId] then
			local salvo = valor.idioma
			if type(salvo) == "string" and self.op.textos.L[salvo] then
				jogador:SetAttribute(self.op.atributo, salvo)
			end
		elseif not ok then
			self.log("[Bastiao] preferência não carregou: " .. tostring(valor))
		end
	end)
end

function Preferencias:trocar(jogador: Player, idioma: any): boolean
	if type(idioma) ~= "string" or not self.op.textos.L[idioma] then
		return false
	end
	local agora = os.clock()
	local antes = self.ultimaTroca[jogador.UserId]
	if antes and agora - antes < 0.4 then
		return false
	end
	self.ultimaTroca[jogador.UserId] = agora
	self.trocou[jogador.UserId] = true
	jogador:SetAttribute(self.op.atributo, idioma)
	self.pendentes[jogador.UserId] = idioma
	local id = jogador.UserId
	task.delay(ESPERA_GRAVAR, function()
		self:_gravar(id)
	end)
	return true
end

function Preferencias:_gravar(userId: number)
	local idioma = self.pendentes[userId]
	if not idioma or not self.store then
		return
	end
	self.pendentes[userId] = nil
	local ok, err = pcall(function()
		self.store:SetAsync("u" .. userId, { idioma = idioma, v = 1 })
	end)
	if not ok then
		self.log("[Bastiao] preferência não salva: " .. tostring(err))
	end
end

function Preferencias:saiu(jogador: Player)
	self:_gravar(jogador.UserId)
	self.ultimaTroca[jogador.UserId] = nil
	self.trocou[jogador.UserId] = nil
end

return Preferencias
