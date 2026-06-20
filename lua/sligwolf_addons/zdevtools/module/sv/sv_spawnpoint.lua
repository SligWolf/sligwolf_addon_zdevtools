local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBPrint = SligWolf_Addons.Print
local LIBHook = SligWolf_Addons.Hook

local function setSpawnpoint(ply, command, args)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then return end

	local plyTable = ply:SligWolf_GetTable()

	plyTable.devSpawnPoint = ply:GetPos()
	plyTable.devSpawnAngle = ply:GetAngles()

	local message = LIBPrint.FormatMessage("Spawnpoint set.")
	LIBPrint.Notify(LIBPrint.NOTIFY_GENERIC, message, 5, ply)
end

local function removeSpawnpoint(ply, command, args)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	local plyTable = ply:SligWolf_GetTable()

	if not plyTable.devSpawnPoint and not plyTable.devSpawnAngle then
		return
	end

	plyTable.devSpawnPoint = nil
	plyTable.devSpawnAngle = nil

	local message = LIBPrint.FormatMessage("Spawnpoint removed.")
	LIBPrint.Notify(LIBPrint.NOTIFY_GENERIC, message, 5, ply)
end

local function removeAllSpawnpoints(ply, command, args)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayerForCmd(ply) then
		return
	end

	for _, v in player.Iterator() do
		removeSpawnpoint(v)
	end

	local message = LIBPrint.FormatMessage("All Spawnpoints removed.")
	MsgN(message)
end

local function playerSpawnOnSpawnpoint(ply)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	local plyTable = ply:SligWolf_GetTable()

	local devSpawnPoint = plyTable.devSpawnPoint
	local devSpawnAngle = plyTable.devSpawnAngle

	if not devSpawnPoint then
		return
	end

	if not devSpawnAngle then
		return
	end

	ply:SetPos(devSpawnPoint + Vector(0, 0, 16))
	ply:SetEyeAngles(devSpawnAngle)
end

concommand.Add("dev_sligwolf_zdevtools_spawnpoint_set", setSpawnpoint)
concommand.Add("dev_sligwolf_zdevtools_spawnpoint_remove", removeSpawnpoint)
concommand.Add("dev_sligwolf_zdevtools_spawnpoint_remove_all", removeAllSpawnpoints)

LIBHook.Add("PlayerSpawn", "Addon_ZDevTools_Spawnpoint_Spawn", playerSpawnOnSpawnpoint)

return true

