-- User Keybindings
hl.bind("CTRL + SUPER + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/illogical-impulse/config.json"), { description = "Edit shell config" })
hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), { description = "Edit user keybinds" })

-- Vicinae Launcher overlay keybinding
hl.bind("CTRL + Space", hl.dsp.exec_cmd("~/.config/hypr/vicinae_wrapper.sh"), { description = "Vicinae Application Launcher" })

-- Close programs
hl.bind("ALT + F4", hl.dsp.window.close(), { description = "Close program" })
