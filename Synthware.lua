--[[
Synthware — Bedwars utility script
Architecture:
  1. Services layer     — cloneref-wrapped singletons (Players, RunService, etc.)
  2. Entity system      — event-driven player/mob tracking via PlayerAdded/CharacterAdded/AttributeChanged
  3. ESP                — Drawing.new('Square'/'Line'/'Text') per entity, updated on RenderStepped (every 2nd frame)
  4. QoL features       — Sprint (hijacks SprintController.stopSprinting), AutoBridge (block placement)
  5. Keybinds           — ]=ESP, [=Sprint, ;=AutoBridge
  6. UI notifications   — Drawing.new('Text') overlay with fade
]]

local cloneref = cloneref or function(obj) return obj end

local Svc = {
	Players = cloneref(game:GetService('Players')),
	RunService = cloneref(game:GetService('RunService')),
	UserInputService = cloneref(game:GetService('UserInputService')),
	CollectionService = cloneref(game:GetService('CollectionService')),
	ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage')),
	Workspace = cloneref(game:GetService('Workspace')),
	HttpService = cloneref(game:GetService('HttpService')),
	TweenService = cloneref(game:GetService('TweenService')),
	Debris = cloneref(game:GetService('Debris')),
	LocalPlayer = cloneref(game:GetService('Players').LocalPlayer),
	getCamera = function() return Svc.Workspace.CurrentCamera or Svc.Workspace:FindFirstChildWhichIsA('Camera') end
}

-- ── Custom event system ─────────────────────────────────────────────
local Events = setmetatable({}, {
	__index = function(self, idx)
		local ev = {Connections = {}}
		ev.Connect = function(_, fn)
			table.insert(ev.Connections, fn)
			return {Disconnect = function()
				local i = table.find(ev.Connections, fn)
				if i then table.remove(ev.Connections, i) end
			end}
		end
		ev.Fire = function(_, ...)
			for _, v in ev.Connections do task.spawn(v, ...) end
		end
		ev.Destroy = function() table.clear(ev.Connections) end
		rawset(self, idx, ev)
		return ev
	end
})

-- ── Entity Library ───────────────────────────────────────────────────
local entity = {
	isAlive = false, character = nil, List = {},
	PlayerConnections = {}, EntityThreads = {},
	Connections = {}, Running = false, Events = Events
}

local function waitForChildOfType(obj, name, timeout, isProp)
	local deadline = tick() + timeout
	repeat
		local found = isProp and obj[name] or obj:FindFirstChildOfClass(name)
		if found or deadline < tick() then return found end
		task.wait()
	until false
end

local function getShieldHealth(char)
	local total = 0
	for k, v in char:GetAttributes() do
		if k:find('Shield') and type(v) == 'number' and v > 0 then total += v end
	end
	return total
end

entity.targetCheck = function(ent)
	if ent.TeamCheck then return ent:TeamCheck() end
	if ent.NPC then return true end
	if not ent.Player then return true end
	local mt = Svc.LocalPlayer:GetAttribute('Team')
	local tt = ent.Player:GetAttribute('Team')
	if mt == nil or tt == nil then return true end
	return mt ~= tt
end

entity.isVulnerable = function(ent)
	return ent.Health > 0 and not ent.Character:FindFirstChildWhichIsA('ForceField')
end

entity.getEntityColor = function(ent)
	if ent.Friend then return Color3.fromRGB(0, 255, 127) end
	if ent.Player then
		local tc = ent.Player.TeamColor
		if tc and tostring(tc) ~= 'White' then return tc.Color end
	end
	return nil
end

