"""Update the client script, managed server scripts and native avatar settings in a Roblox place."""

from dataclasses import dataclass, field
from hashlib import sha256
import struct
import re
from xml.parsers import expat
from xml.sax.saxutils import escape

from .codec import Binary, Chunk, Failure, MAX_FILE, pack32, prefs, pstring, puints, refs, uints


BINARY_MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"
MENU_NAME = "CyberOutlawMenu"
MENU_PATH = ("StarterPlayer", "StarterPlayerScripts", MENU_NAME)
MENU_CLASSES = ("StarterPlayer", "StarterPlayerScripts", "LocalScript")
SERVER_SERVICE = "ServerScriptService"
# Every managed server script starts with this line plus its own name.
SERVER_HEADER = "-- CyberOutlaw · script de servidor gerenciado: "
CLIENT_HEADER = "-- CyberOutlaw · script de cliente gerenciado: "
SERVER_NAME = re.compile(r"CyberOutlaw[A-Za-z0-9]{1,48}")
CONTAINER_CLASSES = ("StarterPlayer", "StarterPlayerScripts", SERVER_SERVICE, "AvatarSettings", "AvatarRules")
SCRIPT_CLASSES = ("LocalScript", "Script")
SERVICE_CLASSES = ("StarterPlayer", SERVER_SERVICE)
R6 = 0  # Enum.GameAvatarType.R6
RIG_PROPERTIES = {
    "StarterPlayer": ("GameSettingsAvatar", "PlaceAvatarRules"),
    "AvatarRules": ("AvatarType",),
    "AvatarBodyRules": ("AvatarType",),
    "Lighting": ("Technology", "LightingStyle", "PrioritizeLightingQuality"),
}
# Iluminação "Realistic" com prioridade de qualidade: o equivalente do antigo Future no sistema unificado
# (Technology.Unified = 5, LightingStyle.Realistic = 0). Scripts não podem mudar isso; o arquivo do place pode.
LIGHTING = (("Technology", "token", 5), ("LightingStyle", "token", 0), ("PrioritizeLightingQuality", "bool", True))


def source_digest(source):
    return sha256(source.encode("utf-8")).hexdigest()


def _accept_source(old, new, known):
    if old != new and source_digest(old) not in known:
        raise Failure(
            "Já existe um CyberOutlawMenu com código desconhecido. "
            "O instalador preservou o script."
        )


def server_route(name):
    if not SERVER_NAME.fullmatch(name):
        raise Failure(f"Nome inválido para script de servidor: {name}")
    return (SERVER_SERVICE, name), (SERVER_SERVICE, "Script")


def client_route(name):
    if not SERVER_NAME.fullmatch(name) or name == MENU_NAME:
        raise Failure(f"Nome inválido para script de cliente: {name}")
    return ("StarterPlayer", "StarterPlayerScripts", name), MENU_CLASSES


def _managed_route(name, code):
    """The header picks the route: server scripts in ServerScriptService, client ones in StarterPlayerScripts."""
    if code.startswith(CLIENT_HEADER + name + "\n"):
        return client_route(name), CLIENT_HEADER, "StarterPlayerScripts"
    if code.startswith(SERVER_HEADER + name + "\n"):
        return server_route(name), SERVER_HEADER, SERVER_SERVICE
    server_route(name)
    raise Failure(f"O script {name} precisa começar pelo cabeçalho do CyberOutlaw.")


def _accept_managed(name, code, old):
    _, header, where = _managed_route(name, code)
    if old != code and not old.startswith(header + name + "\n"):
        raise Failure(f"Já existe um {name} com código desconhecido em {where}. O instalador preservou o script.")


def managed_source(raw, name, code):
    return script_source(raw, *_managed_route(name, code)[0])


def _server_header(name):
    return SERVER_HEADER + name + "\n"


