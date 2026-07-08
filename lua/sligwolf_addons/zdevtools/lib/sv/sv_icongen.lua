local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIB = SLIGWOLF_ADDON.IconGenerator
if not LIB then
	return
end

local LIBSkinsystem = SligWolf_Addons.Skinsystem
local LIBEntities = SligWolf_Addons.Entities
local LIBSourceIO = SligWolf_Addons.SourceIO
local LIBPosition = SligWolf_Addons.Position
local LIBPrint = SligWolf_Addons.Print
local LIBUtil = SligWolf_Addons.Util
local LIBHook = SligWolf_Addons.Hook
local LIBNet = SligWolf_Addons.Net

local META = LIB.meta

LIB.processId = 0
LIB.processSubId = 0

local g_spawnCategoryToCmd = {
	[LIBEntities.SPAWN_CATEGORY_ENTITY] = "gm_spawnsent",
	[LIBEntities.SPAWN_CATEGORY_WEAPON] = "gm_spawnswep",
	[LIBEntities.SPAWN_CATEGORY_NPC] = "gmod_spawnnpc",
	[LIBEntities.SPAWN_CATEGORY_VEHICLE] = "gm_spawnvehicle",
}

LIBNet.AddNetworkString("zdevtools_icongen_start")
LIBNet.AddNetworkString("zdevtools_icongen_done")

LIBNet.Receive("zdevtools_icongen_done", function(len, ply)
	local name = net.ReadString()
	local processSubId = net.ReadUInt(32)
	local success = net.ReadBool()

	local instance = LIB.GetInstance(name)

	if not IsValid(ply) then
		return
	end

	if not IsValid(instance) then
		return
	end

	local captureResponce = {
		player = ply,
		processSubId = processSubId,
		success = success,
	}

	instance:HandleCaptureDone(captureResponce)
end)

local function freezeEntity(ent)
	LIBSourceIO.SetKeyValue(ent, "sligwolf_frozen", true)
	LIBEntities.EnableSystemMotion(ent, false)
end

function META:ResetInternal()
	self.processSubId = nil

	self.workload = nil
	self.workloadByPath = nil
	self.workloadCount = 0

	self.currentIndex = 0
	self.currentEntry = nil

	self.currentAddonname = nil
	self.currentCategory = nil
	self.currentSpawnname = nil
	self.currentTheme = nil
	self.currentPath = nil

	self.currentSavegame = nil
	self.lastSavegame = nil

	self.currentEntity = nil

	self.entriesTotal = 0
	self.entriesRun = 0
	self.entriesDone = 0
	self.entriesError = 0

	self.timeoutTotalTimer = string.format("timeout_total_%s", self.namespace)
	self.timeoutEntityTimer = string.format("timeout_entity_%s", self.namespace)
	self.playerTimer = string.format("player_%s", self.namespace)
	self.readyTimer = string.format("ready_%s", self.namespace)
	self.waitTimer = string.format("wait_%s", self.namespace)
	self.delayTimer = string.format("delay_%s", self.namespace)
	self.startTimer = string.format("start_%s", self.namespace)

	self.spawnHookName = string.format("Addon_ZDevTools_IconGen_Spawn_%s", self.namespace)
	self.controlHookName = string.format("Addon_ZDevTools_IconGen_Control_%s", self.namespace)
end

function META:Lock()
	local ply = self.player

	if IsValid(ply) then
		ply:ExitVehicle()
		ply:ExitLadder()
		ply:SetViewEntity(nil)

		ply:SetNotSolid(true)
		ply:SetNoDraw(true)

		ply:SetMoveType(MOVETYPE_NONE)
		ply:GodEnable()

		local unlockWeapon = LIB.config.unlockWeapon
		ply:Give(unlockWeapon)
		ply:SelectWeapon(unlockWeapon)

		local lockWeapon = LIB.config.lockWeapon
		ply:Give(lockWeapon)
		ply:SelectWeapon(lockWeapon)

		local wep = ply:GetWeapon(lockWeapon)
		if IsValid(wep) then
			wep:SetNoDraw(true)
		end

		ply:SetNWVector("sligwolf_zdevtools_icongen_lock_pos", ply:GetPos())
		ply:SetNWAngle("sligwolf_zdevtools_icongen_lock_ang", ply:EyeAngles())
		ply:SetNWBool("sligwolf_zdevtools_icongen_lock", true)
	end

	self:SetupControlHook()
