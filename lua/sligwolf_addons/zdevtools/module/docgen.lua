AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIBMustache = SligWolf_Addons.Mustache
local LIBString = SligWolf_Addons.String
local LIBConvar = SligWolf_Addons.Convar
local LIBPrint = SligWolf_Addons.Print
local LIBFile = SligWolf_Addons.File
local LIBNet = SligWolf_Addons.Net

if SERVER then
	LIBNet.AddNetworkString("zdevtools_docgen_serverdata")
end

local function FilterSubHelpList(subHelplist, addonnames, tablename, tableout)
	if not subHelplist then
		return
	end

	for _, helpItem in ipairs(subHelplist) do
		local cmdName = helpItem.name

		local addon = nil

		for _, addonname in ipairs(addonnames) do
			if string.find(cmdName, "_" .. addonname .. "_", 1, true) then
				addon = addonname
				break
			end
		end

		if not addon then
			continue
		end

		local addonResult = tableout[addon] or {}
		tableout[addon] = addonResult

		local addonSubResult = addonResult[tablename] or {}
		addonResult[tablename] = addonSubResult

		local helpObj = helpItem.help

		local newHelpItem = {
			name = cmdName,
			plaintext = helpObj:GetPlaintext(),
			parameters = helpItem.parameters,
		}

		table.insert(addonSubResult, newHelpItem)
	end
end

local function FilterHelpList(helplist, addonnames)
	local result = {}

	FilterSubHelpList(helplist.sharedConvars, addonnames, "sharedConvars", result)
	FilterSubHelpList(helplist.clientConvars, addonnames, "clientConvars", result)
	FilterSubHelpList(helplist.commands, addonnames, "commands", result)

	return result
end

local function DeDuplicateSubHelpList(subHelplist, tablename, dedupe, tableout)
	if not subHelplist then
		return
	end

	for addon, addonSubHelplist in pairs(subHelplist) do
		for _, addonSubHelplistItem in ipairs(addonSubHelplist) do
			local cmdName = helpItem.name

			if dedupe[cmdName] then
				continue
			end

			dedupe[cmdName] = true

			local addonResult = tableout[addon] or {}
			tableout[addon] = addonResult

			local addonSubResult = addonResult[tablename] or {}
			addonResult[tablename] = addonSubResult

			table.insert(addonSubResult, helpItem)
		end
	end
end

local function DeDuplicateHelpList(helplistServer, helplistClient)
	local dedupe = {}
	local result = {}

	DeDuplicateSubHelpList(helplistServer.sharedConvars, "sharedConvars", dedupe, result)
	DeDuplicateSubHelpList(helplistClient.sharedConvars, "sharedConvars", dedupe, result)

	DeDuplicateSubHelpList(helplistServer.clientConvars, "clientConvars", dedupe, result)
	DeDuplicateSubHelpList(helplistClient.clientConvars, "clientConvars", dedupe, result)

	DeDuplicateSubHelpList(helplistServer.commands, "commands", dedupe, result)
	DeDuplicateSubHelpList(helplistClient.commands, "commands", dedupe, result)

	return result
end

local function RunDocGeneratorCmd(ply, cmd, args)
	local addonfilter = string.lower(string.Trim(tostring(args[1] or "")))

	if addonfilter == "" or addonfilter == "all" then
		addonfilter = "*"
	end

	local addons = SligWolf_Addons.GetAddonsSorted()
	local selectedAddons = {}

	for _, addon in ipairs(addons) do
		local addonname = addon.Addonname

		if not LIBString.WildcardMatch(addonname, addonfilter) then
			continue
		end

		table.insert(selectedAddons, addonname)
	end

	local helplist = LIBConvar.GetCommandHelpList()

	local filteredHelpListServer = FilterHelpList(helplist, selectedAddons)

	LIBNet.Start("zdevtools_docgen_serverdata")
		LIBNet.WriteTable(selectedAddons)
		LIBNet.WriteTable(filteredHelpListServer)
	LIBNet.Send(ply)
end

LIBConvar.AddCommand("dev_sligwolf_zdevtools_docgen_generate", {
	flags = bit.bor(FCVAR_DONTRECORD, FCVAR_GAMEDLL),
	role = LIBConvar.ROLE_HOST_PLAYER,

	callback = RunDocGeneratorCmd,

	help = "Generate Addon documentations.",
	helpSyntax = "[<addon wildcard|*>]",
})

if CLIENT then
	local function ReadTemplate(templateName)
		local fileNameTemplate = LIBFile.Join("docgen", templateName)

		local fileNameTemplateAbsolute = LIBFile.GetAbsolutePath(fileNameTemplate, SLIGWOLF_ADDON, LIBFile.REALM_DATA_STATIC)
		local template = LIBFile.Read(fileNameTemplate, SLIGWOLF_ADDON, LIBFile.REALM_DATA_STATIC) or ""

		if template == "" then
			LIBPrint.Print(
				"ReadTemplate: Template '%s' not found or empty",
				fileNameTemplateAbsolute
			)

			return
		end

		return template
	end

	local function GenerateHelpText(templateName, template, addonname, data)
		local generated = LIBMustache.Render(template, data)

		generated = LIBString.NormalizeNewlines(generated, "\r\n")

		local fileNameGenerated = LIBFile.Join("docgen", addonname, templateName)
		local fileNameGeneratedAbsolute = LIBFile.GetAbsolutePath(fileNameGenerated, SLIGWOLF_ADDON, LIBFile.REALM_DATA_STATIC)
		local success = LIBFile.Write(fileNameGenerated, generated, SLIGWOLF_ADDON)

		if success then
			LIBPrint.Print("GenerateHelpText: Written to 'data/%s'.", fileNameGeneratedAbsolute)
		else
			LIBPrint.Print("GenerateHelpText: Could not Write to 'data/%s'", fileNameGeneratedAbsolute)
		end
	end

	LIBNet.Receive("zdevtools_docgen_serverdata", function(len)
		local selectedAddons = LIBNet.ReadTable()
		local filteredHelpListServer = LIBNet.ReadTable()

		local helplist = LIBConvar.GetCommandHelpList()
		local filteredHelpListClient = FilterHelpList(helplist, selectedAddons)

		local filteredHelp = DeDuplicateHelpList(filteredHelpListServer, filteredHelpListClient)
		local template = ReadTemplate("workshop-template.txt")

		for _, addonname in ipairs(selectedAddons) do
			local filteredAddonHelp = filteredHelp[addonname]
			if not filteredAddonHelp then
				continue
			end

			local data = {
				addonname = addonname,
				consoleHelp = filteredAddonHelp,
			}

			data.test = util.TableToJSON(data, true)

			GenerateHelpText("workshop.txt", template, addonname, data)
		end
	end)
end

return true

