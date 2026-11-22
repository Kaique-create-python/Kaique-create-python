local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

assert(fs.isFile("src/menu.client.luau"), "the client menu is required")
local source = fs.readFile("src/menu.client.luau")
local E = roblox.Enum

local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { connected = true, Disconnect = function(self) self.connected = false end }
			listeners[connection] = callback
			return connection
		end,
		Fire = function(_, ...)
			for connection, callback in table.clone(listeners) do
				if connection.connected then
					callback(...)
				end
			end
		end,
	}
end

-- Lune supplies Roblox value types. Model the few runtime events and GUI sizes
-- the LocalScript receives from Studio so the actual state transitions can run.
local function scenario(config, options)
	options = options or {}
	local h = {
		now = 0, size = options.size or roblox.Vector2.new(1280, 680), jobs = {}, sounds = {}, bindings = {},
		failCity = options.failCity, useStage = options.useStage,
	}
	local nodeMethods = {}
	function nodeMethods:GetPropertyChangedSignal(key)
		self.changes[key] = self.changes[key] or signal()
		return self.changes[key]
	end
	function nodeMethods:FindFirstChild(name, recursive)
		for _, child in self.children do
			if child.Name == name then
				return child
			end
		end
		if recursive then
			for _, child in self.children do
				local found = child:FindFirstChild(name, true)
				if found then
					return found
				end
			end
		end
	end
	nodeMethods.WaitForChild = nodeMethods.FindFirstChild
	function nodeMethods:GetAttribute(name)
		return self.attributes[name]
	end
	function nodeMethods:SetAttribute(name, value)
		local previous = self.attributes[name]
		self.attributes[name] = value
		if previous ~= value then
			self:GetAttributeChangedSignal(name):Fire()
		end
	end
	function nodeMethods:GetAttributeChangedSignal(name)
		return self:GetPropertyChangedSignal("attribute:" .. name)
	end
	function nodeMethods:IsDescendantOf(ancestor)
		local current = self.Parent
		while current do
			if current == ancestor then
				return true
			end
			current = current.Parent
		end
		return false
	end
	function nodeMethods:Destroy()
		if self.destroyed then
			return
		end
		self.destroyed = true
		self.Destroying:Fire()
		for _, child in table.clone(self.children) do
			child:Destroy()
		end
		self.Parent = nil
	end
	function nodeMethods:Play()
		self.Playing = true
		self.IsPlaying = true
		if self.ClassName == "Sound" then
			table.insert(h.sounds, self.Name)
		end
	end
	function nodeMethods:Pause()
		self.Playing = false
	end
	function nodeMethods:Stop()
		self.IsPlaying = false
	end

	local function node(class, name)
		local self = { changes = {}, attributes = {}, children = {}, values = {} }
		self.values.ClassName = class
		self.values.Name = name or class
		self.values.Size = roblox.UDim2.fromOffset(100, 100)
		self.values.Position = roblox.UDim2.fromOffset(0, 0)
		self.values.AnchorPoint = roblox.Vector2.new(0, 0)
		self.values.Visible = true
		self.values.Active = false
		self.values.IsLoaded = false
		for _, key in { "Destroying", "Activated", "MouseEnter", "MouseLeave", "SelectionGained",
			"SelectionLost", "InputBegan", "InputChanged", "InputEnded", "WindowFocusReleased",
			"Loaded", "Ended" } do
			self.values[key] = signal()
		end
		return setmetatable(self, {
			__index = function(instance, key)
				local values = instance.values
				if key == "AbsoluteSize" or key == "AbsolutePosition" then
					local parent = values.Parent
					if not parent or class == "ScreenGui" then
						return if key == "AbsoluteSize" then h.size else roblox.Vector2.new(0, 0)
					end
					local parentSize, size = parent.AbsoluteSize, values.Size
					local ownSize = roblox.Vector2.new(parentSize.X * size.X.Scale + size.X.Offset, parentSize.Y * size.Y.Scale + size.Y.Offset)
					if key == "AbsoluteSize" then
						return ownSize
					end
					local pos, anchor = values.Position, values.AnchorPoint
					return parent.AbsolutePosition + roblox.Vector2.new(
						parentSize.X * pos.X.Scale + pos.X.Offset - ownSize.X * anchor.X,
						parentSize.Y * pos.Y.Scale + pos.Y.Offset - ownSize.Y * anchor.Y
					)
				end
				return nodeMethods[key] or values[key]
			end,
			__newindex = function(instance, key, value)
				local previous = instance.values[key]
				if key == "Parent" and previous ~= value then
					if previous then
						table.remove(previous.children, assert(table.find(previous.children, instance)))
					end
					if value then
						table.insert(value.children, instance)
					end
				end
				instance.values[key] = value
				local changed = instance.changes[key]
				if changed and previous ~= value then
					changed:Fire()
				end
			end,
		})
	end

	h.gui = node("PlayerGui")
	h.player = node("Player")
	h.player.DisplayName = "Outlaw Teste"
	h.player.UserId = 321
	h.gui.Parent = h.player
	h.script = node("LocalScript")
	h.guiService = node("GuiService")
	h.guiService.ReducedMotionEnabled = options.reduced == true
	h.input = node("UserInputService")
	h.input.PreferredInput = options.preferredInput or E.PreferredInput.KeyboardAndMouse
	local heartbeat = signal()
	local services = {
		Players = { LocalPlayer = h.player },
		GuiService = h.guiService,
		UserInputService = h.input,
		RunService = { Heartbeat = heartbeat },
		SoundService = node("SoundService"),
		ContentProvider = { PreloadAsync = function() end },
		ContextActionService = {
			BindActionAtPriority = function(_, name, callback)
				h.bindings[name] = callback
			end,
			UnbindAction = function(_, name)
				h.bindings[name] = nil
			end,
		},
	}

	local function schedule(seconds, callback)
		local job = { at = h.now + seconds, run = callback }
		table.insert(h.jobs, job)
		return job
	end

	function h:step(seconds)
		local target = self.now + seconds
		while self.now + 0.000001 < target do
			local dt = math.min(0.025, target - self.now)
			self.now += dt
			for _, job in table.clone(self.jobs) do
				if job.run and job.at <= self.now + 0.000001 then
					local run = job.run
					job.run = nil
					run()
				end
			end
			heartbeat:Fire(dt)
		end
	end

	function h:run()
		local code = string.gsub(source, "__CYBEROUTLAW_CONFIG__", function()
			return config or "{}"
		end)
		code = string.gsub(code, "%-%- __CYBEROUTLAW_CITY__", [[
			local function createCyberCity(parent)
				Trace.cityParent = parent
				local city = Instance.new("Model")
				city.Parent = parent
				if Trace.failCity then
					error("city unavailable")
				end
				return city, function(seconds)
					Trace.cityTime = seconds
					return CFrame.new(seconds, 0, 0)
				end
			end
		]])
		code = string.gsub(code, "%-%- __CYBEROUTLAW_SCENE__", [[
			local function openCyberOutlawScene(_, view)
				if not Trace.useStage then
					return
				end
				view:SetAttribute("CyberOutlawWorkspaceStage", true)
				return function(seconds)
					Trace.stageTime = seconds
				end, function()
					Trace.stageClosed = true
					view:SetAttribute("CyberOutlawWorkspaceStage", false)
				end
			end
		]])
		local binding = luau.load(code, {
			debugName = "menu.client.luau",
			injectGlobals = true,
			environment = {
				Trace = h,
				Enum = E,
				Instance = { new = node },
				script = h.script,
				game = { GetService = function(_, name) return assert(services[name], name) end },
				Vector2 = roblox.Vector2,
				Vector3 = roblox.Vector3,
				Color3 = roblox.Color3,
				UDim2 = roblox.UDim2,
				UDim = roblox.UDim,
				CFrame = roblox.CFrame,
				Font = roblox.Font,
				ColorSequence = roblox.ColorSequence,
				ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
				NumberSequence = roblox.NumberSequence,
				NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
				Rect = roblox.Rect,
				Random = { new = function()
					return {
						NextNumber = function(_, low, high) return low + (high - low) / 2 end,
						NextInteger = function(_, low, _) return low end,
					}
				end },
				os = {
					clock = function() return h.now end,
					date = function() return { hour = 17 } end,
				},
				task = {
					delay = schedule,
					defer = function(fun) return schedule(0, fun) end,
					spawn = function(fun) return schedule(0, fun) end,
					cancel = function(job) job.run = nil end,
				},
				warn = function() end,
			},
		})
		binding()
	end

	function h:find(name)
		return self.gui:FindFirstChild(name, true)
	end
	function h:resize(width, height)
		self.size = roblox.Vector2.new(width, height)
		self:find("SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
	end
	h:run()
	return h
end

local main = scenario("{video = 123}", { reduced = true, preferredInput = E.PreferredInput.Gamepad })
assert(main:find("CyberOutlawBackdrop") and main:find("CyberOutlawMenu"), "menu layers were not mounted")
assert(main.player:GetAttribute("CyberOutlawMenuOpen") == true, "gameplay is gated during the loader")
assert(main:find("Loader").Visible and not main:find("MenuStack").Visible, "loader owns the first real frame")
main:step(5.95)
assert(main:find("Loader").Visible, "loader ended early")
assert(main.cityParent.ClassName == "WorldModel" and main.cityParent.Parent.ClassName == "ViewportFrame", "the city must be real isolated 3D")
assert(main.cityTime == 0, "reduced motion must keep the viewport camera still")
local video = main:find("LoadingVideo")
assert(not video or not video.Playing, "the loader respects reduced motion")
main:step(0.05)
assert(not main:find("Loader") and main:find("MenuStack").Visible, "no optional asset can delay the six-second loader")
assert(not main:find("LoadingVideo"), "the loader releases video before the menu")
assert(main.guiService.SelectedObject == main:find("Play"), "controller focus starts at Play")
main:find("Settings").Activated:Fire()
assert(main:find("Modal").Visible and main:find("SoundToggle").Visible, "Configurações opens its controls")
main:find("SoundToggle").Activated:Fire()
main:find("Close").Activated:Fire()
assert(main.guiService.SelectedObject == main:find("Settings"), "modal closes back to its caller")
main:find("Credits").Activated:Fire()
assert(main:find("Modal").Visible, "Créditos opens its panel")
main:find("Close").Activated:Fire()
main:find("Play").Activated:Fire()
main:step(0.5)
assert(main.player:GetAttribute("CyberOutlawMenuStarted") == true, "Jogar reports the local handoff")
assert(main.player:GetAttribute("CyberOutlawMenuOpen") == false and not main:find("CyberOutlawMenu") and not main:find("CyberOutlawBackdrop"), "handoff releases both screens and gameplay gate")
assert(main.guiService.SelectedObject == nil and next(main.bindings) == nil, "handoff releases menu focus and bound input")

local moving = scenario("{video=678,sounds={click=987,rain=988}}")
moving:step(0.02)
assert(#moving.sounds == 0, "the opening is silent")
local mutedVideo = assert(moving:find("LoadingVideo"))
assert(mutedVideo.Volume == 0 and not mutedVideo.Playing, "video starts muted when it loads")
mutedVideo.IsLoaded = true
mutedVideo.Loaded:Fire()
assert(mutedVideo.Playing, "valid, loaded video can play within the loader")
moving:step(6)
assert(moving.cityTime > 1, "the panorama normally moves")
assert(moving.sounds[1] == "rain", "the rain starts when the opening ends")
moving:find("Settings").Activated:Fire()
moving:find("MotionToggle").Activated:Fire()
moving:step(0.07)
assert(moving.cityTime == 0, "the animation setting can stop the city camera")
moving:find("SoundToggle").Activated:Fire()
local played = #moving.sounds
moving:find("Close").Activated:Fire()
moving:find("Credits").Activated:Fire()
assert(#moving.sounds == played, "muting prevents menu sounds")
moving.script:Destroy()
moving:run()
assert(not moving:find("Loader") and moving:find("MenuStack").Visible, "a reopened menu does not repeat the session loader")

local narrow = scenario("{}", { size = roblox.Vector2.new(320, 510) })
narrow:step(6)
local function checkButtons(h)
	for _, name in { "Play", "Settings", "Credits" } do
		local button = h:find(name)
		assert(button.AbsoluteSize.Y >= 44, name .. " is hard to tap on a narrow phone")
		assert(button.AbsolutePosition.X >= 0 and button.AbsolutePosition.X + button.AbsoluteSize.X <= h.size.X, name .. " crosses horizontal safe bounds")
		assert(button.AbsolutePosition.Y >= 0 and button.AbsolutePosition.Y + button.AbsoluteSize.Y <= h.size.Y, name .. " crosses vertical safe bounds")
	end
end

checkButtons(narrow)
narrow:resize(568, 238)
checkButtons(narrow)

local fallBack = scenario("{}", { failCity = true })
fallBack:step(6)
assert(fallBack:find("MenuStack").Visible and fallBack:find("CyberCity").ImageTransparency == 1,
	"a city build failure preserves the menu and dark fallback")

local stage = scenario("{art={title=902}}", { useStage = true })
assert(stage:find("Backdrop").BackgroundTransparency == 0, "the place stays hidden while the menu stage starts")
assert(not stage:find("Profile").Visible, "the loader keeps the profile hidden")
stage:step(6.1)
assert(stage:find("Backdrop").BackgroundTransparency == 1 and stage.stageTime > 0, "the live 3D stage shows through the backdrop")
assert(stage:find("Wordmark").Text == "CyberOutlaw" and stage:find("Wordmark").Visible and not stage:find("Logo").Visible,
	"the wordmark stays legible if its image is slow or unavailable")
stage:find("Logo").IsLoaded = true
stage:step(0.05)
assert(stage:find("Logo").Visible and not stage:find("Wordmark").Visible, "the supplied brush art replaces the wordmark after loading")
assert(stage:find("Profile").Visible and stage:find("DisplayName").Text == "Outlaw Teste", "profile shows the player's real display name")
assert(string.find(stage:find("Avatar").Image, "&id=321&", 1, true), "profile thumbnail uses the local player id")
assert(not stage:find("Level").Visible, "only an actual level is shown")
stage.player:SetAttribute("Level", 12)
assert(stage:find("Level").Visible and stage:find("Level").Text == "Nível 12", "profile reflects a level supplied by the experience")
stage:find("ProfileSettings").Activated:Fire()
assert(stage:find("Modal").Visible and stage:find("SoundToggle").Visible, "profile gear opens the existing settings")
stage:find("Close").Activated:Fire()
stage.guiService.ReducedMotionEnabled = true
stage:step(0.05)
assert(stage.stageTime == 0, "reduced motion holds the live stage at the first camera pose")
stage:find("Play").Activated:Fire()
assert(stage.stageClosed and stage.player:GetAttribute("CyberOutlawMenuOpen") == false, "Jogar releases the live stage before entering the place")

local function fakeClip(id, size)
	return string.format(
		"{fps=10,frames={{id=%d,x=1,y=1,w=%d,h=%d},{id=%d,x=%d,y=1,w=%d,h=%d}}}",
		id, size.X, size.Y, id, size.X + 2, size.X, size.Y
	)
end
local animations = { "idle", "arrive", "leave", "perch", "laydown", "laydown_sleep", "wake", "dangle", "click", "grin", "blink" }
local definitions, ids = {}, {}
for index, key in animations do
	ids[key] = 500 + index
	definitions[index] = key .. "=" .. fakeClip(ids[key], if key == "click" then roblox.Vector2.new(64, 64) else roblox.Vector2.new(142, 200))
end
local capri = scenario("{clips={" .. table.concat(definitions, ",") .. "},sounds={react=800,hello_miss=801,confirm=802}}")
local body = capri:find("CapriSprite")
local grab = capri:find("CapriHitBox")
local function imageFor(key)
	return "rbxassetid://" .. tostring(ids[key])
end
local function verifySafeCapri()
	local pos, size = body.AbsolutePosition, body.AbsoluteSize
	assert(grab.Visible and grab.AbsoluteSize.X >= 44 and grab.AbsoluteSize.Y >= 44, "Capri has a usable touch target")
	assert(pos.X >= 0 and pos.Y >= 0 and pos.X + size.X <= capri.size.X and pos.Y + size.Y <= capri.size.Y,
		"the sprite's canvas stays inside the safe viewport")
	local grabPos, grabSize = grab.AbsolutePosition, grab.AbsoluteSize
	for _, key in { "Play", "Settings", "Credits" } do
		local other = capri:find(key)
		local origin, extent = other.AbsolutePosition, other.AbsoluteSize
		local overlap = grabPos.X < origin.X + extent.X and grabPos.X + grabSize.X > origin.X
			and grabPos.Y < origin.Y + extent.Y and grabPos.Y + grabSize.Y > origin.Y
		assert(not overlap, "Capri does not intercept button " .. key)
	end
end
capri:step(6.3)
assert(body.Image == imageFor("idle"), "Capri settles after arriving")
verifySafeCapri()
assert(body.AbsoluteSize.Y >= 430, "Capri has a substantially larger desktop canvas")
local original = body.Position
local initial = grab.AbsolutePosition + grab.AbsoluteSize / 2
local touch = {
	UserInputType = E.UserInputType.Touch, UserInputState = E.UserInputState.Begin,
	Position = roblox.Vector3.new(initial.X, initial.Y, 0),
}
grab.InputBegan:Fire(touch)
capri.input.InputChanged:Fire({
	UserInputType = E.UserInputType.Touch, UserInputState = E.UserInputState.Change,
	Position = touch.Position + roblox.Vector3.new(-110, -25, 0),
})
assert(body.Position == original, "another finger cannot drag Capri")
touch.UserInputState = E.UserInputState.Change
touch.Position += roblox.Vector3.new(-90, -20, 0)
capri.input.InputChanged:Fire(touch)
assert(body.Position ~= original and body.Image == imageFor("dangle"), "the grabbing finger moves Capri with dangle animation")
capri:step(9)
assert(body.Image == imageFor("dangle"), "a held drag suspends autonomous movement")
touch.Position = roblox.Vector3.new(5000, 5000, 0)
capri.input.InputChanged:Fire(touch)
verifySafeCapri()
touch.UserInputState = E.UserInputState.End
capri.input.InputEnded:Fire(touch)
assert(body.Image == imageFor("idle"), "release settles Capri")

capri:resize(390, 780)
verifySafeCapri()
assert(body.AbsoluteSize.Y >= 300, "Capri stays larger on portrait phones")
capri:resize(320, 510)
verifySafeCapri()
capri:resize(1280, 680)
verifySafeCapri()

local pointer = {
	UserInputType = E.UserInputType.MouseButton1, UserInputState = E.UserInputState.Begin,
	Position = roblox.Vector3.new(grab.AbsolutePosition.X, grab.AbsolutePosition.Y, 0),
}
grab.InputBegan:Fire(pointer)
pointer.UserInputState = E.UserInputState.End
capri.input.InputEnded:Fire(pointer)
assert(capri:find("CapriClick").Visible and body.Image == imageFor("grin"), "tapping Capri plays the separate click effect and grin")
capri:step(0.3)
assert(not capri:find("CapriClick").Visible, "the click effect ends on its own")
capri:step(9)
assert(body.Image == imageFor("perch"), "autonomy teleports Capri and lets her perch")
verifySafeCapri()
capri:step(9)
assert(body.Image == imageFor("laydown"), "Capri moves from perching to resting")
capri:step(8)
assert(body.Image == imageFor("laydown_sleep"), "rest can lead to sleep")
capri:step(8)
assert(body.Image == imageFor("idle") or body.Image == imageFor("wake"), "Capri wakes up after sleeping")

capri.guiService.ReducedMotionEnabled = true
capri:find("Play").Activated:Fire()
assert(capri.sounds[#capri.sounds] == "confirm" and capri:find("CyberOutlawMenu"), "Jogar gives the confirm sound time to play in reduced motion")
capri:step(0.35)
assert(not capri:find("CyberOutlawMenu") and capri.player:GetAttribute("CyberOutlawMenuStarted"), "confirm finishes in the normal handoff")

print("CyberOutlaw menu timeline, live and fallback 3D, brush art, player profile, settings, focus, media, responsive layouts and Capri interactions passed")
