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

local g_trimPattern = "[%s%(%)%{%}%[%]%\"%\']"
local g_seperatorPattern = "[%s%,%|%;]"

function LIB.ParseString(str)
	str = tostring(str or "")
	str = string.Trim(str)
	str = string.lower(str)

	return str
end

function LIB.ParseVector(stringOrAngleOrVector)
	if not stringOrAngleOrVector or stringOrAngleOrVector == "" then
		return Vector()
	end

	if isvector(stringOrAngleOrVector) then
		stringOrAngleOrVector = Vector(stringOrAngleOrVector)

		return stringOrAngleOrVector
	end

	if isstring(stringOrAngleOrVector) then
		stringOrAngleOrVector = string.Trim(stringOrAngleOrVector, g_trimPattern)
		stringOrAngleOrVector = string.gsub(stringOrAngleOrVector, g_seperatorPattern, " ")
		stringOrAngleOrVector = Vector(stringOrAngleOrVector)

		return stringOrAngleOrVector
	end

	if isangle(stringOrAngleOrVector) then
		stringOrAngleOrVector = Vector(stringOrAngleOrVector.p, stringOrAngleOrVector.y, stringOrAngleOrVector.r)

		return stringOrAngleOrVector
	end

	return Vector()
end

function LIB.ParseAngle(stringOrAngleOrVector)
	if not stringOrAngleOrVector or stringOrAngleOrVector == "" then
		return Angle()
	end

	if isangle(stringOrAngleOrVector) then
		stringOrAngleOrVector = Angle(stringOrAngleOrVector)
		stringOrAngleOrVector:Normalize()

		return stringOrAngleOrVector
	end

	if isstring(stringOrAngleOrVector) then
		stringOrAngleOrVector = string.Trim(stringOrAngleOrVector, g_trimPattern)
		stringOrAngleOrVector = string.gsub(stringOrAngleOrVector, g_seperatorPattern, " ")
		stringOrAngleOrVector = Angle(stringOrAngleOrVector)
		stringOrAngleOrVector:Normalize()

		return stringOrAngleOrVector
	end

	if isvector(stringOrAngleOrVector) then
		stringOrAngleOrVector = Angle(stringOrAngleOrVector.x, stringOrAngleOrVector.y, stringOrAngleOrVector.z)
		stringOrAngleOrVector:Normalize()

		return stringOrAngleOrVector
	end

	return Angle()
end

function LIB.ParseNumber(stringOrNumber)
	if not stringOrNumber or stringOrNumber == "" then
		return 0
	end

	if isnumber(stringOrNumber) then
		return stringOrNumber
	end

	if isstring(stringOrNumber) then
		stringOrNumber = string.Trim(stringOrAngleOrVector, g_trimPattern)
		stringOrNumber = tonumber(stringOrNumber or 0) or 0

		return stringOrNumber
	end

	return 0
end

function LIB.ParseFov(stringOrNumber)
	stringOrNumber = LIB.ParseNumber(stringOrNumber)

	if stringOrNumber == 0 then
		stringOrNumber = 90
	end

	return math.Clamp(stringOrNumber, 0.1, 175)
end

function LIB.ParseBool(bool)
	return tobool(bool)
end

function LIB.FormatString(str)
	str = LIB.ParseString(str)
	return str
end

function LIB.FormatVector(vec)
	vec = LIB.ParseVector(vec)

	local x = math.floor(vec.z * 1000) / 1000
	local y = math.floor(vec.y * 1000) / 1000
	local z = math.floor(vec.z * 1000) / 1000

	local str = string.format("[%.3f, %.3f, %.3f]", x, y, z)
	return str
end

function LIB.FormatAngle(ang)
	ang = LIB.ParseAngle(ang)

	local p = math.floor(ang.p * 1000) / 1000
	local y = math.floor(ang.y * 1000) / 1000
	local r = math.floor(ang.r * 1000) / 1000

	local str = string.format("{%.3f, %.3f, %.3f}", p, y, r)
	return str
end

function LIB.FormatNumber(num)
	num = LIB.ParseNumber(num)
	num = math.floor(num * 1000) / 1000

	local str = string.format("%.3f", num)
	return str
end

function LIB.FormatInteger(int)
	int = LIB.ParseNumber(int)
	int = math.floor(int)

	local str = string.format("%i", int)
	return str
end

