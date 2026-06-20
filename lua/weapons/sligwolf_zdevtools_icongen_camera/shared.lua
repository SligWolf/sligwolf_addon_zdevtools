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

SWEP.ShootSound				= "NPC_CScanner.TakePhoto"
SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false

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

	if SERVER then
		self:SetZoom(70)
	end
end

function SWEP:Reload()
	local owner = self:GetOwner()

	if not owner:KeyDown(IN_ATTACK2) then
		self:SetZoom(75)
	end
end

function SWEP:PrimaryAttack()
	self:DoShootEffect()

	if CLIENT then
		return
	end

	local owner = self:GetOwner()
	if not owner:IsPlayer() then
		return
	end

	owner:ConCommand("dev_sligwolf_zdevtools_icongen_snapshot")
end

function SWEP:SecondaryAttack()
end

function SWEP:Tick()
	local owner = self:GetOwner()
	if CLIENT and owner ~= LocalPlayer() then -- If someone is spectating a player holding this weapon, bail
		return
	end

	local cmd = owner:GetCurrentCommand()
	if not cmd:KeyDown(IN_ATTACK2) then -- Not holding Mouse 2, bail
		return
	end

	self:SetZoom(math.Clamp(self:GetZoom() + cmd:GetMouseY() * FrameTime() * 6.6, 0.1, 175)) -- Handles zooming
end

function SWEP:TranslateFOV(current_fov)
	return self:GetZoom()
end

function SWEP:Deploy()
	return true
end

function SWEP:Equip()
	local owner = self:GetOwner()
	if self:GetZoom() == 70 and owner:IsPlayer() and not owner:IsBot() then self:SetZoom(owner:GetInfoNum("fov_desired", 75)) end
end

function SWEP:ShouldDropOnDie()
	return false
end

function SWEP:DoShootEffect()
	if self.NextShootEffect and self.NextShootEffect > CurTime() then return end
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
		LIBIconGenerator.ResetCamera()
		LIBIconGenerator.ResetSuperDof()
		LIBIconGenerator.ClearBufferRenderTarget()
		LIBIconGenerator.ClearRenderTarget()

		self.oldPos = nil
		self.oldAng = nil
		self.oldFov = nil
		self.posTime = nil

		self.dofRendered = nil
		self.dof = nil
	end
end

function SWEP:OnReloaded()
	if CLIENT then
		LIBIconGenerator.ResetCamera()
		LIBIconGenerator.ResetSuperDof()
		LIBIconGenerator.ClearBufferRenderTarget()
		LIBIconGenerator.ClearRenderTarget()

		self.oldPos = nil
		self.oldAng = nil
		self.oldFov = nil
		self.posTime = nil
		self.dofRendered = nil
	end
end

if SERVER then
	return
end

function SWEP:IsStandingStill()
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

	local timeout = now + 1

	if not self.posTime then
		self.posTime = timeout
	end

	if LIBIconGenerator.IsUIOpen() or self:FreezeMovement() then
		self.posTime = timeout
		return false
	end

	if ang:IsEqualTol(oldAng, 0.01) and pos:IsEqualTol(oldPos, 0.01) and fov == oldFov then
		if self.posTime <= now then
			return true
		end
	else
		self.posTime = timeout
	end

	return false
end

function SWEP:DrawHUD()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		return
	end

	local defaults = LIBIconGenerator.config.defaults
	local defaultsCamera = defaults.camera

	local standingStill = self:IsStandingStill()
	local oldStandingStill = self.oldStandingStill
	local changedStandingStill = standingStill ~= oldStandingStill

	self.oldStandingStill = standingStill

	if changedStandingStill then
		self.dofRendered = false
		self.dof = nil

		LIBIconGenerator.ResetSuperDof()
		LIBIconGenerator.ResetCamera()
	end

	if not standingStill then
		LIBIconGenerator.CopyScreenCopyScreenToBuffer()
		self:RenderView()
		return
	end

	if not self.dof then
		local tr = LIBTrace.PlayerAimTrace(owner, 10000)

		local distance = tr.Hit and tr.HitPos:Distance(tr.StartPos) or 0
		distance = math.Clamp(distance or 0, 0, 10000)

		if distance > 0 then
			self.dof = {
				distance = distance,
				blur = defaultsCamera.dof.blur,
				passes = defaultsCamera.dof.passes,
				steps = defaultsCamera.dof.steps,
			}
		end
	end

	if self.dof then
		self:RenderDofView()
		return
	end

	LIBIconGenerator.CopyScreenCopyScreenToBuffer()
	self:RenderView()
end

function SWEP:RenderView()
	LIBIconGenerator.RenderBufferToRenderTarget()
	LIBIconGenerator.DrawPreviewScreen()
end

function SWEP:RenderDofView()
	local owner = self:GetOwner()
	if not IsValid(owner) then
		return
	end

	if self.dofRendered then
		if not LIBIconGenerator.HasSuperDofRendered() then
			-- Wait until the dof render has been completed
			return
		end

		LIBIconGenerator.CopyScreenCopyScreenToBufferIfRequested()
		self:RenderView()
		return
	end

	if self.dof then
		LIBIconGenerator.SetCamera({
			pos = owner:EyePos(),
			ang = owner:EyeAngles(),
			fov = self:GetZoom(),
		})

		LIBIconGenerator.SetSuperDof(self.dof)

		LIBIconGenerator.RequestCopyScreenCopyScreenToBuffer()
		self.dofRendered = true
	end
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

