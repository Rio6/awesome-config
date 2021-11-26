local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")

local sys_menu = wibox {
    ontop = true,
    width = 400,
    height = 40 * 5,
    border_width = beautiful.menu_border_width,
    border_color = beautiful.menu_border_color,
    shape = function(cr, w, h) return gears.shape.octogon(cr, w, h, w * 0.04) end,
}

local keys = {}

local function item(text, key, callback)
    local widget = wibox.widget {
        widget = wibox.widget.textbox,
        markup = string.format('<span color="%s">%s</span> %s', beautiful.fg_colored, key, text),
        font = beautiful.font_menu,
        align = "left",
    }

    widget.key = key
    keys[key] = callback

    return widget
end

local layout = wibox.layout.flex.vertical()
layout.spacing = 5
layout:add(
    item("Poweroff", "S", function() awful.spawn("s6-sudo /run/s6-power-sudod poweroff") end),
    item("Reboot", "R", function() awful.spawn("s6-sudo /run/s6-power-sudod reboot") end),
    item("Suspend", "D", function() awful.spawn("s6-sudo /run/s6-power/sudod zzz") end),
    item("Logout", "L", awesome.quit),
    item("Lock", "l", function() awful.spawn.with_shell("xset s activate && sleep 0.5 && xset dpms force off") end)
)

local ssaver_item = item("Screensaver", "a", nil)
layout:add(ssaver_item)

sys_menu.widget = wibox.container.margin(layout, 20, 20, 15, 15)

function sys_menu:show()
    if self.visible then return end

    local ss_enabled = os.execute('test "$(xset q | awk \'/timeout/{print $2}\')" -ne 0')
    local new_ssaver_item = nil
    if ss_enabled then
        new_ssaver_item = item("Disable Screensaver", ssaver_item.key, function()
            awful.spawn.with_shell("xset s 0 0; xset dpms 0 0 0")
        end)
    else
        new_ssaver_item = item("Enable Screensaver", ssaver_item.key, function()
            awful.spawn.with_shell("xset s 300 300; xset dpms 300 300 300")
        end)
    end

    layout:replace_widget(ssaver_item, new_ssaver_item)
    ssaver_item = new_ssaver_item

    awful.keygrabber {
        autostart = true,
        stop_key = gears.table.join(gears.table.keys(keys), { 'Return', 'Escape' }),
        stop_event = "release",
        keypressed_callback = function(self, mod, key, cmd)
            if type(keys[key]) == "function" then
                keys[key]()
            end
        end,
        stop_callback = function()
            self:hide()
        end,
    }

    self.screen = awful.screen.focused()
    awful.placement.centered(self)
    self.visible = true
end

function sys_menu:hide()
    self.visible = false
end

return sys_menu
