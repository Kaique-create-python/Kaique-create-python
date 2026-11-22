local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local source = fs.readFile("src/city.luau")
local createCyberCity = luau.load(source .. "\nreturn createCyberCity", {
    debugName = "city.luau",
    environment = {
        CFrame = roblox.CFrame,
        Color3 = roblox.Color3,
        Enum = roblox.Enum,
        Instance = roblox.Instance,
        UDim2 = roblox.UDim2,
        Vector2 = roblox.Vector2,
        Vector3 = roblox.Vector3,
    },
})()

local function mount(media, origin)
    local parent = roblox.Instance.new("Model")
    local model, cameraAt, updateAt = createCyberCity(parent, media, origin)
    assert(model.Parent == parent and model:IsA("Model"))
    assert(type(updateAt) == "function")
    return model, cameraAt, updateAt
end

local zero = roblox.Vector3.zero
local origin = roblox.Vector3.new(13300, 4100, 7200)
local city, cameraAt, updateAt = mount(nil, zero)
local offsetCity, cameraOffset = mount({billboard = 1001, facades = 1002}, origin)
local duration = city:GetAttribute("LoopDuration")
local verticalFov = city:GetAttribute("VerticalFieldOfView")
assert(duration >= 50 and duration <= 85 and verticalFov >= 44 and verticalFov <= 48)

local function near(a, b, epsilon)
    assert((a - b).Magnitude < epsilon, ("Expected %s near %s"):format(tostring(a), tostring(b)))
end

local function verifyArt(model)
    local count = 0
    local found = {}
    for _, item in model:GetDescendants() do
        if item:IsA("ImageLabel") then
            count += 1
            assert(item.Image == "rbxassetid://1001")
            assert(item.ImageRectSize == roblox.Vector2.new(340, 1020))
            local column = item.ImageRectOffset.X / 340 + 1
            assert(column % 1 == 0 and column >= 1 and column <= 3)
            assert(not found[column])
            found[column] = true
        end
    end
    return count
end

assert(verifyArt(city) == 0 and verifyArt(offsetCity) == 3, "Atlas and native fallback are both required")
local sodium = city:FindFirstChild("Lâmpada de sódio", true)
local sodiumOffset = offsetCity:FindFirstChild("Lâmpada de sódio", true)
near(sodiumOffset.CFrame.Position - sodium.CFrame.Position, origin, 0.002)
assert(city:FindFirstChild("Lua", true):GetAttribute("Moon"))

local geometry = 0
local lights = 0
local shadows = 0
local mirrors = 0
local puddleEdges = 0
local facadeFamilies = {glass = 0, residential = 0, industrial = 0, spine = 0}
local balconies, frames = 0, 0
local opaque = {}
for _, object in city:GetDescendants() do
    if object:IsA("Part") then
        geometry += 1
        assert(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery)
        local size = object.Size
        assert(size.X > 0 and size.Y > 0 and size.Z > 0)
        local family = object:GetAttribute("FacadeFamily")
        if family then
            assert(facadeFamilies[family] ~= nil, "Família desconhecida de fachada")
            local depth = object:GetAttribute("FacadeDepth")
            assert(type(depth) == "number" and depth >= 0 and depth <= 1)
            facadeFamilies[family] += 1
        elseif object.Name == "Laje da varanda" then
            balconies += 1
        elseif object.Name == "Montante vertical do caixilho" then
            frames += 1
        elseif object.Name == "Interior iluminado atrás do caixilho" then
            assert(size.X < 5 and size.Y < 3.1, "A janela deve caber no vão do caixilho")
        end
        if object.Name == "Margem irregular de asfalto" then
            puddleEdges += 1
            assert(object.Shape == roblox.Enum.PartType.Wedge)
        end
        if string.find(object.Name, "Reflexo •", 1, true) then
            mirrors += 1
        end
        if object.Transparency < 0.02 then
            table.insert(opaque, {pose = object.CFrame, half = size / 2})
        end
    elseif object:IsA("Light") then
        lights += 1
        if object.Shadows then
            shadows += 1
            assert(object.Parent == sodium)
        end
        assert(object.Range <= 30)
    end
end
assert(geometry >= 3100 and geometry <= 3900, "Orçamento de geometria excedido")
assert(lights >= 6 and lights <= 12 and shadows == 1, "Orçamento de iluminação excedido")
assert(puddleEdges >= 32 and mirrors >= 60, "Espelho e contorno da poça ausentes")
assert(balconies >= 25 and frames >= 70, "Geometria de caixilho ou varanda ausente")
for family, count in facadeFamilies do
    assert(count > 4, "Poucas fachadas na família " .. family)
end
assert(city:FindFirstChild("Envidraçado recuado", true), "A fachada sem atlas precisa de vidro nativo")
assert(city:FindFirstChild("Vão envidraçado no retorno", true), "O retorno sem atlas precisa de vidro nativo")
assert(not offsetCity:FindFirstChild("Envidraçado recuado", true), "O vidro opaco ocultaria o atlas de fachada")
assert(not offsetCity:FindFirstChild("Vão envidraçado no retorno", true), "O vidro opaco ocultaria o atlas lateral")
local atlasGeometry = 0
for _, item in offsetCity:GetDescendants() do
    if item:IsA("Part") then
        atlasGeometry += 1
    end
