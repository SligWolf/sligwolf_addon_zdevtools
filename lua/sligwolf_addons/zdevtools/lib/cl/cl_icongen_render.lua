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
local LIBFile = SligWolf_Addons.File
local LIBHook = SligWolf_Addons.Hook

LIB.renderTarget = nil
LIB.renderTargetMaterial = nil
LIB.bufferRenderTarget = nil
LIB.bufferRenderTargetMaterial = nil

LIB.superDofResources = nil

LIB.hasDofRendered = nil
LIB.hasCanvasRendered = nil
LIB.hasBufferRendered = nil

LIB.renderDofRequest = {}
LIB.copyToBufferRequest = {}

LIB.currentView = {
	pos = Vector(),
	ang = Angle(),
	fov = 0,
}

LIB.currentIndex = nil
LIB.currentCount = nil
LIB.currentCamera = nil
LIB.currentSuperDof = nil

if IsValid(LIB.previewContentIcon) then
	LIB.previewContentIcon:Remove()
	LIB.previewContentIcon = nil
end

LIBHook.Add("OnScreenSizeChanged", "Addon_ZDevTools_Icongen_ScreenResized", function()
	LIB.renderTarget = nil
	LIB.renderTargetMaterial = nil
	LIB.bufferRenderTarget = nil
	LIB.bufferRenderTargetMaterial = nil
	LIB.superDofResources = nil

	LIB.hasDofRendered = nil
	LIB.hasCanvasRendered = nil
	LIB.hasBufferRendered = nil

	if IsValid(LIB.previewContentIcon) then
		LIB.previewContentIcon:Remove()
		LIB.previewContentIcon = nil
	end
end)

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
	local renderDofRequest = LIB.renderDofRequest
	if not renderDofRequest then
		return
	end

	local renderNow = renderDofRequest.renderNow
	if not renderNow then
		return
	end

	local callbacks = renderDofRequest.callbacks
	local realtime = renderDofRequest.realtime

	local superDof = LIB.GetSuperDof()

	if superDof then
		local distance = superDof.distance
		local blur = superDof.blur
		local passes = superDof.passes
		local steps = superDof.steps
		local shape = superDof.shape

		local focus = pos + ang:Forward() * distance

		if realtime then
			LIB.RenderSuperDofRealtime(pos, ang, fov, focus, blur, shape)
			LIB.hasDofRendered = true
		else
			LIB.RenderSuperDof(pos, ang, fov, focus, blur, shape, steps, passes)
			LIB.hasDofRendered = true
		end
	else
		LIB.hasDofRendered = false
	end

	local renderTargetMaterial = LIB.GetRenderTargetMaterial()
	local bufferRenderTargetMaterial = LIB.GetBufferRenderTargetMaterial()

	LIB.CopyScreenToBuffer()

	cam.Start2D()
		LIB.DrawPreviewScreenStats(renderTargetMaterial, bufferRenderTargetMaterial)
	cam.End2D()

	if not realtime then
		if callbacks then
			for _, callback in pairs(callbacks) do
				if not callback then
					continue
				end

				ProtectedCall(callback)
			end
		end

		renderDofRequest.callbacks = nil
		renderDofRequest.renderNow = false
	end
end, 20000)

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

	local texFP = render.GetSuperFPTex()
	local matMotionblur = Material( "pp/motionblur" )
	local matFB = Material( "pp/fb" )

	local superDofResources = {
		texFP = texFP,
		matMotionblur = matMotionblur,
		matFB = matFB,
	}

	LIB.superDofResources = superDofResources
	return LIB.superDofResources
end

