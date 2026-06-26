AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBConvar = SligWolf_Addons.Convar
local LIBDebug = SligWolf_Addons.Debug
local LIBUtil = SligWolf_Addons.Util
local LIBHook = SligWolf_Addons.Hook

local cvarFlags = bit.bor(FCVAR_GAMEDLL, FCVAR_REPLICATED, FCVAR_DONTRECORD)

LIBConvar.AddConvar("dev_sligwolf_zdevtools_developers_enabled", {
	default = false,
	flags = cvarFlags,
	help = "(DANGEROUS, do not use in production!) Enable sv_sligwolf_zdevtools_developers. See 'help sv_sligwolf_zdevtools_developers'. This is not saved. 0 = Disabled, 1 = Enabled, Default: 0",
})

LIBConvar.AddConvar("dev_sligwolf_zdevtools_developers", {
	default = "",
	flags = cvarFlags,
	help = "(DANGEROUS, do not use in production!) Space separated list of player names to be considered as 'SW Addons'-developer (Can run server code, via Luapad!). This is usefull for '-multirun' session testing. This is not saved. Default: (empty)",
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
	local pattern = "^" .. escapedSearch .. "%s*%(?%d*%)?$"

	-- Using steam id does not work for multirun instances, so match the player's nicknames.
	-- Matches player names and their multirun variations, case-insensitive. Example for SligWolf:
	--  SligWolf,
	--	SligWolf(1),
	--	SligWolf(2),
	--	SligWolf (1),
	--	SligWolf (2)

	if string.match(playerName, pattern) then
		return true
	end

	return false
end

-- Check if the player is a developer.
function SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply)
	if not IsValid(ply) then
		return false
	end

	if LIBDebug.IsValidDebugPlayer(ply) then
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
	if LIBUtil.IsAdminForCMD(ply) then
		return true
	end

	if SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return true
	end

	return false
end

-- Gets the first a developer player.
function SLIGWOLF_ADDON:GetFirstDeveloperPlayer()
	if self:IsValidDeveloperPlayer(self.Developer) then
		return self.Developer
	end

	self.Developer = nil

	local debugPly = LIBDebug.GetDebugPlayer()
	if self:IsValidDeveloperPlayer(debugPly) then
		self.Developer = debugPly
		return debugPly
	end

	for _, ply in player.Iterator() do
		if not self:IsValidDeveloperPlayer(ply) then
			continue
		end

		self.Developer = ply
		return self.Developer
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

