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
local LIBPrint = SligWolf_Addons.Print
local LIBNet = SligWolf_Addons.Net

local META = LIB.meta

LIBNet.Receive("zdevtools_icongen_start", function(len)
	local name = net.ReadString()
	local processSubId = net.ReadUInt(32)
	local index = net.ReadUInt(16)
	local count = net.ReadUInt(16)

	local addonname = net.ReadString()
	local category = net.ReadString()
	local spawnname = net.ReadString()
	local theme = net.ReadString()
	local ent = net.ReadEntity()

	local path = net.ReadString()

	local pos = net.ReadVector()
	local ang = net.ReadAngle()
	local fov = net.ReadFloat()

	local distance = net.ReadFloat()
	local blur = net.ReadFloat()
	local passes = net.ReadUInt(8)
	local steps = net.ReadUInt(8)
	local shape = net.ReadFloat()

	local instance = LIB.GetInstance(name)
	if not IsValid(instance) then
		return
	end

	local captureRequest = {
		processSubId = processSubId,
		index = index,
		count = count,
		path = path,

		entity = {
			addonname = addonname,
			category = category,
			spawnname = spawnname,
			theme = theme,
			ent = ent,
		},

		camera = {
			pos = pos,
			ang = ang,
			fov = fov,
			dof = {
				distance = distance,
				blur = blur,
				passes = passes,
				steps = steps,
				shape = shape,
			},
		},
	}

	instance:HandleCaptureRequest(captureRequest)
end)

function META:ResetInternal()
	self.currentCaptureRequest = nil
	self.processSubId = nil

	self.currentIndex = 0
	self.workloadCount = nil
	self.currentPath = nil

	self.currentAddonname = nil
	self.currentCategory = nil
	self.currentSpawnname = nil
	self.currentTheme = nil
	self.currentEntity = nil

	self.entriesTotal = 0
	self.entriesRun = 0
	self.entriesDone = 0
	self.entriesError = 0

	self.screenDelayTimer = string.format("screendelay_%s", self.namespace)
	self.dofCallback = string.format("dofcallback_%s", self.namespace)
	self.copyCallback = string.format("copycallback_%s", self.namespace)
end

function META:Initialize()
	local ply = LocalPlayer()

	if not IsValid(ply) or not ply:IsPlayer() then
		LIBPrint.Error("No player provided.")
		return
	end

	self.player = ply
	self.isProcessing = false
	self.isListening = false
end

function META:Start()
	local ply = self.player

	if not IsValid(ply) or not ply:IsPlayer() then
		LIBPrint.Error("No Player given, call Initialize() first.")
		return
	end

	self.isProcessing = false
	self.isListening = true
end

function META:DestroyInternal()
	self:RemoveDelayTimer()

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ResetEntityData()
	LIB.ClearBuffer()
	LIB.ClearCanvas()
	LIB.RemoveRequestDofRenderCallback(self.dofCallback)
	LIB.RemoveRequestCopyToBufferCallback(self.copyCallback)
end

function META:CancelInternal()
	self:RemoveDelayTimer()

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ResetEntityData()
	LIB.ClearBuffer()
	LIB.ClearCanvas()
	LIB.RemoveRequestDofRenderCallback(self.dofCallback)
	LIB.RemoveRequestCopyToBufferCallback(self.copyCallback)
end

function META:ValidateEntity(ent)
	if not LIBEntities.IsMarkedForDeletion(ent) then
		return true
	end

	if self.OnEarlyEntityRemove then
		ProtectedCall(self.OnEarlyEntityRemove, self)
	end

	self:Warn("ValidateEntity: Entity has been removed early.")
	return false
end

function META:ValidateStateInternal()
	if not self.currentCaptureRequest then
		return false
	end

	if table.IsEmpty(self.currentCaptureRequest) then
		return false
	end

	if not self:ValidateEntity(self.currentEntity) then
		return false
	end

	return true
end

function META:HandleCaptureRequest(captureRequest)
	if not captureRequest then
		return
	end

	self:RemoveDelayTimer()

	if not self.isListening then
		return
	end

	self.currentCaptureRequest = captureRequest
	self.processSubId = captureRequest.processSubId

	local entity = captureRequest.entity
	local index = captureRequest.index
	local count = captureRequest.count

	self.currentIndex = index
	self.workloadCount = count
	self.currentPath = captureRequest.path

	self.currentAddonname = entity.addonname
	self.currentCategory = entity.category
	self.currentSpawnname = entity.spawnname
	self.currentTheme = entity.theme
	self.currentEntity = entity.ent

	if index == 1 then
		self:ProcessStart()
	end

	if self.OnProgress then
		ProtectedCall(self.OnProgress, self, index, count)
	end

	self:ShowPreviewAndCapture()