function LIB.FormatFov(fov)
	fov = LIB.ParseFov(fov)

	local str = string.format("%.3f", fov)
	return str
end

function LIB.FormatBool(bool)
	bool = LIB.ParseBool(bool)

	local str = bool and "false" or "true"
	return str
end

local g_defaultColor = Color(220, 220, 255)
local g_parenthesesColor = Color(204, 204, 193)
local g_seperatorColor = Color(204, 204, 193)
local g_commaColor = Color(204, 204, 193)
local g_commentColor = Color(96, 153, 85)
local g_keyColor = Color(197, 134, 182)
local g_stringColor = Color(206, 145, 120)
local g_vectorColor = Color(156, 220, 254)
local g_angleColor = Color(220, 220, 170)
local g_numberColor = Color(181, 206, 168)
local g_boolColor = Color(86, 156, 214)

local function outputLine(segments)
	segments = segments or {}

	for _, segment in ipairs(segments) do
		local str = segment.format or ""
		local color = segment.color or g_defaultColor
		local formatParams = segment.formatParams or {}

		if not table.IsEmpty(formatParams) then
			str = string.format(str, unpack(formatParams))
		end

		MsgC(color, str)
	end

	MsgC(g_defaultColor, "\n")
end

local function formatTab(tab)
	if isstring(tab) then
		return tab
	end

	tab = string.rep(" ", tab)
	return tab
end

local function outputKeyValueLine(tab, key, space, valueSegment, comma)
	local segments = {}

	table.insert(segments, {
		format = formatTab(tab),
		color = g_defaultColor,
	})

	table.insert(segments, {
		format = "\"%s\"",
		formatParams = {LIB.FormatString(key)},
		color = g_keyColor,
	})

	table.insert(segments, {
		format = ": ",
		color = g_seperatorColor,
	})

	table.insert(segments, {
		format = formatTab(space),
		color = g_defaultColor,
	})

	table.insert(segments, valueSegment)

	if comma then
		table.insert(segments, {
			format = ",",
			color = g_commaColor,
		})
	end

	outputLine(segments)
end

local function outputKeyValueListLine(tab, key, space, valueSegments, comma)
	local segments = {}

	table.insert(segments, {
		format = formatTab(tab),
		color = g_defaultColor,
	})

	table.insert(segments, {
		format = "\"%s\"",
		formatParams = {LIB.FormatString(key)},
		color = g_keyColor,
	})

	table.insert(segments, {
		format = ": ",
		color = g_seperatorColor,
	})

	table.insert(segments, {
		format = formatTab(space),
		color = g_defaultColor,
	})

	table.insert(segments, {
		format = "[",
		color = g_parenthesesColor,
	})

	local count = #valueSegments

	for i, valueSegment in ipairs(valueSegments) do
		table.insert(segments, valueSegment)

		if i < count then
			table.insert(segments, {
				format = ", ",
				color = g_commaColor,
			})
		end
	end

	table.insert(segments, {
		format = "]",
		color = g_parenthesesColor,
	})

	if comma then
		table.insert(segments, {
			format = ",",
			color = g_commaColor,
		})
	end

	outputLine(segments)
end

local function outputKeyValueStringLine(tab, key, space, value, comma)
	local valueSegment = {
		format = "\"%s\"",
		formatParams = {LIB.FormatString(value)},
		color = g_stringColor,
	}

	outputKeyValueLine(tab, key, space, valueSegment, comma)
end

local function outputKeyValueStringListableLine(tab, key, space, value, comma)
	local valueSegment = {
		format = "\"%s\"",
		formatParams = {LIB.FormatString(value)},
		color = g_stringColor,
	}

	outputKeyValueListLine(tab, key, space, {valueSegment}, comma)
end

local function outputKeyValueVectorLine(tab, key, space, value, comma)
	local valueSegment = {
		format = "\"%s\"",
		formatParams = {LIB.FormatVector(value)},
		color = g_vectorColor,
	}

	outputKeyValueLine(tab, key, space, valueSegment, comma)
end

local function outputKeyValueAngleLine(tab, key, space, value, comma)
	local valueSegment = {
		format = "\"%s\"",
		formatParams = {LIB.FormatAngle(value)},
		color = g_angleColor,
	}

	outputKeyValueLine(tab, key, space, valueSegment, comma)
end

