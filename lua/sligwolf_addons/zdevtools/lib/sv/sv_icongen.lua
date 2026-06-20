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

	self.currentEntity = nil

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

		ply:SetNotSolid(true)
		ply:SetNoTarget(true)
		ply:SetNoDraw(true)

		ply:SetMoveType(MOVETYPE_NONE)
		ply:GodEnable()

		local lockWeapon = LIB.config.lockWeapon
		ply:Give(lockWeapon)
		ply:SelectWeapon(lockWeapon)

		ply:SetNWVector("sligwolf_zdevtools_icongen_lock_pos", ply:GetPos())
		ply:SetNWAngle("sligwolf_zdevtools_icongen_lock_ang", ply:GetAngles())
		ply:SetNWBool("sligwolf_zdevtools_icongen_lock", true)
	end

	self:SetupControlHook()
end

function META:Unlock()
	local ply = self.player

	if IsValid(ply) then
		ply:SetNWBool("sligwolf_zdevtools_icongen_lock", false)

		ply:SetNotSolid(false)
		ply:SetNoTarget(false)
		ply:SetNoDraw(false)

		ply:SetMoveType(MOVETYPE_NOCLIP)
		ply:GodDisable()

		local lockWeaponEntity = ply:GetWeapon(LIB.config.lockWeapon)
		if IsValid(lockWeaponEntity) then
			lockWeaponEntity:Remove()
		end

		local weapon = LIB.config.unlockWeapon
		ply:Give(weapon)
		ply:SelectWeapon(weapon)
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
		LIBPrint.Error("No player given. Call Initialize(player, workload) first.")
		return
	end

	if not self.workload or table.IsEmpty(self.workload) then
		LIBPrint.Error("No workload given. Add Workload first.")
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

	local category = tostring(workloadItem.category or "")
	if category == "" then
		LIBPrint.Error("No category given.")
		return
	end

	local map = tostring(workloadItem.map or "")
	local loadedMap = game.GetMap()

	if map ~= loadedMap then
		LIBPrint.Warn(
			"Different map given, skipping. (Map: '%s', Loaded map: '%s')",
			map,
			loadedMap
		)

		return
	end

	local spawnnames = workloadItem.spawnname or ""
	if not istable(spawnnames) then
		spawnnames = {spawnnames}
	end

	spawnnames = LIBUtil.DeduplicateTable(spawnnames)

	local spawnparams = workloadItem.spawnparams or ""
	if not istable(spawnparams) then
		spawnparams = {spawnparams}
	end

	spawnparams = LIBUtil.DeduplicateTable(spawnparams)

	local themesTmp = workloadItem.theme or defaults.theme
	if not istable(themesTmp) then
		themesTmp = {themesTmp}
	end

	local maxDofDistance = LIB.config.maxDofDistance

	local camera = workloadItem.camera or {}
	local dof = camera.dof or {}

	local entity = workloadItem.entity or {}

	local workload = self.workload
	local workloadByPath = self.workloadByPath

	if table.IsEmpty(themesTmp) then
		themesTmp = {defaults.theme}
	end

	for _, spawnname in ipairs(spawnnames) do
		spawnname = tostring(spawnname or "")

		local spawntable = LIBEntities.GetSpawntableByName(category, spawnname)
		if not spawntable or not spawntable.Is_SLIGWOLF then
			LIBPrint.Warn(
				"Invalid spawnname given, skipping. (Spawnname: '%s', Category: '%s')",
				spawnname,
				category
			)

			continue
		end

		local addonname = spawntable.SLIGWOLF_Addonname or ""

		local addon = SligWolf_Addons.GetAddon(addonname)
		if not addon then
			LIBPrint.Warn(
				"Spawntable with bad addon given, skipping. (Spawnname: '%s', Category: '%s', Addonname: '%s')",
				spawnname,
				category,
				addonname
			)

			continue
		end

		local themeCategoryName, themeNapName = addon:SkinGetCategoryAndMapNameFromSpawntable(spawntable)
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
					themename = "default"
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
						themename = "default"
					end

					table.insert(themes, themename)
				end
			end
		end

		themes = LIBUtil.DeduplicateTable(themes)

		local newItemTemplate = {}

		newItemTemplate.spawnname = spawnname
		newItemTemplate.category = category
		newItemTemplate.addonname = addonname
		newItemTemplate.spawnparams = spawnparams

		newItemTemplate.camera = {
			pos = camera.pos or defaultsCamera.pos,
			ang = camera.ang or defaultsCamera.ang,
			fov = math.Clamp(camera.fov or defaultsCamera.fov, 0.1, 175),
			dof = {
				distance = math.Clamp(dof.distance or defaultsCamera.dof.distance, 0, maxDofDistance),
				blur = math.Clamp(dof.blur or defaultsCamera.dof.blur, 0, 10),
				passes = math.Clamp(math.floor(dof.passes or defaultsCamera.dof.passes), 0, 64),
				steps = math.Clamp(math.floor(dof.steps or defaultsCamera.dof.steps), 0, 64),
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
			themes = {"default"}
		end

		for _, theme in ipairs(themes) do
			local newItem = table.Copy(newItemTemplate)
			local path = nil

			if theme == "default" then
				path = string.format(
					"%s/%s.png",
					addonname,
					spawnname
				)
			else
				path = string.format(
					"%s/%s_%s.png",
					addonname,
					spawnname,
					theme
				)
			end

			path = string.lower(path)

			if workloadByPath[path] then
				LIBPrint.Warn(
					"Duplicate entry given, skipping. (Path: '%s')",
					path
				)

				continue
			end

			newItem.id = #workload + 1
			newItem.path = path
			newItem.theme = theme

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

function META:DestroyInternal()
	self:CleanupSpawn()
	self:Unlock()
end

function META:CancelInternal()
	self:CleanupSpawn()
	self:Unlock()
end

function META:ValidateStateInternal()
	local workload = self.workload
	if not workload or #workload <= 0 then
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
	local workloadCount = self.workloadCount

	self.currentIndex = self.currentIndex + 1
	local currentIndex = self.currentIndex

	if currentIndex > workloadCount then
		self:ProcessEnd()
		return
	end

	local currentEntry = workload[currentIndex]
	if not currentEntry then
		self:ProcessEnd()
		return
	end

	self.currentEntry = currentEntry

	if self.OnProgress then
		ProtectedCall(self.OnProgress, self, currentEntry, currentIndex, workloadCount)
	end

	-- Move player to specified position
	self:MovePlayerToEntry(function()
		-- Spawn the entity
		self:SpawnEntityForEntry()
	end)
end

function META:ProcessEnd()
	self.isProcessing = false

	self.workload = nil
	self.workloadCount = nil

	self.currentIndex = 0
	self.currentEntry = nil

	self.currentAddonname = nil
	self.currentCategory = nil
	self.currentSpawnname = nil
	self.currentTheme = nil
	self.currentPath = nil

	self:Unlock()

	if self.OnDone then
		ProtectedCall(self.OnDone, self)
	end
end

function META:MovePlayerToPosition(playerPos, playerAng, callback)
	if not self:ValidateState() then
		return
	end

	local ply = self.player

	ply:SetNWVector("sligwolf_zdevtools_icongen_lock_pos", playerPos)
	ply:SetNWAngle("sligwolf_zdevtools_icongen_lock_ang", playerAng)
	ply:SetPos(playerPos)
	ply:SetEyeAngles(playerAng)

	callback(self)
end

function META:MovePlayerToEntry(callback)
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

	self:MovePlayerToPosition(playerPos, playerAng, callback)
end

function META:MovePlayerToCamera(callback)
	if not self:ValidateState() then
		return
	end

	local ply = self.player

	local entry = self.currentEntry

	local eyePos = entry.camera.pos
	local playerAng = entry.camera.ang

	local viewOffset = ply:GetCurrentViewOffset()
	local playerPos = eyePos - viewOffset

	self:MovePlayerToPosition(playerPos, playerAng, callback)
end

function META:MoveEntityToPosition(entPos, entAng, callback)
	if not self:ValidateState() then
		return
	end

	local ent = self.currentEntity

	if LIBEntities.IsMarkedForDeletion(ent) then
		self:ProcessNextEntry()
		return
	end

	LIBPosition.SetPosAng(ent, entPos, entAng, function()
		if not IsValid(self) then
			return
		end

		if not self:ValidateState() then
			return
		end

		if LIBEntities.IsMarkedForDeletion(ent) then
			self:ProcessNextEntry()
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

	self.currentAddonname = entry.addonname
	self.currentCategory = entry.category
	self.currentSpawnname = entry.spawnname
	self.currentTheme = entry.theme
	self.currentPath = entry.path

	local spawncommand = g_spawnCategoryToCmd[self.currentCategory]
	if not spawncommand then
		self:ProcessNextEntry()
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

		self:ProcessNextEntry()
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

		self:ProcessNextEntry()
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

	if LIBEntities.IsMarkedForDeletion(ent) then
		self:ProcessNextEntry()
		return
	end

	if self.OnSpawn then
		ProtectedCall(self.OnSpawn, self, ent)
	end

	if LIBEntities.IsMarkedForDeletion(ent) then
		self:ProcessNextEntry()
		return
	end

	SLIGWOLF_ADDON:TimerRemove(self.timeoutEntityTimer)

	self:RemoveSpawnHooks()

	local entry = self.currentEntry

	local entPos = entry.entity.pos
	local entAng = entry.entity.ang
	local entSpawnFrozen = entry.entity.spawnFrozen

	local addon = SligWolf_Addons.GetAddon(self.currentAddonname)
	if not addon then
		self:ProcessNextEntry()
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
		self:MovePlayerToCamera(function()
			self:WaitForEntityReady(function()
				self:SendCaptureRequest()
			end)
		end)
	end)
end

function META:WaitForEntityReady(callback)
	if not self:ValidateState() then
		return
	end

	local ent = self.currentEntity

	if LIBEntities.IsMarkedForDeletion(ent) then
		self:ProcessNextEntry()
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

		if LIBEntities.IsMarkedForDeletion(ent) then
			self:ProcessNextEntry()
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

			if LIBEntities.IsMarkedForDeletion(ent) then
				self:ProcessNextEntry()
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

	if not IsValid(ent) then
		self:ProcessNextEntry()
		return
	end

	local entry = self.currentEntry
	local camera = entry.camera
	local dof = camera.dof

	LIBNet.Start("zdevtools_icongen_start")
		net.WriteString(self.name)
		net.WriteUInt(self.processSubId, 32)
		net.WriteString(self.currentPath or "")

		net.WriteVector(camera.pos)
		net.WriteAngle(camera.ang)
		net.WriteFloat(camera.fov)

		net.WriteFloat(dof.distance)
		net.WriteFloat(dof.blur)
		net.WriteUInt(dof.passes, 8)
		net.WriteUInt(dof.steps, 8)
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
		self:Cancel()
		return
	end

	self:CleanupSpawn()

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

