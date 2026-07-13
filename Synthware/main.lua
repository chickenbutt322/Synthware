repeat task.wait() until game:IsLoaded()

if shared.Synthware then
	pcall(function() shared.Synthware:Unload() end)
end

local S = {}
shared.Synthware = S

local Svc = require(script.lib.services)
local entity = require(script.lib.entity)
local UI = require(script.lib.uilib)

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

require(script.features.killaura)(UI, store)
require(script.features.esp)(UI)
require(script.features.sprint)(UI)

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
