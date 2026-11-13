local F=require('../tests/graphics14_fixture')
local e=F.world();e.player.UserId=5
local function events(m)m.GetAttributeChangedSignal=function(self,name)return self:GetPropertyChangedSignal(name)end;return m end
events(e.own);events(e.target)
local Registry=e.load('Registro')
Registry.iniciar()
local foreign=events(e.instance('Model'));foreign:SetAttribute('BB_Lutador',true);foreign:SetAttribute('BB_LaboratorioDono',7);foreign.Parent=e.ws
local mine=events(e.instance('Model'));mine:SetAttribute('BB_Lutador',true);mine:SetAttribute('BB_LaboratorioDono',5);mine.Parent=e.ws
assert(not Registry.lutadores()[foreign] and Registry.lutadores()[mine],'foreign training target leaked into camera/HUD registry')
print('AJ17 private client registry excludes foreign targets without changing Camera PASS')
