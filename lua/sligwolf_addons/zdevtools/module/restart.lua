AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBNet = SligWolf_Addons.Net

local function restart()
	RunConsoleCommand("changelevel", game.GetMap())
end

if SERVER then
	LIBNet.AddNetworkString("zdevtools_restart_call")

	LIBNet.Receive("zdevtools_restart_call", function(ply)
		if SLIGWOLF_ADDON and not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then return end
		restart()
	end)
end

local function restartCmd(ply, command, args)
	if SLIGWOLF_ADDON and not SLIGWOLF_ADDON:IsValidDeveloperPlayerForCmd(ply) then
		return
	end

	if SERVER then
		restart()
	else
		LIBNet.Start("zdevtools_restart_call")
		LIBNet.SendToServer()
	end
end

local helptext = "Reloads the current map."
local helptextAlias = "Reloads the current map. Alias of 'dev_sligwolf_zdevtools_restart_server'."

concommand.Add("dev_sligwolf_zdevtools_restart_server", restartCmd, nil, helptext)

-- aliases for fast access
concommand.Add("restart_server", restartCmd, nil, helptextAlias)
concommand.Add("server_restart", restartCmd, nil, helptextAlias)
concommand.Add("reload_server", restartCmd, nil, helptextAlias)
concommand.Add("server_reload", restartCmd, nil, helptextAlias)

concommand.Add("restart", restartCmd, nil, helptextAlias)

return true

