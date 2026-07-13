-- Synthware
local w = "-- Synthware"
local p = "Synthware/compiled.lua"
if isfile and readfile then
 local c = readfile(p)
 if c and c:sub(1,#w) == w then loadstring(c)() return end
end
if makefolder then pcall(makefolder,"Synthware") end
if writefile then
 writefile(p,w.."\n"..game:HttpGet("https://raw.githubusercontent.com/chickenbutt322/Synthware/main/Synthware/compiled.lua",true))
 loadstring(readfile(p))()
end