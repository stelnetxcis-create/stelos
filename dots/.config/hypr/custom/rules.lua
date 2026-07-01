-- ######## Custom Window Rules ########

-- Vicinae (app launcher overlay)
hl.window_rule({ match = { class = "^(Vicinae)$" }, float = true })
hl.window_rule({ match = { class = "^(Vicinae)$" }, center = true })
hl.window_rule({ match = { class = "^(Vicinae)$" }, pin = true })
hl.window_rule({ match = { class = "^(Vicinae)$" }, stay_focused = true })

-- Transparency + blur for specific apps
hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "0.85 0.8" })
hl.window_rule({ match = { class = "^(code-url-handler)$" }, opacity = "0.85 0.8" })
hl.window_rule({ match = { class = "^(code)$" }, opacity = "0.85 0.8" })
hl.window_rule({ match = { class = "^(vscodium)$" }, opacity = "0.85 0.8" })
hl.window_rule({ match = { class = "^(antigravity)$" }, opacity = "0.85 0.8" })