end

function META:Unlock()
	local ply = self.player

	if IsValid(ply) then
		ply:SetNWBool("sligwolf_zdevtools_icongen_lock", false)

		ply:SetNotSolid(false)
		ply:SetNoDraw(false)

		ply:SetMoveType(MOVETYPE_NOCLIP)
		ply:GodDisable()

		local lockWeapon = LIB.config.lockWeapon

		local wep = ply:GetWeapon(lockWeapon)
		if IsValid(wep) then
			wep:SetNoDraw(false)
		end

		ply:StripWeapon(lockWeapon)

		local unlockWeapon = LIB.config.unlockWeapon
		ply:Give(unlockWeapon)
		ply:SelectWeapon(unlockWeapon)
	end

	self:RemoveControlHook()
end

function META:Initialize(ply)
	if not IsValid(ply) or not ply:IsPlayer() then
		LIBPrint.Error("No player provided.")
		return
	end

	if self:IsLocked() then
		LIBPrint.Error("System is already locked by another instance.")
		return
	end

	self.workload = {}
	self.workloadByPath = {}

	self.player = ply
	self.currentIndex = 0

	self.isProcessing = false
end

function META:Start()
	local ply = self.player

	if not IsValid(ply) or not ply:IsPlayer() then
		LIBPrint.Error("No player given, call Initialize(player) first.")
		return
	end

	if not self.workload then
		LIBPrint.Error("No workload given, call Initialize(player) first.")
		return
	end

	if self:IsLocked() then
		LIBPrint.Error("System is already locked by another instance.")
		return
	end

	self.workloadCount = #self.workload

	self.isProcessing = true
	self.currentIndex = 0

	LIB.processId = LIB.processId + 1
	self.processId = LIB.processId

	self:Lock()

	if not self:ValidateState() then
		return
	end

	SLIGWOLF_ADDON:TimerOnce(self.startTimer, self.config.time.start, function()
		if not IsValid(self) then
			return
		end

		self:ProcessNextEntry()
	end)
end


