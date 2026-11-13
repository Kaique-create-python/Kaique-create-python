local H=require('./harness');local R=require('@lune/roblox')
local Time=H.modulo('ServerScriptService/BB_Servidor/TempoSessao')
local owner,other={},{};local target={laboratorioDono17=owner}
assert(#Time.congelar(Time.nova({jogador=other},60),{target})==0 and not target.sessaoTempo,'foreign time stop froze private target')
assert(#Time.congelar(Time.nova({jogador=owner},60),{target})==1,'owner could not practice time stop')
local L=H.modulo('ServerScriptService/BB_Servidor/Lutadores')
local HB=H.modulo('ServerScriptService/BB_Servidor/Hitbox')
local world=R.Instance.new('Folder')
local function actor(name,pos,who)
 local m=R.Instance.new('Model');m.Name=name;m.Parent=world
 local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=m
 for _,n in {'HumanoidRootPart','Torso'}do local p=R.Instance.new('Part');p.Name=n;p.Position=pos;p.CFrame=R.CFrame.new(pos);p.Parent=m end
 return L.criar(m,who,'STAR_PLATINUM')
end
local a=actor('A',R.Vector3.new(0,3,0),other)
local private=actor('Private',R.Vector3.new(0,3,-5),nil);private.laboratorioDono17=owner
local normal=actor('Normal',R.Vector3.new(0,3,-8),owner)
H.workspace.GetPartBoundsInRadius=function()return{private.raiz,normal.raiz}end
assert(HB.maisPertoNaFrente(a,R.Vector3.new(0,0,-1),15)==normal,'foreign private target consumed automatic targeting')
print('AJ17 private targets excluded before selection and direct time-stop PASS')
