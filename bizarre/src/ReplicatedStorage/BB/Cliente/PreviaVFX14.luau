-- Local inspection of the approved SP/TW catalog. No combat, remote, audio or camera dependency.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Piloto = require(script.Parent:WaitForChild("VFXPiloto"))
local Receitas = require(script.Parent.Parent:WaitForChild("VFXReceitas"))
local Barragem16 = require(script.Parent:WaitForChild("Barragem16"))
local Previa = {}
local token = 0
local atual: any = nil

local function vivo(handle: any): boolean
	local owner = handle.owner
	local hum = owner and owner:FindFirstChildOfClass("Humanoid")
	return handle.active and atual == handle and owner.Parent ~= nil
		and Players.LocalPlayer.Character == owner and hum ~= nil and hum.Health > 0
		and owner:FindFirstChild("HumanoidRootPart") ~= nil
end

function Previa.cancelar()
	local handle = atual
	if not handle then return end
	atual = nil
	handle.active = false
	if handle.connection then handle.connection:Disconnect() end
	for _, scope in handle.scopes do Piloto.cancelar(handle.owner, scope) end
	for _,barrage in handle.barragens or{}do Barragem16.cancelar(handle.owner,barrage)end
end

local function selecionado(owner,id)
 Previa.cancelar()
 if not Receitas.suporta(id)or not owner or not owner.Parent or Players.LocalPlayer.Character~=owner then return false end
 for name,templates in Receitas.catalogos(id)do
  local catalog=RS:FindFirstChild(name);if not catalog then return false end
  for template in templates do if not catalog:FindFirstChild(template)then return false end end
 end
 local root=owner:FindFirstChild("HumanoidRootPart");local hum=owner:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 then return false end
 token+=1
 local prefix="preview15:"..token..":"..id
 local h={owner=owner,active=true,scopes={prefix},barragens={},token=token,stand=id};atual=h
 local base=root.CFrame:PointToWorldSpace(Vector3.new(0,0,-12));local dir=root.CFrame.LookVector
 local function tocar(move,phase,extra)
  if not vivo(h)then return end
  local ctx={preview=true,owner=owner,pos=base,dir=dir,t=workspace:GetServerTimeNow(),actionId=prefix,n=1,variant="antecipacao"}
  for k,v in extra or {}do ctx[k]=v end
  if not table.find(h.scopes,ctx.actionId)then table.insert(h.scopes,ctx.actionId)end
  Piloto.tocar(id,move,phase,ctx)
 end
 local function after(t,fn)task.delay(t,function()if atual==h then if vivo(h)then fn()else Previa.cancelar()end end end)end
 h.cancelar=function()if atual==h then Previa.cancelar()end end
 h.connection=RunService.Heartbeat:Connect(function()if atual==h and not vivo(h)then Previa.cancelar()end end)
 tocar("invocar","inicio")
 after(.6,function()tocar("m1","inicio")end);after(.72,function()tocar("m1","contato")end)
 local G=require(script.Parent.Parent:WaitForChild("Golpes"))
 local clock=1.2
 for _,slot in {1,2,3,4,"ULT"}do
  local move=id.."_"..slot;local g=G.get(move);local start=clock
  after(start,function()tocar(move,"inicio")end)
  if g.tipo=="barragem"and g.animS=="barragem"then
   after(start+(g.inicio or .1),function()
    local catalog=RS:FindFirstChild("BB_Stands");local source=catalog and catalog:FindFirstChild(id)
    local handle=Barragem16.tocar(owner,source,(g.fim or 1)-(g.inicio or 0),function()return vivo(h)end,{preview=true,base=CFrame.lookAt(base,base+dir)})
    if handle then table.insert(h.barragens,handle)end
   end)
  end
  if g.proj then after(start+g.proj.t,function()tocar(move,"inicio",{variant="projetil",actionId=prefix..":proj:"..slot,dur=g.proj.alcance/g.proj.vel,speed=g.proj.vel})end)end
  if id=="MAGICIANS_RED"and slot=="ULT"then after(start,function()tocar("sol","inicio",{above=base+Vector3.new(0,24,0),destination=base+dir*28,formar=1.1,cair=.5})end)end
  if id=="SILVER_CHARIOT"and slot==4 then after(start,function()tocar("buff","inicio",{dur=8})end)end
  after(start+(g.animImpacto or g.final and g.final.t or math.min(.5,g.trava*.6)),function()tocar(move,"contato")end)
  clock+=math.max(g.trava or .6,g.agarrao and g.agarrao.duracao or 0)+.35
 end
 h.duration=math.max(clock+2,12)
 after(h.duration,Previa.cancelar)
 return h