function LIB.RenderSuperDof(origin, ang, fov, focus, blur, shape, steps, passes)
	-- Borrowed code from Garry's Mod
	-- garrysmod\lua\postprocess\super_dof.lua

	local renderTargetMaterial = LIB.GetRenderTargetMaterial()
	local bufferRenderTargetMaterial = LIB.GetBufferRenderTargetMaterial()

	local bufferW = bufferRenderTargetMaterial:Width()
	local bufferH = bufferRenderTargetMaterial:Height()

	local OldRT = render.GetRenderTarget()

	local fDistance = origin:Distance(focus)
	blur = blur * math.Clamp(256 / fDistance, 0.1, 1) * 0.5

	local view = {
		x = 0,
		y = 0,
		w = bufferW,
		h = bufferH,
		dopostprocess = true,
		origin = origin,
		angles = ang,
		fov = fov
	}

	local resources = LIB.GetSuperDofResources()
	local texFP = resources.texFP
	local matMotionblur = resources.matMotionblur
	local matFB = resources.matFB

	-- Straight render (to act as a canvas)
	render.RenderView(view)

	render.UpdateScreenEffectTexture()

	render.SetRenderTarget(texFP)
	render.Clear(0, 0, 0, 255, true, true)
	matFB:SetFloat("$alpha", 1)
	render.SetMaterial(matFB)
	render.DrawScreenQuad()

	local hasForcedRealTime = false
	local isRealTime = steps <= 2 and passes <= 2

	local Radials = math.tau / steps
	for mul = 1 / passes, 1, 1 / passes do
		if hasForcedRealTime then
			break
		end

		for i = 0, math.tau, Radials do
			local VA = Angle(ang)
			local VRot = Angle(ang)

			-- Rotate around the focus point
			VA:RotateAroundAxis(VRot:Right(), math.sin(i + mul) * blur * mul * shape * 2)
			VA:RotateAroundAxis(VRot:Up(), math.cos(i + mul) * blur * mul * (1 - shape) * 2)

			view.origin = focus - VA:Forward() * fDistance
			view.angles = VA

			-- Render to the front buffer
			render.SetRenderTarget(OldRT)
			render.Clear(0, 0, 0, 255, true, true)
			render.RenderView(view)
			render.UpdateScreenEffectTexture()

			-- Copy it to our floating point buffer at a reduced alpha
			render.SetRenderTarget(texFP)
			local alpha = Radials / math.tau -- Divide alpha by number of radials
			alpha = alpha * (1 - mul) -- Reduce alpha the further away from center we are
			matFB:SetFloat("$alpha", alpha)

			render.SetMaterial(matFB)
			render.DrawScreenQuad()

			if not isRealTime then
				-- Restore RT
				render.SetRenderTarget(OldRT)

				-- Render our result buffer to the screen
				matMotionblur:SetFloat("$alpha", 1)
				matMotionblur:SetTexture("$basetexture", texFP)
				render.SetMaterial(matMotionblur)
				render.DrawScreenQuad()

				cam.Start2D()
					local add = (i / math.tau) * (1 / passes)
					local percent = (mul - (1 / passes) + add) * 100

					LIB.DrawPreviewScreenStats(renderTargetMaterial, bufferRenderTargetMaterial, percent)
				cam.End2D()

				-- We have to SPIN here to stop the Source engine running out of render queue space.
				render.Spin()
			end
		end
	end

	-- Restore RT
	render.SetRenderTarget(OldRT)
	render.Clear(0, 0, 0, 255, true, true)

	-- Render our result buffer to the screen
	matMotionblur:SetFloat("$alpha", 1)
	matMotionblur:SetTexture("$basetexture", texFP)
	render.SetMaterial(matMotionblur)
	render.DrawScreenQuad()
end

function LIB.RenderSuperDofRealtime(origin, ang, fov, focus, blur, shape)
	LIB.RenderSuperDof(origin, ang, fov, focus, blur, shape, 2, 2)
end

local function copyScreenToBuffer()
	local bufferRenderTarget = LIB.GetBufferRenderTarget()

	if LIB.hasDofRendered then
	 	local resources = LIB.GetSuperDofResources()
	 	local texFP = resources.texFP

	 	render.CopyTexture(texFP, bufferRenderTarget)
		LIB.hasBufferRendered = true
	 	return
	end

	render.CopyRenderTargetToTexture(bufferRenderTarget)
	LIB.hasBufferRendered = true
end

