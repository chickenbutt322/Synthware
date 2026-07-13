local Svc = require(script.Parent.services)
local TS = Svc.TweenService
local IS = Svc.UserInputService
local TextSvc = Svc.TextService

local palette = {
	Main = Color3.fromRGB(26, 25, 26),
	Text = Color3.fromRGB(200, 200, 200),
	Font = Font.fromEnum(Enum.Font.Arial),
	FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold),
	Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear),
}

local asset = {
	blur = 'rbxassetid://14898786664',
	close = 'rbxassetid://14368309446',
	dots = 'rbxassetid://14368314459',
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
	expandright = 'rbxassetid://14368316544',
	expandicon = 'rbxassetid://14368353032',
	closeb = 'rbxassetid://14368310467',
	add = 'rbxassetid://14368300605',
	allowedicon = 'rbxassetid://14368302000',
	allowedtab = 'rbxassetid://14368302875',
	edit = 'rbxassetid://14368315443',
	colorpreview = 'rbxassetid://14368311578',
	rainbow_1 = 'rbxassetid://14368344374',
	rainbow_2 = 'rbxassetid://14368345149',
	rainbow_3 = 'rbxassetid://14368345840',
	rainbow_4 = 'rbxassetid://14368346696',
	range = 'rbxassetid://14368347435',
	rangearrow = 'rbxassetid://14368348640',
	targetstab = 'rbxassetid://14497393895',
	targetplayers1 = 'rbxassetid://14497396015',
	targetplayers2 = 'rbxassetid://14497397862',
	targetnpc1 = 'rbxassetid://14497400332',
	targetnpc2 = 'rbxassetid://14497402744',
}

local cloneref = cloneref or function(obj) return obj end
local guiService = cloneref(game:GetService('GuiService'))
local scale = {Scale = 1}

local fontsize = Instance.new('GetTextBoundsParams')
fontsize.Width = math.huge

local function getTextSize(text, size, font)
	fontsize.Text = text
	fontsize.Size = size
	if typeof(font) == 'Font' then
		fontsize.Font = font
	end
	return TextSvc:GetTextBoundsAsync(fontsize)
end

local tween = {tweens = {}, tweenstwo = {}}
function tween:Tween(obj, tweeninfo, goal, tab)
	tab = tab or self.tweens
	if tab[obj] then tab[obj]:Cancel(); tab[obj] = nil end
	if obj.Parent and obj.Visible then
		tab[obj] = TS:Create(obj, tweeninfo, goal)
		tab[obj].Completed:Once(function()
			if tab then tab[obj] = nil; tab = nil end
		end)
		tab[obj]:Play()
	else
		for i, v in goal do obj[i] = v end
	end
end
function tween:Cancel(obj)
	if self.tweens[obj] then self.tweens[obj]:Cancel(); self.tweens[obj] = nil end
end

local color = {}
function color.Dark(col, num)
	local h, s, v = col:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(select(3, palette.Main:ToHSV()) > 0.5 and v + num or v - num, 0, 1))
end
function color.Light(col, num)
	local h, s, v = col:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(select(3, palette.Main:ToHSV()) > 0.5 and v - num or v + num, 0, 1))
end

local function addBlur(parent, notif)
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
	btn.ImageColor3 = color.Light(palette.Text, 0.2)
	btn.ImageTransparency = 0.5
	btn.Parent = parent
	addCorner(btn, UDim.new(1, 0))
	btn.MouseEnter:Connect(function()
		btn.ImageTransparency = 0.3
		tween:Tween(btn, palette.Tween, {BackgroundTransparency = 0.6})
	end)
	btn.MouseLeave:Connect(function()
		btn.ImageTransparency = 0.5
		tween:Tween(btn, palette.Tween, {BackgroundTransparency = 1})
	end)
	return btn
end

local function addTooltip(guiObj, text)
	if not text then return end
	local tooltip, toolblur
	local parentGui = guiObj:FindFirstAncestorOfClass('ScreenGui')
	if not parentGui then return end
	toolblur = parentGui:FindFirstChild('TooltipBlur')
	if not toolblur then
		toolblur = Instance.new('ImageLabel')
		toolblur.Name = 'TooltipBlur'
		toolblur.Size = UDim2.fromOffset(0, 0)
		toolblur.BackgroundTransparency = 1
		toolblur.Image = asset.blur
		toolblur.ScaleType = Enum.ScaleType.Slice
		toolblur.SliceCenter = Rect.new(52, 31, 261, 502)
		toolblur.Visible = false
		toolblur.Parent = parentGui
	end
	tooltip = Instance.new('TextLabel')
	tooltip.Name = 'Tooltip'
	tooltip.Size = UDim2.fromOffset(0, 0)
	tooltip.BackgroundTransparency = 1
	tooltip.TextColor3 = palette.Text
	tooltip.TextSize = 12
	tooltip.FontFace = palette.Font
	tooltip.Visible = false
	tooltip.Parent = toolblur

	local function move(x, y)
		local right = x + 16 + tooltip.Size.X.Offset > (scale.Scale * 1920)
		toolblur.Position = UDim2.fromOffset(
			(right and x - (tooltip.Size.X.Offset * scale.Scale) - 16 or x + 16) / scale.Scale,
			((y + 11) - (tooltip.Size.Y.Offset / 2)) / scale.Scale
		)
		toolblur.Visible = true
	end
	guiObj.MouseEnter:Connect(function(x, y)
		local sz = getTextSize(text, tooltip.TextSize, palette.Font)
		tooltip.Size = UDim2.fromOffset(sz.X + 10, sz.Y + 10)
		tooltip.Text = text
		toolblur.Size = tooltip.Size
		move(x, y)
	end)
	guiObj.MouseMoved:Connect(move)
	guiObj.MouseLeave:Connect(function()
		toolblur.Visible = false
	end)
end