end

function META:ProcessStart()
	self.isProcessing = true

	self.entriesTotal = self.workloadCount
	self.entriesRun = 0
	self.entriesDone = 0
	self.entriesError = 0

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ResetEntityData()
	LIB.ClearBuffer()
	LIB.ClearCanvas()
	LIB.RemoveRequestDofRenderCallback(self.dofCallback)
	LIB.RemoveRequestCopyToBufferCallback(self.copyCallback)

	LIB.CloseMainMenu()

	if self.OnStart then
		ProtectedCall(self.OnStart, self)
	end
end

function META:ProcessEnd()
	self.isProcessing = false

	self.currentCaptureRequest = nil
	self.processSubId = nil

	self.currentIndex = 0
	self.workloadCount = nil
	self.currentPath = nil

	self.currentAddonname = nil
	self.currentCategory = nil
	self.currentSpawnname = nil
	self.currentTheme = nil
	self.currentEntity = nil

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ResetEntityData()
	LIB.ClearBuffer()
	LIB.ClearCanvas()
	LIB.RemoveRequestDofRenderCallback(self.dofCallback)
	LIB.RemoveRequestCopyToBufferCallback(self.copyCallback)

	if self.OnFinished then
		ProtectedCall(self.OnFinished, self)
	end

	self.entriesTotal = 0
	self.entriesRun = 0
	self.entriesDone = 0
	self.entriesError = 0
end

function META:SendCaptureDone(success)
	if not self:ValidateState() then
		return
	end

	local name = self.name
	local processSubId = self.processSubId
	local index = self.currentIndex
	local count = self.workloadCount

	if not success then
		self.entriesRun = math.min(self.entriesRun + 1, self.entriesTotal)
		self.entriesError = math.min(self.entriesError + 1, self.entriesTotal)

		self:Cancel()

		LIBNet.Start("zdevtools_icongen_done")
			net.WriteString(name)
			net.WriteUInt(processSubId, 32)
			net.WriteBool(false)
		LIBNet.SendToServer()

		return
	end

	self.entriesRun = math.min(self.entriesRun + 1, self.entriesTotal)
	self.entriesDone = math.min(self.entriesDone + 1, self.entriesTotal)

	if self.OnProgressDone then
		ProtectedCall(self.OnProgressDone, self, index, count)
	end

	if index >= count then
		self:ProcessEnd()
	end

	LIBNet.Start("zdevtools_icongen_done")
		net.WriteString(name)
		net.WriteUInt(processSubId, 32)
		net.WriteBool(true)
	LIBNet.SendToServer()
end

function META:ShowPreviewAndCapture()
	if not self:ValidateState() then
		return
	end

	local processSubId = self.processSubId
	local captureRequest = self.currentCaptureRequest
	local index = self.currentIndex
	local count = self.workloadCount
	local path = self.currentPath

	local entityData = {
		addonname = self.currentAddonname,
		category = self.currentCategory,
		spawnname = self.currentSpawnname,
		theme = self.currentTheme,
		ent = self.currentEntity,
	}

	local validateCallback = function()
		if not IsValid(self) then
			return false
		end

		if self.processSubId ~= processSubId then
			return false
		end

		if not self:ValidateState() then
			return false
		end

		return true
	end

	local callback = function(success, errorOrPath, absolutePath)
		if not success then
			self:Warn("ShowPreviewAndCapture: %s", errorOrPath)
			self:SendCaptureDone(false)
			return
		end

		local workloadEntry = LIB.GetViewWorkloadEntry()
		if workloadEntry then
			local jsonPath = self.config.iconsFolderAutoJson .. "/" .. path .. ".json"
			LIB.SaveWorkloadEntry(jsonPath, workloadEntry)
		end

		self:SendCaptureDone(true)

		if self.OnFileWritten then
			ProtectedCall(self.OnFileWritten, self, errorOrPath, absolutePath)
		end
	end

	LIB.TakeScreenshot({
		camera = captureRequest.camera,
		index = index,
		count = count,
		entityData = entityData,
		imagePath = self.config.iconsFolderAuto .. "/" .. path,
		previewTime = self.config.time.preview,
		validateCallback = validateCallback,
		callback = callback,
	})
end

function META:RemoveDelayTimer()
	SLIGWOLF_ADDON:TimerRemove(self.screenDelayTimer)
end

return true

