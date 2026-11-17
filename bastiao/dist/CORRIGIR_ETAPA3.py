#!/usr/bin/env python3
"""Projeto Bastião — correção do teste na nuvem da ETAPA 3 (pacote do ChatGPT).

Conserta, NA PASTA JÁ EXTRAÍDA (para não perder os recibos dos assets já enviados):
  1) tabela de áudio: o 3º campo do trecho é o NOME do sprite, não o ID;
  2) marcador no fim exato do clipe (ex.: 10_FREAR) era recusado;
  3) a nuvem não deixa criar Player: o fluxo com jogadores vira aviso, o resto é testado.
Não usa chave nenhuma, não envia nada, não publica nada.
"""
import pathlib, shutil, sys

R = [
 ('audioReal(seg[3] or Audio.ids["voz_" .. idioma], seg[1], seg[2], idioma .. "/" .. chave)',
  'audioReal(Audio.ids[seg[3] or ("voz_" .. idioma)], seg[1], seg[2], idioma .. "/" .. chave)'),
 ('audioReal(trecho[3] or Audio.ids.efeitos, trecho[1], trecho[2], nome)',
  'audioReal(Audio.ids[trecho[3] or "efeitos"], trecho[1], trecho[2], nome)'),
 ('and marker.time >= 0 and marker.time < clip.duration, "marcador inválido: " .. nome)',
  'and marker.time >= 0 and marker.time <= clip.duration + 1e-6, "marcador inválido: " .. nome)'),
 ('local fixtures = {}\nif not checar("fixtures Player reais", function()',
  'local pavelReal = nil\nlocal fluxoOk = nil\n'
  '-- A execução Luau da Open Cloud não tem a permissão WritePlayer: lá não dá para criar Player.\n'
  'local podePlayer = pcall(function() Instance.new("Player"):Destroy() end)\n'
  'if not podePlayer then\n'
  '\taviso("Nuvem sem permissão para criar Player: o fluxo com jogadores fica para o servidor ao vivo.")\n'
  'end\n'
  'if podePlayer then\n'
  'local fixtures = {}\nif not checar("fixtures Player reais", function()'),
 ('\nlocal pavelReal = nil\nlocal pavelProxy\n', '\npavelReal = nil\nlocal pavelProxy\n'),
 ('local fluxoOk = checar("fluxo da abertura", function()', 'fluxoOk = checar("fluxo da abertura", function()'),
 ('out.info.fluxo = fluxoOk\n',
  'out.info.fluxo = fluxoOk\nend\n'
  'if not podePlayer and not aoVivo then\n'
  '\tchecar("criar o Pavel no motor", function()\n'
  '\t\tpavelReal = Pavel.criar(pasta, function(m)\n'
  '\t\t\tfalha(m)\n'
  '\t\tend)\n'
  '\t\tassert(pavelReal.rig and pavelReal.rig.Parent == pasta, "rig do Pavel não foi criado")\n'
  '\tend)\n'
  'end\n'),
]

CORE = [("and marker.time >= 0 and marker.time < clip.duration then",
         "and marker.time >= 0 and marker.time <= clip.duration + 1e-6 then")]


def aplicar(arq, trocas, marca):
    s = arq.read_text(encoding="utf-8")
    if marca in s:
        return "já estava corrigido"
    for a, b in trocas:
        if s.count(a) != 1:
            raise SystemExit("ERRO: trecho esperado não encontrado em " + arq.name + ". Nada foi alterado neste arquivo.")
    bak = arq.with_name(arq.name + ".antes_correcao")
    if not bak.exists():
        shutil.copy2(arq, bak)
    for a, b in trocas:
        s = s.replace(a, b)
    arq.write_text(s, encoding="utf-8")
    return "corrigido"


base = pathlib.Path.home() / ".bastiao_etapa3"
pacotes = sorted(p for p in base.glob("pacote_*") if (p / "instalar.py").is_file() and (p / "src/teste_nuvem.luau").is_file())
if not pacotes:
    raise SystemExit("ERRO: não achei a pasta do pacote em ~/.bastiao_etapa3. Rode antes: python ~/storage/downloads/BASTIAO_ETAPA3.py status")
for p in pacotes:
    print("Pacote:", p.name)
    print("  teste_nuvem.luau:", aplicar(p / "src/teste_nuvem.luau", R, "local podePlayer"))
    print("  CriaturaCore.luau:", aplicar(p / "src/server/CriaturaCore.luau", CORE, "clip.duration + 1e-6"))
print("PRONTO. Agora rode:  python ~/storage/downloads/BASTIAO_ETAPA3.py testar-nuvem")
