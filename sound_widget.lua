local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")

---- Pulse volume widget

local sound_widget = wibox.widget {
    widget = wibox.widget.textbox,
    align = "center",
    font = beautiful.font_large,
}

function sound_widget:volume(action)
    local cmd
    if action ~= nil then
        cmd = "amixer set Master " .. action
    else
        cmd = "amixer get Master"
    end

    awful.spawn.easy_async(cmd, function(output)
        local volu, mute = output:match("%[([0-9.,]+)%%%].*%[([onf]+)%]")

        if mute ~= "on" or volu == nil then
            self:set_text("00 ﱝ ") -- for some reason this icon reverses the text
        else
            self:set_text(string.format("墳 %02d", volu))
        end
    end)
end

-- mouse bindings
sound_widget:buttons(awful.util.table.join(
  awful.button({ }, 1, function() --click to (un)mute
    sound_widget:volume("toggle")
  end),
  awful.button({ }, 4, function() --wheel to rise or reduce volume
    sound_widget:volume("1%+")
  end),
  awful.button({ }, 5, function()
    sound_widget:volume("1%-")
  end)
))

sound_widget:connect_signal("mouse::enter", function() sound_widget:volume() end)
gears.timer.start_new(10, function()
    sound_widget:volume()
    return true
end)
sound_widget:volume()

return sound_widget