entity.addEntity = function(char, plr, teamFunc)
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

		local ent = {
			Connections = {}, Character = char, Head = head,
			Humanoid = hum, HumanoidRootPart = rootPart, RootPart = rootPart,
			Player = plr, NPC = plr == nil, TeamCheck = teamFunc,
			Health = plr and (char:GetAttribute('Health') or hum.Health or 100) or 100,
			MaxHealth = plr and (char:GetAttribute('MaxHealth') or hum.MaxHealth or 100) or 100,
			HipHeight = hum.HipHeight + (rootPart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
		}

		if plr == Svc.LocalPlayer then
			entity.character = ent
			entity.isAlive = true
			entity.Events.LocalAdded:Fire(ent)
		else
			ent.Targetable = entity.targetCheck(ent)
			if plr then
				for _, attr in {'Health', 'MaxHealth'} do
					table.insert(ent.Connections, char:GetAttributeChangedSignal(attr):Connect(function()
						ent.Health = (char:GetAttribute('Health') or 100) + getShieldHealth(char)
						ent.MaxHealth = char:GetAttribute('MaxHealth') or 100
						entity.Events.EntityUpdated:Fire(ent)
					end))
				end
				for k, v in char:GetAttributes() do
					if k:find('Shield') and type(v) == 'number' then
						table.insert(ent.Connections, char:GetAttributeChangedSignal(k):Connect(function()
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
			if not char.Parent then entity.removeEntity(char, plr == Svc.LocalPlayer) end
		end))
		entity.EntityThreads[char] = nil
	end)
end

entity.removeEntity = function(char, isLocal)
	if isLocal then
		if entity.isAlive then
			entity.isAlive = false
			for _, c in entity.character.Connections do c:Disconnect() end
			table.clear(entity.character.Connections)
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
			table.clear(v.Connections)
			table.remove(entity.List, i)
			entity.Events.EntityRemoved:Fire(v)
			break
		end
	end
end

entity.refreshEntity = function(char, plr)
	entity.removeEntity(char)
	entity.addEntity(char, plr)
end

entity.addPlayer = function(plr)
	if plr.Character then entity.refreshEntity(plr.Character, plr) end
	entity.PlayerConnections[plr] = {
		plr.CharacterAdded:Connect(function(char) entity.refreshEntity(char, plr) end),
		plr.CharacterRemoving:Connect(function(char) entity.removeEntity(char, plr == Svc.LocalPlayer) end),
		plr:GetAttributeChangedSignal('Team'):Connect(function()
			if plr == Svc.LocalPlayer then
				local c = table.clone(entity.List)
				for _, v in c do
					if v.Targetable ~= entity.targetCheck(v) then entity.refreshEntity(v.Character, v.Player) end
				end
			else
				for _, v in entity.List do
					if v.Player == plr and v.Targetable ~= entity.targetCheck(v) then
						entity.refreshEntity(v.Character, v.Player) break
					end
				end
			end
		end)
	}
end

entity.removePlayer = function(plr)
	if entity.PlayerConnections[plr] then
		for _, c in entity.PlayerConnections[plr] do c:Disconnect() end
		table.clear(entity.PlayerConnections[plr])
		entity.PlayerConnections[plr] = nil
	end
	entity.removeEntity(plr)
end

entity.start = function()
	if entity.Running then entity.stop() end
	table.insert(entity.Connections, Svc.Players.PlayerAdded:Connect(function(p) entity.addPlayer(p) end))
	table.insert(entity.Connections, Svc.Players.PlayerRemoving:Connect(function(p) entity.removePlayer(p) end))
	table.insert(entity.Connections, Svc.Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		Svc.getCamera = function() return Svc.Workspace.CurrentCamera or Svc.Workspace:FindFirstChildWhichIsA('Camera') end
	end))
	for _, p in Svc.Players:GetPlayers() do entity.addPlayer(p) end
	entity.Running = true
end

entity.stop = function()
	for _, c in entity.Connections do c:Disconnect() end
	for _, pc in entity.PlayerConnections do
		for _, c in pc do c:Disconnect() end
		table.clear(pc)
	end
	entity.removeEntity(nil, true)
	local c = table.clone(entity.List)
	for _, v in c do entity.removeEntity(v.Character) end
	for _, t in entity.EntityThreads do task.cancel(t) end
	table.clear(entity.PlayerConnections); table.clear(entity.EntityThreads)
	table.clear(entity.Connections); entity.Running = false
