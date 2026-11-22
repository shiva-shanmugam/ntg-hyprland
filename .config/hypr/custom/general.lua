local palette = require("custom.palette")
-- Matte desktop colors applied after the wallpaper defaults.
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 1,
        col = {
            active_border = palette.outline,
            inactive_border = palette.outline
        }
    },
    decoration = {
        rounding = palette.corner_radius,
        rounding_power = 2,
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = false,
            xray = false,
            brightness = 1,
            contrast = 1,
            noise = 0,
            vibrancy = 0,
            popups = false,
            input_methods = false
        },
        shadow = { enabled = false },
        dim_strength = 0.035
    },
    cursor = { enable_hyprcursor = false },
    misc = { background_color = palette.background }
})

hl.curve("desktopEaseOut", {
    type = "bezier",
    points = {{0.22, 0.82}, {0.25, 1}}
})

hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "desktopEaseOut", style = "popin 97%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "desktopEaseOut", style = "popin 99%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "desktopEaseOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "desktopEaseOut", style = "slide" })
