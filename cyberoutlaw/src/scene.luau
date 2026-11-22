-- PBR decal properties are available on Texture through its Decal base class.
local function addCyberOutlawMaterials(city, art, origin)
    local function uri(id)
        return if type(id) == "number" and id > 0 then "rbxassetid://" .. tostring(id) else nil
    end

    local function apply(part, material, face, tileU, tileV, offsetU, offsetV)
        local diffuse = uri(art[material])
        if not diffuse then return end
        local texture = Instance.new("Texture")
        texture.Name = "Acabamento " .. material
        texture.Face = face
        texture.Texture = diffuse
        texture.StudsPerTileU, texture.StudsPerTileV = tileU, tileV
        texture.OffsetStudsU, texture.OffsetStudsV = offsetU, offsetV
        texture.Color3 = if material == "concrete" then Color3.fromRGB(158, 153, 173) else Color3.fromRGB(139, 154, 183)
        texture.Transparency = if material == "concrete" then 0.14 else 0.16
        texture:SetAttribute("CyberOutlawMaterial", material)
        if Content then
            local normal = uri(art[material .. "_normal"])
            local rough = uri(art[material .. "_rough"])
            if normal then
                pcall(function() texture.NormalMapContent = Content.fromUri(normal) end)
            end
            if rough then
                pcall(function() texture.RoughnessMapContent = Content.fromUri(rough) end)
            end
        end
        texture.Parent = part
    end

    for _, part in city:GetDescendants() do
        if not part:IsA("BasePart") then continue end
        local p, s = part.CFrame.Position - origin, part.Size
        if part.Name == "Asfalto do terraço" then
            local tile = 9.5
            apply(part, "asphalt", Enum.NormalId.Top, tile, tile,
                -(p.X - s.X / 2) % tile, -(p.Z - s.Z / 2) % tile)
        elseif part.Material == Enum.Material.Concrete and s.Y >= 3.2 and p.Z > -145 and math.max(s.X, s.Z) >= 3 then
            local face = if s.Z > s.X * 2.25 and p.Z > -22 then Enum.NormalId.Right else Enum.NormalId.Back
            local across = if face == Enum.NormalId.Right then p.Z - s.Z / 2 else p.X - s.X / 2
            apply(part, "concrete", face, 10.7, 9.3, -across % 10.7, -(p.Y - s.Y / 2) % 9.3)
        end
    end
end

