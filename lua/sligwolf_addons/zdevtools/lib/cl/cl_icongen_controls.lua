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

local LIBConvar = SligWolf_Addons.Convar
local LIBDebug = SligWolf_Addons.Debug
local LIBTrace = SligWolf_Addons.Trace
local LIBHook = SligWolf_Addons.Hook

local PANEL = {}

local cvDistance = LIBConvar.AddClientConvar("dev_sligwolf_zdevtools_icongen_dof_distance", {
	default = LIB.config.defaults.camera.dof.distance,
	min = 0,
	max = LIB.config.limits.dof.distance,
	shouldsave = true,
	userinfo = false,
})

local cvBlur = LIBConvar.AddClientConvar("dev_sligwolf_zdevtools_icongen_dof_blur", {
	default = LIB.config.defaults.camera.dof.blur,
	min = 0,
	max = LIB.config.limits.dof.blur,
	shouldsave = true,
	userinfo = false,
})

local cvPasses = LIBConvar.AddClientConvar("dev_sligwolf_zdevtools_icongen_dof_passes", {
	default = LIB.config.defaults.camera.dof.passes,
	min = 0,
	max = LIB.config.limits.dof.passes,
	shouldsave = true,
	userinfo = false,
})

local cvSteps = LIBConvar.AddClientConvar("dev_sligwolf_zdevtools_icongen_dof_steps", {
	default = LIB.config.defaults.camera.dof.steps,
	min = 0,
	max = LIB.config.limits.dof.steps,
	shouldsave = true,
	userinfo = false,
})

local cvShape = LIBConvar.AddClientConvar("dev_sligwolf_zdevtools_icongen_dof_shape", {
	default = LIB.config.defaults.camera.dof.shape,
	min = 0,
	max = LIB.config.limits.dof.shape,
	shouldsave = true,
	userinfo = false,
})

