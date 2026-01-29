local shape = require("gears.shape")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi
local naughty = require("naughty")

local theme = {}

local font_name     = "DroidSansMono Nerd Font "
theme.font          = font_name .. 8
theme.font_large    = font_name .. 10
theme.font_calendar = font_name .. 11
theme.font_menu     = font_name .. 15

theme.bg_normal     = "#111111"
theme.bg_focus      = "#505050"
theme.bg_urgent     = "#e25428"
theme.bg_minimize   = "#303030"
theme.bg_systray    = theme.bg_normal
theme.bg_dark       = "#000000"
theme.bg_colored    = "#e22833"
theme.bg_graph      = theme.bg_colored

theme.fg_normal     = "#cccccc"
theme.fg_focus      = "#dddddd"
theme.fg_urgent     = "#ffffff"
theme.fg_minimize   = "#ffffff"
theme.fg_colored    = theme.bg_colored
theme.fg_dark       = "#111111"
theme.fg_dim        = "#333333"

theme.useless_gap   = 0
theme.border_width  = 1.2
theme.border_normal = "#000000"
theme.border_focus  = "#707050"
theme.border_marked = "#404040"
theme.bar_height = dpi(22)

theme.menu_border_width = 1
theme.menu_border_color = theme.border_focus

theme.calendar_style = {
    border_width = 0,
}

-- There are other variable sets
-- overriding the default one when
-- defined, the sets are:
-- taglist_[bg|fg]_[focus|urgent|occupied|empty]
-- tasklist_[bg|fg]_[focus|urgent]
-- titlebar_[bg|fg]_[normal|focus]
-- tooltip_[font|opacity|fg_color|bg_color|border_width|border_color]
-- mouse_finder_[color|timeout|animate_timeout|radius|factor]
-- Example:
--theme.taglist_bg_focus = "#ff0000"

theme.tooltip_fg = theme.fg_normal
theme.tooltip_bg = theme.bg_normal

-- Display the taglist squares
theme.taglist_bg_empty = theme.bg_minimize
theme.taglist_bg_occupied = theme.bg_focus
theme.taglist_bg_focus = theme.bg_colored

theme.tasklist_bg_focus = theme.bg_colored
theme.tasklist_bg_urgent = theme.bg_urgent

-- Variables set for theming the menu:
-- menu_[bg|fg]_[normal|focus]
-- menu_[border_color|border_width]
theme.menu_submenu_icon = "/usr/share/awesome/themes/default/submenu.png"
theme.menu_height = dpi(15)
theme.menu_width  = dpi(100)

-- You can add as many variables as
-- you wish and access them by using
-- beautiful.variable in your rc.lua

theme.wallpaper = function(s)
    local home = os.getenv("HOME")
    if screen.count() == 1 or s.geometry.width > 2000 then
        return home .. "/.config/awesome/wallpaper.png"
    else
        return home .. "/.config/awesome/wallpaper-2.png"
    end
end

-- You can use your own layout icons like this:
theme.layout_fairh = "/usr/share/awesome/themes/default/layouts/fairhw.png"
theme.layout_fairv = "/usr/share/awesome/themes/default/layouts/fairvw.png"
theme.layout_floating  = "/usr/share/awesome/themes/default/layouts/floatingw.png"
theme.layout_magnifier = "/usr/share/awesome/themes/default/layouts/magnifierw.png"
theme.layout_max = "/usr/share/awesome/themes/default/layouts/maxw.png"
theme.layout_fullscreen = "/usr/share/awesome/themes/default/layouts/fullscreenw.png"
theme.layout_tilebottom = "/usr/share/awesome/themes/default/layouts/tilebottomw.png"
theme.layout_tileleft   = "/usr/share/awesome/themes/default/layouts/tileleftw.png"
theme.layout_tile = "/usr/share/awesome/themes/default/layouts/tilew.png"
theme.layout_tiletop = "/usr/share/awesome/themes/default/layouts/tiletopw.png"
theme.layout_spiral  = "/usr/share/awesome/themes/default/layouts/spiralw.png"
theme.layout_dwindle = "/usr/share/awesome/themes/default/layouts/dwindlew.png"
theme.layout_cornernw = "/usr/share/awesome/themes/default/layouts/cornernww.png"
theme.layout_cornerne = "/usr/share/awesome/themes/default/layouts/cornernew.png"
theme.layout_cornersw = "/usr/share/awesome/themes/default/layouts/cornersww.png"
theme.layout_cornerse = "/usr/share/awesome/themes/default/layouts/cornersew.png"

theme.awesome_icon = "/usr/share/awesome/icons/awesome16.png"

-- Define the icon theme for application icons. If not set then the icons
-- from /usr/share/icons and /usr/share/icons/hicolor will be used.
theme.icon_theme = "Adwaita"

theme.notification_font = theme.font_large
theme.notification_icon_size = dpi(80)
--theme.notification_width = dpi(400)
theme.notification_shape = function(cr, w, h) return shape.octogon(cr, w, h, 10) end
theme.notification_border_color = theme.fg_dim
theme.notification_border_width = 2
naughty.config.defaults.margin = dpi(20) -- bug in naughty makes it not read margin from theme

return theme

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
