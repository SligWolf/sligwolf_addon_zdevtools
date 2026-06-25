AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBTimer = SligWolf_Addons.Timer
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
local g_delay = LIBTimer.TickTime(2)

local function giveAllAmmo(ply, ammoCount, callback)
	if not IsValid(ply) then
		return
	end

	local togive = {}
	local torefill = {}

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

		torefill[weapon] = weapon
	end

	ply:RemoveAllAmmo()

	SLIGWOLF_ADDON:EntityTimerOnce(ply, "GiveAll", g_delay, function()
		for _, ammo in pairs(togive) do
			ply:GiveAmmo(ammoCount, ammo, true)
		end

		for _, weapon in pairs(torefill) do
			if not IsValid(weapon) then
				continue
			end

			weapon:SetClip1(weapon:GetMaxClip1())
			weapon:SetClip2(weapon:GetMaxClip2())
		end

		SLIGWOLF_ADDON:EntityTimerOnce(ply, "GiveAll", g_delay, function()
			callback(ply)
		end)
	end)
end

local function giveAllWeapons(ply, ammoCount, callback)
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

	SLIGWOLF_ADDON:EntityTimerOnce(ply, "GiveAll", g_delay, function()
		for _, classname in pairs(togive) do
			ply:Give(classname, true)
		end

		SLIGWOLF_ADDON:EntityTimerOnce(ply, "GiveAll", g_delay, function()
			ply:SelectWeapon(g_lastWeaponClass or "weapon_physgun")

			SLIGWOLF_ADDON:EntityTimerOnce(ply, "GiveAll", g_delay, function()
				giveAllAmmo(ply, ammoCount, callback)
			end)
		end)
	end)
end

local function giveAll(ply, modeId, ammoCount)
	if modeId <= 0 then
		return
	end

	local callback = function()
		ply:EmitSound("Weapon_Alyx_Shotgun.Cock")
	end

	if modeId == 1 then
		giveAllWeapons(ply, ammoCount, callback)
	elseif modeId == 2 then
		giveAllAmmo(ply, ammoCount, callback)
	end
end

if SERVER then
	LIBNet.AddNetworkString("zdevtools_giveall_call")

	LIBNet.Receive("zdevtools_giveall_call", function(ply)
		if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
			return
		end

		local modeId = net.ReadUInt(4)
		local ammoCount = net.ReadUInt(16)

		giveAll(ply, modeId, ammoCount)
	end)
end

local function giveAllCmd(ply, command, args)
	if not SLIGWOLF_ADDON:IsValidDeveloperPlayer(ply) then
		return
	end

	local modeId = 0

	local mode = string.lower(string.Trim(tostring(args[1] or "")))
	local ammoCountStr = string.lower(string.Trim(tostring(args[2] or "")))
	local ammoCount = tonumber(ammoCountStr or 0) or 0

	if ammoCount <= 0 and ammoCountStr == "" then
		ammoCount = 300
	end

	ammoCount = math.Clamp(ammoCount, 0, 9999)

	if mode == "" then
		mode = "<empty>"
	end

	if mode == "weapons" then
		modeId = 1
	elseif mode == "ammo" then
		modeId = 2
	end

	if modeId <= 0 then
		LIBPrint.Print("Unknown mode '%s' given. Enter: 'dev_sligwolf_zdevtools_giveall {weapons|ammo} [<ammo count>]'", mode)
		return
	end

	if SERVER then
		giveAll(ply, modeId, ammoCount)
	else
		LIBNet.Start("zdevtools_giveall_call")
			net.WriteUInt(modeId, 4)
			net.WriteUInt(ammoCount, 16)
		LIBNet.SendToServer()
	end
end

local helptext = "Give the player all weapons and/or ammo. Syntax: dev_sligwolf_zdevtools_giveall {weapons|ammo} [<ammo count>]"

concommand.Add(
	"dev_sligwolf_zdevtools_giveall",
	giveAllCmd,
	nil,
	helptext
)

return true

