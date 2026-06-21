AddCSLuaFile()
local SligWolf_Addons = SligWolf_Addons

if not SLIGWOLF_ADDON then
	SligWolf_Addons.AutoLoadAddon()
	return
end

local SLIGWOLF_ADDON = SLIGWOLF_ADDON

local LIB = SLIGWOLF_ADDON.IconGenerator or {}
SLIGWOLF_ADDON.IconGenerator = LIB

local META = LIB.meta or {}
LIB.meta = META

META.__index = META

LIB.config = {
	-- Output subfolder in data directory
	iconsFolder = "icongen/icons",

	-- Render target settings
	rendertarget = {
		width   = 1024,
		height  = 1024,
	},

	-- Timer settings (seconds)
	time = {
		timeoutTotal   = 25.0,  -- Max time to wait for an entity to be processed
		timeoutEntity  = 2,     -- Max time to wait for an entity to be spawned
		delay    = 0.05,        -- Delay between entities
		preview  = 0.5,         -- How long to show preview on screen
		start    = 1,           -- Delay first item
	},

	defaults = {
		theme = "default",
		camera = {
			pos = Vector(),
			ang = Angle(),
			fov = 90,
			dof = {
				distance = 0,
				blur = 0.5,
				passes = 12,
				steps = 24,
			}
		},
		entity = {
			pos = Vector(),
			ang = Angle(),
			wait = 0,
			freeze = true,
		},
	},

	maxDofDistance = 10000,

	lockWeapon = "sligwolf_zdevtools_icongen_camera_locked",
	unlockWeapon = "weapon_physgun",
}

local g_instances = LIB.instances or {}
LIB.instances = g_instances

for _, oldInstance in pairs(g_instances) do
	if oldInstance.Destroy then
		oldInstance:Destroy()
	end
end

table.Empty(g_instances)

LIB.instaceId = 0

function LIB.NewInstance(name)
	name = tostring(name or "")

	if name == "" then
		error("No name provided")
		return
	end

	LIB.Destroy(name)

	local newInstance = {}

	newInstance.instaceId = LIB.instaceId
	newInstance.name = name
	newInstance.namespace = string.format("icongen[%s]", name)
	newInstance.config = LIB.config

	setmetatable(newInstance, META)

	LIB.instaceId = LIB.instaceId + 1
	LIB.instances[name] = newInstance

	newInstance.isProcessing = nil
	newInstance:Reset()

	return newInstance
end

function LIB.GetInstance(name)
	name = tostring(name or "")

	if name == "" then
		error("No name provided")
		return
	end

	local instances = LIB.instances
	if not instances then
		return nil
	end

	local instance = instances[name]
	if not IsValid(instance) then
		return nil
	end

	return instance
end

function LIB.Destroy(name)
	local instance = LIB.GetInstance(name)

	if instance and instance.Destroy then
		instance:Destroy()
	end

	if LIB.instances then
		LIB.instances[name] = nil
	end
end

function META:Destroy()
	if not IsValid(self) then
		return
	end

	local name = self.name

	if self.OnDestroy then
		ProtectedCall(self.OnDestroy, self)
	end

	if self.DestroyInternal then
		ProtectedCall(self.DestroyInternal, self)
	end

	self:Cancel()
	self:Reset()

	table.Empty(self)

	self.IsValid = function()
		return false
	end

	if LIB.instances then
		LIB.instances[name] = nil
	end
end

function META:IsValid()
	if not self.Destroy then
		return false
	end

	return true
end

function META:__tostring()
	return self.namespace
end

function META:IsLocked()
	local ply = self.player

	if not IsValid(ply) then
		return false
	end

	if not ply:IsPlayer() then
		return false
	end

	if not ply:Alive() then
		return false
	end

	if not ply:GetNWBool("sligwolf_zdevtools_icongen_lock", false) then
		return false
	end

	local lockWeaponEntity = ply:GetWeapon(LIB.config.lockWeapon)
	if not IsValid(lockWeaponEntity) then
		return false
	end

	return true
end

function META:Reset()
	self.isProcessing = false

	if self.OnReset then
		ProtectedCall(self.OnReset, self)
	end

	if self.ResetInternal then
		ProtectedCall(self.ResetInternal, self)
	end
end

function META:Cancel()
	if not self.isProcessing then
		return
	end

	if self.OnCancel then
		ProtectedCall(self.OnCancel, self)
	end

	if self.CancelInternal then
		ProtectedCall(self.CancelInternal, self)
	end

	self:Reset()
end

function META:ValidateState()
	if not self.isProcessing then
		return true
	end

	local ply = self.player

	if not IsValid(ply) then
		self:Cancel()
		return false
	end

	if not self:IsLocked() then
		self:Cancel()
		return false
	end

	if self.ValidateStateInternal then
		local valid = false

		ProtectedCall(function()
			valid = self:ValidateStateInternal()
		end)

		if not valid then
			return false
		end
	end

	return true
end

return true