def _accept_server(name, old, new):
    if not new.startswith(_server_header(name)):
        raise Failure(f"O script de servidor {name} precisa começar pelo cabeçalho do CyberOutlaw.")
    if old != new and not old.startswith(_server_header(name)):
        raise Failure(
            f"Já existe um {name} com código desconhecido em ServerScriptService. "
            "O instalador preservou o script."
        )


def _find(nodes, name, class_name, canonical):
    named = [node for node, node_name, _ in nodes if node_name == name]
    if len(named) > 1:
        raise Failure(f"Há mais de um objeto chamado {name} no caminho do menu.")
    if named and not any(
        node == named[0] and cls == class_name for node, _, cls in nodes
    ):
        raise Failure(f"O objeto {name} tem uma classe diferente da esperada.")
    if canonical and any(
        cls == class_name and node_name != name for _, node_name, cls in nodes
    ):
        raise Failure(f"Há um {class_name} renomeado no caminho do menu.")
    return named[0] if named else None


def _single(items, description):
    items = list(items)
    if len(items) > 1:
        raise Failure(f"O place tem mais de um registro de {description}.")
    return items[0] if items else None


@dataclass(eq=False)
class _Item:
    tag: str
    start: int
    class_name: str = ""
    end: int = 0
    props_count: int = 0
    children: list = field(default_factory=list)
    names: list = field(default_factory=list)
    sources: list = field(default_factory=list)
    referent: str = ""
    props_end: int = 0
    avatar_props: dict = field(default_factory=dict)


@dataclass
class _Prop:
    tag: str
    start: int
    end: int = 0
    text: list = field(default_factory=list)
    nested: bool = False

    def value(self, allowed):
        if self.nested or self.tag not in allowed:
            raise Failure("Propriedade inválida no caminho do menu.")
        return "".join(self.text)


