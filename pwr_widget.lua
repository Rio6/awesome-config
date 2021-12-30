local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local beautiful = require("beautiful")

local warned = false
local warn_pcent = 10

local pwr_widget = wibox.widget {
    widget = wibox.widget.textbox,
    align = "center",
    font = beautiful.font_large,
}

return function(bat)
    -- power
    local function pwr_usage()
        local rst = {}

        for line in io.lines("/sys/class/power_supply/" .. bat .. "/capacity") do
            rst.pcent = tonumber(line)
        end

        for line in io.lines("/sys/class/power_supply/" .. bat .. "/status") do
            rst.stat = line
        end

        return rst
    end

    local function update()
        local usage = pwr_usage()
        if usage then
            local pwr_icon
            if  usage.stat == "Charging" then
                pwr_icon = ""
                warned = false
            else
                pwr_icon = ({ "", "", "", "", "", "", "", "", "", "", "" })[math.ceil((usage.pcent+1)/10)]

                if usage.pcent <= warn_pcent and not warned then
                    naughty.notify({
                        title="Warning",
                        text="\nThe battery is low!       \n",
                        timeout=0,
                        fg = beautiful.fg_urgent,
                        bg = beautiful.bg_urgent
                    })
                    warned = true
                end
            end

            pwr_widget:set_markup(string.format("%s %02.0f", pwr_icon, usage.pcent))
        end
    end

    gears.timer.start_new(5, function() update(); return true end)
    update()

    return pwr_widget
end
