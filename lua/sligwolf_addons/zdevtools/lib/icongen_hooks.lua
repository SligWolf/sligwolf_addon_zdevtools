AddCSLuaFile()
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

local LIBHook = SligWolf_Addons.Hook

if SERVER then
	local function freezePlayerMove(ply, cmd)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			return
		end

		if not ply:GetNWBool("sligwolf_zdevtools_icongen_lock", false) then
			return
		end

		local targetAngles = ply:GetNWAngle("sligwolf_zdevtools_icongen_lock_ang", Angle())
		cmd:SetViewAngles(targetAngles)

		local vecBlank = Vector()
		local targetPos = ply:GetNWVector("sligwolf_zdevtools_icongen_lock_pos", vecBlank)

		if targetPos ~= vecBlank then
			ply:SetPos(targetPos)
		end

		cmd:SetButtons(0)
	end

	LIBHook.Add("StartCommand", "Addon_ZDevTools_Icongen_FreezePlayerMove", freezePlayerMove)

	local function preventItemPickup(ply, item)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			return
		end

		if ply:GetNWBool("sligwolf_zdevtools_icongen_lock", false) then
			return false
		end

		local weapon = ply:GetActiveWeapon()
		if not IsValid(weapon) then
			return
		end

		local weaponClass = weapon:GetClass()

		if weaponClass == LIB.config.cameraWeapon then
			return false
		end

		if weaponClass == LIB.config.lockWeapon then
			return false
		end
	end

	LIBHook.Add("PlayerCanPickupItem", "Addon_ZDevTools_Icongen_PreventItemPickup", preventItemPickup)
	LIBHook.Add("PlayerCanPickupWeapon", "Addon_ZDevTools_Icongen_PreventItemPickup", preventItemPickup)
end

local function freezePlayerSwitchWeapon(ply, oldWeapon, newWeapon)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	if not ply:GetNWBool("sligwolf_zdevtools_icongen_lock", false) then
		return
	end

	if not IsValid(newWeapon) then
		return
	end

	if newWeapon:GetClass() ~= LIB.config.lockWeapon then
		return true
	end
end

LIBHook.Add("PlayerSwitchWeapon", "Addon_ZDevTools_Icongen_FreezePlayerSwitchWeapon", freezePlayerSwitchWeapon)

if CLIENT then
	local hideWeaponPickedUp = function(weapon)
		if not IsValid(weapon) then
			return
		end

		if weapon:GetClass() ~= LIB.config.lockWeapon then
			return true
		end

		local ply = weapon:GetOwner()
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			return
		end

		if not ply:GetNWBool("sligwolf_zdevtools_icongen_lock", false) then
			return
		end

		return true
	end

	LIBHook.Add("HUDWeaponPickedUp", "Addon_ZDevTools_Icongen_HideWeaponPickedUp", hideWeaponPickedUp)
end


return true

