-- Minimal Roblox service boundary, not an audio or physics engine.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Harness = {}
function Harness.new(config)
	config = config or {}
	local h = { now = 0, nodes = {}, connections = {}, pending = {}, played = {}, warnings = {} }
	function h:signal()
		local listeners = {}
		local s = {}
		function s:Connect(fn)
			local c = { Connected = true, fn = fn }
			function c:Disconnect() self.Connected = false end
			table.insert(listeners, c); table.insert(h.connections, c)
			return c
		end
		function s:Fire(...)
			for _, c in table.clone(listeners) do if c.Connected then c.fn(...) end end
		end
		return s
	end
	local methods = {}
	local function descendants(node, list)
		for _, child in node._children do table.insert(list, child); descendants(child, list) end
		return list
	end
	-- hierarquia mínima de classes que os módulos perguntam (no Roblox, Frame é um GuiObject)
	local HIERARQUIA = {
		BasePart = { Part = true, MeshPart = true },
		GuiObject = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true,
			ScrollingFrame = true, CanvasGroup = true, ViewportFrame = true, TextBox = true },
		GuiButton = { TextButton = true, ImageButton = true },
		LayerCollector = { ScreenGui = true, SurfaceGui = true, BillboardGui = true },
	}
	function methods:IsA(class)
		if self.ClassName == class or class == "Instance" then return true end
		local filhos = HIERARQUIA[class]
		return filhos ~= nil and filhos[self.ClassName] == true
	end
	function methods:FindFirstChild(name, recursive)
		for _, child in self._children do if child.Name == name then return child end end
		if recursive then for _, child in self:GetDescendants() do if child.Name == name then return child end end end
		return nil
	end
	function methods:FindFirstChildOfClass(class) for _, child in self._children do if child:IsA(class) then return child end end; return nil end
	function methods:FindFirstAncestorOfClass(class)
		local parent = self.Parent
		while parent do if parent:IsA(class) then return parent end; parent = parent.Parent end
		return nil
	end
	function methods:WaitForChild(name) return self:FindFirstChild(name) end
	function methods:GetChildren() return table.clone(self._children) end
	function methods:GetDescendants() return descendants(self, {}) end
	function methods:IsDescendantOf(parent)
		local current = self.Parent
		while current do if current == parent then return true end; current = current.Parent end
		return false
	end
	function methods:GetAttribute(name) return self._attributes[name] end
	function methods:SetAttribute(name, value) self._attributes[name] = value; self:GetAttributeChangedSignal(name):Fire() end
	function methods:GetAttributeChangedSignal(name)
		self._attributeSignals[name] = self._attributeSignals[name] or h:signal()
		return self._attributeSignals[name]
	end
	function methods:GetPropertyChangedSignal(name)
		self._propertySignals[name] = self._propertySignals[name] or h:signal()
		return self._propertySignals[name]
	end
	function methods:GetState() return self._state or roblox.Enum.HumanoidStateType.Running end
	function methods:Play()
		self.IsPlaying = true
		table.insert(h.played, { sound = self, at = h.now, position = self.TimePosition, region = self.PlaybackRegion, loopRegion = self.LoopRegion })
	end
	function methods:Stop() self.IsPlaying = false end
	function methods:Destroy()
		if self._destroyed then return end
		self._destroyed = true
		self.Destroying:Fire()
		for _, child in table.clone(self._children) do child:Destroy() end
		self.Parent = nil
	end
	function h:new(class, name, parent)
		local node = {
			_p = { ClassName = class, Name = name or class, AbsoluteSize = roblox.Vector2.new(1280, 720), Position = roblox.Vector3.zero, Volume = 0.65, TimeLength = config.length or 60, TimePosition = 0, IsLoaded = config.autoLoad == true, IsPlaying = false },
			_children = {}, _attributes = {}, _attributeSignals = {}, _propertySignals = {},
		}
		for _, signalName in { "Ended", "Loaded", "AncestryChanged", "Destroying", "ChildAdded", "DescendantAdded", "StateChanged", "CharacterAdded", "CharacterRemoving", "HealthChanged", "Activated" } do node._p[signalName] = self:signal() end
		setmetatable(node, {
			__index = function(self, key) return methods[key] or self._p[key] end,
			__newindex = function(self, key, value)
				if class == "Sound" and key == "PlaybackRegionsEnabled" and config.regions == false then error("PlaybackRegion unsupported") end
				local previous = self._p[key]
				self._p[key] = value
				if key == "Parent" and previous ~= value then
					if previous then local i = table.find(previous._children, self); if i then table.remove(previous._children, i) end end
					if value then
						table.insert(value._children, self); value.ChildAdded:Fire(self)
						local ancestor = value
						while ancestor do ancestor.DescendantAdded:Fire(self); ancestor = ancestor.Parent end
					end
					self.AncestryChanged:Fire(self, value)
				end
				if previous ~= value and self._propertySignals[key] then self._propertySignals[key]:Fire() end
			end,
		})
		table.insert(self.nodes, node)
		if parent then node.Parent = parent end
		return node
	end
	h.workspace = h:new("Workspace", "Workspace")
	h.workspace.Terrain = h:new("Terrain", "Terrain", h.workspace)
	h.workspace.CurrentCamera = { CFrame = { Position = roblox.Vector3.zero } }
	function h.workspace:Raycast() return h.hit end
	function h.workspace:GetServerTimeNow() return h.now end
	h.soundService = h:new("SoundService", "SoundService")
	h.player = h:new("Player", "Player")
	h.playerGui = h:new("PlayerGui", "PlayerGui", h.player)
	h.story = h:new("Folder", "BastiaoHistoria", h.workspace)
	h.heartbeat = h:signal()
	h.tagAdded, h.tagRemoved = h:signal(), h:signal()
	h.tagged = {}
	h.playerAdded, h.playerRemoving = h:signal(), h:signal()
	h.playerList = { h.player }
	h.services = {
		Workspace = h.workspace, SoundService = h.soundService,
		RunService = { Heartbeat = h.heartbeat },
		Players = {
			LocalPlayer = h.player, PlayerAdded = h.playerAdded, PlayerRemoving = h.playerRemoving,
			GetPlayers = function() return h.playerList end,
			GetPlayerFromCharacter = function(_, model) for _, p in h.playerList do if p.Character == model then return p end end; return nil end,
		},
		CollectionService = { GetTagged = function(_, tag) return h.tagged[tag] or {} end, GetInstanceAddedSignal = function() return h.tagAdded end, GetInstanceRemovedSignal = function() return h.tagRemoved end },
		ContentProvider = { PreloadAsync = function(_, probes) for _, probe in probes do probe.IsLoaded = config.preload == true; probe.TimeLength = config.length or 60 end end },
		GuiService = { ReducedMotionEnabled = true },
		UserInputService = { PreferredInput = roblox.Enum.PreferredInput.KeyboardAndMouse, GetPropertyChangedSignal = function() return h:signal() end },
		TweenService = { Create = function(_, node, _, properties) return { Play = function() for key, value in properties do node[key] = value end end } end },
	}
	local taskLib = {}
	function taskLib.spawn(fn, ...) local handle = { fn = fn, args = { ... }, at = h.now }; table.insert(h.pending, handle); return handle end
	taskLib.defer = taskLib.spawn
	function taskLib.delay(delay, fn, ...) local handle = { fn = fn, args = { ... }, at = h.now + delay }; table.insert(h.pending, handle); return handle end
	function taskLib.cancel(handle) if handle then handle.cancelled = true end end
	function taskLib.wait() return 0 end
	h.services.Debris = { AddItem = function(_, node, delay) taskLib.delay(delay, function() node:Destroy() end) end }
	h.environment = {
		game = { GetService = function(_, name) assert(h.services[name], "unknown service " .. name); return h.services[name] end }, workspace = h.workspace,
		Instance = { new = function(class) return h:new(class) end },
		Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, Color3 = roblox.Color3, Font = roblox.Font, Enum = roblox.Enum,
		UDim = roblox.UDim, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange,
		TweenInfo = { new = function(...) return { ... } end }, RaycastParams = { new = function() return {} end },
		Random = { new = function() return { NextNumber = function(_, a, b) return (a + b) / 2 end } end },
		task = taskLib, os = { clock = function() return h.now end },
		typeof = function(value) return if type(value) == "table" and rawget(value, "_p") then "Instance" else typeof(value) end,
		warn = function(message) table.insert(h.warnings, message) end,
	}
	function h:load(path) return luau.load(fs.readFile(path), { environment = self.environment, injectGlobals = true })() end
	function h:flush()
		local due, later = {}, {}
		for _, pending in self.pending do if pending.at <= self.now then table.insert(due, pending) else table.insert(later, pending) end end
		self.pending = later
		for _, pending in due do if not pending.cancelled then pending.fn(table.unpack(pending.args)) end end
	end
	function h:tick(dt) self.now += dt; self:flush(); self.heartbeat:Fire(dt) end
	function h:character(name, parent)
		local model = self:new("Model", name, parent or self.workspace)
		local root = self:new("Part", "HumanoidRootPart", model)
		local humanoid = self:new("Humanoid", "Humanoid", model)
		humanoid.FloorMaterial = roblox.Enum.Material.Concrete
		humanoid.MoveDirection = roblox.Vector3.new(1, 0, 0)
		humanoid.Health = 100
		root.AssemblyLinearVelocity = roblox.Vector3.new(10, 0, 0)
		local running = self:new("Sound", "Running", root); running.Volume = 0.65
		return model, root, humanoid, running
	end
	function h:countPlaying(key)
		local n = 0
		for _, play in self.played do if key == nil or play.sound.Name == "Bastiao_" .. key then n += 1 end end
		return n
	end
	return h
end
return Harness
