local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local function make_widget(name)
    local widget = wibox.widget {
        widget = wibox.widget.piechart,
        display_labels = false,
        colors = { beautiful.bg_colored, beautiful.bg_normal },
        border_width = 0,
        forced_width = 20,
    }
    widget.tooltip = awful.tooltip({
        objects = { widget },
        margins = 4,
        font = beautiful.font_large,
        mode = "outside",
        preferred_alignments = { "middle", "front", "back" },
    })

    return widget
end

local function disk_widget(mnts)
    local widget = wibox.layout.fixed.horizontal()
    local widgets = {}

    local function update_disk()
        for _,mnt in pairs(mnts) do
            awful.spawn.easy_async_with_shell("df -P " .. mnt .. " | tail -n 1", function(data)
                local total, used, avail, pcent = data:gmatch(" (%d+) +(%d+) +(%d+) +(%d+)%%")()

                widgets[mnt].data_list = { {"", pcent}, {"", 100-pcent} }

                local c = beautiful.fg_colored
                widgets[mnt].tooltip:set_markup(string.format(' %4s <span color="%s">%.1f%%</span>\n<span color="%s">%.2fG</span> | <span color="%s">%.2fG</span>',
                    mnt, c, pcent, c, used / 1048576, c, total / 1048576))
            end)
        end
    end

    for _,mnt in pairs(mnts) do
        widgets[mnt] = make_widget(mnt)
        widget:add(widgets[mnt])
    end

    widget:add(wibox.widget.textbox(" "))

    gears.timer.start_new(15, function() update_disk(); return true end)
    update_disk()

    -- mouse bindings
    widget:connect_signal("button::press", update_disk)

    return widget
end

return disk_widget