class _Xml:
    """Use the parser's byte offsets to preserve the original XML outside the edit."""

    def __init__(self, raw):
        if raw.startswith((b"\xff\xfe", b"<\x00")):
            self.encoding = "utf-16-le"
        elif raw.startswith((b"\xfe\xff", b"\x00<")):
            self.encoding = "utf-16-be"
        else:
            self.encoding = "utf-8"
        self.raw = raw
        self.root = None
        self.refs = set()
        self.stack = []
        parser = expat.ParserCreate()
        self.parser = parser
        parser.StartDoctypeDeclHandler = self._reject_dtd
        parser.XmlDeclHandler = self._decl
        parser.StartElementHandler = self._open
        parser.EndElementHandler = self._close
        parser.CharacterDataHandler = self._text
        try:
            parser.Parse(raw, True)
        except expat.ExpatError:
            raise Failure("O XML do place está inválido ou incompleto.") from None
        finally:
            del self.parser

    @staticmethod
    def _reject_dtd(*_):
        raise Failure("O XML do place contém uma declaração de tipo de documento.")

    def _decl(self, version, encoding, standalone):
        if not encoding:
            return
        allowed = {"utf-8", "us-ascii"} if self.encoding == "utf-8" else {"utf-16", self.encoding}
        if encoding.lower() not in allowed:
            raise Failure("A codificação declarada do XML do place não é compatível.")
        if encoding.lower() == "us-ascii":
            self.encoding = "ascii"

    def _open(self, tag, attrs):
        parent_tag, parent = self.stack[-1] if self.stack else (None, None)
        node = None
        position = self.parser.CurrentByteIndex
        if not self.stack:
            if tag != "roblox" or attrs.get("version") != "4":
                raise Failure("O arquivo não é um XML Roblox versão 4.")
            self.root = node = _Item(tag, position)
        elif tag == "Item":
            if attrs.get("referent"):
                self.refs.add(attrs["referent"])
            if parent_tag in ("roblox", "Item") and isinstance(parent, _Item) and (
                parent is self.root or parent.class_name in CONTAINER_CLASSES
            ):
                node = _Item(tag, position, attrs.get("class", ""), referent=attrs.get("referent", ""))
                parent.children.append(node)
        elif tag == "Properties" and parent_tag == "Item" and isinstance(parent, _Item):
            parent.props_count += 1
            node = parent
        elif parent_tag == "Properties" and isinstance(parent, _Item):
            property_name = attrs.get("name")
            if property_name == "Name" or (
                property_name == "Source" and parent.class_name in SCRIPT_CLASSES
            ):
                node = _Prop(tag, position)
                (parent.names if property_name == "Name" else parent.sources).append(node)
            elif property_name in RIG_PROPERTIES.get(parent.class_name, ()):
                node = _Prop(tag, position)
                parent.avatar_props.setdefault(property_name, []).append(node)
        if isinstance(parent, _Prop):
            parent.nested = True
        self.stack.append((tag, node))

    def _close(self, tag):
        _, node = self.stack.pop()
        if isinstance(node, (_Item, _Prop)) and node.tag == tag:
            node.end = self.parser.CurrentByteIndex
        elif tag == "Properties" and isinstance(node, _Item):
            node.props_end = self.parser.CurrentByteIndex

    def _text(self, text):
        if self.stack and isinstance(self.stack[-1][1], _Prop):
            self.stack[-1][1].text.append(text)

    def locate(self, path=MENU_PATH, classes=MENU_CLASSES):
        parent = self.root
        for depth, (name, class_name) in enumerate(zip(path, classes)):
            nodes = []
            for child in parent.children:
                if child.props_count > 1 or len(child.names) > 1:
                    raise Failure("Há propriedades duplicadas no caminho do menu.")
                child_name = child.names[0].value({"string"}) if child.names else child.class_name
                nodes.append((child, child_name, child.class_name))
            found = _find(nodes, name, class_name, depth < len(path) - 1)
            if found is None:
                return parent, depth, None
            parent = found
        if len(parent.sources) > 1:
            raise Failure(f"O {path[-1]} tem mais de uma propriedade Source.")
        return parent, len(path), parent.sources[0] if parent.sources else None

    def bytes(self, value):
        return value.encode(self.encoding, errors="xmlcharrefreplace")

    def close_start(self, node):
        return self.bytes("</" + node.tag)

    def source_markup(self, tag, source):
        text = escape(source).replace("\r", "&#13;")
        return self.bytes(f'<{tag} name="Source">{text}</{tag}>')

    def child_edit(self, parent, markup):
        if self.raw.startswith(self.close_start(parent), parent.end):
            return parent.end, parent.end, markup
        self_close = self.bytes("/>")
        start = parent.end - len(self_close)
        if self.raw[start:parent.end] != self_close:
            raise Failure("A marcação do contêiner do menu está incompleta.")
        closing = self.bytes(f"</{parent.tag}>")
        return start, parent.end, self.bytes(">") + markup + closing

    def prop_end(self, prop):
        end = prop.end
        if self.raw.startswith(self.close_start(prop), end):
            terminator = self.bytes(">")
            while self.raw[end:end + len(terminator)] != terminator:
                end += len(terminator)
            end += len(terminator)
        return end

    def patch(self, source, known):
        return self.patch_script(MENU_PATH, MENU_CLASSES, source, lambda old: _accept_source(old, source, known))

    def patch_script(self, path, classes, source, accept):
        parent, depth, prop = self.locate(path, classes)
        if depth < len(path):
            markup = b""
            for name, class_name in reversed(list(zip(path[depth:], classes[depth:]))):
                reference = "RBX_CYBEROUTLAW_" + name
                while reference in self.refs:
                    reference += "_"
                self.refs.add(reference)
                opening = self.bytes(f'<Item class="{class_name}" referent="{reference}"><Properties>')
                name_prop = self.bytes(f'<string name="Name">{name}</string>')
                source_prop = self.source_markup("ProtectedString", source) if name == path[-1] else b""
                markup = opening + name_prop + source_prop + self.bytes("</Properties>") + markup + self.bytes("</Item>")
            start, end, replacement = self.child_edit(parent, markup)
            return self.raw[:start] + replacement + self.raw[end:], True
        old = prop.value({"ProtectedString", "string"}) if prop is not None else ""
        accept(old)
        if old == source:
            return self.raw, False
        if prop is None:
            raise Failure(f"O {path[-1]} existente não tem a propriedade Source.")
        return self.raw[:prop.start] + self.source_markup(prop.tag, source) + self.raw[self.prop_end(prop):], True

    def enforce_lighting(self):
        lighting = _single((node for node in self.root.children if node.class_name == "Lighting"), "Lighting")
        if lighting is None:
            return self.raw
        if lighting.props_count > 1:
            raise Failure("O place tem propriedades de iluminação duplicadas.")
        edits = []
        additions = []
        for name, kind, value in LIGHTING:
            text = ("true" if value else "false") if kind == "bool" else str(value)
            markup = self.bytes(f'<{kind} name="{name}">{text}</{kind}>')
            prop = _single(lighting.avatar_props.get(name, ()), name)
            if prop:
                if prop.value({kind}).strip().lower() != text:
                    edits.append((prop.start, self.prop_end(prop), markup))
            else:
                additions.append(markup)
        if additions:
            joined = b"".join(additions)
            if lighting.props_count:
                edits.append(self.child_edit(_Item("Properties", 0, end=lighting.props_end), joined))
            elif lighting.children:
                start = lighting.children[0].start
                edits.append((start, start, self.bytes("<Properties>") + joined + self.bytes("</Properties>")))
            else:
                edits.append(self.child_edit(lighting, self.bytes("<Properties>") + joined + self.bytes("</Properties>")))
        raw = self.raw
        for start, end, replacement in sorted(edits, reverse=True):
            raw = raw[:start] + replacement + raw[end:]
        return raw

    def enforce_r6(self):
        starter = _single((node for node in self.root.children if node.class_name == "StarterPlayer"), "StarterPlayer")
        settings = _single((node for node in self.root.children if node.class_name == "AvatarSettings"), "AvatarSettings")
        global_rules = [node for node in settings.children if node.class_name == "AvatarRules"] if settings else []
        default = _single((node for node in global_rules if node.names and node.names[0].value({"string"}) == "DefaultAvatarRules"), "DefaultAvatarRules")
        rules = [default] if default else []
        link = _single(starter.avatar_props.get("PlaceAvatarRules", ()), "PlaceAvatarRules")
        reference = link.value({"Ref"}).strip() if link else "null"
        if reference not in ("null", ""):
            explicit = _single(
                (node for node in [*global_rules, *starter.children, *self.root.children]
                 if node.class_name == "AvatarRules" and node.referent == reference), "regra de avatar vinculada"
            )
            if explicit is None:
                raise Failure("O place tem uma regra de avatar vinculada em um caminho desconhecido.")
            if explicit not in rules:
                rules.append(explicit)

        targets = [(starter, "GameSettingsAvatar")]
        for rule in rules:
            targets.append((rule, "AvatarType"))
            body = _single((node for node in rule.children if node.class_name == "AvatarBodyRules"), "AvatarBodyRules")
            if body:
                targets.append((body, "AvatarType"))
        edits = []
        for node, name in targets:
            if node.props_count > 1:
                raise Failure("O place tem propriedades de avatar duplicadas.")
            prop = _single(node.avatar_props.get(name, ()), name)
            markup = self.bytes(f'<token name="{name}">{R6}</token>')
            if prop:
                if prop.value({"token"}).strip() != str(R6):
                    edits.append((prop.start, self.prop_end(prop), markup))
            elif node.props_count:
                edits.append(self.child_edit(_Item("Properties", 0, end=node.props_end), markup))
            elif node.children:
                start = node.children[0].start
                edits.append((start, start, self.bytes("<Properties>") + markup + self.bytes("</Properties>")))
            else:
                edits.append(self.child_edit(node, self.bytes("<Properties>") + markup + self.bytes("</Properties>")))
        raw = self.raw
        for start, end, replacement in sorted(edits, reverse=True):
            raw = raw[:start] + replacement + raw[end:]
        return raw


