-- Run with Studio MCP execute_luau in Edit; output consumed by tools/build_place.py.
local props={
    Instance={"Archivable"},
    Model={"PrimaryPart"},
    BasePart={"Size","CFrame","Color","Material","Anchored","CanCollide","CanTouch","CanQuery","Transparency","Reflectance","CastShadow","TopSurface","BottomSurface"},
    Part={"Shape"},
    SpawnLocation={"Enabled","Neutral","Duration","AllowTeamChangeOnTouch"},
    Light={"Brightness","Color","Enabled","Shadows"},
    PointLight={"Range"},
    SpotLight={"Range","Angle","Face"},
    SurfaceGui={"Face","CanvasSize","AlwaysOnTop","LightInfluence","SizingMode","PixelsPerStud"},
    GuiObject={"Size","Position","AnchorPoint","BackgroundColor3","BackgroundTransparency","BorderSizePixel","Visible","ZIndex","Rotation"},
    TextLabel={"Text","TextColor3","TextSize","Font","TextScaled","TextWrapped","TextXAlignment","TextYAlignment","TextTransparency","TextStrokeTransparency"},
    UIStroke={"Color","Thickness","Transparency"},
    UICorner={"CornerRadius"},
    ProximityPrompt={"ActionText","ObjectText","KeyboardKeyCode","GamepadKeyCode","HoldDuration","MaxActivationDistance","RequiresLineOfSight","Enabled"},
    Humanoid={"WalkSpeed","JumpPower","HipHeight","Health","MaxHealth","RigType","DisplayDistanceType","BreakJointsOnDeath"},
    JointInstance={"C0","C1","Part0","Part1"},
    Decal={"Texture","Face","Transparency","Color3"},
    DataModelMesh={"Scale","Offset","VertexColor"},
    SpecialMesh={"MeshId","TextureId","MeshType"},
    BodyColors={"HeadColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3","TorsoColor3"},
    BaseScript={"Source","Disabled"},
    ModuleScript={"Source"},
    ValueBase={"Value"},
    Animation={"AnimationId"},
    Lighting={"ClockTime","Brightness","Ambient","OutdoorAmbient","FogColor","FogStart","FogEnd","GlobalShadows","ExposureCompensation"},
    ColorCorrectionEffect={"Enabled","Brightness","Contrast","Saturation","TintColor"},
    StarterPlayer={"CameraMode","CameraMinZoomDistance","CameraMaxZoomDistance","EnableMouseLockOption","CharacterWalkSpeed"},
    StarterGui={"ScreenOrientation"},
}
local roots={workspace.Sector7World,game.ReplicatedStorage.Sector7,game.ServerScriptService.Sector7,game.StarterPlayer,game.StarterGui,game.Lighting}
local nodes={}
local ids={}
local function collect(obj,parent)
    if string.find(obj.Name,"CoreTests") or obj:IsA("TouchTransmitter") then return end
    local id="RBX"..(#nodes+1)
    ids[obj]=id
    local attrs={}
    for key,value in obj:GetAttributes() do
        if typeof(value)=="boolean" or typeof(value)=="number" or typeof(value)=="string" then attrs[key]=value end
    end
    local entry={id=id,parent=parent,class=obj.ClassName,name=obj.Name,properties={},attributes=attrs}
    table.insert(nodes,entry)
    for _,c in obj:GetChildren() do collect(c,id) end
end
for _,root in roots do if root then collect(root,nil) end end
local function encode(v)
    local t=typeof(v)
    if t=="Vector3" then return {t=t,v={v.X,v.Y,v.Z}}
    elseif t=="Vector2" then return {t=t,v={v.X,v.Y}}
    elseif t=="Color3" then return {t=t,v={v.R,v.G,v.B}}
    elseif t=="CFrame" then return {t=t,v={v:GetComponents()}}
    elseif t=="UDim2" then return {t=t,v={v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset}}
    elseif t=="UDim" then return {t=t,v={v.Scale,v.Offset}}
    elseif t=="EnumItem" then return {t=t,v=v.Value}
    elseif t=="Instance" then return {t=t,v=ids[v] or "null"}
    elseif t=="string" or t=="number" or t=="boolean" then return {t=t,v=v} end
end
for obj,id in pairs(ids) do
    local entry=nodes[tonumber(string.sub(id,4))]
    for class,names in pairs(props) do
        if obj:IsA(class) then
            for _,name in names do
                local ok,v=pcall(function() return obj[name] end)
                if ok then entry.properties[name]=encode(v) end
            end
        end
    end
end
-- MCP responses are bounded. Retrieve each StringValue as {chunk=value}, concatenate,
-- write build/studio-snapshot.json, then destroy this temporary buffer folder.
local json=game:GetService("HttpService"):JSONEncode(nodes)
local previous=game.ServerStorage:FindFirstChild("Sector7ExportBuffer")
if previous then previous:Destroy() end
local buffer=Instance.new("Folder")
buffer.Name="Sector7ExportBuffer";buffer.Parent=game.ServerStorage
local start,count=1,0
while start<=#json do
    local finish=math.min(start+24999,#json)
    if finish<#json then finish=utf8.offset(json,0,finish+1)-1 end
    local chunk=Instance.new("StringValue")
    count+=1;chunk.Name=tostring(count)
    chunk.Value=string.sub(json,start,finish);chunk.Parent=buffer
    start=finish+1
end
return {bytes=#json,nodes=#nodes,chunks=count}
