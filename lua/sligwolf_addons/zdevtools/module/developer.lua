AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

SLIGWOLF_ADDON.ROLE_DEVELOPER = "developer"
SLIGWOLF_ADDON.ROLE_DEVELOPER_PLAYER = "developer_player"

local LIBConvar = SligWolf_Addons.Convar
local LIBPlayer = SligWolf_Addons.Player
local LIBPrint = SligWolf_Addons.Print
local LIBHook = SligWolf_Addons.Hook

local cvarFlags = bit.bor(FCVAR_GAMEDLL, FCVAR_REPLICATED, FCVAR_DONTRECORD)

LIBConvar.AddConvar("dev_sligwolf_zdevtools_developers_enabled", {
	default = false,
	flags = cvarFlags,
	help = "\x06(DANGEROUS, do not use in production!)\x03 Enables \x04'sv_sligwolf_zdevtools_developers'\x03. See \x04'help sv_sligwolf_zdevtools_developers'\x03. This is not saved to config.",
})

LIBConvar.AddConvar("dev_sligwolf_zdevtools_developers", {
	default = "",
	flags = cvarFlags,
	help = "\x06(DANGEROUS, do not use in production!)\x03 Space separated list of player names to be considered as 'SW Addons'-developer. \x06(Can run server code, via Luapad!)\x03 This is useful for \x04'-multirun'\x03 session testing. This is not saved to config.",
	helpSyntax = "[<playername 1>] [<playername 2>] ... [<playername N>]",
})

SLIGWOLF_ADDON.Developer = nil
SLIGWOLF_ADDON.DeveloperNames = {}
SLIGWOLF_ADDON.DeveloperNamesEnabled = {}

LIBConvar.AddChangeCallback("dev_sligwolf_zdevtools_developers_enabled", function(value)
	SLIGWOLF_ADDON.Developer = nil
	SLIGWOLF_ADDON.DeveloperNamesEnabled = value
end)

LIBConvar.AddChangeCallback("dev_sligwolf_zdevtools_developers", function(value)
	SLIGWOLF_ADDON.Developer = nil

	value = string.lower(string.Trim(value))
	value = string.Explode("%s+", value)

	table.CopyFromTo(value, SLIGWOLF_ADDON.DeveloperNames)
end)

LIBConvar.AddCommandRole(SLIGWOLF_ADDON.ROLE_DEVELOPER, {
	title = "Developer only",
	callback = function(ply, cmd, args)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayerForCmd(ply) then
			LIBPrint.PrintForPlayer(ply, "This is developer only.")
			return false
		end

		return true
	end,
})

LIBConvar.AddCommandRole(SLIGWOLF_ADDON.ROLE_DEVELOPER_PLAYER, {
	title = "Developer player only",
	callback = function(ply, cmd, args)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			LIBPrint.PrintForPlayer(ply, "This is developer player only.")
			return false
		end

		return true
	end,
})

-- Matches player names to their name variations when they are joined as a -multirun session.
local function matchPlayerNameMultirunVariations(playerName, searchName)
	playerName = string.lower(string.Trim(playerName))
	searchName = string.lower(string.Trim(searchName))

	if playerName == "" then
		return false
	end

	if searchName == "" then
		return false
	end

	local escapedSearch = string.PatternSafe(searchName)
	local pattern = "^%(?%d*%)?%s*" .. escapedSearch .. "%s*%(?%d*%)?$"

	-- Using steam id does not work for multirun instances, so match the player's nicknames.
	-- Matches player names and their multirun variations, case-insensitive. Example for SligWolf:
	--  SligWolf,
	--	SligWolf(1),
	--	SligWolf (1),
	--	(1)SligWolf,
	--	(1) SligWolf,
	--	(1)SligWolf(1),
	--	(1) SligWolf (1),

	if string.match(playerName, pattern) then
		return true
	end

	return false
end

-- Check if the player is a developer.
function SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply)
	if CLIENT and ply == nil then
		ply = LocalPlayer()
	end

	if not IsValid(ply) then
		return false
	end

	if LIBPlayer.IsHostPlayer(ply) then
		return true
	end

	if ply:IsBot() then
		return false
	end

	if ply:IsSuperAdmin() then
		return true
	end

	if not self.DeveloperNamesEnabled then
		return false
	end

	local developerNames = self.DeveloperNames
	if not developerNames then
		return false
	end

	local playerName = string.lower(string.Trim(ply:Nick()))

	for key, developerName in ipairs(developerNames) do
		if matchPlayerNameMultirunVariations(playerName, developerName) then
			return true
		end
	end

	return false
end

function SLIGWOLF_ADDON:IsValidDeveloperPlayerForCmd(ply)
	if LIBPlayer.IsAdminForCMD(ply) then
		return true
	end

	if SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return true
	end

	return false
end

local g_developerPlayer = nil

-- Gets the first a developer player.
function SLIGWOLF_ADDON:GetFirstDeveloperPlayer()
	if g_developerPlayer and self:IsValidDeveloperPlayer(g_developerPlayer) then
		return g_developerPlayer
	end

	g_developerPlayer = nil

	local hostPly = LIBPlayer.GetHostPlayer()
	if hostPly and self:IsValidDeveloperPlayer(hostPly) then
		g_developerPlayer = hostPly
		return hostPly
	end

	for _, ply in player.Iterator() do
		if not ply then
			continue
		end

		if not self:IsValidDeveloperPlayer(ply) then
			continue
		end

		g_developerPlayer = ply
		return g_developerPlayer
	end

	return nil
end

local function blockSwitchWeaponForNonDev(ply, oldWeapon, newWeapon)
	if not IsValid(ply) then
		return
	end

	if not newWeapon.DeveloperOnly then
		return
	end

	if SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	return true
end

LIBHook.Add("PlayerSwitchWeapon", "Addon_ZDevTools_Developer_BlockDeveloperOnlyWeapons", blockSwitchWeaponForNonDev)

local function preventItemPickup(ply, item)
	if not IsValid(ply) then
		return
	end

	if not item.DeveloperOnly then
		return
	end

	if SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	return false
end

LIBHook.Add("PlayerCanPickupItem", "Addon_ZDevTools_Developer_BlockDeveloperOnlyWeapons", preventItemPickup)
LIBHook.Add("PlayerCanPickupWeapon", "Addon_ZDevTools_Developer_BlockDeveloperOnlyWeapons", preventItemPickup)

return true

