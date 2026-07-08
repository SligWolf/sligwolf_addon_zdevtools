AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

local SLIGWOLF_BASECHECK = include("sligwolf_addons/basecheck.lua")

if not SLIGWOLF_BASECHECK then
	return
end

SLIGWOLF_BASECHECK.Addonname = "zdevtools"
SLIGWOLF_BASECHECK.RequiredBaseApiVersion = "2.0.0"

if not SLIGWOLF_BASECHECK.CheckBaseAddonExist() then
	return
end

if not SLIGWOLF_ADDON then
	if not SligWolf_Addons.AutoLoadAddon then
		SLIGWOLF_BASECHECK.CheckBaseAddonVersion()
		return SligWolf_Addons.ERROR_BAD_VERSION
	end

	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ERROR = SLIGWOLF_BASECHECK.DoRuntimeChecks()
if SLIGWOLF_ERROR then
	return SLIGWOLF_ERROR
end

-- About SligWolf's ZDevTools:
--  This is an internal development and testing tool for SligWolf's Addons.
--  Do not use on production servers/clients. Only use this during addon development. 
--  Use this addon at your own risk! This will not be publicly available on Workshop!
--  Do not reupload in any way!

-- Safe operation:
--  dev_sligwolf_zdevtools_developers_enabled 0 (default)


SLIGWOLF_ADDON.Author = "Grocel"
SLIGWOLF_ADDON.NiceName = "ZDevTools"
SLIGWOLF_ADDON.Version = "1.1.0"

-- Modules
SLIGWOLF_ADDON:LuaInclude("module/developer.lua")
SLIGWOLF_ADDON:LuaInclude("module/luapad.lua")
SLIGWOLF_ADDON:LuaInclude("module/debug.lua")
SLIGWOLF_ADDON:LuaInclude("module/restart.lua")
SLIGWOLF_ADDON:LuaInclude("module/railscan.lua")
SLIGWOLF_ADDON:LuaInclude("module/giveall.lua")
SLIGWOLF_ADDON:LuaInclude("module/icongen.lua")

if SERVER then
	SLIGWOLF_ADDON:LuaInclude("module/sv/sv_physics.lua")
	SLIGWOLF_ADDON:LuaInclude("module/sv/sv_spawnpoint.lua")
end

return true

