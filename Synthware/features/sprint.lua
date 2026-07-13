local Svc = require(script.Parent.Parent.lib.services)
local entity = require(script.Parent.Parent.lib.entity)

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
