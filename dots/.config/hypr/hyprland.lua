-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    require("custom.env")
end

-- Default configurations --
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom.general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom.rules")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
end

-- nwg-displays support --
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
end
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    require("monitors")
end

-- Shell overrides --
require("hyprland.shellOverrides.main")

-- Monitor safe mode: if this marker file exists, skip HyprMon and StelSync entirely and
-- force every monitor to the safest possible fallback. Exists so a bad monitor config
-- (wrong color management mode, unsupported forced refresh rate, etc.) can be recovered
-- from with a single `touch` command at a TTY, instead of having to find and edit the
-- specific broken line in a generated file while the display is unusable.
--
-- To use: `touch ~/.config/hypr/SAFE_MODE` then restart Hyprland. Remove the file
-- (`rm ~/.config/hypr/SAFE_MODE`) once you've fixed the real config, then restart again
-- to resume normal HyprMon/StelSync behavior.
if is_file_exists(HOME .. "/.config/hypr/SAFE_MODE") then
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, cm = "srgb", vrr = 0 })
else
    -- hyprmon: managed monitor profile include
    require("hyprmon")

    -- ii Settings > Monitors: auto-adapt overrides (always applied last, wins over any HyprMon profile)
    if is_file_exists(HOME .. "/.config/hypr/autoadapt.lua") then
        require("autoadapt")
    end
end
