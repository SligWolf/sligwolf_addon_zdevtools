AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

local addonName = "zdevtools"

DEFINE_BASECLASS("sligwolf_weapon_base")

-- Tell the user something is wrong ("Broken") with the addons in case they see the usually hidden placeholder node.
-- This item is moved to a different custom build category if everything is fine and the "Broken" one is hidden.
SWEP.Category				= "SligWolf's Addons (Broken)"

SWEP.Spawnable				= false
SWEP.AdminOnly				= false
SWEP.PrintName 				= "ZDevtools Icongen Camera (Locked)"
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
SWEP.SlotPos				= 2
SWEP.DrawAmmo				= false
SWEP.DrawCrosshair			= false

SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false

SWEP.m_bPlayPickupSound		= false

SWEP.DisableDuplicator		= true
SWEP.DoNotDuplicate			= true

if CLIENT then
	SWEP.BounceWeaponIcon 	= false
	SWEP.WepSelectIcon 		= surface.GetTextureID("hud/sligwolf/zdevtools/weaponicon/sligwolf_zdevtools_icongen_camera")
end

if not SligWolf_Addons then return end
if not SligWolf_Addons.HasLoadedAddon then return end
if not SligWolf_Addons.HasLoadedAddon(addonName) then return end

local addon = SligWolf_Addons.GetAddon(addonName)

local LIBIconGenerator = addon.IconGenerator

function SWEP:Initialize()
	self:SetAddonID(addonName)
	self:SetHoldType("camera")
end

function SWEP:Reload()
	if SERVER then
		self:Remove()
	end
end

function SWEP:PrimaryAttack()
	-- do nothing
end

function SWEP:SecondaryAttack()
	-- do nothing
end

function SWEP:ShouldDropOnDie()
	return false
end

function SWEP:OnRemove()
	if CLIENT then
		self:ResetRender()
	end
end

function SWEP:OnReloaded()
	if CLIENT then
		self:ResetRender()
	end
end

function SWEP:Reset()
	if CLIENT then
		self:ResetRender()
	end
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
end

function SWEP:DrawHUD()
	if not LIBIconGenerator.hasCanvasRendered then
		LIBIconGenerator.CopyScreenToBuffer()
		LIBIconGenerator.RenderBufferToCanvas()
	end

	LIBIconGenerator.PollCopyScreenToBuffer()
	LIBIconGenerator.DrawPreviewScreen()
end

function SWEP:PrintWeaponInfo(x, y, alpha)
end

function SWEP:HUDShouldDraw(name)
	-- So we can change weapons
	if name == "CHudGMod" then return true end

	return false
end

function SWEP:FreezeMovement()
	return true
end

