"""Correção 14: acrescenta ao Textos.luau (versão da correção 11) as falas, objetivos, prompts, avisos
e o cartão final do capítulo 2, parte 2 (a subestação), em PT/EN/RU."""
import re, sys
from pathlib import Path
arq = Path(sys.argv[1]); t = arq.read_text()
NOVO = {
 "pt": dict(
  falas=dict(pavel_sub_ir="A subestação fica dois níveis abaixo das utilidades. Rampa de serviço. Fiquem colados em mim.",
             pavel_sub_chegou="O disjuntor principal queimou. Tem fusível de reserva nas caixas da parede. Precisamos de três.",
             pavel_sub_fusiveis="Três. No painel. Quando eu puxar essa alavanca, a luz volta... e ele vai saber onde a gente está.",
             pavel_sub_luz="Energia! O elevador acordou. Correndo, de volta para a porta blindada! Ele ouviu!",
             pavel_descida="Esse painel só tem um botão, e ele não tem número. Segurem-se. Isso não estava na planta."),
  objetivos=dict(subestacao="Desça até a subestação pela porta de manutenção", fusiveis="Encontre os 3 fusíveis nas caixas e coloque no painel",
                 disjuntor="Puxe a alavanca do disjuntor principal", elevador_volta="Volte correndo para o elevador na porta blindada"),
  prompts=dict(PegarFusivel="PEGAR FUSÍVEL", ColocarFusiveis="COLOCAR FUSÍVEIS", Religar="RELIGAR DISJUNTOR"),
  avisos=dict(fusivel_1="Fusível 1 de 3.", fusivel_2="Fusível 2 de 3.", fusivel_3="Fusível 3 de 3. Leve ao painel principal."),
  fim=dict(linha="FIM DO CAPÍTULO 2 · O CAPÍTULO 3 COMEÇA NO ANDAR SEM NÚMERO")),
 "en": dict(
  falas=dict(pavel_sub_ir="The substation is two levels below the utilities room. Service ramp. Stay close to me.",
             pavel_sub_chegou="The main breaker blew. There are spare fuses in the wall boxes. We need three.",
             pavel_sub_fusiveis="Three. Into the panel. When I pull this lever the lights come back... and it'll know where we are.",
             pavel_sub_luz="Power! The elevator's awake. Run, back to the blast door! It heard us!",
             pavel_descida="This panel has one button, and it has no number. Hold on. This wasn't on the blueprints."),
  objetivos=dict(subestacao="Go down to the substation through the maintenance door", fusiveis="Find the 3 fuses in the boxes and put them in the panel",
                 disjuntor="Pull the main breaker lever", elevador_volta="Run back to the elevator at the blast door"),
  prompts=dict(PegarFusivel="TAKE FUSE", ColocarFusiveis="INSERT FUSES", Religar="RESET BREAKER"),
  avisos=dict(fusivel_1="Fuse 1 of 3.", fusivel_2="Fuse 2 of 3.", fusivel_3="Fuse 3 of 3. Take them to the main panel."),
  fim=dict(linha="END OF CHAPTER 2 · CHAPTER 3 BEGINS ON THE UNNUMBERED FLOOR")),
 "ru": dict(
  falas=dict(pavel_sub_ir="Подстанция двумя уровнями ниже техзала. Служебный спуск. Держитесь рядом со мной.",
             pavel_sub_chegou="Главный автомат сгорел. В щитках на стене есть запасные предохранители. Нужно три.",
             pavel_sub_fusiveis="Три. В щит. Когда я опущу этот рычаг, свет вернётся... и он поймёт, где мы.",
             pavel_sub_luz="Есть питание! Лифт ожил. Бегом к гермодвери! Он услышал!",
             pavel_descida="На этой панели одна кнопка, и на ней нет номера. Держитесь. Этого не было в чертежах."),
  objetivos=dict(subestacao="Спуститесь на подстанцию через служебную дверь", fusiveis="Найдите 3 предохранителя в щитках и вставьте в щит",
                 disjuntor="Опустите рычаг главного автомата", elevador_volta="Бегом обратно к лифту у гермодвери"),
  prompts=dict(PegarFusivel="ВЗЯТЬ ПРЕДОХРАНИТЕЛЬ", ColocarFusiveis="ВСТАВИТЬ ПРЕДОХРАНИТЕЛИ", Religar="ВКЛЮЧИТЬ АВТОМАТ"),
  avisos=dict(fusivel_1="Предохранитель 1 из 3.", fusivel_2="Предохранитель 2 из 3.", fusivel_3="Предохранитель 3 из 3. Несите к главному щиту."),
  fim=dict(linha="КОНЕЦ ГЛАВЫ 2 · ГЛАВА 3 НАЧНЁТСЯ НА ЭТАЖЕ БЕЗ НОМЕРА")),
}
def lua(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
def depois(seg, chave, extra):
    m = re.search(r"^(\t+)" + re.escape(chave) + r" = .*$", seg, re.M)
    assert m, chave
    ind = m.group(1)
    return seg[:m.end()] + "".join("\n" + ind + k + " = " + lua(v) + "," for k, v in extra.items()) + seg[m.end():]
m = re.search(r'^\tpavel_elevador = "PAVEL",$', t, re.M); assert m
t = t[:m.end()] + "".join(f'\n\t{k} = "PAVEL",' for k in NOVO["pt"]["falas"]) + t[m.end():]
partes = re.split(r"(?m)^(?=L\.(?:pt|en|ru) = \{)", t)
saida = [partes[0]]
for seg in partes[1:]:
    n = NOVO[seg[2:4]]
    seg = depois(seg, "pavel_elevador", n["falas"])
    seg = depois(seg, "porta_blindada", n["objetivos"])
    seg = depois(seg, "PegarMunicao", n["prompts"])
    seg = depois(seg, "municao_cheia", n["avisos"])
    seg, q = re.subn(r"(?m)^(\t\tlinha = ).*$", lambda mm: mm.group(1) + lua(n["fim"]["linha"]) + ",", seg, count=1)
    assert q == 1
    saida.append(seg)
novo = "".join(saida)
assert novo.count("pavel_descida") == 4 and novo.count("ColocarFusiveis") == 3
arq.write_text(novo)
print("Textos: +5 falas, +4 objetivos, +3 prompts, +3 avisos e o cartão final do capítulo 2 (pt/en/ru)")
