"""Correção 15: acrescenta ao Textos.luau as falas, objetivos, prompts e o cartão final do capítulo 3
(A Guarnição, parte 1) em PT/EN/RU."""
import re, sys
from pathlib import Path
arq = Path(sys.argv[1]); t = arq.read_text()
NOVO = {
 "pt": dict(
  falas=dict(pavel_c3_chegada="Esse andar não existe em planta nenhuma. A placa diz Guarnição 7... era a minha unidade.",
             pavel_c3_quartel="O alojamento. O tenente Orlov guardava o cartão do arsenal no bolso. Procurem o corpo dele.",
             pavel_c3_blackout="A luz caiu! Eles estão acordando... não são mais homens! Atirem na cabeça!",
             pavel_c3_limpo="Acabou... por enquanto. Eram meus companheiros. O arsenal fica no fim do corredor.",
             pavel_c3_arsenal="O cartão funcionou. O que tiver aqui dentro vai ter que bastar para o que vem lá embaixo."),
  objetivos=dict(cap3_explorar="Explore o andar sem número", cartao="Encontre o cartão do arsenal no corpo do tenente",
                 sobreviver="Sobreviva: mate todos os infectados", arsenal="Abra o arsenal com o cartão"),
  prompts=dict(PegarCartao="PEGAR CARTÃO", UsarCartao="USAR CARTÃO"),
  fim=dict(capitulo="CAPÍTULO 3 — A GUARNIÇÃO", linha="FIM DA PARTE 1 · O ARSENAL GUARDA MAIS DO QUE ARMAS")),
 "en": dict(
  falas=dict(pavel_c3_chegada="This floor isn't on any blueprint. The sign says Garrison 7... that was my unit.",
             pavel_c3_quartel="The barracks. Lieutenant Orlov kept the armory card in his pocket. Find his body.",
             pavel_c3_blackout="The power's gone! They're waking up... they're not men anymore! Aim for the head!",
             pavel_c3_limpo="It's over... for now. They were my comrades. The armory is at the end of the hall.",
             pavel_c3_arsenal="The card worked. Whatever is in here will have to be enough for what's down below."),
  objetivos=dict(cap3_explorar="Explore the unnumbered floor", cartao="Find the armory card on the lieutenant's body",
                 sobreviver="Survive: kill every infected", arsenal="Open the armory with the card"),
  prompts=dict(PegarCartao="TAKE CARD", UsarCartao="USE CARD"),
  fim=dict(capitulo="CHAPTER 3 — THE GARRISON", linha="END OF PART 1 · THE ARMORY HOLDS MORE THAN WEAPONS")),
 "ru": dict(
  falas=dict(pavel_c3_chegada="Этого этажа нет ни на одном чертеже. Табличка: Гарнизон-7... это было моё подразделение.",
             pavel_c3_quartel="Казарма. Лейтенант Орлов носил карту арсенала в кармане. Найдите его тело.",
             pavel_c3_blackout="Свет вырубило! Они просыпаются... это больше не люди! Стреляйте в голову!",
             pavel_c3_limpo="Всё... пока что. Это были мои товарищи. Арсенал в конце коридора.",
             pavel_c3_arsenal="Карта сработала. Того, что здесь есть, должно хватить на то, что ждёт внизу."),
  objetivos=dict(cap3_explorar="Исследуйте этаж без номера", cartao="Найдите карту арсенала у тела лейтенанта",
                 sobreviver="Выживите: убейте всех заражённых", arsenal="Откройте арсенал картой"),
  prompts=dict(PegarCartao="ВЗЯТЬ КАРТУ", UsarCartao="ПРИЛОЖИТЬ КАРТУ"),
  fim=dict(capitulo="ГЛАВА 3 — ГАРНИЗОН", linha="КОНЕЦ ЧАСТИ 1 · В АРСЕНАЛЕ НЕ ТОЛЬКО ОРУЖИЕ")),
}
def lua(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
def depois(seg, chave, extra):
    m = re.search(r"^(\t+)" + re.escape(chave) + r" = .*$", seg, re.M)
    assert m, chave
    ind = m.group(1)
    return seg[:m.end()] + "".join("\n" + ind + k + " = " + lua(v) + "," for k, v in extra.items()) + seg[m.end():]
m = re.search(r'^\tpavel_descida = "PAVEL",$', t, re.M); assert m
t = t[:m.end()] + "".join(f'\n\t{k} = "PAVEL",' for k in NOVO["pt"]["falas"]) + t[m.end():]
partes = re.split(r"(?m)^(?=L\.(?:pt|en|ru) = \{)", t)
saida = [partes[0]]
for seg in partes[1:]:
    n = NOVO[seg[2:4]]
    seg = depois(seg, "pavel_descida", n["falas"])
    seg = depois(seg, "elevador_volta", n["objetivos"])
    seg = depois(seg, "Religar", n["prompts"])
    for k in ("capitulo", "linha"):
        seg, q = re.subn(r"(?m)^(\t\t" + k + r" = ).*$", lambda mm: mm.group(1) + lua(n["fim"][k]) + ",", seg, count=1)
        assert q == 1, k
    saida.append(seg)
novo = "".join(saida)
assert novo.count("pavel_c3_arsenal") == 4 and novo.count("UsarCartao") == 3
arq.write_text(novo)
print("Textos: +5 falas, +4 objetivos, +2 prompts e o cartão final do capítulo 3 (pt/en/ru)")
