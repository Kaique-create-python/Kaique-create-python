-- BIZARRE BATTLEGROUNDS :: sessões de tempo parado (AJUSTE7)
-- Cada "tempo parado" é uma sessão com dono e número. Uma ULT nunca sobrescreve nem libera os
-- alvos de outra sessão; quando a sessão acaba (ou o dono morre/sai), só os alvos DELA voltam.

local Treino17=require(game:GetService("ReplicatedStorage"):WaitForChild("BB"):WaitForChild("Laboratorio17"))
local TempoSessao = {}

local proximo = 0

function TempoSessao.nova(dono: any, fim: number): any
	proximo += 1
	return { id = proximo, dono = dono, fim = fim, ativa = true, alvos = {}, vida14=dono and dono.vida14 }
end

-- congela quem ainda não está congelado por OUTRA sessão ativa; devolve quem entrou nesta
function TempoSessao.congelar(sessao: any, candidatos: { any }): { any }
	local entraram = {}
	for _, l in candidatos do
  if not Treino17.permite(sessao.dono or {},l)then continue end
		local outra = l.sessaoTempo
		if outra and outra ~= sessao and outra.ativa then
			continue -- já está parado por outra ULT: não mexe
		end
		l.sessaoTempo = sessao
		table.insert(sessao.alvos, l)
		table.insert(entraram, l)
	end
	return entraram
end

-- encerra a sessão; devolve só os alvos que ainda são dela (para soltar)
function TempoSessao.encerrar(sessao: any): { any }
	if not sessao.ativa then
		return {}
	end
	sessao.ativa = false
	local soltar = {}
	for _, l in sessao.alvos do
		if l.sessaoTempo == sessao then
			l.sessaoTempo = nil
			table.insert(soltar, l)
		end
	end
	sessao.alvos = {}
	return soltar
end

-- o dono ainda pode manter o tempo parado?
function TempoSessao.donoVivo(sessao: any): boolean
	local d = sessao.dono
	return d ~= nil and d.vida14==sessao.vida14 and d.hum ~= nil and d.hum.Health > 0 and d.modelo ~= nil and d.modelo.Parent ~= nil
end

return TempoSessao
