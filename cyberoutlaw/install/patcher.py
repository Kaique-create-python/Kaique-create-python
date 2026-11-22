"""Insert one client script into a full Roblox place, leaving other data intact."""

from dataclasses import dataclass, field
from hashlib import sha256
import struct
from xml.parsers import expat
from xml.sax.saxutils import escape

from .codec import Binary, Chunk, Failure, MAX_FILE, pack32, prefs, pstring


BINARY_MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"
MENU_NAME = "CyberOutlawMenu"
MENU_PATH = ("StarterPlayer", "StarterPlayerScripts", MENU_NAME)
MENU_CLASSES = ("StarterPlayer", "StarterPlayerScripts", "LocalScript")


def source_digest(source):
    return sha256(source.encode("utf-8")).hexdigest()


def _accept_source(old, new, known):
    if old != new and source_digest(old) not in known:
        raise Failure(
            "Já existe um CyberOutlawMenu com código desconhecido. "
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
                parent is self.root or parent.class_name in MENU_CLASSES[:2]
            ):
                node = _Item(tag, position, attrs.get("class", ""))
                parent.children.append(node)
        elif tag == "Properties" and parent_tag == "Item" and isinstance(parent, _Item):
            parent.props_count += 1
            node = parent
        elif parent_tag == "Properties" and isinstance(parent, _Item):
            property_name = attrs.get("name")
            if property_name == "Name" or (
                property_name == "Source" and parent.class_name == "LocalScript"
            ):
                node = _Prop(tag, position)
                (parent.names if property_name == "Name" else parent.sources).append(node)
        if isinstance(parent, _Prop):
            parent.nested = True
        self.stack.append((tag, node))

    def _close(self, tag):
        _, node = self.stack.pop()
        if isinstance(node, (_Item, _Prop)) and node.tag == tag:
            node.end = self.parser.CurrentByteIndex

    def _text(self, text):
        if self.stack and isinstance(self.stack[-1][1], _Prop):
            self.stack[-1][1].text.append(text)

    def locate(self):
        parent = self.root
        for depth, (name, class_name) in enumerate(zip(MENU_PATH, MENU_CLASSES)):
            nodes = []
            for child in parent.children:
                if child.props_count > 1 or len(child.names) > 1:
                    raise Failure("Há propriedades duplicadas no caminho do menu.")
                child_name = child.names[0].value({"string"}) if child.names else child.class_name
                nodes.append((child, child_name, child.class_name))
            found = _find(nodes, name, class_name, depth < 2)
            if found is None:
                return parent, depth, None
            parent = found
        if len(parent.sources) > 1:
            raise Failure("O CyberOutlawMenu tem mais de uma propriedade Source.")
        return parent, len(MENU_PATH), parent.sources[0] if parent.sources else None

    def bytes(self, value):
        return value.encode(self.encoding, errors="xmlcharrefreplace")

    def close_start(self, node):
        return self.bytes("</" + node.tag)

    def source_markup(self, tag, source):
        text = escape(source).replace("\r", "&#13;")
        return self.bytes(f'<{tag} name="Source">{text}</{tag}>')

    def add_child(self, parent, markup):
        if self.raw.startswith(self.close_start(parent), parent.end):
            return self.raw[:parent.end] + markup + self.raw[parent.end:]
        self_close = self.bytes("/>")
        start = parent.end - len(self_close)
        if self.raw[start:parent.end] != self_close:
            raise Failure("A marcação do contêiner do menu está incompleta.")
        closing = self.bytes(f"</{parent.tag}>")
        return self.raw[:start] + self.bytes(">") + markup + closing + self.raw[parent.end:]

    def patch(self, source, known):
        parent, depth, prop = self.locate()
        if depth < len(MENU_PATH):
            markup = b""
            for name, class_name in reversed(list(zip(MENU_PATH[depth:], MENU_CLASSES[depth:]))):
                reference = "RBX_CYBEROUTLAW_" + name
                while reference in self.refs:
                    reference += "_"
                self.refs.add(reference)
                opening = self.bytes(f'<Item class="{class_name}" referent="{reference}"><Properties>')
                name_prop = self.bytes(f'<string name="Name">{name}</string>')
                source_prop = self.source_markup("ProtectedString", source) if name == MENU_NAME else b""
                markup = opening + name_prop + source_prop + self.bytes("</Properties>") + markup + self.bytes("</Item>")
            return self.add_child(parent, markup), True
        old = prop.value({"ProtectedString", "string"}) if prop is not None else ""
        _accept_source(old, source, known)
        if old == source:
            return self.raw, False
        if prop is None:
            raise Failure("O CyberOutlawMenu existente não tem a propriedade Source.")
        end = prop.end
        if self.raw.startswith(self.close_start(prop), end):
            terminator = self.bytes(">")
            while self.raw[end:end + len(terminator)] != terminator:
                end += len(terminator)
            end += len(terminator)
        return self.raw[:prop.start] + self.source_markup(prop.tag, source) + self.raw[end:], True


