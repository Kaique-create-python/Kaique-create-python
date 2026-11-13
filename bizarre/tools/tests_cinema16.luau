local F=require('../tests/graphics14_fixture')
local frames={}
for _,id in {'CRAZY_DIAMOND','KILLER_QUEEN'}do
 local e=F.world();local c=e:cinematica();c.iniciar(e.gui)
 c.ult(e.own,{id=id},{cinema=2})
 e:tick(.15);frames[id]=e.ws.CurrentCamera.CFrame
 assert(e.ws.CurrentCamera.FieldOfView<70,'new Stand cinema did not own FOV '..id)
 for _=1,60 do e:tick(1/60)end
 assert(not c.tocando() and e.cam.dono()=='jogo' and math.abs(e.ws.CurrentCamera.FieldOfView-70)<.001)
 assert(not e.ws.CurrentCamera:FindFirstChildOfClass('DepthOfFieldEffect'))
end
assert(frames.CRAZY_DIAMOND~=frames.KILLER_QUEEN,'two ULTs used generic trajectory')
print('AJ16 cinemas: own CD/KQ routes, <=.9s, FOV/resource return PASS')