end

-- ── ESP Feature ──────────────────────────────────────────────────────
local ESP = {
	Enabled = false, ShowBox = true, ShowHealth = true, ShowName = true,
	ShowTracers = false, TeamCheck = true, Reference = {}, Connections = {}, frame = 0
}

function ESP:Add(ent)
	if not self.Enabled then return end
	if ent.Player and ent.Player == Svc.LocalPlayer then return end
	local d = {}
	d.Box = Drawing.new('Square'); d.Box.Thickness = 1; d.Box.Filled = false; d.Box.ZIndex = 2
	d.Box.Color = entity.getEntityColor(ent) or Color3.fromRGB(255, 255, 255)
	d.BoxBorder = Drawing.new('Square'); d.BoxBorder.Thickness = 1; d.BoxBorder.Filled = false; d.BoxBorder.ZIndex = 1
	d.BoxBorder.Color = Color3.new(0,0,0); d.BoxBorder.Transparency = 0.35
	d.BoxFill = Drawing.new('Square'); d.BoxFill.Thickness = 1; d.BoxFill.Filled = true; d.BoxFill.ZIndex = 1
	d.BoxFill.Color = Color3.new(0,0,0); d.BoxFill.Transparency = 0.25
	d.HealthBar = Drawing.new('Line'); d.HealthBar.Thickness = 2; d.HealthBar.ZIndex = 4
	d.HealthBg = Drawing.new('Line'); d.HealthBg.Thickness = 4; d.HealthBg.ZIndex = 3
	d.HealthBg.Color = Color3.new(0,0,0); d.HealthBg.Transparency = 0.35
	d.Name = Drawing.new('Text'); d.Name.Size = 16; d.Name.Center = true; d.Name.ZIndex = 4
	d.Name.Outline = true; d.Name.Color = Color3.fromRGB(255,255,255)
	d.Name.Text = ent.Player and ent.Player.Name or ent.Character.Name
	d.NameBg = Drawing.new('Square'); d.NameBg.Thickness = 1; d.NameBg.Filled = true; d.NameBg.ZIndex = 3
	d.NameBg.Color = Color3.new(0,0,0); d.NameBg.Transparency = 0.35
	d.Tracer = Drawing.new('Line'); d.Tracer.Thickness = 1; d.Tracer.ZIndex = 3; d.Tracer.Color = d.Box.Color
	self.Reference[ent] = d
end

function ESP:Remove(ent)
	local d = self.Reference[ent]
	if d then self.Reference[ent] = nil; for _, v in d do pcall(function() v.Visible = false; v:Remove() end) end end
end

