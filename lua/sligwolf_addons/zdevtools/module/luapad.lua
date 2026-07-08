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
-- _G.sw.dev        | First developer player. SligWolf_Addons.DEV_ADDON:GetFirstDeveloperPlayer()
-- _G.sw.host       | Host player. SligWolf_Addons.Player.GetHostPlayer()
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

	local addonDev = lib.DEV_ADDON
	local libPlayer = lib.Player
	local libEntities = lib.Entities

	local dev = nil
	local host = nil
	local fbplayer = nil

	if addonDev then
		dev = addonDev:GetFirstDeveloperPlayer()
	end

	if libPlayer then
		host = libPlayer.GetHostPlayer()
		fbplayer = libPlayer.GetFailbackPlayer()
	end

	local sw = {}
	sw.lib = lib

	sw.const = libConstants
	sw.debug = libDebug

	if IsValid(dev) then
		sw.dev = dev
	end

	if IsValid(host) then
		sw.host = host
	end

	if IsValid(fbplayer) then
		sw.fbplayer = fbplayer
	end

	local ent = env.this

	if IsValid(ent) then
		if libEntities then
			local sp = libEntities.GetSuperParent(ent)

			if IsValid(sp) then
				sw.sp = sp
			end
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

