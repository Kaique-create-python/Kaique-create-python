-- Execute the structural validator embedded in the generated installer, offline.
-- Instance.Source is data only; no Script/LocalScript or downloaded model code runs.
local fs=require('@lune/fs')
local serde=require('@lune/serde')
local process=require('@lune/process')
local R=require('@lune/roblox')
local H=require('./harness')
local fixture=serde.decode('json',fs.readFile(assert(process.args[1])))
local root=R.Instance.new('DataModel')
for _,row in fixture.entries do
 local at=root
 for i,name in row.path do
  local child=at:FindFirstChild(name)
  if not child then
   child=R.Instance.new(if i==#row.path then row.cls else 'Folder')
   child.Name=name;child.Parent=at
  end
  at=child
 end
 at.Source=row.source
end
local rs=assert(root:FindFirstChild('ReplicatedStorage'))
for _,n in {14,15}do R.deserializeModel(fs.readFile('bizarre/assets/vfx'..n..'/catalogo.rbxm'))[1].Parent=rs end
local BB=H.arvore.ReplicatedStorage.BB
for _,row in fixture.entries do
 if row.path[1]=='ReplicatedStorage'and row.path[2]=='BB'and #row.path==3 and BB[row.path[3]] then BB[row.path[3]].fonte=row.source end
end
local V=H.modulo('ReplicatedStorage/BB/Validacao14')
local cfg=fixture.cfg
local config=H.modulo('ReplicatedStorage/BB/Config')
local recipes=H.modulo('ReplicatedStorage/BB/VFXReceitas')
local profile=H.modulo('ReplicatedStorage/BB/PerfilCombate14')
local reports={}
local function run(name,patch,revision)
 local c=table.clone(cfg)
 for k,v in patch do c[k]=v end
 local conf=table.clone(config)
 if revision then conf.REVISAO=revision end
 reports[name]=V.executar(root,c,conf,recipes,profile)
end
run('actual',{})
run('stage18',{stage=18,package='BIZARRE-AJUSTE-18'},'AJUSTE-18')
run('wrongUniverse',{universe=1444199554})
run('wrongPlace',{place=4508269622})
run('wrongPackage',{package='BIZARRE-AJUSTE-18'})
run('future',{stage=20,package='BIZARRE-AJUSTE-20'},'AJUSTE-20')
print(serde.encode('json',reports))