function ESP:UpdateLoop()
	self.frame += 1
	if self.frame % 2 ~= 0 then return end
	local vp = Svc.getCamera().ViewportSize
	local to = Vector2.new(vp.X / 2, vp.Y)
	for ent, d in self.Reference do
		if not ent.RootPart or not ent.RootPart.Parent then self:Remove(ent) continue end
		if self.TeamCheck and not ent.Targetable and not ent.Friend then
			for _, v in d do v.Visible = false end
			continue
		end
		local rp, vis = Svc.getCamera():WorldToViewportPoint(ent.RootPart.Position)
		if not vis then
			for _, v in d do v.Visible = false end
			if self.ShowTracers then
				d.Tracer.Visible = true
				d.Tracer.From = to
				d.Tracer.To = Vector2.new(rp.X, math.clamp(rp.Y, 0, vp.Y))
			end
			continue
		end
		local lv = Svc.getCamera().CFrame.LookVector
		local tw = (CFrame.lookAlong(ent.RootPart.Position, lv) * CFrame.new(2, ent.HipHeight, 0)).p
		local bw = (CFrame.lookAlong(ent.RootPart.Position, lv) * CFrame.new(-2, -ent.HipHeight - 1, 0)).p
		local tv, _ = Svc.getCamera():WorldToViewportPoint(tw)
		local bv, _ = Svc.getCamera():WorldToViewportPoint(bw)
		local sx, sy = tv.X - bv.X, tv.Y - bv.Y
		local px, py = rp.X - sx / 2, rp.Y - sy / 2

		d.Box.Position = Vector2.new(px, py)//1; d.Box.Size = Vector2.new(sx, sy)//1; d.Box.Visible = self.ShowBox
		d.BoxBorder.Position = Vector2.new(px-1, py+1)//1; d.BoxBorder.Size = Vector2.new(sx+2, sy-2)//1; d.BoxBorder.Visible = self.ShowBox
		d.BoxFill.Position = Vector2.new(px+1, py-1)//1; d.BoxFill.Size = Vector2.new(sx-2, sy+2)//1; d.BoxFill.Visible = self.ShowBox

		if self.ShowHealth then
			local hf = math.clamp(ent.Health / math.max(ent.MaxHealth, 1), 0, 1)
			local hy = py + (sy - sy * hf)
			d.HealthBar.From = Vector2.new(px-7, hy)//1; d.HealthBar.To = Vector2.new(px-7, py)//1
			d.HealthBar.Color = Color3.fromHSV(hf / 2.8, 0.9, 0.8)
			d.HealthBar.Visible = true
			d.HealthBg.From = Vector2.new(px-7, py+1)//1; d.HealthBg.To = Vector2.new(px-7, py+sy-1)//1
			d.HealthBg.Visible = true
		else d.HealthBar.Visible = false; d.HealthBg.Visible = false end

		if self.ShowName then
			d.Name.Position = Vector2.new(px+sx/2, py+sy-24)//1
			local bnd = d.Name.TextBounds
			d.NameBg.Size = bnd + Vector2.new(8,4); d.NameBg.Position = Vector2.new(px+sx/2 - bnd.X/2 - 4, py+sy-26)//1
			d.Name.Visible = true; d.NameBg.Visible = true
		else d.Name.Visible = false; d.NameBg.Visible = false end

		if self.ShowTracers then d.Tracer.From = to; d.Tracer.To = Vector2.new(rp.X, rp.Y); d.Tracer.Visible = true
		else d.Tracer.Visible = false end
	end
end

