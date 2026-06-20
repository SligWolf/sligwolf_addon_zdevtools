AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

SLIGWOLF_ADDON:AddWeapon("sligwolf_zdevtools_icongen_camera", {
	title = "ZDevtools Icongen Camera",
})

return true

