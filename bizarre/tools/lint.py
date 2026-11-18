#!/usr/bin/env python3
"""BIZARRE :: procura nomes usados sem declarar (erro que o compilador não pega e só apareceria
dentro do Roblox). Simples de propósito: um nome conta como declarado se aparece em qualquer
'local', parâmetro, 'for' ou 'function' do arquivo. uso: python3 bizarre/tools/lint.py"""
import os
import re
import sys

RAIZ = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src")
GLOBAIS = set("""game workspace script Instance Vector3 Vector2 CFrame Color3 ColorSequence ColorSequenceKeypoint
NumberSequence NumberSequenceKeypoint NumberRange UDim UDim2 Rect Ray Font Enum TweenInfo Random OverlapParams
RaycastParams task typeof print warn tick time os math string table utf8 coroutine pcall xpcall error assert
pairs ipairs next select tostring tonumber type setmetatable getmetatable rawget rawset rawequal unpack buffer
bit32 debug require true false nil and or not if then else elseif end for while do repeat until function local
return break continue in self number boolean any Model BasePart Part Player Humanoid Attachment DataStore
TextLabel TextButton Frame ScreenGui GuiObject RemoteEvent Sound Folder Motor6D LinearVelocity Camera
BillboardGui ViewportFrame ColorCorrectionEffect InputObject RBXScriptConnection Color DateTime PhysicalProperties
BrickColor Region3 Faces Axes shared _G _VERSION newproxy gcinfo collectgarbage loadstring getfenv setfenv
never unknown thread userdata vector""".split())


def limpar(src):
    src = re.sub(r"--\[\[.*?\]\]", " ", src, flags=re.S)
    src = re.sub(r"--[^\n]*", " ", src)
    src = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', src)
    src = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", src)
    src = re.sub(r"`(?:\\.|[^`\\])*`", "``", src)
    return src


def declarados(src):
    nomes = set()
    for m in re.finditer(r"\blocal\s+function\s+([A-Za-z_]\w*)", src):
        nomes.add(m.group(1))
    for m in re.finditer(r"\blocal\s+([A-Za-z_][\w\s,:<>\[\]{}()?|&.\-]*?)(?==|\n|$)", src):
        for parte in re.split(r",", m.group(1)):
            n = re.match(r"\s*([A-Za-z_]\w*)", parte)
            if n:
                nomes.add(n.group(1))
    # Tipos de callback têm parênteses próprios: não encerrar a assinatura no () -> ().
    for m in re.finditer(r"\bfunction\b[^(\n]*\(", src):
        depth, start, end = 1, m.end(), m.end()
        while end < len(src) and depth:
            if src[end] == "(":
                depth += 1
            elif src[end] == ")":
                depth -= 1
            end += 1
        if depth:
            continue
        for parte in src[start:end - 1].split(","):
            n = re.match(r"\s*([A-Za-z_]\w*)", parte)
            if n:
                nomes.add(n.group(1))
    for m in re.finditer(r"\bfor\s+([^=\n]*?)(?:\s+in\b|\s*=)", src):
        for parte in m.group(1).split(","):
            n = re.match(r"\s*([A-Za-z_]\w*)", parte)
            if n:
                nomes.add(n.group(1))
    for m in re.finditer(r"\bfunction\s+([A-Za-z_]\w*)", src):
        nomes.add(m.group(1))
    for m in re.finditer(r"\btype\s+([A-Za-z_]\w*)", src):
        nomes.add(m.group(1))
    return nomes


def main():
    ruins = 0
    for pasta, _, arquivos in os.walk(RAIZ):
        for arq in sorted(arquivos):
            if not arq.endswith(".luau"):
                continue
            caminho = os.path.join(pasta, arq)
            src = limpar(open(caminho, encoding="utf-8").read())
            dec = declarados(src) | GLOBAIS
            vistos = set()
            for n_linha, linha in enumerate(src.split("\n"), 1):
                for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)", linha):
                    nome = m.group(1)
                    if nome in dec or nome in vistos:
                        continue
                    resto = linha[m.end():]
                    antes = linha[:m.start()].rstrip()
                    # campo de tabela ({ nome = ...}) ou anotação de tipo (x: Tipo, :: Tipo, -> Tipo)
                    if re.match(r"\s*=(?!=)", resto) and (antes.endswith(("{", ",")) or antes == ""):
                        continue
                    if antes.endswith((":", "::", "->", "|", "&", "<", "?")) or re.match(r"\s*[<>?]?\s*[,)}\]|]?\s*$", resto) and antes.endswith(("{", "[")):
                        continue
                    # anotação "nome: Tipo" (com espaço); chamada de método é "obj:Metodo" (sem espaço)
                    if re.match(r":\s", resto) or nome == "export":
                        continue
                    vistos.add(nome)
                    ruins += 1
                    print("%s:%d  nome sem declarar: %s" % (os.path.relpath(caminho, RAIZ), n_linha, nome))
    print("lint: %d suspeito(s)" % ruins)
    sys.exit(1 if ruins else 0)


if __name__ == "__main__":
    main()