local function addCyberOutlawFacades(city, art)
    local atlas = art.facades
    if type(atlas) ~= "number" or atlas <= 0 then return end
    local image = "rbxassetid://" .. tostring(atlas)
    local profiles = {
        glass = {x = 2, y = 2, span = 47, tint = Color3.fromRGB(224, 240, 255)},
        residential = {x = 514, y = 2, span = 42, tint = Color3.fromRGB(224, 231, 237)},
        industrial = {x = 2, y = 514, span = 40, tint = Color3.fromRGB(211, 226, 236)},
        spine = {x = 514, y = 514, span = 44, tint = Color3.fromRGB(213, 232, 255)},
    }

    local function clad(part, face, profile, depth)
        local extent = part.Size.Y
        local width = if face == Enum.NormalId.Left then part.Size.Z else part.Size.X
        local strips = math.clamp(math.ceil(extent / profile.span), 1, 5)
        local gui = Instance.new("SurfaceGui")
        gui.Name = "Pano de fachada"
        gui:SetAttribute("CyberOutlawFacade", true)
        gui.Face = face
        gui.AlwaysOnTop = false
        gui.LightInfluence = 0.23
        gui.Brightness = 1.19 - depth * 0.15
        gui.MaxDistance = 520
        gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        local resolution = if depth < 0.28 then 304 elseif depth < 0.53 then 200 else 132
        local height = math.clamp(math.ceil(resolution * extent / width / 32) * 32, 128, resolution * 3)
        gui.CanvasSize = Vector2.new(resolution, height)
        for band = 1, strips do
            local height = math.clamp(math.floor(508 * extent / strips / profile.span + 0.5), 104, 508)
            local vertical = math.floor((508 - height) * ((band - 1) % 3) / 2)
            local glazing = Instance.new("ImageLabel")
            glazing.Name = "Andares " .. band
            glazing.BackgroundTransparency = 1
            glazing.BorderSizePixel = 0
            glazing.Position = UDim2.fromScale(0, (band - 1) / strips)
            glazing.Size = UDim2.fromScale(1, 1 / strips)
            glazing.Image = image
            glazing.ImageRectOffset = Vector2.new(profile.x, profile.y + vertical)
            glazing.ImageRectSize = Vector2.new(508, height)
            glazing.ImageColor3 = profile.tint:Lerp(Color3.fromRGB(172, 196, 225), depth * 0.46)
            glazing.ImageTransparency = 0.03
            glazing.Parent = gui
        end
        gui.Parent = part
    end

    for _, part in city:GetDescendants() do
        if not part:IsA("BasePart") then continue end
        local family = part:GetAttribute("FacadeFamily")
        local profile = profiles[family]
        if profile then
            local depth = math.clamp(part:GetAttribute("FacadeDepth") or 0, 0, 1)
            if part:GetAttribute("FacadeSideOnly") ~= true then clad(part, Enum.NormalId.Back, profile, depth) end
            if part:GetAttribute("FacadeSideOnly") or (depth < 0.56 and part:GetAttribute("FacadeSide")) then
                clad(part, Enum.NormalId.Left, profile, depth)
            end
        end
    end
end

