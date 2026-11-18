#!/usr/bin/env python3
"""Projeto Bastião — correção 2 da ETAPA 3.
Volta o CriaturaCore.luau ao original (o Place já tem esse script na versão Saved 12 e o
instalador só aceita trocar script cuja fonte ele conhece). A correção do teste na nuvem
(teste_nuvem.luau) continua. Não usa chave, não envia nada, não publica nada.
"""
import pathlib, shutil

base = pathlib.Path.home() / ".bastiao_etapa3"
achou = False
for p in sorted(base.glob("pacote_*")):
    core = p / "src/server/CriaturaCore.luau"
    bak = p / "src/server/CriaturaCore.luau.antes_correcao"
    if not core.is_file():
        continue
    achou = True
    if bak.is_file():
        shutil.copy2(bak, core)
        bak.unlink()
        print(p.name, "- CriaturaCore.luau: voltou ao original")
    elif "clip.duration + 1e-6" in core.read_text(encoding="utf-8"):
        s = core.read_text(encoding="utf-8").replace(
            "and marker.time >= 0 and marker.time <= clip.duration + 1e-6 then",
            "and marker.time >= 0 and marker.time < clip.duration then")
        core.write_text(s, encoding="utf-8")
        print(p.name, "- CriaturaCore.luau: voltou ao original")
    else:
        print(p.name, "- CriaturaCore.luau: já estava original")
    t = (p / "src/teste_nuvem.luau").read_text(encoding="utf-8")
    print("   teste_nuvem.luau:", "corrigido (ok)" if "local podePlayer" in t else "SEM correção: rode antes CORRIGIR_ETAPA3.py")
if not achou:
    raise SystemExit("ERRO: não achei a pasta do pacote em ~/.bastiao_etapa3.")
print("PRONTO. Agora rode:  python ~/storage/downloads/BASTIAO_ETAPA3.py testar-nuvem")
