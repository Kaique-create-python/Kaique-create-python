"""Single-write publication protocol. Roblox credentials remain in Cloud only."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import uuid
import zipfile
import xml.etree.ElementTree as ET
from .codec import Failure,Binary
from .paths import guard,private_dir,write_once,sync_dir,sync_file,remove

TARGET={'universe':10774214555,'place':108061345551908}
def sha(raw):return hashlib.sha256(raw).hexdigest()
def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def read(path,default=None):
    path=guard(path)
    if path.is_symlink():raise Failure('Metadado e um link inesperado; preserve e revise: '+str(path))
    try:return json.loads(path.read_text())
    except FileNotFoundError:return default
def save(path,value):
    path=guard(path)
    if path.is_symlink():raise Failure('Metadado e um link inesperado: '+str(path))
    private_dir(path.parent)
    temp=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
    try:
        with temp.open('x',encoding='utf8')as stream:
            os.chmod(temp,0o600);json.dump(value,stream,ensure_ascii=False,indent=2)
            stream.flush();os.fsync(stream.fileno())
        temp.replace(path)
        sync_dir(path.parent)
    finally:temp.unlink(missing_ok=True)

class Runtime:
    def __init__(self,root,stage,digest,patch,scripts):
        if stage not in (14,15,16):raise Failure('Revisao invalida.')
        self.root=private_dir(root);self.stage=stage;self.package='BIZARRE-AJUSTE-'+str(stage)
        self.state=private_dir(self.root/('state-ajuste'+str(stage)))
        self.digest=digest;self.patch=patch;self.scripts=scripts
        self.active=self.root/'active-write.json'
    def pending(self):
        entry=read(self.active)
        if entry is not None and (not isinstance(entry,dict) or entry.get('package')!=self.package):
            previous=re.fullmatch(r'BIZARRE-AJUSTE-(14|15|16)',str(entry.get('package','')))if isinstance(entry,dict)else None
            hint='\nExecute: python ~/BIZARRE_AJUSTE'+previous[1]+'.py resume'if previous else''
            raise Failure('Existe envio pendente de outro instalador. Preserve active-write.json e use resume no instalador que iniciou o envio.'+hint)
        return entry
    def _ready(self,raw,base):
        suffix='.rbxl'if raw.startswith(b'<roblox!')else'.rbxlx'
        ready=self.state/('Bizarre_AJUSTE'+str(self.stage)+'_v'+str(base)+'_'+sha(raw)[:12]+suffix)
        if ready.is_symlink()or ready.exists()and ready.read_bytes()!=raw:raise Failure('Arquivo preparado conflitante; preserve e revise.')
        return write_once(ready,raw)
    def test(self,cloud):
        if self.pending():raise Failure('Existe envio pendente; use resume, sem repetir o envio.')
        remove(self.state/'test.json')
        cloud.validate_destination();base,rows=cloud.history()
        print('Versao atual:',base,'| AJUSTE'+str(self.stage)+': preserva mapa, artes e sons.',flush=True)
        backup=self.state/('Backup_v'+str(base)+'.rbxl')
        raw=cloud.download(base,backup)
        try:prepared,changed=self.patch(raw)
        except(Failure,ValueError):
            self.export_review(raw,base)
            raise
        if self.patch(prepared)!=(prepared,False):raise Failure('O patch preparado nao e idempotente.')
        ready=self._ready(prepared,base)
        latestrow=next((r for r in rows if int(r['version'])==base),{})
        needs_publish=changed or latestrow.get('isPublished')is not True
        if changed:
            print('Criando Saved para testar no motor; a versao publicada continua a mesma.',flush=True)
            saved=self._write(cloud,base,ready,'Saved')
            base=saved['version']
        reports=[]
        for source in self.scripts(base,False):
            report=cloud.task(base,source)
            safe=json.dumps(report,ensure_ascii=False)
            secret=getattr(cloud,'key','')
            if secret:safe=safe.replace(secret,'[OCULTA]')
            report=json.loads(safe)
            diagnostic=self.state/'ultimo-teste.json'
            save(diagnostic,dict(version=base,report=report,at=stamp()))
            if report.get('package')!=self.package or report.get('passed')is not True:
                errors=report.get('erros') or report.get('errors') or ['Relatorio retornou pacote incorreto ou passed diferente de true.']
                if not isinstance(errors,list):errors=[errors]
                detail='\n'.join(str(error) for error in errors)[:16000]
                raise Failure('Teste na nuvem reprovado:\n'+detail+'\nRelatorio seguro: '+str(diagnostic)+'\nPublicacao bloqueada.')
            reports.append(report)
        if not reports:raise Failure('Nenhuma verificacao foi executada.')
        current,_=cloud.history()
        if current!=base:raise Failure('O Place mudou durante o teste. Preserve os arquivos e rode test novamente.')
        proof=dict(package=self.package,config=TARGET,base=base,backup=str(backup),backup_sha=sha(raw),ready=str(ready),ready_sha=sha(prepared),source_digest=self.digest,reports=reports,changed=needs_publish,at=stamp())
        save(self.state/'test.json',proof)
        print('TESTE APROVADO. Backup completo preservado. '+('Agora execute publish.'if needs_publish else'Esta entrega ja esta publicada.'),flush=True)
        return proof
    def _proof(self):
        proof=read(self.state/'test.json',{})
        if not isinstance(proof,dict) or proof.get('package')!=self.package or proof.get('config')!=TARGET or proof.get('source_digest')!=self.digest or not isinstance(proof.get('reports'),list) or not proof['reports'] or not all(isinstance(r,dict) and r.get('passed')is True and r.get('package')==self.package for r in proof['reports']):
            raise Failure('Execute test com este instalador antes de publicar.')
        return proof
    def publish(self,cloud):
        if self.pending():raise Failure('Envio pendente. Use resume; nao repita publish.')
        proof=self._proof()
        if not proof.get('changed'):
            print('Esta entrega ja esta publicada. Nenhum envio necessario.');return
        ready=guard(proof['ready'],self.state);backup=guard(proof['backup'],self.state)
        if ready.is_symlink()or backup.is_symlink():raise Failure('Backup/preparado inesperado; publicacao bloqueada.')
        raw=ready.read_bytes();original=backup.read_bytes()
        if sha(raw)!=proof['ready_sha']or sha(original)!=proof['backup_sha']or self.patch(original)[0]!=raw or self.patch(raw)!=(raw,False):
            raise Failure('Backup ou arquivo preparado mudou. Rode test novamente.')
        cloud.validate_destination();latest,_=cloud.history()
        if latest!=proof['base']:raise Failure('O Place mudou depois do teste. Rode test novamente; nada foi enviado.')
        print('Nao salve pelo Studio/outra API durante este envio.',flush=True)
        if input('Para publicar, digite PUBLICAR AJUSTE'+str(self.stage)+': ').strip()!='PUBLICAR AJUSTE'+str(self.stage):raise Failure('Publicacao cancelada.')
        return self._write(cloud,latest,ready,'Published')
    def _write(self,cloud,base,ready,mode):
        if self.pending():raise Failure('Envio pendente. Use resume; nenhum POST foi repetido.')
        cloud.team_empty()
        if cloud.history()[0]!=base:raise Failure('O Place mudou antes do envio. Rode test novamente.')
        ready=guard(ready,self.state);raw=ready.read_bytes()
        if self.patch(raw)!=(raw,False):raise Failure('Arquivo preparado nao corresponde ao pacote.')
        sync_file(ready)
        entry=dict(package=self.package,**TARGET,base=base,mode=mode,status='UPLOADING',at=stamp(),source_digest=self.digest,ready=str(ready),ready_sha=sha(raw),ready_bytes=len(raw),proof_sha=sha((self.state/'test.json').read_bytes()) if mode=='Published' else None,intent=uuid.uuid4().hex)
        write_once(self.active,json.dumps(entry,ensure_ascii=False,indent=2).encode())
        try:
            response=cloud.request(f"/universes/v1/{TARGET['universe']}/places/{TARGET['place']}/versions?versionType={mode}",raw=raw,mime='application/octet-stream'if raw.startswith(b'<roblox!')else'application/xml',method='POST')
        except BaseException:
            self._update_active(entry,status='UNCERTAIN')
            print('Envio sem confirmacao. Preserve active-write.json e execute resume; nao repita envio.',flush=True)
            raise
        version=response.get('versionNumber')if isinstance(response,dict)else None
        minimum=base if mode=='Published' else base+1
        if isinstance(version,bool)or not isinstance(version,(str,int))or not str(version).isdigit()or int(version)<minimum:
            self._update_active(entry,status='UNCERTAIN')
            raise Failure('Resposta inesperada. Recibo preservado; use resume, sem repetir envio.')
        self._update_active(entry,status='UPLOADED',version=int(version))
        return self.resume(cloud)
    def _update_active(self,entry,**changes):
        if read(self.active)!=entry:raise Failure('Recibo ativo mudou; ele foi preservado. Nao repita o envio.')
        entry.update(changes);save(self.active,entry)
    def _identity(self,entry):
        if entry.get('package')!=self.package or entry.get('source_digest')!=self.digest or entry.get('mode')not in ('Saved','Published')or any(entry.get(k)!=v for k,v in TARGET.items()):
            raise Failure('Recibo pertence a outro destino/pacote. Preserve e revise.')
        if (not isinstance(entry.get('intent'),str) or not re.fullmatch(r'[0-9a-f]{32}',entry['intent'])
            or type(entry.get('base')) is not int or entry['base']<=0
            or entry.get('status') not in ('UPLOADING','UNCERTAIN','UPLOADED')
            or type(entry.get('ready_bytes')) is not int or entry['ready_bytes']<=0
            or not isinstance(entry.get('ready_sha'),str) or not re.fullmatch(r'[0-9a-f]{64}',entry['ready_sha'])
            or not isinstance(entry.get('ready'),str)
            or ('version'in entry and (type(entry['version']) is not int or entry['version']<entry['base']+(entry['mode']!='Published')))):
            raise Failure('Recibo incompleto/invalido. Preserve e revise; nenhum envio sera repetido.')
        ready=guard(entry['ready'],self.state)
        if ready.is_symlink()or len(ready.read_bytes())!=entry.get('ready_bytes')or sha(ready.read_bytes())!=entry['ready_sha']:raise Failure('Arquivo do envio pendente mudou. Preserve o recibo.')
    def resume(self,cloud):
        entry=self.pending()
        if not entry:print('Nao existe envio pendente desta entrega.');return
        original_entry=dict(entry)
        self._identity(entry);cloud.validate_destination();latest,rows=cloud.history()
        version=entry.get('version');published=entry['mode']=='Published'
        # Publishing identical bytes may retain the Saved version number. Only
        # consider that base when it is still latest; flag + full hash remain mandatory.
        same_base=published and latest==entry['base']
        candidates=[r for r in rows if (int(r['version'])==version if version is not None else (int(r['version'])>entry['base'] or same_base and int(r['version'])==entry['base']))and r.get('isPublished')is published]
        if len(candidates)>10:raise Failure('Historico tem muitas alteracoes apos o envio. Preserve active-write.json; nao repita POST.')
        matches=[]
        for row in candidates:
            n=int(row['version']);raw=cloud.download(n,self.state/('Verificacao_v'+str(n)+'.rbxl'))
            if sha(raw)==entry['ready_sha']:matches.append((n,raw))
        if len(matches)!=1 or matches[0][0]!=latest:
            summary=dict(base=entry['base'],resposta_version=version,ultima_versao=latest,
                ultima_publicada=max((int(r['version'])for r in rows if r.get('isPublished')is True),default=None),
                recentes=[dict(version=int(r['version']),isPublished=r.get('isPublished'))for r in sorted(rows,key=lambda r:int(r['version']),reverse=True)[:5]],
                candidatos=[int(r['version'])for r in candidates],bytes_confirmados=[n for n,_ in matches])
            raise Failure('Publicacao ainda nao confirmada; recibo preservado. Nenhum POST foi repetido.\nConferencia somente GET: '+json.dumps(summary,ensure_ascii=False))
        version,raw=matches[0]
        if self.patch(raw)!=(raw,False):raise Failure('Conteudo enviado divergiu. Recibo preservado; nao repita o envio.')
        if cloud.history()[0]!=version:raise Failure('O Place mudou durante a verificacao. Preserve o recibo.')
        if read(self.active)!=original_entry:raise Failure('Recibo ativo mudou; ele foi preservado.')
        entry.update(version=version,status='VERIFIED',finished=stamp())
        save(self.state/('receipt-'+entry['intent']+'.json'),entry)
        save(self.state/('last-'+entry['mode'].lower()+'.json'),entry)
        if read(self.active)!=original_entry:raise Failure('Recibo ativo mudou; ele foi preservado.')
        remove(self.active)
        if published:print('PUBLICADO E VERIFICADO: v'+str(version)+'. Entre em um servidor novo.',flush=True)
        else:print('Saved confirmado:',version,'| jogo publicado preservado. Continue com test.',flush=True)
        return entry
    def status(self):
        active=read(self.active,{})
        return {'package':self.package,'tested':bool(read(self.state/'test.json')),
                'pending':{k:active.get(k)for k in ('package','mode','base','version','status','at')}if active else None}

    def export_review(self,raw,version):
        """Export game bytes/sources only; never read Termux configuration/receipts."""
        sources={};error=None
        try:
            if raw.startswith(b'<roblox!'):
                doc=Binary(raw)
                for ref,obj in doc.objects.items():
                    if obj['class']not in ('Script','LocalScript','ModuleScript'):continue
                    path=[];seen=set();current=ref
                    while current!=-1:
                        if current in seen:raise Failure('Ciclo na arvore do backup.')
                        seen.add(current);path.insert(0,doc.objects[current]['name']);current=doc.parents[current]
                    sources['/'.join(path)]=doc.value(ref,'Source').decode()
            else:
                def walk(parent,path):
                    for obj in parent.findall('Item'):
                        current=path+[obj.findtext("Properties/string[@name='Name']")or obj.get('class','Item')]
                        source=obj.find("Properties/ProtectedString[@name='Source']")
                        if source is not None:sources['/'.join(current)]=source.text or ''
                        walk(obj,current)
                walk(ET.fromstring(raw),[])
        except(Failure,ValueError,KeyError,ET.ParseError)as exc:error=str(exc)
        target=self.state/('Bizarre_Revisar_v'+str(version)+'_'+sha(raw)[:10]+'.zip')
        if target.exists():target=target.with_name(target.stem+'_'+uuid.uuid4().hex[:8]+'.zip')
        guard(target,self.state)
        if target.is_symlink():raise Failure('Arquivo de revisao inesperado; preserve e revise.')
        with zipfile.ZipFile(target,'x',zipfile.ZIP_DEFLATED)as z:
            z.writestr('Backup_Completo'+('.rbxl'if raw.startswith(b'<roblox!')else'.rbxlx'),raw)
            z.writestr('sources.json',json.dumps(sources,ensure_ascii=False,indent=2))
            z.writestr('LEIA.txt','Exportacao do jogo BIZARRE JoJo, versao '+str(version)+'. Contem o Place completo e fontes; nao contem configuracao/chave/recibos do Termux. Nada foi publicado.'+('\nExtracao parcial de fontes: '+error if error else''))
        os.chmod(target,0o600)
        print('ZIP para revisar a fonte atual:',target,flush=True)
        return target
