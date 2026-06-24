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
local LIBFile = SligWolf_Addons.File
local LIBUtil = SligWolf_Addons.Util
local LIBNet = SligWolf_Addons.Net

local META = LIB.meta

LIBNet.Receive("zdevtools_icongen_start", function(len)
	local name = net.ReadString()
	local processSubId = net.ReadUInt(32)
	local index = net.ReadUInt(16)
	local count = net.ReadUInt(16)
	local path = net.ReadString()
	local ent = net.ReadEntity()

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
		ent = ent,
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

function LIB.IsUIOpen()
	if gui.IsGameUIVisible() then
		return true
	end

	if LIBUtil.GameIsPaused() then
		return true
	end

	if vgui.GetHoveredPanel() ~= nil then
		return true
	end

	if vgui.GetKeyboardFocus() ~= nil then
		return true
	end

	return false
end

function META:ResetInternal()
	self.currentCaptureRequest = nil
	self.processSubId = nil

	self.currentEntity = nil
	self.currentIndex = nil
	self.workloadCount = nil

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
	LIB.ResetEntity()
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
	LIB.ResetEntity()
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

	local ent = captureRequest.ent
	local index = captureRequest.index
	local count = captureRequest.count

	self.currentEntity = ent
	self.currentIndex = index
	self.workloadCount = count

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
	LIB.ResetEntity()
	LIB.ClearBuffer()
	LIB.ClearCanvas()
	LIB.RemoveRequestDofRenderCallback(self.dofCallback)
	LIB.RemoveRequestCopyToBufferCallback(self.copyCallback)

	if gui.IsGameUIVisible() then
		-- Close the main menu when we start rendering
		ProtectedCall(RunConsoleCommand, "gamemenucommand", "ResumeGame")
	end

	if self.OnStart then
		ProtectedCall(self.OnStart, self)
	end
end

function META:ProcessEnd()
	self.isProcessing = false

	self.currentCaptureRequest = nil
	self.processSubId = nil

	self.currentEntity = nil
	self.workloadCount = nil
	self.currentIndex = 0

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ResetEntity()
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

	local captureRequest = self.currentCaptureRequest
	local index = self.currentIndex
	local count = self.workloadCount
	local ent = self.currentEntity

	local processSubId = self.processSubId
	local screenDelayTimer = self.screenDelayTimer
	local dofCallback = self.dofCallback
	local copyCallback = self.copyCallback

	LIB.SetCamera(captureRequest.camera)
	LIB.SetSuperDof(captureRequest.camera.dof)
	LIB.SetProgressStats(index, count)
	LIB.SetEntity(ent)

	local validate = function()
		if not IsValid(self) then
			return false
		end

		if self.processSubId ~= processSubId then
			return false
		end

		if not self:ValidateState() then
			return false
		end

		if LIB.IsUIOpen() then
			self:Warn("ShowPreviewAndCapture: Can not capture render target with menus open.")
			self:SendCaptureDone(false)
			return false
		end

		return true
	end

	local capture = function()
		if not validate() then
			return
		end

		if not self:CaptureAndSave() then
			self:Warn("ShowPreviewAndCapture: Could not capture render target.")
			self:SendCaptureDone(false)
			return
		end

		self:SendCaptureDone(true)
	end

	local renderBufferToCanvas = function()
		if not validate() then
			return
		end

		LIB.RenderBufferToCanvas()
		SLIGWOLF_ADDON:TimerOnce(screenDelayTimer, self.config.time.preview, capture)
	end

	local requestCopyToBuffer = function()
		if not validate() then
			return
		end

		LIB.RequestCopyToBuffer(copyCallback, renderBufferToCanvas)
	end

	local nextFrame = function()
		if not validate() then
			return
		end

		LIB.RequestDofRender(false, dofCallback, requestCopyToBuffer)
	end

	SLIGWOLF_ADDON:TimerNextFrame(self.config.time.preview, nextFrame)
end

function META:CaptureAndSave()
	if not self:ValidateState() then
		return false
	end

	local captureRequest = self.currentCaptureRequest
	local path = captureRequest.path or ""

	if path == "" then
		self:Warn("CaptureAndSave: No path given.")
		return false
	end

	local renderTarget = LIB.GetRenderTarget()

	local viewW = renderTarget:Width()
	local viewH = renderTarget:Height()

	local iconsFolder = self.config.iconsFolder
	local filename = iconsFolder .. "/" .. captureRequest.path

	local data = nil

	render.PushRenderTarget(renderTarget, 0, 0, viewW, viewH)
		ProtectedCall(function()
			data = render.Capture({
				format = "png",
				alpha = false,
				x = 0,
				y = 0,
				w = viewW,
				h = viewH,
			})
		end)
	render.PopRenderTarget()

	if not data then
		self:Warn("CaptureAndSave: No data returned.")
		return false
	end

	if data == "" then
		self:Warn("CaptureAndSave: No data returned.")
		return false
	end

	local absoluteFilename = LIBFile.GetAbsolutePath(filename, SLIGWOLF_ADDON)

	local success = LIBFile.Write(filename, data, SLIGWOLF_ADDON)
	if not success then
		self:Warn("CaptureAndSave: Could not write too 'data/%s'.", absoluteFilename)
		return false
	end

	if self.OnFileWritten then
		ProtectedCall(self.OnFileWritten, self, filename, absoluteFilename)
	end

	return true
end

function META:RemoveDelayTimer()
	SLIGWOLF_ADDON:TimerRemove(self.screenDelayTimer)
end

return true

