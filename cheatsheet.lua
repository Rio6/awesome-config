local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local cheatsheet = {}

function cheatsheet.show(image, width, height)
    local screen = awful.screen.focused()

    widget = wibox({
        ontop = true,
        bgimage = gears.filesystem.get_configuration_dir() .. image,
        width = width,
        height = height,
        x = screen.geometry.x +(screen.geometry.width - width) / 2,
        y = screen.geometry.y +(screen.geometry.height - height) / 2
    })

    awful.keygrabber {
        autostart = true,
        stop_key = { "Return", "Escape", " " },
        start_callback = function()
            widget.screen = screen
            widget.visible = true
        end,
        stop_callback = function()
            widget.visible = false
        end
    }
end

return cheatsheet