function LIB.CopyScreenToBuffer()
	local copyToBufferRequest = LIB.copyToBufferRequest
	if not copyToBufferRequest then
		return
	end

	local callbacks = copyToBufferRequest.callbacks

	copyScreenToBuffer()

	if callbacks then
		for _, callback in pairs(callbacks) do
			if not callback then
				continue
			end

			ProtectedCall(callback)
		end
	end

	copyToBufferRequest.callbacks = nil
	copyToBufferRequest.copyNow = false
end

function LIB.PollCopyScreenToBuffer()
	local copyToBufferRequest = LIB.copyToBufferRequest
	if not copyToBufferRequest then
		return
	end

	local copyNow = copyToBufferRequest.copyNow
	if not copyNow then
		return
	end

	LIB.CopyScreenToBuffer()
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

function LIB.RequestDofRender(realtime, callbackname, callback)
	local renderDofRequest = LIB.renderDofRequest or {}
	LIB.renderDofRequest = renderDofRequest

	renderDofRequest.renderNow = true
	renderDofRequest.realtime = realtime

	if realtime then
		renderDofRequest.callbacks = nil
		return
	end

	callbackname = tostring(callbackname or "")

	if callbackname ~= "" then
		local callbacks = renderDofRequest.callbacks or {}
		renderDofRequest.callbacks = callbacks

		callbacks[callbackname] = callback
	end
end

function LIB.ResetRequestDofRender()
	local renderDofRequest = LIB.renderDofRequest or {}
	LIB.renderDofRequest = renderDofRequest

	renderDofRequest.realtime = false
	renderDofRequest.renderNow = false
	renderDofRequest.callbacks = nil

	LIB.hasDofRendered = nil
end

function LIB.RemoveRequestDofRenderCallback(callbackname)
	local renderDofRequest = LIB.renderDofRequest or {}
	LIB.renderDofRequest = renderDofRequest

	callbackname = tostring(callbackname or "")
	local callbacks = renderDofRequest.callbacks

	if callbacks and callbackname ~= "" then
		callbacks[callbackname] = nil
	end
end

function LIB.RequestCopyToBuffer(callbackname, callback)
	local copyToBufferRequest = LIB.copyToBufferRequest or {}
	LIB.copyToBufferRequest = copyToBufferRequest

	copyToBufferRequest.copyNow = true
	copyToBufferRequest.realtime = realtime

	if realtime then
		copyToBufferRequest.callbacks = nil
		return
	end

	callbackname = tostring(callbackname or "")

	if callbackname ~= "" then
		local callbacks = copyToBufferRequest.callbacks or {}
		copyToBufferRequest.callbacks = callbacks

		callbacks[callbackname] = callback
	end
end

function LIB.ResetRequestCopyToBuffer()
	local copyToBufferRequest = LIB.copyToBufferRequest or {}
	LIB.copyToBufferRequest = copyToBufferRequest

	copyToBufferRequest.realtime = false
	copyToBufferRequest.copyNow = false
	copyToBufferRequest.callbacks = nil
end

function LIB.RemoveRequestCopyToBufferCallback(callbackname)
	local copyToBufferRequest = LIB.copyToBufferRequest or {}
	LIB.copyToBufferRequest = copyToBufferRequest

	callbackname = tostring(callbackname or "")
	local callbacks = copyToBufferRequest.callbacks

	if callbacks and callbackname ~= "" then
		callbacks[callbackname] = nil
	end
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

	LIB.currentSuperDof = superDof
end

function LIB.GetSuperDof()
	local superDof = LIB.currentSuperDof

	if not superDof then
		return
	end

	if superDof.distance <= 0 then
		return nil
	end

	if superDof.blur <= 0 then
		return nil
	end

	if superDof.passes <= 0 then
		return nil
	end

	if superDof.steps <= 0 then
		return nil
	end

	return superDof
end

function LIB.ResetSuperDof()
	LIB.currentSuperDof = nil
end

function LIB.SetProgressStats(index, count)
	if not index or not count then
		LIB.ResetProgress()
		return
	end

	LIB.currentIndex = index
	LIB.currentCount = count
end

function LIB.GetProgressStats()
	return LIB.currentIndex, LIB.currentCount