local function outputKeyValueBoolLine(tab, key, space, value, comma)
	local valueSegment = {
		format = LIB.FormatBool(value),
		color = g_boolColor,
	}

	outputKeyValueLine(tab, key, space, valueSegment, comma)
end

local function outputKeyValueNumberLine(tab, key, space, value, comma)
	local valueSegment = {
		format = LIB.FormatNumber(value),
		color = g_numberColor,
	}

	outputKeyValueLine(tab, key, space, valueSegment, comma)
end

local function outputKeyValueIntegerLine(tab, key, space, value, comma)
	local valueSegment = {
		format = LIB.FormatInteger(value),
		color = g_numberColor,
	}

	outputKeyValueLine(tab, key, space, valueSegment, comma)
end

local function outputKeyValueFovLine(tab, key, space, value, comma)
	local valueSegment = {
		format = LIB.FormatFov(value),
		color = g_numberColor,
	}

	outputKeyValueLine(tab, key, space, valueSegment, comma)
end


local function outputObjectStart(tab, key)
	local segments = {}

	if tab then
		table.insert(segments, {
			format = formatTab(tab),
			color = g_defaultColor,
		})
	end

	if key then
		table.insert(segments, {
			format = "\"%s\"",
			formatParams = {LIB.FormatString(key)},
			color = g_keyColor,
		})

		table.insert(segments, {
			format = ": ",
			color = g_seperatorColor,
		})
	end

	table.insert(segments, {
		format = "{",
		color = g_parenthesesColor,
	})

	outputLine(segments)
end

local function outputObjectEnd(tab, comma)
	local segments = {}

	if tab then
		table.insert(segments, {
			format = formatTab(tab),
			color = g_defaultColor,
		})
	end

	table.insert(segments, {
		format = "}",
		color = g_parenthesesColor,
	})

	if comma then
		table.insert(segments, {
			format = ",",
			color = g_commaColor,
		})
	end

	outputLine(segments)
end

local function outputCommentine(tab, comment, ...)
	local segments = {}

	table.insert(segments, {
		format = formatTab(tab),
		color = g_defaultColor,
	})

	table.insert(segments, {
		format = "// " .. comment,
		formatParams = {...},
		color = g_commentColor,
	})

	outputLine(segments)
end

function LIB.PrintSnapshotToConsole(workloadEntry)
	if not workloadEntry then
		return
	end

	local camera = workloadEntry.camera
	local entity = workloadEntry.entity
	local dof = camera.dof

	local addon = SligWolf_Addons.GetAddon(entity.addonname or "")

	outputObjectStart()

	outputCommentine(4, "%s (%s)", addon.NiceName, addon.Addonname)
	outputCommentine(4, "%s", entity.title)

	outputLine()

	outputKeyValueStringLine        (4, "map", "      ", workloadEntry.map, true)
	outputKeyValueStringLine        (4, "category", " ", workloadEntry.category, true)
	outputKeyValueStringListableLine(4, "spawnname", "", workloadEntry.spawnname, true)
	outputKeyValueStringListableLine(4, "theme", "    ", workloadEntry.theme, true)

	outputLine()

	outputObjectStart(4, "entity")
	outputKeyValueVectorLine(8, "pos", "        ", entity.pos, true)
	outputKeyValueAngleLine (8, "ang", "        ", entity.ang, true)
	outputKeyValueBoolLine  (8, "spawnFrozen", "", true, true)
	outputKeyValueNumberLine(8, "wait", "       ", 0)
	outputObjectEnd(4, true)

	outputLine()

	outputObjectStart(4, "camera")
	outputKeyValueVectorLine(8, "pos", "", camera.pos, true)
	outputKeyValueAngleLine (8, "ang", "", camera.ang, true)
	outputKeyValueFovLine   (8, "fov", "", camera.fov, dof ~= nil)
	if dof then
		outputObjectStart(8, "dof")
		outputKeyValueNumberLine (12, "distance", "", dof.distance, true)
		outputKeyValueNumberLine (12, "blur", "    ", dof.blur, true)
		outputKeyValueIntegerLine(12, "passes", "  ", dof.passes, true)
		outputKeyValueIntegerLine(12, "steps", "   ", dof.steps, true)
		outputKeyValueNumberLine (12, "shape", "   ", dof.shape)
		outputObjectEnd(8)
	end
	outputObjectEnd(4)

	outputObjectEnd()
end

return true

