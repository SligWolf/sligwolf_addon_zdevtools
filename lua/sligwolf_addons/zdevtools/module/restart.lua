AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBConvar = SligWolf_Addons.Convar
local LIBNet = SligWolf_Addons.Net

local function restart()
	RunConsoleCommand("changelevel", game.GetMap())
end

if SERVER then
	LIBNet.AddNetworkString("zdevtools_restart_call")

	LIBNet.Receive("zdevtools_restart_call", function(len, ply)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			return
		end

		restart()
	end)
end

local function restartCmd(ply, command, args)
	if SERVER then
		restart()
	else
		LIBNet.Start("zdevtools_restart_call")
		LIBNet.SendToServer()
	end
end

local params = {
	flags = bit.bor(FCVAR_GAMEDLL, FCVAR_CLIENTDLL, FCVAR_CLIENTCMD_CAN_EXECUTE),
	role = SLIGWOLF_ADDON.ROLE_DEVELOPER,
	callback = restartCmd,
	help = "Reloads the current map.",
}

local paramsAlias = table.Copy(params)
paramsAlias.help = "Reloads the current map. Alias of \x04'dev_sligwolf_zdevtools_restart_server'\x03.",

LIBConvar.AddCommand("dev_sligwolf_zdevtools_restart_server", params)

-- aliases for fast access
LIBConvar.AddCommand("restart_server", paramsAlias)
LIBConvar.AddCommand("server_restart", paramsAlias)
LIBConvar.AddCommand("reload_server", paramsAlias)
LIBConvar.AddCommand("server_reload", paramsAlias)

LIBConvar.AddCommand("restart", paramsAlias)

return true

