local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBHook = SligWolf_Addons.Hook
local LIBConvar = SligWolf_Addons.Convar

-- Docs of defaults: https://wiki.facepunch.com/gmod/Structures/PhysEnvPerformanceSettings

local cvarFlags = bit.bor(FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_GAMEDLL)

local cvEnabled = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_enabled", {
	default = false,
	flags = cvarFlags,
})

local cvMaxVelocity = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_maxvelocity", {
	default = 4000,
	flags = cvarFlags,
})

local cvMaxAngularVelocity = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_maxangularvelocity", {
	default = 7272.7280273438,
	flags = cvarFlags,
})

local cvGravityX = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_gravity_x", {
	default = 0,
	flags = cvarFlags,
})

local cvGravityY = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_gravity_y", {
	default = 0,
	flags = cvarFlags,
})

local cvGravityZ = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_gravity_z", {
	default = 600,
	flags = cvarFlags,
})

local cvCollisionsPerObjectPerTimestep = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_collisions_object_timestep", {
	default = 10,
	flags = cvarFlags,
})

local cvCollisionsPerTimestep = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_collisions_timestep", {
	default = 50000,
	flags = cvarFlags,
})

local cvMinFrictionMass = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_minfrictionmass", {
	default = 10,
	flags = cvarFlags,
})

local cvMaxFrictionMass = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_maxfrictionmass", {
	default = 2500,
	flags = cvarFlags,
})

local cvAirDensity = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_airdensity", {
	default = 2,
	flags = cvarFlags,
})

local cvTimeScale = LIBConvar.AddConvar("phys_sligwolf_zdevtools_custom_timescale", {
	default = 1,
	flags = cvarFlags,
})

local g_defaults = SLIGWOLF_ADDON.PhysDefaults or {}
SLIGWOLF_ADDON.PhysDefaults = g_defaults

local function buildDefaults()
	if not table.IsEmpty(g_defaults) then
		return true
	end

	local settings = physenv.GetPerformanceSettings()
	if not settings then
		return false
	end

	g_defaults.airDensity = physenv.GetAirDensity()
	g_defaults.gravity = physenv.GetGravity()
	g_defaults.performanceSettings = settings
	g_defaults.timescale = physenv.GetTimeScale()

	return true
end

local function updatePerformanceSettings()
	if not buildDefaults() then
		return
	end

	local enabled = cvEnabled:GetBool()
	if not enabled then
		physenv.SetPerformanceSettings(g_defaults.performanceSettings)
		return
	end

	local settings = physenv.GetPerformanceSettings()

	settings.MaxVelocity = cvMaxVelocity:GetFloat()
	settings.MaxAngularVelocity = cvMaxAngularVelocity:GetFloat()
	settings.MinFrictionMass = cvMinFrictionMass:GetFloat()
	settings.MaxFrictionMass = cvMaxFrictionMass:GetFloat()
	settings.MaxCollisionsPerObjectPerTimestep = cvCollisionsPerObjectPerTimestep:GetInt()
	settings.MaxCollisionChecksPerTimestep = cvCollisionsPerTimestep:GetInt()

	physenv.SetPerformanceSettings(settings)
end

local function updateGravity()
	if not buildDefaults() then
		return
	end

	local enabled = cvEnabled:GetBool()
	local gravity = nil

	if enabled then
		gravity = Vector(
			-cvGravityX:GetFloat(),
			-cvGravityY:GetFloat(),
			-cvGravityZ:GetFloat()
		)
	else
		gravity = Vector(
		 	0,
		 	0,
		 	-LIBConvar.GetValue("sv_gravity")
		)
	end

	local oldGravity = physenv.GetGravity()
	if oldGravity == gravity then
		return
	end

	physenv.SetGravity(gravity)
end

local function updateAirDensity()
	if not buildDefaults() then
		return
	end

	local enabled = cvEnabled:GetBool()
	local airDensity = enabled and cvAirDensity:GetFloat() or g_defaults.airDensity

	local oldAirDensity = physenv.GetAirDensity()
	if oldAirDensity == airDensity then
		return
	end

	physenv.SetAirDensity(airDensity)
end

local function updateTimeScale()
	if not buildDefaults() then
		return
	end

	local enabled = cvEnabled:GetBool()
	local timescale = enabled and cvTimeScale:GetFloat() or g_defaults.timescale

	local oldTimescale = physenv.GetTimeScale()
	if oldTimescale == timescale then
		return
	end

	physenv.SetTimeScale(timescale)
end

local function updateAll()
	if not buildDefaults() then
		return
	end

	updatePerformanceSettings()
	updateGravity()
	updateAirDensity()
	updateTimeScale()
end

LIBHook.Add("InitPostEntity", "Addon_ZDevTools_Physics_InitPhysicsSettings", updateAll)

LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_enabled", updateAll)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_maxvelocity", updatePerformanceSettings)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_maxangularvelocity", updatePerformanceSettings)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_collisions_object_timestep", updatePerformanceSettings)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_collisions_timestep", updatePerformanceSettings)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_minfrictionmass", updatePerformanceSettings)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_maxfrictionmass", updatePerformanceSettings)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_gravity_x", updateGravity)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_gravity_y", updateGravity)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_gravity_z", updateGravity)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_airdensity", updateAirDensity)
LIBConvar.AddChangeCallback("phys_sligwolf_zdevtools_custom_timescale", updateTimeScale)

local function printSettingsCmd(ply, command, args)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayerForCmd(ply) then
		return
	end

	local settings = {}

	settings.airDensity = physenv.GetAirDensity()
	settings.gravity = physenv.GetGravity()
	settings.performanceSettings = physenv.GetPerformanceSettings()
	settings.timescale = physenv.GetTimeScale()

	PrintTable(settings)
end

concommand.Add("phys_sligwolf_zdevtools_print_settings", printSettingsCmd)

local function printDefaultCmd(ply, command, args)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayerForCmd(ply) then
		return
	end

	if not buildDefaults() then
		return
	end

	PrintTable(g_defaults)
end

concommand.Add("phys_sligwolf_zdevtools_print_default", printDefaultCmd)

return true

