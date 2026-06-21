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
local LIBTrace = SligWolf_Addons.Trace
local LIBHook = SligWolf_Addons.Hook
local LIBFile = SligWolf_Addons.File
local LIBUtil = SligWolf_Addons.Util
local LIBNet = SligWolf_Addons.Net

local META = LIB.meta

LIB.renderTarget = nil
LIB.renderTargetMaterial = nil
LIB.bufferRenderTarget = nil
LIB.bufferRenderTargetMaterial = nil
LIB.superDofResources = nil

LIBNet.Receive("zdevtools_icongen_start", function(len)
	local name = net.ReadString()
	local processSubId = net.ReadUInt(32)
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

LIBHook.Add("OnScreenSizeChanged", "Addon_ZDevTools_Icongen_ScreenResized", function()
	LIB.renderTarget = nil
	LIB.renderTargetMaterial = nil
	LIB.bufferRenderTarget = nil
	LIB.bufferRenderTargetMaterial = nil
	LIB.superDofResources = nil
end)

LIB.currentView = {
	pos = Vector(),
	ang = Angle(),
	fov = 0,
}

LIBHook.Add("CalcView", "Addon_ZDevTools_Icongen_Camera", function(ply, origin, angles, fov)
	local view = LIB.currentView

	view.pos = origin
	view.ang = angles
	view.fov = fov

	local camera = LIB.GetCamera()
	if not camera then
		return
	end

	view.pos = camera.pos
	view.ang = camera.ang
	view.fov = camera.fov

	return {
		origin = camera.pos,
		angles = camera.ang,
		fov = camera.fov,
		drawviewer = false
	}
end)

LIBHook.Add("RenderScene", "Addon_ZDevTools_Icongen_SuperDof", function(pos, ang, fov)
	local camera = LIB.GetCamera()
	if not camera then
		return
	end

	local superDof = LIB.GetSuperDof()

	if not superDof then
		return
	end

	if superDof.rendered then
		return
	end

	local distance = superDof.distance
	local blur = superDof.blur
	local passes = superDof.passes
	local steps = superDof.steps

	local focuspoint = pos + ang:Forward() * distance

	superDof.rendered = false

	RenderDoF( pos, ang, focuspoint, blur, steps, passes, true, nil, fov )

	local resources = LIB.GetSuperDofResources()
	local tex = resources.tex
	local mat = resources.mat

	mat:SetFloat( "$alpha", 1 )
	mat:SetTexture( "$basetexture", tex )

	render.SetMaterial( mat )
	render.DrawScreenQuad()

	superDof.rendered = true

	LIB.RequestCopyScreenCopyScreenToBuffer()

	return true
end )

function LIB.GetRenderTarget()
	if LIB.renderTarget then
		return LIB.renderTarget
	end

	local rendertargetConfig = LIB.config.rendertarget
	local width = rendertargetConfig.width
	local height = rendertargetConfig.height

	local name = string.format(
		"sligwolf_zdevtools_icongen_rendertarget[%ix%i]",
		width,
		height
	)

	local sizeMode = RT_SIZE_DEFAULT
	local depthMode = MATERIAL_RT_DEPTH_SEPARATE

	local textureFlags = bit.bor(
		1, -- TEXTUREFLAGS_POINTSAMPLE
		256, -- TEXTUREFLAGS_NOMIP
		512 -- TEXTUREFLAGS_NOLOD
	)

	local rtFlags = 0
	local imageFormat = IMAGE_FORMAT_RGBA8888

	local renderTarget = GetRenderTargetEx(
		name,
		width,
		height,
		sizeMode,
		depthMode,
		textureFlags,
		rtFlags,
		imageFormat
	)

	LIB.renderTarget = renderTarget
	return LIB.renderTarget
end

function LIB.GetRenderTargetMaterial()
	if LIB.renderTargetMaterial then
		return LIB.renderTargetMaterial
	end

	local renderTarget = LIB.GetRenderTarget()

	local viewW = renderTarget:Width()
	local viewH = renderTarget:Height()

	local name = string.format(
		"sligwolf_zdevtools_icongen_rendertarget_material[%ix%i]",
		viewW,
		viewH
	)

	local renderTargetMaterial = CreateMaterial(name, "UnlitGeneric", {
		["$basetexture"] = renderTarget:GetName(),
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 0,
		["$ignorez"] = 1,
		["$nocull"] = 1,
		["$nolod"] = 1,
		["$selfillum"] = 1,
		["$translucent"] = 0,
	})

	LIB.renderTargetMaterial = renderTargetMaterial
	return renderTargetMaterial
end

function LIB.GetBufferRenderTarget()
	if LIB.bufferRenderTarget then
		return LIB.bufferRenderTarget
	end

	local width = ScrW()
	local height = ScrH()

	local name = string.format(
		"sligwolf_zdevtools_icongen_buffer_rendertarget[%ix%i]",
		width,
		height
	)

	local sizeMode = RT_SIZE_DEFAULT
	local depthMode = MATERIAL_RT_DEPTH_SEPARATE

	local textureFlags = bit.bor(
		1, -- TEXTUREFLAGS_POINTSAMPLE
		256, -- TEXTUREFLAGS_NOMIP
		512 -- TEXTUREFLAGS_NOLOD
	)

	local rtFlags = 0
	local imageFormat = IMAGE_FORMAT_RGBA8888

	local bufferRenderTarget = GetRenderTargetEx(
		name,
		width,
		height,
		sizeMode,
		depthMode,
		textureFlags,
		rtFlags,
		imageFormat
	)

	LIB.bufferRenderTarget = bufferRenderTarget
	return LIB.bufferRenderTarget
end

function LIB.GetBufferRenderTargetMaterial()
	if LIB.bufferRenderTargetMaterial then
		return LIB.bufferRenderTargetMaterial
	end

	local bufferRenderTarget = LIB.GetBufferRenderTarget()

	local bufferW = bufferRenderTarget:Width()
	local bufferH = bufferRenderTarget:Height()

	local name = string.format(
		"sligwolf_zdevtools_icongen_buffer_rendertarget_material[%ix%i]",
		bufferW,
		bufferH
	)

	local bufferRenderTargetMaterial = CreateMaterial(name, "UnlitGeneric", {
		["$basetexture"] = bufferRenderTarget:GetName(),
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 0,
		["$ignorez"] = 1,
		["$nocull"] = 1,
		["$nolod"] = 1,
		["$selfillum"] = 1,
		["$translucent"] = 0,
		["$nodepthtest"] = 1,
	})

	LIB.bufferRenderTargetMaterial = bufferRenderTargetMaterial
	return bufferRenderTargetMaterial
end

function LIB.GetSuperDofResources()
	if LIB.superDofResources then
		return LIB.superDofResources
	end

	local tex = render.GetSuperFPTex()
	local mat = Material( "pp/motionblur" )

	local superDofResources = {
		tex = tex,
		mat = mat,
	}

	LIB.superDofResources = superDofResources
	return LIB.superDofResources
end


function LIB.CopyScreenCopyScreenToBuffer()
	local bufferRenderTarget = LIB.GetBufferRenderTarget()

	local superDof = LIB.GetSuperDof()
	if superDof and superDof.rendered then
		local resources = LIB.GetSuperDofResources()
		local tex = resources.tex

		render.CopyTexture(tex, bufferRenderTarget)
		return
	end

	render.CopyRenderTargetToTexture(bufferRenderTarget)
end

function LIB.CopyScreenCopyScreenToBufferIfRequested()
	if not LIB.requestCopyScreenToBuffer then
		return
	end

	if not LIB.HasSuperDofRendered() then
		return
	end

	LIB.CopyScreenCopyScreenToBuffer()
	LIB.requestCopyScreenToBuffer = nil
end

function LIB.RequestCopyScreenCopyScreenToBuffer()
	LIB.requestCopyScreenToBuffer = true
end

function LIB.SetCamera(camera)
	LIB.currentCamera = camera
end

function LIB.ResetCamera()
	LIB.currentCamera = nil
end

function LIB.GetCamera()
	return LIB.currentCamera
end

function LIB.GetView()
	return LIB.currentView
end

function LIB.SetSuperDof(superDof)
	if not superDof then
		LIB.ResetSuperDof()
		return
	end

	local distance = superDof.distance
	if distance <= 0 then
		LIB.ResetSuperDof()
		return
	end

	local blurSize = superDof.blur
	if blurSize <= 0 then
		LIB.ResetSuperDof()
		return
	end

	local passes = superDof.passes
	if passes <= 0 then
		LIB.ResetSuperDof()
		return
	end

	local steps = superDof.steps
	if steps <= 0 then
		LIB.ResetSuperDof()
		return
	end

	superDof.rendered = false
	LIB.currentSuperDof = superDof
end

function LIB.GetSuperDof()
	return LIB.currentSuperDof
end

function LIB.ResetSuperDof()
	LIB.currentSuperDof = nil
end

function LIB.HasSuperDofRendered()
	local superDof = LIB.GetSuperDof()
	if not superDof then
		return true
	end

	if not superDof.rendered then
		return false
	end

	return true
end

function LIB.FindTargetEntityInView()
	local view = LIB.GetView()
	local pos = view.pos
	local ang = view.ang
	local fov = view.fov

	local normal = ang:Forward()
	local maxDofDistance = LIB.config.maxDofDistance

	local entities = LIBEntities.FindEntitiesInCone(pos, normal, maxDofDistance, fov)

	local nearestEnt = nil
	local nearestDistSq = nil

	for _, ent in ipairs(entities) do
		if not IsValid(ent) then
			continue
		end

		local parent = ent:GetParent()
		if IsValid(parent) then
			-- We don't care about finding parented entities
			continue
		end

		local superparent = LIBEntities.GetSuperParent(ent)
		if not IsValid(superparent) then
			continue
		end

		local spawntable = LIBEntities.GetSpawntable(superparent, true)
		if not spawntable then
			continue
		end

		if not spawntable.Is_SLIGWOLF then
			continue
		end

		local distSq = pos:DistToSqr(superparent:GetPos())
		if not nearestDistSq or distSq < nearestDistSq then
			nearestDistSq = distSq
			nearestEnt = superparent
		end
	end

	return nearestEnt
end

function LIB.EstimateViewWorkloadEntry()
	local view = LIB.GetView()

	local pos = view.pos
	local ang = view.ang
	local fov = view.fov

	local ent = LIB.FindTargetEntityInView()
	if not IsValid(ent) then
		return nil
	end

	local spawnname = LIBEntities.GetSpawnname(ent, true)
	if not spawnname then
		return nil
	end

	local spawntable = LIBEntities.GetSpawntable(ent, true)
	if not spawntable then
		return nil
	end

	local dof = nil

	local currentCamera = LIB.GetCamera()

	local defaults = LIB.config.defaults
	local defaultsCamera = defaults.camera

	if currentCamera then
		local currentDof = LIB.GetSuperDof()
		if currentDof and currentDof.distance > 0 then
			dof = {
				distance = currentDof.distance,
				blur = currentDof.blur,
				passes = currentDof.passes,
				steps = currentDof.steps,
			}
		end
	else
		local maxDofDistance = LIB.config.maxDofDistance

		local tr = LIBTrace.PlayerAimTrace(LocalPlayer(), maxDofDistance)

		local distance = tr.Hit and tr.HitPos:Distance(tr.StartPos) or 0
		distance = math.Clamp(distance or 0, 0, maxDofDistance)

		if distance > 0 then
			dof = {
				distance = distance,
				blur = defaultsCamera.dof.blur,
				passes = defaultsCamera.dof.passes,
				steps = defaultsCamera.dof.steps,
			}
		end
	end

	local workloadEntry = {
		map = game.GetMap(),
		category = spawntable.SLIGWOLF_SkinCategory,
		spawnname = spawnname,
		theme = defaults.theme,
		camera = {
			pos = pos,
			ang = ang,
			fov = fov,
			dof = dof,
		},
		entity = {
			pos = ent:GetPos(),
			ang = ent:GetAngles(),
		},
	}

	return workloadEntry
end

local g_lineBuffer = {}

function LIB.DrawPreviewScreen()
	local renderTargetMaterial = LIB.GetRenderTargetMaterial()
	local bufferRenderTargetMaterial = LIB.GetBufferRenderTargetMaterial()

	local viewW = renderTargetMaterial:Width()
	local viewH = renderTargetMaterial:Height()

	local bufferW = bufferRenderTargetMaterial:Width()
	local bufferH = bufferRenderTargetMaterial:Height()

	local scale = math.min(bufferW / viewW, bufferH / viewH)

	local newW = viewW * scale
	local newH = viewH * scale

	local centerX = (bufferW - newW) / 2
	local centerY = (bufferH - newH) / 2

	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)

	surface.SetMaterial(bufferRenderTargetMaterial)
	surface.SetDrawColor(96, 96, 96, 255)
	surface.DrawTexturedRect(0, 0, bufferW, bufferH)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(renderTargetMaterial)
	surface.DrawTexturedRect(centerX, centerY, newW, newH)

	local workloadEntry = LIB.EstimateViewWorkloadEntry()

	table.Empty(g_lineBuffer)

	if workloadEntry then
		local entity = workloadEntry.entity
		local camera = workloadEntry.camera
		local dof = camera.dof

		g_lineBuffer[#g_lineBuffer + 1] = string.format("Spawnname: %s", workloadEntry.spawnname)
		g_lineBuffer[#g_lineBuffer + 1] = string.format("Category: %s", workloadEntry.category)
		g_lineBuffer[#g_lineBuffer + 1] = string.format("Map: %s", workloadEntry.map)

		g_lineBuffer[#g_lineBuffer + 1] = ""
		g_lineBuffer[#g_lineBuffer + 1] = "Entity: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Pos: Vector(%10.3f, %10.3f, %10.3f)", entity.pos:Unpack())
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Ang:  Angle(%10.3f, %10.3f, %10.3f)", entity.ang:Unpack())

		g_lineBuffer[#g_lineBuffer + 1] = ""
		g_lineBuffer[#g_lineBuffer + 1] = "Camera: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Pos: Vector(%10.3f, %10.3f, %10.3f)", camera.pos:Unpack())
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Ang:  Angle(%10.3f, %10.3f, %10.3f)", camera.ang:Unpack())
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  FOV: %8.3f", camera.fov)

		if dof and dof.distance > 0 then
			g_lineBuffer[#g_lineBuffer + 1] = ""
			g_lineBuffer[#g_lineBuffer + 1] = "DOF: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Distance: %10.3f", dof.distance)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Blur: %7.3f", dof.blur)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Passes: %3i", dof.passes)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Steps: %3i", dof.steps)
		end
	else
		local view = LIB.GetView()

		g_lineBuffer[#g_lineBuffer + 1] = "Camera: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Pos: Vector(%10.3f, %10.3f, %10.3f)", view.pos:Unpack())
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Ang:  Angle(%10.3f, %10.3f, %10.3f)", view.ang:Unpack())
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  FOV: %7.3f", view.fov)
	end

	local linesCount = #g_lineBuffer

	local textX = 32
	local textH = 32
	local textY = bufferH - linesCount * textH - 10

	surface.SetFont("DebugOverlay")
	surface.SetTextColor(255, 255, 255)

	for i, line in ipairs(g_lineBuffer) do
		local lineY = textY + (i - 1) * textH

		if line == "" then
			continue
		end

		surface.SetTextPos(textX, lineY)
		surface.DrawText(line)
	end

	render.PopFilterMin()
	render.PopFilterMag()
end

function LIB.RenderBufferToRenderTarget()
	local renderTarget = LIB.GetRenderTarget()
	local bufferRenderTargetMaterial = LIB.GetBufferRenderTargetMaterial()

	local viewW = renderTarget:Width()
	local viewH = renderTarget:Height()

	local bufferW = bufferRenderTargetMaterial:Width()
	local bufferH = bufferRenderTargetMaterial:Height()

	local squareSize = math.min(bufferW, bufferH)
	local bufferX = math.floor((bufferW - squareSize) / 2)
	local bufferY = math.floor((bufferH - squareSize) / 2)

	local u0 = bufferX / bufferW
	local v0 = bufferY / bufferH
	local u1 = (bufferX + squareSize) / bufferW
	local v1 = (bufferY + squareSize) / bufferH

	render.PushRenderTarget(renderTarget, 0, 0, viewW, viewH)
		render.Clear(0, 0, 0, 255, true, true)

		render.OverrideAlphaWriteEnable(true, true)

		cam.Start2D()
			surface.SetMaterial(bufferRenderTargetMaterial)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRectUV(0, 0, viewW, viewH, u0, v0, u1, v1)
		cam.End2D()

		render.OverrideAlphaWriteEnable(false)
	render.PopRenderTarget()
end

function LIB.ClearRenderTarget()
	local renderTarget = LIB.GetRenderTarget()

	local viewW = renderTarget:Width()
	local viewH = renderTarget:Height()

	render.PushRenderTarget(renderTarget, 0, 0, viewW, viewH)
		render.Clear(0, 0, 0, 255, true, true)
	render.PopRenderTarget()
end

function LIB.ClearBufferRenderTarget()
	local bufferRenderTarget = LIB.GetBufferRenderTarget()

	local bufferW = bufferRenderTarget:Width()
	local bufferH = bufferRenderTarget:Height()

	render.PushRenderTarget(bufferRenderTarget, 0, 0, bufferW, bufferH)
		render.Clear(0, 0, 0, 255, true, true)
	render.PopRenderTarget()
end

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

	self.isProcessing = true
end

function META:DestroyInternal()
	self:RemoveDelayTimer()

	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ClearBufferRenderTarget()
	LIB.ClearRenderTarget()
end

function META:CancelInternal()
	self:RemoveDelayTimer()

	LIB.ResetCamera()
	LIB.ResetSuperDof()
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

	if not self.isProcessing then
		self:SendCaptureFail()
		return
	end

	if not self.currentCaptureRequest then
		self:ProcessStart()
	end

	self.currentCaptureRequest = captureRequest
	self.processSubId = captureRequest.processSubId

	self:ShowPreviewAndCapture()
end

function META:ProcessStart()
	LIB.ResetCamera()
	LIB.ResetSuperDof()
	LIB.ClearBufferRenderTarget()
	LIB.ClearRenderTarget()
end

function META:SendCaptureDone()
	if not self:ValidateState() then
		return
	end

	local captureRequest = self.currentCaptureRequest

	LIBNet.Start("zdevtools_icongen_done")
		net.WriteString(self.name)
		net.WriteUInt(captureRequest.processSubId, 32)
		net.WriteBool(true)
	LIBNet.SendToServer()
end

function META:SendCaptureFail()
	if not self:ValidateState() then
		return
	end

	local captureRequest = self.currentCaptureRequest

	LIBNet.Start("zdevtools_icongen_done")
		net.WriteString(self.name)
		net.WriteUInt(captureRequest.processSubId, 32)
		net.WriteBool(false)
	LIBNet.SendToServer()
end

function META:ShowPreviewAndCapture()
	if not self:ValidateState() then
		return
	end

	local captureRequest = self.currentCaptureRequest

	local processSubId = self.processSubId
	local screenDelayTimer = self.screenDelayTimer

	LIB.SetCamera(captureRequest.camera)
	LIB.SetSuperDof(captureRequest.camera.dof)
	LIB.RequestCopyScreenCopyScreenToBuffer()

	if gui.IsGameUIVisible() then
		-- Close the main menu when we start rendering
		ProtectedCall(RunConsoleCommand, "gamemenucommand", "ResumeGame")
	end


	SLIGWOLF_ADDON:TimerUntil(screenDelayTimer, 0, function(addon, success)
		if not IsValid(self) then
			return true
		end

		if not self:ValidateState() then
			return true
		end

		if self.processSubId ~= processSubId then
			return true
		end

		if not success then
			self:SendCaptureFail()
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

			if not self:ValidateState() then
				return
			end

			if self.processSubId ~= processSubId then
				return
			end

			local menuIsOpen = LIB.IsUIOpen()
			if menuIsOpen then
				self:SendCaptureFail()
				return
			end

			if not self:CaptureAndSave() then
				self:SendCaptureFail()
				return
			end

			self:SendCaptureDone()
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

