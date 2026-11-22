hl.layer_rule({ match = { namespace = ".*" }, blur = false, blur_popups = false })

hl.layer_rule({
    match = { namespace = "^quickshell:nothingControlCentre$" },
    no_anim = true,
    blur = true,
    -- The tile shadows sit below the opacity threshold for backdrop blur.
    ignore_alpha = 0.18,
    xray = false,
    blur_popups = false
})

hl.layer_rule({
    match = { namespace = "^quickshell:sidebarLeft$" },
    blur = true,
    ignore_alpha = 0.18,
    xray = false
})

hl.layer_rule({
    match = { namespace = "quickshell:onScreenDisplay" },
    no_anim = true
})

hl.window_rule({
    match = { pin = 1 },
    border_color = require("custom.palette").outline
})
