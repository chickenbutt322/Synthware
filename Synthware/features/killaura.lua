local Svc = require(script.Parent.Parent.lib.services)
local entity = require(script.Parent.Parent.lib.entity)

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

				local selfpos = entity.character.RootPart.Position
				local localfacing = entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

				local sortFunc
				if Sort.Value == 'Health' then
					sortFunc = function(a, b) return a.Entity.Health < b.Entity.Health end
				elseif Sort.Value == 'Angle' then
					sortFunc = function(a, b)
						local da = (a.Entity.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
						local db = (b.Entity.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
						return da.Magnitude < db.Magnitude
					end
				end

				local plrs = entity.AllPosition({
					Range = SwingRange.Value,
					Players = Targets.Players.Enabled,
					NPCs = Targets.NPCs.Enabled,
					Sort = sortFunc,
					Limit = Mode.Value == 'Single' and 1 or MaxTargets.Value,
					Part = 'RootPart',
				})

				if #plrs == 0 then task.wait(1 / UpdateRate.Value) continue end

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