function META:AddWorkloadItem(workloadItem)
	workloadItem = workloadItem or {}

	local defaults = LIB.config.defaults
	local defaultsCamera = defaults.camera
	local defaultsEntity = defaults.entity
	local defaultsTheme = defaults.theme

	local maxDofDistance = LIB.config.limits.dof.distance
	local maxDofBlur = LIB.config.limits.dof.blur
	local maxDofPasses = LIB.config.limits.dof.passes
	local maxDofSteps = LIB.config.limits.dof.steps
	local maxDofShape = LIB.config.limits.dof.shape

	local workload = self.workload
	local workloadByPath = self.workloadByPath

	local spawnnames = workloadItem.spawnname or ""
	if not istable(spawnnames) then
		spawnnames = {spawnnames}
	end

	spawnnames = LIBUtil.DeduplicateTable(spawnnames)

	local firstSpawnname = tostring(spawnnames[1] or "")
	if firstSpawnname == "" then
		firstSpawnname = "<empty spawnname>"
	end

	local category = tostring(workloadItem.category or "")
	if category == "" then
		self:Warn(
			"AddWorkloadItem: No category given, skipping. (Spawnname: '%s')",
			firstSpawnname
		)

		return
	end

	local map = tostring(workloadItem.map or "")
	if map == "" then
		self:Warn(
			"AddWorkloadItem: No map given, skipping. (Spawnname: '%s', Category: '%s')",
			firstSpawnname,
			category
		)

		return
	end

	local spawnparams = workloadItem.spawnparams or ""
	if not istable(spawnparams) then
		spawnparams = {spawnparams}
	end

	spawnparams = LIBUtil.DeduplicateTable(spawnparams)

	local themesTmp = workloadItem.theme or defaultsTheme
	if not istable(themesTmp) then
		themesTmp = {themesTmp}
	end

	local camera = workloadItem.camera or {}
	local dof = camera.dof or {}

	local entity = workloadItem.entity or {}

	if table.IsEmpty(themesTmp) then
		themesTmp = {defaultsTheme}
	end

	local savegame = tostring(workloadItem.savegame or "")
	if savegame == "" then
		savegame = "none"
	end

	for _, spawnname in ipairs(spawnnames) do
		spawnname = tostring(spawnname or "")

		if spawnname == "" then
			self:Warn(
				"AddWorkloadItem: Empty spawnname given, skipping. (Category: '%s')",
				category
			)

			continue
		end

		local addon = nil
		local addonname = nil

		local spawntable = LIBEntities.GetSpawntableByName(category, spawnname)
		if spawntable and spawntable.Is_SLIGWOLF then
			addon = SligWolf_Addons.GetAddon(spawntable.SLIGWOLF_Addonname or "")

			if addon then
				addonname = addon.Addonname
			end
		end

		local themeCategoryName = nil
		local themeNapName = nil

		if addon then
			themeCategoryName, themeNapName = addon:SkinGetCategoryAndMapNameFromSpawntable(spawntable)
		end

		local themes = {}

		if themeCategoryName and themeNapName then
			local getall = false

			for _, themename in ipairs(themesTmp) do
				if themename == "all" then
					getall = true
					break
				end

				themename = tostring(themename or "")
				themename = addon:SkinNormalizeThemeName(themeCategoryName, themename)

				local themeconfig = addon:SkinGetThemeConfig(themeCategoryName, themename, false)
				if not themeconfig then
					continue
				end

				if themeconfig.isRandom then
					continue
				end

				if themeconfig.isPlayerColored then
					continue
				end

				if themename == "" or themeconfig.isDefault then
					themename = LIBSkinsystem.THEME_DEFAULT
				end

				table.insert(themes, themename)
			end

			if getall then
				table.Empty(themes)

				local themeConfigs = addon:SkinGetThemeConfigs(themeCategoryName)

				for _, themeconfig in ipairs(themeConfigs) do
					if themeconfig.isRandom then
						continue
					end

					if themeconfig.isPlayerColored then
						continue
					end

					local themename = themeconfig.name
					if themename == "" or themeconfig.isDefault then
						themename = LIBSkinsystem.THEME_DEFAULT
					end

					table.insert(themes, themename)
				end
			end
		end

		themes = LIBUtil.DeduplicateTable(themes)

		local newItemTemplate = {}

		newItemTemplate.map = map
		newItemTemplate.spawnname = spawnname
		newItemTemplate.category = category
		newItemTemplate.addonname = addonname
		newItemTemplate.spawnparams = spawnparams
		newItemTemplate.savegame = savegame

		newItemTemplate.camera = {
			pos = camera.pos or defaultsCamera.pos,
			ang = camera.ang or defaultsCamera.ang,
			fov = math.Clamp(camera.fov or defaultsCamera.fov, 0.1, 175),
			dof = {
				distance = math.Clamp(dof.distance or defaultsCamera.dof.distance, 0, maxDofDistance),
				blur = math.Clamp(dof.blur or defaultsCamera.dof.blur, 0, maxDofBlur),
				passes = math.Clamp(math.floor(dof.passes or defaultsCamera.dof.passes), 0, maxDofPasses),
				steps = math.Clamp(math.floor(dof.steps or defaultsCamera.dof.steps), 0, maxDofSteps),
				shape = math.Clamp(dof.shape or defaultsCamera.dof.shape, 0, maxDofShape),
			},
		}

		local spawnFrozen = entity.spawnFrozen

		if spawnFrozen == nil then
			spawnFrozen = defaultsEntity.spawnFrozen
		end

		newItemTemplate.entity = {
			pos = entity.pos or defaultsEntity.pos,
			ang = entity.ang or defaultsEntity.ang,
			wait = math.Clamp(entity.wait or defaultsEntity.wait, 0, 10),
			spawnFrozen = spawnFrozen,
		}

		if table.IsEmpty(themes) then
			themes = {LIBSkinsystem.THEME_DEFAULT}
		end

		for _, theme in ipairs(themes) do
			local newItem = table.Copy(newItemTemplate)

			local id = #workload + 1

			newItem.id = id
			newItem.theme = theme

			local path = LIB.GetPathFromWorkloadEntry(newItem)
			newItem.path = path

			if not self:CallWorkloadFilters(newItem) then
				continue
			end

			if not self:ValidateWorkloadItem(newItem) then
				continue
			end

			workloadByPath[path] = newItem
			table.insert(workload, newItem)
		end
	end
