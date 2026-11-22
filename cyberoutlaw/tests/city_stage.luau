local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local source = fs.readFile("src/city.luau")
local createCyberCity = luau.load(source .. "\nreturn createCyberCity", {
    debugName = "city.luau",
    environment = {
        CFrame = roblox.CFrame,
        Color3 = roblox.Color3,
        Enum = roblox.Enum,
        Instance = roblox.Instance,
        Vector3 = roblox.Vector3,
    },
})()

local parent = roblox.Instance.new("WorldModel")
local city, cameraAt = createCyberCity(parent)
assert(city.Parent == parent and city:IsA("Model"))
local duration = city:GetAttribute("LoopDuration")
assert(duration >= 50 and duration <= 85)

local function vectorEntries(v)
    return {v.X, v.Y, v.Z}
end

local function cframeEntries(cf)
    return {cf:GetComponents()}
end

local modelCount = 0
local parts = {}
local anchors = {}
local materialCounts = {}
for _, object in city:GetDescendants() do
    if object:IsA("Part") then
        assert(object.Anchored and not object.CanCollide and not object.CanTouch and not object.CanQuery)
        assert(not object.CastShadow)
        local cf, size, color = object.CFrame, object.Size, object.Color
        assert(size.X >= 0.001 and size.Y >= 0.001 and size.Z >= 0.001)
        table.insert(parts, {
            name = object.Name,
            cf = cframeEntries(cf),
            size = vectorEntries(size),
            color = {color.R, color.G, color.B},
            material = object.Material.Name,
            shape = object.Shape.Name,
        })
        table.insert(anchors, {cf = cf, half = size / 2})
        materialCounts[object.Material.Name] = (materialCounts[object.Material.Name] or 0) + 1
    else
        assert(object:IsA("Model"), "City contains a non-geometry instance")
        modelCount += 1
    end
end
assert(#parts >= 1100 and #parts <= 2400, "City part budget exceeded")
assert(#city["Torres do estuário"]:GetChildren() == 8, "Signature towers are missing")

local frames = {}
local lower = roblox.Vector3.new(math.huge, math.huge, math.huge)
local upper = -lower
local nearest = math.huge
local previous
local maxSpeed = 0
local rate = 12
for i = 0, duration * rate do
    local seconds = i / rate
    local pose = cameraAt(seconds)
    local eye = pose.Position
    assert(pose.LookVector.Z < -0.94, "Camera strayed from the city")
    lower = roblox.Vector3.new(math.min(lower.X, eye.X), math.min(lower.Y, eye.Y), math.min(lower.Z, eye.Z))
    upper = roblox.Vector3.new(math.max(upper.X, eye.X), math.max(upper.Y, eye.Y), math.max(upper.Z, eye.Z))
    if previous then
        maxSpeed = math.max(maxSpeed, (eye - previous).Magnitude * rate)
    end
    previous = eye

    if i % 4 == 0 then
        for _, part in anchors do
            local point = part.cf:PointToObjectSpace(eye)
            local delta = roblox.Vector3.new(
                math.max(math.abs(point.X) - part.half.X, 0),
                math.max(math.abs(point.Y) - part.half.Y, 0),
                math.max(math.abs(point.Z) - part.half.Z, 0)
            )
            nearest = math.min(nearest, delta.Magnitude)
        end
    end
    if seconds <= 16 then
        table.insert(frames, {t = seconds, cf = cframeEntries(pose)})
    end
end

assert(nearest > 15, "Camera came too close to geometry")
assert(maxSpeed < 2, "Camera movement should remain slow")
local origin = cframeEntries(cameraAt(0))
local seam = cframeEntries(cameraAt(duration))
for i, value in origin do
    assert(math.abs(value - seam[i]) <= 1e-6, "Camera loop is discontinuous")
end

local function velocityAt(t)
    local delta = 1 / 30
    return (cameraAt(t + delta).Position - cameraAt(t - delta).Position) / (2 * delta)
end

assert((velocityAt(0) - velocityAt(duration)).Magnitude <= 1e-4, "Velocity jumps across loop")
print(
    ("City stage passed with %d parts (%d neon), %d descendant models, %ds loop, %.1f-stud clearance, %.2f studs/s")
        :format(#parts, materialCounts.Neon, modelCount, duration, nearest, maxSpeed)
)
print(("Camera bounds %s to %s"):format(tostring(lower), tostring(upper)))

if process.args[1] then
    fs.writeFile(process.args[1], serde.encode("json", {
        parts = parts,
        frames = frames,
        cameras = {
            {t = 0, cf = origin},
            {t = 17, cf = cframeEntries(cameraAt(17))},
            {t = 34, cf = cframeEntries(cameraAt(34))},
            {t = 51, cf = cframeEntries(cameraAt(51))},
        },
        fieldOfView = 44,
        duration = duration,
        bounds = {minimum = vectorEntries(lower), maximum = vectorEntries(upper)},
    }))
end
