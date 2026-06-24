AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

local addonName = "zdevtools"

DEFINE_BASECLASS("sligwolf_weapon_base")

-- Tell the user something is wrong ("Broken") with the addons in case they see the usually hidden placeholder node.
-- This item is moved to a different custom build category if everything is fine and the "Broken" one is hidden.
SWEP.Category				= "SligWolf's Addons (Broken)"

SWEP.Spawnable				= false
SWEP.AdminOnly				= false
SWEP.PrintName 				= "ZDevtools Icongen Camera"
SWEP.Author 				= "Grocel"

SWEP.ViewModel 				= "models/weapons/c_arms_animations.mdl"
SWEP.WorldModel				= "models/MaxOfS2D/camera.mdl"

SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

SWEP.Slot					= 6
SWEP.SlotPos				= 1
SWEP.DrawAmmo				= false
SWEP.DrawCrosshair			= false

SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false

SWEP.m_bPlayPickupSound		= true

SWEP.DisableDuplicator		= false
SWEP.DoNotDuplicate			= false

if CLIENT then
	SWEP.BounceWeaponIcon 	= false
	SWEP.WepSelectIcon 		= surface.GetTextureID("hud/sligwolf/zdevtools/weaponicon/sligwolf_zdevtools_icongen_camera")
end

if not SligWolf_Addons then return end
if not SligWolf_Addons.HasLoadedAddon then return end
if not SligWolf_Addons.HasLoadedAddon(addonName) then return end

SWEP.Spawnable = true

local addon = SligWolf_Addons.GetAddon(addonName)

local LIBIconGenerator = addon.IconGenerator

local LIBEntities = SligWolf_Addons.Entities
local LIBPrint = SligWolf_Addons.Print

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:AddNetworkRVar("Float", "Zoom")
end

function SWEP:SetZoom(num)
	self:SetNetworkRVar("Zoom", num)
end

function SWEP:GetZoom()
	return self:GetNetworkRVarNumber("Zoom", 0)
end

function SWEP:Initialize()
	self:SetAddonID(addonName)
	self:SetHoldType("camera")

	BaseClass.Initialize(self)
end

function SWEP:Reset()
	if SERVER then
		self:AddClientCallForPredictionHook("Deploy")
		self:AddClientCallForPredictionHook("Holster")

		self:ResetZoom()
		return
	end

	self.holdDelay = 0.50
	self.holdHintAt = self.holdDelay - 0.15

	self:ResetRender()
end

function SWEP:Reload()
	self:ResetZoom()
end

function SWEP:ResetZoom()
	local owner = self:GetOwner()

	if IsValid(owner) and owner:IsPlayer() and not owner:IsBot() then
		self:SetZoom(owner:GetInfoNum("fov_desired", 75))
	else
		self:SetZoom(75)
	end
end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		return
	end

	if not owner:IsPlayer() then
		return
	end

	if owner:IsBot() then
		return
	end

	if SERVER and game.SinglePlayer() then
		self:CallOnClient("TakeSnapshot")
		return
	end

	if CLIENT and IsFirstTimePredicted() then
		self:TakeSnapshot()
	end
end

function SWEP:SecondaryAttack()
	-- see SWEP:HandleZoom()
end

function SWEP:Think()
	self:HandleZoom()

	if CLIENT then
		self:HandlePanelInput()
	end
end

function SWEP:HandleZoom()
	local owner = self:GetOwner()
	if CLIENT then
		if game.SinglePlayer() then
			return
		end

		if owner ~= LocalPlayer() then
			return
		end
	end

	local cmd = owner:GetCurrentCommand()
	if not cmd:KeyDown(IN_ATTACK2) then
		return
	end

	-- Handles zooming
	self:SetZoom(math.Clamp(self:GetZoom() + cmd:GetMouseY() * FrameTime() * 6.6, 0.1, 175))
end

function SWEP:TranslateFOV(current_fov)
	return self:GetZoom()
end

function SWEP:ShouldDropOnDie()
	return false
end

function SWEP:DoShootEffect()
	if self.NextShootEffect and self.NextShootEffect > CurTime() then
		return
	end

	self.NextShootEffect = CurTime() + 0.4

	local owner = self:GetOwner()
	self:EmitSound(self.ShootSound)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	owner:SetAnimation(PLAYER_ATTACK1)

	if SERVER and not game.SinglePlayer() then
		local vPos = owner:GetShootPos()
		local vForward = owner:GetAimVector()

		local trace = {}
		trace.start = vPos
		trace.endpos = vPos + vForward * 256
		trace.filter = owner

		local tr = util.TraceLine(trace)
		local effectdata = EffectData()

		effectdata:SetOrigin(tr.HitPos)
		util.Effect("camera_flash", effectdata, true)
	end
end

function SWEP:OnRemove()
	if CLIENT then
		self:ResetRender()
		LIBIconGenerator.CloseDofOptions()
	end
end

if SERVER then
	return
end

function SWEP:DeployClient()
	LIBIconGenerator.CloseDofOptions()
end

function SWEP:HolsterClient()
	LIBIconGenerator.CloseDofOptions()
end