def _binary_location(doc):
    parent = -1
    for depth, (name, class_name) in enumerate(zip(MENU_PATH, MENU_CLASSES)):
        nodes = [
            (ref, doc.objects[ref]["name"], doc.objects[ref]["class"])
            for ref in doc.children.get((parent, name), [])
        ]
        # Services are unique by class even if their Name was customized.
        if depth < 2:
            nodes.extend(
                (ref, obj["name"], class_name)
                for ref, obj in doc.objects.items()
                if doc.parents[ref] == parent and obj["class"] == class_name and obj["name"] != name
            )
        found = _find(nodes, name, class_name, depth < 2)
        if found is None:
            return parent, depth
        parent = found
    return parent, len(MENU_PATH)


def _add_binary(doc, parent, depth, source):
    next_ref = max(doc.objects, default=-1) + 1
    next_group = max(doc.groups, default=-1) + 1
    parents = list(doc.parents.items())
    instances, props = [], []
    for offset, (name, class_name) in enumerate(zip(MENU_PATH[depth:], MENU_CLASSES[depth:])):
        ref = next_ref + offset
        group = pack32(next_group + offset)
        service = class_name == "StarterPlayer"
        service_byte = b"\1" if service else b"\0"
        instance = group + pstring(class_name.encode()) + service_byte + pack32(1) + prefs([ref])
        instances.append(Chunk(b"INST", instance + (b"\1" if service else b"")))
        props.append(Chunk(b"PROP", group + pstring(b"Name") + b"\1" + pstring(name.encode())))
        if name == MENU_NAME:
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


def menu_source(raw):
    try:
        doc = _read_document(raw)
        if isinstance(doc, Binary):
            ref, depth = _binary_location(doc)
            if depth == len(MENU_PATH):
                obj = doc.objects[ref]
                return doc.value(ref, "Source").decode("utf-8") if (obj["group"], "Source") in doc.props else ""
        else:
            _, depth, prop = doc.locate()
            if depth == len(MENU_PATH):
                return prop.value({"ProtectedString", "string"}) if prop is not None else ""
        return None
    except (ValueError, IndexError, KeyError, struct.error) as exc:
        raise Failure(f"Não foi possível ler o código do menu no place. {exc}") from None


def patch_place(raw, source, known=frozenset()):
    try:
        if not source:
            raise Failure("O código do menu está vazio.")
        doc = _read_document(raw)
        if isinstance(doc, Binary):
            ref, depth = _binary_location(doc)
            if depth < len(MENU_PATH):
                _add_binary(doc, ref, depth, source)
            else:
                obj = doc.objects[ref]
                if (obj["group"], "Source") not in doc.props:
                    raise Failure("O CyberOutlawMenu existente não tem a propriedade Source.")
                old = doc.value(ref, "Source").decode("utf-8")
                _accept_source(old, source, known)
                if old == source:
                    return raw, False
                doc.set_sources([dict(path=MENU_PATH, **{"class": "LocalScript"}, before=old, after=source)])
            result = doc.encode()
        else:
            result, changed = doc.patch(source, known)
            if not changed:
                return raw, False
        if menu_source(result) != source:
            raise Failure("O código do menu preparado divergiu na verificação.")
        return result, True
    except (ValueError, IndexError, KeyError, struct.error) as exc:
        raise Failure(f"Não foi possível preparar o place. {exc}") from None
