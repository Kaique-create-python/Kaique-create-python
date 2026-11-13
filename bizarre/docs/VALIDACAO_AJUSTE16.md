# Verificação AJUSTE-16

Verificação offline Lune/Python. Sem chave ou chamada autenticada/publicação Roblox.

- Módulos reais de combate: perfil para seis Stands, buffer/cancel/seguimento; bomba/eco
  com atribuição original e dano após nova ação; morte/troca invalidam efeitos.
- Vínculos: duas prisões, liberação adiada por tempo parado, morte do dono, geração
  substituída e limpeza antiga sem interromper agarrão novo.
- Receitas: todos os slots CD/KQ e eventos usam templates dos catálogos reais14/15.
  Poses próprias amostradas com valores finitos; câmera própria<=0,9s e devolução de FOV.
- Instâncias reais: cópias sem código/juntas, partes ancoradas sem colisão/query; mapa
  original imóvel, retorno dos fragmentos, prisão acompanhando vítima e troca de geração.
- Rajadas: braços/mesh originais, movimento para frente, pausa/retomada e limpeza;
  previsão/ACK sem reinício, final4,35s/fim4,6s e parada de voz na interrupção.
- Prévia: seleção dos seis Stands, cancelamento próprio, ausência de comandos de combate,
  dano, áudio/câmera; parar uma prévia não interrompe uma rajada real.
- Instalador: estado16, confirmação16, pendente15 preservado, Saved antes de teste,
  resume sem segundo POST. Fontes desconhecidas continuam bloqueadas.
- Migração completa14/15→16: idempotente; objetos/pais, chunks opacos/propriedades e
  catálogos anteriores preservados. Fixture14 é o Place13 original com patch14; não é
  um backup ao vivo. Hashes e contagens finais em ENTREGA_AJUSTE16.json.

Morioh, Camera, Golpes/Regras, AnimacoesDono e Dados comparados byte a byte às bases.
O teste nativo também confere fontes/catálogos, seis kits e acrescenta prisão+tempo,
restauração sem destroços e poses. Ele precisa ser executado por Kaique no Termux.
Os testes locais controlam relógio, sinais e fronteiras sem física de Roblox.
A revisão final é estática independente; não substitui a avaliação visual no cliente.
