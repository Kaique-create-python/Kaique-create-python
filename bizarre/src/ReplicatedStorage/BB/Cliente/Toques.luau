-- BIZARRE BATTLEGROUNDS :: botões de segurar que nunca ficam presos (AJUSTE7)
-- Solta quando: o dedo sai da tela (mesmo fora do botão), o jogo perde o foco, o menu abre,
-- o botão é refeito (tela girou) ou outro dedo aperta o mesmo botão.

local Toques = {}

local todos: { any } = {}

function Toques.novo(aoApertar: () -> (), aoSoltar: (() -> ())?): any
	local t = { preso = nil :: any }
	function t.comecar(entrada: any, ehMouse: boolean?)
		if t.preso ~= nil then
			t.soltar()
		end
		aoApertar()
		if aoSoltar then
			t.preso = entrada or true
			t.mouse = ehMouse == true
		end
	end
	-- termina só se for o mesmo dedo que apertou (outro dedo levantando não solta)
	function t.terminar(entrada: any)
		if t.preso ~= nil and (entrada == nil or t.preso == true or t.preso == entrada) then
			t.soltar()
		end
	end
	function t.soltar()
		if t.preso == nil then
			return
		end
		t.preso = nil
		if aoSoltar then
			aoSoltar()
		end
	end
	table.insert(todos, t)
	return t
end

-- um dedo (ou o botão do mouse) saiu da tela em QUALQUER lugar: solta o botão que ele segurava
function Toques.terminou(entrada: any, ehMouse: boolean?)
	for _, t in todos do
		if t.preso ~= nil and (t.preso == entrada or (ehMouse and t.mouse)) then
			t.soltar()
		end
	end
end

-- foco perdido, menu aberto, tela girou: solta todos os botões presos
function Toques.soltarTudo()
	for _, t in todos do
		t.soltar()
	end
end

function Toques.esquecerTodos()
	Toques.soltarTudo()
	todos = {}
end

return Toques
