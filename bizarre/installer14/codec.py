"""Reviewed V13 binary codec, unchanged behavior. No network or installer entrypoint."""
import ctypes,ctypes.util,struct,sys
MAX_FILE=64*1024*1024
MAX_INFLATED=256*1024*1024
class Failure(Exception):
 def __init__(self,message,code=None):super().__init__(message);self.code=code

def u32(b,p=0):return struct.unpack_from('<I',b,p)[0]

def pack32(x):return struct.pack('<I',x)

def string(b,p):
 n=u32(b,p);p+=4
 if n>MAX_INFLATED or p+n>len(b):raise ValueError('String RBXL truncada')
 return b[p:p+n],p+n

def pstring(b):return pack32(len(b))+b

def uints(b,n):
 if len(b)!=n*4:raise ValueError('Array RBXL truncado')
 return [int.from_bytes(bytes((b[i],b[n+i],b[2*n+i],b[3*n+i])),'big')for i in range(n)]

def puints(values):
 rows=[v.to_bytes(4,'big')for v in values]
 return b''.join(bytes(r[j]for r in rows)for j in range(4))

def refs(b,n):
 result=[];value=0
 for v in uints(b,n):value+=(v>>1)^-(v&1);result.append(value)
 return result

def prefs(values):
 prior=0;rows=[]
 for v in values:
  delta=v-prior;prior=v
  if not -2**31<=delta<2**31:raise ValueError('Referente fora do limite')
  rows.append(((delta<<1)^(delta>>31))&0xffffffff)
 return puints(rows)

class Compression:
 def __init__(self):
  names=[ctypes.util.find_library('zstd'),'libzstd.so','libzstd.so.1',str(__import__('pathlib').Path(sys.prefix)/'lib/libzstd.so')]
  self.z=None
  for name in names:
   if name:
    try:self.z=ctypes.CDLL(name);break
    except OSError:pass
  if self.z is None:raise Failure('Instale a biblioteca de compressão: pkg install zstd')
  for n,args in [('ZSTD_decompress',[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_char_p,ctypes.c_size_t]),
    ('ZSTD_compress',[ctypes.c_void_p,ctypes.c_size_t,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_int]),
    ('ZSTD_compressBound',[ctypes.c_size_t]),('ZSTD_isError',[ctypes.c_size_t])]:
   f=getattr(self.z,n);f.argtypes=args;f.restype=ctypes.c_size_t
 def decompress(self,b,n):
  if b[:4]==b'\x28\xb5\x2f\xfd':
   out=ctypes.create_string_buffer(n);size=self.z.ZSTD_decompress(out,n,b,len(b))
   if self.z.ZSTD_isError(size)or size!=n:raise ValueError('Bloco Zstd inválido')
   return out.raw
  # LZ4 raw block, bounded by the already validated chunk size.
  out=bytearray();i=0
  while i<len(b):
   token=b[i];i+=1;literal=token>>4
   if literal==15:
    while True:
     v=b[i];i+=1;literal+=v
     if v!=255:break
   if i+literal>len(b)or len(out)+literal>n:raise ValueError('Bloco LZ4 inválido')
   out+=b[i:i+literal];i+=literal
   if i==len(b):break
   offset=int.from_bytes(b[i:i+2],'little');i+=2;length=(token&15)+4
   if offset<=0 or offset>len(out):raise ValueError('Distância LZ4 inválida')
   if token&15==15:
    while True:
     v=b[i];i+=1;length+=v
     if v!=255:break
   if len(out)+length>n:raise ValueError('Bloco LZ4 excedeu limite')
   for _ in range(length):out.append(out[-offset])
  if len(out)!=n:raise ValueError('Comprimento LZ4 inválido')
  return bytes(out)
 def compress(self,b):
  size=self.z.ZSTD_compressBound(len(b));out=ctypes.create_string_buffer(size)
  size=self.z.ZSTD_compress(out,size,b,len(b),3)
  if self.z.ZSTD_isError(size):raise ValueError('Falha de compressão Zstd')
  return out.raw[:size]

class Chunk:
 def __init__(self,tag,data,packet=None):self.tag,self.data,self.packet=tag,data,packet
 def encoded(self,codec):
  if self.packet is not None:return self.packet
  data=codec.compress(self.data)
  return self.tag+struct.pack('<III',len(data),len(self.data),0)+data

