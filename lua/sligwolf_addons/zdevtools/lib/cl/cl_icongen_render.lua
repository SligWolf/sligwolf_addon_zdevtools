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

LIB.renderTarget = nil
LIB.renderTargetMaterial = nil
LIB.bufferRenderTarget = nil
LIB.bufferRenderTargetMaterial = nil
LIB.superDofResources = nil

LIB.currentView = {
	pos = Vector(),
	ang = Angle(),
	fov = 0,
}

LIB.requestCopyScreenToBuffer = nil

LIB.currentIndex = nil
LIB.currentCount = nil
LIB.currentCamera = nil
LIB.currentSuperDof = nil

LIBHook.Add("OnScreenSizeChanged", "Addon_ZDevTools_Icongen_ScreenResized", function()
	LIB.renderTarget = nil
	LIB.renderTargetMaterial = nil
	LIB.bufferRenderTarget = nil
	LIB.bufferRenderTargetMaterial = nil
	LIB.superDofResources = nil
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

	LIB.RenderSuperDof(pos, ang, focuspoint, blur, steps, passes, fov)

	local resources = LIB.GetSuperDofResources()
	local texFP = resources.texFP
	local matMotionblur = resources.matMotionblur

	matMotionblur:SetFloat( "$alpha", 1 )
	matMotionblur:SetTexture( "$basetexture", texFP )

	render.SetMaterial( matMotionblur )
	render.DrawScreenQuad()

	local renderTargetMaterial = LIB.GetRenderTargetMaterial()
	local bufferRenderTargetMaterial = LIB.GetBufferRenderTargetMaterial()

	local viewW = renderTargetMaterial:Width()
	local viewH = renderTargetMaterial:Height()

	local bufferW = bufferRenderTargetMaterial:Width()
	local bufferH = bufferRenderTargetMaterial:Height()

	cam.Start2D()
		LIB.DrawPreviewScreenStats(viewW, viewH, bufferW, bufferH)
	cam.End2D()

	superDof.rendered = true

	LIB.RequestCopyScreenCopyScreenToBuffer()

	return true
end)

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

