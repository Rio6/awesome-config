local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local array_search = {}

local box = wibox {
    width = 300,
    height = 20,
    ontop = true,
    bg = beautiful.bg_normal,
    border_color = beautiful.border_focus,
    border_width = 1,
    max_widget_size = 500,

    widget = wibox.container.margin (
        wibox.widget {
            widget = wibox.widget.textbox,
            align = "center",
            font = "Droid Sans Mono 12"
        },
    0, 2, 2, 0)
}

box:connect_signal("button::release", function()
    box.visible = false
end)

local function show_box(text)
    awful.placement.top(box, { margins = {top = 40}})
    box.widget.widget:set_markup(text)
    box.height = box.widget.widget:get_height_for_width(box.width, awful.screen.focused())
    box.visible = true
end

function array_search.show_prompt()
    awful.spawn.easy_async("zenity --entry --text 輸入要查詢的字", function(stdout, stderr)
        if stdout and #stdout > 0 then
            local char = stdout--:sub(1, utf8.offset(stdout, 1))
            awful.spawn.easy_async("~/.local/bin/array_keys.sh " .. char, function(stdout, stderr)
                if #stdout > 0 then
                    show_box(stdout)
                else
                    show_box("Error\n")
                end
            end)
        else
            box.visible = false
        end
    end)
end

return array_search