class Binary:
 def __init__(self,blob):
  if len(blob)>MAX_FILE or blob[:14]!=b'<roblox!\x89\xff\r\n\x1a\n' or len(blob)<32:raise ValueError('Arquivo não é RBXL/RBXM binário compatível')
  if blob[14:16]!=b'\0\0':raise ValueError('Versão binária desconhecida')
  self.header=blob[:32];self.codec=Compression();self.chunks=[];p=32;inflated=0
  while p+16<=len(blob):
   tag,compressed,size,reserved=struct.unpack_from('<4sIII',blob,p)
   if reserved!=0 or size>MAX_INFLATED:raise ValueError('Cabeçalho de bloco desconhecido')
   end=p+16+(compressed or size)
   if end>len(blob):raise ValueError('Arquivo truncado')
   inflated+=size
   if inflated>MAX_INFLATED:raise ValueError('Arquivo descomprimido acima do limite')
   raw=blob[p+16:end];data=self.codec.decompress(raw,size)if compressed else raw
   self.chunks.append(Chunk(tag,data,blob[p:end]));p=end
   if tag==b'END\0':break
  if p!=len(blob)or not self.chunks or self.chunks[-1].tag!=b'END\0':raise ValueError('Final RBXL inválido')
  self.groups={};self.objects={};self.props={};self.parents={};self.shared=[];self.parent_chunk=None;self.stringcache={}
  for c in self.chunks:
   d=c.data
   if c.tag==b'INST':
    gid=u32(d);name,q=string(d,4);service=d[q];count=u32(d,q+1);q+=5
    rr=refs(d[q:q+count*4],count);q+=count*4
    tail=d[q:]
    if gid in self.groups or service not in (0,1)or len(tail)!=(count if service else 0):raise ValueError('Grupo de instâncias desconhecido')
    self.groups[gid]={'name':name.decode(),'refs':rr,'service':service,'tail':tail}
    for index,ref in enumerate(rr):
     if ref<0 or ref in self.objects:raise ValueError('Referente repetido')
     self.objects[ref]={'group':gid,'index':index,'class':name.decode()}
   elif c.tag==b'SSTR':
    if self.shared or u32(d)!=0:raise ValueError('Tabela compartilhada desconhecida')
    q=8
    for _ in range(u32(d,4)):
     start=q;q+=16;_,q=string(d,q);self.shared.append(d[start:q])
    if q!=len(d):raise ValueError('Tabela compartilhada truncada')
   elif c.tag==b'PRNT':
    if self.parent_chunk is not None or d[0]!=0:raise ValueError('Árvore de pais desconhecida')
    n=u32(d,1)
    if len(d)!=5+n*8:raise ValueError('Árvore truncada')
    children=refs(d[5:5+n*4],n);parents=refs(d[5+n*4:],n)
    if len(set(children))!=n:raise ValueError('Pai duplicado')
    self.parents=dict(zip(children,parents));self.parent_chunk=c
  if len(self.groups)!=u32(self.header,16)or len(self.objects)!=u32(self.header,20)or set(self.parents)!=set(self.objects):raise ValueError('Contagem de instâncias inconsistente')
  for ref,parent in self.parents.items():
   if parent!=-1 and parent not in self.objects:raise ValueError('Pai ausente')
  for c in self.chunks:
   if c.tag==b'PROP':
    gid=u32(c.data);name,q=string(c.data,4);name=name.decode();typ=c.data[q];q+=1
    if gid not in self.groups or (gid,name)in self.props:raise ValueError('Propriedade ambígua')
    self.props[gid,name]=(c,typ,q)
  self.children={}
  for ref,o in self.objects.items():
   name=self.value(ref,'Name').decode('utf-8');o['name']=name
   self.children.setdefault((self.parents[ref],name),[]).append(ref)
 def strings(self,gid,name):
  if (gid,name)in self.stringcache:return self.stringcache[gid,name]
  c,typ,q=self.props[gid,name]
  if typ!=1:raise ValueError('Propriedade textual usa formato não suportado: '+name)
  result=[]
  for _ in self.groups[gid]['refs']:v,q=string(c.data,q);result.append(v)
  if q!=len(c.data):raise ValueError('Propriedade textual truncada')
  self.stringcache[gid,name]=result
  return result
 def value(self,ref,name):
  o=self.objects[ref];return self.strings(o['group'],name)[o['index']]
 def locate(self,path):
  ref=-1
  for name in path:
   values=self.children.get((ref,name),[])
   if len(values)!=1:raise ValueError('Caminho ausente/ambíguo: '+'/'.join(path))
   ref=values[0]
  return ref
 def set_sources(self,edits):
  changed={}
  for e in edits:
   ref=self.locate(e['path']);o=self.objects[ref]
   if o['class']!=e['class']:raise ValueError('Classe diferente no alvo')
   before=self.value(ref,'Source')
   if before!=e['before'].encode()and before!=e['after'].encode():raise ValueError('Fonte atual divergiu: '+'/'.join(e['path']))
   gid=o['group'];values=changed.setdefault(gid,self.strings(gid,'Source'));values[o['index']]=e['after'].encode()
  for gid,values in changed.items():
   c,_,q=self.props[gid,'Source'];c.data=c.data[:q]+b''.join(pstring(v)for v in values);c.packet=None
   self.stringcache[gid,'Source']=values
 def encode(self):return self.header+b''.join(c.encoded(self.codec)for c in self.chunks)