local function makeDraggable(guiObj, window)
	guiObj.InputBegan:Connect(function(inputObj)
		if window and not window.Visible then return end
		if (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
			and (inputObj.Position.Y - guiObj.AbsolutePosition.Y < 40 or window) then
			local dragPos = Vector2.new(
				guiObj.AbsolutePosition.X - inputObj.Position.X,
				guiObj.AbsolutePosition.Y - inputObj.Position.Y + guiService:GetGuiInset().Y
			) / scale.Scale
			local changed = IS.InputChanged:Connect(function(input)
				if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
					local pos = input.Position
					if IS:IsKeyDown(Enum.KeyCode.LeftShift) then
						dragPos = (dragPos // 3) * 3
						pos = (pos // 3) * 3
					end
					guiObj.Position = UDim2.fromOffset((pos.X / scale.Scale) + dragPos.X, (pos.Y / scale.Scale) + dragPos.Y)
				end
			end)
			local ended
			ended = inputObj.Changed:Connect(function()
				if inputObj.UserInputState == Enum.UserInputState.End then
					if changed then changed:Disconnect() end
					if ended then ended:Disconnect() end
				end
			end)
		end
	end)
end

local function getTableSize(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local UI = {
	Modules = {},
	Categories = {},
	IsOpen = false,
	ScreenGui = nil,
	ClickGui = nil,
	Windows = {},
	CategoryButtons = {},
	OpenCategory = nil,
	GUIColor = {
		Hue = 0.46,
		Sat = 0.96,
		Value = 0.52,
	},
}

function UI:Color(h)
	local s = 0.75 + (0.15 * math.min(h / 0.03, 1))
	if h > 0.57 then s = 0.9 - (0.4 * math.min((h - 0.57) / 0.09, 1)) end
	if h > 0.66 then s = 0.5 + (0.4 * math.min((h - 0.66) / 0.16, 1)) end
	if h > 0.87 then s = 0.9 - (0.15 * math.min((h - 0.87) / 0.13, 1)) end
	return h, s, 1
end

function UI:TextColor(h, s, v)
	if v >= 0.7 and (s < 0.6 or h > 0.04 and h < 0.56) then return Color3.new(0.19, 0.19, 0.19) end
	return Color3.new(1, 1, 1)
end

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
		Children = nil,
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
		local s = {Type='Toggle', Name=sconfig.Name, Default=sconfig.Default~=nil and sconfig.Default or false, Value=sconfig.Default~=nil and sconfig.Default or false, Darker=sconfig.Darker or false, Tooltip=sconfig.Tooltip or '', Object=nil, Function=sconfig.Function or nil}
		table.insert(mod.Settings, s); return s
	end
	function mod:CreateSlider(sconfig)
		local s = {Type='Slider', Name=sconfig.Name, Min=sconfig.Min or 0, Max=sconfig.Max or 100, Default=sconfig.Default or 50, Value=sconfig.Default or 50, Decimal=sconfig.Decimal or 1, Suffix=sconfig.Suffix or '', Darker=sconfig.Darker or false, Tooltip=sconfig.Tooltip or '', Object=nil}
		table.insert(mod.Settings, s); return s
	end
	function mod:CreateTwoSlider(sconfig)
		local s = {Type='TwoSlider', Name=sconfig.Name, Min=sconfig.Min or 0, Max=sconfig.Max or 100, DefaultMin=sconfig.DefaultMin or 0, DefaultMax=sconfig.DefaultMax or 50, Value=sconfig.DefaultMin or 0, Value2=sconfig.DefaultMax or 50, Decimal=sconfig.Decimal or 1, Suffix=sconfig.Suffix or '', Darker=sconfig.Darker or false, Tooltip=sconfig.Tooltip or '', Object=nil}
		table.insert(mod.Settings, s); return s
	end
	function mod:CreateDropdown(sconfig)
		local s = {Type='Dropdown', Name=sconfig.Name, List=sconfig.List or {}, Default=sconfig.Default or (sconfig.List and sconfig.List[1] or ''), Value=sconfig.Default or (sconfig.List and sconfig.List[1] or ''), Darker=sconfig.Darker or false, Tooltip=sconfig.Tooltip or '', Object=nil, Function=sconfig.Function or nil}
		table.insert(mod.Settings, s); return s
	end
	function mod:CreateTargets(sconfig)
		local s = {Type='Targets', Name='Targets', Players={Enabled=sconfig.Players~=nil and sconfig.Players or true}, NPCs={Enabled=sconfig.NPCs~=nil and sconfig.NPCs or true}, Walls={Enabled=false}, Invisible={Enabled=false}, Visible=true, Object=nil}
		table.insert(mod.Settings, s); return s
	end
	function mod:CreateTextBox(sconfig)
		local s = {Type='TextBox', Name=sconfig.Name, Default=sconfig.Default or '', Value=sconfig.Default or '', Placeholder=sconfig.Placeholder or '', Darker=sconfig.Darker or false, Visible=sconfig.Visible~=nil and sconfig.Visible or true, Object=nil, Function=sconfig.Function or nil}
		table.insert(mod.Settings, s); return s
	end
	function mod:CreateColorSlider(sconfig)
		local s = {Type='ColorSlider', Name=sconfig.Name, DefaultHue=sconfig.DefaultHue or 0, DefaultSat=sconfig.DefaultSat or 1, DefaultValue=sconfig.DefaultValue or 1, DefaultOpacity=sconfig.DefaultOpacity or 1, Hue=sconfig.DefaultHue or 0, Sat=sconfig.DefaultSat or 1, Value=sconfig.DefaultValue or 1, Opacity=sconfig.DefaultOpacity or 1, Darker=sconfig.Darker or false, Visible=sconfig.Visible~=nil and sconfig.Visible or false, Object=nil}
		table.insert(mod.Settings, s); return s
	end
	function mod:CreateTextList(sconfig)
		local s = {Type='TextList', Name=sconfig.Name, Default=sconfig.Default or {}, List=sconfig.Default or {}, ListEnabled=sconfig.Default or {}, Visible=sconfig.Visible~=nil and sconfig.Visible or false, Darker=sconfig.Darker or false, Tooltip=sconfig.Tooltip or '', Object=nil, Icon=sconfig.Icon or asset.allowedicon, Tab=sconfig.Tab or asset.allowedtab, TabSize=sconfig.TabSize or UDim2.fromOffset(19, 16), Placeholder=sconfig.Placeholder or 'Add entry...', Color=sconfig.Color or Color3.fromRGB(5, 134, 105)}
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
	for _, m in pairs(self.Modules) do
		if m.Name == name then return m end
	end
	return nil
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
	main.Size = UDim2.fromOffset(220, 0)
	main.AutomaticSize = Enum.AutomaticSize.Y
	main.Position = UDim2.fromOffset(6, 60)
	main.BackgroundColor3 = color.Dark(palette.Main, 0.02)
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
	window.Visible = false
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
	title.FontFace = palette.Font
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

	if not self.CategoryButtons[cat.Name] then
		local btn = Instance.new('TextButton')
		btn.Name = cat.Name
		btn.Size = UDim2.fromOffset(220, 40)
		btn.BackgroundColor3 = palette.Main
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = '                         ' .. cat.Name
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.TextColor3 = color.Dark(palette.Text, 0.16)
		btn.TextSize = 14
		btn.FontFace = palette.Font
		btn.Parent = self.ClickGui:FindFirstChild('MainWindow') and self.ClickGui.MainWindow.Children or nil
		self.CategoryButtons[cat.Name] = btn

		btn.MouseEnter:Connect(function()
			if not window.Visible then
				btn.BackgroundColor3 = color.Light(palette.Main, 0.02)
			end
		end)
		btn.MouseLeave:Connect(function()
			if not window.Visible then
				btn.BackgroundColor3 = palette.Main
			end
		end)
		btn.MouseButton1Click:Connect(function()
			window.Visible = not window.Visible
			btn.TextColor3 = window.Visible and Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value) or color.Dark(palette.Text, 0.16)
			btn.BackgroundColor3 = window.Visible and color.Light(palette.Main, 0.02) or palette.Main
		end)
	end
end

function UI:BuildModuleButton(mod)
	local cat = mod.Category
	local content = cat.Content
	if not content then return end
	local window = cat.Window

	local btn = Instance.new('TextButton')
	btn.Size = UDim2.fromOffset(220, 40)
	btn.BackgroundColor3 = palette.Main
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = '                         ' .. mod.Name
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.TextColor3 = color.Dark(palette.Text, 0.16)
	btn.TextSize = 14
	btn.FontFace = palette.Font
	btn.Parent = content
	mod.Object = btn
	addTooltip(btn, mod.Tooltip)

	btn.MouseEnter:Connect(function()
		if not mod.Enabled then
			tween:Tween(btn, palette.Tween, {BackgroundColor3 = color.Light(palette.Main, 0.02)})
		end
	end)
	btn.MouseLeave:Connect(function()
		if not mod.Enabled then
			tween:Tween(btn, palette.Tween, {BackgroundColor3 = palette.Main})
		end
	end)

	local knobholder = Instance.new('Frame')
	knobholder.Name = 'Knob'
	knobholder.Size = UDim2.fromOffset(22, 12)
	knobholder.Position = UDim2.new(1, -30, 0, 14)
	knobholder.BackgroundColor3 = color.Light(palette.Main, 0.14)
	knobholder.Parent = btn
	addCorner(knobholder, UDim.new(1, 0))

	local knob = knobholder:Clone()
	knob.Size = UDim2.fromOffset(8, 8)
	knob.Position = UDim2.fromOffset(2, 2)
	knob.BackgroundColor3 = palette.Main
	knob.Parent = knobholder

	local function updateToggle()
		if mod.Enabled then
			tween:Tween(knobholder, palette.Tween, {
				BackgroundColor3 = Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
			})
			tween:Tween(knob, palette.Tween, {
				Position = UDim2.fromOffset(12, 2)
			})
		else
			tween:Tween(knobholder, palette.Tween, {
				BackgroundColor3 = color.Light(palette.Main, 0.14)
			})
			tween:Tween(knob, palette.Tween, {
				Position = UDim2.fromOffset(2, 2)
			})
		end
	end

	btn.MouseButton1Click:Connect(function()
		mod:Toggle()
		updateToggle()
	end)

	local dotsBtn = Instance.new('TextButton')
	dotsBtn.Name = 'Dots'
	dotsBtn.Size = UDim2.fromOffset(25, 40)
	dotsBtn.Position = UDim2.new(1, -55, 0, 0)
	dotsBtn.BackgroundTransparency = 1
	dotsBtn.Text = ''
	dotsBtn.Parent = btn

	local dots = Instance.new('ImageLabel')
	dots.Name = 'Dots'
	dots.Size = UDim2.fromOffset(3, 16)
	dots.Position = UDim2.fromOffset(11, 12)
	dots.BackgroundTransparency = 1
	dots.Image = asset.dots
	dots.ImageColor3 = color.Light(palette.Main, 0.37)
	dots.Parent = dotsBtn

	local children = Instance.new('Frame')
	children.Name = mod.Name..'Children'
	children.Size = UDim2.new(1, 0, 0, 0)
	children.AutomaticSize = Enum.AutomaticSize.Y
	children.BackgroundColor3 = color.Dark(palette.Main, 0.02)
	children.BorderSizePixel = 0
	children.Visible = false
	children.Parent = content
	mod.Children = children

	local childList = Instance.new('UIListLayout')
	childList.SortOrder = Enum.SortOrder.LayoutOrder
	childList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	childList.Parent = children

	local settingsOpen = false
	if #mod.Settings == 0 then dotsBtn.Visible = false end
	dotsBtn.MouseButton1Click:Connect(function()
		settingsOpen = not settingsOpen
		children.Visible = settingsOpen
	end)

	for _, setting in pairs(mod.Settings) do
		if setting.Type == 'Toggle' then
			local hovered = false
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 30)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = '                         ' .. setting.Name
			sf.TextXAlignment = Enum.TextXAlignment.Left
			sf.TextColor3 = color.Dark(palette.Text, 0.16)
			sf.TextSize = 14
			sf.FontFace = palette.Font
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip)

			local sknobholder = Instance.new('Frame')
			sknobholder.Name = 'Knob'
			sknobholder.Size = UDim2.fromOffset(22, 12)
			sknobholder.Position = UDim2.new(1, -30, 0, 9)
			sknobholder.BackgroundColor3 = setting.Value and Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value) or color.Light(palette.Main, 0.14)
			sknobholder.Parent = sf
			addCorner(sknobholder, UDim.new(1, 0))

			local sknob = sknobholder:Clone()
			sknob.Size = UDim2.fromOffset(8, 8)
			sknob.Position = UDim2.fromOffset(setting.Value and 12 or 2, 2)
			sknob.BackgroundColor3 = palette.Main
			sknob.Parent = sknobholder

			sf.MouseEnter:Connect(function()
				hovered = true
				if not setting.Value then
					tween:Tween(sknobholder, palette.Tween, {BackgroundColor3 = color.Light(palette.Main, 0.37)})
				end
			end)
			sf.MouseLeave:Connect(function()
				hovered = false
				if not setting.Value then
					tween:Tween(sknobholder, palette.Tween, {BackgroundColor3 = color.Light(palette.Main, 0.14)})
				end
			end)
			sf.MouseButton1Click:Connect(function()
				setting.Value = not setting.Value
				tween:Tween(sknobholder, palette.Tween, {
					BackgroundColor3 = setting.Value and Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value) or (hovered and color.Light(palette.Main, 0.37) or color.Light(palette.Main, 0.14))
				})
				tween:Tween(sknob, palette.Tween, {
					Position = UDim2.fromOffset(setting.Value and 12 or 2, 2)
				})
				if setting.Function then setting.Function(setting.Value) end
			end)

		elseif setting.Type == 'Slider' then
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 50)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = ''
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip)

			local title = Instance.new('TextLabel')
			title.Name = 'Title'
			title.Size = UDim2.fromOffset(60, 30)
			title.Position = UDim2.fromOffset(10, 2)
			title.BackgroundTransparency = 1
			title.Text = setting.Name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = color.Dark(palette.Text, 0.16)
			title.TextSize = 11
			title.FontFace = palette.Font
			title.Parent = sf

			local valueBtn = Instance.new('TextButton')
			valueBtn.Name = 'Value'
			valueBtn.Size = UDim2.fromOffset(60, 15)
			valueBtn.Position = UDim2.new(1, -69, 0, 9)
			valueBtn.BackgroundTransparency = 1
			valueBtn.Text = setting.Value .. (type(setting.Suffix) == 'function' and ' ' .. setting.Suffix(setting.Value) or (setting.Suffix ~= '' and ' ' .. setting.Suffix or ''))
			valueBtn.TextXAlignment = Enum.TextXAlignment.Right
			valueBtn.TextColor3 = color.Dark(palette.Text, 0.16)
			valueBtn.TextSize = 11
			valueBtn.FontFace = palette.Font
			valueBtn.Parent = sf

			local valueBox = Instance.new('TextBox')
			valueBox.Name = 'Box'
			valueBox.Size = valueBtn.Size
			valueBox.Position = valueBtn.Position
			valueBox.BackgroundTransparency = 1
			valueBox.Visible = false
			valueBox.Text = setting.Value
			valueBox.TextXAlignment = Enum.TextXAlignment.Right
			valueBox.TextColor3 = color.Dark(palette.Text, 0.16)
			valueBox.TextSize = 11
			valueBox.FontFace = palette.Font
			valueBox.ClearTextOnFocus = false
			valueBox.Parent = sf

			local barBg = Instance.new('Frame')
			barBg.Name = 'Slider'
			barBg.Size = UDim2.new(1, -20, 0, 2)
			barBg.Position = UDim2.fromOffset(10, 37)
			barBg.BackgroundColor3 = color.Light(palette.Main, 0.034)
			barBg.BorderSizePixel = 0
			barBg.Parent = sf

			local fill = barBg:Clone()
			fill.Name = 'Fill'
			fill.Size = UDim2.fromScale(math.clamp((setting.Value - setting.Min) / setting.Max, 0.04, 0.96), 1)
			fill.Position = UDim2.new()
			fill.BackgroundColor3 = Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
			fill.Parent = barBg

			local knobholder = Instance.new('Frame')
			knobholder.Name = 'Knob'
			knobholder.Size = UDim2.fromOffset(24, 4)
			knobholder.Position = UDim2.fromScale(1, 0.5)
			knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
			knobholder.BackgroundColor3 = sf.BackgroundColor3
			knobholder.BorderSizePixel = 0
			knobholder.Parent = fill

			local knob = Instance.new('Frame')
			knob.Name = 'Knob'
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Position = UDim2.fromScale(0.5, 0.5)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
			knob.Parent = knobholder
			addCorner(knob, UDim.new(1, 0))

			sf.InputBegan:Connect(function(inputObj)
				if (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
					and (inputObj.Position.Y - sf.AbsolutePosition.Y) > (20 * scale.Scale) then
					local newPos = math.clamp((inputObj.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
					setting.Value = math.floor((setting.Min + (setting.Max - setting.Min) * newPos) * setting.Decimal) / setting.Decimal
					fill.Size = UDim2.fromScale(math.clamp(newPos, 0.04, 0.96), 1)
					valueBtn.Text = setting.Value .. (type(setting.Suffix) == 'function' and ' ' .. setting.Suffix(setting.Value) or (setting.Suffix ~= '' and ' ' .. setting.Suffix or ''))
					local lastVal = setting.Value
					local changed = IS.InputChanged:Connect(function(input)
						if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
							local p = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
							setting.Value = math.floor((setting.Min + (setting.Max - setting.Min) * p) * setting.Decimal) / setting.Decimal
							fill.Size = UDim2.fromScale(math.clamp(p, 0.04, 0.96), 1)
							valueBtn.Text = setting.Value .. (type(setting.Suffix) == 'function' and ' ' .. setting.Suffix(setting.Value) or (setting.Suffix ~= '' and ' ' .. setting.Suffix or ''))
							lastVal = setting.Value
						end
					end)
					local ended
					ended = inputObj.Changed:Connect(function()
						if inputObj.UserInputState == Enum.UserInputState.End then
							if changed then changed:Disconnect() end
							if ended then ended:Disconnect() end
						end
					end)
				end
			end)

			sf.MouseEnter:Connect(function()
				tween:Tween(knob, palette.Tween, {Size = UDim2.fromOffset(16, 16)})
			end)
			sf.MouseLeave:Connect(function()
				tween:Tween(knob, palette.Tween, {Size = UDim2.fromOffset(14, 14)})
			end)

			valueBtn.MouseButton1Click:Connect(function()
				valueBtn.Visible = false; valueBox.Visible = true
				valueBox.Text = setting.Value; valueBox:CaptureFocus()
			end)
			valueBox.FocusLost:Connect(function(enter)
				valueBtn.Visible = true; valueBox.Visible = false
				if enter and tonumber(valueBox.Text) then
					setting.Value = tonumber(valueBox.Text)
					local frac = math.clamp((setting.Value - setting.Min) / setting.Max, 0.04, 0.96)
					fill.Size = UDim2.fromScale(frac, 1)
					valueBtn.Text = setting.Value .. (type(setting.Suffix) == 'function' and ' ' .. setting.Suffix(setting.Value) or (setting.Suffix ~= '' and ' ' .. setting.Suffix or ''))
				end
			end)

		elseif setting.Type == 'Dropdown' then
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 40)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = ''
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip or setting.Name)

			local bkg = Instance.new('Frame')
			bkg.Name = 'BKG'
			bkg.Size = UDim2.new(1, -20, 1, -9)
			bkg.Position = UDim2.fromOffset(10, 4)
			bkg.BackgroundColor3 = color.Light(palette.Main, 0.034)
			bkg.Parent = sf
			addCorner(bkg, UDim.new(0, 6))

			local button = Instance.new('TextButton')
			button.Name = 'Dropdown'
			button.Size = UDim2.new(1, -2, 1, -2)
			button.Position = UDim2.fromOffset(1, 1)
			button.BackgroundColor3 = palette.Main
			button.AutoButtonColor = false
			button.Text = ''
			button.Parent = bkg

			local title = Instance.new('TextLabel')
			title.Size = UDim2.new(1, 0, 0, 29)
			title.BackgroundTransparency = 1
			title.Text = '                         ' .. setting.Name .. ' - ' .. setting.Value
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = color.Dark(palette.Text, 0.16)
			title.TextSize = 13
			title.TextTruncate = Enum.TextTruncate.AtEnd
			title.FontFace = palette.Font
			title.Parent = button
			addCorner(button, UDim.new(0, 6))

			local arrow = Instance.new('ImageLabel')
			arrow.Name = 'Arrow'
			arrow.Size = UDim2.fromOffset(4, 8)
			arrow.Position = UDim2.new(1, -17, 0, 11)
			arrow.BackgroundTransparency = 1
			arrow.Image = asset.expandright
			arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
			arrow.Rotation = 90
			arrow.Parent = button

			local dropdownChildren

			button.MouseButton1Click:Connect(function()
				if not dropdownChildren then
					arrow.Rotation = 270
					sf.Size = UDim2.new(1, 0, 0, 40 + (#setting.List - 1) * 26)
					dropdownChildren = Instance.new('Frame')
					dropdownChildren.Name = 'Children'
					dropdownChildren.Size = UDim2.new(1, 0, 0, (#setting.List - 1) * 26)
					dropdownChildren.Position = UDim2.fromOffset(0, 27)
					dropdownChildren.BackgroundTransparency = 1
					dropdownChildren.Parent = button
					local ind = 0
					for _, v in setting.List do
						if v == setting.Value then continue end
						local opt = Instance.new('TextButton')
						opt.Name = v .. 'Option'
						opt.Size = UDim2.new(1, 0, 0, 26)
						opt.Position = UDim2.fromOffset(0, ind * 26)
						opt.BackgroundColor3 = palette.Main
						opt.BorderSizePixel = 0
						opt.AutoButtonColor = false
						opt.Text = '                         ' .. v
						opt.TextXAlignment = Enum.TextXAlignment.Left
						opt.TextColor3 = color.Dark(palette.Text, 0.16)
						opt.TextSize = 13
						opt.TextTruncate = Enum.TextTruncate.AtEnd
						opt.FontFace = palette.Font
						opt.Parent = dropdownChildren
						opt.MouseEnter:Connect(function()
							tween:Tween(opt, palette.Tween, {BackgroundColor3 = color.Light(palette.Main, 0.02)})
						end)
						opt.MouseLeave:Connect(function()
							tween:Tween(opt, palette.Tween, {BackgroundColor3 = palette.Main})
						end)
						opt.MouseButton1Click:Connect(function()
							setting.Value = v
							title.Text = '                         ' .. setting.Name .. ' - ' .. setting.Value
							arrow.Rotation = 90
							dropdownChildren:Destroy()
							dropdownChildren = nil
							sf.Size = UDim2.new(1, 0, 0, 40)
							if setting.Function then setting.Function(v) end
						end)
						ind += 1
					end
				else
					arrow.Rotation = 90
					dropdownChildren:Destroy()
					dropdownChildren = nil
					sf.Size = UDim2.new(1, 0, 0, 40)
				end
			end)

			sf.MouseEnter:Connect(function()
				tween:Tween(bkg, palette.Tween, {BackgroundColor3 = color.Light(palette.Main, 0.0875)})
			end)
			sf.MouseLeave:Connect(function()
				tween:Tween(bkg, palette.Tween, {BackgroundColor3 = color.Light(palette.Main, 0.034)})
			end)

		elseif setting.Type == 'TwoSlider' then
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 50)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = ''
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip)

			local title = Instance.new('TextLabel')
			title.Size = UDim2.fromOffset(60, 30)
			title.Position = UDim2.fromOffset(10, 2)
			title.BackgroundTransparency = 1
			title.Text = setting.Name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = color.Dark(palette.Text, 0.16)
			title.TextSize = 11
			title.FontFace = palette.Font
			title.Parent = sf

			local valBtnMin = Instance.new('TextButton')
			valBtnMin.Size = UDim2.fromOffset(60, 15)
			valBtnMin.Position = UDim2.new(1, -133, 0, 9)
			valBtnMin.BackgroundTransparency = 1
			valBtnMin.Text = setting.Value
			valBtnMin.TextXAlignment = Enum.TextXAlignment.Right
			valBtnMin.TextColor3 = color.Dark(palette.Text, 0.16)
			valBtnMin.TextSize = 11
			valBtnMin.FontFace = palette.Font
			valBtnMin.Parent = sf

			local valBtnMax = Instance.new('TextButton')
			valBtnMax.Size = UDim2.fromOffset(60, 15)
			valBtnMax.Position = UDim2.new(1, -69, 0, 9)
			valBtnMax.BackgroundTransparency = 1
			valBtnMax.Text = setting.Value2
			valBtnMax.TextXAlignment = Enum.TextXAlignment.Right
			valBtnMax.TextColor3 = color.Dark(palette.Text, 0.16)
			valBtnMax.TextSize = 11
			valBtnMax.FontFace = palette.Font
			valBtnMax.Parent = sf

			local arrow = Instance.new('ImageLabel')
			arrow.Name = 'Arrow'
			arrow.Size = UDim2.fromOffset(12, 6)
			arrow.Position = UDim2.new(1, -56, 0, 10)
			arrow.BackgroundTransparency = 1
			arrow.Image = asset.rangearrow
			arrow.ImageColor3 = color.Light(palette.Main, 0.14)
			arrow.Parent = sf

			local barBg = Instance.new('Frame')
			barBg.Name = 'Slider'
			barBg.Size = UDim2.new(1, -20, 0, 2)
			barBg.Position = UDim2.fromOffset(10, 37)
			barBg.BackgroundColor3 = color.Light(palette.Main, 0.034)
			barBg.BorderSizePixel = 0
			barBg.Parent = sf

			local fill = barBg:Clone()
			fill.Name = 'Fill'
			fill.Position = UDim2.fromScale(math.clamp(setting.Value / setting.Max, 0.04, 0.96), 0)
			fill.Size = UDim2.fromScale(math.clamp(setting.Value2 / setting.Max, 0.04, 0.96) - fill.Position.X.Scale, 1)
			fill.BackgroundColor3 = Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
			fill.Parent = barBg

			local knobMin = Instance.new('Frame')
			knobMin.Name = 'Knob'
			knobMin.Size = UDim2.fromOffset(16, 4)
			knobMin.Position = UDim2.fromScale(0, 0.5)
			knobMin.AnchorPoint = Vector2.new(0.5, 0.5)
			knobMin.BackgroundColor3 = sf.BackgroundColor3
			knobMin.BorderSizePixel = 0
			knobMin.Parent = fill

			local knobIconMin = Instance.new('ImageLabel')
			knobIconMin.Name = 'Knob'
			knobIconMin.Size = UDim2.fromOffset(9, 16)
			knobIconMin.Position = UDim2.fromScale(0.5, 0.5)
			knobIconMin.AnchorPoint = Vector2.new(0.5, 0.5)
			knobIconMin.BackgroundTransparency = 1
			knobIconMin.Image = asset.range
			knobIconMin.ImageColor3 = Color3.fromHSV(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value)
			knobIconMin.Parent = knobMin

			local knobMax = knobMin:Clone()
			knobMax.Name = 'KnobMax'
			knobMax.Position = UDim2.fromScale(1, 0.5)
			knobMax.Parent = fill
			knobMax.Knob.Rotation = 180

			local dragging, isMax
			sf.InputBegan:Connect(function(inputObj)
				if (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
					and (inputObj.Position.Y - sf.AbsolutePosition.Y) > (20 * scale.Scale) then
					isMax = (inputObj.Position.X - knobMax.AbsolutePosition.X) > -10
					local newPos = math.clamp((inputObj.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
					local val = math.floor((setting.Min + (setting.Max - setting.Min) * newPos) * setting.Decimal) / setting.Decimal
					if isMax then setting.Value2 = val else setting.Value = val end
					setting.Value = math.clamp(setting.Value, setting.Min, setting.Value2)
					setting.Value2 = math.clamp(setting.Value2, setting.Value, setting.Max)
					local minFrac = math.clamp(setting.Value / setting.Max, 0.04, 0.96)
					local maxFrac = math.clamp(setting.Value2 / setting.Max, 0.04, 0.96)
					fill.Position = UDim2.fromScale(minFrac, 0)
					fill.Size = UDim2.fromScale(maxFrac - minFrac, 1)
					valBtnMin.Text = setting.Value; valBtnMax.Text = setting.Value2

					local changed = IS.InputChanged:Connect(function(input)
						if input.UserInputType == (inputObj.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
							local p = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
							local v = math.floor((setting.Min + (setting.Max - setting.Min) * p) * setting.Decimal) / setting.Decimal
							if isMax then setting.Value2 = v else setting.Value = v end
							setting.Value = math.clamp(setting.Value, setting.Min, setting.Value2)
							setting.Value2 = math.clamp(setting.Value2, setting.Value, setting.Max)
							local minF = math.clamp(setting.Value / setting.Max, 0.04, 0.96)
							local maxF = math.clamp(setting.Value2 / setting.Max, 0.04, 0.96)
							fill.Position = UDim2.fromScale(minF, 0)
							fill.Size = UDim2.fromScale(maxF - minF, 1)
							valBtnMin.Text = setting.Value; valBtnMax.Text = setting.Value2
						end
					end)
					local ended
					ended = inputObj.Changed:Connect(function()
						if inputObj.UserInputState == Enum.UserInputState.End then
							if changed then changed:Disconnect() end
							if ended then ended:Disconnect() end
						end
					end)
				end
			end)

		elseif setting.Type == 'TextBox' then
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 58)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = ''
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip)

			local title = Instance.new('TextLabel')
			title.Size = UDim2.new(1, -10, 0, 20)
			title.Position = UDim2.fromOffset(10, 3)
			title.BackgroundTransparency = 1
			title.Text = setting.Name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = palette.Text
			title.TextSize = 12
			title.FontFace = palette.Font
			title.Parent = sf

			local bkg = Instance.new('Frame')
			bkg.Name = 'BKG'
			bkg.Size = UDim2.new(1, -20, 0, 29)
			bkg.Position = UDim2.fromOffset(10, 23)
			bkg.BackgroundColor3 = color.Light(palette.Main, 0.02)
			bkg.Parent = sf
			addCorner(bkg, UDim.new(0, 4))

			local box = Instance.new('TextBox')
			box.Size = UDim2.new(1, -8, 1, 0)
			box.Position = UDim2.fromOffset(8, 0)
			box.BackgroundTransparency = 1
			box.Text = setting.Default or ''
			box.PlaceholderText = setting.Placeholder or 'Click to set'
			box.TextXAlignment = Enum.TextXAlignment.Left
			box.TextColor3 = color.Dark(palette.Text, 0.16)
			box.PlaceholderColor3 = color.Dark(palette.Text, 0.31)
			box.TextSize = 12
			box.FontFace = palette.Font
			box.ClearTextOnFocus = false
			box.Parent = bkg

			sf.MouseButton1Click:Connect(function() box:CaptureFocus() end)
			box.FocusLost:Connect(function(enter)
				if enter then
					setting.Value = box.Text
					if setting.Function then setting.Function() end
				end
			end)

		elseif setting.Type == 'ColorSlider' then
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 50)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = ''
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip)

			local title = Instance.new('TextLabel')
			title.Size = UDim2.fromOffset(60, 30)
			title.Position = UDim2.fromOffset(10, 2)
			title.BackgroundTransparency = 1
			title.Text = setting.Name
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextColor3 = color.Dark(palette.Text, 0.16)
			title.TextSize = 11
			title.FontFace = palette.Font
			title.Parent = sf

			local preview = Instance.new('ImageButton')
			preview.Name = 'Preview'
			preview.Size = UDim2.fromOffset(12, 12)
			preview.Position = UDim2.new(1, -22, 0, 10)
			preview.BackgroundTransparency = 1
			preview.Image = asset.colorpreview
			preview.ImageColor3 = Color3.fromHSV(setting.Hue, setting.Sat, setting.Value)
			preview.ImageTransparency = 1 - setting.Opacity
			preview.Parent = sf

			local barBg = Instance.new('Frame')
			barBg.Name = 'Slider'
			barBg.Size = UDim2.new(1, -20, 0, 2)
			barBg.Position = UDim2.fromOffset(10, 39)
			barBg.BackgroundColor3 = Color3.new(1, 1, 1)
			barBg.BorderSizePixel = 0
			barBg.Parent = sf

			local rainbowKeys = {}
			for i = 0, 1, 0.1 do table.insert(rainbowKeys, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1))) end
			local gradient = Instance.new('UIGradient')
			gradient.Color = ColorSequence.new(rainbowKeys)
			gradient.Parent = barBg

			local fill = barBg:Clone()
			fill.Name = 'Fill'
			fill.Size = UDim2.fromScale(math.clamp(setting.Hue, 0.04, 0.96), 1)
			fill.Position = UDim2.new()
			fill.BackgroundTransparency = 1
			fill.Parent = barBg

			local expandBtn = Instance.new('TextButton')
			expandBtn.Name = 'Expand'
			expandBtn.Size = UDim2.fromOffset(17, 13)
			expandBtn.Position = UDim2.new(0, getTextSize(title.Text, title.TextSize, title.Font).X + 11, 0, 7)
			expandBtn.BackgroundTransparency = 1
			expandBtn.Text = ''
			expandBtn.Parent = sf

			local expandIcon = Instance.new('ImageLabel')
			expandIcon.Size = UDim2.fromOffset(9, 5)
			expandIcon.Position = UDim2.fromOffset(4, 4)
			expandIcon.BackgroundTransparency = 1
			expandIcon.Image = asset.expandicon
			expandIcon.ImageColor3 = color.Dark(palette.Text, 0.43)
			expandIcon.Parent = expandBtn

			local rainbow = Instance.new('TextButton')
			rainbow.Name = 'Rainbow'
			rainbow.Size = UDim2.fromOffset(12, 12)
			rainbow.Position = UDim2.new(1, -42, 0, 10)
			rainbow.BackgroundTransparency = 1
			rainbow.Text = ''
			rainbow.Parent = sf

			local rb1 = Instance.new('ImageLabel')
			rb1.Size = UDim2.fromOffset(12, 12); rb1.BackgroundTransparency = 1
			rb1.Image = asset.rainbow_1; rb1.ImageColor3 = color.Light(palette.Main, 0.37); rb1.Parent = rainbow
			local rb2 = rb1:Clone(); rb2.Image = asset.rainbow_2; rb2.Parent = rainbow
			local rb3 = rb1:Clone(); rb3.Image = asset.rainbow_3; rb3.Parent = rainbow
			local rb4 = rb1:Clone(); rb4.Image = asset.rainbow_4; rb4.Parent = rainbow

			local knobholder = Instance.new('Frame')
			knobholder.Name = 'Knob'
			knobholder.Size = UDim2.fromOffset(24, 4)
			knobholder.Position = UDim2.fromScale(1, 0.5)
			knobholder.AnchorPoint = Vector2.new(0.5, 0.5)
			knobholder.BackgroundColor3 = sf.BackgroundColor3
			knobholder.BorderSizePixel = 0
			knobholder.Parent = fill

			local knob = Instance.new('Frame')
			knob.Name = 'Knob'
			knob.Size = UDim2.fromOffset(14, 14)
			knob.Position = UDim2.fromScale(0.5, 0.5)
			knob.AnchorPoint = Vector2.new(0.5, 0.5)
			knob.BackgroundColor3 = palette.Text
			knob.Parent = knobholder
			addCorner(knob, UDim.new(1, 0))

			local satSlider, vibSlider, opSlider
			local function createSubSlider(name, gradColors)
				local ss = Instance.new('TextButton')
				ss.Name = setting.Name .. 'Sub' .. name
				ss.Size = UDim2.new(1, 0, 0, 50)
				ss.BackgroundColor3 = color.Dark(sf.BackgroundColor3, 0.02)
				ss.BorderSizePixel = 0
				ss.AutoButtonColor = false
				ss.Visible = false
				ss.Text = ''
				ss.Parent = children

				local stitle = Instance.new('TextLabel')
				stitle.Size = UDim2.fromOffset(60, 30); stitle.Position = UDim2.fromOffset(10, 2)
				stitle.BackgroundTransparency = 1; stitle.Text = name
				stitle.TextXAlignment = Enum.TextXAlignment.Left
				stitle.TextColor3 = color.Dark(palette.Text, 0.16)
				stitle.TextSize = 11; stitle.FontFace = palette.Font; stitle.Parent = ss

				local sbar = Instance.new('Frame')
				sbar.Name = 'Slider'
				sbar.Size = UDim2.new(1, -20, 0, 2); sbar.Position = UDim2.fromOffset(10, 37)
				sbar.BackgroundColor3 = Color3.new(1, 1, 1); sbar.BorderSizePixel = 0; sbar.Parent = ss

				local sgrad = Instance.new('UIGradient')
				sgrad.Color = gradColors; sgrad.Parent = sbar

				local sfill = sbar:Clone()
				sfill.Name = 'Fill'
				sfill.Size = UDim2.fromScale(math.clamp(name == 'Saturation' and setting.Sat or name == 'Vibrance' and setting.Value or setting.Opacity, 0.04, 0.96), 1)
				sfill.Position = UDim2.new(); sfill.BackgroundTransparency = 1; sfill.Parent = sbar

				local sknobHolder = Instance.new('Frame')
				sknobHolder.Name = 'Knob'; sknobHolder.Size = UDim2.fromOffset(24, 4)
				sknobHolder.Position = UDim2.fromScale(1, 0.5); sknobHolder.AnchorPoint = Vector2.new(0.5, 0.5)
				sknobHolder.BackgroundColor3 = ss.BackgroundColor3; sknobHolder.BorderSizePixel = 0; sknobHolder.Parent = sfill

				local sknob = Instance.new('Frame')
				sknob.Name = 'Knob'; sknob.Size = UDim2.fromOffset(14, 14)
				sknob.Position = UDim2.fromScale(0.5, 0.5); sknob.AnchorPoint = Vector2.new(0.5, 0.5)
				sknob.BackgroundColor3 = palette.Text; sknob.Parent = sknobHolder
				addCorner(sknob, UDim.new(1, 0))

				ss.InputBegan:Connect(function(inputObj)
					if (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
						and (inputObj.Position.Y - ss.AbsolutePosition.Y) > (20 * scale.Scale) then
						local changed = IS.InputChanged:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement then
								local p = math.clamp((input.Position.X - sbar.AbsolutePosition.X) / sbar.AbsoluteSize.X, 0, 1)
								setting.Hue = setting.Hue
								if name == 'Saturation' then setting.Sat = p
								elseif name == 'Vibrance' then setting.Value = p
								elseif name == 'Opacity' then setting.Opacity = p end
								sfill.Size = UDim2.fromScale(math.clamp(p, 0.04, 0.96), 1)
								preview.ImageColor3 = Color3.fromHSV(setting.Hue, setting.Sat, setting.Value)
								preview.ImageTransparency = 1 - setting.Opacity
							end
						end)
						local ended
						ended = inputObj.Changed:Connect(function()
							if inputObj.UserInputState == Enum.UserInputState.End then
								if changed then changed:Disconnect() end
								if ended then ended:Disconnect() end
							end
						end)
					end
				end)

				return ss
			end

			satSlider = createSubSlider('Saturation', ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, setting.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(setting.Hue, 1, setting.Value))
			}))
			vibSlider = createSubSlider('Vibrance', ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(setting.Hue, setting.Sat, 1))
			}))
			opSlider = createSubSlider('Opacity', ColorSequence.new({
				ColorSequenceKeypoint.new(0, color.Dark(palette.Main, 0.02)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(setting.Hue, setting.Sat, setting.Value))
			}))

			local expanded = false
			expandBtn.MouseButton1Click:Connect(function()
				expanded = not expanded
				satSlider.Visible = expanded
				vibSlider.Visible = expanded
				opSlider.Visible = expanded
				expandIcon.Rotation = expanded and 180 or 0
			end)

			local doubleClick = tick()
			sf.InputBegan:Connect(function(inputObj)
				if (inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch)
					and (inputObj.Position.Y - sf.AbsolutePosition.Y) > (20 * scale.Scale) then
					if doubleClick > tick() then end
					doubleClick = tick() + 0.3
					local changed = IS.InputChanged:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement then
							setting.Hue = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
							fill.Size = UDim2.fromScale(math.clamp(setting.Hue, 0.04, 0.96), 1)
							preview.ImageColor3 = Color3.fromHSV(setting.Hue, setting.Sat, setting.Value)
							satSlider:FindFirstChild('Slider', true).UIGradient.Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, setting.Value)),
								ColorSequenceKeypoint.new(1, Color3.fromHSV(setting.Hue, 1, setting.Value))
							})
							vibSlider:FindFirstChild('Slider', true).UIGradient.Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
								ColorSequenceKeypoint.new(1, Color3.fromHSV(setting.Hue, setting.Sat, 1))
							})
							opSlider:FindFirstChild('Slider', true).UIGradient.Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, color.Dark(palette.Main, 0.02)),
								ColorSequenceKeypoint.new(1, Color3.fromHSV(setting.Hue, setting.Sat, setting.Value))
							})
						end
					end)
					local ended
					ended = inputObj.Changed:Connect(function()
						if inputObj.UserInputState == Enum.UserInputState.End then
							if changed then changed:Disconnect() end
							if ended then ended:Disconnect() end
						end
					end)
				end
			end)

			sf.MouseEnter:Connect(function()
				tween:Tween(knob, palette.Tween, {Size = UDim2.fromOffset(16, 16)})
			end)
			sf.MouseLeave:Connect(function()
				tween:Tween(knob, palette.Tween, {Size = UDim2.fromOffset(14, 14)})
			end)

		elseif setting.Type == 'TextList' then
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 50)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = ''
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip)

			local bkg = Instance.new('Frame')
			bkg.Name = 'BKG'
			bkg.Size = UDim2.new(1, -20, 1, -9)
			bkg.Position = UDim2.fromOffset(10, 4)
			bkg.BackgroundColor3 = color.Light(palette.Main, 0.034)
			bkg.Parent = sf
			addCorner(bkg, UDim.new(0, 4))

			local button = Instance.new('TextButton')
			button.Name = 'TextList'
			button.Size = UDim2.new(1, -2, 1, -2)
			button.Position = UDim2.fromOffset(1, 1)
			button.BackgroundColor3 = palette.Main
			button.AutoButtonColor = false
			button.Text = ''
			button.Parent = bkg

			local btnIcon = Instance.new('ImageLabel')
			btnIcon.Size = UDim2.fromOffset(14, 12)
			btnIcon.Position = UDim2.fromOffset(10, 14)
			btnIcon.BackgroundTransparency = 1
			btnIcon.Image = setting.Icon
			btnIcon.Parent = button

			local btnTitle = Instance.new('TextLabel')
			btnTitle.Size = UDim2.new(1, -35, 0, 15)
			btnTitle.Position = UDim2.fromOffset(35, 6)
			btnTitle.BackgroundTransparency = 1
			btnTitle.Text = setting.Name
			btnTitle.TextXAlignment = Enum.TextXAlignment.Left
			btnTitle.TextColor3 = color.Dark(palette.Text, 0.16)
			btnTitle.TextSize = 15
			btnTitle.TextTruncate = Enum.TextTruncate.AtEnd
			btnTitle.FontFace = palette.Font
			btnTitle.Parent = button

			local amount = btnTitle:Clone()
			amount.Size = UDim2.new(1, -13, 0, 15)
			amount.Position = UDim2.fromOffset(0, 6)
			amount.Text = tostring(#setting.List)
			amount.TextXAlignment = Enum.TextXAlignment.Right
			amount.Parent = button

			local items = btnTitle:Clone()
			items.Position = UDim2.fromOffset(35, 21)
			items.Text = #setting.ListEnabled > 0 and table.concat(setting.ListEnabled, ', ') or 'None'
			items.TextColor3 = color.Dark(palette.Text, 0.43)
			items.TextSize = 11
			items.Parent = button

			local window = Instance.new('TextButton')
			window.Name = setting.Name .. 'TextWindow'
			window.Size = UDim2.fromOffset(220, 85)
			window.BackgroundColor3 = palette.Main
			window.BorderSizePixel = 0
			window.AutoButtonColor = false
			window.Visible = false
			window.Text = ''
			window.Parent = self.ClickGui
			addBlur(window)
			addCorner(window)

			local wIcon = Instance.new('ImageLabel')
			wIcon.Size = setting.TabSize; wIcon.Position = UDim2.fromOffset(10, 13)
			wIcon.BackgroundTransparency = 1; wIcon.Image = setting.Tab; wIcon.Parent = window

			local wTitle = Instance.new('TextLabel')
			wTitle.Size = UDim2.new(1, -36, 0, 20)
			wTitle.Position = UDim2.fromOffset(math.abs(wTitle.Size.X.Offset), 11)
			wTitle.BackgroundTransparency = 1; wTitle.Text = setting.Name
			wTitle.TextXAlignment = Enum.TextXAlignment.Left
			wTitle.TextColor3 = palette.Text; wTitle.TextSize = 13
			wTitle.FontFace = palette.Font; wTitle.Parent = window

			local wClose = addCloseButton(window)
			local addBkg = Instance.new('Frame')
			addBkg.Name = 'Add'; addBkg.Size = UDim2.fromOffset(200, 31)
			addBkg.Position = UDim2.fromOffset(10, 45)
			addBkg.BackgroundColor3 = color.Light(palette.Main, 0.02)
			addBkg.Parent = window; addCorner(addBkg)

			local addBox = Instance.new('TextBox')
			addBox.Size = UDim2.new(1, -35, 1, 0); addBox.Position = UDim2.fromOffset(10, 0)
			addBox.BackgroundTransparency = 1; addBox.Text = ''
			addBox.PlaceholderText = setting.Placeholder
			addBox.TextXAlignment = Enum.TextXAlignment.Left
			addBox.TextColor3 = Color3.new(1, 1, 1); addBox.TextSize = 15
			addBox.FontFace = palette.Font; addBox.ClearTextOnFocus = false; addBox.Parent = addBkg

			local addBtn = Instance.new('ImageButton')
			addBtn.Size = UDim2.fromOffset(16, 16); addBtn.Position = UDim2.new(1, -26, 0, 8)
			addBtn.BackgroundTransparency = 1; addBtn.Image = asset.add
			addBtn.ImageColor3 = setting.Color; addBtn.ImageTransparency = 0.3; addBtn.Parent = addBkg

			local textListObjects = {}

			local function refreshList()
				for _, v in textListObjects do v:Destroy() end
				table.clear(textListObjects)
				window.Size = UDim2.fromOffset(220, 85 + (#setting.List * 35))
				amount.Text = tostring(#setting.List)
				local txt = ''
				for i, v in setting.ListEnabled do txt = txt .. (i == 1 and v or ', ' .. v) end
				items.Text = txt ~= '' and txt or 'None'

				for i, v in setting.List do
					local enabled = table.find(setting.ListEnabled, v)
					local obj = Instance.new('TextButton')
					obj.Name = v; obj.Size = UDim2.fromOffset(200, 32)
					obj.Position = UDim2.fromOffset(10, 47 + (i * 35))
					obj.BackgroundColor3 = color.Light(palette.Main, 0.02)
					obj.AutoButtonColor = false; obj.Text = ''; obj.Parent = window; addCorner(obj)

					local dot = Instance.new('Frame')
					dot.Size = UDim2.fromOffset(10, 11); dot.Position = UDim2.fromOffset(10, 12)
					dot.BackgroundColor3 = enabled and setting.Color or color.Light(palette.Main, 0.37)
					dot.Parent = obj; addCorner(dot, UDim.new(1, 0))

					local dotIn = dot:Clone()
					dotIn.Size = UDim2.fromOffset(8, 9); dotIn.Position = UDim2.fromOffset(1, 1)
					dotIn.BackgroundColor3 = enabled and setting.Color or color.Light(palette.Main, 0.02)
					dotIn.Parent = dot

					local oTitle = Instance.new('TextLabel')
					oTitle.Size = UDim2.new(1, -30, 1, 0); oTitle.Position = UDim2.fromOffset(30, 0)
					oTitle.BackgroundTransparency = 1; oTitle.Text = v
					oTitle.TextXAlignment = Enum.TextXAlignment.Left
					oTitle.TextColor3 = color.Dark(palette.Text, 0.16); oTitle.TextSize = 15
					oTitle.FontFace = palette.Font; oTitle.Parent = obj

					local oClose = Instance.new('ImageButton')
					oClose.Size = UDim2.fromOffset(16, 16); oClose.Position = UDim2.new(1, -26, 0, 8)
					oClose.BackgroundTransparency = 1; oClose.AutoButtonColor = false
					oClose.Image = asset.closeb; oClose.ImageColor3 = color.Light(palette.Text, 0.2)
					oClose.ImageTransparency = 0.5; oClose.Parent = obj; addCorner(oClose, UDim.new(1, 0))

					oClose.MouseButton1Click:Connect(function()
						local idx = table.find(setting.List, v)
						if idx then table.remove(setting.List, idx) end
						local idx2 = table.find(setting.ListEnabled, v)
						if idx2 then table.remove(setting.ListEnabled, idx2) end
						refreshList()
					end)

					obj.MouseButton1Click:Connect(function()
						local idx = table.find(setting.ListEnabled, v)
						if idx then
							table.remove(setting.ListEnabled, idx)
							dot.BackgroundColor3 = color.Light(palette.Main, 0.37)
							dotIn.BackgroundColor3 = color.Light(palette.Main, 0.02)
						else
							table.insert(setting.ListEnabled, v)
							dot.BackgroundColor3 = setting.Color
							dotIn.BackgroundColor3 = setting.Color
						end
						local txt = ''
						for i, ve in setting.ListEnabled do txt = txt .. (i == 1 and ve or ', ' .. ve) end
						items.Text = txt ~= '' and txt or 'None'
					end)

					table.insert(textListObjects, obj)
				end
			end

			addBtn.MouseButton1Click:Connect(function()
				if addBox.Text ~= '' and not table.find(setting.List, addBox.Text) then
					table.insert(setting.List, addBox.Text)
					table.insert(setting.ListEnabled, addBox.Text)
					refreshList()
					addBox.Text = ''
				end
			end)

			wClose.MouseButton1Click:Connect(function() window.Visible = false end)
			button.MouseButton1Click:Connect(function() window.Visible = not window.Visible end)

		elseif setting.Type == 'Targets' then
			local sf = Instance.new('TextButton')
			sf.Size = UDim2.new(1, 0, 0, 50)
			sf.BackgroundColor3 = color.Dark(children.BackgroundColor3, setting.Darker and 0.02 or 0)
			sf.BorderSizePixel = 0
			sf.AutoButtonColor = false
			sf.Text = ''
			sf.Parent = children
			setting.Object = sf
			addTooltip(sf, setting.Tooltip)

			local bkg = Instance.new('Frame')
			bkg.Name = 'BKG'
			bkg.Size = UDim2.new(1, -20, 1, -9)
			bkg.Position = UDim2.fromOffset(10, 4)
			bkg.BackgroundColor3 = color.Light(palette.Main, 0.034)
			bkg.Parent = sf
			addCorner(bkg, UDim.new(0, 4))

			local button = Instance.new('TextButton')
			button.Name = 'TargetsButton'
			button.Size = UDim2.new(1, -2, 1, -2)
			button.Position = UDim2.fromOffset(1, 1)
			button.BackgroundColor3 = palette.Main
			button.AutoButtonColor = false
			button.Text = ''
			button.Parent = bkg

			local btnTitle = Instance.new('TextLabel')
			btnTitle.Size = UDim2.new(1, -5, 0, 15)
			btnTitle.Position = UDim2.fromOffset(5, 6)
			btnTitle.BackgroundTransparency = 1
			btnTitle.Text = 'Target:'
			btnTitle.TextXAlignment = Enum.TextXAlignment.Left
			btnTitle.TextColor3 = color.Dark(palette.Text, 0.16)
			btnTitle.TextSize = 15
			btnTitle.TextTruncate = Enum.TextTruncate.AtEnd
			btnTitle.FontFace = palette.Font
			btnTitle.Parent = button

			local items = btnTitle:Clone()
			items.Size = UDim2.new(1, -5, 0, 15)
			items.Position = UDim2.fromOffset(5, 21)
			items.Text = 'Ignore none'
			items.TextColor3 = color.Dark(palette.Text, 0.43)
			items.TextSize = 11
			items.Parent = button

			local tool = Instance.new('Frame')
			tool.Size = UDim2.fromOffset(65, 12)
			tool.Position = UDim2.fromOffset(52, 8)
			tool.BackgroundTransparency = 1
			tool.Parent = button
			local toolList = Instance.new('UIListLayout')
			toolList.FillDirection = Enum.FillDirection.Horizontal
			toolList.Padding = UDim.new(0, 6)
			toolList.Parent = tool

			local tw = Instance.new('TextButton')
			tw.Name = 'TargetsTextWindow'
			tw.Size = UDim2.fromOffset(220, 145)
			tw.BackgroundColor3 = palette.Main
			tw.BorderSizePixel = 0
			tw.AutoButtonColor = false
			tw.Visible = false
			tw.Text = ''
			tw.Parent = self.ClickGui
			addBlur(tw); addCorner(tw)

			local twIcon = Instance.new('ImageLabel')
			twIcon.Size = UDim2.fromOffset(18, 12); twIcon.Position = UDim2.fromOffset(10, 15)
			twIcon.BackgroundTransparency = 1; twIcon.Image = asset.targetstab; twIcon.Parent = tw

			local twTitle = Instance.new('TextLabel')
			twTitle.Size = UDim2.new(1, -36, 0, 20)
			twTitle.Position = UDim2.fromOffset(math.abs(twTitle.Size.X.Offset), 11)
			twTitle.BackgroundTransparency = 1; twTitle.Text = 'Target settings'
			twTitle.TextXAlignment = Enum.TextXAlignment.Left
			twTitle.TextColor3 = palette.Text; twTitle.TextSize = 13
			twTitle.FontFace = palette.Font; twTitle.Parent = tw

			local twClose = addCloseButton(tw)

			local targetToggles = {}
			local function makeTargetToggle(name, tbl)
				local targetBtn = Instance.new('TextButton')
				targetBtn.Size = UDim2.fromOffset(98, 31)
				targetBtn.Position = UDim2.fromOffset(#targetToggles * 110 + 11, 45)
				targetBtn.BackgroundColor3 = color.Light(palette.Main, 0.05)
				targetBtn.AutoButtonColor = false; targetBtn.Text = ''; targetBtn.Parent = tw; addCorner(targetBtn)

				local tbkg = Instance.new('Frame')
				tbkg.Size = UDim2.new(1, -2, 1, -2); tbkg.Position = UDim2.fromOffset(1, 1)
				tbkg.BackgroundColor3 = palette.Main; tbkg.Parent = targetBtn; addCorner(tbkg)

				local tIcon = Instance.new('ImageLabel')
				local iconMap = {Players = asset.targetplayers1, NPCs = asset.targetnpc1}
				tIcon.Size = UDim2.fromOffset(15, 16); tIcon.Position = UDim2.fromScale(0.5, 0.5)
				tIcon.AnchorPoint = Vector2.new(0.5, 0.5); tIcon.BackgroundTransparency = 1
				tIcon.Image = iconMap[name] or asset.targetplayers1
				tIcon.ImageColor3 = color.Light(palette.Main, 0.37); tIcon.Parent = tbkg

				local toggleApi = {Enabled = tbl.Enabled}
				function toggleApi:Toggle()
					self.Enabled = not self.Enabled
					tbl.Enabled = self.Enabled
					tween:Tween(tbkg, palette.Tween, {
						BackgroundColor3 = self.Enabled and Color3.fromHSV(self.GUIColor and self.GUIColor.Hue or 0.46, 0.96, 0.52) or palette.Main
					})
					tween:Tween(tIcon, palette.Tween, {
						ImageColor3 = self.Enabled and Color3.new(1, 1, 1) or color.Light(palette.Main, 0.37)
					})
					local txt = ''
					local parts = {}
					if setting.Players.Enabled then table.insert(parts, '') end
					if setting.NPCs.Enabled then table.insert(parts, '') end
					items.Text = 'Ignore ' ..
						(not setting.Invisible.Enabled and not setting.Walls.Enabled and 'none'
						or (setting.Invisible.Enabled and 'invisible' or '')
						.. (setting.Invisible.Enabled and setting.Walls.Enabled and ', ' or '')
						.. (setting.Walls.Enabled and 'behind walls' or ''))
				end

				targetBtn.MouseEnter:Connect(function()
					if not toggleApi.Enabled then
						tween:Tween(tbkg, palette.Tween, {
							BackgroundColor3 = Color3.fromHSV(0.46, 0.96, 0.52 - 0.25)
						})
						tween:Tween(tIcon, palette.Tween, {ImageColor3 = Color3.new(1, 1, 1)})
					end
				end)
				targetBtn.MouseLeave:Connect(function()
					if not toggleApi.Enabled then
						tween:Tween(tbkg, palette.Tween, {BackgroundColor3 = palette.Main})
						tween:Tween(tIcon, palette.Tween, {ImageColor3 = color.Light(palette.Main, 0.37)})
					end
				end)
				targetBtn.MouseButton1Click:Connect(function() toggleApi:Toggle() end)

				table.insert(targetToggles, toggleApi)
				return toggleApi
			end

			setting.Players = makeTargetToggle('Players', setting.Players)
			setting.NPCs = makeTargetToggle('NPCs', setting.NPCs)

			twClose.MouseButton1Click:Connect(function() tw.Visible = false end)
			button.MouseButton1Click:Connect(function() tw.Visible = not tw.Visible end)
		end
	end
end

function UI:Open()
	if self.IsOpen then return end
	self.IsOpen = true
	if not self.ScreenGui then
		self:BuildMainWindow()
		for _, mod in pairs(self.Modules) do
			self:BuildModuleButton(mod)
		end
	end
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
