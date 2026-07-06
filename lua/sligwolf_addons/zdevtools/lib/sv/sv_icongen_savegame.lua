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

local LIBFile = SligWolf_Addons.File
local LIBHook = SligWolf_Addons.Hook

function LIB.GetSaveGamePath(savegame)
	savegame = tostring(savegame or "")

	if savegame == "" then
		return nil
	end

	if savegame == "none" then
		return nil
	end

	local filename = savegame .. ".gms.dat"
	local path = LIBFile.Join(LIB.config.savegameFolder, filename)
	local absolutePath = LIBFile.GetAbsolutePath(path, SLIGWOLF_ADDON, LIBFile.REALM_DATA_STATIC)

	if LIBFile.Exists(path, SLIGWOLF_ADDON, LIBFile.REALM_DATA_STATIC) then
		return path, absolutePath
	end

	return nil
end

function LIB.SaveGameMap(savegame)
	local path = LIB.GetSaveGamePath(savegame)
	if not path then
		return nil
	end

	local saveFile = LIBFile.Open(path, "rb", SLIGWOLF_ADDON, LIBFile.REALM_DATA_STATIC)
	if not saveFile then
		return nil
	end

	-- file type header
	saveFile:Seek(4)

	-- map name
	local saveMap = saveFile:ReadLine()
	saveMap = string.Trim(saveMap)

	saveFile:Close()

	if saveMap == "" then
		return nil
	end

	return saveMap
end

function LIB.SaveGameExists(savegame)
	savegame = tostring(savegame or "")

	if savegame == "" then
		return false
	end

	if savegame == "none" then
		return true
	end

	if LIB.GetSaveGamePath(savegame) then
		return true
	end

	return false
end

function LIB.LoadSaveGame(savegame, callback)
	savegame = tostring(savegame or "")
	callback = callback or function() end

	local timerName = "icongen_savegame_callback"

	local path, absolutePath = LIB.GetSaveGamePath(savegame)

	local callCallback = function()
		callback(true, path, absolutePath)
	end

	LIBHook.Remove("PostCleanupMap", "Addon_ZDevTools_Icongen_LoadSaveGameCallback")
	SLIGWOLF_ADDON:TimerRemove(timerName)

	if savegame == "none" then
		LIBHook.Add("PostCleanupMap", "Addon_ZDevTools_Icongen_LoadSaveGameCallback", function()
			LIBHook.Remove("PostCleanupMap", "Addon_ZDevTools_Icongen_LoadSaveGameCallback")

			SLIGWOLF_ADDON:TimerOnce(timerName, LIB.config.time.savegame, callCallback)
		end)

		game.CleanUpMap()
		return
	end

	if not path then
		local err = string.format("Savegame '%s' does not exists.", savegame)
		callback(false, err)

		return
	end

	local saveMap = LIB.SaveGameMap(savegame)
	local loadedMap = game.GetMap()

	if not saveMap then
		local err = string.format("Savegame file '%s' could not be read.", absolutePath)
		callback(false, err)

		return
	end

	if saveMap ~= loadedMap then
		local err = string.format("Savegame file '%s' does not match map. ('%s' != '%s')", absolutePath, saveMap, loadedMap)
		callback(false, err)

		return
	end

	local saveFile = LIBFile.Open(path, "rb", SLIGWOLF_ADDON, LIBFile.REALM_DATA_STATIC)
	if not saveFile then
		local err = string.format("Savegame file '%s' could not be read.", absolutePath)
		callback(false, err)

		return
	end

	-- skip file type header
	saveFile:Seek(4)

	-- skip map name
	saveFile:ReadLine()

	-- skip workshop id
	saveFile:ReadLine()

	local saveDataCompressed = saveFile:Read(saveFile:Size() - saveFile:Tell()) or ""

	saveFile:Close()

	if saveDataCompressed == "" then
		local err = string.format("Savegame file '%s' could not read data.", absolutePath)
		callback(false, err)

		return
	end

	local saveData = util.Decompress(saveDataCompressed, 16 * 1024 ^ 2) or ""
	if saveData == "" then
		local err = string.format("Savegame file '%s' is malformed.", absolutePath)
		callback(false, err)

		return
	end

	local result = false

	local ok = ProtectedCall(function()
		result = gmsave.LoadMap(saveData, nil, function()
			SLIGWOLF_ADDON:TimerOnce(timerName, LIB.config.time.savegame, callCallback)
		end)
	end)

	if not ok or result == false then
		-- gmsave.LoadMap never returns true, only false if it fails.
		local err = string.format("LoadSaveGame: Savegame file '%s' could not be loaded.", absolutePath)
		callback(false, err)
	end
end


return true