def _binary_location(doc, path=MENU_PATH, classes=MENU_CLASSES):
    parent = -1
    for depth, (name, class_name) in enumerate(zip(path, classes)):
        nodes = [
            (ref, doc.objects[ref]["name"], doc.objects[ref]["class"])
            for ref in doc.children.get((parent, name), [])
        ]
        # Services are unique by class even if their Name was customized.
        if depth < len(path) - 1:
            nodes.extend(
                (ref, obj["name"], class_name)
                for ref, obj in doc.objects.items()
                if doc.parents[ref] == parent and obj["class"] == class_name and obj["name"] != name
            )
        found = _find(nodes, name, class_name, depth < len(path) - 1)
        if found is None:
            return parent, depth
        parent = found
    return parent, len(path)


def _add_binary(doc, parent, depth, source, force_r6=False, path=MENU_PATH, classes=MENU_CLASSES):
    next_ref = max(doc.objects, default=-1) + 1
    next_group = max(doc.groups, default=-1) + 1
    parents = list(doc.parents.items())
    instances, props = [], []
    for offset, (name, class_name) in enumerate(zip(path[depth:], classes[depth:])):
        ref = next_ref + offset
        group = pack32(next_group + offset)
        service = class_name in SERVICE_CLASSES
        service_byte = b"\1" if service else b"\0"
        instance = group + pstring(class_name.encode()) + service_byte + pack32(1) + prefs([ref])
        instances.append(Chunk(b"INST", instance + (b"\1" if service else b"")))
        props.append(Chunk(b"PROP", group + pstring(b"Name") + b"\1" + pstring(name.encode())))
        if class_name == "StarterPlayer" and force_r6:
            props.append(Chunk(b"PROP", group + pstring(b"GameSettingsAvatar") + b"\x12" + puints([R6])))
        if offset == len(path) - depth - 1:
            props.append(Chunk(b"PROP", group + pstring(b"Source") + b"\1" + pstring(source.encode())))
        parents.append((ref, parent))
        parent = ref

    if doc.parent_chunk is None:
        raise Failure("O arquivo binário do place não contém a árvore de instâncias.")
    children, ancestors = zip(*parents)
    doc.parent_chunk.data = b"\0" + pack32(len(parents)) + prefs(children) + prefs(ancestors)
    doc.parent_chunk.packet = None
    after_instances = max(
        (i + 1 for i, chunk in enumerate(doc.chunks) if chunk.tag == b"INST"),
        default=doc.chunks.index(doc.parent_chunk),
    )
    doc.chunks[after_instances:after_instances] = instances
    before_parents = doc.chunks.index(doc.parent_chunk)
    doc.chunks[before_parents:before_parents] = props
    header = bytearray(doc.header)
    struct.pack_into("<II", header, 16, len(doc.groups) + len(instances), len(parents))
    doc.header = bytes(header)


