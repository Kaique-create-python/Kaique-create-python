# BIZARRE AJUSTE-16

Crazy Diamond e Killer Queen recebem o perfil responsivo e animações/efeitos próprios.
ORA/MUDA usam o vídeo enviado como referência: postura avançada, braços alternados,
cópias reais dos braços e acessórios do Stand, pressão e aura forte. O alvo continua
visível no centro. Duração4,6s e golpe final4,35s preservados.

- CD: DORA, disparo de cacos, restauração com cópias cosméticas de peças reais,
  prisão seguindo a vítima e ULT. O cliente não move as peças de colisão do mapa.
- KQ: toque/marca, explosão, tanque guiado, moeda, eco e rebobinamento. Explosões
  confirmadas conservam o golpe original após outra ação; morte/troca invalida vínculos. Projéteis CD/KQ também encerram ao sair/trocar;
  a reflexão transfere a propriedade individual e mantém a aparência original.
- Prisões sobrepostas e tempo parado têm liberações independentes. Limpeza antiga não
  interrompe um agarrão novo do mesmo ator.
- ADM → PRÉVIA VFX: seis Stands, reproduzir e parar, incluindo braços das rajadas quando
  o modelo do Stand estiver carregado. Prévia sem dano/remotos/som de ataque/câmera;
  parar a prévia não cancela o combate em andamento.
- Cenas de ULT próprias de CD/KQ limitadas a0,9s. Mira/Shift Lock e distância aprovadas,
  R6, andar/correr, números de Golpes, Morioh, dados e mídias preservados.

Os efeitos usam os catálogos14/15 existentes, sem novo upload. Os clipes R6 são próprios:
foi encontrado o modelo público16663903306, mas seus dados não puderam ser inspecionados
pela ferramenta disponível. Nenhum ID de animação de terceiro foi colocado às cegas.
Sem redução automática de qualidade por FPS.

## Termux

Preserve `~/.bizarre_instalador` inteira. Se ainda houver envio15 pendente, resolva antes:

```sh
python ~/BIZARRE_AJUSTE15.py resume
```

A16 bloqueia esse recibo e informa o instalador correto; não apague active-write.json.
Após `Saved confirmado`/`PUBLICADO E VERIFICADO`, pode testar diretamente a16:

```sh
gh api 'repos/Kaique-create-python/Kaique-create-python/contents/bizarre/dist/BIZARRE_AJUSTE16.py?ref=claude/context-capture-w0uo2t' -H 'Accept: application/vnd.github.raw+json' > ~/BIZARRE_AJUSTE16.py
python ~/BIZARRE_AJUSTE16.py testar
python ~/BIZARRE_AJUSTE16.py testar-nuvem
```

A chave é pedida oculta no Termux e não é salva. Sem repetir setup/assets-upload.
Se faltar zstd: `pkg install zstd`. Testar-nuvem cria Saved quando necessário; preserva
Published e o backup completo. Fonte desconhecida bloqueia para análise.

Depois de **TESTE APROVADO**, sem salvamento concorrente:

```sh
python ~/BIZARRE_AJUSTE16.py publicar
```

Confirme `PUBLICAR AJUSTE16`; espere **PUBLICADO E VERIFICADO** e entre em servidor novo.
Resposta incerta: `python ~/BIZARRE_AJUSTE16.py resume`. Esse comando só consulta; não
repetir publicação nem excluir recibos. Nunca passar a chave pelo chat ou como argumento.

## Conferência no jogo

Teste CD/KQ contra alvo, parede, bloqueio e parry, com/sem destroços, morte/troca durante
prisão, tanque girando e bombas após M1. Confira rebobinamento com/sem histórico.
Compare ORA/MUDA no treino: animação, contato/erro/defesa/clash, final e fim do som,
interrupção e tempo parado. Confira os outros quatro kits e controles no celular.

Testes locais não são uma partida nem uma renderização do Roblox. Execução autenticada,
física, autorização de texturas e aparência/FPS no Android permanecem pendentes.
Build: `python3 bizarre/tools/gerar_ajuste16.py`, da raiz. Bases conhecidas14/15 em
installer14/baseline14.json e baseline15.json; fontes em src/. Nomes internos14/15
continuam por compatibilidade; entrega, confirmação e estado são16.
