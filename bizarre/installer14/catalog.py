"""Append the audited VFX catalog; preserve original packets and remap all references."""
import copy
import base64
import binascii
import struct
import xml.etree.ElementTree as ET
from .codec import Binary,Chunk,Failure,pack32,pstring,prefs,refs,puints,uints,u32,string,MAX_FILE
NAME='BB_VFXCatalogo14'
ALLOWED={'Folder','Part','Attachment','ParticleEmitter','Beam','Trail'}

def xml_doc(raw):
 if len(raw)>MAX_FILE or b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():raise Failure('XML excede limites ou usa entidades externas.')
 parser=ET.XMLParser(target=ET.TreeBuilder(insert_comments=True,insert_pis=True))
 root=ET.fromstring(raw,parser=parser)
 if root.tag!='roblox' or root.get('version')!='4':raise Failure('XML Roblox invalido.')
 return root

def _content_safe(data,count):
 # Content type 0x22: interleaved types, URI table, object table, external table.
 # Catalog accepts only None / URI. External and object-backed content fail closed.
 types=uints(data[:count*4],count);p=count*4
 if any(t not in (0,2) for t in types):raise Failure('Content de catalogo deve conter apenas URI.')
 n=u32(data,p);p+=4
 if n!=types.count(2):raise Failure('Tabela URI inconsistente.')
 for _ in range(n):_,p=string(data,p)
 if data[p:]!=bytes(8):raise Failure('Content com referencias externas nao autorizado.')

def _tree(doc,root):
 children={}
 for r,p in doc.parents.items():children.setdefault(p,[]).append(r)
 result=[];visiting=set()
 def visit(r):
  if r in visiting:raise Failure('Ciclo no catalogo.')
  visiting.add(r);result.append(r)
  for child in children.get(r,[]):visit(child)
 visit(root);return result

def _validate_catalog(doc):
 roots=[r for r,p in doc.parents.items() if p==-1]
 if len(roots)!=1 or doc.objects[roots[0]]['class']!='Folder' or doc.objects[roots[0]]['name']!=NAME:raise Failure('Catalogo exige raiz unica Folder '+NAME)
 if len(_tree(doc,roots[0]))!=len(doc.objects) or any(o['class'] not in ALLOWED for o in doc.objects.values()):raise Failure('Catalogo contem classe ou arvore nao autorizada.')
 for (g,name),(c,t,q) in doc.props.items():
  count=len(doc.groups[g]['refs']);data=c.data[q:]
  if t==19 and any(r!=-1 and r not in doc.objects for r in refs(data,count)):raise Failure('Referencia externa no catalogo.')
  if t==28 and any(i>=len(doc.shared) for i in uints(data,count)):raise Failure('SharedString ausente.')
  if t==34:_content_safe(data,count)
  if not 1<=t<=34:raise Failure('Tipo de propriedade do catalogo nao revisado.')
  if name=='Source':raise Failure('Catalogo nao pode conter codigo.')
 return roots[0]

def _binary_equal(doc,root,cat,catroot):
 # Match children by name and occurrence, preserving intentionally duplicated names.
 def index(d,r):
  children={}
  for child,parent in d.parents.items():children.setdefault(parent,[]).append(child)
  result={}
  def visit(ref,path):
   result[path]=ref;counts={}
   for child in children.get(ref,[]):
    o=d.objects[child];key=(o['class'],o['name']);n=counts.get(key,0);counts[key]=n+1
    visit(child,path+((key,n),))
  visit(r,());return result
 a,b=index(doc,root),index(cat,catroot)
 if set(a)!=set(b):return False
 mapping={b[k]:a[k] for k in a};inverse={v:k for k,v in mapping.items()}
 for cg,group in cat.groups.items():
  targets=[mapping[r] for r in group['refs']];tg=doc.objects[targets[0]]['group'];target=doc.groups[tg]
  if target['name']!=group['name'] or target['refs']!=targets:return False
  expected={n for g,n in cat.props if g==cg};actual={n for g,n in doc.props if g==tg}
  if expected!=actual:return False
  for name in expected:
   c,t,q=cat.props[cg,name];d,dt,dq=doc.props[tg,name]
   if t!=dt:return False
   left,right=c.data[q:],d.data[dq:];count=len(targets)
   if t==19:
    try:right=prefs([-1 if r==-1 else inverse[r] for r in refs(right,count)])
    except KeyError:return False
   elif t==28:
    try:
     if [cat.shared[i] for i in uints(left,count)]!=[doc.shared[i] for i in uints(right,count)]:return False
    except IndexError:return False
    continue
   if left!=right:return False
 return True