end

function META:AddWorkload(workload)
	workload = workload or {}

	for _, workloadItem in ipairs(workload) do
		self:AddWorkloadItem(workloadItem)
	end
end

function META:AddWorkloadFilter(name, filter)
	local workloadFilters = self.workloadFilters or {}
	self.workloadFilters = workloadFilters

	workloadFilters[name] = filter
end

function META:CallWorkloadFilters(item)
	if not item then
		return false
	end

	local workloadFilters = self.workloadFilters

	if not workloadFilters then
		return true
	end

	for _, filter in pairs(workloadFilters) do
		if not filter then
			continue
		end

		local result = filter(item)
		if result == nil then
			continue
		end

		if result then
			return true
		end

		return false
	end

	return true
end

function META:ValidateWorkloadItem(item)
	if not item then
		return false
	end

	local workloadByPath = self.workloadByPath

	local map = item.map
	local spawnname = item.spawnname
	local category = item.category
	local addonname = item.addonname
	local savegame = item.savegame

	local id = item.id
	local path = item.path

	local loadedMap = game.GetMap()

	if map ~= loadedMap then
		self:Warn(
			"ValidateWorkloadItem: Given map does not match, skipping. ('%s' != '%s') (ID: %i, Spawnname: '%s', Category: '%s')",
			map,
			loadedMap,
			id,
			spawnname,
			category
		)

		return false
	end

	local spawntable = LIBEntities.GetSpawntableByName(category, spawnname)
	if not spawntable or not spawntable.Is_SLIGWOLF then
		self:Warn(
			"ValidateWorkloadItem: Given spawnname does not exist, skipping. (ID: %i, Spawnname: '%s', Category: '%s')",
			id,
			spawnname,
			category
		)

		return false
	end

	if not addonname then
		self:Warn(
			"ValidateWorkloadItem: Addon does not exist, skipping. (ID: %i, Spawnname: '%s', Category: '%s')",
			id,
			spawnname,
			category
		)

		return false
	end

	if savegame ~= "none" then
		local saveMap = LIB.SaveGameMap(savegame)

		if not saveMap then
			self:Warn(
				"ValidateWorkloadItem: Savegame '%s' does not exist, skipping. (ID: %i, Spawnname: '%s', Category: '%s')",
				savegame,
				id,
				spawnname,
				category
			)

			return false
		end

		if saveMap ~= loadedMap then
			self:Warn(
				"ValidateWorkloadItem: Savegame '%s' does not match map, skipping. ('%s' != '%s') (ID: %i, Spawnname: '%s', Category: '%s')",
				savegame,
				saveMap,
				loadedMap,
				id,
				spawnname,
				category
			)

			return false
		end
	end

	if workloadByPath[path] then
		self:Warn(
			"AddWorkloadItem: Duplicate entry given, skipping. (ID: %i, Path: '%s')",
			id,
			path
		)

		return false
	end

	return true
end

function META:DestroyInternal()
	self:ResetPlayerPosition()
	self:CleanupSpawn()
	self:Unlock()
	game.CleanUpMap()