end

function LIB.ResetProgressStats()
	LIB.currentIndex = nil
	LIB.currentCount = nil
end

function LIB.SetEntity(ent)
	if not IsValid(ent) then
		LIB.ResetEntity()
		return
	end

	LIB.currentEntity = ent
end

function LIB.ResetEntity()
	LIB.currentEntity = nil
end

function LIB.GetEntity()
	return LIB.currentEntity
end

local function captureAndSave(path, callback)
	path = tostring(path or "")

	if path == "" then
		callback(false, "No path given.")
		return false
	end

	local renderTarget = LIB.GetRenderTarget()

	local viewW = renderTarget:Width()
	local viewH = renderTarget:Height()

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
		callback(false, "No data returned.")
		return false
	end

	if data == "" then
		callback(false, "No data returned.")
		return false
	end

	local absolutePath = LIBFile.GetAbsolutePath(path, SLIGWOLF_ADDON)

	local success = LIBFile.Write(path, data, SLIGWOLF_ADDON)
	if not success then
		local err = string.format("Could not write too 'data/%s'.", absolutePath)

		callback(false, err)
		return false
	end

	callback(true, path, absolutePath)
	return true
end

function LIB.TakeScreenshot(parameter)
	local camera = parameter.camera
	local dof = camera.dof
	local index = parameter.index
	local count = parameter.count
	local ent = parameter.ent
	local imagePath = parameter.imagePath
	local previewTime = parameter.previewTime or 0
	local validateCallback = parameter.validateCallback
	local callback = parameter.callback

	LIB.SetCamera(camera)
	LIB.SetSuperDof(dof)
	LIB.SetProgressStats(index, count)
	LIB.SetEntity(ent)

	local timerAndCallbackName = "icongen_callback"

	local validate = function()
		if validateCallback and not validateCallback() then
			return false
		end

		if LIB.IsUIOpen() then
			callback(false, "Can not capture render target with menus open.")
			return false
		end

		return true
	end

	local capture = function()
		if not validate() then
			return
		end

		captureAndSave(imagePath, callback)
	end

	local renderBufferToCanvas = function()
		if not validate() then
			return
		end

		LIB.RenderBufferToCanvas()
		SLIGWOLF_ADDON:TimerOnce(timerAndCallbackName, previewTime, capture)
	end

	local requestCopyToBuffer = function()
		if not validate() then
			return
		end

		LIB.RequestCopyToBuffer(timerAndCallbackName, renderBufferToCanvas)
	end

	local nextFrame = function()
		if not validate() then
			return
		end

		LIB.RequestDofRender(false, timerAndCallbackName, requestCopyToBuffer)
	end

	SLIGWOLF_ADDON:TimerNextFrame(timerAndCallbackName, nextFrame)
end

function LIB.FindTargetEntityInView()
	local view = LIB.GetView()
	local pos = view.pos
	local ang = view.ang
	local fov = view.fov

	local normal = ang:Forward()
	local maxDofDistance = LIB.config.limits.dof.distance

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

function LIB.GetViewWorkloadEntry()
	local view = LIB.GetView()

	local pos = view.pos
	local ang = view.ang
	local fov = view.fov

	local superDof = LIB.GetSuperDof()

	local ent = LIB.GetEntity()
	if not IsValid(ent) then
		ent = LIB.FindTargetEntityInView()

		if not IsValid(ent) then
			return nil
		end
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
	local defaults = LIB.config.defaults

	if superDof then
		dof = superDof
	end

	local title = spawntable.PrintName or spawntable.Name or spawnname
	local addonname = spawntable.SLIGWOLF_Addonname

	local workloadEntry = {
		map = game.GetMap(),
		category = spawntable.SLIGWOLF_SkinCategory,
		spawnname = spawnname,
		addonname = addonname,
		theme = defaults.theme,

		entity = {
			pos = ent:GetPos(),
			ang = ent:GetAngles(),
			title = title,
			ent = ent,
		},

		camera = {
			pos = pos,
			ang = ang,
			fov = fov,
			dof = dof,
		},
	}

	local path = LIB.GetPathFromWorkloadEntry(workloadEntry)
	workloadEntry.path = path

	return workloadEntry