function SWEP:ResetRender()
	LIBIconGenerator.ResetCamera()
	LIBIconGenerator.ResetSuperDof()
	LIBIconGenerator.ResetProgressStats()
	LIBIconGenerator.ClearBuffer()
	LIBIconGenerator.ClearCanvas()

	self:ResetStillState()
end

function SWEP:ResetStillState()
	self.oldPos = nil
	self.oldAng = nil
	self.oldFov = nil
	self.posTime = nil
	self.posTimeInputLock = nil
	self.oldStandingStill = nil
	self.oldQuickDof = nil

	self.hasQuickDofRendered = nil
	self.hasFullDofRendered = nil

	self.oldPanelKeyPressed = false

	self.stabilityProgress = 0
	self.pulseAlpha = 0
end

function SWEP:HandlePanelInput()
	local panelKeyPressed = input.IsKeyDown(KEY_LALT)

	local oldPanelKeyPressed = self.oldPanelKeyPressed
	self.oldPanelKeyPressed = panelKeyPressed

	if oldPanelKeyPressed == panelKeyPressed then
		return
	end

	if not panelKeyPressed then
		local panel = LIBIconGenerator.ToogleDofOptions()
		if IsValid(panel) then
			panel.OnRemove = function()
				if not IsValid(self) then
					return
				end

				self:ApplyQuickDofState()
			end
		end
	end
end

function SWEP:TakeSnapshot()
	local workloadEntry = LIBIconGenerator.EstimateViewWorkloadEntry()
	if not workloadEntry then
		self:EmitSound("Buttons.snd42")

		local message = LIBPrint.FormatMessage("No SW Entity found to snapshot!")
		LIBPrint.Notify(LIBPrint.NOTIFY_HINT, message, 3)
		return
	end

	local spawntable = LIBEntities.GetSpawntable(workloadEntry.entity.ent, true)
	local title = spawntable.PrintName or spawntable.Name

	self:EmitSound("NPC_CScanner.TakePhoto")
	RunConsoleCommand("dev_sligwolf_zdevtools_icongen_snapshot")

	local message = LIBPrint.FormatMessage("Printed snapshot of '%s' to console!", title)
	LIBPrint.Notify(LIBPrint.NOTIFY_GENERIC, message, 3)
end

function SWEP:IsDoFButtonPressedPressed()
	return input.IsMouseDown(MOUSE_MIDDLE)
end

function SWEP:IsStandingStillForFullDoF()
	local owner = self:GetOwner()

	if not IsValid(owner) then
		return false
	end

	local now = CurTime()

	local pos = owner:EyePos()
	local ang = owner:EyeAngles()
	local fov = self:GetZoom()

	local oldPos = self.oldPos or Vector()
	local oldAng = self.oldAng or Angle()
	local oldFov = self.oldFov or 0

	self.oldPos = pos
	self.oldAng = ang
	self.oldFov = fov

	local delay = self.holdDelay
	local timeout = math.max(self.posTime or 0, now + delay)

	if not self.posTime then
		self.posTime = timeout
	end

	if not self.posTimeInputLock then
		local renderButtonPressed = self:IsDoFButtonPressedPressed()
		if not renderButtonPressed then
			self.posTime = timeout
			self.posTimeInputLock = nil
			return false, delay
		end
	end

	if LIBIconGenerator.IsUIOpen() or self:FreezeMovement() then
		self.posTime = timeout
		self.posTimeInputLock = nil
		return false, delay
	end

	local currentSuperDofOptions = LIBIconGenerator.GetSuperDofOptions()
	if not currentSuperDofOptions then
		self.posTime = timeout
		self.posTimeInputLock = nil
		return false, delay
	end

	if ang:IsEqualTol(oldAng, 0.1) and pos:IsEqualTol(oldPos, 0.1) and fov == oldFov then
		if self.posTime <= now then
			self.posTimeInputLock = true
			return true, 0
		end
	else
		self.posTime = timeout
		self.posTimeInputLock = nil
	end

	local timeleft = math.Clamp(self.posTime - now, 0, delay)
	return false, timeleft
end

function SWEP:ApplyQuickDofState()
	if self.hasQuickDofRendered then
		-- realtime DoF preview
		LIBIconGenerator.RequestDofRender(true)
		self.hasQuickDofRendered = true
		self.hasFullDofRendered = false
	else
		LIBIconGenerator.ResetRequestDofRender()
		self.hasQuickDofRendered = false
		self.hasFullDofRendered = false
	end
end

