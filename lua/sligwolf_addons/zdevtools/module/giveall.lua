AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBPrint = SligWolf_Addons.Print
local LIBNet = SligWolf_Addons.Net

local g_vanillaWeapons = {
	"weapon_physcannon",
	"weapon_stunstick",
	"weapon_frag",
	"weapon_crossbow",
	"weapon_bugbait",
	"weapon_rpg",
	"weapon_crowbar",
	"weapon_shotgun",
	"weapon_pistol",
	"weapon_slam",
	"weapon_smg1",
	"weapon_ar2",
	"weapon_357",

	"weapon_physgun",
	"weapon_cubemap",
	"gmod_camera",
	"gmod_tool",
}

local g_lastWeaponClass = nil

local function giveAllAmmo(ply, callback)
	if not IsValid(ply) then
		return
	end

	local togive = {}
	local ammoCount = 300

	for _, weapon in ipairs(ply:GetWeapons()) do
		if not IsValid(weapon) then
			continue
		end

		local primary = weapon:GetPrimaryAmmoType()
		if primary >= 0 then
			togive[primary] = primary
		end

		local secondary = weapon:GetSecondaryAmmoType()
		if secondary >= 0 then
			togive[secondary] = secondary
		end
	end

	for _, ammo in pairs(togive) do
		ply:SetAmmo(ammoCount, ammo)
	end

	SLIGWOLF_ADDON:EntityTimerOnce(ply, "GiveAll", 0.1, function(thisPly)
		callback(thisPly)
	end)
end

local function giveAllWeapons(ply, callback)
	if not IsValid(ply) then
		return
	end

	local SpawnableWeapons = LIBUtil.GetList("Weapon")

	local togive = {}

	for _, weaponItem in pairs(SpawnableWeapons) do
		if not weaponItem then
			continue
		end

		if not weaponItem.Spawnable then
			PrintTable({weaponItem = weaponItem})
			continue
		end

		if not weaponItem.Is_SLIGWOLF then
			continue
		end

		local classname = weaponItem.ClassName
		if not classname then
			continue
		end

		if not classname then
			continue
		end

		togive[classname] = classname
	end

	for _, classname in ipairs(g_vanillaWeapons) do
		togive[classname] = classname
	end

	local lastWeapon = ply:GetActiveWeapon()
	if IsValid(lastWeapon) then
		g_lastWeaponClass = lastWeapon:GetClass()
	end

	for _, classname in pairs(togive) do
		local weapon = ply:GetWeapon(classname)

		if not IsValid(weapon) then
			continue
		end

		weapon:Remove()
	end

	SLIGWOLF_ADDON:EntityTimerOnce(ply, "GiveAll", 0.1, function(thisPly)
		for _, classname in pairs(togive) do
			thisPly:Give(classname)
		end

		thisPly:SelectWeapon(g_lastWeaponClass or "weapon_physgun")

		SLIGWOLF_ADDON:EntityTimerOnce(thisPly, "GiveAll", 0.1, function(thisThisPly)
			giveAllAmmo(thisThisPly, callback)
		end)
	end)
end

local function giveAll(ply, modeId)
	if modeId <= 0 then
		return
	end

	local callback = function()
		ply:EmitSound("Weapon_Alyx_Shotgun.Cock")
	end

	if modeId == 1 then
		giveAllWeapons(ply, callback)
	elseif modeId == 2 then
		giveAllAmmo(ply, callback)
	end
end

if SERVER then
	LIBNet.AddNetworkString("zdevtools_giveall_call")

	LIBNet.Receive("zdevtools_giveall_call", function(ply)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			return
		end

		local modeId = net.ReadUInt(4)
		giveAll(ply, modeId)
	end)
end

local function giveAllCmd(ply, command, args)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	local modeId = 0

	local mode = tostring(args[1] or "")
	if mode == "" then
		mode = "<empty>"
	end

	if mode == "weapons" then
		modeId = 1
	elseif mode == "ammo" then
		modeId = 2
	end

	if modeId <= 0 then
		LIBPrint.Print("Unknown mode '%s' given. Enter: 'dev_sligwolf_zdevtools_giveall {weapons|ammo}'", mode)
		return
	end

	if SERVER then
		giveAll(ply, modeId)
	else
		LIBNet.Start("zdevtools_giveall_call")
			net.WriteUInt(modeId, 4)
		LIBNet.SendToServer()
	end
end

concommand.Add("dev_sligwolf_zdevtools_giveall", giveAllCmd)

return true