end

function LIB.GetPreviewContentIcon()
	if IsValid(LIB.previewContentIcon) then
		return LIB.previewContentIcon
	end

	local icon = vgui.Create("ContentIcon")
	icon:SetPaintedManually(true)

	icon:SetName("Preview")
	icon:SetContentType("entity")
	icon:SetSpawnName("")
	icon:SetAdminOnly(false)

	icon:SetMouseInputEnabled(false)
	icon:SetKeyboardInputEnabled(false)

	icon.DoRightClick = function() end
	icon.DoClick = function() end
	icon.OpenMenu = function() end

	LIB.previewContentIcon = icon
	return icon
end

local g_lineBuffer = {}

function LIB.DrawPreviewScreenStats(renderTargetMaterial, bufferRenderTargetMaterial, dofPercent)
	local viewW = renderTargetMaterial:Width()
	local viewH = renderTargetMaterial:Height()

	local bufferW = bufferRenderTargetMaterial:Width()
	local bufferH = bufferRenderTargetMaterial:Height()

	local scale = math.min(bufferW / viewW, bufferH / viewH)

	local newW = viewW * scale
	local newH = viewH * scale

	local centerX = (bufferW - newW) / 2
	local centerY = (bufferH - newH) / 2

	local leftEdgeX = centerX
	local rightEdgeX = leftEdgeX + newW

	local topEdgeY = centerY
	local bottomEdgeY = topEdgeY + newH

	surface.SetDrawColor(0, 0, 0, 224)
	surface.DrawRect(0, 0, bufferW, topEdgeY)
	surface.DrawRect(0, bottomEdgeY, bufferW, bufferH - bottomEdgeY)
	surface.DrawRect(0, topEdgeY, leftEdgeX, newH)
	surface.DrawRect(rightEdgeX, topEdgeY, bufferW - rightEdgeX, newH)

	local index, count = LIB.GetProgressStats()

	index = index or 0
	count = count or 0

	count = math.max(count, 0)
	index = math.Clamp(index, 0, count)

	local font = "DefaultFixed"

	surface.SetFont(font)

	local shadowOffset = 1
	local margin = 32

	local lineY = 0

	local _, textH = surface.GetTextSize(font)
	textH = textH + 8

	local textX = margin
	local textY = margin

	local workloadEntry = LIB.GetViewWorkloadEntry()

	do
		g_lineBuffer[#g_lineBuffer + 1] = "Progress: "

		local percent = 0

		if count <= 0 then
			index = 0
			count = 0
			percent = 0
		else
			percent = math.Round(index / count * 100, 2)
		end

		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Total: %i / %i  %6.2f%%", index, count, percent)
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  DoF:   %.2f%%", dofPercent or 0)

		textX = margin
		textY = margin
		lineY = textY

		for _, line in ipairs(g_lineBuffer) do
			if line == "" then
				lineY = lineY + textH
				continue
			end

			surface.SetFont(font)

			surface.SetTextColor(0, 0, 0, 255)
			surface.SetTextPos(textX + shadowOffset, lineY + shadowOffset)
			surface.DrawText(line, false)

			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(textX, lineY)
			surface.DrawText(line, false)

			lineY = lineY + textH
		end

		table.Empty(g_lineBuffer)
	end

	do
		local previewIcon = LIB.GetPreviewContentIcon()

		g_lineBuffer[#g_lineBuffer + 1] = "Raw buffer: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  %ix%i", bufferW, bufferH)
		g_lineBuffer[#g_lineBuffer + 1] = bufferRenderTargetMaterial
		g_lineBuffer[#g_lineBuffer + 1] = ""

		g_lineBuffer[#g_lineBuffer + 1] = "Raw result: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  %ix%i", viewW, viewH)
		g_lineBuffer[#g_lineBuffer + 1] = renderTargetMaterial
		g_lineBuffer[#g_lineBuffer + 1] = ""

		if IsValid(previewIcon) then
			g_lineBuffer[#g_lineBuffer + 1] = "Preview Icon: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  %ix%i", previewIcon:GetWide(), previewIcon:GetTall())
			g_lineBuffer[#g_lineBuffer + 1] = previewIcon
		end

		local miniX = rightEdgeX + margin
		local miniY = margin
		local miniH = textH * 9
		local miniW = miniH * bufferW / bufferH

		local miniXInd = miniX + 14

		textX = miniX
		textY = miniY
		lineY = textY

		for _, line in ipairs(g_lineBuffer) do

			if line == "" then
				lineY = lineY + textH
				continue
			end

			if line == bufferRenderTargetMaterial then
				render.PushFilterMag(TEXFILTER.ANISOTROPIC)
				render.PushFilterMin(TEXFILTER.ANISOTROPIC)

				surface.SetDrawColor(0, 0, 0, 255)
				surface.DrawRect(miniXInd + shadowOffset, lineY + shadowOffset, miniW, miniH)

				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(bufferRenderTargetMaterial)
				surface.DrawTexturedRect(miniXInd, lineY, miniW, miniH)

				render.PopFilterMin()
				render.PopFilterMag()

				lineY = lineY + miniH
				continue
			end

			if line == renderTargetMaterial then
				render.PushFilterMag(TEXFILTER.ANISOTROPIC)
				render.PushFilterMin(TEXFILTER.ANISOTROPIC)

				surface.SetDrawColor(0, 0, 0, 255)
				surface.DrawRect(miniXInd + shadowOffset, lineY + shadowOffset, miniH, miniH)

				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(renderTargetMaterial)
				surface.DrawTexturedRect(miniXInd, lineY, miniH, miniH)

				render.PopFilterMin()
				render.PopFilterMag()

				lineY = lineY + miniH
				continue
			end

			if line == previewIcon then
				if not IsValid(previewIcon) then
					continue
				end

				previewIcon:SetPos(miniXInd, lineY)
				previewIcon:SetMaterial("!" .. renderTargetMaterial:GetName())
				previewIcon:PaintManual(false)

				if workloadEntry then
					local title = workloadEntry.entity.title
					local category = workloadEntry.category
					local spawnname = workloadEntry.spawnname

					previewIcon:SetName(title)
					previewIcon:SetContentType(category)
					previewIcon:SetSpawnName(spawnname)
					previewIcon:SetAdminOnly(false)
				else
					previewIcon:SetName("Preview")
					previewIcon:SetContentType("entity")
					previewIcon:SetSpawnName("")
					previewIcon:SetAdminOnly(false)
				end

				lineY = lineY + previewIcon:GetTall() + 4
				continue
			end

			surface.SetFont(font)

			surface.SetTextColor(0, 0, 0, 255)
			surface.SetTextPos(textX + shadowOffset, lineY + shadowOffset)
			surface.DrawText(line, false)

			surface.SetTextColor(210, 255, 210, 255)
			surface.SetTextPos(textX, lineY)
			surface.DrawText(line, false)

			lineY = lineY + textH
		end

		table.Empty(g_lineBuffer)
	end

	do
		if workloadEntry then
			local entity = workloadEntry.entity
			local camera = workloadEntry.camera
			local superDof = camera.dof

			local addon = SligWolf_Addons.GetAddon(workloadEntry.addonname or "")

			g_lineBuffer[#g_lineBuffer + 1] = "Map: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  %s", workloadEntry.map)
			g_lineBuffer[#g_lineBuffer + 1] = ""

			g_lineBuffer[#g_lineBuffer + 1] = "Addon: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  %s", addon.Addonname)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  %s", addon.NiceName)
			g_lineBuffer[#g_lineBuffer + 1] = ""

			g_lineBuffer[#g_lineBuffer + 1] = "Spawn: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  %s", workloadEntry.spawnname)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  LIBEntities.SPAWN_CATEGORY_%s", string.upper(workloadEntry.category))
			g_lineBuffer[#g_lineBuffer + 1] = ""

			g_lineBuffer[#g_lineBuffer + 1] = "Entity: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Pos:   Vector(%10.3f, %10.3f, %10.3f)", entity.pos:Unpack())
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Ang:   Angle (%10.3f, %10.3f, %10.3f)", entity.ang:Unpack())
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Title: %s", entity.title)
			g_lineBuffer[#g_lineBuffer + 1] = ""

			g_lineBuffer[#g_lineBuffer + 1] = "Camera: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Pos: Vector(%10.3f, %10.3f, %10.3f)", camera.pos:Unpack())
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Ang: Angle (%10.3f, %10.3f, %10.3f)", camera.ang:Unpack())
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  FOV: %.3f", camera.fov)

			if superDof then
				g_lineBuffer[#g_lineBuffer + 1] = ""
				g_lineBuffer[#g_lineBuffer + 1] = "DoF: "
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Distance: %.3f", superDof.distance)
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Blur:     %.3f", superDof.blur)
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Passes:   %i", superDof.passes)
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Steps:    %i", superDof.steps)
			end
		else
			local view = LIB.GetView()
			local superDof = LIB.GetSuperDof()

			g_lineBuffer[#g_lineBuffer + 1] = "Map: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  %s", game.GetMap())
			g_lineBuffer[#g_lineBuffer + 1] = ""

			g_lineBuffer[#g_lineBuffer + 1] = "Camera: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Pos: Vector(%10.3f, %10.3f, %10.3f)", view.pos:Unpack())
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Ang: Angle (%10.3f, %10.3f, %10.3f)", view.ang:Unpack())
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  FOV: %.3f", view.fov)

			if superDof then
				g_lineBuffer[#g_lineBuffer + 1] = ""
				g_lineBuffer[#g_lineBuffer + 1] = "DoF: "
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Distance: %.3f", superDof.distance)
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Blur:     %.3f", superDof.blur)
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Passes:   %i", superDof.passes)
				g_lineBuffer[#g_lineBuffer + 1] = string.format("  Steps:    %i", superDof.steps)
			end
		end

		local linesCount = #g_lineBuffer

		textX = margin
		textY = bufferH - linesCount * textH - margin
		lineY = textY

		for _, line in ipairs(g_lineBuffer) do
			if line == "" then
				lineY = lineY + textH
				continue
			end

			surface.SetFont(font)

			surface.SetTextColor(0, 0, 0, 255)
			surface.SetTextPos(textX + shadowOffset, lineY + shadowOffset)
			surface.DrawText(line, false)

			surface.SetTextColor(210, 255, 250, 255)
			surface.SetTextPos(textX, lineY)
			surface.DrawText(line, false)

			lineY = lineY + textH
		end

		table.Empty(g_lineBuffer)
	end
end

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

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(bufferRenderTargetMaterial)
	surface.DrawTexturedRect(0, 0, bufferW, bufferH)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(renderTargetMaterial)
	surface.DrawTexturedRect(centerX, centerY, newW, newH)

	render.PopFilterMin()
	render.PopFilterMag()

	LIB.DrawPreviewScreenStats(renderTargetMaterial, bufferRenderTargetMaterial)
end

function LIB.RenderBufferToCanvas()
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

	LIB.hasCanvasRendered = true
end

function LIB.ClearCanvas()
	local renderTarget = LIB.GetRenderTarget()

	local viewW = renderTarget:Width()
	local viewH = renderTarget:Height()

	render.PushRenderTarget(renderTarget, 0, 0, viewW, viewH)
		render.Clear(0, 0, 0, 255, true, true)
	render.PopRenderTarget()

	LIB.hasCanvasRendered = nil
end

function LIB.ClearBuffer()
	local bufferRenderTarget = LIB.GetBufferRenderTarget()

	local bufferW = bufferRenderTarget:Width()
	local bufferH = bufferRenderTarget:Height()

	render.PushRenderTarget(bufferRenderTarget, 0, 0, bufferW, bufferH)
		render.Clear(0, 0, 0, 255, true, true)
	render.PopRenderTarget()

	LIB.hasBufferRendered = nil
end

return true

