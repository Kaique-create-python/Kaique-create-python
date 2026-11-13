-- Native serialization preflight: real AJ13 place + actual AmbienteVisual14 module.
-- No engine renderer/physics/CameraModule is implied by this preservation test.
local fs = require("@lune/fs")
local R = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
-- Lune exposes the serialized Instances, not engine events. Streaming behavior is exercised
-- separately by tests_graphics14; this native snapshot uses inert event boundaries only.
for _, event in {"ChildAdded", "DescendantAdded", "AncestryChanged"} do
 R.implementProperty("Instance", event, function()
  return { Connect=function() return { Disconnect=function() end } end }
 end)
end
local file = process.args[1] or "/workspace/jojo-ajuste13/audit/payload/place.rbxl"
local base = if fs.isDir("src") then "src/" else "bizarre/src/"
local game = R.deserializePlace(fs.readFile(file))
local workspace = game:GetService("Workspace")
local light = game:GetService("Lighting")
local map = assert(workspace:FindFirstChild("Morioh"), "real Morioh required")
local before, count, materials = {}, 0, {}
for _, item in map:GetDescendants() do
 local properties = { Parent = item.Parent, Name = item.Name }
 if item:IsA("BasePart") then
  count += 1
  materials[item] = item.Material
  for _, key in {"CFrame","Size","CanCollide","CanTouch","CanQuery","CollisionGroup","Anchored","Color","Transparency","Reflectance"} do properties[key] = item[key] end
 end
 if item:IsA("MeshPart") then properties.TextureID = item.TextureID properties.MeshId = item.MeshId end
 if item:IsA("Texture") or item:IsA("Decal") then properties.Texture = item.Texture end
 if item:IsA("SurfaceAppearance") then
  for _,key in {"ColorMap","MetalnessMap","NormalMap","RoughnessMap"} do properties[key]=item[key] end
 end
 before[item] = properties
end
assert(count>100000,"requires full city, not a test reconstruction")
local ambient = luau.load(fs.readFile(base .. "ReplicatedStorage/BB/Cliente/AmbienteVisual14.luau"), {
 debugName="AmbienteVisual14.luau", environment={
  game=game, workspace=workspace, Enum=R.Enum, Color3=R.Color3, Instance=R.Instance,
 },
})()
ambient.iniciar() ambient.iniciar()
local afterCount,changedMaterials=0,0
for _,item in map:GetDescendants() do
 afterCount+=1
 local properties=assert(before[item],"unexpected new city object")
 for key,value in properties do assert(item[key]==value,"city property changed: "..item.Name.."."..key) end
end
for part,original in materials do
 if part.Material~=original then
  changedMaterials+=1
  assert(part.Material==R.Enum.Material.Asphalt or part.Material==R.Enum.Material.Concrete or part.Material==R.Enum.Material.Metal or part.Material==R.Enum.Material.Glass,"unexpected material role")
 end
end
assert(changedMaterials<count*.02,"broad city material replacement")
local expectedCount=0 for _ in before do expectedCount+=1 end
assert(afterCount==expectedCount,"city objects removed")
assert(math.abs(light.ClockTime-15.8)<.001)
assert(light.GlobalShadows and light.PrioritizeLightingQuality and light.LightingStyle==R.Enum.LightingStyle.Realistic)
local classes={}
for _,effect in light:GetChildren() do classes[effect.ClassName]=(classes[effect.ClassName] or 0)+1 end
assert(classes.Atmosphere==1 and classes.BloomEffect==1 and classes.ColorCorrectionEffect==1,"stacked ambient effects")
assert(not classes.DepthOfFieldEffect,"ambient DOF")
print(string.format("graphics14 native place: %d BaseParts / %d Morioh objects preserved; %d selective material changes; realistic/high; single atmosphere/bloom/grade; no ambient DOF",count,afterCount,changedMaterials))
