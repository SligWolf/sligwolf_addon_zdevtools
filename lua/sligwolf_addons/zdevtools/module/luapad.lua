AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBHook = SligWolf_Addons.Hook

-- Docs on: https://github.com/wrefgtzweve/luapad

local function luapadDeveloper(ply)
	if SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return true
	end
end

LIBHook.Add("LuapadCanRunSV", "Addon_ZDevTools_Luapad_Developer", luapadDeveloper)
LIBHook.Add("LuapadCanRunCL", "Addon_ZDevTools_Luapad_Developer", luapadDeveloper)


-- Available custom globals in the Luapad environment:
--------------------------------------------------------
-- _G.this          | The entiy you are aiming at. Stock variable of Luapad.
-- _G.sw.lib        | SligWolf_Addons
-- _G.sw.const      | SligWolf_Addons.CONSTANTS
-- _G.sw.debug      | SligWolf_Addons.Debug
-- _G.sw.base       | SligWolf_Addons.BASE_ADDON
-- _G.sw.dev        | SligWolf_Addons.DEV_ADDON
-- _G.sw.debugger   | First debugger player. SligWolf_Addons.Debug.GetDebugPlayer()
-- _G.sw.developer  | First developer player. SligWolf_Addons.DEV_ADDON:GetFirstDeveloperPlayer()
-- _G.sw.fbplayer   | First player, hosts/admins prioritized. SligWolf_Addons.Util:GetFailbackPlayer()
-- _G.sw.addon      | Addon of _G.this.
-- _G.sw.addonname  | Addonname of _G.this.
-- _G.sw.sp 		| superparent of of _G.this. LIBEntities.GetSuperParent(_G.this)

local function luapadEnvironment(ply, env)
	local lib = _G.SligWolf_Addons
	if not lib then
		return
	end

	local libConstants = lib.Constants
	if not libConstants then
		return
	end

	local libDebug = lib.Debug
	if not libDebug then
		return
	end

	local baseAddon = lib.BASE_ADDON
	if not baseAddon then
		return
	end

	local libUtil = lib.Util
	if not libUtil then
		return
	end

	local libEntities = lib.Entities
	if not libEntities then
		return
	end

	local devAddon = lib.DEV_ADDON
	local developer = devAddon and devAddon:GetFirstDeveloperPlayer()
	local debugger = libDebug.GetDebugPlayer()
	local fbplayer = libUtil:GetFailbackPlayer()

	local sw = {}
	sw.lib = lib

	sw.const = libConstants
	sw.debug = libDebug
	sw.base = baseAddon
	sw.dev = devAddon

	if IsValid(debugger) then
		sw.debugger = debugger
	end

	if IsValid(developer) then
		sw.developer = developer
	end

	if IsValid(fbplayer) then
		sw.fbplayer = fbplayer
	end

	local ent = env.this
	if IsValid(ent) then
		local sp = libEntities.GetSuperParent(ent)

		if IsValid(sp) then
			sw.sp = sp
		end

		local addon = lib.GetAddonFromEntity(ent)
		if addon then
			sw.addon = addon
			sw.addonname = addon.Addonname
		end
	end

	env.sw = sw
end

LIBHook.Add("LuapadCustomizeEnv", "Addon_ZDevTools_Luapad_Environment", luapadEnvironment)

return true

