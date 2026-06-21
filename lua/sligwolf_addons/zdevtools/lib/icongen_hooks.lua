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
		if not IsValid(ply) then
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
end

local function freezePlayerSwitchWeapon(ply, oldWeapon, newWeapon)
	if not IsValid(ply) then
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

return true

