AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

SLIGWOLF_ADDON:LuaInclude("lib/icongen.lua")
SLIGWOLF_ADDON:LuaInclude("lib/icongen_hooks.lua")
SLIGWOLF_ADDON:LuaInclude("lib/icongen_parser.lua")

if SERVER then
	SLIGWOLF_ADDON:LuaInclude("lib/sv/sv_icongen.lua")

	SLIGWOLF_ADDON:AddCSLuaFile("lib/cl/cl_icongen.lua")
	SLIGWOLF_ADDON:AddCSLuaFile("lib/cl/cl_icongen_render.lua")
	SLIGWOLF_ADDON:AddCSLuaFile("lib/cl/cl_icongen_controls.lua")
end

if CLIENT then
	SLIGWOLF_ADDON:LuaInclude("lib/cl/cl_icongen.lua")
	SLIGWOLF_ADDON:LuaInclude("lib/cl/cl_icongen_render.lua")
	SLIGWOLF_ADDON:LuaInclude("lib/cl/cl_icongen_controls.lua")
end

local LIBEntities = SligWolf_Addons.Entities
local LIBHook = SligWolf_Addons.Hook

local LIBIconGenerator = SLIGWOLF_ADDON.IconGenerator
local LIBString = SligWolf_Addons.String
local LIBTimer = SligWolf_Addons.Timer
local LIBFile = SligWolf_Addons.File

local function log(format, ...)
	local text = string.format(format, ...)
	local line = ""

	local now = LIBTimer.UnixSysTime()

	local sec = math.floor(now)
	local msec = math.floor(now * 1000) % 100

	local time = string.format(
		"%s.%03d",
		os.date("%Y-%m-%d %H:%M:%S", sec),
		msec
	)

	if SERVER then
		line = string.format("[%s][SV] %s\n", time, text)
	else
		line = string.format("[%s][CL] %s\n", time, text)
	end

	local filename = "icongen/log.txt"

	LIBFile.Log(filename, line, SLIGWOLF_ADDON)

	Msg(filename .. " > ")
	MsgC(Color(220, 220, 255), line)
end

local g_iconGenerator = LIBIconGenerator.NewInstance("g_iconGenerator")

g_iconGenerator.OnProgress = function(this, currentIndex, workloadCount)
	if SERVER then
		local addonname = this.currentAddonname or "?"
		local category = this.currentCategory or "?"
		local spawnname = this.currentSpawnname or "?"
		local theme = this.currentTheme or "?"

		log("OnProgress: %05i / %05i | %s, %s, %s, %s",
			currentIndex, workloadCount,
			addonname, category, spawnname, theme
		)
	else
		log("OnProgress: %05i / %05i",
			currentIndex, workloadCount
		)
	end
end

g_iconGenerator.OnProgressDone = function(this, currentIndex, workloadCount)
	if SERVER then
		local addonname = this.currentAddonname or "?"
		local category = this.currentCategory or "?"
		local spawnname = this.currentSpawnname or "?"
		local theme = this.currentTheme or "?"

		log("OnProgressDone: %05i / %05i | %s, %s, %s, %s",
			currentIndex, workloadCount,
			addonname, category, spawnname, theme
		)
	else
		log("OnProgressDone: %05i / %05i",
			currentIndex, workloadCount
		)
	end
end

g_iconGenerator.OnStart = function(this)
	log("OnStart: %i items found", this.entriesTotal or 0)
end

g_iconGenerator.OnFinished = function(this)
	local entriesTotal = this.entriesTotal or 0
	local entriesRun = this.entriesRun or 0
	local entriesDone = this.entriesDone or 0
	local entriesError = this.entriesError or 0

	log(
		"OnFinished | total %i, run %i, done %i, error %i",
		entriesTotal,
		entriesRun,
		entriesDone,
		entriesError
	)
end

g_iconGenerator.OnCancel = function(this)
	local entriesTotal = this.entriesTotal or 0
	local entriesRun = this.entriesRun or 0
	local entriesDone = this.entriesDone or 0
	local entriesError = this.entriesError or 0

	log(
		"OnCancel | total %i, run %i, done %i, error %i",
		entriesTotal,
		entriesRun,
		entriesDone,
		entriesError
	)
