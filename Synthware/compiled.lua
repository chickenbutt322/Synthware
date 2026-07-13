-- Synthware Compiled
print("[Synthware] Loading...")

local moduleCache = {}

local function defineMod(name, fn)
	moduleCache[name] = fn
end

local function require(path)
	local mod = moduleCache[path]
	if mod then
		if type(mod) == "function" then
			moduleCache[path] = mod()
		end
		return moduleCache[path]
	end
	error("Module not found: " .. path)
end

-- lib.services.lua
defineMod("lib.services", function()
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

-- lib.events.lua
defineMod("lib.events", function()
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

-- lib.entity.lua
defineMod("lib.entity", function()
local Svc = require("lib.services")
local Events = require("lib.events")
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

-- lib.uilib.lua
defineMod("lib.uilib", function()
local Svc = require("lib.services")
local TS = Svc.TweenService
local IS = Svc.UserInputService

local palette = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Darker = Color3.fromRGB(22, 21, 23),
	Accent = Color3.fromHSV(0.46, 0.96, 0.52),
	SliderBg = Color3.fromRGB(42, 41, 44),
	Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear),
}

local asset = {
	blur = 'rbxassetid://14898786664',
	close = 'rbxassetid://14368309446',
	dots = 'rbxassetid://14368314459',
	expandup = 'rbxassetid://14368317595',
	guivape = 'rbxassetid://14657521312',
	guiv4 = 'rbxassetid://14368322199',
	guisettings = 'rbxassetid://14368318994',
	back = 'rbxassetid://14368303894',
	bind = 'rbxassetid://14368304734',
	bindbkg = 'rbxassetid://14368305655',
	blatant = 'rbxassetid://14368306745',
	combat = 'rbxassetid://14368312652',
	render = 'rbxassetid://14368350193',
	world = 'rbxassetid://14368362492',
	utility = 'rbxassetid://14368359107',
}

local function dark(c, amt)
	return Color3.fromRGB(math.floor(c.R * 255 * (1 - amt)), math.floor(c.G * 255 * (1 - amt)), math.floor(c.B * 255 * (1 - amt)))
end

local function light(c, amt)
	return Color3.fromRGB(math.min(255, math.floor(c.R * 255 + 255 * amt)), math.min(255, math.floor(c.G * 255 + 255 * amt)), math.min(255, math.floor(c.B * 255 + 255 * amt)))
end

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = asset.blur
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function addCorner(parent, radius)
	local c = Instance.new('UICorner')
	c.CornerRadius = radius or UDim.new(0, 5)
	c.Parent = parent
	return c
end

local function addCloseButton(parent, offset)
	local btn = Instance.new('ImageButton')
	btn.Name = 'Close'
	btn.Size = UDim2.fromOffset(24, 24)
	btn.Position = UDim2.new(1, -35, 0, offset or 9)
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Image = asset.close
	btn.ImageColor3 = light(palette.Text, 0.2)
	btn.ImageTransparency = 0.5
	btn.Parent = parent
	addCorner(btn, UDim.new(1, 0))
	btn.MouseEnter:Connect(function()
		btn.ImageTransparency = 0.3
	end)
	btn.MouseLeave:Connect(function()
		btn.ImageTransparency = 0.5
	end)
	return btn
end

local UI = {
	Modules = {},
	Categories = {},
	IsOpen = false,
	ScreenGui = nil,
	ClickGui = nil,
	Windows = {},
}

function UI:CreateCategory(name)
	local icons = {
		Blatant = asset.blatant,
		Combat = asset.combat,
		Render = asset.render,
		World = asset.world,
		Utility = asset.utility,
	}
	local cat = {
		Name = name,
		Modules = {},
		Window = nil,
		Icon = icons[name] or asset.blatant,
	}
	self.Categories[name] = cat
	table.insert(self.Categories, cat)
	return cat
end

function UI:GetCategory(name)
	return self.Categories[name]
end

function UI:CreateModule(catName, config)
	local cat = self.Categories[catName]
	if not cat then cat = self:CreateCategory(catName) end

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
		ExtraText = config.ExtraText,
	}

	function mod:Toggle()
		self.Enabled = not self.Enabled
		if self.Enabled then
			task.spawn(function() self.Function(true) end)
		else
			self.Function(false)
			for _, c in pairs(self.Connections) do pcall(c.Disconnect, c) end
			table.clear(self.Connections)
			for _, v in pairs(self.Clean) do pcall(v) end
			table.clear(self.Clean)
		end
	end

	function mod:CreateToggle(sconfig)
		local s = {Type='Toggle',Name=sconfig.Name,Default=sconfig.Default~=nil and sconfig.Default or false,Value=sconfig.Default~=nil and sconfig.Default or false,Darker=sconfig.Darker or false,Tooltip=sconfig.Tooltip or '',Object=nil,Function=sconfig.Function or nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:CreateSlider(sconfig)
		local s = {Type='Slider',Name=sconfig.Name,Min=sconfig.Min or 0,Max=sconfig.Max or 100,Default=sconfig.Default or 50,Value=sconfig.Default or 50,Decimal=sconfig.Decimal or 1,Suffix=sconfig.Suffix or '',Darker=sconfig.Darker or false,Tooltip=sconfig.Tooltip or '',Object=nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:CreateTwoSlider(sconfig)
		local s = {Type='TwoSlider',Name=sconfig.Name,Min=sconfig.Min or 0,Max=sconfig.Max or 100,DefaultMin=sconfig.DefaultMin or 0,DefaultMax=sconfig.DefaultMax or 50,Value=sconfig.DefaultMin or 0,Value2=sconfig.DefaultMax or 50,Decimal=sconfig.Decimal or 1,Suffix=sconfig.Suffix or '',Darker=sconfig.Darker or false,Tooltip=sconfig.Tooltip or '',Object=nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:CreateDropdown(sconfig)
		local s = {Type='Dropdown',Name=sconfig.Name,List=sconfig.List or {},Default=sconfig.Default or (sconfig.List and sconfig.List[1] or ''),Value=sconfig.Default or (sconfig.List and sconfig.List[1] or ''),Darker=sconfig.Darker or false,Tooltip=sconfig.Tooltip or '',Object=nil,Function=sconfig.Function or nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:CreateTargets(sconfig)
		local s = {Type='Targets',Name='Targets',Players={Enabled=sconfig.Players~=nil and sconfig.Players or true},NPCs={Enabled=sconfig.NPCs~=nil and sconfig.NPCs or true},Walls={Enabled=false},Visible=true,Object=nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:CreateTextBox(sconfig)
		local s = {Type='TextBox',Name=sconfig.Name,Default=sconfig.Default or '',Value=sconfig.Default or '',Placeholder=sconfig.Placeholder or '',Darker=sconfig.Darker or false,Visible=sconfig.Visible~=nil and sconfig.Visible or true,Object=nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:CreateColorSlider(sconfig)
		local s = {Type='ColorSlider',Name=sconfig.Name,DefaultHue=sconfig.DefaultHue or 0,DefaultSat=sconfig.DefaultSat or 1,DefaultValue=sconfig.DefaultValue or 1,DefaultOpacity=sconfig.DefaultOpacity or 1,Hue=sconfig.DefaultHue or 0,Sat=sconfig.DefaultSat or 1,Value=sconfig.DefaultValue or 1,Opacity=sconfig.DefaultOpacity or 1,Darker=sconfig.Darker or false,Visible=sconfig.Visible~=nil and sconfig.Visible or false,Object=nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:CreateTextList(sconfig)
		local s = {Type='TextList',Name=sconfig.Name,Default=sconfig.Default or {},ListEnabled=sconfig.Default or {},Visible=sconfig.Visible~=nil and sconfig.Visible or false,Darker=sconfig.Darker or false,Tooltip=sconfig.Tooltip or '',Object=nil}
		table.insert(mod.Settings, s); return s
	end

	function mod:Clean(func)
		table.insert(self.Clean, func)
	end

	table.insert(cat.Modules, mod)
	table.insert(self.Modules, mod)

	return mod
end

function UI:GetModule(name)
	for _, m in pairs(self.Modules) do if m.Name == name then return m end end
	return nil
end

local function makeDraggable(frame, window)
	local dragging, dragInput, startPos, startMouse
	frame.InputBegan:Connect(function(input)
		if window and not window.Visible then return end
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
			and (input.Position.Y - frame.AbsolutePosition.Y < 40 or window) then
			dragging = true
			startPos = frame.Position
			startMouse = input.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
	end)
	IS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - startMouse
			frame.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
		end
	end)
end

function UI:BuildCategoryWindow(cat, index)
	local window = Instance.new('TextButton')
	window.Name = cat.Name..'Category'
	window.Size = UDim2.fromOffset(220, 0)
	window.AutomaticSize = Enum.AutomaticSize.Y
	window.Position = UDim2.fromOffset(236 + (index - 1) * 10, 60 + (index - 1) * 10)
	window.BackgroundColor3 = palette.Main
	window.AutoButtonColor = false
	window.Text = ''
	window.Parent = self.ClickGui
	addBlur(window)
	addCorner(window)
	makeDraggable(window)
	cat.Window = window

	local icon = Instance.new('ImageLabel')
	icon.Name = 'Icon'
	icon.Size = UDim2.fromOffset(16, 16)
	icon.Position = UDim2.fromOffset(12, 12)
	icon.BackgroundTransparency = 1
	icon.Image = cat.Icon
	icon.ImageColor3 = palette.Text
	icon.Parent = window

	local title = Instance.new('TextLabel')
	title.Size = UDim2.new(1, -40, 0, 41)
	title.Position = UDim2.fromOffset(32, 0)
	title.BackgroundTransparency = 1
	title.Text = cat.Name
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = palette.Text
	title.TextSize = 13
	title.Font = Enum.Font.SourceSans
	title.Parent = window

	local divider = Instance.new('Frame')
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.fromOffset(0, 41)
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.928
	divider.BorderSizePixel = 0
	divider.Parent = window

	local content = Instance.new('Frame')
	content.Name = 'Content'
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, 42)
	content.Parent = window

	local list = Instance.new('UIListLayout')
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = content

	cat.Content = content
end

function UI:BuildModuleButton(mod)
	local cat = mod.Category
	local content = cat.Content
	if not content then return end

	local btn = Instance.new('TextButton')
	btn.Size = UDim2.fromOffset(220, 40)
	btn.BackgroundColor3 = palette.Main
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = '                         ' .. mod.Name
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.TextColor3 = dark(palette.Text, 0.16)
	btn.TextSize = 14
	btn.Font = Enum.Font.SourceSans
	btn.Parent = content
	mod.Object = btn

	btn.MouseEnter:Connect(function()
		if mod.Object then btn.BackgroundColor3 = dark(palette.Main, 0.02) end
	end)
	btn.MouseLeave:Connect(function()
		if mod.Object then btn.BackgroundColor3 = palette.Main end
	end)

	local toggleBg = Instance.new('TextButton')
	toggleBg.Size = UDim2.fromOffset(28, 14)
	toggleBg.Position = UDim2.new(1, -42, 0.5, -7)
	toggleBg.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
	toggleBg.BorderSizePixel = 0
	toggleBg.AutoButtonColor = false
	toggleBg.Text = ''
	toggleBg.Parent = btn
	addCorner(toggleBg, UDim.new(1, 0))

	local toggleKnob = Instance.new('Frame')
	toggleKnob.Size = UDim2.fromOffset(10, 10)
	toggleKnob.Position = UDim2.fromOffset(2, 2)
	toggleKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	toggleKnob.BorderSizePixel = 0
	toggleKnob.Parent = toggleBg
	addCorner(toggleKnob, UDim.new(1, 0))

	local function updateToggle()
		local on = mod.Enabled
		toggleBg.BackgroundColor3 = on and palette.Accent or Color3.fromRGB(55, 55, 60)
		toggleKnob.Position = on and UDim2.fromOffset(16, 2) or UDim2.fromOffset(2, 2)
	end

	toggleBg.MouseButton1Click:Connect(function()
		mod:Toggle()
		updateToggle()
	end)

	local dotsBtn = Instance.new('TextButton')
	dotsBtn.Name = 'Dots'
	dotsBtn.Size = UDim2.fromOffset(25, 40)
	dotsBtn.Position = UDim2.new(1, -25, 0, 0)
	dotsBtn.BackgroundTransparency = 1
	dotsBtn.Text = ''
	dotsBtn.Parent = btn

	local dots = Instance.new('ImageLabel')
	dots.Name = 'Dots'
	dots.Size = UDim2.fromOffset(3, 16)
	dots.Position = UDim2.fromOffset(11, 12)
	dots.BackgroundTransparency = 1
	dots.Image = asset.dots
	dots.ImageColor3 = light(palette.Main, 0.37)
	dots.Parent = dotsBtn

	local children = Instance.new('Frame')
	children.Name = mod.Name..'Children'
	children.Size = UDim2.new(1, 0, 0, 0)
	children.AutomaticSize = Enum.AutomaticSize.Y
	children.BackgroundColor3 = dark(palette.Main, 0.02)
	children.BorderSizePixel = 0
	children.Visible = false
	children.Parent = content
	mod.Children = children

	local childList = Instance.new('UIListLayout')
	childList.SortOrder = Enum.SortOrder.LayoutOrder
	childList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	childList.Parent = children

	local settingsOpen = false
	dotsBtn.MouseButton1Click:Connect(function()
		settingsOpen = not settingsOpen
		children.Visible = settingsOpen
	end)

	if #mod.Settings == 0 then dotsBtn.Visible = false end

	for _, setting in pairs(mod.Settings) do
		if setting.Type == 'Toggle' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 28)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.new(1, -40, 1, 0)
			lbl.Position = UDim2.fromOffset(10, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
			lbl.TextSize = 13
			lbl.Font = Enum.Font.SourceSans
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local tbg = Instance.new('TextButton')
			tbg.Size = UDim2.fromOffset(26, 13)
			tbg.Position = UDim2.new(1, -32, 0.5, -6.5)
			tbg.BackgroundColor3 = setting.Value and palette.Accent or Color3.fromRGB(55, 55, 60)
			tbg.BorderSizePixel = 0
			tbg.AutoButtonColor = false
			tbg.Text = ''
			tbg.Parent = sf
			addCorner(tbg, UDim.new(1, 0))

			local knob = Instance.new('Frame')
			knob.Size = UDim2.fromOffset(9, 9)
			knob.Position = setting.Value and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2)
			knob.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
			knob.BorderSizePixel = 0
			knob.Parent = tbg
			addCorner(knob, UDim.new(1, 0))

			tbg.MouseButton1Click:Connect(function()
				setting.Value = not setting.Value
				tbg.BackgroundColor3 = setting.Value and palette.Accent or Color3.fromRGB(55, 55, 60)
				knob.Position = setting.Value and UDim2.fromOffset(15, 2) or UDim2.fromOffset(2, 2)
				if setting.Function then setting.Function(setting.Value) end
			end)
		elseif setting.Type == 'Slider' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 32)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.fromOffset(100, 16)
			lbl.Position = UDim2.fromOffset(10, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
			lbl.TextSize = 13
			lbl.Font = Enum.Font.SourceSans
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local valLbl = Instance.new('TextLabel')
			valLbl.Size = UDim2.fromOffset(50, 16)
			valLbl.Position = UDim2.new(1, -54, 0, 0)
			valLbl.BackgroundTransparency = 1
			local sfx = type(setting.Suffix) == 'function' and setting.Suffix(setting.Value) or setting.Suffix
			valLbl.Text = tostring(setting.Value) .. (sfx ~= '' and ' ' .. sfx or '')
			valLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
			valLbl.TextSize = 12
			valLbl.Font = Enum.Font.SourceSans
			valLbl.TextXAlignment = Enum.TextXAlignment.Right
			valLbl.Parent = sf

			local barBg = Instance.new('Frame')
			barBg.Size = UDim2.new(1, -12, 0, 3)
			barBg.Position = UDim2.fromOffset(6, 22)
			barBg.BackgroundColor3 = palette.SliderBg
			barBg.BorderSizePixel = 0
			barBg.Parent = sf
			addCorner(barBg, UDim.new(1, 0))

			local bar = Instance.new('Frame')
			bar.Size = UDim2.new((setting.Value - setting.Min) / (setting.Max - setting.Min), 0, 1, 0)
			bar.BackgroundColor3 = palette.Accent
			bar.BorderSizePixel = 0
			bar.Parent = barBg
			addCorner(bar, UDim.new(1, 0))

			local dragging = false
			local function updateSlider(input)
				local pos = input.Position.X - barBg.AbsolutePosition.X
				local frac = math.clamp(pos / barBg.AbsoluteSize.X, 0, 1)
				local val = setting.Min + frac * (setting.Max - setting.Min)
				if setting.Decimal > 0 then val = math.floor(val * setting.Decimal + 0.5) / setting.Decimal
				else val = math.floor(val + 0.5) end
				setting.Value = val
				bar.Size = UDim2.new(frac, 0, 1, 0)
				local s = type(setting.Suffix) == 'function' and setting.Suffix(val) or setting.Suffix
				valLbl.Text = tostring(val) .. (s ~= '' and ' ' .. s or '')
			end

			barBg.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
					updateSlider(input)
				end
			end)
			barBg.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end)
			barBg.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					updateSlider(input)
				end
			end)
		elseif setting.Type == 'Dropdown' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 28)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.fromOffset(90, 28)
			lbl.Position = UDim2.fromOffset(10, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
			lbl.TextSize = 13
			lbl.Font = Enum.Font.SourceSans
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local dd = Instance.new('TextButton')
			dd.Size = UDim2.fromOffset(80, 20)
			dd.Position = UDim2.new(1, -86, 0.5, -10)
			dd.BackgroundColor3 = palette.SliderBg
			dd.BorderSizePixel = 0
			dd.AutoButtonColor = false
			dd.Text = setting.Value
			dd.TextColor3 = Color3.fromRGB(200, 200, 200)
			dd.TextSize = 12
			dd.Font = Enum.Font.SourceSans
			dd.Parent = sf
			addCorner(dd)

			local idx = 1
			for i, v in pairs(setting.List) do if v == setting.Value then idx = i break end end
			dd.MouseButton1Click:Connect(function()
				idx = idx % #setting.List + 1
				setting.Value = setting.List[idx]
				dd.Text = setting.Value
				if setting.Function then setting.Function(setting.Value) end
			end)
		elseif setting.Type == 'Targets' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 54)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local y = 3
			for name, tbl in pairs({Players = setting.Players, NPCs = setting.NPCs, Walls = setting.Walls}) do
				local lbl = Instance.new('TextLabel')
				lbl.Size = UDim2.fromOffset(60, 20)
				lbl.Position = UDim2.fromOffset(10, y)
				lbl.BackgroundTransparency = 1
				lbl.Text = name
				lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
				lbl.TextSize = 13
				lbl.Font = Enum.Font.SourceSans
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Parent = sf

				local tbg = Instance.new('TextButton')
				tbg.Size = UDim2.fromOffset(24, 12)
				tbg.Position = UDim2.new(1, -32, 0, y + 4)
				tbg.BackgroundColor3 = tbl.Enabled and palette.Accent or Color3.fromRGB(55, 55, 60)
				tbg.BorderSizePixel = 0
				tbg.AutoButtonColor = false
				tbg.Text = ''
				tbg.Parent = sf
				addCorner(tbg, UDim.new(1, 0))

				local knob = Instance.new('Frame')
				knob.Size = UDim2.fromOffset(8, 8)
				knob.Position = tbl.Enabled and UDim2.fromOffset(14, 2) or UDim2.fromOffset(2, 2)
				knob.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
				knob.BorderSizePixel = 0
				knob.Parent = tbg
				addCorner(knob, UDim.new(1, 0))

				tbg.MouseButton1Click:Connect(function()
					tbl.Enabled = not tbl.Enabled
					tbg.BackgroundColor3 = tbl.Enabled and palette.Accent or Color3.fromRGB(55, 55, 60)
					knob.Position = tbl.Enabled and UDim2.fromOffset(14, 2) or UDim2.fromOffset(2, 2)
				end)
				y = y + 22
			end
		elseif setting.Type == 'TwoSlider' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 32)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.fromOffset(90, 16)
			lbl.Position = UDim2.fromOffset(10, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
			lbl.TextSize = 13
			lbl.Font = Enum.Font.SourceSans
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local valLbl = Instance.new('TextLabel')
			valLbl.Size = UDim2.fromOffset(60, 16)
			valLbl.Position = UDim2.new(1, -64, 0, 0)
			valLbl.BackgroundTransparency = 1
			valLbl.Text = tostring(setting.Value) .. '-' .. tostring(setting.Value2) .. (type(setting.Suffix) == 'string' and ' ' .. setting.Suffix or '')
			valLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
			valLbl.TextSize = 12
			valLbl.Font = Enum.Font.SourceSans
			valLbl.TextXAlignment = Enum.TextXAlignment.Right
			valLbl.Parent = sf

			local barBg = Instance.new('Frame')
			barBg.Size = UDim2.new(1, -12, 0, 3)
			barBg.Position = UDim2.fromOffset(6, 22)
			barBg.BackgroundColor3 = palette.SliderBg
			barBg.BorderSizePixel = 0
			barBg.Parent = sf
			addCorner(barBg, UDim.new(1, 0))

			local fill = Instance.new('Frame')
			fill.Size = UDim2.new((setting.Value2 - setting.Value) / (setting.Max - setting.Min), 0, 1, 0)
			fill.Position = UDim2.new((setting.Value - setting.Min) / (setting.Max - setting.Min), 0, 0, 0)
			fill.BackgroundColor3 = palette.Accent
			fill.BorderSizePixel = 0
			fill.Parent = barBg
			addCorner(fill, UDim.new(1, 0))

			local function updateTwoSlider()
				local minFrac = (setting.Value - setting.Min) / (setting.Max - setting.Min)
				local maxFrac = (setting.Value2 - setting.Min) / (setting.Max - setting.Min)
				fill.Position = UDim2.new(minFrac, 0, 0, 0)
				fill.Size = UDim2.new(maxFrac - minFrac, 0, 1, 0)
				local sfx = type(setting.Suffix) == 'function' and setting.Suffix(setting.Value) or setting.Suffix
				valLbl.Text = tostring(setting.Value) .. '-' .. tostring(setting.Value2) .. (sfx ~= '' and ' ' .. sfx or '')
			end

			local dragging, dragMin
			barBg.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = true
					local pos = input.Position.X - barBg.AbsolutePosition.X
					local frac = pos / barBg.AbsoluteSize.X
					local midFrac = (setting.Value + setting.Value2) / 2 / (setting.Max - setting.Min)
					dragMin = frac < midFrac
					if dragMin then
						setting.Value = math.floor((setting.Min + frac * (setting.Max - setting.Min)) * setting.Decimal + 0.5) / setting.Decimal
					else
						setting.Value2 = math.floor((setting.Min + frac * (setting.Max - setting.Min)) * setting.Decimal + 0.5) / setting.Decimal
					end
					setting.Value = math.clamp(setting.Value, setting.Min, setting.Max)
					setting.Value2 = math.clamp(setting.Value2, setting.Min, setting.Max)
					updateTwoSlider()
				end
			end)
			barBg.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					dragging = false
				end
			end)
			barBg.InputChanged:Connect(function(input)
				if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
					local pos = input.Position.X - barBg.AbsolutePosition.X
					local frac = math.clamp(pos / barBg.AbsoluteSize.X, 0, 1)
					if dragMin then
						setting.Value = math.floor((setting.Min + frac * (setting.Max - setting.Min)) * setting.Decimal + 0.5) / setting.Decimal
						if setting.Value >= setting.Value2 then
							setting.Value = setting.Value2 - (1 / setting.Decimal)
						end
					else
						setting.Value2 = math.floor((setting.Min + frac * (setting.Max - setting.Min)) * setting.Decimal + 0.5) / setting.Decimal
						if setting.Value2 <= setting.Value then
							setting.Value2 = setting.Value + (1 / setting.Decimal)
						end
					end
					setting.Value = math.clamp(setting.Value, setting.Min, setting.Max)
					setting.Value2 = math.clamp(setting.Value2, setting.Min, setting.Max)
					updateTwoSlider()
				end
			end)
		elseif setting.Type == 'TextBox' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 28)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.fromOffset(90, 28)
			lbl.Position = UDim2.fromOffset(10, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
			lbl.TextSize = 13
			lbl.Font = Enum.Font.SourceSans
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local box = Instance.new('TextBox')
			box.Size = UDim2.fromOffset(80, 20)
			box.Position = UDim2.new(1, -86, 0.5, -10)
			box.BackgroundColor3 = palette.SliderBg
			box.BorderSizePixel = 0
			box.Text = setting.Value
			box.TextColor3 = Color3.fromRGB(200, 200, 200)
			box.TextSize = 12
			box.Font = Enum.Font.SourceSans
			box.TextXAlignment = Enum.TextXAlignment.Center
			box.ClearTextOnFocus = false
			box.Parent = sf
			addCorner(box)

			box.FocusLost:Connect(function(enter)
				if enter then
					setting.Value = box.Text
					if setting.Function then setting.Function(box.Text) end
				end
			end)
		elseif setting.Type == 'ColorSlider' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 28)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local preview = Instance.new('Frame')
			preview.Size = UDim2.fromOffset(14, 14)
			preview.Position = UDim2.fromOffset(10, 7)
			preview.BackgroundColor3 = Color3.fromHSV(setting.Hue, setting.Sat, setting.Value)
			preview.BorderSizePixel = 0
			preview.Parent = sf
			addCorner(preview, UDim.new(1, 0))

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.new(1, -70, 1, 0)
			lbl.Position = UDim2.fromOffset(30, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
			lbl.TextSize = 13
			lbl.Font = Enum.Font.SourceSans
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local hueBar = Instance.new('Frame')
			hueBar.Size = UDim2.new(1, -14, 0, 3)
			hueBar.Position = UDim2.fromOffset(7, 22)
			hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
			hueBar.BorderSizePixel = 0
			hueBar.Parent = sf
			addCorner(hueBar, UDim.new(1, 0))
			local hueGradient = Instance.new('UIGradient')
			hueGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
				ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
				ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
				ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
			})
			hueGradient.Parent = hueBar
		elseif setting.Type == 'TextList' then
			local sf = Instance.new('Frame')
			sf.Size = UDim2.fromOffset(220, 28)
			sf.BackgroundTransparency = 1
			sf.Parent = children
			setting.Object = sf

			local lbl = Instance.new('TextLabel')
			lbl.Size = UDim2.fromOffset(90, 28)
			lbl.Position = UDim2.fromOffset(10, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = setting.Name
			lbl.TextColor3 = Color3.fromRGB(170, 170, 170)
			lbl.TextSize = 13
			lbl.Font = Enum.Font.SourceSans
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = sf

			local countLbl = Instance.new('TextLabel')
			countLbl.Size = UDim2.fromOffset(60, 28)
			countLbl.Position = UDim2.new(1, -64, 0, 0)
			countLbl.BackgroundTransparency = 1
			countLbl.Text = tostring(#setting.List)
			countLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
			countLbl.TextSize = 12
			countLbl.Font = Enum.Font.SourceSans
			countLbl.TextXAlignment = Enum.TextXAlignment.Right
			countLbl.Parent = sf
		end
	end
end

function UI:BuildMainWindow()
	local parent = (gethui and gethui()) or Svc.CoreGui

	self.ScreenGui = Instance.new('ScreenGui')
	self.ScreenGui.Name = 'Synthware'
	self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.ScreenGui.ResetOnSpawn = false
	self.ScreenGui.Parent = parent

	local clickgui = Instance.new('Frame')
	clickgui.Name = 'ClickGui'
	clickgui.Size = UDim2.new(1, 0, 1, 0)
	clickgui.BackgroundTransparency = 1
	clickgui.Active = true
	clickgui.Parent = self.ScreenGui
	self.ClickGui = clickgui

	local main = Instance.new('TextButton')
	main.Name = 'MainWindow'
	main.Size = UDim2.fromOffset(220, 41)
	main.Position = UDim2.fromOffset(6, 60)
	main.BackgroundColor3 = dark(palette.Main, 0.02)
	main.AutoButtonColor = false
	main.Text = ''
	main.Parent = clickgui
	addBlur(main)
	addCorner(main)
	makeDraggable(main)

	local logo = Instance.new('ImageLabel')
	logo.Name = 'SynthwareLogo'
	logo.Size = UDim2.fromOffset(62, 18)
	logo.Position = UDim2.fromOffset(11, 11)
	logo.BackgroundTransparency = 1
	logo.Image = asset.guivape
	logo.ImageColor3 = palette.Text
	logo.Parent = main

	local logov4 = Instance.new('ImageLabel')
	logov4.Size = UDim2.fromOffset(28, 16)
	logov4.Position = UDim2.new(1, 1, 0, 1)
	logov4.BackgroundTransparency = 1
	logov4.Image = asset.guiv4
	logov4.Parent = logo

	local children = Instance.new('Frame')
	children.Name = 'Children'
	children.Size = UDim2.new(1, 0, 1, -33)
	children.Position = UDim2.fromOffset(0, 37)
	children.BackgroundTransparency = 1
	children.Parent = main

	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlist.Parent = children

	local catIdx = 0
	for _, cat in pairs(self.Categories) do
		catIdx += 1
		self:BuildCategoryWindow(cat, catIdx)
	end

	for _, mod in pairs(self.Modules) do
		self:BuildModuleButton(mod)
	end

	clickgui.Visible = false
end

function UI:Open()
	if self.IsOpen then return end
	self.IsOpen = true
	if not self.ScreenGui then self:BuildMainWindow() end
	self.ClickGui.Visible = true
end

function UI:Close()
	if not self.IsOpen then return end
	self.IsOpen = false
	if self.ClickGui then self.ClickGui.Visible = false end
end

function UI:Toggle()
	if self.IsOpen then self:Close() else self:Open() end
end

return UI


end)

-- features.killaura.lua
defineMod("features.killaura", function()
local Svc = require("lib.services")
local entity = require("lib.entity")

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
					local ok, opened = pcall(bw.AppController.isLayerOpen, bw.AppController, 1)
					if ok and opened then task.wait(1 / UpdateRate.Value) continue end
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
					sword = store.hand.tool
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

-- features.esp.lua
defineMod("features.esp", function()
local Svc = require("lib.services")
local entity = require("lib.entity")
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

-- features.sprint.lua
defineMod("features.sprint", function()
local Svc = require("lib.services")
local entity = require("lib.entity")

return function(UI)
	local SprintState = {}
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
				SprintState.oldStop = SC.stopSprinting
				SC.stopSprinting = function(...)
					local ret = SprintState.oldStop(...)
					SC:startSprinting()
					return ret
				end
				SprintState.connection = entity.Events.LocalAdded:Connect(function()
					task.delay(0.1, function() SC:stopSprinting() end)
				end)
				SC:stopSprinting()
			else
				if SprintState.oldStop then
					local Knit = debug.getupvalue(require(Svc.LocalPlayer.PlayerScripts.TS.knit).setup, 6)
					if Knit and Knit.Controllers.SprintController then
						Knit.Controllers.SprintController.stopSprinting = SprintState.oldStop
					end
					SprintState.oldStop = nil
				end
				if SprintState.connection then SprintState.connection:Disconnect() SprintState.connection = nil end
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

local Svc = require("lib.services")
local entity = require("lib.entity")
local UI = require("lib.uilib")

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

require("features.killaura")(UI, store)
require("features.esp")(UI)
require("features.sprint")(UI)

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
	if UI.IsOpen then UI:Close() end
	entity:kill()
	table.clear(notifications)
	shared.Synthware = nil
end

return S
