hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = false, blur_popups = false })

hl.layer_rule({
    match = { namespace = "quickshell:onScreenDisplay" },
    no_anim = true
})

hl.window_rule({
    match = { pin = 1 },
    border_color = require("custom.palette").outline
})