end

g_iconGenerator.OnSpawn = function(this, ent)
	if SERVER then
		local addonname = this.currentAddonname or "?"
		local category = this.currentCategory or "?"
		local spawnname = this.currentSpawnname or "?"
		local theme = this.currentTheme or "?"

		log("OnSpawn: %s | %s, %s, %s, %s",
			tostring(ent),
			addonname, category, spawnname, theme
		)
	end
end

g_iconGenerator.OnFileWritten = function(this, path, absoluteFilename)
	log("OnFileWritten: 'data/%s'", absoluteFilename)
end

g_iconGenerator.OnReset = function(this)
	log("OnReset")
end

g_iconGenerator.OnTimeout = function(this)
	log("ERROR: OnTimeout")
end

g_iconGenerator.OnEarlyEntityRemove = function(this)
	log("ERROR: OnEarlyEntityRemove")
end

g_iconGenerator.OnWarn = function(this, err)
	log("ERROR: %s", err)
end

if CLIENT then
	local cvarFlags = bit.bor(FCVAR_CLIENTDLL, FCVAR_DONTRECORD)

	concommand.Add("dev_sligwolf_zdevtools_icongen_snapshot", function(ply)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			return
		end

		local workloadEntry = LIBIconGenerator.EstimateViewWorkloadEntry()
		if not workloadEntry then
			return
		end

		LIBIconGenerator.PrintSnapshotToConsole(workloadEntry)
	end, nil, nil, cvarFlags)

	local function clientInit()
		if not IsValid(LocalPlayer()) then
			return
		end

		ProtectedCall(function()
			g_iconGenerator:Initialize()
			g_iconGenerator:Start()
		end)
	end

	LIBHook.Add("InitPostEntity", "Addon_ZDevTools_Icongen_ClientInit", clientInit)
	clientInit()
end

