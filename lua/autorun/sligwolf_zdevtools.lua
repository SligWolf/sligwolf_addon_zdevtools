-- About SligWolf's ZDevTools:
--  This is an internal development and testing tool for SligWolf's Addons.
--  Do not use on production servers/clients. Only use this during addon development. 
--  Use this addon at your own risk! This will not be publicly available on Workshop!
--  Do not reupload in any way!

-- Safe operation:
--  dev_sligwolf_zdevtools_developers_enabled 0 (default)

AddCSLuaFile()
include("sligwolf_addons/zdevtools/init.lua")

-- Static global to check developer's install. Only for pre sw-base loaded code.
SligWolf_Addons_ZDevTools = true

