local wibox = require("wibox")
local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")

local function wifi_widget(ifname)
    local wifi_widget = wibox.widget {
        widget = wibox.widget.textbox,
        align = "center",
        font = beautiful.font_large,
    }

    local function update_wifi()
        local up = false
        for line in io.lines("/proc/net/wireless") do
            rst = line:match(ifname .. ": +%d+ +(%d+)")
            if rst ~= nil then
                local level = tonumber(rst)
                wifi_widget:set_markup(string.format(" 直 %02.0f", level))
                up = true
                break
            end
        end
        
        if not up then
            wifi_widget:set_markup(" 睊 00")
        end
    end

    gears.timer.start_new(5, function() update_wifi(); return true end)
    update_wifi()
    
    return wifi_widget
end

return wifi_widget
