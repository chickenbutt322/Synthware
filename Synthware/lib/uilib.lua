local Svc = require(script.Parent.services)
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
