-- Synthware Auto-Loader
if not isfolder then pcall(function() makefolder("Synthware") end) end
if not isfolder("Synthware") then pcall(function() makefolder("Synthware") end) end
local p = "Synthware/compiled.lua"
if not isfile(p) then
 local c = [==[ + -- Synthware Compiled
print('[Synthware] Loading...')
local ok, err = pcall(function()
do
local moduleCache = {}

local function defineMod(name, fn)
	moduleCache[name] = fn
end

local function require(path)
	local mod = moduleCache[path]
	if mod then
		if type(mod) == 'function' then
			moduleCache[path] = mod()
		end
		return moduleCache[path]
	end
	error('Module not found: ' .. path)
end

-- lib/services.lua
defineMod('lib.services', function()
local cloneref = cloneref or function(obj) return obj end

return {
	Players = cloneref(game:GetService('Players')),
	RunService = cloneref(game:GetService('RunService')),
	UserInputService = cloneref(game:GetService('UserInputService')),
	CollectionService = cloneref(game:GetService('CollectionService')),
	ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage')),
	Workspace = cloneref(game:GetService('Workspace')),
	HttpService = cloneref(game:GetService('HttpService')),
	TweenService = cloneref(game:GetService('TweenService')),
	Debris = cloneref(game:GetService('Debris')),
	Lighting = cloneref(game:GetService('Lighting')),
	MarketplaceService = cloneref(game:GetService('MarketplaceService')),
	CoreGui = cloneref(game:GetService('CoreGui')),
	LocalPlayer = cloneref(game:GetService('Players').LocalPlayer),
	getCamera = function()
		return workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end
}

end)

-- lib/events.lua
defineMod('lib.events', function()
local Events = {}

Events.__index = function(self, index)
	local event = {Connections = {}}
	event.Connect = function(_, func)
		table.insert(event.Connections, func)
		return {
			Disconnect = function()
				local idx = table.find(event.Connections, func)
				if idx then table.remove(event.Connections, idx) end
			end
		}
	end
	event.Fire = function(_, ...)
		for _, v in event.Connections do
			task.spawn(v, ...)
		end
	end
	event.Destroy = function()
		table.clear(event.Connections)
	end
	rawset(self, index, event)
	return event
end

setmetatable(Events, Events)

return Events

end)

-- lib/entity.lua
defineMod('lib.entity', function()
local Svc = require('lib.services')
local Events = require('lib.events')
local Players = Svc.Players
local lplr = Svc.LocalPlayer
local camera = Svc.getCamera()

local entity = {
	isAlive = false,
	character = nil,
	List = {},
	PlayerConnections = {},
	EntityThreads = {},
	Running = false,
	Events = Events
}

local function loopClean(tbl)
	for i, v in tbl do
		if type(v) == 'table' then loopClean(v) end
		tbl[i] = nil
	end
end

local function waitForChildOfType(obj, name, timeout, isProp)
	local deadline = tick() + timeout
	repeat
		local found = isProp and obj[name] or obj:FindFirstChildOfClass(name)
		if found or deadline < tick() then return found end
		task.wait()
	until false
end

function entity:targetCheck(ent)
	if ent.TeamCheck then return ent:TeamCheck() end
	if ent.NPC then return true end
	if not ent.Player then return true end
	local myTeam = lplr:GetAttribute('Team')
	local theirTeam = ent.Player:GetAttribute('Team')
	if myTeam == nil or theirTeam == nil then return true end
	return myTeam ~= theirTeam
end

function entity:isVulnerable(ent)
	return ent.Health > 0 and ent.Character and not ent.Character:FindFirstChildWhichIsA('ForceField')
end

function entity:getEntityColor(ent)
	if ent.Friend then return Color3.fromRGB(0, 255, 127) end
	if ent.Player then
		local tc = ent.Player.TeamColor
		if tc and tostring(tc) ~= 'White' then return tc.Color end
	end
	return nil
end

local function getShieldHealth(char)
	local total = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			total += val
		end
	end
	return total
end

function entity:addEntity(char, plr, teamFunc)
	if not char then return end
	entity.EntityThreads[char] = task.spawn(function()
		local hum, rootPart, head
		if plr then
			hum = waitForChildOfType(char, 'Humanoid', 10)
			if not hum then entity.EntityThreads[char] = nil return end
			rootPart = hum and waitForChildOfType(hum, 'RootPart', 10, true)
			head = char:WaitForChild('Head', 5) or rootPart
		else
			hum = {HipHeight = 0.5, RigType = Enum.HumanoidRigType.R15}
			rootPart = waitForChildOfType(char, 'PrimaryPart', 5, true)
			head = rootPart
		end

		if not rootPart then entity.EntityThreads[char] = nil return end

		local ent = setmetatable({
			Connections = {},
			Character = char,
			Head = head,
			Humanoid = hum,
			HumanoidRootPart = rootPart,
			RootPart = rootPart,
			Player = plr,
			NPC = plr == nil,
			TeamCheck = teamFunc,
			Health = plr and (char:GetAttribute('Health') or hum.Health or 100) or 100,
			MaxHealth = plr and (char:GetAttribute('MaxHealth') or hum.MaxHealth or 100) or 100,
			HipHeight = hum.HipHeight + (rootPart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
		}, {__index = entity})

		if plr == lplr then
			entity.character = ent
			entity.isAlive = true
			entity.Events.LocalAdded:Fire(ent)
		else
			ent.Targetable = entity:targetCheck(ent)

			if plr then
				for _, attr in {'Health', 'MaxHealth'} do
					table.insert(ent.Connections, char:GetAttributeChangedSignal(attr):Connect(function()
						ent.Health = (char:GetAttribute('Health') or 100) + getShieldHealth(char)
						ent.MaxHealth = char:GetAttribute('MaxHealth') or 100
						entity.Events.EntityUpdated:Fire(ent)
					end))
				end
				for name, val in char:GetAttributes() do
					if name:find('Shield') and type(val) == 'number' then
						table.insert(ent.Connections, char:GetAttributeChangedSignal(name):Connect(function()
							ent.Health = (char:GetAttribute('Health') or 100) + getShieldHealth(char)
							entity.Events.EntityUpdated:Fire(ent)
						end))
					end
				end
			end

			table.insert(entity.List, ent)
			entity.Events.EntityAdded:Fire(ent)
		end

		table.insert(ent.Connections, char.AncestryChanged:Connect(function()
			if not char.Parent then entity:removeEntity(char, plr == lplr) end
		end))

		entity.EntityThreads[char] = nil
	end)
end

function entity:removeEntity(char, isLocal)
	if isLocal then
		if entity.isAlive then
			entity.isAlive = false
			for _, v in entity.character.Connections do v:Disconnect() end
			loopClean(entity.character.Connections)
			entity.Events.LocalRemoved:Fire(entity.character)
		end
		return
	end

	if not char then return end
	if entity.EntityThreads[char] then
		task.cancel(entity.EntityThreads[char])
		entity.EntityThreads[char] = nil
	end

	for i, v in entity.List do
		if v.Character == char or v.Player == char then
			for _, c in v.Connections do c:Disconnect() end
			loopClean(v.Connections)
			table.remove(entity.List, i)
			entity.Events.EntityRemoved:Fire(v)
			break
		end
	end
end

function entity:refreshEntity(char, plr)
	entity:removeEntity(char)
	entity:addEntity(char, plr)
end

function entity:addPlayer(plr)
	if plr == lplr then
		if plr.Character then entity:refreshEntity(plr.Character, plr) end
	else
		if plr.Character then entity:refreshEntity(plr.Character, plr) end
	end

	entity.PlayerConnections[plr] = {
		plr.CharacterAdded:Connect(function(char) entity:refreshEntity(char, plr) end),
		plr.CharacterRemoving:Connect(function(char) entity:removeEntity(char, plr == lplr) end),
		plr:GetAttributeChangedSignal('Team'):Connect(function()
			if plr == lplr then
				local cloned = table.clone(entity.List)
				for _, v in cloned do
					if v.Targetable ~= entity:targetCheck(v) then entity:refreshEntity(v.Character, v.Player) end
				end
			else
				for _, v in entity.List do
					if v.Player == plr then
						local new = entity:targetCheck(v)
						if v.Targetable ~= new then entity:refreshEntity(v.Character, v.Player) end
						break
					end
				end
			end
		end)
	}
end

function entity:removePlayer(plr)
	if entity.PlayerConnections[plr] then
		for _, c in entity.PlayerConnections[plr] do c:Disconnect() end
		loopClean(entity.PlayerConnections[plr])
		entity.PlayerConnections[plr] = nil
	end
	entity:removeEntity(plr)
end

function entity:start()
	if entity.Running then entity:stop() end

	entity.Connections = {
		Players.PlayerAdded:Connect(function(plr) entity:addPlayer(plr) end),
		Players.PlayerRemoving:Connect(function(plr) entity:removePlayer(plr) end),
		Svc.Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			camera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end)
	}

	for _, plr in Players:GetPlayers() do entity:addPlayer(plr) end

	entity.Running = true
end

function entity:stop()
	for _, c in entity.Connections do c:Disconnect() end
	for _, pc in entity.PlayerConnections do
		for _, c in pc do c:Disconnect() end
		loopClean(pc)
	end
	entity:removeEntity(nil, true)
	local cloned = table.clone(entity.List)
	for _, v in cloned do entity:removeEntity(v.Character) end
	for _, t in entity.EntityThreads do task.cancel(t) end
	loopClean(entity.PlayerConnections)
	loopClean(entity.EntityThreads)
	loopClean(entity.Connections)
	entity.Running = false
end

function entity:kill()
	if entity.Running then entity:stop() end
	loopClean(entity)
end

function entity:getTargets(opts)
	local targets = {}
	for _, ent in entity.List do
		if not ent.RootPart or not ent.Targetable then continue end
		if not entity:isVulnerable(ent) then continue end
		if opts.Players == false and ent.Player then continue end
		if opts.NPCs == false and ent.NPC then continue end
		local mag = (ent.RootPart.Position - entity.character.RootPart.Position).Magnitude
		if mag > opts.Range then continue end
		if opts.Wallcheck and entity:Wallcheck(entity.character.RootPart.Position, ent.RootPart.Position) then continue end
		table.insert(targets, {Entity = ent, Magnitude = mag})
	end
	if opts.Sort == 'Distance' then
		table.sort(targets, function(a, b) return a.Magnitude < b.Magnitude end)
	elseif opts.Sort == 'Health' then
		table.sort(targets, function(a, b) return a.Entity.Health < b.Entity.Health end)
	end
	if opts.Limit and #targets > opts.Limit then
		for i = #targets, opts.Limit + 1, -1 do targets[i] = nil end
	end
	return targets
end

function entity:Wallcheck(from, to)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {lplr.Character, Svc.Workspace.CurrentCamera}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	local ray = Svc.Workspace:Raycast(from, (to - from), params)
	return ray ~= nil
end

return entity

end)

-- lib/uilib.lua
defineMod('lib.uilib', function()
local Svc = require('lib.services')
local TweenService = Svc.TweenService

local UI = {
	Modules = {},
	Categories = {},
	Objects = {},
	Open = false,
	ScreenGui = nil,
	MainFrame = nil,
	SelectedTab = nil,
	TabButtons = {},
	TabFrames = {},
	ScrollFrames = {},
	ModuleButtons = {},
}

function UI:CreateCategory(name)
	local cat = {
		Name = name,
		Modules = {},
		Options = {},
		UI = self,
		TabButton = nil,
		TabFrame = nil,
		ScrollFrame = nil,
		ModuleButtons = {},
	}
	self.Categories[name] = cat
	return cat
end

function UI:GetCategory(name)
	return self.Categories[name]
end

function UI:CreateModule(catName, config)
	local cat = self.Categories[catName]
	if not cat then
		cat = self:CreateCategory(catName)
	end

	local mod = {
		Name = config.Name,
		Category = cat,
		Enabled = false,
		Settings = {},
		Connections = {},
		Clean = {},
		UI = self,
		Object = nil,
		Function = config.Function or function() end,
		Tooltip = config.Tooltip or '',
		ExtraText = config.ExtraText or nil,
	}

	local function getSetting(name)
		for _, s in mod.Settings do
			if s.Name == name then return s end
		end
		return nil
	end

	function mod:Toggle()
		self.Enabled = not self.Enabled
		if self.Enabled then
			task.spawn(function()
				self.Function(true)
			end)
		else
			self.Function(false)
			for _, c in self.Connections do
				pcall(c.Disconnect, c)
			end
			table.clear(self.Connections)
			for _, v in self.Clean do
				pcall(v)
			end
			table.clear(self.Clean)
		end
		if self.UI and self.UI.UpdateModule then
			self.UI:UpdateModule(self)
		end
	end

	function mod:CreateToggle(sconfig)
		local setting = {
			Type = 'Toggle',
			Name = sconfig.Name,
			Default = sconfig.Default ~= nil and sconfig.Default or false,
			Value = sconfig.Default ~= nil and sconfig.Default or false,
			Darker = sconfig.Darker or false,
			Visible = sconfig.Visible ~= nil and sconfig.Visible or true,
			Tooltip = sconfig.Tooltip or '',
			Object = nil,
			Function = sconfig.Function or nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:CreateSlider(sconfig)
		local setting = {
			Type = 'Slider',
			Name = sconfig.Name,
			Min = sconfig.Min or 0,
			Max = sconfig.Max or 100,
			Default = sconfig.Default or 50,
			Value = sconfig.Default or 50,
			Decimal = sconfig.Decimal or 1,
			Suffix = sconfig.Suffix or '',
			Darker = sconfig.Darker or false,
			Visible = sconfig.Visible ~= nil and sconfig.Visible or true,
			Tooltip = sconfig.Tooltip or '',
			Object = nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:CreateTwoSlider(sconfig)
		local setting = {
			Type = 'TwoSlider',
			Name = sconfig.Name,
			Min = sconfig.Min or 0,
			Max = sconfig.Max or 100,
			DefaultMin = sconfig.DefaultMin or 0,
			DefaultMax = sconfig.DefaultMax or 50,
			Value = sconfig.DefaultMin or 0,
			Value2 = sconfig.DefaultMax or 50,
			Decimal = sconfig.Decimal or 1,
			Suffix = sconfig.Suffix or '',
			Darker = sconfig.Darker or false,
			Tooltip = sconfig.Tooltip or '',
			Object = nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:CreateDropdown(sconfig)
		local setting = {
			Type = 'Dropdown',
			Name = sconfig.Name,
			List = sconfig.List or {},
			Default = sconfig.Default or (sconfig.List and sconfig.List[1] or ''),
			Value = sconfig.Default or (sconfig.List and sconfig.List[1] or ''),
			Darker = sconfig.Darker or false,
			Visible = sconfig.Visible ~= nil and sconfig.Visible or true,
			Tooltip = sconfig.Tooltip or '',
			Object = nil,
			Function = sconfig.Function or nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:CreateTargets(sconfig)
		local setting = {
			Type = 'Targets',
			Name = 'Targets',
			Players = {Enabled = sconfig.Players ~= nil and sconfig.Players or true},
			NPCs = {Enabled = sconfig.NPCs ~= nil and sconfig.NPCs or true},
			Walls = {Enabled = false},
			Visible = true,
			Object = nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:CreateTextBox(sconfig)
		local setting = {
			Type = 'TextBox',
			Name = sconfig.Name,
			Default = sconfig.Default or '',
			Value = sconfig.Default or '',
			Placeholder = sconfig.Placeholder or '',
			Darker = sconfig.Darker or false,
			Visible = sconfig.Visible ~= nil and sconfig.Visible or true,
			Object = nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:CreateColorSlider(sconfig)
		local setting = {
			Type = 'ColorSlider',
			Name = sconfig.Name,
			DefaultHue = sconfig.DefaultHue or 0,
			DefaultSat = sconfig.DefaultSat or 1,
			DefaultValue = sconfig.DefaultValue or 1,
			DefaultOpacity = sconfig.DefaultOpacity or 1,
			Hue = sconfig.DefaultHue or 0,
			Sat = sconfig.DefaultSat or 1,
			Value = sconfig.DefaultValue or 1,
			Opacity = sconfig.DefaultOpacity or 1,
			Darker = sconfig.Darker or false,
			Visible = sconfig.Visible ~= nil and sconfig.Visible or false,
			Object = nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:CreateTextList(sconfig)
		local setting = {
			Type = 'TextList',
			Name = sconfig.Name,
			Default = sconfig.Default or {},
			ListEnabled = sconfig.Default or {},
			Visible = sconfig.Visible ~= nil and sconfig.Visible or false,
			Darker = sconfig.Darker or false,
			Tooltip = sconfig.Tooltip or '',
			Object = nil,
		}
		table.insert(mod.Settings, setting)
		return setting
	end

	function mod:Clean(func)
		table.insert(self.Clean, func)
	end

	table.insert(cat.Modules, mod)
	table.insert(self.Modules, mod)

	if self.UpdateModule then
		self:UpdateModule(mod)
	end
	if self.UpdateCategory then
		self:UpdateCategory(cat)
	end

	return mod
end

function UI:GetModule(name)
	for _, m in self.Modules do
		if m.Name == name then return m end
	end
	return nil
end

function UI:Build()
	local parent = (gethui and gethui()) or Svc.CoreGui

	self.ScreenGui = Instance.new('ScreenGui')
	self.ScreenGui.Name = 'Synthware'
	self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.Parent = parent

	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = 'rbxassetid://15318520749'
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = self.ScreenGui

	local main = Instance.new('Frame')
	main.Name = 'Main'
	main.Size = UDim2.new(0, 580, 0, 400)
	main.Position = UDim2.new(0.5, -290, 0.5, -200)
	main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	main.BorderSizePixel = 0
	main.Active = true
	main.Parent = self.ScreenGui
	self.MainFrame = main

	local topBar = Instance.new('Frame')
	topBar.Size = UDim2.new(1, 0, 0, 28)
	topBar.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
	topBar.BorderSizePixel = 0
	topBar.Parent = main

	local title = Instance.new('TextLabel')
	title.Size = UDim2.new(0, 120, 1, 0)
	title.Position = UDim2.new(0, 8, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = 'Synthware'
	title.TextColor3 = Color3.fromRGB(220, 220, 220)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = topBar

	local version = Instance.new('TextLabel')
	version.Size = UDim2.new(0, 50, 1, 0)
	version.Position = UDim2.new(0, 80, 0, 2)
	version.BackgroundTransparency = 1
	version.Text = 'v1.0'
	version.TextColor3 = Color3.fromRGB(100, 100, 100)
	version.Font = Enum.Font.SourceSans
	version.TextSize = 11
	version.TextXAlignment = Enum.TextXAlignment.Left
	version.Parent = topBar

	local close = Instance.new('TextButton')
	close.Size = UDim2.new(0, 20, 0, 20)
	close.Position = UDim2.new(1, -24, 0, 4)
	close.BackgroundTransparency = 1
	close.Text = 'X'
	close.TextColor3 = Color3.fromRGB(180, 60, 60)
	close.Font = Enum.Font.SourceSansBold
	close.TextSize = 14
	close.Parent = main
	close.MouseButton1Click:Connect(function() self:Close() end)

	local tabBar = Instance.new('Frame')
	tabBar.Size = UDim2.new(0, 120, 1, -28)
	tabBar.Position = UDim2.new(0, 0, 0, 28)
	tabBar.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
	tabBar.BorderSizePixel = 0
	tabBar.Parent = main

	local tabList = Instance.new('UIListLayout')
	tabList.Padding = UDim.new(0, 2)
	tabList.Parent = tabBar

	local contentBg = Instance.new('Frame')
	contentBg.Size = UDim2.new(1, -120, 1, -28)
	contentBg.Position = UDim2.new(0, 120, 0, 28)
	contentBg.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	contentBg.BorderSizePixel = 0
	contentBg.Parent = main

	local drag, dragStart, startPos
	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	topBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = false
		end
	end)
	self.ScreenGui.InputChanged:Connect(function(input)
		if not drag or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end)

	local yOff = 0
	for name, cat in self.Categories do
		local btn = Instance.new('TextButton')
		btn.Size = UDim2.new(1, -6, 0, 26)
		btn.Position = UDim2.new(0, 3, 0, yOff)
		btn.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
		btn.BorderSizePixel = 0
		btn.Text = '  ' .. name
		btn.TextColor3 = Color3.fromRGB(160, 160, 160)
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 14
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Parent = tabBar
		cat.TabButton = btn
		yOff += 28

		local scroll = Instance.new('ScrollingFrame')
		scroll.Size = UDim2.new(1, -8, 1, -8)
		scroll.Position = UDim2.new(0, 4, 0, 4)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 4
		scroll.ScrollBarImageColor3 = Color3.fromRGB(40, 40, 50)
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = contentBg
		scroll.Visible = false
		cat.ScrollFrame = scroll

		local list = Instance.new('UIListLayout')
		list.Padding = UDim.new(0, 2)
		list.Parent = scroll

		btn.MouseButton1Click:Connect(function()
			self:SelectTab(name)
		end)
	end

	if next(self.Categories) then
		for name in self.Categories do
			self:SelectTab(name)
			break
		end
	end

	for _, mod in self.Modules do
		self:BuildModuleUI(mod)
	end
end

function UI:SelectTab(name)
	if self.SelectedTab == name then return end
	self.SelectedTab = name
	for n, cat in self.Categories do
		local selected = n == name
		cat.TabButton.BackgroundColor3 = selected and Color3.fromRGB(35, 35, 45) or Color3.fromRGB(24, 24, 30)
		cat.TabButton.TextColor3 = selected and Color3.fromRGB(220, 220, 220) or Color3.fromRGB(160, 160, 160)
		if cat.ScrollFrame then
			cat.ScrollFrame.Visible = selected
		end
	end
end

function UI:BuildModuleUI(mod)
	local cat = mod.Category
	if not cat or not cat.ScrollFrame then return end
	local scroll = cat.ScrollFrame

	local frame = Instance.new('Frame')
	frame.Size = UDim2.new(1, -4, 0, 28)
	frame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = scroll
	mod.Object = frame

	local topBar = Instance.new('Frame')
	topBar.Size = UDim2.new(1, 0, 0, 28)
	topBar.BackgroundTransparency = 1
	topBar.BorderSizePixel = 0
	topBar.Parent = frame

	local label = Instance.new('TextLabel')
	label.Size = UDim2.new(1, -60, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = mod.Name
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.Font = Enum.Font.SourceSans
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = topBar

	if mod.ExtraText then
		local extra = Instance.new('TextLabel')
		extra.Size = UDim2.new(0, 40, 1, 0)
		extra.Position = UDim2.new(1, -100, 0, 0)
		extra.BackgroundTransparency = 1
		extra.Text = mod:ExtraText()
		extra.TextColor3 = Color3.fromRGB(120, 120, 120)
		extra.Font = Enum.Font.SourceSans
		extra.TextSize = 13
		extra.Parent = topBar

		table.insert(mod.Clean, mod:ExtraText and task.spawn(function()
			while mod and mod.Enabled do
				task.wait(0.5)
				if extra and extra.Parent then extra.Text = mod:ExtraText() end
			end
		end) or nil)
	end

	local toggleBtn = Instance.new('TextButton')
	toggleBtn.Size = UDim2.new(0, 44, 0, 18)
	toggleBtn.Position = UDim2.new(1, -52, 0.5, -9)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Text = ''
	toggleBtn.Parent = topBar

	local toggleInd = Instance.new('TextLabel')
	toggleInd.Size = UDim2.new(1, 0, 1, 0)
	toggleInd.BackgroundTransparency = 1
	toggleInd.Text = 'OFF'
	toggleInd.TextColor3 = Color3.fromRGB(180, 180, 180)
	toggleInd.Font = Enum.Font.SourceSansBold
	toggleInd.TextSize = 10
	toggleInd.Parent = toggleBtn

	toggleBtn.MouseButton1Click:Connect(function()
		mod:Toggle()
		toggleBtn.BackgroundColor3 = mod.Enabled and Color3.fromRGB(0, 160, 60) or Color3.fromRGB(60, 60, 70)
		toggleInd.Text = mod.Enabled and 'ON' or 'OFF'
		toggleInd.TextColor3 = mod.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
	end)

	local settingsFrame = Instance.new('Frame')
	settingsFrame.Size = UDim2.new(1, 0, 0, 0)
	settingsFrame.Position = UDim2.new(0, 0, 0, 28)
	settingsFrame.BackgroundTransparency = 1
	settingsFrame.BorderSizePixel = 0
	settingsFrame.Visible = false
	settingsFrame.Parent = frame

	local settingsList = Instance.new('UIListLayout')
	settingsList.Padding = UDim.new(0, 1)
	settingsList.Parent = settingsFrame

	local settingsOpen = false
	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			settingsOpen = not settingsOpen
			settingsFrame.Visible = settingsOpen
			local h = 28
			if settingsOpen then
				for _, child in settingsFrame:GetChildren() do
					if child:IsA('Frame') then
						h += child.Size.Y.Offset + 1
					end
				end
			end
			frame.Size = UDim2.new(1, -4, 0, 28 + (settingsOpen and h - 28 or 0))
		end
	end)

	for _, setting in mod.Settings do
		if setting.Type == 'Toggle' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.new(1, -8, 0, 24)
			sf.Position = UDim2.new(0, 4, 0, 0)
			sf.BackgroundColor3 = setting.Darker and Color3.fromRGB(22, 22, 28) or Color3.fromRGB(26, 26, 33)
			sf.BorderSizePixel = 0
			sf.Parent = settingsFrame
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.new(1, -50, 1, 0)
			lbl.Position = UDim2.new(0, 8, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
			lbl.Font = Enum.Font.SourceSans
			lbl.TextSize = 14
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local tbtn = Instance.new('TextButton')
			tbtn.Size = UDim2.new(0, 36, 0, 16)
			tbtn.Position = UDim2.new(1, -42, 0.5, -8)
			tbtn.BackgroundColor3 = setting.Value and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(55, 55, 65)
			tbtn.BorderSizePixel = 0
			tbtn.Text = ''
			tbtn.Parent = sf

			local tind = Instance.new('TextLabel')
			tind.Size = UDim2.new(1, 0, 1, 0)
			tind.BackgroundTransparency = 1
			tind.Text = setting.Value and 'ON' or 'OFF'
			tind.TextColor3 = Color3.fromRGB(200, 200, 200)
			tind.Font = Enum.Font.SourceSansBold
			tind.TextSize = 9
			tind.Parent = tbtn

			tbtn.MouseButton1Click:Connect(function()
				setting.Value = not setting.Value
				tbtn.BackgroundColor3 = setting.Value and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(55, 55, 65)
				tind.Text = setting.Value and 'ON' or 'OFF'
				if setting.Function then setting.Function(setting.Value) end
			end)
		elseif setting.Type == 'Slider' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.new(1, -8, 0, 28)
			sf.Position = UDim2.new(0, 4, 0, 0)
			sf.BackgroundColor3 = setting.Darker and Color3.fromRGB(22, 22, 28) or Color3.fromRGB(26, 26, 33)
			sf.BorderSizePixel = 0
			sf.Parent = settingsFrame
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.new(0, 100, 1, 0)
			lbl.Position = UDim2.new(0, 8, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
			lbl.Font = Enum.Font.SourceSans
			lbl.TextSize = 13
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local valLbl = Instance.new('TextLabel')
			valLbl.Size = UDim2.new(0, 50, 1, 0)
			valLbl.Position = UDim2.new(1, -56, 0, 0)
			valLbl.BackgroundTransparency = 1
			valLbl.Text = tostring(setting.Value) .. (type(setting.Suffix) == 'string' and ' ' .. setting.Suffix or '')
			valLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
			valLbl.Font = Enum.Font.SourceSans
			valLbl.TextSize = 12
			valLbl.Parent = sf

			local barBg = Instance.new('Frame')
			barBg.Size = UDim2.new(0, 80, 0, 4)
			barBg.Position = UDim2.new(1, -140, 0.5, -2)
			barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
			barBg.BorderSizePixel = 0
			barBg.Parent = sf

			local bar = Instance.new('Frame')
			bar.Size = UDim2.new((setting.Value - setting.Min) / (setting.Max - setting.Min), 0, 1, 0)
			bar.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
			bar.BorderSizePixel = 0
			bar.Parent = barBg

			local function updateSlider(input)
				local pos = input.Position.X - barBg.AbsolutePosition.X
				local frac = math.clamp(pos / barBg.AbsoluteSize.X, 0, 1)
				local val = setting.Min + frac * (setting.Max - setting.Min)
				if setting.Decimal > 0 then
					val = math.floor(val * setting.Decimal + 0.5) / setting.Decimal
				else
					val = math.floor(val + 0.5)
				end
				setting.Value = val
				bar.Size = UDim2.new(frac, 0, 1, 0)
				local sfx = type(setting.Suffix) == 'function' and setting.Suffix(val) or setting.Suffix
				valLbl.Text = tostring(val) .. (sfx ~= '' and ' ' .. sfx or '')
			end

			barBg.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					updateSlider(input)
					local conn
					conn = barBg.InputChanged:Connect(function(ci)
						if ci.UserInputType == Enum.UserInputType.MouseMovement then
							updateSlider(ci)
						end
					end)
					local conn2
					conn2 = barBg.InputEnded:Connect(function(ci)
						if ci.UserInputType == Enum.UserInputType.MouseButton1 then
							conn:Disconnect()
							conn2:Disconnect()
						end
					end)
				end
			end)
		elseif setting.Type == 'TwoSlider' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.new(1, -8, 0, 28)
			sf.Position = UDim2.new(0, 4, 0, 0)
			sf.BackgroundColor3 = setting.Darker and Color3.fromRGB(22, 22, 28) or Color3.fromRGB(26, 26, 33)
			sf.BorderSizePixel = 0
			sf.Parent = settingsFrame
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.new(0, 90, 1, 0)
			lbl.Position = UDim2.new(0, 8, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
			lbl.Font = Enum.Font.SourceSans
			lbl.TextSize = 13
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local valLbl = Instance.new('TextLabel')
			valLbl.Size = UDim2.new(0, 50, 1, 0)
			valLbl.Position = UDim2.new(1, -56, 0, 0)
			valLbl.BackgroundTransparency = 1
			valLbl.Text = tostring(setting.Value) .. '-' .. tostring(setting.Value2) .. (type(setting.Suffix) == 'string' and ' ' .. setting.Suffix or '')
			valLbl.TextColor3 = Color3.fromRGB(140, 140, 140)
			valLbl.Font = Enum.Font.SourceSans
			valLbl.TextSize = 12
			valLbl.Parent = sf
		elseif setting.Type == 'Dropdown' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.new(1, -8, 0, 24)
			sf.Position = UDim2.new(0, 4, 0, 0)
			sf.BackgroundColor3 = setting.Darker and Color3.fromRGB(22, 22, 28) or Color3.fromRGB(26, 26, 33)
			sf.BorderSizePixel = 0
			sf.Parent = settingsFrame
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.new(0, 100, 1, 0)
			lbl.Position = UDim2.new(0, 8, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
			lbl.Font = Enum.Font.SourceSans
			lbl.TextSize = 13
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local dropdown = Instance.new('TextButton')
			dropdown.Size = UDim2.new(0, 80, 0, 20)
			dropdown.Position = UDim2.new(1, -86, 0.5, -10)
			dropdown.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
			dropdown.BorderSizePixel = 0
			dropdown.Text = setting.Value
			dropdown.TextColor3 = Color3.fromRGB(200, 200, 200)
			dropdown.Font = Enum.Font.SourceSans
			dropdown.TextSize = 12
			dropdown.Parent = sf

			local idx = 1
			dropdown.MouseButton1Click:Connect(function()
				idx = idx % #setting.List + 1
				setting.Value = setting.List[idx]
				dropdown.Text = setting.Value
				if setting.Function then setting.Function(setting.Value) end
			end)
		elseif setting.Type == 'Targets' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.new(1, -8, 0, 50)
			sf.Position = UDim2.new(0, 4, 0, 0)
			sf.BackgroundColor3 = Color3.fromRGB(26, 26, 33)
			sf.BorderSizePixel = 0
			sf.Parent = settingsFrame
			setting.Object = sf

			local y = 2
			for name, tbl in {Players = setting.Players, NPCs = setting.NPCs, Walls = setting.Walls} do
				local lbl = Instance.new('TextLabel')
				lbl.Size = UDim2.new(0, 60, 0, 20)
				lbl.Position = UDim2.new(0, 6, 0, y)
				lbl.BackgroundTransparency = 1
				lbl.Text = name
				lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
				lbl.Font = Enum.Font.SourceSans
				lbl.TextSize = 13
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = sf

				local tbtn = Instance.new('TextButton')
				tbtn.Size = UDim2.new(0, 36, 0, 16)
				tbtn.Position = UDim2.new(1, -44, 0, y + 2)
				tbtn.BackgroundColor3 = tbl.Enabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(55, 55, 65)
				tbtn.BorderSizePixel = 0
				tbtn.Text = ''
				tbtn.Parent = sf

				local tind = Instance.new('TextLabel')
				tind.Size = UDim2.new(1, 0, 1, 0)
				tind.BackgroundTransparency = 1
				tind.Text = tbl.Enabled and 'ON' or 'OFF'
				tind.TextColor3 = Color3.fromRGB(200, 200, 200)
				tind.Font = Enum.Font.SourceSansBold
				tind.TextSize = 9
				tind.Parent = tbtn

				tbtn.MouseButton1Click:Connect(function()
					tbl.Enabled = not tbl.Enabled
					tbtn.BackgroundColor3 = tbl.Enabled and Color3.fromRGB(0, 150, 50) or Color3.fromRGB(55, 55, 65)
					tind.Text = tbl.Enabled and 'ON' or 'OFF'
				end)
				y += 22
			end
		end
	end

	if #mod.Settings == 0 then
		frame.Size = UDim2.new(1, -4, 0, 28)
	end
end

function UI:UpdateModule(mod)
	if not mod.Object then return end
	local toggleBtn = mod.Object:FindFirstChildOfClass('Frame')
	if toggleBtn then
		local topBar = toggleBtn:FindFirstChildOfClass('Frame')
		if topBar then
			local tbtn = topBar:FindFirstChildOfClass('TextButton')
			if tbtn then
				local tind = tbtn:FindFirstChildOfClass('TextLabel')
				if tind then
					tbtn.BackgroundColor3 = mod.Enabled and Color3.fromRGB(0, 160, 60) or Color3.fromRGB(60, 60, 70)
					tind.Text = mod.Enabled and 'ON' or 'OFF'
					tind.TextColor3 = mod.Enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
				end
			end
		end
	end
end

function UI:Open()
	if self.Open then return end
	self.Open = true
	self:Build()
end

function UI:Close()
	self.Open = false
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
	self.MainFrame = nil
	for _, mod in self.Modules do
		if mod.Enabled then
			mod:Toggle()
		end
	end
end

function UI:Toggle()
	if self.Open then self:Close() else self:Open() end
end

return UI

end)

-- features/killaura.lua
defineMod('features.killaura', function()
local Svc = require('lib.services')
local entity = require('lib.entity')

return function(UI, store)
	local Killaura = UI:CreateModule('Blatant', {
		Name = 'Killaura',
		Tooltip = 'Attack players around you\nwithout aiming at them.',
	})

	local Targets = Killaura:CreateTargets({Players = true, NPCs = true})

	local SwingRange = Killaura:CreateSlider({
		Name = 'Swing range', Min = 1, Max = 30, Default = 16, Suffix = 'studs',
	})

	local AttackRange = Killaura:CreateSlider({
		Name = 'Attack range', Min = 1, Max = 22, Default = 12.4, Decimal = 10, Suffix = 'studs',
	})

	local AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle', Min = 1, Max = 360, Default = 100, Suffix = 'deg',
	})

	local AirChance = Killaura:CreateSlider({
		Name = 'Air Hit Chance', Min = 0, Max = 100, Default = 75, Suffix = '%',
	})

	local SwingTime = Killaura:CreateSlider({
		Name = 'Swing time', Min = 0, Max = 1, Default = 0.05, Decimal = 100, Suffix = 'seconds',
	})

	local UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate', Min = 1, Max = 120, Default = 25, Suffix = 'hz',
	})

	local MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets', Min = 1, Max = 10, Default = 10,
	})

	local Mode = Killaura:CreateDropdown({
		Name = 'Attack Mode',
		List = {'Single', 'Multi', 'Switch'},
		Default = 'Switch',
		Tooltip = 'Single: one target | Multi: multiple at once | Switch: cycles targets',
		Function = function(val)
			pcall(function() MaxTargets.Object.Visible = val ~= 'Single' end)
		end,
	})

	local Sort = Killaura:CreateDropdown({
		Name = 'Target Mode', List = {'Distance', 'Health', 'Angle', 'Mouse'}, Default = 'Distance',
	})

	local GUI = Killaura:CreateToggle({
		Name = 'GUI check', Default = true, Tooltip = 'Disables while in shop/chest',
	})

	local Swing = Killaura:CreateToggle({
		Name = 'No Swing', Tooltip = 'Disables swing animation',
	})

	local Limit = Killaura:CreateToggle({
		Name = 'Limit items', Default = true, Tooltip = 'Sword only',
	})

	Killaura.Function = function(callback)
		if callback then
			repeat task.wait() until entity.isAlive

			local bw = shared.Synthware and shared.Synthware.Bedwars
			if not bw or not bw.NetClient then
				repeat
					task.wait(1)
					bw = shared.Synthware and shared.Synthware.Bedwars
				until bw and bw.NetClient
			end

			local AttackRemote
			local ok, rem = pcall(function()
				return bw.NetClient:Get('AttackEntity')
			end)
			if ok and rem and rem.instance then
				AttackRemote = rem.instance
			end
			if not AttackRemote then return end

			local swingCooldown, switchCooldown, lastSwing, targetIndex = tick(), tick(), 0, 0

			repeat
				if not entity.isAlive then task.wait() continue end

				if GUI.Enabled and bw.AppController and bw.AppController.isLayerOpen then
					local ok2 = pcall(bw.AppController.isLayerOpen, bw.AppController, 1)
					if ok2 then task.wait(1 / UpdateRate.Value) continue end
				end

				local sword, meta
				if Limit.Enabled then
					sword = store.hand.tool
					if sword then
						meta = bw.ItemMeta and bw.ItemMeta[sword.Name]
						if meta and not meta.sword then
							sword = nil; meta = nil
						end
					end
				else
					sword = store.tools and store.tools.sword and store.tools.sword.tool
					if sword then
						meta = bw.ItemMeta and bw.ItemMeta[sword.Name]
					end
				end

				if not sword or not meta then task.wait(1 / UpdateRate.Value) continue end

				local plrs = entity:getTargets({
					Range = SwingRange.Value,
					Players = Targets.Players.Enabled,
					NPCs = Targets.NPCs.Enabled,
					Sort = Sort.Value,
					Limit = Mode.Value == 'Single' and 1 or MaxTargets.Value,
				})

				if #plrs == 0 then task.wait(1 / UpdateRate.Value) continue end

				local selfpos = entity.character.RootPart.Position
				local localfacing = entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

				if tick() > switchCooldown and Mode.Value == 'Switch' then
					switchCooldown = tick() + 0.7
					targetIndex += 1
				end
				if not plrs[targetIndex] then targetIndex = 1 end

				for i, v in plrs do
					if Mode.Value == 'Switch' and i ~= targetIndex then continue end

					local delta = (v.Entity.RootPart.Position - selfpos)
					local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
					if angle > (math.rad(AngleSlider.Value) / 2) then continue end

					if not Swing.Enabled and tick() > lastSwing + math.max(SwingTime.Value, 0.02) then
						lastSwing = tick()
						pcall(function() bw.SwordController:playSwordEffect(meta, false) end)
					end

					if delta.Magnitude > AttackRange.Value then continue end

					local actualRoot = v.Entity.Character.PrimaryPart
					if not actualRoot then continue end

					if v.Entity.Humanoid.FloorMaterial == Enum.Material.Air then
						if AirChance.Value < 100 and math.random(1, 100) >= AirChance.Value then continue end
					end

					if tick() - swingCooldown < math.max(SwingTime.Value, 0.02) then continue end
					swingCooldown = tick()

					local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
					local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)

					AttackRemote:FireServer({
						weapon = sword,
						chargedAttack = {chargeRatio = 0},
						lastSwingServerTimeDelta = 0.5,
						entityInstance = v.Entity.Character,
						validate = {
							raycast = {
								cameraPosition = {value = pos},
								cursorDirection = {value = dir},
							},
							targetPosition = {value = actualRoot.Position},
							selfPosition = {value = pos},
						},
					})

					if Mode.Value ~= 'Multi' then break end
				end

				task.wait(1 / UpdateRate.Value)
			until not Killaura.Enabled
		end
	end

	return Killaura
end

end)

-- features/esp.lua
defineMod('features.esp', function()
local Svc = require('lib.services')
local entity = require('lib.entity')
local camera = Svc.getCamera

return function(UI)
	local ESP = UI:CreateModule('Render', {
		Name = 'ESP',
		Tooltip = 'Shows players through walls',
		Function = function(callback)
			if callback then
				for _, v in entity.List do ESP:Add(v) end
				ESP.Connections[#ESP.Connections + 1] = entity.Events.EntityAdded:Connect(function(ent) ESP:Add(ent) end)
				ESP.Connections[#ESP.Connections + 1] = entity.Events.EntityRemoved:Connect(function(ent) ESP:Remove(ent) end)
				ESP.Connections[#ESP.Connections + 1] = Svc.RunService.RenderStepped:Connect(function() ESP:UpdateLoop() end)
			else
				for _, d in ESP.Reference do
					for _, v in d do pcall(function() v:Remove() end) end
				end
				table.clear(ESP.Reference)
				for _, c in ESP.Connections do c:Disconnect() end
				table.clear(ESP.Connections)
			end
		end,
	})

	ESP.Enabled = false
	ESP.ShowBox = true
	ESP.ShowHealth = true
	ESP.ShowName = true
	ESP.ShowTracers = false
	ESP.TeamCheck = true
	ESP.Reference = {}
	ESP.Connections = {}
	ESP.frame = 0

	local ShowBox = ESP:CreateToggle({Name = 'Box', Default = true, Function = function(val) ESP.ShowBox = val end})
	local ShowHealth = ESP:CreateToggle({Name = 'Health', Default = true, Function = function(val) ESP.ShowHealth = val end})
	local ShowName = ESP:CreateToggle({Name = 'Name', Default = true, Function = function(val) ESP.ShowName = val end})
	local ShowTracers = ESP:CreateToggle({Name = 'Tracers', Function = function(val) ESP.ShowTracers = val end})
	local TeamCheckT = ESP:CreateToggle({Name = 'Team Check', Default = true, Function = function(val) ESP.TeamCheck = val end})

	function ESP:Add(ent)
		if not ESP.Enabled then return end
		if ent.Player and ent.Player == Svc.LocalPlayer then return end

		local draw = {}

		draw.Box = Drawing.new('Square')
		draw.Box.Thickness = 1; draw.Box.Filled = false; draw.Box.ZIndex = 2
		draw.Box.Color = entity:getEntityColor(ent) or Color3.fromRGB(255, 255, 255)

		draw.BoxBorder = Drawing.new('Square')
		draw.BoxBorder.Thickness = 1; draw.BoxBorder.Filled = false; draw.BoxBorder.ZIndex = 1
		draw.BoxBorder.Color = Color3.new(0, 0, 0); draw.BoxBorder.Transparency = 0.35

		draw.BoxFill = Drawing.new('Square')
		draw.BoxFill.Thickness = 1; draw.BoxFill.Filled = true; draw.BoxFill.ZIndex = 1
		draw.BoxFill.Color = Color3.new(0, 0, 0); draw.BoxFill.Transparency = 0.25

		draw.HealthBar = Drawing.new('Line')
		draw.HealthBar.Thickness = 2; draw.HealthBar.ZIndex = 4

		draw.HealthBg = Drawing.new('Line')
		draw.HealthBg.Thickness = 4; draw.HealthBg.ZIndex = 3
		draw.HealthBg.Color = Color3.new(0, 0, 0); draw.HealthBg.Transparency = 0.35

		draw.Name = Drawing.new('Text')
		draw.Name.Size = 16; draw.Name.Center = true; draw.Name.ZIndex = 4; draw.Name.Outline = true
		draw.Name.Color = Color3.fromRGB(255, 255, 255)
		draw.Name.Text = ent.Player and ent.Player.Name or ent.Character.Name

		draw.NameBg = Drawing.new('Square')
		draw.NameBg.Thickness = 1; draw.NameBg.Filled = true; draw.NameBg.ZIndex = 3
		draw.NameBg.Color = Color3.new(0, 0, 0); draw.NameBg.Transparency = 0.35

		draw.Tracer = Drawing.new('Line')
		draw.Tracer.Thickness = 1; draw.Tracer.ZIndex = 3; draw.Tracer.Color = draw.Box.Color

		ESP.Reference[ent] = draw
	end

	function ESP:Remove(ent)
		local draw = ESP.Reference[ent]
		if draw then
			ESP.Reference[ent] = nil
			for _, v in draw do pcall(function() v.Visible = false; v:Remove() end) end
		end
	end

	function ESP:UpdateLoop()
		ESP.frame += 1
		if ESP.frame % 2 ~= 0 then return end

		local viewport = camera().ViewportSize
		local tracerOrigin = Vector2.new(viewport.X / 2, viewport.Y)

		for ent, draw in ESP.Reference do
			if not ent.RootPart or not ent.RootPart.Parent then ESP:Remove(ent) continue end

			if ESP.TeamCheck and not ent.Targetable and not ent.Friend then
				draw.Box.Visible = false; draw.BoxBorder.Visible = false; draw.BoxFill.Visible = false
				draw.HealthBar.Visible = false; draw.HealthBg.Visible = false
				draw.Name.Visible = false; draw.NameBg.Visible = false; draw.Tracer.Visible = false
				continue
			end

			local rootPos, vis = camera():WorldToViewportPoint(ent.RootPart.Position)
			if not vis then
				draw.Box.Visible = false; draw.BoxBorder.Visible = false; draw.BoxFill.Visible = false
				draw.HealthBar.Visible = false; draw.HealthBg.Visible = false
				draw.Name.Visible = false; draw.NameBg.Visible = false
				if ESP.ShowTracers then
					draw.Tracer.Visible = true
					draw.Tracer.From = tracerOrigin
					draw.Tracer.To = Vector2.new(rootPos.X, math.clamp(rootPos.Y, 0, viewport.Y))
				else
					draw.Tracer.Visible = false
				end
				continue
			end

			local lookVec = camera().CFrame.LookVector
			local topW = (CFrame.lookAlong(ent.RootPart.Position, lookVec) * CFrame.new(2, ent.HipHeight, 0)).p
			local botW = (CFrame.lookAlong(ent.RootPart.Position, lookVec) * CFrame.new(-2, -ent.HipHeight - 1, 0)).p
			local topV, _ = camera():WorldToViewportPoint(topW)
			local botV, _ = camera():WorldToViewportPoint(botW)
			local sizex = topV.X - botV.X; local sizey = topV.Y - botV.Y
			local posx = rootPos.X - sizex / 2; local posy = rootPos.Y - sizey / 2

			draw.Box.Position = Vector2.new(posx, posy) // 1; draw.Box.Size = Vector2.new(sizex, sizey) // 1; draw.Box.Visible = ESP.ShowBox
			draw.BoxBorder.Position = Vector2.new(posx - 1, posy + 1) // 1; draw.BoxBorder.Size = Vector2.new(sizex + 2, sizey - 2) // 1; draw.BoxBorder.Visible = ESP.ShowBox
			draw.BoxFill.Position = Vector2.new(posx + 1, posy - 1) // 1; draw.BoxFill.Size = Vector2.new(sizex - 2, sizey + 2) // 1; draw.BoxFill.Visible = ESP.ShowBox

			if ESP.ShowHealth then
				local healthFrac = math.clamp(ent.Health / math.max(ent.MaxHealth, 1), 0, 1)
				local healthY = posy + (sizey - (sizey * healthFrac))
				draw.HealthBar.From = Vector2.new(posx - 7, healthY) // 1; draw.HealthBar.To = Vector2.new(posx - 7, posy) // 1
				draw.HealthBar.Color = Color3.fromHSV(healthFrac / 2.8, 0.9, 0.8)
				draw.HealthBar.Visible = true
				draw.HealthBg.From = Vector2.new(posx - 7, posy + 1) // 1; draw.HealthBg.To = Vector2.new(posx - 7, posy + sizey - 1) // 1
				draw.HealthBg.Visible = true
			else
				draw.HealthBar.Visible = false; draw.HealthBg.Visible = false
			end

			if ESP.ShowName then
				draw.Name.Position = Vector2.new(posx + sizex / 2, posy + sizey - 24) // 1
				local bounds = draw.Name.TextBounds
				draw.NameBg.Size = bounds + Vector2.new(8, 4)
				draw.NameBg.Position = Vector2.new(posx + sizex / 2 - bounds.X / 2 - 4, posy + sizey - 26) // 1
				draw.Name.Visible = true; draw.NameBg.Visible = true
			else
				draw.Name.Visible = false; draw.NameBg.Visible = false
			end

			if ESP.ShowTracers then
				draw.Tracer.From = tracerOrigin; draw.Tracer.To = Vector2.new(rootPos.X, rootPos.Y); draw.Tracer.Visible = true
			else
				draw.Tracer.Visible = false
			end
		end
	end

	return ESP
end

end)

-- features/sprint.lua
defineMod('features.sprint', function()
local Svc = require('lib.services')
local entity = require('lib.entity')

return function(UI)
	return UI:CreateModule('Blatant', {
		Name = 'Sprint',
		Tooltip = 'Keeps you sprinting at all times',
		Function = function(callback)
			if callback then
				repeat task.wait() until entity.isAlive
				local Knit = debug.getupvalue(require(Svc.LocalPlayer.PlayerScripts.TS.knit).setup, 6)
				if not Knit then return end
				local SC = Knit.Controllers.SprintController
				if not SC then return end
				Sprint.oldStop = SC.stopSprinting
				SC.stopSprinting = function(...)
					local ret = Sprint.oldStop(...)
					SC:startSprinting()
					return ret
				end
				Sprint.connection = entity.Events.LocalAdded:Connect(function()
					task.delay(0.1, function() SC:stopSprinting() end)
				end)
				SC:stopSprinting()
			else
				if Sprint.oldStop then
					local Knit = debug.getupvalue(require(Svc.LocalPlayer.PlayerScripts.TS.knit).setup, 6)
					if Knit and Knit.Controllers.SprintController then
						Knit.Controllers.SprintController.stopSprinting = Sprint.oldStop
					end
					Sprint.oldStop = nil
				end
				if Sprint.connection then Sprint.connection:Disconnect() Sprint.connection = nil end
			end
		end,
	})
end

end)

-- main.lua
repeat task.wait() until game:IsLoaded()

if shared.Synthware then
	pcall(function() shared.Synthware:Unload() end)
end

local S = {}
shared.Synthware = S

local Svc = require('lib.services')
local entity = require('lib.entity')
local UI = require('lib.uilib')

S.Services = Svc
S.Entity = entity
S.UI = UI

local notifications = {}
local notifyDraw = Drawing.new('Text')
notifyDraw.Size = 18; notifyDraw.Center = true; notifyDraw.Outline = true
notifyDraw.Color = Color3.fromRGB(255, 255, 255)

function S:notify(text, dur)
	dur = dur or 3
	local nt = {Text = text, Start = tick(), Duration = dur}
	table.insert(notifications, nt)
	task.delay(dur, function()
		for i, v in notifications do if v == nt then table.remove(notifications, i) break end end
	end)
end

Svc.RunService.RenderStepped:Connect(function()
	if #notifications == 0 then notifyDraw.Visible = false return end
	local n = notifications[#notifications]
	local a = math.clamp(1 - (tick() - n.Start) / n.Duration, 0, 1)
	notifyDraw.Transparency = 1 - a
	notifyDraw.Position = Vector2.new(Svc.getCamera().ViewportSize.X / 2, 40)
	notifyDraw.Text = n.Text; notifyDraw.Visible = true
end)

Svc.UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.RightShift then
		UI:Toggle()
	end
end)

UI:CreateCategory('Blatant')
UI:CreateCategory('Combat')
UI:CreateCategory('Render')
UI:CreateCategory('World')
UI:CreateCategory('Utility')

S.Features = {}

local store = {
	hand = {tool = nil, toolType = nil},
	tools = {sword = nil},
	inventory = {inventory = {items = {}}, hotbar = {}},
}
shared.Synthware.Store = store

require('features.killaura')(UI, store)
require('features.esp')(UI)
require('features.sprint')(UI)

S:notify('Synthware loaded | RightShift GUI', 5)

Svc.RunService.Heartbeat:Wait()
entity:start()

local rs = Svc.ReplicatedStorage

local function initBedwars()
	local ok, KnitMod = pcall(function()
		return require(Svc.LocalPlayer.PlayerScripts.TS.knit)
	end)
	if not ok then return false end

	local KnitClient
	ok, KnitClient = pcall(function()
		return KnitMod.Client or debug.getupvalue(KnitMod.setup, 6)
	end)
	if not ok or not KnitClient then return false end

	if not debug.getupvalue(KnitClient.Start, 1) then
		repeat task.wait() until debug.getupvalue(KnitClient.Start, 1)
	end

	local C = KnitClient.Controllers
	local bw = {
		Knit = KnitClient,
		Controllers = C,
		SwordController = C.SwordController,
		AppController = C.AppController,
		HandController = C.HandController,
	}

	local ok2, NC = pcall(function()
		return require(rs.TS.remotes).default.Client
	end)
	if ok2 then bw.NetClient = NC end

	local ok3, IM = pcall(function()
		return require(rs.TS.item['item-meta']).ItemMeta
	end)
	if ok3 then bw.ItemMeta = IM end

	if not bw.ItemMeta then
		local ok4, IM2 = pcall(function()
			return require(rs.TS.games.bedwars['bedwars-shop']).ItemMeta
		end)
		if ok4 then bw.ItemMeta = IM2 end
	end

	if C.HandController then
		local function updateHand()
			local item = C.HandController:getItem()
			local tool = item and typeof(item) == 'table' and item.tool or item
			store.hand.tool = tool
			store.hand.toolType = tool and bw.ItemMeta and bw.ItemMeta[tool.Name] and (bw.ItemMeta[tool.Name].sword and 'sword' or nil) or nil
		end
		updateHand()
		C.HandController:GetAttributeChangedSignal('Item'):Connect(updateHand)
		if C.HandController.Changed then
			C.HandController.Changed:Connect(updateHand)
		end
	end

	shared.Synthware.Bedwars = bw
	S.Bedwars = bw
	return true
end

task.spawn(function()
	task.wait(1)
	initBedwars()
end)

S.Unload = function()
	for _, mod in UI.Modules do
		if mod.Enabled then mod:Toggle() end
	end
	if UI.Open then UI:Close() end
	entity:kill()
	table.clear(notifications)
	shared.Synthware = nil
end

return S


end end)
if not ok then warn('[Synthware] Error:', err) end
 + "]==]
 if isfile and writefile then
  writefile(p, c)
 end
end
if isfile and readfile then
 local c = readfile(p)
 if c then loadstring(c)() end
end