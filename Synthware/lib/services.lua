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