end

function META:CancelInternal()
	self:ResetPlayerPosition()
	self:CleanupSpawn()
	self:Unlock()
	game.CleanUpMap()
end

function META:ValidateStateInternal()
	local workload = self.workload
	if not workload then
		return false
	end

	return true
end

function META:ProcessNextEntry()
	if not self:ValidateState() then
		return
	end

	self:CleanupSpawn()

	LIB.processSubId = LIB.processSubId + 1
	self.processSubId = LIB.processSubId

	local workload = self.workload
	local count = self.workloadCount

	self.currentIndex = self.currentIndex + 1
	local index = self.currentIndex

	if count <= 0 then
		self:ProcessStart()
		self:ProcessEnd()
		return
	end

	if index > count then
		self:ProcessEnd()
		return
	end

	local currentEntry = workload[index]
	if not currentEntry then
		self:ProcessEnd()
		return
	end

	self.currentEntry = currentEntry

	self.currentAddonname = currentEntry.addonname
	self.currentCategory = currentEntry.category
	self.currentSpawnname = currentEntry.spawnname
	self.currentTheme = currentEntry.theme
	self.currentPath = currentEntry.path
	self.currentSavegame = currentEntry.savegame

	if index == 1 then
		self:ProcessStart()
	end

	if self.OnProgress then
		ProtectedCall(self.OnProgress, self, index, count)
	end

	self:LoadSaveGame(function()
		self:MovePlayerToEntry()
		self:SpawnEntityForEntry()
	end)
end

function META:ProcessNextEntryOnError()
	if not self:ValidateState() then
		return
	end

	self.entriesError = math.min(self.entriesError + 1, self.entriesTotal)
	self.entriesRun = math.min(self.entriesRun + 1, self.entriesTotal)

	self:ProcessNextEntry()
end

function META:ProcessStart()
	self.isProcessing = true

	local ply = self.player

	self.originalPos = ply:GetPos()
	self.originalAng = ply:EyeAngles()

	self.entriesTotal = self.workloadCount
	self.entriesRun = 0
	self.entriesDone = 0
	self.entriesError = 0

	if self.OnStart then
		ProtectedCall(self.OnStart, self)
	end
end

function META:ProcessEnd()
	self.isProcessing = false
	self.processSubId = nil

	self.workload = nil
	self.workloadCount = nil

	self.currentIndex = 0
	self.currentEntry = nil

	self.currentAddonname = nil
	self.currentCategory = nil
	self.currentSpawnname = nil
	self.currentTheme = nil
	self.currentPath = nil

	self.currentSavegame = nil
	self.lastSavegame = nil

	self:ResetPlayerPosition()
	self:Unlock()
	game.CleanUpMap()

	if self.OnFinished then
		ProtectedCall(self.OnFinished, self)
	end

	self.entriesTotal = 0
	self.entriesRun = 0
	self.entriesDone = 0
	self.entriesError = 0
end

function META:ResetPlayerPosition()
	if self.originalPos and self.originalAng then
		self:MovePlayerToPosition(self.originalPos, self.originalAng)
	end

	self.originalPos = nil
	self.originalAng = nil
end

function META:MovePlayerToPosition(playerPos, playerAng)
	if not IsValid(self.player) then
		return
	end

	local ply = self.player

	ply:SetNWVector("sligwolf_zdevtools_icongen_lock_pos", playerPos)
	ply:SetNWAngle("sligwolf_zdevtools_icongen_lock_ang", playerAng)
	ply:SetPos(playerPos)
	ply:SetEyeAngles(playerAng)
end

function META:MovePlayerToEntry()
	if not self:ValidateState() then
		return
	end

	local ply = self.player

	local entry = self.currentEntry

	local pos = entry.entity.pos
	local ang = entry.entity.ang

	local yaw = math.NormalizeAngle(ang.y - 180)

	local distance = 100

	local playerAng = Angle(45, yaw, 0)

	local eyePos = pos - (playerAng:Forward() * distance)

	local viewOffset = ply:GetCurrentViewOffset()
	local playerPos = eyePos - viewOffset

	self:MovePlayerToPosition(playerPos, playerAng)
