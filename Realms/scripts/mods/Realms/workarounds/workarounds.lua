local mod = get_mod("Realms")
local Cinematics = mod:io_dofile("Realms/scripts/mods/Realms/workarounds/cinematics")
local GameplayTimeScale = mod:io_dofile("Realms/scripts/mods/Realms/workarounds/gameplay_time_scale")
local Prologue = mod:io_dofile("Realms/scripts/mods/Realms/workarounds/prologue")
local ShootingRange = mod:io_dofile("Realms/scripts/mods/Realms/workarounds/shooting_range")
local TeamHud = mod:io_dofile("Realms/scripts/mods/Realms/workarounds/team_hud")

local Workarounds = {}

function Workarounds.install(Session, GameplayControl)
	Cinematics.install(Session)
	GameplayTimeScale.install(Session, GameplayControl)
	Prologue.install(Session)
	ShootingRange.install(Session, GameplayControl)
	TeamHud.install(Session)
end

function Workarounds.update()
	ShootingRange.update()
end

return Workarounds
