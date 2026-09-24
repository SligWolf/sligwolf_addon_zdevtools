AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBHook = SligWolf_Addons.Hook

-- Docs on: https://github.com/ZARP-Gaming/GProfiler/tree/main

local function permissionGProfilerDeveloper(ply)
	if SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return true
	end
end

LIBHook.Add("GProfiler.Access.CanAccess", "Addon_ZDevTools_GProfiler_Developer", permissionGProfilerDeveloper)

return true

