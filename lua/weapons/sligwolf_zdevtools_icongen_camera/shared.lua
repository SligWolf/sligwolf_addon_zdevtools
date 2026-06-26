AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

local addonName = "zdevtools"

DEFINE_BASECLASS("sligwolf_weapon_base")

-- Tell the user something is wrong ("Broken") with the addons in case they see the usually hidden placeholder node.
-- This item is moved to a different custom build category if everything is fine and the "Broken" one is hidden.
SWEP.Category				= "SligWolf's Addons (Broken)"

SWEP.Spawnable				= false
SWEP.AdminOnly				= false
SWEP.DeveloperOnly			= true
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
local LIBPrint = SligWolf_Addons.Print

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:AddNetworkRVar("Float", "Zoom")
	self:AddNetworkRVar("Float", "ZoomRaw")
end

function SWEP:SetZoom(num)
	self:SetNetworkRVar("Zoom", num)
end

function SWEP:SetZoomRaw(num)
	self:SetNetworkRVar("ZoomRaw", num)
end

function SWEP:GetZoom()
	return self:GetNetworkRVarNumber("Zoom", 0)
end

function SWEP:GetZoomRaw()
	return self:GetNetworkRVarNumber("ZoomRaw", 0)
end

function SWEP:Initialize()
	self:SetAddonID(addonName)
	self:SetHoldType("camera")

	BaseClass.Initialize(self)
end

function SWEP:OnReset()
	if SERVER then
		self:ResetZoom()

		local owner = self:GetOwner()
		if IsValid(owner) then
			owner:SetNoTarget(false)
		end

		return
	end

	self.holdDelay = 0.50
	self.holdHintAt = self.holdDelay - 0.15

	self:ResetRender()

	LIBIconGenerator.CloseDofOptions()
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
		local doScreenshot = owner:KeyDown(IN_SPEED)

		if doScreenshot then
			self:CallOnClient("TakeScreenshot")
		else
			self:CallOnClient("TakeSnapshot")
		end

		return
	end

	if CLIENT and IsFirstTimePredicted() then
		local doScreenshot = owner:KeyDown(IN_SPEED)

		if doScreenshot then
			self:TakeScreenshot()
		else
			self:TakeSnapshot()
		end
	end
end

function SWEP:SecondaryAttack()
	-- see SWEP:HandleZoom()
end

function SWEP:Reload()
	self:ResetZoom()
end

function SWEP:OnDeploy()
	if SERVER then
		local owner = self:GetOwner()
		if IsValid(owner) then
			owner:SetNoTarget(true)
		end
	end

	return true
end

function SWEP:FastThink()
	self:HandleZoom()

	if CLIENT then
		self:HandlePanelInput()
	end
end

function SWEP:ResetZoom()
	local owner = self:GetOwner()

	local zoom = 75

	if IsValid(owner) and owner:IsPlayer() and not owner:IsBot() then
		zoom = owner:GetInfoNum("fov_desired", 75)
	end

	self:SetZoomRaw(zoom)
	self:SetZoom(zoom)
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

	local snap = cmd:KeyDown(IN_SPEED)

	local zoomRaw = self:GetZoomRaw()
	local zoomChange = cmd:GetMouseY() * FrameTime() * 6.6

	local newZoomRaw = zoomRaw + zoomChange
	local newZoomSnapped = newZoomRaw

	if snap then
		newZoomSnapped = math.Round(newZoomSnapped / 5) * 5
	end

	newZoomRaw = math.Clamp(newZoomRaw, 0.1, 175)
	newZoomSnapped = math.Clamp(newZoomSnapped, 0.1, 175)

	-- Handles zooming
	self:SetZoomRaw(newZoomRaw)
	self:SetZoom(newZoomSnapped)
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
end

if SERVER then
	return
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
	local workloadEntry = LIBIconGenerator.GetViewWorkloadEntry()
	if not workloadEntry then
		local message = LIBPrint.FormatMessage("No SW Entity found to snapshot!")

		LIBPrint.Notify(LIBPrint.NOTIFY_HINT, message, 3)
		self:EmitSound("Buttons.snd42")
		return
	end

	local title = workloadEntry.entity.title
	local message = LIBPrint.FormatMessage("Printed snapshot of %s to console!", title)

	LIBIconGenerator.PrintSnapshotToConsole(workloadEntry)

	LIBPrint.Notify(LIBPrint.NOTIFY_GENERIC, message, 3)
	self:EmitSound("NPC_CScanner.TakePhoto")
end

function SWEP:TakeScreenshot()
	local workloadEntry = LIBIconGenerator.GetViewWorkloadEntry()
	if not workloadEntry then
		local message = LIBPrint.FormatMessage("No SW Entity found to screenshot!")

		LIBPrint.Notify(LIBPrint.NOTIFY_HINT, message, 3)
		self:EmitSound("Buttons.snd42")
		return
	end

	local owner = self:GetOwner()

	local title = workloadEntry.entity.title
	local entityData = {
		addonname = workloadEntry.addonname,
		category = workloadEntry.category,
		spawnname = workloadEntry.spawnname,
		theme = workloadEntry.theme,
		ent = workloadEntry.entity.ent,
	}

	local validateCallback = function()
		if not IsValid(self) then
			return false
		end

		if not IsValid(owner) then
			return false
		end

		if owner ~= self:GetOwner() then
			return false
		end

		local activeWeapon = owner:GetActiveWeapon()
		if activeWeapon ~= self then
			return false
		end

		return true
	end

	local callback = function(success, errorOrPath, absolutePath)
		if not success then
			LIBPrint.Notify(LIBPrint.NOTIFY_ERROR, "Could not take screenshot!", 3)
			LIBPrint.Warn("TakeScreenshot: %s", errorOrPath)

			self:ResetRender()
			return
		end

		local jsonPath = LIBIconGenerator.config.iconsFolderManuelJson .. "/" .. workloadEntry.path .. ".json"
		LIBIconGenerator.SaveWorkloadEntry(jsonPath, workloadEntry)

		local message = LIBPrint.FormatMessage("Took screenshot of %s!", title)

		LIBPrint.Notify(LIBPrint.NOTIFY_GENERIC, message, 3)
		LIBPrint.Print("Screenshot written to: %s", absolutePath)

		self:EmitSound("NPC_CScanner.TakePhoto")

		self:ResetRender()
	end

	LIBIconGenerator.TakeScreenshot({
		camera = workloadEntry.camera,
		index = 0,
		count = 0,
		entityData = entityData,
		imagePath = LIBIconGenerator.config.iconsFolderManuel .. "/" .. workloadEntry.path,
		previewTime = 0,
		validateCallback = validateCallback,
		callback = callback,
	})
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

	local x = ScrW() / 2
	local y = ScrH() - 200

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