function LIB.RenderSuperDof(vOrigin, vAngle, vFocus, fAngleSize, steps, passes, ViewFOV)
	-- Borrowed code from Garry's Mod
	-- garrysmod\lua\postprocess\super_dof.lua

	local renderTargetMaterial = LIB.GetRenderTargetMaterial()
	local bufferRenderTargetMaterial = LIB.GetBufferRenderTargetMaterial()

	local viewW = renderTargetMaterial:Width()
	local viewH = renderTargetMaterial:Height()

	local bufferW = bufferRenderTargetMaterial:Width()
	local bufferH = bufferRenderTargetMaterial:Height()

	local Shape = 0.5

	local OldRT = render.GetRenderTarget()

	local fDistance = vOrigin:Distance(vFocus)
	fAngleSize = fAngleSize * math.Clamp(256 / fDistance, 0.1, 1) * 0.5

	local view = {
		x = 0,
		y = 0,
		w = ScrW(),
		h = ScrH(),
		dopostprocess = true,
		origin = vOrigin,
		angles = vAngle,
		fov = ViewFOV
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

	-- cam.Start2D()
	-- 	LIB.DrawPreviewScreenStats(viewW, viewH, bufferW, bufferH)
	-- cam.End2D()

	local Radials = math.tau / steps
	for mul = 1 / passes, 1, 1 / passes do
		for i = 0, math.tau, Radials do
			local VA = Angle(vAngle)
			local VRot = Angle(vAngle)

			-- Rotate around the focus point
			VA:RotateAroundAxis(VRot:Right(), math.sin(i + mul) * fAngleSize * mul * Shape * 2)
			VA:RotateAroundAxis(VRot:Up(), math.cos(i + mul) * fAngleSize * mul * (1 - Shape) * 2)

			view.origin = vFocus - VA:Forward() * fDistance
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

				LIB.DrawPreviewScreenStats(viewW, viewH, bufferW, bufferH, percent)
			cam.End2D()

			-- We have to SPIN here to stop the Source engine running out of render queue space.
			render.Spin()
		end
	end

	-- Restore RT
	render.SetRenderTarget(OldRT)
	render.Clear(0, 0, 0, 255, true, true)

	-- Render our result buffer to the screen
	-- matMotionblur:SetFloat("$alpha", 1)
	-- matMotionblur:SetTexture("$basetexture", texFP)
	-- render.SetMaterial(matMotionblur)
	-- render.DrawScreenQuad()

	-- cam.Start2D()
	-- 	LIB.DrawPreviewScreenStats(viewW, viewH, bufferW, bufferH)
	-- cam.End2D()
end

function LIB.CopyScreenCopyScreenToBuffer()
	local bufferRenderTarget = LIB.GetBufferRenderTarget()

	local superDof = LIB.GetSuperDof()
	if superDof and superDof.rendered then
		local resources = LIB.GetSuperDofResources()
		local texFP = resources.texFP

		render.CopyTexture(texFP, bufferRenderTarget)
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

function LIB.EstimateSuperDof()
	local defaults = LIB.config.defaults
	local defaultsCamera = defaults.camera

	local maxDofDistance = LIB.config.maxDofDistance

	local tr = LIBTrace.PlayerAimTrace(LocalPlayer(), maxDofDistance)

	local distance = tr.Hit and tr.HitPos:Distance(tr.StartPos) or 0
	distance = math.Clamp(distance or 0, 0, maxDofDistance)

	local dof = nil

	if distance > 0 then
		dof = {
			distance = distance,
			blur = defaultsCamera.dof.blur,
			passes = defaultsCamera.dof.passes,
			steps = defaultsCamera.dof.steps,
		}
	end

	return dof
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
		dof = LIB.EstimateSuperDof()
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

function LIB.DrawPreviewScreenCover(viewW, viewH, bufferW, bufferH)
	local scale = math.min(bufferW / viewW, bufferH / viewH)

	local newW = viewW * scale
	local newH = viewH * scale

	local centerX = (bufferW - newW) / 2
	local centerY = (bufferH - newH) / 2

	surface.SetDrawColor(0, 0, 0, 224)
	surface.DrawRect(0, 0, bufferW, centerY)
	surface.DrawRect(0, centerY + newH, bufferW, bufferH - (centerY + newH))
	surface.DrawRect(0, centerY, centerX, newH)
	surface.DrawRect(centerX + newW, centerY, bufferW - (centerX + newW), newH)
end

function LIB.DrawPreviewScreenStats(viewW, viewH, bufferW, bufferH, dofPercent)
	LIB.DrawPreviewScreenCover(viewW, viewH, bufferW, bufferH)

	local index, count = LIB.GetProgressStats()
	local workloadEntry = LIB.EstimateViewWorkloadEntry()

	index = index or 0
	count = count or 0

	count = math.max(count, 0)
	index = math.Clamp(index, 0, count)

	--index = 5
	--count = 10

	surface.SetFont("DefaultFixed")

	local _, topTextH = surface.GetTextSize("DefaultFixed")
	topTextH = topTextH + 8

	local topTextX = 32
	local topTextY = 32

	local totalProgress = "Progress: 0 / 0"

	if count > 0 then
		local percent = math.Round(index / count * 100, 2)
		totalProgress = string.format("Progress: %i / %i  %6.2f%%", index, count, percent)
	end

	surface.SetTextColor(0, 0, 0, 255)
	surface.SetTextPos(topTextX + 2, topTextY + 2)
	surface.DrawText(totalProgress, false)

	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(topTextX, topTextY)
	surface.DrawText(totalProgress, false)

	local progress = string.format("DoF:      %.2f%%", dofPercent or 0)

	surface.SetTextColor(0, 0, 0, 255)
	surface.SetTextPos(topTextX + 2, topTextY + topTextH + 2)
	surface.DrawText(progress, false)

	surface.SetTextColor(255, 255, 255, 255)
	surface.SetTextPos(topTextX, topTextY + topTextH)
	surface.DrawText(progress, false)

	if workloadEntry then
		local entity = workloadEntry.entity
		local camera = workloadEntry.camera
		local dof = camera.dof

		g_lineBuffer[#g_lineBuffer + 1] = "Map: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  %s", workloadEntry.map)
		g_lineBuffer[#g_lineBuffer + 1] = ""

		g_lineBuffer[#g_lineBuffer + 1] = "Spawn: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  %s", workloadEntry.spawnname)
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  LIBEntities.SPAWN_CATEGORY_%s", string.upper(workloadEntry.category))
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
			g_lineBuffer[#g_lineBuffer + 1] = "DoF: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Distance: %.3f", dof.distance)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Blur:     %.3f", dof.blur)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Passes:   %i", dof.passes)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Steps:    %i", dof.steps)
		end
	else
		local view = LIB.GetView()
		local dof = LIB.EstimateSuperDof()

		g_lineBuffer[#g_lineBuffer + 1] = "Camera: "
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Pos: Vector(%10.3f, %10.3f, %10.3f)", view.pos:Unpack())
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  Ang:  Angle(%10.3f, %10.3f, %10.3f)", view.ang:Unpack())
		g_lineBuffer[#g_lineBuffer + 1] = string.format("  FOV: %7.3f", view.fov)

		if dof and dof.distance > 0 then
			g_lineBuffer[#g_lineBuffer + 1] = ""
			g_lineBuffer[#g_lineBuffer + 1] = "DoF: "
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Distance: %.3f", dof.distance)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Blur:     %.3f", dof.blur)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Passes:   %i", dof.passes)
			g_lineBuffer[#g_lineBuffer + 1] = string.format("  Steps:    %i", dof.steps)
		end
	end

	local linesCount = #g_lineBuffer

	if linesCount > 0 then
		surface.SetFont("DefaultFixed")

		local _, textH = surface.GetTextSize("DefaultFixed")
		textH = textH + 8

		local textX = 32
		local textY = bufferH - linesCount * textH - 32


		for i, line in ipairs(g_lineBuffer) do
			local lineY = textY + (i - 1) * textH

			if line == "" then
				continue
			end

			surface.SetTextColor(0, 0, 0, 255)
			surface.SetTextPos(textX + 2, lineY + 2)
			surface.DrawText(line, false)

			surface.SetTextColor(250, 255, 210)
			surface.SetTextPos(textX, lineY)
			surface.DrawText(line, false)
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

	LIB.DrawPreviewScreenStats(viewW, viewH, bufferW, bufferH)
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

return true

