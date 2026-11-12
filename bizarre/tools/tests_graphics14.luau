-- Executes production modules and real CFrame/Vector3 math; mocks only engine boundaries.
local F = require("../tests/graphics14_fixture")
local V, C, E = F.V, F.C, F.Enum
local total, failed = 0, 0
local function test(name, fn)
 total += 1
 local ok, err = pcall(fn)
 if not ok then failed += 1 print("FAIL " .. name .. ": " .. tostring(err)) else print("PASS " .. name) end
end
local function near(a,b,eps) assert(math.abs(a-b) < (eps or 1e-4), tostring(a).." != "..tostring(b)) end
local function many(e, dur) for _=1,math.ceil(dur*60) do e:tick(1/60) end end

test("manual aim OFF and ShiftLock remain intentional defaults", function()
 local e=F.world()
 assert(not e.cam.miraAuto)
 e.cam.aoAcerto({a=e.own,v=e.target}) assert(e.cam.travado()==nil)
 e.cam.miraAuto=true
 e.cam.aoAcerto({a=e.target,v=e.own}) assert(e.cam.travado()==nil)
 e.cam.shiftLock(true) many(e,1)
 near(e.hum.CameraOffset.X,1.75,.01)
 e.cam.aoAcerto({a=e.own,v=e.target}) assert(e.cam.travado()==e.target)
end)
test("manual R6 lock 11 studs persists through ragdoll and falling", function()
 local e=F.world() e.cam.travar(e.target)
 near(e.player.CameraMinZoomDistance,11)
 e.own:SetAttribute("BB_Ragdoll",true) e.target:SetAttribute("BB_Ragdoll",true)
 many(e,1)
 assert(e.cam.travado()==e.target and e.cam.modoTrava())
 local p=e.ws.CurrentCamera.CFrame.Position
 e.targetRoot.Position+=V.new(0,15,0) many(e,1)
 assert(e.ws.CurrentCamera.CFrame.Position.Y>p.Y+2)
 many(e,5) assert(e.cam.travado()==e.target)
 near(e.ws.CurrentCamera.CFrame.RightVector.Y,0,.0001)
end)
test("FOV gameplay respects cinema ownership", function()
 local e=F.world() e.cam.assumir("cinema") e.ws.CurrentCamera.FieldOfView=44
 e.cam.correndo(true) e:tick(.1) near(e.ws.CurrentCamera.FieldOfView,44)
end)
test("old FOV timeout cannot erase newer pulse", function()
 local e=F.world() e.cam.fov(10,.1) e:tick(.05) e.cam.fov(20,.5) e:tick(.1)
 assert(e.ws.CurrentCamera.FieldOfView>80, "old pulse erased newer FOV")
end)
test("replacement camera has its own gameplay FOV base",function()
 local e=F.world() e.ws.CurrentCamera=e.newCamera() e.ws.CurrentCamera.FieldOfView=50
 many(e,1) near(e.ws.CurrentCamera.FieldOfView,50)
end)
test("nested camera leases restore after buried owner closes",function()
 local e=F.world() local a=e.cam.assumir("cinema")
 e.cam.fovCinema(a,42) local b=e.cam.assumir("cinema",true) e.cam.fovCinema(b,55)
 e.cam.devolver("cinema",a) near(e.ws.CurrentCamera.FieldOfView,55)
 e.cam.devolver("cinema",b) near(e.ws.CurrentCamera.FieldOfView,70)
 assert(e.cam.dono()=="jogo")
end)
test("older same-name lease cannot close a newer cinema",function()
 local e=F.world() local a=e.cam.assumir("cinema") local b=e.cam.assumir("cinema",true)
 e.cam.devolver("cinema",a) assert(e.cam.pertence(b))
 e.cam.assumir("menu") e.cam.devolver("cinema",b) assert(e.cam.dono()=="menu")
end)
test("previous shake does not alter newer menu frame or replacement",function()
 local e=F.world() e.cam.tremer(.8,.5) e:tick(.02)
 e.cam.assumir("menu") local frame=C.new(50,20,50) e.ws.CurrentCamera.CFrame=frame
 e.steps.BB_CameraAntes(.01) assert(e.ws.CurrentCamera.CFrame==frame)
end)
test("cinema SP replacement camera gets frame FOV and only cinematic DOF",function()
 local e=F.world() local cinema=e:cinematica() cinema.iniciar(e.gui)
 cinema.ult(e.own,{nome="Stand",usuario="Dono",id="STAR_PLATINUM"},{cinema=1.7})
 assert(cinema.tocando()) e:tick(.1)
 local old=e.ws.CurrentCamera local frame=old.CFrame
 local replacement=e.newCamera() replacement.FieldOfView=50 e.ws.CurrentCamera=replacement
 e:tick(.1)
 assert(replacement.CFrame~=e.newCamera().CFrame,"new camera never received scene")
 assert(old.CFrame==frame,"old camera still written")
 assert(replacement:FindFirstChildOfClass("DepthOfFieldEffect"),"cinematic DOF missing")
 many(e,1) assert(not cinema.tocando() and e.cam.dono()=="jogo")
 assert(not replacement:FindFirstChildOfClass("DepthOfFieldEffect")) near(replacement.FieldOfView,50,.01)
end)
test("cinema interruption death respawn and menu restore local resources",function()
 for _, reason in {"death","respawn","menu","explicit"} do
 local e=F.world() local cinema=e:cinematica() cinema.iniciar(e.gui)
 cinema.ult(e.own,{nome="Stand",usuario="Dono",id="THE_WORLD"},{cinema=.9}) e:tick(.15)
 if reason=="death" then e.hum.Health=0 elseif reason=="respawn" then e.player.Character=e.target elseif reason=="menu" then e.cam.assumir("menu") else cinema.cancelar() end
 e:tick(.01) assert(not cinema.tocando(),reason)
 assert(not e.ws.CurrentCamera:FindFirstChildOfClass("DepthOfFieldEffect"),reason)
 near(e.ws.CurrentCamera.FieldOfView,70,.001)
 assert(e.cam.dono()==(if reason=="menu" then "menu" else "jogo"))
 end
end)
test("new cinema supersedes old without old cleanup erasing new grade",function()
 local e=F.world() local cinema=e:cinematica() cinema.iniciar(e.gui)
 cinema.ult(e.own,{nome="Stand",usuario="Dono",id="STAR_PLATINUM"},{cinema=.5}) e:tick(.3)
 cinema.ult(e.own,{nome="Stand",usuario="Dono",id="THE_WORLD"},{cinema=.9}) e:tick(.3)
 assert(cinema.tocando() and e.cam.dono()=="cinema")
 local dof=e.ws.CurrentCamera:FindFirstChildOfClass("DepthOfFieldEffect") assert(dof and dof.Enabled)
 many(e,.7) assert(not cinema.tocando()) near(e.ws.CurrentCamera.FieldOfView,70,.01)
end)
test("six legacy stand entry points remain and no anime text overlays",function()
 for _, id in {"STAR_PLATINUM","THE_WORLD","CRAZY_DIAMOND","KILLER_QUEEN","SILVER_CHARIOT","MAGICIANS_RED"} do
 local e=F.world() local cinema=e:cinematica() cinema.iniciar(e.gui) cinema.despertar(e.own,{nome="Stand",usuario="Dono",id=id})
 e:tick(.15) assert(cinema.tocando())
 for _, item in e.gui:GetDescendants() do assert(not item:IsA("TextLabel"),"forbidden anime title") end
 many(e,1) assert(not cinema.tocando())
 end
end)
test("ambient high profile idempotent and DOF absent outside cinema",function()
 local e=F.world() local env=e.load("AmbienteVisual14") env.iniciar() env.iniciar()
 near(e.lighting.ClockTime,15.8) assert(e.lighting.GlobalShadows)
 assert(e.lighting.LightingStyle==E.LightingStyle.Realistic and e.lighting.PrioritizeLightingQuality)
 local counts={} for _, item in e.lighting:GetChildren() do counts[item.ClassName]=(counts[item.ClassName] or 0)+1 end
 assert(counts.Atmosphere==1 and counts.BloomEffect==1 and counts.ColorCorrectionEffect==1)
 assert(not counts.DepthOfFieldEffect)
end)
test("map materials only recognized roles preserve appearance geometry collisions",function()
 local e=F.world()
 local function part(name) local p=e.instance("Part") p.Name=name p.CFrame=C.new(5,6,7) p.CanCollide=true p.Material=E.Material.SmoothPlastic p.Parent=e.map return p end
 local road=part("Asfalto") local glass=part("Janela") local unknown=part("CityPart184983") local styled=part("Concreto")
 local appearance=e.instance("SurfaceAppearance") appearance.Parent=styled
 local env=e.load("AmbienteVisual14") env.iniciar()
 assert(road.Material==E.Material.Asphalt and glass.Material==E.Material.Glass)
 assert(unknown.Material==E.Material.SmoothPlastic and styled.Material==E.Material.SmoothPlastic)
 for _,p in {road,glass,unknown,styled} do assert(p.CanCollide and p.CFrame==C.new(5,6,7)) end
 assert(appearance.Parent==styled)
end)
test("nested active lease resumes previous FOV until final release",function()
 local e=F.world() local a=e.cam.assumir("cinema") e.cam.fovCinema(a,42)
 local b=e.cam.assumir("cinema",true) e.cam.fovCinema(b,55)
 e.cam.devolver("cinema",b) near(e.ws.CurrentCamera.FieldOfView,42) assert(e.cam.pertence(a))
 e.cam.devolver("cinema",a) near(e.ws.CurrentCamera.FieldOfView,70)
end)
test("SP and TW have distinct short framing and color direction",function()
 local positions,colors={},{}
 for _,id in {"STAR_PLATINUM","THE_WORLD"} do
 local e=F.world() local cinema=e:cinematica() cinema.iniciar(e.gui)
 cinema.ult(e.own,{id=id,nome="Stand",usuario="Dono"},{cinema=1.7}) e:tick(.2)
 positions[id]=e.ws.CurrentCamera.CFrame.Position
 colors[id]=e.ws.CurrentCamera:FindFirstChildOfClass("ColorCorrectionEffect").TintColor
 assert(e.ws.CurrentCamera.FieldOfView<65 and e.ws.CurrentCamera.FieldOfView>50)
 many(e,.71) assert(not cinema.tocando())
 end
 assert((positions.STAR_PLATINUM-positions.THE_WORLD).Magnitude>1)
 assert(colors.STAR_PLATINUM.B>colors.STAR_PLATINUM.R)
 assert(colors.THE_WORLD.R>colors.THE_WORLD.B)
end)
test("ambient reuses AJ13 effects and disables any ambient DOF",function()
 local e=F.world()
 for _,data in {{"ColorCorrectionEffect","Paleta_Morioh"},{"BloomEffect","BloomEffect"},{"Atmosphere","Atmosfera_Parte4"},{"DepthOfFieldEffect","OldDOF"}} do
 local effect=e.instance(data[1]) effect.Name=data[2] effect.Parent=e.lighting
 end
 local env=e.load("AmbienteVisual14") env.iniciar()
 local count={} for _,item in e.lighting:GetChildren() do count[item.ClassName]=(count[item.ClassName] or 0)+1 end
 assert(count.ColorCorrectionEffect==1 and count.BloomEffect==1 and count.Atmosphere==1,"stacked old profile")
 assert(not e.lighting:FindFirstChild("OldDOF").Enabled,"DOF outside cinema")
 assert(e.lighting.ColorShift_Top.R<.2,"sun shift clips white")
end)
test("legacy repeated menu ownership is idempotent",function()
 local e=F.world() e.cam.assumir("menu") e.cam.assumir("menu")
 e.cam.devolver("menu") assert(e.cam.dono()=="jogo","legacy menu stuck")
end)
test("streamed map parts inherit appearance and cleanup stops observers",function()
 local e=F.world() local env=e.load("AmbienteVisual14") env.iniciar() env.iniciar()
 local function road(parent)
 local p=e.instance("Part") p.Name="Asfalto" p.Material=E.Material.SmoothPlastic p.CanCollide=true p.CFrame=C.new(3,4,5) p.Parent=parent return p
 end
 local late=road(e.map) assert(late.Material==E.Material.Asphalt,"streamed material unchanged")
 assert(late.CanCollide and late.CFrame==C.new(3,4,5))
 local texture=e.instance("Texture") texture.Parent=late
 assert(late.Material==E.Material.SmoothPlastic,"late special texture did not restore original material")
 env.parar()
 local stopped=road(e.map) assert(stopped.Material==E.Material.SmoothPlastic)
 env.iniciar() assert(stopped.Material==E.Material.Asphalt)
 e.map.Parent=nil
 local detached=road(e.map) assert(detached.Material==E.Material.SmoothPlastic,"detached map observer leaked")
 e.map.Parent=e.ws assert(detached.Material==E.Material.Asphalt,"returned map not observed")
end)
test("four legacy cinemas preserve inherited FOV through replacement and finish",function()
 for _,id in {"CRAZY_DIAMOND","KILLER_QUEEN"} do
 local e=F.world() e.ws.CurrentCamera=e.newCamera() e.ws.CurrentCamera.FieldOfView=63
 local cinema=e:cinematica() cinema.iniciar(e.gui)
 cinema.ult(e.own,{id=id,nome="Stand",usuario="Dono"},{cinema=.9}) e:tick(.2)
 near(e.ws.CurrentCamera.FieldOfView,63)
 e.ws.CurrentCamera=e.newCamera() e.ws.CurrentCamera.FieldOfView=51 e:tick(.2)
 near(e.ws.CurrentCamera.FieldOfView,51)
 many(e,.7) near(e.ws.CurrentCamera.FieldOfView,51,.01)
 end
end)
print(string.format("graphics14: %d/%d PASS",total-failed,total))
assert(failed==0,tostring(failed).." graphics14 failures")
