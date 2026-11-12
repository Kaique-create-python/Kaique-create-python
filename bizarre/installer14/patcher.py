"""Patch estrito de Source no Place atual; mantém cenário, mídia e dados opacos."""
import hashlib
import struct
import xml.etree.ElementTree as ET
from .catalog import xml_doc
from .codec import Binary, Chunk, Failure, pack32, prefs, pstring


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def validate(rows):
    paths = set()
    for row in rows:
        path = tuple(row['path'])
        if len(path) < 2 or any(not isinstance(p, str) or not p or '/' in p for p in path) or path in paths:
            raise Failure('Caminho ausente/duplicado no pacote.')
        paths.add(path)
        if row['cls'] not in ('Script', 'LocalScript', 'ModuleScript') or not isinstance(row['source'], str):
            raise Failure('Classe/fonte invalida no pacote.')
        if row.get('add') and row['cls'] != 'ModuleScript':
            raise Failure('Somente modulos explicitos podem ser acrescentados.')


def recognized(row, source):
    if source != row['source'] and digest(source) not in row.get('known', []):
        raise Failure('Fonte desconhecida: ' + '/'.join(row['path']) + '. Backup preservado para revisao; nao forcar.')


def patch_place(raw, rows):
    validate(rows)
    if raw.startswith(b'<roblox!'):
        return patch_binary(raw, rows)
    try:
        root = xml_doc(raw)
    except ET.ParseError:
        raise Failure('Backup nao e um arquivo Roblox valido.') from None
    if root.tag != 'roblox' or root.get('version') != '4':
        raise Failure('Formato do Place nao reconhecido.')
    objects = {}
    def walk(parent, path):
        for obj in parent.findall('Item'):
            name = obj.findtext("Properties/string[@name='Name']")
            if name is None: raise Failure('Instancia sem nome no backup.')
            current = path + (name,)
            objects[current] = None if current in objects else obj
            walk(obj, current)
    walk(root, ())
    edits, additions = [], []
    for row in rows:
        path = tuple(row['path'])
        if path not in objects:
            if not row.get('add'): raise Failure('Fonte obrigatoria ausente: ' + '/'.join(path))
            if objects.get(path[:-1]) is None: raise Failure('Pai ausente/ambiguo: ' + '/'.join(path[:-1]))
            additions.append(row)
            continue
        obj = objects[path]
        if obj is None or obj.get('class') != row['cls']: raise Failure('Classe/caminho inesperado: ' + '/'.join(path))
        source = obj.find("Properties/ProtectedString[@name='Source']")
        if source is None: source = obj.find("Properties/string[@name='Source']")
        if source is None: raise Failure('Source ausente: ' + '/'.join(path))
        before = source.text or ''
        recognized(row, before)
        if before != row['source']: edits.append((source, row['source']))
    if not edits and not additions: return raw, False
    for source, text in edits: source.text = text
    used = {o.get('referent') for o in root.iter('Item')}
    for i, row in enumerate(additions):
        path = tuple(row['path']); ref = 'BB_AJUSTE14_' + str(i)
        while ref in used: ref += '_'
        used.add(ref)
        obj = ET.SubElement(objects[path[:-1]], 'Item', {'class': row['cls'], 'referent': ref})
        props = ET.SubElement(obj, 'Properties')
        ET.SubElement(props, 'string', name='Name').text = path[-1]
        ET.SubElement(props, 'ProtectedString', name='Source').text = row['source']
    return ET.tostring(root, encoding='utf-8'), True


def patch_binary(raw, rows):
    doc = Binary(raw)
    edits, additions = [], []
    for row in rows:
        path = row['path']; ref = -1; missing = False
        for name in path:
            found = doc.children.get((ref, name), [])
            if not found:
                missing = True; break
            if len(found) != 1: raise Failure('Caminho ambiguo: ' + '/'.join(path))
            ref = found[0]
        if missing:
            if not row.get('add'): raise Failure('Fonte obrigatoria ausente: ' + '/'.join(path))
            doc.locate(path[:-1])
            additions.append(row)
            continue
        if doc.objects[ref]['class'] != row['cls']: raise Failure('Classe inesperada: ' + '/'.join(path))
        before = doc.value(ref, 'Source').decode('utf-8')
        recognized(row, before)
        if before != row['source']:
            edits.append(dict(path=path, **{'class': row['cls']}, before=before, after=row['source']))
    if not edits and not additions: return raw, False
    if edits: doc.set_sources(edits)
    if additions:
        first = max(doc.objects, default=-1) + 1
        grouped = {}
        for i, row in enumerate(additions): grouped.setdefault(row['cls'], []).append((first + i, row))
        inst, props, parents = [], [], list(doc.parents.items())
        start = max(doc.groups, default=-1) + 1
        for i, (cls, items) in enumerate(grouped.items()):
            gid = start + i
            inst.append(Chunk(b'INST', pack32(gid) + pstring(cls.encode()) + b'\0' + pack32(len(items)) + prefs([ref for ref, _ in items])))
            props.append(Chunk(b'PROP', pack32(gid) + pstring(b'Name') + b'\1' + b''.join(pstring(row['path'][-1].encode()) for _, row in items)))
            props.append(Chunk(b'PROP', pack32(gid) + pstring(b'Source') + b'\1' + b''.join(pstring(row['source'].encode()) for _, row in items)))
            for ref, row in items: parents.append((ref, doc.locate(row['path'][:-1])))
        doc.parent_chunk.data = b'\0' + pack32(len(parents)) + prefs([r for r, _ in parents]) + prefs([p for _, p in parents])
        doc.parent_chunk.packet = None
        point = max(i for i, c in enumerate(doc.chunks) if c.tag == b'INST') + 1
        doc.chunks[point:point] = inst
        point = doc.chunks.index(doc.parent_chunk)
        doc.chunks[point:point] = props
        header = bytearray(doc.header)
        struct.pack_into('<II', header, 16, len(doc.groups) + len(grouped), len(doc.objects) + len(additions))
        doc.header = bytes(header)
    result = doc.encode()
    check = Binary(result)
    for row in rows:
        ref = check.locate(row['path'])
        if check.objects[ref]['class'] != row['cls'] or check.value(ref, 'Source').decode() != row['source']:
            raise Failure('Verificacao do patch divergiu; original preservado.')
    return result, True
