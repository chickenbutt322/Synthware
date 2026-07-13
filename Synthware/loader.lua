local files = {
	lib = {
		services = "Synthware/lib/services.lua",
		events = "Synthware/lib/events.lua",
		entity = "Synthware/lib/entity.lua",
		uilib = "Synthware/lib/uilib.lua",
	},
	features = {
		killaura = "Synthware/features/killaura.lua",
		esp = "Synthware/features/esp.lua",
		sprint = "Synthware/features/sprint.lua",
	},
}

local cache = {}
local function loadModule(path)
	if cache[path] then return cache[path] end
	local src = readfile(path)
	local fn, err = loadstring(src, path)
	if not fn then error("Failed to load " .. path .. ": " .. err) end
	local ok, res = pcall(fn)
	if not ok then error("Error in " .. path .. ": " .. res) end
	cache[path] = res
	return res
end

local script = {Parent = {Parent = {}}}
script.Parent.Parent.lib = {services = loadModule(files.lib.services)}
script.Parent.Parent.lib.events = loadModule(files.lib.events)
script.Parent.Parent.lib.entity = loadModule(files.lib.entity)
script.Parent.Parent.lib.uilib = loadModule(files.lib.uilib)
script.Parent.Parent.features = {
	killaura = loadModule(files.features.killaura),
	esp = loadModule(files.features.esp),
	sprint = loadModule(files.features.sprint),
}

local mainSrc = readfile("Synthware/main.lua")
local mainFn, mainErr = loadstring(mainSrc, "Synthware/main.lua")
if not mainFn then error("Failed to load main: " .. mainErr) end
mainFn()