end

function META:MovePlayerToCamera()
	if not self:ValidateState() then
		return
	end

	local ply = self.player

	local entry = self.currentEntry

	local eyePos = entry.camera.pos
	local playerAng = entry.camera.ang

	local viewOffset = ply:GetCurrentViewOffset()
	local playerPos = eyePos - viewOffset

	self:MovePlayerToPosition(playerPos, playerAng)
end

function META:LoadSaveGame(callback)
	if not self:ValidateState() then
		return
	end

	local savegame = self.currentSavegame
	local lastSavegame = self.lastSavegame
	self.lastSavegame = savegame

	if lastSavegame and lastSavegame == savegame then
		callback()
		return
	end

	local processSubId = self.processSubId

	LIB.LoadSaveGame(savegame, function(success, errorOrPath, absolutePath)
		if not IsValid(self) then
			return
		end

		if processSubId ~= self.processSubId then
			return
		end

		if not self:ValidateState() then
			return
		end

		if not success then
			self:Warn("LoadSaveGame: %s", errorOrPath)
			self:Cancel()
			return
		end

		if self.OnLoadSavegame then
			ProtectedCall(self.OnLoadSavegame, self, errorOrPath, absolutePath)
		end

		callback()
	end)
end

function META:ValidateEntity(ent)
	if not LIBEntities.IsMarkedForDeletion(ent) then
		return true
	end

	if self.OnEarlyEntityRemove then
		ProtectedCall(self.OnEarlyEntityRemove, self)
	end

	self:Warn("ValidateEntity: Entity has been removed early, skipping.")
	self:ProcessNextEntryOnError()

	return false
end

function META:MoveEntityToPosition(entPos, entAng, callback)
	if not self:ValidateState() then
		return
	end

	local processSubId = self.processSubId
	local ent = self.currentEntity

	if not self:ValidateEntity(ent) then
		return
	end

	LIBPosition.SetPosAng(ent, entPos, entAng, function()
		if not IsValid(self) then
			return
		end

		if processSubId ~= self.processSubId then
			return
		end

		if not self:ValidateState() then
			return
		end

		if not self:ValidateEntity(ent) then
			return
		end

		callback(self)
	end)
end

function META:SpawnEntityForEntry()
	if not self:ValidateState() then
		return
	end

	self:SetupSpawnHooks()

	local ply = self.player
	local entry = self.currentEntry
	local category = self.currentCategory

	local spawncommand = g_spawnCategoryToCmd[self.currentCategory]
	if not spawncommand then
		self:Warn("SpawnEntityForEntry: No spawncommand for given category '%s', skipping.", category)
		self:ProcessNextEntryOnError()
		return
	end

	local cmd = string.format("%s \"%s\"", spawncommand, entry.spawnname)

	for _, spawnparam in ipairs(entry.spawnparams) do
		spawnparam = tostring(spawnparam or "")
		if spawnparam == "" then
			continue
		end

		cmd = string.format("%s \"%s\"", spawncommand, spawnparam)
	end

	-- Run the spawn command
	ply:ConCommand(cmd)

	local processSubId = self.processSubId

	-- Set timeout for processing
	SLIGWOLF_ADDON:TimerOnce(self.timeoutTotalTimer, self.config.time.timeoutTotal, function()
		if not IsValid(self) then
			return
		end

		if processSubId ~= self.processSubId then
			return
		end

		if self.OnTimeout then
			ProtectedCall(self.OnTimeout, self)
		end

		self:Warn("SpawnEntityForEntry: Processing timed out, skipping.")
		self:ProcessNextEntryOnError()
	end)

	-- Set timeout for entity spawn
	SLIGWOLF_ADDON:TimerOnce(self.timeoutEntityTimer, self.config.time.timeoutEntity, function()
		if not IsValid(self) then
			return
		end

		if processSubId ~= self.processSubId then
			return
		end

		if self.OnTimeout then
			ProtectedCall(self.OnTimeout, self)
		end

		self:Warn("SpawnEntityForEntry: Entity spawn timed out, skipping.")
		self:ProcessNextEntryOnError()
	end)
