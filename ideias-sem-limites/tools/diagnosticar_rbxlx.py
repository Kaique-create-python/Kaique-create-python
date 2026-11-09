#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Diagnóstico de arquivos de lugar Roblox (.rbxlx / .rbxl) antes do envio ao Open Cloud.

Procura as causas conhecidas do erro 400 "Invalid Content stream" e outros
problemas de serialização, comparando o arquivo com a base de reflexão do Roblox
(classes, propriedades, tipos e valores de enum válidos).

Uso (Termux ou PC, só biblioteca padrão do Python 3):
  python3 diagnosticar_rbxlx.py ARQUIVO.rbxlx
  python3 diagnosticar_rbxlx.py V2.rbxlx --comparar V1.rbxlx
  python3 diagnosticar_rbxlx.py V2.rbxlx --bisseccao pasta_saida
  python3 diagnosticar_rbxlx.py V2.rbxlx --corrigir V2_corrigido.rbxlx
  python3 diagnosticar_rbxlx.py V2.rbxlx --json relatorio.json

Nunca altera o arquivo original. Códigos de saída: 0 = sem problemas graves,
1 = encontrou problema FATAL/ALTO, 2 = erro de uso.
"""

import argparse
import base64
import copy
import gzip
import json
import math
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

AQUI = os.path.dirname(os.path.abspath(__file__))
REFLEXAO_PADRAO = os.path.join(AQUI, "roblox_reflexao.json.gz")
LIMITE_BYTES = 100 * 1024 * 1024

SEVERIDADES = ["FATAL", "ALTO", "MEDIO", "INFO"]

# Tipo da base de reflexão -> tags XML aceitas
TAGS_POR_TIPO = {
    "Bool": {"bool"},
    "Int32": {"int", "int64"},
    "Int64": {"int64", "int"},
    "Float32": {"float", "double"},
    "Float64": {"double", "float"},
    "String": {"string", "ProtectedString"},
    "BinaryString": {"BinaryString"},
    "Attributes": {"BinaryString"},
    "Tags": {"BinaryString"},
    "MaterialColors": {"BinaryString"},
    "Axes": {"Axes"},
    "Faces": {"Faces"},
    "BrickColor": {"int", "BrickColor"},
    "CFrame": {"CoordinateFrame"},
    "OptionalCFrame": {"OptionalCoordinateFrame"},
    "Color3": {"Color3"},
    "Color3uint8": {"Color3uint8"},
    "ColorSequence": {"ColorSequence"},
    "NumberSequence": {"NumberSequence"},
    "NumberRange": {"NumberRange"},
    "Content": {"Content", "ContentId"},
    "ContentId": {"Content", "ContentId"},
    "Font": {"Font"},
    "PhysicalProperties": {"PhysicalProperties"},
    "Ray": {"Ray"},
    "Rect": {"Rect2D"},
    "Ref": {"Ref"},
    "Region3int16": {"Region3int16"},
    "SecurityCapabilities": {"SecurityCapabilities"},
    "SharedString": {"SharedString"},
    "UDim": {"UDim"},
    "UDim2": {"UDim2"},
    "UniqueId": {"UniqueId"},
    "Vector2": {"Vector2"},
    "Vector3": {"Vector3"},
    "Vector3int16": {"Vector3int16"},
}
TAGS_CONHECIDAS = set()
for _v in TAGS_POR_TIPO.values():
    TAGS_CONHECIDAS |= _v
TAGS_CONHECIDAS |= {"token", "Vector2int16", "Region3", "NetAssetRef"}

NUMERO = re.compile(r"^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$")
NUMERO_ROBLOX_ESPECIAL = {"INF", "-INF", "NAN", "+INF", "inf", "-inf", "nan", "Infinity", "-Infinity", "NaN"}
INTEIRO = re.compile(r"^[+-]?\d+$")
NOTACAO_CIENTIFICA = re.compile(r"[eE][+-]?\d+$")

SERVICOS_PROIBIDOS = {
    "CoreGui", "CorePackages", "RobloxPluginGuiService", "PluginGuiService", "PluginDebugService",
    "StudioService", "RobloxReplicatedStorage", "AppStorageService", "UserStorageService",
}
SCRIPTS = {"Script", "LocalScript", "ModuleScript"}
# classes "não criáveis" que existem normalmente dentro de arquivos de lugar
SINGLETONS_DE_ARQUIVO = {"Terrain", "Camera", "StarterPlayerScripts", "StarterCharacterScripts", "StarterGear"}


class Relatorio:
    def __init__(self):
        self.achados = []

    def add(self, severidade, codigo, mensagem, onde=None, dica=None):
        self.achados.append({
            "severidade": severidade, "codigo": codigo, "mensagem": mensagem,
            "onde": onde, "dica": dica,
        })

    def contar(self, sev):
        return sum(1 for a in self.achados if a["severidade"] == sev)

    def grave(self):
        return self.contar("FATAL") + self.contar("ALTO") > 0


# ---------------------------------------------------------------------------
# Base de reflexão
# ---------------------------------------------------------------------------
class Reflexao:
    def __init__(self, caminho):
        self.ok = False
        self.versao = "?"
        self.classes = {}
        self.enums = {}
        if caminho and os.path.exists(caminho):
            abrir = gzip.open if caminho.endswith(".gz") else open
            with abrir(caminho, "rt", encoding="utf-8") as f:
                dados = json.load(f)
            self.versao = dados.get("version", "?")
            self.classes = dados["classes"]
            self.enums = dados["enums"]
            self.ok = True

    def existe(self, classe):
        return classe in self.classes

    def tags(self, classe):
        return set(self.classes.get(classe, {}).get("tags", []))

    def propriedade(self, classe, nome):
        c = classe
        while c and c in self.classes:
            props = self.classes[c]["props"]
            if nome in props:
                return props[nome]
            # nomes de propriedade não diferenciam maiúsculas no leitor XML
            for k, v in props.items():
                if k.lower() == nome.lower():
                    return v
            c = self.classes[c].get("super")
        return None

    def eh_servico(self, classe):
        return "Service" in self.tags(classe)


# ---------------------------------------------------------------------------
# Verificações de bytes / codificação
# ---------------------------------------------------------------------------
def verificar_bytes(dados, caminho, rel):
    info = {"formato": "desconhecido"}
    tamanho = len(dados)
    info["tamanho"] = tamanho
    if tamanho == 0:
        rel.add("FATAL", "ARQUIVO_VAZIO", "O arquivo tem 0 bytes.",
                dica="Um corpo vazio é rejeitado como conteúdo inválido. Confira o caminho e se o download terminou.")
        return info
    if tamanho > LIMITE_BYTES:
        rel.add("FATAL", "ARQUIVO_GRANDE", "Arquivo maior que 100 MB (%d bytes)." % tamanho)
    cabeca = dados[:16]
    if cabeca.startswith(b"<roblox!"):
        info["formato"] = "rbxl"
        if caminho.lower().endswith(".rbxlx"):
            rel.add("ALTO", "BINARIO_COM_EXTENSAO_XML",
                    "O conteúdo é binário (.rbxl), mas a extensão é .rbxlx.",
                    dica="Envie com Content-Type: application/octet-stream, ou renomeie para .rbxl.")
        return info
    if cabeca.startswith(b"PK\x03\x04"):
        info["formato"] = "zip"
        rel.add("FATAL", "ARQUIVO_ZIP", "O arquivo é um ZIP, não um lugar Roblox.",
                dica="Extraia o .rbxlx de dentro do ZIP antes de enviar.")
        return info
    if cabeca.startswith(b"\x1f\x8b"):
        info["formato"] = "gzip"
        rel.add("FATAL", "ARQUIVO_GZIP", "O arquivo está compactado em gzip.")
        return info
    if cabeca.startswith(b"\xef\xbb\xbf"):
        rel.add("ALTO", "BOM_UTF8", "O arquivo começa com BOM UTF-8 (EF BB BF).",
                dica="Arquivos do Studio não têm BOM. Use --corrigir para remover.")
        dados = dados[3:]
    if cabeca.startswith(b"\xff\xfe") or cabeca.startswith(b"\xfe\xff"):
        rel.add("FATAL", "UTF16", "O arquivo está em UTF-16. O Roblox espera UTF-8.")
        return info
    inicio = dados.lstrip()[:20]
    if inicio.startswith(b"<roblox") or inicio.startswith(b"<?xml"):
        info["formato"] = "rbxlx"
        if caminho.lower().endswith(".rbxl"):
            rel.add("ALTO", "XML_COM_EXTENSAO_BINARIA",
                    "O conteúdo é XML, mas a extensão é .rbxl.",
                    dica="Envie com Content-Type: application/xml ou renomeie para .rbxlx.")
    else:
        rel.add("FATAL", "NAO_E_LUGAR", "O início do arquivo não parece um lugar Roblox: %r" % dados[:40])
        return info
    try:
        texto = dados.decode("utf-8")
    except UnicodeDecodeError as e:
        trecho = dados[max(0, e.start - 30):e.start + 30]
        rel.add("FATAL", "UTF8_INVALIDO",
                "Bytes inválidos em UTF-8 na posição %d: %r" % (e.start, trecho),
                dica="Gere o arquivo com encoding='utf-8' (acentos em Latin-1 quebram o leitor).")
        return info
    proibidos = [(m.start(), m.group()) for m in re.finditer(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", texto)]
    if proibidos:
        pos, ch = proibidos[0]
        linha = texto.count("\n", 0, pos) + 1
        rel.add("FATAL", "CARACTER_CONTROLE",
                "%d caractere(s) de controle proibidos em XML 1.0 (primeiro: %r na linha %d)." % (len(proibidos), ch, linha),
                dica="Remova caracteres como \\x00, \\x1b de nomes e scripts.")
    if "\r\n" in texto:
        rel.add("INFO", "CRLF", "Quebras de linha CRLF (Windows). Normalmente inofensivo.")
    m = re.match(r"\s*<\?xml[^>]*encoding=[\"']([^\"']+)[\"']", texto)
    if m and m.group(1).lower().replace("-", "") not in ("utf8",):
        rel.add("ALTO", "DECLARACAO_ENCODING", "Declaração XML diz encoding=%s, mas o Roblox lê UTF-8." % m.group(1))
    info["texto"] = texto
    return info


# ---------------------------------------------------------------------------
# Verificações de estrutura e propriedades
# ---------------------------------------------------------------------------
def numeros_filhos(el, nomes):
    valores = []
    for n in nomes:
        filho = el.find(n)
        if filho is None or filho.text is None:
            return None, "falta <%s>" % n
        t = filho.text.strip()
        if not (NUMERO.match(t) or t in NUMERO_ROBLOX_ESPECIAL):
            return None, "<%s> não numérico: %r" % (n, t)
        valores.append(float(t) if NUMERO.match(t) else float("nan"))
    return valores, None


class Analisador:
    def __init__(self, reflexao, rel):
        self.R = reflexao
        self.rel = rel
        self.referents = {}
        self.refs_usadas = []
        self.shared_keys = set()
        self.shared_usadas = []
        self.stats = {
            "itens": 0, "classes": {}, "tipos": {}, "props_por_tipo": {},
            "cientifica": 0, "scripts": 0, "bytes_scripts": 0,
        }
        self.tripla = set()  # (classe, propriedade, tag)
        self.token_checado = False
        self.limite_por_codigo = {}

    def add(self, sev, codigo, msg, onde=None, dica=None):
        n = self.limite_por_codigo.get(codigo, 0)
        self.limite_por_codigo[codigo] = n + 1
        if n < 12:
            self.rel.add(sev, codigo, msg, onde, dica)
        elif n == 12:
            self.rel.add(sev, codigo, "(mais ocorrências de %s omitidas)" % codigo)

    def analisar(self, raiz):
        if raiz.tag != "roblox":
            self.add("FATAL", "RAIZ", "Elemento raiz é <%s>, deveria ser <roblox>." % raiz.tag)
            return
        versao = raiz.get("version")
        if versao != "4":
            self.add("FATAL", "VERSAO", "Atributo version=%r na raiz; o formato atual exige version=\"4\"." % versao)
        for filho in raiz:
            if filho.tag == "SharedStrings":
                for ss in filho.findall("SharedString"):
                    self.shared_keys.add(ss.get("md5"))
        servicos_vistos = {}
        for filho in raiz:
            if filho.tag == "Item":
                classe = filho.get("class")
                if classe and self.R.ok:
                    if not self.R.eh_servico(classe) and classe not in ("Model", "Folder"):
                        self.add("MEDIO", "NAO_SERVICO_NA_RAIZ",
                                 "Item '%s' (%s) está na raiz do arquivo, fora de um serviço." % (self.nome(filho), classe),
                                 dica="Coloque objetos dentro de Workspace/ReplicatedStorage etc.")
                    if self.R.eh_servico(classe):
                        if classe in servicos_vistos:
                            self.add("ALTO", "SERVICO_DUPLICADO", "Serviço %s aparece mais de uma vez na raiz." % classe)
                        servicos_vistos[classe] = True
                self.item(filho, "", 0)
            elif filho.tag in ("Meta", "External", "SharedStrings"):
                pass
            else:
                self.add("ALTO", "TAG_RAIZ", "Tag inesperada na raiz: <%s>." % filho.tag)
        for ref, onde in self.refs_usadas:
            if ref not in self.referents:
                self.add("MEDIO", "REF_QUEBRADA", "Ref aponta para referent inexistente %r." % ref, onde)
        for chave, onde in self.shared_usadas:
            if chave not in self.shared_keys:
                self.add("ALTO", "SHAREDSTRING_QUEBRADA", "SharedString %r sem entrada em <SharedStrings>." % chave, onde)

    @staticmethod
    def nome(item):
        props = item.find("Properties")
        if props is not None:
            for p in props:
                if p.get("name") == "Name" and p.text:
                    return p.text
        return "?"

    def item(self, el, caminho, profundidade):
        self.stats["itens"] += 1
        classe = el.get("class")
        nome = self.nome(el)
        onde = "%s/%s" % (caminho, nome)
        if not classe:
            self.add("FATAL", "ITEM_SEM_CLASSE", "<Item> sem atributo class.", onde)
            return
        self.stats["classes"][classe] = self.stats["classes"].get(classe, 0) + 1
        ref = el.get("referent")
        if ref is None:
            self.add("ALTO", "SEM_REFERENT", "Item sem atributo referent.", onde)
        elif ref in self.referents:
            self.add("FATAL", "REFERENT_DUPLICADO", "referent %r repetido (também em %s)." % (ref, self.referents[ref]), onde,
                     dica="Cada <Item> precisa de um referent único. --corrigir renumera.")
        else:
            self.referents[ref] = onde
        if self.R.ok:
            if not self.R.existe(classe):
                self.add("ALTO", "CLASSE_DESCONHECIDA", "Classe %r não existe no Roblox (versão da base %s)." % (classe, self.R.versao), onde,
                         dica="Erro de digitação ou classe removida? O carregador pode rejeitar o arquivo.")
            else:
                tags = self.R.tags(classe)
                if classe in SERVICOS_PROIBIDOS:
                    self.add("FATAL", "SERVICO_INTERNO", "Serviço interno %s não pode estar no arquivo." % classe, onde)
                elif "Service" in tags and profundidade > 0:
                    self.add("ALTO", "SERVICO_ANINHADO", "Serviço %s dentro de outro objeto." % classe, onde)
                elif "NotCreatable" in tags and "Service" not in tags and classe not in SINGLETONS_DE_ARQUIVO:
                    self.add("MEDIO", "CLASSE_NAO_CRIAVEL", "Classe %s é marcada como não criável; confirme se pode existir em arquivo." % classe, onde)
                if "Deprecated" in tags:
                    self.add("INFO", "CLASSE_OBSOLETA", "Classe obsoleta %s." % classe, onde)
        props = el.find("Properties")
        if props is None:
            self.add("MEDIO", "SEM_PROPERTIES", "Item sem <Properties>.", onde)
        else:
            for p in props:
                self.propriedade(classe, p, onde)
        if classe in SCRIPTS:
            self.stats["scripts"] += 1
        for filho in el:
            if filho.tag == "Item":
                self.item(filho, onde, profundidade + 1)
            elif filho.tag != "Properties":
                self.add("MEDIO", "TAG_ITEM", "Tag inesperada <%s> dentro de Item." % filho.tag, onde)

    def propriedade(self, classe, p, onde):
        tag = p.tag
        nome = p.get("name")
        self.stats["tipos"][tag] = self.stats["tipos"].get(tag, 0) + 1
        if not nome:
            self.add("ALTO", "PROP_SEM_NOME", "Propriedade <%s> sem atributo name." % tag, onde)
            return
        self.tripla.add((classe, nome, tag))
        lugar = "%s.%s" % (onde, nome)
        if tag not in TAGS_CONHECIDAS:
            self.add("ALTO", "TIPO_DESCONHECIDO", "Tipo de propriedade desconhecido <%s name=%r>." % (tag, nome), lugar)
            return
        texto = (p.text or "").strip()
        self.token_checado = False
        # tipo esperado pela base de reflexão
        if self.R.ok and self.R.existe(classe) and nome not in ("AttributesSerialize", "Tags", "SourceAssetId", "HistoryId", "UniqueId", "Capabilities", "DefinesCapabilities"):
            esperado = self.R.propriedade(classe, nome)
            if esperado is None:
                self.add("INFO", "PROP_DESCONHECIDA", "Propriedade %r não existe em %s (o Roblox costuma ignorar)." % (nome, classe), lugar)
            elif esperado.startswith("Enum."):
                if tag != "token":
                    self.add("ALTO", "ENUM_COM_TIPO_ERRADO",
                             "%s é enum (%s) mas foi gravado como <%s>." % (nome, esperado, tag), lugar,
                             dica="Enums devem ser <token name=\"%s\">NÚMERO</token>." % nome)
                else:
                    self.token(esperado[5:], texto, lugar)
                    self.token_checado = True
            else:
                aceitas = TAGS_POR_TIPO.get(esperado)
                if aceitas and tag not in aceitas:
                    sev = "ALTO"
                    if esperado == "Color3" and tag == "Color3uint8":
                        sev = "INFO"
                    self.add(sev, "TIPO_ERRADO",
                             "%s.%s espera %s (tag %s) mas foi gravado como <%s>." % (classe, nome, esperado, "/".join(sorted(aceitas)), tag), lugar)
        self.valor(tag, nome, p, texto, lugar)

    def token(self, enum, texto, lugar):
        if not INTEIRO.match(texto):
            self.add("FATAL", "TOKEN_NAO_NUMERICO",
                     "Enum %s gravado como texto %r; o formato exige o número do item." % (enum, texto), lugar,
                     dica="Ex.: Material Neon = 288. --corrigir converte nomes conhecidos.")
            return
        itens = self.R.enums.get(enum)
        if itens and int(texto) not in itens.values():
            self.add("ALTO", "TOKEN_INVALIDO", "Valor %s não existe no enum %s." % (texto, enum), lugar)

    def checar_numero(self, t, lugar, nome, tipo):
        if t in NUMERO_ROBLOX_ESPECIAL:
            if t in ("inf", "-inf", "nan", "Infinity", "-Infinity", "NaN"):
                self.add("ALTO", "NUMERO_ESPECIAL_PYTHON",
                         "%s=%r: infinito/NaN escrito no estilo Python/JS." % (nome, t), lugar,
                         dica="Use INF, -INF ou NAN, ou corrija a conta que gerou o valor.")
            return
        if not NUMERO.match(t):
            self.add("FATAL" if tipo in ("int", "int64") else "ALTO", "NUMERO_INVALIDO",
                     "%s <%s> com valor não numérico %r." % (nome, tipo, t), lugar)
            return
        if NOTACAO_CIENTIFICA.search(t):
            self.stats["cientifica"] += 1
        if tipo in ("int", "int64") and not INTEIRO.match(t):
            self.add("ALTO", "INTEIRO_COM_DECIMAL", "%s <%s> com casas decimais %r." % (nome, tipo, t), lugar)

    def valor(self, tag, nome, p, t, lugar):
        if tag == "bool":
            if t not in ("true", "false"):
                self.add("ALTO", "BOOL_INVALIDO", "%s = %r; o formato aceita só 'true' ou 'false' (minúsculas)." % (nome, t), lugar,
                         dica="str(True) do Python gera 'True'. --corrigir resolve.")
        elif tag in ("int", "int64", "float", "double"):
            if t == "":
                self.add("ALTO", "NUMERO_VAZIO", "%s <%s> vazio." % (nome, tag), lugar)
            else:
                self.checar_numero(t, lugar, nome, tag)
        elif tag == "token":
            # quando a base de reflexão conhece a propriedade, token() já validou
            if not INTEIRO.match(t) and not self.token_checado:
                self.add("FATAL", "TOKEN_NAO_NUMERICO", "token %s = %r não numérico." % (nome, t), lugar,
                         dica="Enums são gravados como número (ex.: Material Neon = 288).")
        elif tag == "Color3uint8":
            if not INTEIRO.match(t) or not (0 <= int(t) <= 4294967295):
                self.add("ALTO", "COLOR3UINT8_INVALIDO", "%s = %r fora de 0..4294967295." % (nome, t), lugar)
        elif tag == "Vector3":
            _, erro = numeros_filhos(p, ["X", "Y", "Z"])
            if erro:
                self.add("ALTO", "VECTOR3_INVALIDO", "%s: %s." % (nome, erro), lugar)
        elif tag == "Vector2":
            _, erro = numeros_filhos(p, ["X", "Y"])
            if erro:
                self.add("ALTO", "VECTOR2_INVALIDO", "%s: %s." % (nome, erro), lugar)
        elif tag == "CoordinateFrame":
            nomes = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
            v, erro = numeros_filhos(p, nomes)
            if erro:
                self.add("ALTO", "CFRAME_INVALIDO", "%s: %s." % (nome, erro), lugar,
                         dica="CoordinateFrame precisa de X,Y,Z e R00..R22 (12 números).")
            elif v and all(math.isfinite(x) for x in v):
                r = [v[3:6], v[6:9], v[9:12]]
                for i in range(3):
                    norma = math.sqrt(sum(r[i][j] ** 2 for j in range(3)))
                    if abs(norma - 1) > 0.02:
                        self.add("MEDIO", "CFRAME_NAO_ORTONORMAL",
                                 "%s: matriz de rotação não ortonormal (linha %d com norma %.3f)." % (nome, i, norma), lugar)
                        break
        elif tag == "Color3":
            v, erro = numeros_filhos(p, ["R", "G", "B"])
            if erro:
                self.add("ALTO", "COLOR3_INVALIDO", "%s: %s." % (nome, erro), lugar)
            elif v and any(x > 1.0001 for x in v if math.isfinite(x)):
                self.add("MEDIO", "COLOR3_ESCALA", "%s com componentes > 1 (%s); Color3 usa 0..1, não 0..255." % (nome, v), lugar)
        elif tag == "UDim2":
            _, erro = numeros_filhos(p, ["XS", "XO", "YS", "YO"])
            if erro:
                self.add("ALTO", "UDIM2_INVALIDO", "%s: %s." % (nome, erro), lugar)
        elif tag == "UDim":
            _, erro = numeros_filhos(p, ["S", "O"])
            if erro:
                self.add("ALTO", "UDIM_INVALIDO", "%s: %s." % (nome, erro), lugar)
        elif tag in ("Content", "ContentId"):
            filhos = [f.tag for f in p]
            if not filhos:
                if t:
                    self.add("ALTO", "CONTENT_SEM_URL",
                             "%s = %r gravado como texto puro." % (nome, t), lugar,
                             dica="Formato correto: <Content name=\"%s\"><url>%s</url></Content> (ou <null></null>)." % (nome, t))
            elif not any(f in ("url", "null", "uri", "Object", "SharedString") for f in filhos):
                self.add("ALTO", "CONTENT_FILHO_DESCONHECIDO", "%s com filhos inesperados %s." % (nome, filhos), lugar)
        elif tag == "BinaryString":
            try:
                bruto = base64.b64decode("".join(t.split()), validate=True) if t else b""
            except Exception:
                self.add("ALTO", "BASE64_INVALIDO", "%s não é base64 válido." % nome, lugar,
                         dica="BinaryString precisa ser base64. JSON/texto puro aqui quebra o carregamento.")
                return
            if nome == "AttributesSerialize" and bruto:
                erro = validar_atributos(bruto)
                if erro:
                    self.add("ALTO", "ATRIBUTOS_INVALIDOS", "AttributesSerialize malformado: %s." % erro, lugar)
        elif tag == "SharedString":
            self.shared_usadas.append((t, lugar))
        elif tag == "Ref":
            if t and t != "null":
                self.refs_usadas.append((t, lugar))
        elif tag == "NumberSequence":
            partes = t.split()
            if len(partes) % 3 != 0 or len(partes) < 6:
                self.add("ALTO", "NUMBERSEQUENCE_INVALIDA", "%s: esperado grupos 'tempo valor envelope' (>=2 pontos), veio %r." % (nome, t), lugar)
            else:
                try:
                    tempos = [float(partes[i]) for i in range(0, len(partes), 3)]
                    if abs(tempos[0]) > 1e-6 or abs(tempos[-1] - 1) > 1e-6:
                        self.add("ALTO", "NUMBERSEQUENCE_TEMPO", "%s: primeiro ponto deve ser 0 e último 1." % nome, lugar)
                except ValueError:
                    self.add("ALTO", "NUMBERSEQUENCE_INVALIDA", "%s com valores não numéricos." % nome, lugar)
        elif tag == "ColorSequence":
            partes = t.split()
            if len(partes) % 5 != 0 or len(partes) < 10:
                self.add("ALTO", "COLORSEQUENCE_INVALIDA", "%s: esperado grupos 'tempo r g b 0' (>=2 pontos), veio %r." % (nome, t), lugar)
        elif tag == "NumberRange":
            partes = t.split()
            if len(partes) < 2 or not all(NUMERO.match(x) for x in partes[:2]):
                self.add("ALTO", "NUMBERRANGE_INVALIDO", "%s: esperado 'min max', veio %r." % (nome, t), lugar)
        elif tag == "Font":
            if p.find("Family") is None or p.find("Weight") is None or p.find("Style") is None:
                self.add("ALTO", "FONT_INVALIDA", "%s: Font precisa de Family/Weight/Style." % nome, lugar)
        elif tag in ("string", "ProtectedString"):
            if nome == "Source":
                self.stats["bytes_scripts"] += len(t)
                if "\x00" in (p.text or ""):
                    self.add("ALTO", "SCRIPT_COM_NUL", "Script com caractere NUL.", lugar)


def validar_atributos(b):
    """Valida o formato binário de AttributesSerialize (contagem + pares nome/valor)."""
    try:
        if len(b) < 4:
            return "menos de 4 bytes"
        (qtd,) = struct.unpack_from("<I", b, 0)
        pos = 4
        for _ in range(qtd):
            (tam,) = struct.unpack_from("<I", b, pos)
            pos += 4 + tam
            tipo = b[pos]
            pos += 1
            if tipo == 0x02:  # string
                (tam,) = struct.unpack_from("<I", b, pos)
                pos += 4 + tam
            elif tipo == 0x03:  # bool
                pos += 1
            elif tipo in (0x05, 0x06):  # float / double
                pos += 4 if tipo == 0x05 else 8
            elif tipo == 0x09:  # UDim
                pos += 8
            elif tipo == 0x0A:  # UDim2
                pos += 16
            elif tipo == 0x0E:  # BrickColor
                pos += 4
            elif tipo == 0x0F:  # Color3
                pos += 12
            elif tipo == 0x10:  # Vector2
                pos += 8
            elif tipo == 0x11:  # Vector3
                pos += 12
            elif tipo == 0x14:  # CFrame
                pos += 12
                rot = b[pos]
                pos += 1
                if rot == 0:
                    pos += 36
            elif tipo == 0x1B:  # NumberRange
                pos += 8
            else:
                return None  # tipo raro: não validamos o resto
            if pos > len(b):
                return "dados terminam antes do esperado"
        return None
    except (struct.error, IndexError):
        return "estrutura truncada"


# ---------------------------------------------------------------------------
# Correções seguras
# ---------------------------------------------------------------------------
def corrigir(raiz, reflexao, log):
    vistos = set()
    contador = [0]

    def novo_ref():
        contador[0] += 1
        return "RBXFIX%026d" % contador[0]

    def walk(el, classe=None):
        if el.tag == "Item":
            classe = el.get("class")
            ref = el.get("referent")
            if ref is None or ref in vistos:
                novo = novo_ref()
                log.append("referent %r -> %r" % (ref, novo))
                el.set("referent", novo)
                ref = novo
            vistos.add(ref)
            props = el.find("Properties")
            if props is not None:
                for p in list(props):
                    corrigir_prop(classe, p, reflexao, log)
        for filho in list(el):
            walk(filho, classe)

    walk(raiz)


def corrigir_prop(classe, p, R, log):
    nome = p.get("name")
    t = (p.text or "").strip()
    if p.tag == "bool" and t.lower() in ("true", "false") and t not in ("true", "false"):
        p.text = t.lower()
        log.append("%s.%s: bool %r -> %r" % (classe, nome, t, p.text))
    if p.tag in ("float", "double") and t in ("inf", "-inf", "nan", "Infinity", "-Infinity", "NaN"):
        mapa = {"inf": "INF", "Infinity": "INF", "-inf": "-INF", "-Infinity": "-INF", "nan": "NAN", "NaN": "NAN"}
        p.text = mapa[t]
        log.append("%s.%s: %r -> %r" % (classe, nome, t, p.text))
    if R.ok and R.existe(classe):
        esperado = R.propriedade(classe, nome)
        if esperado and esperado.startswith("Enum.") and not INTEIRO.match(t):
            itens = R.enums.get(esperado[5:], {})
            alvo = itens.get(t)
            if alvo is None:
                for k, v in itens.items():
                    if k.lower() == t.lower().replace("enum.%s." % esperado[5:].lower(), ""):
                        alvo = v
            if alvo is not None:
                antigo_tag = p.tag
                p.tag = "token"
                p.text = str(alvo)
                log.append("%s.%s: <%s>%r -> <token>%d" % (classe, nome, antigo_tag, t, alvo))
    if p.tag in ("Content", "ContentId") and len(p) == 0 and t:
        p.text = None
        url = ET.SubElement(p, "url")
        url.text = t
        log.append("%s.%s: Content texto -> <url>" % (classe, nome))
    if p.tag == "Color3uint8" and INTEIRO.match(t):
        v = int(t)
        if v < 0 or v > 4294967295:
            p.text = str(max(0, min(v, 4294967295)))
            log.append("%s.%s: Color3uint8 %s -> %s" % (classe, nome, t, p.text))


def normalizar_cientifica(raiz, log):
    n = 0
    for el in raiz.iter():
        if el.text and NOTACAO_CIENTIFICA.search(el.text.strip()) and NUMERO.match(el.text.strip()):
            v = float(el.text.strip())
            el.text = ("%.9f" % v).rstrip("0").rstrip(".") or "0"
            n += 1
    if n:
        log.append("%d números convertidos de notação científica para decimal" % n)


def escrever(raiz, destino):
    arvore = ET.ElementTree(raiz)
    with open(destino, "wb") as f:
        arvore.write(f, encoding="utf-8", xml_declaration=False)


# ---------------------------------------------------------------------------
# Comparação e bissecção
# ---------------------------------------------------------------------------
def comparar(a, b, rel):
    so_b_classes = sorted(set(b.stats["classes"]) - set(a.stats["classes"]))
    so_b_tipos = sorted(set(b.stats["tipos"]) - set(a.stats["tipos"]))
    so_b_props = sorted((c, n, t) for (c, n, t) in b.tripla - a.tripla)
    rel.add("INFO", "COMPARACAO",
            "Classes só no arquivo analisado: %s" % (", ".join(so_b_classes) or "nenhuma"))
    rel.add("INFO", "COMPARACAO",
            "Tipos de propriedade só no arquivo analisado: %s" % (", ".join(so_b_tipos) or "nenhum"),
            dica="Como o arquivo de referência foi aceito, estes tipos são os primeiros suspeitos.")
    if so_b_props:
        amostra = ["%s.%s<%s>" % x for x in so_b_props[:40]]
        rel.add("INFO", "COMPARACAO", "%d combinações classe.propriedade<tipo> novas, ex.: %s" % (len(so_b_props), "; ".join(amostra)))
    return so_b_tipos


def bisseccao(raiz, pasta, tipos_suspeitos):
    os.makedirs(pasta, exist_ok=True)
    gerados = []

    def salvar(nome, arvore):
        caminho = os.path.join(pasta, nome)
        escrever(arvore, caminho)
        gerados.append(caminho)

    # A) sem scripts
    r = copy.deepcopy(raiz)
    for pai in r.iter():
        for filho in list(pai):
            if filho.tag == "Item" and filho.get("class") in SCRIPTS:
                pai.remove(filho)
    salvar("A_sem_scripts.rbxlx", r)
    # B) só serviços + scripts (sem objetos do Workspace)
    r = copy.deepcopy(raiz)
    for item in r.findall("Item"):
        if item.get("class") == "Workspace":
            for filho in list(item):
                if filho.tag == "Item":
                    item.remove(filho)
    salvar("B_workspace_vazio.rbxlx", r)
    # C) metade do Workspace
    for metade in (1, 2):
        r = copy.deepcopy(raiz)
        for item in r.findall("Item"):
            if item.get("class") == "Workspace":
                filhos = [f for f in item if f.tag == "Item"]
                meio = len(filhos) // 2
                remover = filhos[meio:] if metade == 1 else filhos[:meio]
                for f in remover:
                    item.remove(f)
        salvar("C%d_workspace_metade_%d.rbxlx" % (metade, metade), r)
    # D) sem cada tipo suspeito
    for tipo in tipos_suspeitos:
        r = copy.deepcopy(raiz)
        for props in r.iter("Properties"):
            for p in list(props):
                if p.tag == tipo:
                    props.remove(p)
        salvar("D_sem_tipo_%s.rbxlx" % tipo, r)
    # E) números sem notação científica
    r = copy.deepcopy(raiz)
    normalizar_cientifica(r, [])
    salvar("E_sem_notacao_cientifica.rbxlx", r)
    with open(os.path.join(pasta, "LEIA-ME.txt"), "w", encoding="utf-8") as f:
        f.write(
            "Bissecção do erro 'Invalid Content stream'\n"
            "===========================================\n"
            "Envie cada arquivo como versão SAVED (nunca Published), um de cada vez:\n"
            "  bash ideias.sh enviar ARQUIVO\n"
            "O arquivo que for ACEITO indica que a parte removida dele contém o problema.\n"
            "  A aceito  -> problema nos scripts\n"
            "  B aceito  -> problema em objetos do Workspace (teste C1 e C2)\n"
            "  C1/C2     -> o problema está na metade removida; repita a bissecção nela\n"
            "  D_sem_tipo_X aceito -> propriedades do tipo X estão malformadas\n"
            "  E aceito  -> notação científica (pouco provável, mas fica comprovado)\n"
            "Cada envio Saved cria uma versão nova no histórico; nenhuma fica publicada.\n"
        )
    return gerados


# ---------------------------------------------------------------------------
def imprimir(rel, info, an, arquivo):
    print("=" * 72)
    print("Diagnóstico: %s" % arquivo)
    print("Formato detectado: %s | Tamanho: %s bytes" % (info.get("formato"), info.get("tamanho")))
    if an:
        s = an.stats
        top = sorted(s["classes"].items(), key=lambda x: -x[1])[:10]
        print("Itens: %d | Scripts: %d (%d bytes de código) | Números em notação científica: %d"
              % (s["itens"], s["scripts"], s["bytes_scripts"], s["cientifica"]))
        print("Classes mais comuns: %s" % ", ".join("%s×%d" % x for x in top))
        print("Tipos de propriedade: %s" % ", ".join("%s×%d" % x for x in sorted(s["tipos"].items())))
    print("-" * 72)
    ordem = {s: i for i, s in enumerate(SEVERIDADES)}
    for a in sorted(rel.achados, key=lambda x: ordem[x["severidade"]]):
        print("[%s] %s: %s" % (a["severidade"], a["codigo"], a["mensagem"]))
        if a.get("onde"):
            print("        em: %s" % a["onde"])
        if a.get("dica"):
            print("        dica: %s" % a["dica"])
    print("-" * 72)
    print("Resumo: FATAL=%d ALTO=%d MEDIO=%d INFO=%d" % tuple(rel.contar(s) for s in SEVERIDADES))
    if not rel.grave():
        print("Nenhum problema grave encontrado no conteúdo. Se o envio ainda falhar,")
        print("verifique a requisição: arquivo certo, --data-binary @arquivo, Content-Type,")
        print("e use --bisseccao para isolar a parte rejeitada.")


def carregar_xml(caminho, reflexao, rel):
    with open(caminho, "rb") as f:
        dados = f.read()
    info = verificar_bytes(dados, caminho, rel)
    if "texto" not in info:
        return info, None, None
    try:
        raiz = ET.fromstring(info["texto"].lstrip("﻿"))
    except ET.ParseError as e:
        rel.add("FATAL", "XML_MALFORMADO", "XML inválido: %s" % e)
        return info, None, None
    an = Analisador(reflexao, rel)
    an.analisar(raiz)
    return info, raiz, an


def main():
    ap = argparse.ArgumentParser(description="Diagnóstico de .rbxlx para o Open Cloud do Roblox")
    ap.add_argument("arquivo")
    ap.add_argument("--comparar", help="arquivo aceito anteriormente (ex.: V1) para comparar")
    ap.add_argument("--bisseccao", metavar="PASTA", help="gera variações reduzidas para isolar o problema")
    ap.add_argument("--corrigir", metavar="SAIDA", help="grava uma cópia com correções seguras")
    ap.add_argument("--sem-cientifica", action="store_true", help="com --corrigir, também converte notação científica")
    ap.add_argument("--json", metavar="SAIDA", help="grava o relatório em JSON")
    ap.add_argument("--reflexao", default=REFLEXAO_PADRAO, help="base de reflexão (json ou json.gz)")
    args = ap.parse_args()

    if not os.path.isfile(args.arquivo):
        print("Arquivo não encontrado: %s" % args.arquivo)
        print("Dica: no Termux os downloads ficam em ~/storage/downloads (rode termux-setup-storage).")
        return 2

    R = Reflexao(args.reflexao)
    rel = Relatorio()
    if not R.ok:
        rel.add("INFO", "SEM_REFLEXAO", "Base de reflexão não encontrada; verificações de classe/tipo desativadas.")
    info, raiz, an = carregar_xml(args.arquivo, R, rel)

    if args.comparar and raiz is not None:
        rel_ref = Relatorio()
        _, raiz_ref, an_ref = carregar_xml(args.comparar, R, rel_ref)
        if an_ref:
            tipos = comparar(an_ref, an, rel)
        else:
            tipos = []
            rel.add("INFO", "COMPARACAO", "Não foi possível analisar o arquivo de referência.")
    else:
        tipos = []

    imprimir(rel, info, an, args.arquivo)

    if args.bisseccao and raiz is not None:
        if not tipos and an:
            tipos = sorted(t for t in an.stats["tipos"] if t not in ("string", "bool", "float", "int", "token", "Vector3", "CoordinateFrame"))
        gerados = bisseccao(raiz, args.bisseccao, tipos)
        print("\nArquivos de bissecção gerados em %s:" % args.bisseccao)
        for g in gerados:
            print("  " + g)

    if args.corrigir and raiz is not None:
        if os.path.abspath(args.corrigir) == os.path.abspath(args.arquivo):
            print("Recusado: --corrigir não pode sobrescrever o arquivo original.")
            return 2
        log = []
        corrigir(raiz, R, log)
        if args.sem_cientifica:
            normalizar_cientifica(raiz, log)
        escrever(raiz, args.corrigir)
        print("\nCópia corrigida: %s (%d alterações)" % (args.corrigir, len(log)))
        for linha in log[:60]:
            print("  - " + linha)
        rel2 = Relatorio()
        _, _, _ = carregar_xml(args.corrigir, R, rel2)
        print("Reanálise da cópia: FATAL=%d ALTO=%d" % (rel2.contar("FATAL"), rel2.contar("ALTO")))

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"arquivo": args.arquivo, "info": {k: v for k, v in info.items() if k != "texto"},
                       "achados": rel.achados, "estatisticas": an.stats if an else None},
                      f, ensure_ascii=False, indent=2)
    return 1 if rel.grave() else 0


if __name__ == "__main__":
    sys.exit(main())
