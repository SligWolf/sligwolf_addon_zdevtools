AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBEntities = SligWolf_Addons.Entities
local LIBHook = SligWolf_Addons.Hook

local LIBIconGenerator = SLIGWOLF_ADDON.IconGenerator

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

		PrintTable(workloadEntry)
	end, nil, nil, cvarFlags)
end

local g_iconGenerator = LIBIconGenerator.NewInstance("test")

g_iconGenerator.OnProgress = function(this, currentIndex, workloadCount)
	MsgN("g_iconGenerator OnProgress ", currentIndex, " ", workloadCount)
end

g_iconGenerator.OnProgressDone = function(this, currentIndex, workloadCount)
	MsgN("g_iconGenerator OnProgressDone ", currentIndex, " ", workloadCount)
end

g_iconGenerator.OnStart = function(this)
	MsgN("g_iconGenerator OnStart ")
end

g_iconGenerator.OnCancel = function(this)
	MsgN("g_iconGenerator OnCancel ")
end

g_iconGenerator.OnFinished = function(this)
	MsgN("g_iconGenerator OnFinished ")
end

g_iconGenerator.OnTimeout = function(this)
	MsgN("g_iconGenerator OnTimeout ")
end

g_iconGenerator.OnSpawn = function(this, ent)
	MsgN("g_iconGenerator OnSpawn ", ent)
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

	concommand.Add("dev_sligwolf_zdevtools_icongen_start", function(ply)
		if not IsValid(g_iconGenerator) then
			return
		end

		g_iconGenerator:Initialize(ply)

		g_iconGenerator:AddWorkload(workload)

		g_iconGenerator:Start()
	end)

	concommand.Add("dev_sligwolf_zdevtools_icongen_stop", function(ply)
		if not IsValid(g_iconGenerator) then
			return
		end

		g_iconGenerator:Cancel()
	end)
else
	local function clientInit()
		if not IsValid(LocalPlayer()) then
			return
		end

		g_iconGenerator:Initialize()
		g_iconGenerator:Start()
	end

	LIBHook.Add("InitPostEntity", "Addon_ZDevTools_Icongen_ClientInit", clientInit)
	clientInit()
end

return true