function ESP:Toggle()
	self.Enabled = not self.Enabled
	if self.Enabled then
		for _, v in entity.List do self:Add(v) end
		self.Connections[#self.Connections+1] = entity.Events.EntityAdded:Connect(function(e) self:Add(e) end)
		self.Connections[#self.Connections+1] = entity.Events.EntityRemoved:Connect(function(e) self:Remove(e) end)
		self.Connections[#self.Connections+1] = Svc.RunService.RenderStepped:Connect(function() self:UpdateLoop() end)
	else
		for _, d in self.Reference do for _, v in d do pcall(function() v:Remove() end) end end
		table.clear(self.Reference)
		for _, c in self.Connections do c:Disconnect() end; table.clear(self.Connections)
	end
end

-- ── Sprint Feature ───────────────────────────────────────────────────
local Sprint = {Enabled = false, oldStop = nil, connection = nil}
function Sprint:Toggle()
	self.Enabled = not self.Enabled
	if self.Enabled then
		repeat task.wait() until entity.isAlive
		local ok, Knit = pcall(function() return debug.getupvalue(require(Svc.LocalPlayer.PlayerScripts.TS.knit).setup, 6) end)
		if not ok or not Knit then return end
		local SC = Knit.Controllers.SprintController
		if not SC then return end
		self.oldStop = SC.stopSprinting
		SC.stopSprinting = function(...) local r = self.oldStop(...) SC:startSprinting() return r end
		self.connection = entity.Events.LocalAdded:Connect(function() task.delay(0.1, function() SC:stopSprinting() end) end)
		SC:stopSprinting()
	else
		if self.oldStop then
			local ok, Knit = pcall(function() return debug.getupvalue(require(Svc.LocalPlayer.PlayerScripts.TS.knit).setup, 6) end)
			if ok and Knit and Knit.Controllers.SprintController then
				Knit.Controllers.SprintController.stopSprinting = self.oldStop
			end
			self.oldStop = nil
		end
		if self.connection then self.connection:Disconnect() self.connection = nil end
	end
end

-- ── AutoBridge Feature ──────────────────────────────────────────────
local AutoBridge = {Enabled = false, connection = nil, lastPlace = 0, placer = nil}
local function initPlacer()
	local ok, BlockEngine = pcall(function()
		return require(Svc.LocalPlayer.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine
	end)
	if not ok then return nil end
	local ok2, BlockPlacer = pcall(function()
		return require(Svc.ReplicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer
	end)
	if not ok2 then return nil end
	return BlockPlacer.new(BlockEngine, 'wool_white')
end

function AutoBridge:Toggle()
	self.Enabled = not self.Enabled
	if self.Enabled then
		self.placer = self.placer or initPlacer()
		if not self.placer then self.Enabled = false return end
		self.connection = Svc.RunService.Heartbeat:Connect(function()
			if not entity.isAlive then return end
			local hum = entity.character.Humanoid
			if hum.FloorMaterial == Enum.Material.Air then return end
			if hum.MoveDirection.Magnitude < 0.1 then return end
			local root = entity.character.RootPart
			local dir = Vector3.new(root.Velocity.X, 0, root.Velocity.Z).Unit
			if dir.Magnitude < 0.1 then return end
			local ahead = root.Position + dir * 7
			local below = ahead - Vector3.new(0, 5, 0)
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {Svc.LocalPlayer.Character}
			params.RespectCanCollide = true
			if Svc.Workspace:Raycast(ahead, below - ahead, params) then return end
			if tick() - self.lastPlace < 0.05 then return end
			self.lastPlace = tick()
			local pp = Vector3.new(math.floor(ahead.X/3+0.5)*3, math.floor(ahead.Y/3)*3, math.floor(ahead.Z/3+0.5)*3)
			if Svc.Workspace:Raycast(pp + Vector3.new(0,5,0), Vector3.new(0,-10,0), params) then return end
			pcall(function() self.placer:placeBlock(pp / 3) end)
		end)
	else
		if self.connection then self.connection:Disconnect() self.connection = nil end
	end
end

-- ── UI Notifications ────────────────────────────────────────────────
local notifications = {}
local notifyDraw = Drawing.new('Text')
notifyDraw.Size = 18; notifyDraw.Center = true; notifyDraw.Outline = true
notifyDraw.Color = Color3.fromRGB(255, 255, 255)

local function notify(text, dur)
	dur = dur or 3; local nt = {Text = text, Start = tick(), Duration = dur}
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

-- ── Keybinds ────────────────────────────────────────────────────────
local keys = {
	ESP = Enum.KeyCode.RightBracket,
	Sprint = Enum.KeyCode.LeftBracket,
	AutoBridge = Enum.KeyCode.Semicolon
}

local function status(n, e) return ('[%s] %s'):format(e and '+' or '-', n) end

Svc.UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if input.KeyCode == keys.ESP then ESP:Toggle(); notify(status('ESP', ESP.Enabled))
	elseif input.KeyCode == keys.Sprint then Sprint:Toggle(); notify(status('Sprint', Sprint.Enabled))
	elseif input.KeyCode == keys.AutoBridge then AutoBridge:Toggle(); notify(status('AutoBridge', AutoBridge.Enabled)) end
end)

notify('Synthware loaded | ] ESP [ Sprint ; Bridge', 5)

-- ── Boot ────────────────────────────────────────────────────────────
Svc.RunService.Heartbeat:Wait()
entity.start()

---@return table
return {entity = entity, ESP = ESP, Sprint = Sprint, AutoBridge = AutoBridge, notify = notify}