def binary_catalog(raw,catalog):
 doc,cat=Binary(raw),Binary(catalog);cr=_validate_catalog(cat)
 parent=doc.locate(['ReplicatedStorage'])
 if doc.objects[parent]['class']!='ReplicatedStorage':raise Failure('ReplicatedStorage inesperado.')
 existing=doc.children.get((parent,NAME),[])
 if existing:
  if len(existing)!=1 or not _binary_equal(doc,existing[0],cat,cr):raise Failure('Catalogo existente desconhecido; exporte para revisao.')
  return raw,False
 first=max(doc.objects,default=-1)+1;gm={g:max(doc.groups,default=-1)+1+i for i,g in enumerate(cat.groups)}
 rm={r:first+i for i,r in enumerate(cat.objects)};inst=[];props=[]
 for g,group in cat.groups.items():
  if group['service']:raise Failure('Catalogo nao pode acrescentar servicos.')
  inst.append(Chunk(b'INST',pack32(gm[g])+pstring(group['name'].encode())+b'\0'+pack32(len(group['refs']))+prefs([rm[r] for r in group['refs']])))
 for (g,name),(chunk,t,q) in cat.props.items():
  data=chunk.data[q:];count=len(cat.groups[g]['refs'])
  if t==19:data=prefs([-1 if r==-1 else rm[r] for r in refs(data,count)])
  elif t==28:data=puints([len(doc.shared)+i for i in uints(data,count)])
  props.append(Chunk(b'PROP',pack32(gm[g])+pstring(name.encode())+bytes([t])+data))
 parents=list(doc.parents.items())+[(rm[r],parent if p==-1 else rm[p]) for r,p in cat.parents.items()]
 doc.parent_chunk.data=b'\0'+pack32(len(parents))+prefs([r for r,p in parents])+prefs([p for r,p in parents]);doc.parent_chunk.packet=None
 if cat.shared:
  tables=[c for c in doc.chunks if c.tag==b'SSTR']
  payload=pack32(0)+pack32(len(doc.shared)+len(cat.shared))+b''.join(doc.shared+cat.shared)
  if tables:tables[0].data=payload;tables[0].packet=None
  else:doc.chunks.insert(0,Chunk(b'SSTR',payload))
 point=max(i for i,c in enumerate(doc.chunks) if c.tag==b'INST')+1;doc.chunks[point:point]=inst
 point=doc.chunks.index(doc.parent_chunk);doc.chunks[point:point]=props
 header=bytearray(doc.header);struct.pack_into('<II',header,16,len(doc.groups)+len(cat.groups),len(doc.objects)+len(cat.objects));doc.header=bytes(header)
 result=doc.encode()
 if len(result)>MAX_FILE:raise Failure('Place preparado acima do limite.')
 check=Binary(result)
 if not _binary_equal(check,rm[cr],cat,cr):raise Failure('Catalogo inserido divergiu.')
 # Opaque map/media packets remain literally unchanged, except PRNT/SSTR.
 for c in Binary(raw).chunks:
  if c.tag not in (b'PRNT',b'SSTR') and c.packet not in [n.packet for n in check.chunks]:raise Failure('Pacote original alterado durante insercao.')
 return result,True