function PANEL:Init()
	self:SetTitle("DoF Options")

	do
		local panel = vgui.Create("DPanel", self)

		local label = Label("Settings", panel)
		label:SetContentAlignment(8)
		label:Dock(TOP)
		label:SetDark(true)

		local blur = vgui.Create("DNumSlider", panel)
		blur:SetMin(0)
		blur:SetMax(LIB.config.limits.dof.blur)
		blur:SetDecimals(3)
		blur:SetText("Blur")
		blur:Dock(TOP)
		blur:DockMargin(0, 0, 0, 16)
		blur:SetDark(true)
		blur:SetConVar(cvBlur:GetName())

		blur.OnValueChanged = function()
			if not IsValid(self) then
				return
			end

			self:DoDofUpdate()
		end

		self.blur = blur

		local distance = vgui.Create("DNumSlider", panel)
		distance:SetMin(0)
		distance:SetMax(LIB.config.limits.dof.distance)
		distance:SetText("Distance")
		distance:Dock(TOP)
		distance:SetDark(true)
		distance:SetConVar(cvDistance:GetName())

		distance.OnValueChanged = function()
			if not IsValid(self) then
				return
			end

			self:DoDofUpdate()
		end

		self.distance = distance

		panel:SetPos(10, 30)
		panel:SetSize(300, 90)
		panel:DockPadding(8, 8, 8, 8)
		panel:DockMargin(0, 0, 4, 0)
		panel:Dock(FILL)
	end

	do
		local panel = vgui.Create("DPanel", self)

		local label = Label("Advanced", panel)
		label:SetContentAlignment(8)
		label:Dock(TOP)
		label:SetDark(true)

		local passes = vgui.Create("DNumSlider", panel)
		passes:SetMin(0)
		passes:SetMax(LIB.config.limits.dof.passes)
		passes:SetDecimals(0)
		passes:SetText("Passes")
		passes:Dock(TOP)
		passes:DockMargin(0, 0, 0, 4)
		passes:SetDark(true)
		passes:SetConVar(cvPasses:GetName())

		passes.OnValueChanged = function()
			if not IsValid(self) then
				return
			end

			self:DoDofUpdate()
		end

		self.passes = passes

		local steps = vgui.Create("DNumSlider", panel)
		steps:SetMin(0)
		steps:SetMax(LIB.config.limits.dof.steps)
		steps:SetDecimals(0)
		steps:SetText("Steps")
		steps:Dock(TOP)
		steps:DockMargin(0, 0, 0, 4)
		steps:SetDark(true)
		steps:SetConVar(cvSteps:GetName())

		steps.OnValueChanged = function()
			if not IsValid(self) then
				return
			end

			self:DoDofUpdate()
		end

		self.steps = steps

		local shape = vgui.Create("DNumSlider", panel)
		shape:SetMin(0)
		shape:SetMax(LIB.config.limits.dof.shape)
		shape:SetDecimals(3)
		shape:SetText("Shape")
		shape:Dock(TOP)
		shape:DockMargin(0, 0, 0, 4)
		shape:SetDark(true)
		shape:SetConVar(cvShape:GetName())

		self.shape = shape

		shape.OnValueChanged = function()
			if not IsValid(self) then
				return
			end

			self:DoDofUpdate()
		end

		panel:SetPos(10, 30)
		panel:SetSize(150, 100)
		panel:DockPadding(8, 8, 8, 8)
		panel:Dock(RIGHT)
	end

	do
		local panel = vgui.Create("DPanel", self)

		local renderButton = vgui.Create("DButton", panel)
		renderButton:SetText("Render")
		renderButton:Dock(RIGHT)
		renderButton:SetSize(70, 20)

		renderButton.DoClick = function()
			if not IsValid(self) then
				return
			end

			self:DoDofUpdate()
			self:DoRender()
		end

		local reset = vgui.Create("DButton", panel)
		reset:SetText("Reset")
		reset:Dock(RIGHT)
		reset:SetSize(120, 20)
		reset:DockMargin(0, 0, 8, 0)

		reset.DoClick = function()
			if not IsValid(self) then
				return
			end

			self:DoReset()
		end

		local snapshot = vgui.Create("DButton", panel)
		snapshot:SetText("Snapshot")
		snapshot:Dock(LEFT)
		snapshot:SetSize(120, 20)
		snapshot:DockMargin(0, 0, 8, 0)

		snapshot.DoClick = function()
			if not IsValid(self) then
				return
			end

			self:DoSnapshot()
		end

		panel:Dock(BOTTOM)
		panel:DockPadding(4, 4, 4, 4)
		panel:DockMargin(0, 4, 0, 0)
		panel:SetTall(28)
		panel:MoveToBack()
	end

	self:SetSize(600, 220)

	self:DoDofUpdate()
end

function PANEL:PositionMySelf()
	self:AlignBottom(50)
	self:AlignRight(50)
end

function PANEL:OnScreenSizeChanged()
	self:PositionMySelf()
end

function PANEL:DoDofUpdate()
	local currentSuperDofOptions = LIB.GetSuperDofOptions()
	LIB.SetSuperDof(currentSuperDofOptions)

	LIB.RequestDofRender(true)
end

function PANEL:DoRender()
	LIB.RequestDofRender(false)
end

function PANEL:DoReset()
	local defaults = LIB.config.defaults.camera.dof

	cvDistance:SetFloat(defaults.distance)
	cvBlur:SetFloat(defaults.blur)
	cvPasses:SetInt(defaults.passes)
	cvSteps:SetInt(defaults.steps)
	cvShape:SetFloat(defaults.shape)
end

function PANEL:DoSnapshot()
	local weapon = LocalPlayer():GetActiveWeapon()

	if IsValid(weapon) and weapon:GetClass() == LIB.config.cameraWeapon then
		weapon:TakeSnapshot()
	end
end

function PANEL:OnClose()
	LIB.CloseDofOptions()
end

function PANEL:OnRemove()
	-- override me
end

local paneltypeSuperDOF = vgui.RegisterTable(PANEL, "DFrame")

LIB.DofOptionPanelType = paneltypeSuperDOF

if IsValid(LIB.DofOptionPanel) then
	LIB.DofOptionPanel:Remove()
	LIB.DofOptionPanel = nil
end