function SWEP:DrawHUD()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		return
	end

	local standingStill, standingStillTimeLeft = self:IsStandingStillForFullDoF()
	local oldStandingStill = self.oldStandingStill
	local changedStandingStill = standingStill ~= oldStandingStill

	self.oldStandingStill = standingStill

	local quickDof = self:IsDoFButtonPressedPressed()
	local oldQuickDof = self.oldQuickDof
	local changedQuickDof = quickDof ~= oldQuickDof

	self.oldQuickDof = quickDof

	local currentSuperDofOptions = LIBIconGenerator.GetSuperDofOptions()
	LIBIconGenerator.SetSuperDof(currentSuperDofOptions)

	if changedStandingStill then
		self.stabilityProgress = 0
		self.pulseAlpha = 0

		if standingStill then
			-- full DoF preview
			LIBIconGenerator.RequestDofRender(false)
			self.hasFullDofRendered = true
		else
			self:ApplyQuickDofState()
		end
	end

	if not standingStill and changedQuickDof and quickDof then
		-- toggle quick dof
		self.hasQuickDofRendered = not self.hasQuickDofRendered
		self:ApplyQuickDofState()
	end

	if self.hasFullDofRendered and changedQuickDof and quickDof then
		-- toggle full dof off
		self.posTimeInputLock = nil
		self.posTime = nil

		self.hasQuickDofRendered = false
		self:ApplyQuickDofState()
	end

	LIBIconGenerator.CopyScreenToBuffer()
	self:RenderView(standingStillTimeLeft)
end

local g_textCol = Color(255, 255, 255)
local g_textShadowCol = Color(0, 0, 0)
local g_textBackgroundCol = Color(0, 0, 0)
local g_cycleCol = Color(200, 200, 255)
local g_cycleBackgroundCol = Color(60, 60, 60)
local g_cycleBorderCol = Color(255, 255, 255)

local function drawProgressSector(x, y, radius, startPercent, endPercent, segments)
	if startPercent == endPercent then return end

	local vertices = {}

	table.insert(vertices, {x = x, y = y})

	for i = segments, 0, -1 do
		local pct = startPercent + (i / segments) * (endPercent - startPercent)
		local angle = -math.tau / 4 - (pct * math.tau)

		table.insert(vertices, {
			x = x + math.cos(angle) * radius,
			y = y + math.sin(angle) * radius
		})
	end

	surface.DrawPoly(vertices)
end

local function drawDualColorCircleChart(x, y, radius, segments, progress, colorActive, colorBackground)
	progress = math.Clamp(progress, 0, 1)

	draw.NoTexture()

	surface.SetDrawColor(colorActive)
	drawProgressSector(x, y, radius, 0, progress, math.ceil(segments * progress))

	surface.SetDrawColor(colorBackground)
	drawProgressSector(x, y, radius, progress, 1, math.ceil(segments * (1 - progress)))
end

function SWEP:RenderHoldHint()
	self.pulseAlpha = math.Approach(self.pulseAlpha, 1, FrameTime() * 4)
	local pulseAlpha = self.pulseAlpha

	local x, y = ScrW() / 2, ScrH() * 0.9

	draw.NoTexture()
	surface.SetFont("HudDefault")

	local text = "Hold For Full DoF"

	local textX, textY = x, y
	local textW, textH = surface.GetTextSize(text)

	local textBackgroundW = textW + 20
	local textBackgroundH = textH + 20
	local textBackgroundX = textX - textBackgroundW / 2
	local textBackgroundY = textY - textBackgroundH / 2

	g_textCol.a = pulseAlpha * 255
	g_textShadowCol.a = pulseAlpha * 255
	g_textBackgroundCol.a = pulseAlpha * 150

	g_cycleCol.a = pulseAlpha * 200
	g_cycleBackgroundCol.a = pulseAlpha * 200
	g_cycleBorderCol.a = pulseAlpha * 200

	surface.SetDrawColor(g_textBackgroundCol)
	surface.DrawRect(textBackgroundX, textBackgroundY, textBackgroundW, textBackgroundH)

	draw.SimpleText(text, "HudDefault", textX + 2, textY + 2, g_textShadowCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "HudDefault", textX, textY, g_textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local circleRadius = 64
	local circleSegments = 60
	local circleProgress = self.stabilityProgress

	local circleX, circleY = x, textBackgroundY + textBackgroundH + circleRadius + 10

	drawDualColorCircleChart(circleX, circleY, circleRadius, circleSegments, circleProgress, g_cycleCol, g_cycleBackgroundCol)
end

function SWEP:RenderView(standingStillTimeLeft)
	local holdHintAt = self.holdHintAt

	LIBIconGenerator.RenderBufferToCanvas()
	LIBIconGenerator.DrawPreviewScreen()

	if standingStillTimeLeft <= 0 or standingStillTimeLeft > holdHintAt then
		self.stabilityProgress = 0
		self.pulseAlpha = 0
		return
	end

	self.stabilityProgress = math.Clamp((holdHintAt - standingStillTimeLeft) / holdHintAt, 0, 1)
	self:RenderHoldHint()
end

function SWEP:PrintWeaponInfo(x, y, alpha)
end

function SWEP:HUDShouldDraw(name)
	-- So we can change weapons
	if name == "CHudWeaponSelection" then return true end
	if name == "CHudChat" then return true end
	if name == "CHudGMod" then return true end

	return false
end

function SWEP:FreezeMovement()
	local owner = self:GetOwner()
	-- Don't aim if we're holding the right mouse button
	if owner:KeyDown(IN_ATTACK2) or owner:KeyReleased(IN_ATTACK2) then return true end
	return false
end

function SWEP:AdjustMouseSensitivity()
	if self:GetOwner():KeyDown(IN_ATTACK2) then return 1 end
	return self:GetZoom() / 80
end

