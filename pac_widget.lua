local wibox = require("wibox")
local naughty = require("naughty")
local awful = require("awful")
local gears = require ("gears")
local beautiful = require("beautiful")

-- pacman/aur updates

local cmd_timer = nil

local pac_widget = wibox.widget {
    layout = wibox.layout.fixed.horizontal,
    {
        widget = wibox.widget.imagebox,
        image = gears.color.recolor_image(gears.filesystem.get_configuration_dir() .. "/pacman.png", beautiful.fg_normal),
        resize = true,
    },
    {
        id = "text",
        widget = wibox.widget.textbox,
        text = "00",
        align = "center",
        resize = true,
        font = beautiful.font_large,
    }
}

local function update()
    if cmd_timer ~= nil then return end

    local cmd = "pacaur -Qu --color=never | awk '{ print($3, $4, $5, $6) }' | column -t"


    awful.spawn.easy_async_with_shell(cmd, function(stdout, stderr)
        local updates = 0
        local pac_info = "No updates"

        if stdout ~= "" then
            pac_info = stdout:gsub("\n$", "")
            for u in stdout:gmatch("[^\n]+") do
                updates = updates + 1
            end
        end

        pac_widget.text:set_text(string.format("%02d", updates))
        pac_tooltip:set_text(pac_info)
    end)
end

pac_tooltip = awful.tooltip {
    objects = {
        pac_widget
    },
    margins = 4,
    text = "No updates",
}

gears.timer.start_new(60, function() update(); return true end)
update()

-- mouse bindings
pac_widget:connect_signal("button::press", update)

return pac_widget