end

function META:SetupControlHook()
	if not self:ValidateState() then
		return
	end

	local processId = self.processId

	local callback = function(ply, button)
		if not IsValid(self) then
			return
		end

		if self.player ~= ply then
			return
		end

		if processId ~= self.processId then
			return
		end

		self:HandlePlayerControl(button)
	end

	LIBHook.Add("PlayerButtonDown", self.controlHookName, callback)
end

function META:RemoveControlHook()
	local controlHookName = self.controlHookName
	LIBHook.Remove("PlayerButtonDown", controlHookName)
end

function META:HandlePlayerControl(button)
	if button == KEY_SPACE then
		self:Cancel()
	end
end

function META:SetupSpawnHooks()
	if not self:ValidateState() then
		return
	end

	local processSubId = self.processSubId

	local entry = self.currentEntry
	local entrySpawnname = entry.spawnname

	local callback = function(ply, ent, spawnname)
		if not IsValid(self) then
			return
		end

		if self.player ~= ply then
			return
		end

		if processSubId ~= self.processSubId then
			return
		end

		if entrySpawnname ~= spawnname then
			return
		end

		self:HandleSpawnedEntity(ent)
	end

	LIBHook.AddCustom("PostPlayerSpawnedAddonEntity", self.spawnHookName, callback)
end

function META:RemoveSpawnHooks()
	LIBHook.RemoveCustom("PostPlayerSpawnedAddonEntity", self.spawnHookName)
end

function META:HandleSpawnedEntity(ent, spawnname)
	if not self:ValidateState() then
		return
	end

	self.currentEntity = ent

	if not self:ValidateEntity(ent) then
		return
	end

	if self.OnSpawn then
		ProtectedCall(self.OnSpawn, self, ent)
	end

	if not self:ValidateEntity(ent) then
		return
	end

	SLIGWOLF_ADDON:TimerRemove(self.timeoutEntityTimer)

	self:RemoveSpawnHooks()

	local entry = self.currentEntry
	local addonname = self.currentAddonname

	local entPos = entry.entity.pos
	local entAng = entry.entity.ang
	local entSpawnFrozen = entry.entity.spawnFrozen

	local addon = SligWolf_Addons.GetAddon(addonname)
	if not addon then
		self:Warn("HandleSpawnedEntity: Addon '%s' not found, skipping", addonname)
		self:ProcessNextEntryOnError()
		return
	end

	LIBSourceIO.SetSpawnedByScript(ent, true)

	if entSpawnFrozen then
		freezeEntity(ent)
	end

	local themeName = addon:SkinNormalizeThemeName(self.currentCategory, self.currentTheme)
	if themeName then
		addon:SkinApplyThemeByName(ent, themeName)
	end

	self:MoveEntityToPosition(entPos, entAng, function()
		self:MovePlayerToCamera()

		self:WaitForEntityReady(function()
			self:SendCaptureRequest()
		end)
	end)
end

function META:WaitForEntityReady(callback)
	if not self:ValidateState() then
		return
	end

	local ent = self.currentEntity

	if not self:ValidateEntity(ent) then
		return
	end

	local processSubId = self.processSubId

	self:CleanupCallbacks()

	local waitTicksLeft = 10

	local entry = self.currentEntry
	local entSpawnFrozen = entry.entity.spawnFrozen
	local entWait = entry.entity.wait

	SLIGWOLF_ADDON:TimerUntil(self.readyTimer, 0, function(_, success)
		if not IsValid(self) then
			return true
		end

		if not success then
			return true
		end

		if processSubId ~= self.processSubId then
			return true
		end

		if waitTicksLeft > 0 then
			waitTicksLeft = waitTicksLeft - 1
			return false
		end

		if not self:ValidateEntity(ent) then
			return
		end

		if LIBPosition.IsAsyncPositioning(ent) then
			return false
		end

		if not LIBEntities.IsSpawnSystemFinished(ent) then
			return false
		end

		if entSpawnFrozen then
			freezeEntity(ent)
		end

		self:CleanupCallbacks()

		SLIGWOLF_ADDON:TimerOnce(self.waitTimer, entWait, function()
			if not IsValid(self) then
				return
			end

			if processSubId ~= self.processSubId then
				return
			end

			if not self:ValidateEntity(ent) then
				return
			end

			freezeEntity(ent)
			self:CleanupCallbacks()

			callback(self)
		end)

		return true
	end)
