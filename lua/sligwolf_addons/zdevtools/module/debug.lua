AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBHook = SligWolf_Addons.Hook
local LIBDebug = SligWolf_Addons.Debug
local LIBConvar = SligWolf_Addons.Convar

function SLIGWOLF_ADDON:IsDebugKeyDown(ply, key)
	if not IsValid(ply) then
		return false
	end

	-- Debug control modifier, hold ALT + SHIFT (default)
	if not ply:KeyDown(IN_WALK) then
		return false
	end

	if not ply:KeyDown(IN_SPEED) then
		return false
	end

	if not inKey then
		return true
	end

	-- Debug control key
	if not ply:KeyDown(inKey) then
		return false
	end

	return true
end

if SERVER then
	local cvDebugMode = LIBConvar.GetConvar("sv_sligwolf_addons_debug_mode")
	local cvDebugTraceEnable = LIBConvar.GetConvar("sv_sligwolf_addons_debug_trace_enable")

	local function playSwitchSound(ply, soundFile, recipientFilter)
		ply:EmitSound(
			soundFile,
			75, 100, 1,
			CHAN_AUTO,
			0, 1,
			recipientFilter
		)
	end

	local function switchDebugMode(ply)
		local debugMode = LIBDebug.GetDebugMode()

		local sendThisPlayerOnly = RecipientFilter()
		sendThisPlayerOnly:RemoveAllPlayers()
		sendThisPlayerOnly:AddPlayer(ply)

		local message = nil

		if debugMode == LIBDebug.ENUM_DEBUG_MODE_DISABLED then
			cvDebugMode:SetInt(LIBDebug.ENUM_DEBUG_MODE_SHARED)
			message = LIBPrint.FormatMessage("Debug Mode: Shared")
		elseif debugMode == LIBDebug.ENUM_DEBUG_MODE_SHARED then
			cvDebugMode:SetInt(LIBDebug.ENUM_DEBUG_MODE_SERVER)
			message = LIBPrint.FormatMessage("Debug Mode: Server")
		elseif debugMode == LIBDebug.ENUM_DEBUG_MODE_SERVER then
			cvDebugMode:SetInt(LIBDebug.ENUM_DEBUG_MODE_CLIENT)
			message = LIBPrint.FormatMessage("Debug Mode: Client")
		elseif debugMode == LIBDebug.ENUM_DEBUG_MODE_CLIENT then
			cvDebugMode:SetInt(LIBDebug.ENUM_DEBUG_MODE_DISABLED)
			message = LIBPrint.FormatMessage("Debug Mode: Disabled")
		end

		LIBConvar.Refresh()

		LIBPrint.Notify(LIBPrint.NOTIFY_GENERIC, message, 3, sendThisPlayerOnly)
		playSwitchSound(ply, "eli_lab.al_buttonmash", sendThisPlayerOnly)
	end

	local function switchDebugTracerMode(ply)
		local tracerEnabled = LIBDebug.GetDebugTraceEnabled()

		local sendThisPlayerOnly = RecipientFilter()
		sendThisPlayerOnly:RemoveAllPlayers()
		sendThisPlayerOnly:AddPlayer(ply)

		local message = nil

		if tracerEnabled then
			cvDebugTraceEnable:SetBool(false)
			message = LIBPrint.FormatMessage("Debug Tracer: Disabled")
		else
			cvDebugTraceEnable:SetBool(true)
			message = LIBPrint.FormatMessage("Debug Tracer: Enabled")
		end

		LIBConvar.Refresh()

		LIBPrint.Notify(LIBPrint.NOTIFY_GENERIC, message, 3, sendThisPlayerOnly)
		playSwitchSound(ply, "eli_lab.al_buttonmash", sendThisPlayerOnly)
	end

	LIBHook.Add("KeyPress", "Addon_ZDevTools_Debug_ModeSwitch", function(ply, key)
		if not LIBDebug.IsValidDebugPlayer(ply) then
			return
		end

		if LIBConvar.GetValue("developer") > 0 then
			return
		end

		if not SLIGWOLF_ADDON:IsDebugKeyDown(ply) then
			return
		end

		-- Switch debug mode by holding ALT, SHIFT and E (default)
		if ply:KeyDown(IN_USE) then
			switchDebugMode(ply)
			return
		end

		-- Switch debug tracers by holding ALT, SHIFT and Z (default)
		if ply:KeyDown(IN_ZOOM) then
			switchDebugTracerMode(ply)
			return
		end
	end)

	local helptext = "Show SW-Names of all SligWolf Addons entities for 60 secounds. This requires 'developer 1' or above. Params: all, console"
	local cvarFlags = bit.bor(FCVAR_GAMEDLL, FCVAR_DONTRECORD)

	concommand.Add("dev_sligwolf_addons_show_entity_names", function(ply, cmd, args)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayerForCmd(ply) then
			return
		end

		if not LIBDebug.IsDeveloper() then
			return
		end

		local all = false
		local console = false

		for _, arg in ipairs(args) do
			arg = string.lower(arg or "")

			if arg == "all" then
				all = true
				continue
			end

			if arg == "console" then
				console = true
				continue
			end
		end

		local nextFrameFunc = function()
			local entities = {}

			if all then
				entities = ents.GetAll()
			else
				local tr = LIBTrace.PlayerAimTrace(ply, 5000)
				if tr and IsValid(tr.Entity) then
					entities = LIBEntities.GetSystemEntities(tr.Entity)
				end
			end

			if console then
				LIBDebug.PrintEntityNames(entities)
			else
				LIBDebug.ShowEntityNames(entities, console)
			end
		end

		if console then
			nextFrameFunc()
		else
			-- Call in next frame, as debugoverlay.* function are not rendered when triggered by concommand callbacks.
			SLIGWOLF_ADDON:TimerNextFrame("Debug_ShowEntityNames", nextFrameFunc)
		end
	end, nil, helptext, cvarFlags)
end

return true