def _binary_r6(doc):
    starter = _single((ref for ref, obj in doc.objects.items() if obj["class"] == "StarterPlayer" and doc.parents[ref] == -1), "StarterPlayer")
    settings = _single((ref for ref, obj in doc.objects.items() if obj["class"] == "AvatarSettings" and doc.parents[ref] == -1), "AvatarSettings")
    default = _single(
        (ref for ref in doc.children.get((settings, "DefaultAvatarRules"), ())
         if doc.objects[ref]["class"] == "AvatarRules"), "DefaultAvatarRules"
    )
    rules = {default} if default is not None else set()
    targets = []
    if starter is not None:
        targets.append((starter, "GameSettingsAvatar"))
        obj = doc.objects[starter]
        gid, index = obj["group"], obj["index"]
        link = doc.props.get((gid, "PlaceAvatarRules"))
        if link:
            chunk, kind, start = link
            if kind != 0x13:
                raise Failure("A propriedade PlaceAvatarRules não é uma referência.")
            linked = refs(chunk.data[start:], len(doc.groups[gid]["refs"]))[index]
            if linked != -1:
                if doc.objects.get(linked, {}).get("class") != "AvatarRules":
                    raise Failure("O place tem uma referência de avatar inválida.")
                rules.add(linked)

    for rule in sorted(rules):
        targets.append((rule, "AvatarType"))
        body = _single((ref for ref, obj in doc.objects.items()
                        if doc.parents[ref] == rule and obj["class"] == "AvatarBodyRules"), "AvatarBodyRules")
        if body is not None:
            targets.append((body, "AvatarType"))

    changed = False
    for ref, name in targets:
        obj = doc.objects[ref]
        gid, index = obj["group"], obj["index"]
        count = len(doc.groups[gid]["refs"])
        prop = doc.props.get((gid, name))
        if prop is None:
            if count != 1:
                raise Failure(f"Não foi possível separar {name} das outras regras de avatar.")
            data = pack32(gid) + pstring(name.encode()) + b"\x12" + puints([R6])
            chunk = Chunk(b"PROP", data)
            doc.chunks.insert(doc.chunks.index(doc.parent_chunk), chunk)
            doc.props[gid, name] = chunk, 0x12, len(data) - 4
            changed = True
            continue
        chunk, kind, start = prop
        if kind != 0x12:
            raise Failure(f"A propriedade {name} não contém um tipo de avatar.")
        values = uints(chunk.data[start:], count)
        if values[index] != R6:
            values[index] = R6
            chunk.data = chunk.data[:start] + puints(values)
            chunk.packet = None
            changed = True
    return changed