end

function Previa.tocar(owner: Model?, standId: string?): any
 if standId then return selecionado(owner,standId)end
	Previa.cancelar()
	local catalogo = RS:FindFirstChild("BB_VFXCatalogo14")
	if not catalogo then return false end
	for name in Receitas.templates() do
		if not catalogo:FindFirstChild(name) then return false end
	end
	if not owner or not owner.Parent or Players.LocalPlayer.Character ~= owner then return false end
	local hum = owner:FindFirstChildOfClass("Humanoid")
	local root = owner:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not root then return false end
	token += 1
	local prefix = "preview14:" .. tostring(token)
	local handle = { owner = owner, active = true, scopes = { prefix .. ":SP", prefix .. ":TW" }, token = token }
	atual = handle
	local bases = {
		root.CFrame:PointToWorldSpace(Vector3.new(-6, 0, -12)),
		root.CFrame:PointToWorldSpace(Vector3.new(6, 0, -12)),
	}
	local dir = root.CFrame.LookVector
	local function tocar(index: number, move: string, phase: string, dur: number?, variant: string?)
		if not vivo(handle) then
			if atual == handle then Previa.cancelar() end
			return
		end
		local stand = if index == 1 then "STAR_PLATINUM" else "THE_WORLD"
		local ok = pcall(Piloto.tocar, stand, move, phase, {
			preview=true, owner = owner, pos = bases[index], dir = dir, actionId = handle.scopes[index],
			t = workspace:GetServerTimeNow(), dur = dur, variant = variant, n = 1,
		})
		if not ok and atual == handle then Previa.cancelar() end
	end
	local function depois(delay: number, callback: () -> ())
		task.delay(delay, function()
			if atual ~= handle then return end
			if not vivo(handle) then Previa.cancelar(); return end
			callback()
		end)
	end
	handle.cancelar = function()
		if atual == handle then Previa.cancelar() end
	end
	handle.connection = RunService.Heartbeat:Connect(function()
		if atual == handle and not vivo(handle) then Previa.cancelar() end
	end)
	for index = 1, 2 do tocar(index, "invocar", "inicio") end
	if not handle.active then return false end
	depois(0.65, function()
		for index = 1, 2 do tocar(index, "m1", "inicio") end
	end)
	depois(0.8, function()
		for index = 1, 2 do tocar(index, "m1", "contato") end
	end)
	depois(1.5, function()
		tocar(1, "STAR_PLATINUM_3", "inicio", 0.5, "antecipacao")
		tocar(2, "THE_WORLD_4", "inicio", 0.5, "antecipacao")
	end)
	depois(2, function()
		tocar(1, "STAR_PLATINUM_3", "contato")
		tocar(2, "THE_WORLD_4", "contato")
	end)
	depois(2.6, function()
		tocar(1, "STAR_PLATINUM_2", "inicio")
		tocar(2, "THE_WORLD_2", "inicio", 0.7, "projetil")
	end)
	depois(3.65, function()
		for index = 1, 2 do tocar(index, "tempo", "contato") end
	end)
	depois(4.5, function() tocar(2, "rolo", "inicio", 0.6) end)
	depois(5.1, function() tocar(2, "rolo", "final") end)
	depois(6.2, Previa.cancelar)
	return handle
end

return Previa
