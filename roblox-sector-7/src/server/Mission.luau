local Mission = {}
function Mission.new()
    return {collected={},fuses=0,power=false,keycard=false,escaped=false}
end
function Mission.attempt(state, id)
    if id == "Fuse1" or id == "Fuse2" or id == "Fuse3" then
        if state.collected[id] then return false, "Este fusível já foi recolhido." end
        state.collected[id] = true
        state.fuses += 1
        return true, "Fusível recuperado. " .. state.fuses .. "/3"
    elseif id == "Generator" then
        if state.power then return false, "O gerador já está funcionando." end
        if state.fuses < 3 then return false, "Encontre os três fusíveis antes de ligar o gerador." end
        state.power = true
        return true, "Energia restaurada. Procure o cartão no arquivo. Algo acordou nos túneis."
    elseif id == "Keycard" then
        if not state.power then return false, "O arquivo está sem energia. Restaure o gerador." end
        if state.keycard then return false, "O cartão já foi recuperado." end
        state.keycard = true
        return true, "Cartão de evacuação recuperado. Siga até a porta do Setor 7."
    elseif id == "Exit" then
        if state.escaped then return false, "A saída já está aberta. Atravesse para evacuar." end
        if not state.power or not state.keycard then return false, "A saída precisa de energia e do cartão de evacuação." end
        state.escaped = true
        return true, "A porta foi liberada. Atravesse para evacuar."
    end
    return false, "Interação desconhecida."
end
return Mission
