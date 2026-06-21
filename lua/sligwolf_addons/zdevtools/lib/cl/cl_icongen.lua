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

	local pos = net.ReadVector()
	local ang = net.ReadAngle()
	local fov = net.ReadFloat()

	local distance = net.ReadFloat()
	local blur = net.ReadFloat()
	local passes = net.ReadUInt(8)
	local steps = net.ReadUInt(8)

	local instance = LIB.GetInstance(name)
	if not IsValid(instance) then
		return
	end

	local captureRequest = {
		processSubId = processSubId,
		index = index,
		count = count,
		path = path,
		camera = {
			pos = pos,
			ang = ang,
			fov = fov,
			dof = {
				distance = distance,
				blur = blur,
				passes = passes,
				steps = steps,
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

	self.currentIndex = nil
	self.workloadCount = nil

	self.screenDelayTimer = string.format("screendelay_%s", self.namespace)
end

function META:Initialize()
	local ply = LocalPlayer()

	if not IsValid(ply) or not ply:IsPlayer() then
		error("No player provided")
		return
	end

	if self:IsLocked() then
		error("System is already locked by another instance")
		return
	end

	self.player = ply
	self.isProcessing = false
	self.isListening = false
end

function META:Start()
	local ply = self.player

	if not IsValid(ply) or not ply:IsPlayer() then
		error("No Player given. Call Initialize() first.")
		return
	end

	if self:IsLocked() then
		error("System is already locked by another instance")
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
	LIB.ClearBufferRenderTarget()
	LIB.ClearRenderTarget()
end

function META:CancelInternal()
	self:RemoveDelayTimer()

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ClearBufferRenderTarget()
	LIB.ClearRenderTarget()
end

function META:ValidateStateInternal()
	if not self.currentCaptureRequest then
		return false
	end

	if table.IsEmpty(self.currentCaptureRequest) then
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

	local index = captureRequest.index
	local count = captureRequest.count

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

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ClearBufferRenderTarget()
	LIB.ClearRenderTarget()

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

	self.workloadCount = nil
	self.currentIndex = 0

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ResetProgressStats()
	LIB.ClearBufferRenderTarget()
	LIB.ClearRenderTarget()

	if self.OnFinished then
		ProtectedCall(self.OnFinished, self)
	end
end

function META:SendCaptureDone(success)
	if not self:ValidateState() then
		return
	end

	local captureRequest = self.currentCaptureRequest
	local index = self.currentIndex
	local count = self.workloadCount

	LIBNet.Start("zdevtools_icongen_done")
		net.WriteString(self.name)
		net.WriteUInt(captureRequest.processSubId, 32)
		net.WriteBool(success)
	LIBNet.SendToServer()

	if not success then
		self:Cancel()
		return
	end

	if self.OnProgressDone then
		ProtectedCall(self.OnProgressDone, self, index, count)
	end

	if index >= count then
		self:ProcessEnd()
	end
end

function META:ShowPreviewAndCapture()
	if not self:ValidateState() then
		return
	end

	local captureRequest = self.currentCaptureRequest
	local index = self.currentIndex
	local count = self.workloadCount

	local processSubId = self.processSubId
	local screenDelayTimer = self.screenDelayTimer

	LIB.SetCamera(captureRequest.camera)
	LIB.SetSuperDof(captureRequest.camera.dof)
	LIB.SetProgressStats(index, count)
	LIB.RequestCopyScreenCopyScreenToBuffer()

	SLIGWOLF_ADDON:TimerUntil(screenDelayTimer, 0, function(addon, success)
		if not IsValid(self) then
			return true
		end

		if self.processSubId ~= processSubId then
			return true
		end

		if not self:ValidateState() then
			return true
		end

		if not success then
			self:SendCaptureDone(false)
			return true
		end

		if not LIB.HasSuperDofRendered() then
			-- Wait until the dof render has been completed
			return false
		end

		if LIB.requestCopyScreenToBuffer then
			-- Wait until the frame copy request has been completed
			return false
		end

		LIB.RenderBufferToRenderTarget()

		SLIGWOLF_ADDON:TimerOnce(screenDelayTimer, self.config.time.preview, function()
			if not IsValid(self) then
				return
			end

			if self.processSubId ~= processSubId then
				return
			end

			if not self:ValidateState() then
				return
			end

			local menuIsOpen = LIB.IsUIOpen()
			if menuIsOpen then
				self:SendCaptureDone(false)
				return
			end

			if not self:CaptureAndSave() then
				self:SendCaptureDone(false)
				return
			end

			self:SendCaptureDone(true)
		end)

		return true
	end, 0, 5)
end

function META:CaptureAndSave()
	if not self:ValidateState() then
		return false
	end

	local captureRequest = self.currentCaptureRequest
	local path = captureRequest.path or ""

	if path == "" then
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
		return false
	end

	if data == "" then
		return false
	end

	local success = LIBFile.Write(filename, data, SLIGWOLF_ADDON)
	if not success then
		return false
	end

	return true
end

function META:RemoveDelayTimer()
	SLIGWOLF_ADDON:TimerRemove(self.screenDelayTimer)
end

return true

