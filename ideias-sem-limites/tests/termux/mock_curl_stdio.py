#!/usr/bin/env python3
"""Test-only curl boundary: real mock HTTP handler over in-memory byte streams.

No sockets, no external HTTP, no real credentials. File downloads still use curl.
This does not claim to test libcurl's networking or native Roblox media loading.
"""
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit
import uuid

def run(args):
 headers={};forms=[];method=None;data=b'';out=None;write=None;url=None;i=0
 while i<len(args):
  arg=args[i];i+=1
  if arg in ('-sS','-s','-S'):continue
  if arg in ('-o','-w','-X','-H','--form','--data-binary'):
   value=args[i];i+=1
   if arg=='-o':out=Path(value)
   elif arg=='-w':write=value
   elif arg=='-X':method=value
   elif arg=='--form':forms.append(value)
   elif arg=='--data-binary':data=Path(value[1:]).read_bytes()if value.startswith('@')else value.encode()
   else:
    rows=Path(value[1:]).read_text().splitlines()if value.startswith('@')else[value]
    for row in rows:
     name,content=row.split(':',1);headers[name.lower()]=content.strip()
  elif arg.startswith('http://'):url=arg
  else:raise ValueError('Unsupported test curl argument: '+arg)
 parsed=urlsplit(url or '')
 if parsed.scheme!='http'or parsed.hostname!='localhost'or parsed.port is not None:raise ValueError('Test transport only accepts http://localhost')
 if forms:
  boundary='ideias-test-'+uuid.uuid4().hex;parts=[]
  for form in forms:
   name,value=form.split('=',1)
   if value.startswith('@'):
    file,ctype=value[1:].split(';type=',1)
    part=f'Content-Disposition: form-data; name="{name}"; filename="{Path(file).name}"\r\nContent-Type: {ctype}\r\n\r\n'.encode()+Path(file).read_bytes()
   else:part=f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()+value.encode()
   parts.append(b'--'+boundary.encode()+b'\r\n'+part+b'\r\n')
  data=b''.join(parts)+b'--'+boundary.encode()+b'--\r\n';headers['content-type']='multipart/form-data; boundary='+boundary
 method=method or('POST'if data else'GET');headers['content-length']=str(len(data));headers['host']='localhost'
 target=parsed.path+('?'+parsed.query if parsed.query else'')
 wire=(method+' '+target+' HTTP/1.0\r\n'+''.join(k+': '+v+'\r\n'for k,v in headers.items())+'\r\n').encode()+data
 spec=importlib.util.spec_from_file_location('ideias_test_api',Path(__file__).with_name('mock_opencloud.py'))
 mock=importlib.util.module_from_spec(spec);spec.loader.exec_module(mock)
 mock.KEY=os.environ['IDEIAS_MOCK_KEY']
 state=Path('mock_state.json');log=Path('mock_log.json')
 if state.exists():mock.STATE=json.loads(state.read_text())
 if log.exists():mock.LOG=json.loads(log.read_text())
 class Stream:
  def __init__(self):self.reply=io.BytesIO()
  def makefile(self,*_):return io.BytesIO(wire)
  def sendall(self,raw):self.reply.write(raw)
 stream=Stream();mock.H(stream,('memory',0),object())
 state.write_text(json.dumps(mock.STATE));answer=stream.reply.getvalue()
 header,body=answer.split(b'\r\n\r\n',1);code=header.split(b' ',2)[1].decode()
 if out:out.write_bytes(body)
 else:sys.stdout.buffer.write(body);sys.stdout.buffer.flush()
 if write:
  if write!='%{http_code}':raise ValueError('Unsupported test curl format')
  print(code,end='')

if __name__=='__main__':run(sys.argv[1:])
