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
local LIBPrint = SligWolf_Addons.Print
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
	local addonname = this.currentAddonname or "?"
	local category = this.currentCategory or "?"
	local spawnname = this.currentSpawnname or "?"
	local theme = this.currentTheme or "?"

	log("OnProgress: %05i / %05i | %s, %s, %s, %s",
		currentIndex, workloadCount,
		addonname, category, spawnname, theme
	)
end

g_iconGenerator.OnProgressDone = function(this, currentIndex, workloadCount)
	local addonname = this.currentAddonname or "?"
	local category = this.currentCategory or "?"
	local spawnname = this.currentSpawnname or "?"
	local theme = this.currentTheme or "?"

	log("OnProgressDone: %05i / %05i | %s, %s, %s, %s",
		currentIndex, workloadCount,
		addonname, category, spawnname, theme
	)
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
	local addonname = this.currentAddonname or "?"
	local category = this.currentCategory or "?"
	local spawnname = this.currentSpawnname or "?"
	local theme = this.currentTheme or "?"

	log("OnSpawn: %s | %s, %s, %s, %s",
		tostring(ent),
		addonname, category, spawnname, theme
	)
end

g_iconGenerator.OnFileWritten = function(this, path, absolutePath)
	log("OnFileWritten: 'data/%s'", absolutePath)
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

		LIBIconGenerator.ReadWorkloadForCurrentMap(function(success, errorOrWorkload, path, absolutePath)
			if not success then
				LIBPrint.Warn("dev_sligwolf_zdevtools_icongen_start: %s", errorOrWorkload)
				return
			end

			LIBPrint.Print("dev_sligwolf_zdevtools_icongen_start: Workload loaded from file '%s'.", absolutePath)

			g_iconGenerator:AddWorkload(errorOrWorkload)
			g_iconGenerator:Start()
		end)
	end)

	concommand.Add("dev_sligwolf_zdevtools_icongen_cancel", function(ply)
		if not IsValid(g_iconGenerator) then
			return
		end

		g_iconGenerator:Cancel()
	end)
end

return true

