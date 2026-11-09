--!strict
-- Movimento do próprio personagem (o cliente é dono da física dele):
-- plataformas de salto, empurrões vindos do servidor, poder de voar,
-- queda lenta (paraquedas) e direção de veículos com botões de altitude.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent.Parent.UI.Theme)

local Movement = {}

local player = Players.LocalPlayer
local flyUntil = 0
local slowUntil = 0
local flyVel: LinearVelocity? = nil
local slowForce: VectorForce? = nil
local padCooldown = 0
local airUp = 0
local airButtons: Frame? = nil

local function charParts(): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Movement.push(v: Vector3, mode: string?)
	local _, hum, root = charParts()
	if not root or not hum or hum.Sit then
		return
	end
	-- limita impulsos absurdos (proteção contra valores estranhos)
	if v.Magnitude > 400 then
		v = v.Unit * 400
	end
	if v.Y > 5 then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	if mode == "set" then
		root.AssemblyLinearVelocity = v
	else
		root.AssemblyLinearVelocity += v
	end
end

function Movement.fly(duration: number)
	flyUntil = os.clock() + duration
end

function Movement.slowfall(duration: number)
	slowUntil = os.clock() + duration
end

local function hookPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	pad.Touched:Connect(function(hit)
		local char, hum, root = charParts()
		if not char or not root or not hum or not hit:IsDescendantOf(char) then
			return
		end
		if os.clock() < padCooldown then
			return
		end
		padCooldown = os.clock() + 1
		local force = (pad:GetAttribute("Forca") :: number?) or 120
		local dir = (pad:GetAttribute("Direcao") :: Vector3?) or Vector3.yAxis
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = dir.Unit * force
		if force > 200 then
			slowUntil = os.clock() + 6
		end
	end)
end

-- direção de veículos -------------------------------------------------------------
local yaw = 0
local currentSeat: VehicleSeat? = nil

local function vehicleOf(seat: Instance?): Model?
	if seat and seat:IsA("VehicleSeat") then
		local m = seat:FindFirstAncestorOfClass("Model")
		if m and m:GetAttribute("Veiculo") then
			return m
		end
	end
	return nil
end

local function drive(dt: number)
	local _, hum = charParts()
	local seat = hum and hum.SeatPart
	local model = vehicleOf(seat)
	if not model or not seat then
		if airButtons then
			airButtons.Visible = false
		end
		currentSeat = nil
		return
	end
	local vseat = seat :: VehicleSeat
	local chassis = model.PrimaryPart
	local lv = chassis and chassis:FindFirstChild("Tracao") :: LinearVelocity?
	local ao = chassis and chassis:FindFirstChild("Estabilizador") :: AlignOrientation?
	if not chassis or not lv or not ao then
		return
	end
	if currentSeat ~= vseat then
		currentSeat = vseat
		local look = chassis.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
	end
	local drivemode = model:GetAttribute("Conducao")
	if drivemode == "rocket" then
		return -- o foguete é controlado pelo servidor
	end
	local maxSpeed = (model:GetAttribute("VelMax") :: number?) or 60
	local throttle = vseat.ThrottleFloat
	local steer = vseat.SteerFloat
	-- no celular o analógico também vale (MoveDirection relativo à câmera)
	if math.abs(throttle) < 0.05 and math.abs(steer) < 0.05 and hum then
		local md = hum.MoveDirection
		if md.Magnitude > 0.1 then
			local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
			local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
			throttle = md:Dot(forward)
			steer = md:Dot(right)
		end
	end
	yaw -= steer * 1.8 * dt * (if throttle < -0.1 then -1 else 1)
	local look = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local speed = throttle * maxSpeed * (if throttle < 0 then 0.45 else 1)
	ao.CFrame = CFrame.Angles(0, yaw, 0)
	if drivemode == "air" then
		if airButtons then
			airButtons.Visible = true
		end
		local up = airUp
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			up = 1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			up = -1
		end
		lv.VectorVelocity = look * speed + Vector3.new(0, up * 30, 0)
	else
		if airButtons then
			airButtons.Visible = false
		end
		lv.PlaneVelocity = Vector2.new(look.X * speed, look.Z * speed)
	end
end

local function buildAirButtons(gui: ScreenGui)
	local frame = Theme.new("Frame", {
		Name = "Altitude",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.45, 0),
		Size = UDim2.fromOffset(64, 140),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, { Theme.new("UIListLayout", { Padding = UDim.new(0, 10) }) })
	for _, def in { { "▲", 1 }, { "▼", -1 } } do
		local b = Theme.button({ Text = def[1], TextSize = 26, Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Theme.Colors.bg, BackgroundTransparency = 0.2, Parent = frame })
		Theme.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = b })
		b.MouseButton1Down:Connect(function()
			airUp = def[2] :: number
		end)
		b.MouseButton1Up:Connect(function()
			airUp = 0
		end)
		b.MouseLeave:Connect(function()
			airUp = 0
		end)
	end
	airButtons = frame
end

local function step(dt: number)
	local char, hum, root = charParts()
	if not char or not hum or not root then
		return
	end
	local now = os.clock()
	-- voo: velocidade segue a direção da câmera enquanto anda
	if now < flyUntil and not hum.Sit then
		if not flyVel or flyVel.Parent ~= root then
			local att = root:FindFirstChild("VooLocal") :: Attachment? or Instance.new("Attachment")
			att.Name = "VooLocal"
			att.Parent = root
			local lv = Instance.new("LinearVelocity")
			lv.Attachment0 = att
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.MaxForce = 4e4
			lv.Parent = root
			flyVel = lv
		end
		local cam = Workspace.CurrentCamera
		local md = hum.MoveDirection
		local v = Vector3.zero
		if md.Magnitude > 0.05 and cam then
			local look = cam.CFrame.LookVector
			v = (md + Vector3.new(0, look.Y * md.Magnitude, 0)).Unit * 55
		end
		if hum.Jump then
			v += Vector3.new(0, 30, 0)
		end
		;(flyVel :: LinearVelocity).VectorVelocity = v
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	elseif flyVel then
		flyVel:Destroy()
		flyVel = nil
	end
	-- queda lenta
	if now < slowUntil then
		if not slowForce or slowForce.Parent ~= root then
			local att = root:FindFirstChild("QuedaLocal") :: Attachment? or Instance.new("Attachment")
			att.Name = "QuedaLocal"
			att.Parent = root
			local f = Instance.new("VectorForce")
			f.Attachment0 = att
			f.RelativeTo = Enum.ActuatorRelativeTo.World
			f.Parent = root
			slowForce = f
		end
		local mass = root.AssemblyMass
		local g = Workspace.Gravity
		local vy = root.AssemblyLinearVelocity.Y
		;(slowForce :: VectorForce).Force = Vector3.new(0, if vy < -12 then mass * g * 0.92 else mass * g * 0.3, 0)
	elseif slowForce then
		slowForce:Destroy()
		slowForce = nil
	end
	drive(dt)
end

function Movement.init(gui: ScreenGui)
	for _, pad in CollectionService:GetTagged("IdeiasPulo") do
		hookPad(pad)
	end
	CollectionService:GetInstanceAddedSignal("IdeiasPulo"):Connect(hookPad)
	buildAirButtons(gui)
	RunService.Heartbeat:Connect(step)
end

return Movement