function LIB.OpenDofOptions()
	LIB.CloseDofOptions()

	local dofOptionPanel = vgui.CreateFromTable(LIB.DofOptionPanelType)
	dofOptionPanel:InvalidateLayout( true )
	dofOptionPanel:MakePopup()
	dofOptionPanel:PositionMySelf()

	dofOptionPanel.FocusGrabber = false

	LIB.DofOptionPanel = dofOptionPanel
	return dofOptionPanel
end

function LIB.CloseDofOptions()
	if IsValid(LIB.DofOptionPanel) then
		LIB.DofOptionPanel:Remove()
		LIB.DofOptionPanel = nil
	end
end

function LIB.ToogleDofOptions()
	if IsValid(LIB.DofOptionPanel) then
		LIB.CloseDofOptions()
	else
		return LIB.OpenDofOptions()
	end
end

function LIB.GetSuperDofOptions()
	local distance = cvDistance:GetFloat()
	local blur = cvBlur:GetFloat()
	local passes = cvPasses:GetInt()
	local steps = cvSteps:GetInt()
	local shape = cvShape:GetFloat()

	if distance <= 0 then
		return nil
	end

	if blur <= 0 then
		return nil
	end

	if passes <= 0 then
		return nil
	end

	if steps <= 0 then
		return nil
	end

	local dof = {
		distance = distance,
		blur = blur,
		passes = passes,
		steps = steps,
		shape = shape,
	}

	return dof
end

LIBHook.Add("GUIMousePressed", "Addon_ZDevTools_Icongen_SuperDOFOptions_MouseDown", function(mouse)
	if not IsValid(LIB.DofOptionPanel) then
		return
	end

	vgui.GetWorldPanel():MouseCapture(true)
	LIB.DofOptionPanel.FocusGrabber = true
end)

LIBHook.Add("GUIMouseReleased", "Addon_ZDevTools_Icongen_SuperDOFOptions_MouseUp", function(mouse)
	if not IsValid(LIB.DofOptionPanel) then
		return
	end

	vgui.GetWorldPanel():MouseCapture(false)
	LIB.DofOptionPanel.FocusGrabber = false
end)

LIBHook.Add("PreventScreenClicks", "Addon_ZDevTools_Icongen_SuperDOFOptions_PreventScreenClicks", function()
	if IsValid(LIB.DofOptionPanel) then
		return true
	end
end)

LIBHook.Add("RenderScene", "Addon_ZDevTools_Icongen_SuperDOFOptions_FocusHelper", function(pos, ang, fov)
	local dofOptionPanel = LIB.DofOptionPanel

	if not IsValid(dofOptionPanel) then
		return
	end

	if not dofOptionPanel.FocusGrabber then
		return
	end

	local maxDofDistance = LIB.config.limits.dof.distance

	local x, y = input.GetCursorPos()
	local dir = util.AimVector(ang, fov, x, y, ScrW(), ScrH())

	local vecStart = pos
	local vecEnd = pos + dir * maxDofDistance

	LIBDebug.SetCurrentTraceDebugContext(LIBDebug.TRACE_DEBUG_CONTEXT_NONE)

	local tr = LIBTrace.TraceSimple(LocalPlayer(), vecStart, vecEnd)

	LIBDebug.ResetTraceDebugContext()

	local distance = tr.Hit and tr.HitPos:Distance(tr.StartPos) or 0
	distance = math.Clamp(distance or 0, 0, maxDofDistance)

	cvDistance:SetFloat(distance)

	if tr.Hit and distance > 0 then
		local effectdata = EffectData()
		effectdata:SetOrigin(tr.HitPos)
		effectdata:SetNormal(tr.HitNormal)
		effectdata:SetMagnitude(1)
		effectdata:SetScale(1)
		effectdata:SetRadius(16)

		util.Effect("Sparks", effectdata)
	end
end, 10000)


local cvarFlags = bit.bor(FCVAR_CLIENTDLL, FCVAR_DONTRECORD)

concommand.Add("dev_sligwolf_zdevtools_icongen_snapshot", function(ply)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	local workloadEntry = LIBIconGenerator.EstimateViewWorkloadEntry()
	if not workloadEntry then
		return
	end

	-- @TODO: Will be replaced soon!
	PrintTable(workloadEntry)
end, nil, nil, cvarFlags)

return true

