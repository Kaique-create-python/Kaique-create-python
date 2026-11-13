-- Shared, finite whitelist. Preferences grant no gameplay powers.
local P = {}
P.BOTOES = {"m1","bloq","dash","g1","g2","g3","g4","ult","stand","mira","shift","pose"}
local nomes = {}
for _, name in P.BOTOES do nomes[name] = true end
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function P.padrao()
 return {musica=1,efeitos=1,qualidade="alta",tremor=1,camera=12.5,mira=false,layout={}}
end
function P.sanitizar(raw)
 local out = {}
 if type(raw)~="table" then return out end
 for key, limits in {musica={0,1.6},efeitos={0,1.6},tremor={0,1.4},camera={9,20}} do
  if finite(raw[key]) then out[key]=math.clamp(raw[key],limits[1],limits[2]) end
 end
 if type(raw.mira)=="boolean" then out.mira=raw.mira end
 if raw.qualidade=="alta" or raw.qualidade=="baixa" then out.qualidade=raw.qualidade end
 if type(raw.layout)=="table" then
  out.layout={}
  for name in nomes do
   local v=raw.layout[name]
   if type(v)=="table" and finite(v.x) and finite(v.y) and finite(v.s) then
    out.layout[name]={x=math.clamp(v.x,0,1),y=math.clamp(v.y,0,1),s=math.clamp(v.s,.8,1.3)}
   end
  end
 end
 return out
end
function P.mesclar(base, patch)
 local out=P.padrao()
 for k,v in P.sanitizar(base) do out[k]=v end
 for k,v in P.sanitizar(patch) do out[k]=v end
 return out
end
return P