def _binary_lighting(doc):
    lighting = _single((ref for ref, obj in doc.objects.items() if obj["class"] == "Lighting" and doc.parents[ref] == -1), "Lighting")
    if lighting is None:
        return False
    obj = doc.objects[lighting]
    gid, index = obj["group"], obj["index"]
    count = len(doc.groups[gid]["refs"])
    changed = False
    for name, kind, value in LIGHTING:
        code = 0x12 if kind == "token" else 0x02
        prop = doc.props.get((gid, name))
        if prop is None:
            if count != 1:
                raise Failure("Não foi possível separar a iluminação de outros serviços.")
            payload = puints([value]) if kind == "token" else bytes([1 if value else 0])
            data = pack32(gid) + pstring(name.encode()) + bytes([code]) + payload
            chunk = Chunk(b"PROP", data)
            doc.chunks.insert(doc.chunks.index(doc.parent_chunk), chunk)
            doc.props[gid, name] = chunk, code, len(data) - len(payload)
            changed = True
            continue
        chunk, found, start = prop
        if found != code:
            raise Failure(f"A propriedade {name} da iluminação tem um tipo inesperado.")
        if kind == "token":
            values = uints(chunk.data[start:], count)
            if values[index] != value:
                values[index] = value
                chunk.data = chunk.data[:start] + puints(values)
                chunk.packet = None
                changed = True
        else:
            current = chunk.data[start + index]
            if bool(current) != value:
                data = bytearray(chunk.data)
                data[start + index] = 1 if value else 0
                chunk.data = bytes(data)
                chunk.packet = None
                changed = True
    return changed


def _document(raw):
    if not 0 < len(raw) <= MAX_FILE:
        raise Failure("O arquivo do place está vazio ou acima do limite de tamanho.")
    return Binary(raw) if raw.startswith(BINARY_MAGIC) else _Xml(raw)


def place_format(raw):
    """Validate the downloaded envelope before treating it as a backup."""
    _read_document(raw)
    return "rbxl" if raw.startswith(BINARY_MAGIC) else "rbxlx"