def _xml_signature(root):
 refs={o.get('referent'):str(i) for i,o in enumerate(root.iter('Item'))}
 if len(refs)!=len(list(root.iter('Item'))):raise Failure('Referentes XML repetidos.')
 def node(el):
  attrs=dict(el.attrib)
  if el.tag=='Item':attrs['referent']=refs[el.get('referent')]
  text=(el.text or '').strip() if el.tag=='Ref' else (el.text or '')
  if el.tag=='Ref' and text!='null':
   if text not in refs:raise Failure('Referencia XML externa no catalogo.')
   text=refs[text]
  # Whitespace between elements is serialization only; strings retain whitespace.
  if len(el) and not text.strip():text=''
  return el.tag,tuple(sorted(attrs.items())),text,tuple(node(c) for c in el)
 return node(root)

def _xml_shared_values(doc,root):
 keys={value.text or '' for value in root.iter('SharedString')}
 if not keys:return {}
 tables=doc.findall('SharedStrings')
 if len(tables)!=1:raise Failure('Tabela SharedStrings XML ausente/ambigua.')
 result={}
 for key in keys:
  matches=[entry for entry in tables[0] if entry.tag=='SharedString' and entry.get('md5')==key]
  if not key or len(matches)!=1:raise Failure('SharedString XML ausente/ambigua.')
  try:result[key]=base64.b64decode(''.join((matches[0].text or '').split()),validate=True)
  except (ValueError,binascii.Error):raise Failure('Payload SharedString XML invalido.') from None
 return result

def xml_catalog(raw,catalog):
 doc,cat=xml_doc(raw),xml_doc(catalog);roots=cat.findall('Item')
 if len(roots)!=1 or roots[0].get('class')!='Folder' or roots[0].findtext("Properties/string[@name='Name']")!=NAME:raise Failure('Raiz XML do catalogo invalida.')
 source=roots[0]
 if any(o.get('class') not in ALLOWED for o in source.iter('Item')):raise Failure('Catalogo contem classe nao autorizada.')
 expected=_xml_signature(source);expected_shared=_xml_shared_values(cat,source)
 parents=[o for o in doc.findall('Item') if o.get('class')=='ReplicatedStorage' and o.findtext("Properties/string[@name='Name']")=='ReplicatedStorage']
 if len(parents)!=1:raise Failure('ReplicatedStorage ausente/ambiguo.')
 existing=[o for o in parents[0].findall('Item') if o.findtext("Properties/string[@name='Name']")==NAME]
 if existing:
  if len(existing)!=1 or _xml_signature(existing[0])!=expected or _xml_shared_values(doc,existing[0])!=expected_shared:raise Failure('Catalogo existente desconhecido; exporte para revisao.')
  return raw,False
 used={o.get('referent') for o in doc.iter('Item')};new=copy.deepcopy(source);mapping={}
 for i,obj in enumerate(new.iter('Item')):
  ref='BB_AJUSTE14_VFX_'+str(i)
  while ref in used:ref+='_' 
  used.add(ref);mapping[obj.get('referent')]=ref;obj.set('referent',ref)
 for value in new.iter('Ref'):
  if value.text and value.text!='null':value.text=mapping[value.text]
 shared=cat.find('SharedStrings')
 if shared is not None:
  dest=doc.find('SharedStrings')
  if dest is None:dest=ET.SubElement(doc,'SharedStrings')
  for item in shared:
   matches=[e for e in dest if e.get('md5')==item.get('md5')]
   if len(matches)>1 or matches and any((e.text or '')!=(item.text or '') for e in matches):raise Failure('SharedString XML conflitante.')
   if not matches:dest.append(copy.deepcopy(item))
 parents[0].append(new);result=ET.tostring(doc,encoding='utf-8')
 if len(result)>MAX_FILE:raise Failure('Place preparado acima do limite.')
 return result,True

def patch_catalog(raw,catalog):
 return binary_catalog(raw,catalog) if raw.startswith(b'<roblox!') else xml_catalog(raw,catalog)
