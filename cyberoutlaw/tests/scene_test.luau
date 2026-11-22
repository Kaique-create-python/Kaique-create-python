local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local services = {}
local root = r.Instance.new("Folder")
local workspace = r.Instance.new("Workspace")
workspace.Parent = root
local lighting = r.Instance.new("Lighting")
lighting.Parent = root
lighting.ClockTime = 18
lighting.Brightness = 2.5
local camera = r.Instance.new("Camera")
camera.CFrame = r.CFrame.new(2, 3, 4)
camera.Focus = r.CFrame.new(21, 5, 11)
camera.FieldOfView = 63
camera.CameraType = r.Enum.CameraType.Custom
camera.Parent = workspace
workspace.CurrentCamera = camera
services.Workspace, services.Lighting = workspace, lighting
local viewport = {AbsoluteSize = r.Vector2.new(1280, 720), SetAttribute = function(self, key, value) self[key] = value end}
local preview = r.Instance.new("Camera")
local world = r.Instance.new("WorldModel")
local fixture = [[
local function createCyberCity(parent, art, origin)
    assert(art.billboard == 554)
    local body = Instance.new("Model")
    body.Name = "TestCity"
    body.Parent = parent
    local part = Instance.new("Part")
    part.Name = "Asfalto do terraço"
    part.Material = Enum.Material.Asphalt
    part.Size = Vector3.new(7, 1, 8)
    part.CFrame = CFrame.new(origin or Vector3.zero)
    part.Parent = body
    local tower = Instance.new("Part")
    tower.Name = "Torre de teste"
    tower.Size = Vector3.new(14, 119, 17)
    tower:SetAttribute("FacadeFamily", "spine")
    tower:SetAttribute("FacadeDepth", 0.4)
    tower:SetAttribute("FacadeSide", true)
    tower.Parent = body
    return body, function(seconds, aspect)
        assert(math.abs(aspect - 16/9) < 0.01)
        return CFrame.new((origin or Vector3.zero) + Vector3.new(seconds, 31, 25))
    end
end
]]
local stage = luau.load(fixture .. fs.readFile("src/scene.luau") .. "\nreturn openCyberOutlawScene", {
    injectGlobals = true,
    environment = {
        game = {GetService = function(_, key) return services[key] end},
        Instance = r.Instance, Vector2 = r.Vector2, Vector3 = r.Vector3, UDim2 = r.UDim2,
        CFrame = r.CFrame, Color3 = r.Color3, Enum = r.Enum,
    },
})()
local step, leave = stage({art={billboard=554, asphalt=555, asphalt_normal=556, asphalt_rough=557, facades=558}}, viewport, world, preview)
assert(viewport.CyberOutlawWorkspaceStage == true and viewport.ImageTransparency == 1)
assert(camera.CameraType == r.Enum.CameraType.Scriptable and camera.FieldOfView == 46)
assert(workspace:FindFirstChild("CyberOutlawMenuStage") ~= nil)
local floor = workspace:FindFirstChild("Asfalto do terraço", true)
local finish = floor:FindFirstChildOfClass("Texture")
assert(finish.Face == r.Enum.NormalId.Top and finish.Texture == "rbxassetid://555")
assert(finish:GetAttribute("CyberOutlawMaterial") == "asphalt" and finish.StudsPerTileU == 9.5)
local screening = workspace:FindFirstChild("Torre de teste", true):GetChildren()
assert(#screening == 2)
for _, panel in screening do
    assert(panel:IsA("SurfaceGui") and #panel:GetChildren() == 3)
    for _, slice in panel:GetChildren() do
        assert(slice.Image == "rbxassetid://558" and slice.ImageRectOffset.X == 514)
        assert(slice.ImageRectOffset.Y >= 514 and slice.ImageRectOffset.Y + slice.ImageRectSize.Y <= 1022)
    end
end
assert(camera:FindFirstChildOfClass("BloomEffect") and camera:FindFirstChildOfClass("ColorCorrectionEffect"))
assert(math.abs(lighting.ClockTime - 1.1) < 0.001)
step(5.25)
assert(camera.CFrame.Position.X == 13305.25)
lighting.Brightness = 2.9
leave()
leave()
assert(camera.CFrame == r.CFrame.new(2, 3, 4) and camera.Focus == r.CFrame.new(21, 5, 11))
assert(camera.FieldOfView == 63 and camera.CameraType == r.Enum.CameraType.Custom)
assert(camera:FindFirstChildOfClass("BloomEffect") == nil and workspace:FindFirstChild("CyberOutlawMenuStage") == nil)
assert(lighting.ClockTime == 18 and math.abs(lighting.Brightness - 2.9) < 0.001)
services.Workspace = {}
local previewStep, previewLeave = stage({art={billboard=554}}, viewport, world, preview)
assert(viewport.CyberOutlawWorkspaceStage == false and viewport.ImageTransparency == 0)
assert(world:FindFirstChild("TestCity"))
previewStep(2)
assert(preview.CFrame.Position.X == 2)
previewLeave()
assert(not world:FindFirstChild("TestCity"))
print("Client scene camera, local effects, lighting restore, fallback and idempotent cleanup passed")