-- A client-owned stage lets Roblox light and shadow the city with the world renderer.
local function openCyberOutlawScene(assets, viewport, viewportWorld, viewportCamera)
    local workspace = game:GetService("Workspace")
    local lighting = game:GetService("Lighting")
    local art = assets.art or {}
    local stagePosition = Vector3.new(13300, 4100, 7200)
    local fieldOfView = 46
    local light = Color3.fromRGB
    local scene, cameraPath, animate
    local current, cameraBefore, appliedPose, appliedFocus
    local bloom, grade
    local lightingBefore = {}
    local closed = false

    local function write(instance, key, value)
        pcall(function()
            local old = instance[key]
            if old ~= value then
                instance[key] = value
                table.insert(lightingBefore, {instance, key, old, instance[key]})
            end
        end)
    end

    local function aspectRatio()
        local size = viewport.AbsoluteSize
        return if size.X > 0 and size.Y > 0 then size.X / size.Y else 16 / 9
    end

    local function releaseCamera()
        if not current then
            return
        end
        local camera = current
        local before = cameraBefore
        if bloom then bloom:Destroy() end
        if grade then grade:Destroy() end
        pcall(function()
            if camera.CameraType == Enum.CameraType.Scriptable then
                if camera.CFrame == appliedPose then camera.CFrame = before.CFrame end
                if camera.Focus == appliedFocus then camera.Focus = before.Focus end
                camera.CameraType = before.CameraType
            end
            if camera.FieldOfView == fieldOfView then camera.FieldOfView = before.FieldOfView end
        end)
        current, cameraBefore, appliedPose, appliedFocus, bloom, grade = nil, nil, nil, nil, nil, nil
    end

    local function acquire(camera)
        releaseCamera()
        current = camera
        cameraBefore = {
            CameraType = camera.CameraType, CFrame = camera.CFrame,
            Focus = camera.Focus, FieldOfView = camera.FieldOfView,
        }
        camera.CameraType = Enum.CameraType.Scriptable
        camera.FieldOfView = fieldOfView

        bloom = Instance.new("BloomEffect")
        bloom.Name = "CyberOutlawNeonBloom"
        bloom.Intensity = 0.72
        bloom.Size = 38
        bloom.Threshold = 0.88
        bloom.Parent = camera

        grade = Instance.new("ColorCorrectionEffect")
        grade.Name = "CyberOutlawNightGrade"
        grade.Brightness = 0.015
        grade.Contrast = 0.11
        grade.Saturation = 0.02
        grade.TintColor = light(214, 227, 255)
        grade.Parent = camera
    end

    local function renderPose(camera, seconds)
        local pose = cameraPath(seconds, aspectRatio())
        local focus = CFrame.new(pose.Position + pose.LookVector * 95)
        camera.CFrame = pose
        camera.Focus = focus
        appliedPose = camera.CFrame
        appliedFocus = camera.Focus
    end

    local function restoreStage()
        releaseCamera()
        for index = #lightingBefore, 1, -1 do
            local entry = lightingBefore[index]
            local instance, key, before, staged = table.unpack(entry)
            pcall(function()
                if instance.Parent and instance[key] == staged then instance[key] = before end
            end)
        end
        table.clear(lightingBefore)
        if scene then
            scene:Destroy()
            scene = nil
        end
    end

    local ok = pcall(function()
        assert(workspace.CurrentCamera, "A câmera do jogador ainda está inicializando")
        scene = Instance.new("Folder")
        scene.Name = "CyberOutlawMenuStage"
        scene.Archivable = false
        scene.Parent = workspace
        local city
        city, cameraPath, animate = createCyberCity(scene, art, stagePosition)
        assert(type(cameraPath) == "function", "A cena precisa de trajetória")
        addCyberOutlawMaterials(city, art, stagePosition)
        addCyberOutlawFacades(city, art)
        write(lighting, "ClockTime", 1.1)
        write(lighting, "Brightness", 1.65)
        write(lighting, "Ambient", light(61, 52, 82))
        write(lighting, "OutdoorAmbient", light(67, 78, 108))
        write(lighting, "EnvironmentDiffuseScale", 0.34)
        write(lighting, "EnvironmentSpecularScale", 0.91)
        write(lighting, "GlobalShadows", true)
        write(lighting, "ShadowSoftness", 0.4)
        write(lighting, "ExposureCompensation", 0.06)
        local haze = lighting:FindFirstChildOfClass("Atmosphere")
        if haze then
            write(haze, "Density", 0.21)
            write(haze, "Offset", 0.13)
            write(haze, "Color", light(98, 138, 194))
            write(haze, "Decay", light(41, 27, 69))
            write(haze, "Glare", 0)
            write(haze, "Haze", 0.42)
        else
            write(lighting, "FogColor", light(30, 43, 72))
            write(lighting, "FogStart", 145)
            write(lighting, "FogEnd", 590)
        end
        acquire(workspace.CurrentCamera)
        renderPose(current, 0)
    end)

    if ok then
        viewport.ImageTransparency = 1
        viewport:SetAttribute("CyberOutlawWorkspaceStage", true)
    else
        restoreStage()
        local fallback, model, path, motion = pcall(createCyberCity, viewportWorld, art)
        if fallback and type(path) == "function" then
            scene, cameraPath, animate = model, path, motion
            addCyberOutlawMaterials(model, art, Vector3.zero)
            addCyberOutlawFacades(model, art)
            viewportCamera.FieldOfView = fieldOfView
            viewportCamera.CFrame = path(0, aspectRatio())
            viewport.ImageTransparency = 0
        else
            cameraPath, animate = nil, nil
            viewport.ImageTransparency = 1
        end
        viewport:SetAttribute("CyberOutlawWorkspaceStage", false)
    end

    local function step(seconds)
        if closed or not cameraPath then return end
        if animate then animate(seconds) end
        if ok then
            local camera = workspace.CurrentCamera
            if not camera then return end
            if camera ~= current then acquire(camera) end
            renderPose(camera, seconds)
        else
            viewportCamera.CFrame = cameraPath(seconds, aspectRatio())
        end
    end

    local function close()
        if closed then return end
        closed = true
        restoreStage()
    end

    return step, close
end