end

function META:SendCaptureRequest()
	if not self:ValidateState() then
		return
	end

	local ent = self.currentEntity
	if not self:ValidateEntity(ent) then
		return
	end

	local entry = self.currentEntry
	local camera = entry.camera
	local dof = camera.dof

	LIBNet.Start("zdevtools_icongen_start")
		net.WriteString(self.name)
		net.WriteUInt(self.processSubId, 32)
		net.WriteUInt(self.currentIndex, 16)
		net.WriteUInt(self.workloadCount, 16)

		net.WriteString(self.currentAddonname or "")
		net.WriteString(self.currentCategory or "")
		net.WriteString(self.currentSpawnname or "")
		net.WriteString(self.currentTheme or "")
		net.WriteUInt(ent:EntIndex(), MAX_EDICT_BITS)

		net.WriteString(self.currentPath or "")

		net.WriteVector(camera.pos)
		net.WriteAngle(camera.ang)
		net.WriteFloat(camera.fov)

		net.WriteFloat(dof.distance)
		net.WriteFloat(dof.blur)
		net.WriteUInt(dof.passes, 8)
		net.WriteUInt(dof.steps, 8)
		net.WriteFloat(dof.shape)
	LIBNet.Send(self.player)
end

function META:HandleCaptureDone(captureResponce)
	if not self:ValidateState() then
		return
	end

	if not self.isProcessing then
		return
	end

	if captureResponce.player ~= self.player then
		return
	end

	if captureResponce.processSubId ~= self.processSubId then
		return
	end

	local success = captureResponce.success

	if not success then
		self.entriesRun = math.min(self.entriesRun + 1, self.entriesTotal)
		self.entriesError = math.min(self.entriesError + 1, self.entriesTotal)

		self:Cancel()
		return
	end

	self:CleanupSpawn()

	local index = self.currentIndex
	local count = self.workloadCount

	self.entriesRun = math.min(self.entriesRun + 1, self.entriesTotal)
	self.entriesDone = math.min(self.entriesDone + 1, self.entriesTotal)

	if self.OnProgressDone then
		ProtectedCall(self.OnProgressDone, self, index, count)
	end

	if index >= count then
		self:ProcessEnd()
		return
	end

	SLIGWOLF_ADDON:TimerOnce(self.delayTimer, self.config.time.delay, function()
		if not IsValid(self) then
			return
		end

		self:ProcessNextEntry()
	end)
end

function META:CleanupCallbacks()
	SLIGWOLF_ADDON:TimerRemove(self.playerTimer)
	SLIGWOLF_ADDON:TimerRemove(self.readyTimer)
	SLIGWOLF_ADDON:TimerRemove(self.waitTimer)
	SLIGWOLF_ADDON:TimerRemove(self.delayTimer)
	SLIGWOLF_ADDON:TimerRemove(self.startTimer)
end

-- Clean up pending spawn state
function META:CleanupSpawn()
	SLIGWOLF_ADDON:TimerRemove(self.timeoutEntityTimer)
	SLIGWOLF_ADDON:TimerRemove(self.timeoutTotalTimer)

	self:RemoveSpawnHooks()
	self:CleanupCallbacks()

	if IsValid(self.currentEntity) then
		self.currentEntity:Remove()
		self.currentEntity = nil
	end
end

return true