end
assert(atlasGeometry < geometry and atlasGeometry <= 3900)

for _, tower in city:FindFirstChild("Quadras verticais"):GetChildren() do
    local shaft = tower:FindFirstChild("Pele do corpo recuado")
    local roof = tower:FindFirstChild("Peitoril da cobertura")
    assert(shaft and roof)
    local shaftTop = shaft.CFrame.Position.Y + shaft.Size.Y / 2
    assert(math.abs(roof.CFrame.Position.Y - shaftTop - 0.04) < 0.01, "Laje sem apoio em " .. tower.Name)
    assert(math.abs(roof.Size.X - shaft.Size.X - 0.38) < 0.01, "Largura do beiral incorreta em " .. tower.Name)
end

local station = city:FindFirstChild("Estação integrada ao edifício", true)
assert(station and station:FindFirstChild("Passagem ao corpo da estação"))
local platformRoof = station:FindFirstChild("Cobertura sobre a via")
local roofBottom = platformRoof.CFrame.Position.Y - platformRoof.Size.Y / 2
local equipment = city:FindFirstChild("Composição em movimento", true):FindFirstChild("Equipamento elétrico")
assert(roofBottom - equipment.CFrame.Position.Y - equipment.Size.Y / 2 > 0.4, "Trem toca a cobertura")

for index, center in {
    roblox.Vector3.new(25.8, 53.5, -67.63), roblox.Vector3.new(52.8, 62.0, -95.89),
    roblox.Vector3.new(91.7, 66.8, -116.79),
} do
    local frame = city:FindFirstChild("Painel de rua " .. index, true):FindFirstChild("Caixilho em aço")
    near(frame.CFrame.Position, center, 0.0001)
end

local function compareCameras(a, b, epsilon)
    near(a.Position, b.Position, epsilon)
    near(a.LookVector, b.LookVector, epsilon)
    near(a.UpVector, b.UpVector, epsilon)
end

local cameraSeam = cameraAt(duration)
compareCameras(cameraAt(0), cameraSeam, 0.00001)
compareCameras(cameraAt(8) + origin, cameraOffset(8), 0.0002)
local function velocityAt(t)
    local dt = 1 / 30
    return (cameraAt(t + dt).Position - cameraAt(t - dt).Position) / (2 * dt)
end
near(velocityAt(0), velocityAt(duration), 0.0001)

local nearest = math.huge
for index = 0, duration * 3 do
    local pose = cameraAt(index / 3)
    assert(pose.LookVector.Z < -0.94)
    for _, part in opaque do
        local point = part.pose:PointToObjectSpace(pose.Position)
        local delta = roblox.Vector3.new(
            math.max(math.abs(point.X) - part.half.X, 0),
            math.max(math.abs(point.Y) - part.half.Y, 0),
            math.max(math.abs(point.Z) - part.half.Z, 0)
        )
        nearest = math.min(nearest, delta.Magnitude)
    end
end
assert(nearest > 4, "A câmera aproxima demais da arquitetura")

local tanVertical = math.tan(math.rad(verticalFov / 2))
local function project(point, t, aspect)
    local v = cameraAt(t, aspect):PointToObjectSpace(point)
    return 0.5 + v.X / (-2 * v.Z * tanVertical * aspect), 0.5 - v.Y / (-2 * v.Z * tanVertical)
end

local heroSign = city:FindFirstChild("Torre da eclusa", true):FindFirstChild("Caixilho em aço", true)
for _, aspect in {16/9, 9/16} do
    for t = 0, duration, 3 do
        local x, y = project(heroSign.CFrame.Position, t, aspect)
        assert(x > 0.5 and x < 0.87 and y > 0.18 and y < 0.58, "O letreiro principal saiu do quadro")
    end
end
local nearDetail = city:FindFirstChild("Baliza magenta de manutenção", true)
local x0 = project(nearDetail.CFrame.Position, 0, 16/9)
local x12 = project(nearDetail.CFrame.Position, 12, 16/9)
local sign0 = project(heroSign.CFrame.Position, 0, 16/9)
local sign12 = project(heroSign.CFrame.Position, 12, 16/9)
assert(math.abs(x12 - x0) > math.abs(sign12 - sign0), "Perspectiva de movimento ausente")

local wagon = city:FindFirstChild("Composição em movimento", true):FindFirstChild("Carroceria")
local streak = city:FindFirstChild("Traço de chuva", true)
local beforeTrain, beforeRain = wagon.CFrame.Position, streak.CFrame.Position
updateAt(3)
assert((wagon.CFrame.Position - beforeTrain).Magnitude > 20)
assert((streak.CFrame.Position - beforeRain).Magnitude > 0.1)
updateAt(duration)
near(wagon.CFrame.Position, beforeTrain, 0.0001)
near(streak.CFrame.Position, beforeRain, 0.0001)

print(("Terraço: %d peças com atlas, %d sem, %d caixilhos, %d varandas, %d reflexos, %d luzes, loop %ds, folga %.2f studs.")
    :format(atlasGeometry, geometry, frames, balconies, mirrors, lights, duration, nearest))