if SERVER then
	local workload = {
		{
			map = "gm_construct_flatgrass_v6-2",
			category = LIBEntities.SPAWN_CATEGORY_VEHICLE,
			spawnname = "sligwolf_westernloco_wl13_loco_phx",
			theme = "all",
			camera = {
				pos = Vector(10919, 5524, -248),
				ang = Angle(18, 0, 0),
				fov = 90,
				dof = {
					distance = 1024,
					blur = 0.5,
					passes = 12,
					steps = 24,
					shape = 0.5,
				}
			},
			entity = {
				pos = Vector(11210, 5531.15, -416.32),
				ang = Angle(0.1, 179.99, 0.13),
			},
		},
		{
			map = "gm_construct_flatgrass_v6-2",
			category = LIBEntities.SPAWN_CATEGORY_WEAPON,
			spawnname = "sligwolf_weapon_motorbike_mg34",
			theme = "default",
			camera = {
				pos = Vector(9837.17, 4920.94, -252.80),
				ang = Angle(10.12, -90.15, 0),
				fov = 28.66,
				dof = {
					distance = 200,
					blur = 0.5,
					passes = 12,
					steps = 24,
					shape = 0.5,
				}
			},
			entity = {
				pos = Vector(9833.09, 4718.68, -288.25),
				ang = Angle(13.77, 7, -21.36),
			},
		},
		{
			map = "gm_construct_flatgrass_v6-2",
			category = LIBEntities.SPAWN_CATEGORY_NPC,
			spawnname = "sligwolf_germancop_rebel",
			theme = "default",
			camera = {
				pos = Vector(9859.69, 4820.43, -339.96),
				ang = Angle(-0.71, -89.56, 0),
				fov = 25.69,
				dof = {
					distance = 100,
					blur = 0.5,
					passes = 12,
					steps = 24,
					shape = 0.5,
				}
			},
			entity = {
				pos = Vector(9860.30, 4714, -399.96),
				ang = Angle(0, 89.14, 0),
			},
		},
		-- {
		-- 	map = "gm_construct_flatgrass_v6-2",
		-- 	category = LIBEntities.SPAWN_CATEGORY_VEHICLE,
		-- 	spawnname = "sligwolf_bus_b13",
		-- 	theme = "default",
		-- 	camera = {
		-- 		pos = Vector(9546.06, 6368.25, -242.6),
		-- 		ang = Angle(24, 75, 0),
		-- 		fov = 90,
		-- 		dof = {
		-- 			distance = 1024,
		-- 			blur = 0.5,
		-- 			passes = 12,
		-- 			steps = 24,
		-- 			shape = 0.5,
		-- 		}
		-- 	},
		-- 	entity = {
		-- 		pos = Vector(9591.06, 6662.25, -404.188),
		-- 		ang = Angle(0.24, -119.55, -0.02),
		-- 		spawnFrozen = false,
		-- 		wait = 1,
		-- 	},
		-- },
		-- {
		-- 	map = "gm_construct_flatgrass_v6-2",
		-- 	category = LIBEntities.SPAWN_CATEGORY_VEHICLE,
		-- 	spawnname = {"sligwolf_bus_b25", "sligwolf_bus_b13"},
		-- 	theme = "blue",
		-- 	camera = {
		-- 		pos = Vector(9546.06, 6368.25, -242.6),
		-- 		ang = Angle(24, 75, 0),
		-- 		fov = 90,
		-- 		dof = {
		-- 			distance = 1024,
		-- 			blur = 0.5,
		-- 			passes = 12,
		-- 			steps = 24,
		-- 			shape = 0.5,
		-- 		}
		-- 	},
		-- 	entity = {
		-- 		pos = Vector(9591.06, 6662.25, -403.6 + 100),
		-- 		ang = Angle(0.24, -119.55, -0.02),
		-- 		spawnFrozen = true,
		-- 		wait = 0,
		-- 	},
		-- },

		-- {
		-- 	map = "gm_construct_flatgrass_v6-2",
		-- 	category = LIBEntities.SPAWN_CATEGORY_VEHICLE,
		-- 	spawnname = "sligwolf_bluex11",
		-- 	theme = "all",
		-- 	camera = {
		-- 		pos = Vector(10728.534, 6324.922, -1.496),
		-- 		ang = Angle(20.567, 140.653, 0.000),
		-- 		fov = 15,
		-- 		dof = {
		-- 			distance = 1005.74,
		-- 			blur = 0.5,
		-- 			passes = 12,
		-- 			steps = 24,
		-- 			shape = 0.5,
		-- 		}
		-- 	},
		-- 	entity = {
		-- 		pos = Vector(9989.93, 6940.40, -404.50),
		-- 		ang = Angle(0.13, -166.37, -2),
		-- 		freeze = false,
		-- 	},
		-- },
		-- Add more entries...
	}

	concommand.Add("dev_sligwolf_zdevtools_icongen_start", function(ply, cmd, args)
		if not IsValid(g_iconGenerator) then
			return
		end

		local spawnname = string.lower(string.Trim(tostring(args[1] or "")))
		local theme = string.lower(string.Trim(tostring(args[2] or "")))

		if spawnname == "" or spawnname == "all" then
			spawnname = "*"
		end

		if theme == "" or theme == "all" then
			theme = "*"
		end

		if theme == "all" then
			theme = "*"
		end

		g_iconGenerator:Initialize(ply)

		g_iconGenerator:AddWorkloadFilter("cmd_parameter_wildcard", function(item)
			local itemSpawnname = string.lower(string.Trim(item.spawnname))
			local itemTheme = string.lower(string.Trim(item.theme))

			if not LIBString.WildcardMatch(itemSpawnname, spawnname) then
				return false
			end

			if not LIBString.WildcardMatch(itemTheme, theme) then
				return false
			end
		end)

		g_iconGenerator:AddWorkload(workload)

		g_iconGenerator:Start()
	end)

	concommand.Add("dev_sligwolf_zdevtools_icongen_cancel", function(ply)
		if not IsValid(g_iconGenerator) then
			return
		end

		g_iconGenerator:Cancel()
	end)
end

return true

