pace = pace or {}

pace.Parts = pace.Parts or {}
pace.Errors = {}

include("util.lua")

include("wear.lua")
include("bans.lua")
include("contraption.lua")
include("spawnmenu.lua")

CreateConVar("has_pac3_editor", "1", {FCVAR_NOTIFY})