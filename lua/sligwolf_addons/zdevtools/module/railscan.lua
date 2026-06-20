AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local LIBRailscan = SligWolf_Addons.Railscan
local LIBConvar = SligWolf_Addons.Convar
local LIBDebug = SligWolf_Addons.Debug
local LIBTrace = SligWolf_Addons.Trace
local LIBRail = SligWolf_Addons.Rail
local LIBHook = SligWolf_Addons.Hook

local cvarFlags = bit.bor(FCVAR_GAMEDLL, FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_DONTRECORD)

LIBConvar.AddConvar("dev_sligwolf_zdevtools_railscan_enabled", {
	default = false,
	flags = cvarFlags,
	help = "Enable Railscan test output, requires 'developer 1' or above. 0 = Disabled, 1 = Enabled, Default: 0",
})

local LIB = SLIGWOLF_ADDON.RailscanTest or {}
SLIGWOLF_ADDON.RailscanTest = LIB

local g_lastAimTrace = LIB.lastAimTrace or {}
LIB.lastAimTrace = g_lastAimTrace

local function railScanThinkTest()
	if not LIBDebug.IsDeveloper() then
		return
	end

	local ply = LIBDebug.GetDebugPlayer()
	if not IsValid(ply) then
		return
	end

	local mode = LIB.mode or LIBRail.TRAIN_GAUGE_WP
	local retrace = false

	if ply:KeyDown(IN_USE) then
		retrace = true
	end

	if ply:KeyDown(IN_WALK) and ply:KeyDown(IN_JUMP) then
		mode = LIBRail.TRAIN_GAUGE_AUTO
	end

	if ply:KeyDown(IN_WALK) and ply:KeyDown(IN_DUCK) then
		mode = LIBRail.TRAIN_GAUGE_PHX
	end

	if ply:KeyDown(IN_WALK) and ply:KeyDown(IN_SPEED) then
		mode = LIBRail.TRAIN_GAUGE_WP
	end

	LIB.mode = mode

	if retrace then
		local aimTrace = LIBTrace.PlayerAimTrace(ply, 5000)
		if aimTrace and aimTrace.Hit then
			table.CopyFromTo(aimTrace, g_lastAimTrace)
		end
	end

	if g_lastAimTrace.Hit and mode then
		LIBDebug.SetLifetime(CLIENT and LIBDebug.DEBUG_LIFETIME_FRAME or LIBDebug.DEBUG_LIFETIME_DEFAULT)

		LIBRailscan.ScanRailWithGauge(ply, g_lastAimTrace, mode)

		LIBDebug.ResetLifetime()
	end
end

LIBConvar.AddChangeCallback("dev_sligwolf_zdevtools_railscan_enabled", function(value)
	if value then
		LIBHook.Add("Think", "Addon_ZDevTools_Railscan_Test", railScanThinkTest)
	else
		LIBHook.Remove("Think", "Addon_ZDevTools_Railscan_Test")
	end
end)

return true