def same_binary_place(first, second):
    """Allow repacking while requiring every instance and opaque chunk to agree."""
    if not first.startswith(BINARY_MAGIC) or not second.startswith(BINARY_MAGIC):
        return False
    try:
        left, right = _read_document(first), _read_document(second)
    except Failure:
        return False
    return (
        left.header == right.header and len(left.chunks) == len(right.chunks)
        and all(a.tag == b.tag and a.data == b.data for a, b in zip(left.chunks, right.chunks))
    )


def _read_document(raw):
    try:
        return _document(raw)
    except (ValueError, IndexError, KeyError, struct.error) as exc:
        raise Failure(f"Não foi possível ler o place Roblox. {exc}") from None


def script_source(raw, path=MENU_PATH, classes=MENU_CLASSES):
    try:
        doc = _read_document(raw)
        if isinstance(doc, Binary):
            ref, depth = _binary_location(doc, path, classes)
            if depth == len(path):
                obj = doc.objects[ref]
                return doc.value(ref, "Source").decode("utf-8") if (obj["group"], "Source") in doc.props else ""
        else:
            _, depth, prop = doc.locate(path, classes)
            if depth == len(path):
                return prop.value({"ProtectedString", "string"}) if prop is not None else ""
        return None
    except (ValueError, IndexError, KeyError, struct.error) as exc:
        raise Failure(f"Não foi possível ler o código de {path[-1]} no place. {exc}") from None


def menu_source(raw):
    return script_source(raw)


def server_source(raw, name):
    return script_source(raw, *server_route(name))


def _patch_script(raw, path, classes, source, accept, force_r6=False):
    """Edit one script per pass, so every binary edit starts from fresh indexes."""
    doc = _read_document(raw)
    if not isinstance(doc, Binary):
        return doc.patch_script(path, classes, source, accept)
    ref, depth = _binary_location(doc, path, classes)
    if depth < len(path):
        _add_binary(doc, ref, depth, source, force_r6, path, classes)
        return doc.encode(), True
    obj = doc.objects[ref]
    if (obj["group"], "Source") not in doc.props:
        raise Failure(f"O {path[-1]} existente não tem a propriedade Source.")
    old = doc.value(ref, "Source").decode("utf-8")
    accept(old)
    if old == source:
        return raw, False
    doc.set_sources([dict(path=path, **{"class": classes[-1]}, before=old, after=source)])
    return doc.encode(), True


def patch_place(raw, source, known=frozenset(), *, force_r6=False, server=None):
    """Install the menu, then each managed server script, then the R6 avatar rules."""
    try:
        if not source:
            raise Failure("O código do menu está vazio.")
        server = dict(server or {})
        for name, code in server.items():
            _managed_route(name, code)
        result, changed = _patch_script(
            raw, MENU_PATH, MENU_CLASSES, source, lambda old: _accept_source(old, source, known), force_r6
        )
        for name, code in sorted(server.items()):
            result, edited = _patch_script(
                result, *_managed_route(name, code)[0], code,
                lambda old, name=name, code=code: _accept_managed(name, code, old),
            )
            changed = changed or edited
        if force_r6:
            doc = _read_document(result)
            if isinstance(doc, Binary):
                if _binary_r6(doc):
                    result, changed = doc.encode(), True
            else:
                enforced = doc.enforce_r6()
                if enforced != result:
                    result, changed = enforced, True
            # Na mesma passagem de configurações do place: iluminação Realistic com prioridade de qualidade.
            doc = _read_document(result)
            if isinstance(doc, Binary):
                if _binary_lighting(doc):
                    result, changed = doc.encode(), True
            else:
                lit = doc.enforce_lighting()
                if lit != result:
                    result, changed = lit, True
        if not changed:
            return raw, False
        if menu_source(result) != source:
            raise Failure("O código do menu preparado divergiu na verificação.")
        for name, code in server.items():
            if managed_source(result, name, code) != code:
                raise Failure(f"O script {name} divergiu na verificação.")
        return result, True
    except (ValueError, IndexError, KeyError, struct.error) as exc:
        raise Failure(f"Não foi possível preparar o place. {exc}") from None
