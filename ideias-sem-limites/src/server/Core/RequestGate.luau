--!strict
-- Porteiro dos pedidos vindos do cliente. Nunca confia no cliente:
--   * tipo e tamanho do texto, UTF-8 válido, sem caracteres de controle
--   * cooldown por jogador (relógio do servidor)
--   * detecção de spam de RemoteFunction com bloqueio temporário
--   * limite global de ideias por janela de tempo no servidor

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.IdeiasShared.Config)
local Normalizer = require(ReplicatedStorage.IdeiasShared.Text.Normalizer)

local RequestGate = {}

type State = { lastOk: number, hits: { number }, mutedUntil: number }

local states: { [any]: State } = {}
local globalHits: { number } = {}

local function stateFor(key: any): State
	local s = states[key]
	if not s then
		s = { lastOk = -math.huge, hits = {}, mutedUntil = 0 }
		states[key] = s
	end
	return s
end

local function prune(list: { number }, window: number, now: number)
	while list[1] and now - list[1] > window do
		table.remove(list, 1)
	end
end

export type Verdict = { ok: boolean, reason: string?, wait: number?, text: string? }

-- key: Player (ou qualquer chave nos testes); clock: relógio (injetável em testes)
function RequestGate.check(key: any, raw: any, clock: number?): Verdict
	local now = clock or os.clock()
	local s = stateFor(key)
	local R = Config.Request

	-- spam: conta TODAS as chamadas, inclusive inválidas
	prune(s.hits, R.SpamWindow, now)
	table.insert(s.hits, now)
	if now < s.mutedUntil then
		return { ok = false, reason = "spam", wait = s.mutedUntil - now }
	end
	if #s.hits > R.SpamMaxRequests then
		s.mutedUntil = now + R.SpamMute
		return { ok = false, reason = "spam", wait = R.SpamMute }
	end

	if type(raw) ~= "string" then
		return { ok = false, reason = "invalid" }
	end
	if #raw > R.MaxRawLength * 4 then
		return { ok = false, reason = "too_long" }
	end
	local text = Normalizer.sanitize(raw, R.MaxTextLength)
	if not text then
		return { ok = false, reason = "empty" }
	end

	local since = now - s.lastOk
	if since < R.Cooldown then
		return { ok = false, reason = "cooldown", wait = R.Cooldown - since }
	end

	prune(globalHits, R.GlobalWindow, now)
	if #globalHits >= R.GlobalMaxRequests then
		return { ok = false, reason = "busy", wait = R.GlobalWindow - (now - globalHits[1]) }
	end

	s.lastOk = now
	table.insert(globalHits, now)
	return { ok = true, text = text }
end

function RequestGate.forget(key: any)
	states[key] = nil
end

function RequestGate.reset()
	table.clear(states)
	table.clear(globalHits)
end

RequestGate.Messages = {
	spam = "Calma! Muitos pedidos seguidos. Aguarde alguns segundos.",
	invalid = "Pedido inválido.",
	too_long = "Texto longo demais.",
	empty = "Digite uma ideia primeiro.",
	cooldown = "Aguarde a recarga.",
	busy = "O servidor está criando muitas ideias. Tente em instantes.",
	full = "O mundo está cheio. Aguarde algumas ideias sumirem.",
}

return RequestGate
