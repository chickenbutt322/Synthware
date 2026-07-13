local Svc = require(script.Parent.Parent.lib.services)
local entity = require(script.Parent.Parent.lib.entity)
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
